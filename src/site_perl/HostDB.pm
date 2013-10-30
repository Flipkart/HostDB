#!/usr/bin/perl

=pod

=head1 NAME

HostDB - A versioned key-value store for any hosts related information

This module provides a functional interface to HostDB

=head1 SYNOPSIS

use HostDB;

my $output = HostDB::get($id[, \%options]);

my $success = HostDB::set($id, $value, \%options);

my $success = HostDB::rename($id, $newname, \%options);

my $success = HostDB::delete($id, \%options);

=head1 SUBROUTINES

=over 8

=cut

package HostDB;

use strict;
use HostDB::Shared qw($logger);
use HostDB::FileStore;
use HostDB::ACL;
use Data::Dumper;
use Log::Log4perl;
use YAML::Syck;

my %parents_map_cache = ();

sub _get_parents {
    my ($host, $namespace, $revision) = @_;
    my $parents_map = {};

    my $_get_parents_rec;
    $_get_parents_rec = sub {
        my $host = shift;
        return () if (!exists $parents_map->{$host});
        my @out = ();
    
        foreach (@{$parents_map->{$host}}) {
            push @out, $_;
            push @out, $_get_parents_rec->("\@$_");
        }
        return ( @out );
    };
    
    if (!$revision && exists $parents_map_cache{$namespace}) {
        $parents_map = $parents_map_cache{$namespace};
    }
    else {
        # Generates key->parents map for a namespace
        # This is heavy as we have to read all keys members in a namespace
        my $keys_store = HostDB::FileStore->new($namespace);
        my @keys = $keys_store->get($revision);
        #$logger->debug( sub { Dumper(\@keys) } );
        foreach my $key (@keys) {
            my $members_store = HostDB::FileStore->new("$namespace/$key/members");
            my @members = $members_store->get($revision);
            foreach (@members) {
                chomp;
                $parents_map->{$_} = [ ] if (!exists $parents_map->{$_});
                push @{$parents_map->{$_}}, $key;
                #$logger->debug(sub { Dumper $parents_map });
            }
        }
        # Cache parents map of HEAD since it is a very common request
        $parents_map_cache{$namespace} = $parents_map if (! $revision);
        #$logger->debug(sub { Dumper $parents_map });
    }
    my @parents = $_get_parents_rec->($host);
    my %out = ();
    $out{$_} = 1 foreach(@parents);  # find unique
    return (keys %out);
}

# http://www.perlmonks.org/?node_id=696592
my $_get_members_rec;
# Return all members recursively and put it in the key=>members hash provided
$_get_members_rec = sub {
    my ($namespace, $key, $revision, $members) = @_;
    return if (exists $members->{$key});
    $members->{$key} = [ ];
    my $store = HostDB::FileStore->new("$namespace/$key/members");
    my @lines = $store->get($revision);
    foreach my $member (@lines) {
        chomp $member;
        next if ($member =~ /^\s*$/);
        next if ($member =~ /^\s*#/);
        if ($member =~ /^\s*\@(.+)\s*$/) {
            $_get_members_rec->($namespace, $1, $revision, $members);
        }
        push @{$members->{$key}}, $member;
    }
};
    
sub _get_members {
    my ($namespace, $key, $revision) = @_;
    my %members = ();
    $_get_members_rec->($namespace, $key, $revision, \%members);
    my %out = ();
    foreach my $key (%members) {
        foreach (@{$members{$key}}) {
            next if (/^\s*\@/);
            $out{$_} = 1;
        }
    }
    return (keys %out);
}

sub _validate_member_addition {
    my ($namespace, $key, $member) = @_;
    
    my $s = HostDB::FileStore->new("$namespace/$key");
    eval {
        $s->get();
    };
    if ($@) {
        $logger->logconfess("4041: Object $namespace/$key does not exist.");
    }
    my $id;
    if ($member =~ /^\s*\@(.+)\s*$/) {
        $id = "$namespace/$1";
    }
    else {
        $id = "hosts/$member";
    }
    $s = HostDB::FileStore->new($id);
    eval {
        $s->get();
    };
    if ($@) {
        $logger->logconfess("4041: Object $id does not exist.");
    }

    if ($member =~ /^\s*\@(.+)\s*$/) {
        my %members = ();
        $_get_members_rec->($namespace, $1, undef, \%members);
        $logger->logconfess("4000: Adding $1 to $key will result in a cycle.") if (exists $members{$key});
    }
    return 1;
}

# For every key in given namespace, get members list and rename a member if exists.
sub _member_rename {
    my ($namespace, $find, $replace, $options) = @_;
    my %matching_files = ();
    my $n = HostDB::FileStore->new($namespace);
    foreach my $key ($n->get()) {
        my $m = HostDB::FileStore->new("$namespace/$key/members");
        foreach ($m->get()) {
            chomp;
            if ($_ eq $find) {
                $matching_files{$key} = $m->{file};
                last;
            }
        }
    }
    foreach my $key (keys %matching_files) {
        my $id = "$namespace/$key/members/$find";
        if (! can_modify($id, $options->{user})) {
            $logger->logconfess("4033: User $options->{user} does not have write permission on $id.");
        }
        $logger->debug("renaming $id");
        my $s = HostDB::FileStore->new($id, {enable_vcs => 0});
        $s->rename($replace);
    }
}

sub _member_delete {
    my ($namespace, $find, $options) = @_;
    my %matching_files = ();
    my $n = HostDB::FileStore->new($namespace);
    foreach my $key ($n->get()) {
        my $m = HostDB::FileStore->new("$namespace/$key/members");
        foreach ($m->get()) {
            chomp;
            if ($_ eq $find) {
                $matching_files{$key} = $m->{file};
                last;
            }
        }
    }
    foreach my $key (keys %matching_files) {
        my $id = "$namespace/$key/members/$find";
        if (! can_modify($id, $options->{user})) {
            $logger->logconfess("4033: User $options->{user} does not have write permission on $id.");
        }
        $logger->debug("deleting $id");
        my $s = HostDB::FileStore->new($id, {enable_vcs => 0});
        $s->delete();
    }
}

=item I<get($id, \%options)> - Returns the value corresponding to the HostDB object as string

STRING $id - Id of HostDB Object

HASHREF \%options - This can take these keys and decides behaviour of get():

=over 8

meta        => Can be 'revisions', 'blame', 'parents' or 'derived'.

limit       => If meta = 'revisions', this is the max number of revisions to get. Defaults to 50.

from        => If meta = 'parents' or 'derived', this is the namespace from which to get the host's meta info.

raw         => If id represents members of a key, setting raw = 1 will not expand inherited members.

=back

In LIST context, also returns the last modified time of the object.

=cut

sub get {
    my ($id, $options) = @_;
    my $store = HostDB::FileStore->new($id, $options);
    my $output;
    # if get is for any metadata
    if (exists $options->{meta}) {
        if ($options->{meta} eq 'revisions') {
            $options->{limit} = 50 if (! exists $options->{limit});
            $output = $store->revisions($options->{limit});
        }
        elsif ($options->{meta} eq 'blame') { 
            $output = $store->blame();
        }
        elsif ($options->{meta} eq 'parents') {
            $logger->logconfess("4001: Namespace missing.") if (! exists $options->{from});
            $logger->logconfess("4051: Namespace should be hosts.") if ($store->{namespace} ne 'hosts');
            $logger->logconfess("4001: Hostname missing.") if (! $store->{key});
            my @parents = _get_parents($store->{key}, $options->{from}, $options->{revision});
            $output = join "\n", sort @parents;
        }
        elsif ($options->{meta} eq 'derived') {
            $logger->logconfess("4001: Namespace missing.") if (! exists $options->{from});
            $logger->logconfess("4051: Namespace should be hosts.") if ($store->{namespace} ne 'hosts');
            $logger->logconfess("4001: Hostname missing.") if (! $store->{key});
            my @parents = _get_parents($store->{key}, $options->{from}, $options->{revision});
            my $out = {};
            foreach (sort @parents) {
                my $s = HostDB::FileStore->new("$options->{from}/$_");
                $out->{$_} = Load(scalar $s->get());
            }
            #$logger->debug(sub {Dumper $out});
            $output = Dump($out);
        }
    }
    elsif ($store->{meta_info} eq 'members' && $store->{record}) {
        $output = $store->get($options->{revision});
#        $logger->debug(sub {Dumper \@members});
#        $logger->debug("$store->{record}");
#        $logger->logconfess("4041: Resource $store->{id} does not exist.") if (! grep {$_ eq $store->{record}} @members);
#        $output = $store->{record};
    }
    elsif ($store->{meta_info} eq 'members' && !(exists $options->{raw} && $options->{raw})) {
        # request is for expanded members list.
        my @members = (_get_members($store->{namespace}, $store->{key}, $options->{revision}));
        $output = join "\n", sort @members;
        #$logger->debug(sub { Dumper(\%members) });
        #$logger->debug(sub { Dumper(\%out) });
    }
    else {
        $output = $store->get($options->{revision});
    }
    
    # Apply transforms on data if any.
    if (exists $options->{search}) {
        my @match = grep { /$options->{search}/ } split /\n/, $output;
        $output = join "\n", @match;
    }
    # Return also the mtime of object in LIST context
    return wantarray ? ($output, $store->mtime()) : $output;
}

=item I<set($id, $value, \%options)> - Sets the value to the HostDB object

STRING $id - Id of HostDB Object

HASHREF \%options - This should have these mandatory keys:

In LIST context, also returns the last modified time of the object.

=over 8

user        => Committer name.

log         => Commit message.

=back

=cut

sub set {
    my ($id, $value, $options) = @_;
    
    $logger->logconfess("4001: Provide a user name.") if (! exists $options->{user});
    if (! can_modify($id, $options->{user})) {
        $logger->logconfess("4033: User $options->{user} does not have write permission on $id.");
    }
    $logger->logconfess("4001: Provide a commit message.") if (! exists $options->{log});
    
    my $store = HostDB::FileStore->new($id, $options);

    $value = "" if (!defined $value);
    
    if (exists $store->{meta_info} && $store->{meta_info} eq 'members') {
        my @members;
        if (exists $store->{record}) {
            @members = ($store->{record});
        }
        else {
            @members = split /\n/, $value;
        }
        foreach (@members) {
            next if (/^\s*#/ || /^\s*$/);
            _validate_member_addition($store->{namespace}, $store->{key}, $_);
        }
        delete $parents_map_cache{$store->{namespace}}; # Invalidate
    }

    $store->set($value, $options->{log}, $options->{user});
    $logger->debug(sub {Dumper $store});
    
    return wantarray ? (1, $store->mtime()) : 1;
}

=item I<rename($id, $newname, \%options)> - Renames a HostDB Object

STRING $id - Id of HostDB Object

STRING $newname - New name for the object identified by $id

HASHREF \%options - Mandatory options for set() are mandatory for rename() also.

In LIST context, also returns the last modified time of the object.

Fails if target exists.

=cut

sub rename {
    my ($id, $newname, $options) = @_;
    $logger->logconfess("4001: Provide a user name.") if (! exists $options->{user});
    if (! can_modify($id, $options->{user})) {
        $logger->logconfess("4033: User $options->{user} does not have write permission on $id.");
    }
    $logger->logconfess("4001: Provide a new name for the object.") if (! defined $newname);
    $logger->logconfess("4001: Provide a commit message.") if (! exists $options->{log});
    
    my $store = HostDB::FileStore->new($id, $options);
    $store->_init_git({user => $options->{user}});
    $store->{_git}->txn_begin();

    # Check if ID is refering a key in a namespace.
    if (exists $store->{key} && $store->{id} eq "$store->{namespace}/$store->{key}") {
        # Yes. So it might have references in other namespace/key/members
        # We have to rename all those references
        if ($store->{namespace} eq 'hosts') {
            # If ID is a host, rename all refs to it in all other namespaces
            my $ndir = HostDB::FileStore->new("");
            foreach my $namespace ($ndir->get()) {
                next if ($namespace =~ /^hosts\$/);
                _member_rename($namespace, $store->{key}, $newname, $options);
            }
        }
        else {
            # If ID is not a host, rename all refs to it in the same namespace
            _member_rename($store->{namespace}, "\@$store->{key}", "\@$newname", $options);
        }
    }
    
    #finally, rename the actual object. This does a txn_commit also.
    $store->rename($newname, $options->{log}, $options->{user});
    delete $parents_map_cache{$store->{namespace}}; # Invalidate
    return wantarray ? (1, $store->mtime()) : 1;
}

=item I<delete($id, \%options)> - Deletes a HostDB Object

STRING $id - Id of HostDB Object.

HASHREF \%options - Mandatory options for set() are mandatory for delete() also.

=cut

sub delete {
    my ($id, $options) = @_;
    $logger->logconfess("4001: Provide a user name.") if (! exists $options->{user});
    if (! can_modify($id, $options->{user})) {
        $logger->logconfess("4033: User $options->{user} does not have write permission on $id.");
    }
    $logger->logconfess("4001: Provide a commit message.") if (! exists $options->{log});
    my $store = HostDB::FileStore->new($id, $options);
    $store->_init_git({user => $options->{user}});
    $store->{_git}->txn_begin();

    # Following logic is similar to that in rename()
    if (exists $store->{key} && $store->{id} eq "$store->{namespace}/$store->{key}") {
        if ($store->{namespace} eq 'hosts') {
            my $ndir = HostDB::FileStore->new("");
            foreach my $namespace ($ndir->get()) {
                next if ($namespace eq 'hosts');
                _member_delete($namespace, $store->{key}, $options);
            }
        }
        else {
            _member_delete($store->{namespace}, "\@$store->{key}", $options);
        }
    }
    $store->delete($options->{log}, $options->{user});
    delete $parents_map_cache{$store->{namespace}}; # Invalidate

    return 1;
}

1;

__END__

=back

=head1 ERROR CODES

=over 8

=item 4000   => 'Bad request'

4001   => 'Required parameter missing'

4002   => 'Target already exists Unable to rename'

=item 4010   => 'Unauthorized'

4011   => 'Invalid credentials'

4012   => 'Unable to parse session token'

4013   => 'Session token mismatch'

4014   => 'Session token expired'
    
=item 4030   => 'Forbidden'

4031   => 'HostDB is in read-only mode'

4032   => 'Writes are not allowed on resource'

4033   => 'Access denied to user'

4034   => 'Access denied for client IP'
    
=item 4040   => 'Not Found'

4041   => 'Resource does not exist'

4042   => 'Parent resource does not exist'
    
=item 4050   => 'Method not allowed'

4051   => 'Method not allowed on resource'
    
=item 5000   => 'Internal server error'

5001   => 'Parsing error'

5002   => 'Version control system error'

=item 5030   => 'Service unavailable'

5031   => 'Failed to read resource from data store'

5032   => 'Failed to create/modify resource in data store'

5033   => 'Failed to initialize versioning system'

5034   => 'Failed to acquire write lock'

=back

=head1 EXAMPLES
