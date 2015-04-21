#!/usr/bin/perl

=pod

=head1 NAME

HostDB::FileStore - Implements HostDB objects on top of text files and directories

=head1 SYNOPSIS

use HostDB::FileStore;

my $hdb = HostDB::FileStore->new($id);

my $output = $hdb->get([$revision_id]);

my $success = $hdb->set($value, $log, $user);

my $success = $hdb->rename($newname, $log, $user);

my $success = $hdb->delete($log, $user);

my $revs = $hdb->revisions([$limit = 50]);

my $blame = $hdb->blame();

my $mtime = $hdb->mtime();

=cut

package HostDB::FileStore;

use strict;
use HostDB::Shared qw( &get_conf $logger );
use Data::Dumper;
use YAML::Syck;
use HostDB::Git;

my $NAMESPACE_DIR = get_conf('server.namespace_dir');

# Additional information related to a key
# This hash describes where is stored and in what format
my %meta_info = (
    members => {
        file_spec    => 'NAMESPACE_DIR/NAMESPACE/.members/KEY',
        content_type => 'list',
    },
    perms   => {
        file_spec    => 'NAMESPACE_DIR/NAMESPACE/.perms/KEY',
        content_type => 'yaml',
    },
);

# Sub to parse a hostdb object ID
# Gets all info required to locate and work on the object
sub _parse_resource_id {
    my ($id) = @_;
    my %parts;
    # If resource ID is empty, return namespace directory
    $parts{_file} = $NAMESPACE_DIR;
    $parts{_content_type} = 'files';
    my @id_parts = split /\//, $id;
    if (@id_parts) {
        # First part is always namespace
        # e.g. hosts
        $parts{namespace} = shift @id_parts;
        $parts{_file} .= '/' . $parts{namespace};
        $parts{_content_type} = 'files';
    }
    if (@id_parts) {
        # Second part is always key
        # hosts/host1.flipkart.com
        $parts{key} = shift @id_parts;
        $parts{_file} .= '/' . $parts{key};
        $parts{_content_type} = 'yaml';
    }
    if (@id_parts) {
        # Third is a meta property of a key or an object inside a key
        my $resource = shift @id_parts;
        if (exists $meta_info{$resource}) {
            $parts{_key_file} = $parts{_file};
            $parts{meta_info} = $resource;
            $parts{_file} = $meta_info{$resource}->{file_spec};
            $parts{_file} =~ s/NAMESPACE_DIR/$NAMESPACE_DIR/;
            $parts{_file} =~ s/NAMESPACE/$parts{namespace}/;
            $parts{_file} =~ s/KEY/$parts{key}/;
            $parts{_content_type} = $meta_info{$resource}->{content_type};
        }
        else {
            # If it is not meta prop, it is a record inside key. unshift it.
            unshift @id_parts, $resource;
        }
    }
    if (@id_parts) {
        $parts{record} = join "/", @id_parts;
        $parts{_content_type} = $parts{_content_type} . '/part';
    }
    return \%parts;
};

# Sub to initialize git object.
# Sets $self->{versioned} and $self->{_git} if successful.
sub _init_git {
    my ($self, $args_ref) = @_;
    
    return $self->{versioned} if (!exists $args_ref->{user});
    
    if (!defined $self->{versioned} || (exists $args_ref->{force} && $args_ref->{force})) {
        $self->{_git} = HostDB::Git->new($NAMESPACE_DIR, $args_ref->{user});
    }
    $self->{versioned} = 1;
};

=head1 CONSTRUCTOR

=over 8

=item I<HostDB::FileStore-E<gt>new($id, \%options)> - Returns a blessed perl object to represent a HostDB Object

STRING $id - ID to represent the HostDB Object

HASHREF \%options may contain these attributes:

=over 8

enable_vcs      => Boolean to enable/disable versioning. Default is true.

=back

Returned object will have these public attributes:

=over 8

id              => ID of the HostDB object

namespace       => Namespace if exists in ID

key             => Key if exists in ID

meta_info       => Name of meta info if ID reprents one. Either "members" or "perms"

record          => ID represents this sub-object inside the file of main object

mtime           => Last modified time of the object

versioned       => 1 if versioning is enabled (git object is created), 
                   
                   0 if versioning is forcefully disabled,
                   
                   undef if neither enabled nor forcefully disabled

=back

Private attributes (Do not use these in your code):

_file           => File representing/containing the value of object

_content_type   => Type of the value. Either "files", "list", "yaml", "list/part" or "yaml/part"

_key_file       => If ID is for meta info, this will contain location of file representing actual object

_git            => Reference to HostDB::Git object.

=back

=head1 METHODS

=over 8

=cut

sub new {
    my ($class, $id, $options) = @_;
    $id =~ s/^\/+//; # Remove extra slashes
    $id =~ s/\/+$//;
    my $self = {
        id           => $id,
        versioned    => (defined $options &&
                         exists $options->{enable_vcs} &&
                         !$options->{enable_vcs}) ? 0 : undef,
        _git         => undef, # create only when required
    };
    my $parts = _parse_resource_id($id);
    foreach (keys %{$parts}) {
        $self->{$_} = $parts->{$_};
    }
    
    $logger->debug("FileStore object for $id created. Caller: " . join(':', caller));
    #$logger->debug(sub {Dumper $self});
    
    bless $self;
}

=item I<get([$revision_id])> - Returns the value stored in the HostDB Object

Returns a string in SCALAR context. In LIST context, returns a array of strings if the value is logically a list.

STRING $revision_id - Optional. If specified, tries to get a revision of value identified by "$revision_id".

=cut

sub get {
    my ($self, $revision) = @_;
    my $file_content = '';
    my $output = '';
    # first read the whole file/dir.
    if (-d $self->{_file}) {
        my @files;
        if ($revision) {
            $self->_init_git({user => "dummy"});
            my (undef, $out) = $self->{_git}->run('ls-tree', '--name-only', $revision, "$self->{_file}/");
            foreach my $file (split /\R/, $out) {
                $file =~ s/^.*\///;
                next if ($file =~ /^\./);
                push @files, $file;
            }
        }
        else {
            opendir(my $dh, $self->{_file})
                || $logger->logconfess("5031: Can't read directory: $self->{_file}. $!");
            @files = sort grep { ! /^\./ } readdir($dh);
            closedir $dh;
        }
        $file_content = join "\n", @files;
    }
    elsif (-f $self->{_file}) {
        if ($revision) {
            $self->_init_git({user => "dummy"});
            my $file = $self->{_file};
            $file =~ s/$NAMESPACE_DIR\///;
            my (undef, $out) = $self->{_git}->run('show', "$revision:$file");
            $file_content = $out;
        }
        else {
            open (my $fh, "<", $self->{_file}) or $logger->logconfess("5031: Can't read file $self->{_file}. $!");
            flock($fh, 1);
            $file_content = do { local $/; <$fh> };
            close $fh;
        }
    }
    else { # File doesn't exist
        # If ID is for a meta property of key, just return empty if key exists. Else die.
        return if ($self->{meta_info} && !$self->{record} && -e $self->{_key_file});
        $logger->logconfess("4041: Resource $self->{id} does not exist.");
    }
    
    # Then go inside the file/dir if needed
    if ($self->{_content_type} eq 'yaml/part') {
        my $data = Load($file_content);
        if (ref $data ne 'HASH') {
            $logger->logconfess("5001: Parsing error on parent resource.");
        }
        foreach (split /\//, $self->{record}) {
            if (ref $data ne 'HASH' || !exists $data->{$_}) {
                $logger->logconfess("4041: Resource $self->{id} does not exist.");
            }
            $data = $data->{$_};
        }
        $output = Dump($data);
    }
    elsif ($self->{_content_type} eq 'list/part') {
        foreach (split /\R/, $file_content) {
            if ($_ eq $self->{record}) {
                $output = $self->{record};
                last;
            }
        }
        if (! $output) {
            $logger->logconfess("4041: Resource $self->{id} does not exist.")
        }
    }
    else {
        $output = $file_content;
    }
    
    # If content is list and caller is in list context, return list. Else return scalar.
    return (wantarray && $self->{_content_type} ~~ ['list', 'files']) ? split(/\R/, $output) : $output;
}

=item I<set($value, $log, $user)> - Create or modify a HostDB Object

Overwrites existing value if any. Returns 1 if successful.

STRING $value - Value to set the object to.

STRING $log, $user - Commit the change to revision control with author "user" and commit message "log".

=cut

sub set {
    my ($self, $value, $log, $user) = @_;
    $logger->logcroak("4001: Missing commit message") if (!$log || $log =~ /^\s*$/);
    my $data = {};
    my $output = '';
    if (! -d "$NAMESPACE_DIR/$self->{namespace}") {
        $logger->logconfess("4042: Resource $self->{namespace} does not exist.");
    }
    if (! $self->{key}) {
        # If key is not defined, then ID is a namespace
        # as of now, no allowed operation requires a 'set' on directory 
        $logger->logconfess("4051: Writes are not allowed on $self->{id}");  
    }
    if ($self->{meta_info}) {
        if (! -f $self->{_key_file}) {
            # Trying to write inside non-existant key
            $logger->logconfess("4042: Parent resource $self->{namespace}/$self->{key} does not exist.");
        }
    }
    elsif ($self->{record} && ! -f $self->{_file}) {
        # Trying to write inside non-existant key
        $logger->logconfess("4042: Parent resource $self->{namespace}/$self->{key} does not exist.");
    }

    defined $self->{versioned} || $self->_init_git({ user => $user });
    $self->{versioned} && $self->{_git}->txn_begin();

    if (! -e $self->{_file}) {
        # New file needs to be created to store object
        open (my $fh, ">", $self->{_file}) or $logger->logconfess("5032: Can't create file: $self->{_file}. $!");
        close $fh;
        $self->{versioned} && $self->{_git}->run('add', $self->{_file});
    }
    
    open(my $fh, "+<", $self->{_file}) or $logger->logconfess("5032: Can't write to file: $self->{_file}. $!");
    flock($fh, 2);
    if ($self->{_content_type} eq 'yaml/part') {
        $output = do { local $/; <$fh> };
        my $data = Load($output) || {};
        my $d = $data;
        my @parts = split /\//, $self->{record};
        $logger->debug(sub {Dumper \@parts});
        my $last = pop @parts;
        foreach (@parts) {
            if (! exists $d->{$_}) {
                #$d->{$_} = (defined $value) ? {} : [];
                $logger->logconfess("4042: Parent resource does not exist.");
            }
            $d = $d->{$_};
        }
        $logger->debug(sub {Dumper $d});
        if (ref $d eq 'HASH') {
            my $v = Load($value);
            $d->{$last} = $v;
        }
        elsif (ref $d eq 'ARRAY') {
            push @{$d}, $last;
        }
        $logger->debug(sub {Dumper $data});
        $output = Dump($data);
    }
    elsif ($self->{_content_type} eq 'list/part') {
        my @records = ();
        while (<$fh>) {
            chomp;
            if ($_ eq $self->{record}) {
                close $fh;
                return 1;
            }
            push @records, $_;
        }
        push @records, $self->{record};
        $output = join "\n", @records;
    }
    elsif ($self->{_content_type} eq 'yaml') {
        # Validate if input is supposed to be yaml
        my $v = Load($value);
        $output = Dump($v);
    }
    else {
        $output = $value;
    }
    $logger->debug($output);
    seek($fh, 0, 0); truncate($fh, 0);
    print {$fh} $output;
    close $fh;
    $self->{versioned} && $self->{_git}->txn_commit($log);
    #$logger->debug($out);
    $self->{mtime} = (stat($self->{_file}))[9];
    return 1;
}

=item I<rename($newname[, $log, $user])> - Renames a HostDB Object

Fails if target object exists.

STRING $newname - new name for the object.

STRING $log, $user - Optional. If specified, will commit the change to revision control with author "user" and commit message "log".

=cut

sub rename {
    my ($self, $newname, $log, $user) = @_;
    
    $logger->debug(sub {Dumper $self});
    
    $logger->logconfess("4001: Provide new name for the resource.") if (! defined $newname);
    my $data = {};
    my $output = '';
    if (! -e $self->{_file}) {
        $logger->logconfess("4042: Resource $self->{id} does not exist.");
    }
    if (! -d "$NAMESPACE_DIR/$self->{namespace}") {
        $logger->logconfess("4042: Resource $self->{namespace} does not exist.");
    }
    if (! $self->{key}) {
        # as of now, no allowed operation requires a 'rename' on directory 
        $logger->logconfess("4051: Writes are not allowed on $self->{id}");  
    }
    if ($self->{meta_info} && !$self->{record}) {
        $logger->logconfess("4051: Operation not allowed on $self->{id}");
    }
    
    defined $self->{versioned} || $self->_init_git({ user => $user });
    $self->{versioned} && $self->{_git}->txn_begin();

    if ($self->{_content_type} eq 'yaml/part') {
        open(my $fh, "+<", $self->{_file}) or $logger->logconfess("5032: Can't write to file: $self->{_file}. $!");
        flock($fh, 2);
        $output = do { local $/; <$fh> };
        my $data = Load($output);
        my $d = $data;
        my @parts = split /\//, $self->{record};
        my $last = pop @parts;
        foreach (@parts) {
            if (! exists $d->{$_}) {
                $logger->logconfess("4042: Resource $self->{id} does not exist.");
            }
            $d = $d->{$_};
        }
        if (ref $d eq 'HASH') {
            if (! exists $d->{$last}) {
                $logger->logconfess("4041: Resource $self->{id} does not exist.");
            }
            my $s = Dumper $d->{$last};
            $s =~ s{\A\$VAR\d+\s*=\s*}{};
            if (exists $d->{$newname}) {
                $logger->logconfess("4002: Target already exists");
            }
            $d->{$newname} = eval $s;
            delete $d->{$last};
        }
        elsif (ref $d eq 'ARRAY') {
            for (my $i=0; $i < @{$d}; $i++) {
                if (${$d}[$i] eq $last) {
                    ${$d}[$i] = $newname;
                }
            }
        }
        $output = Dump($data);
        $logger->debug($output);
        seek($fh, 0, 0); truncate($fh, 0);
        print {$fh} $output;
        close $fh;
    }
    elsif ($self->{_content_type} eq 'list/part') {
        open(my $fh, "+<", $self->{_file}) or $logger->logconfess("5032: Can't write to file: $self->{_file}. $!");
        flock($fh, 2);
	my $r = do { local $/; <$fh> };
	my @records = split /\R/, $r;
        my $modified = 0;
        for (my $i=0; $i < scalar @records; $i++) {
            if ($records[$i] eq $newname) {
                $logger->logconfess("4002: Target already exists");
            }
            if ($records[$i] eq $self->{record}) {
                $records[$i] = $newname;
                $modified = 1;
            }
        }
        if (! $modified) {
            $logger->logconfess("4041: Resource $self->{id} does not exist.");
        }
        $output = join "\n", @records;
        $logger->debug($output);
        seek($fh, 0, 0); truncate($fh, 0);
        print {$fh} $output;
        close $fh;
    }
    else {
        my $newfile = $self->{_file};
        $newfile =~ s/$self->{key}/$newname/;
        if (-e $newfile) {
            $logger->logconfess("4002: Target already exists");
        }
        $logger->debug("file rename $self->{_file}, $newfile");
        rename $self->{_file}, $newfile or $logger->logconfess("Unable to rename $!");
        my %renamed;
        $renamed{$self->{_file}} = $newfile;
        # Rename files where meta info is stored
        foreach (keys %meta_info) {
            my $oldfile = $meta_info{$_}->{file_spec};
            $oldfile =~ s/NAMESPACE_DIR/$NAMESPACE_DIR/;
            $oldfile =~ s/NAMESPACE/$self->{namespace}/;
            $oldfile =~ s/KEY/$self->{key}/;
            $newfile = $oldfile;
            $newfile =~ s/$self->{key}/$newname/;
            if (-e $oldfile) {
                $logger->debug("file rename $oldfile, $newfile");
                rename $oldfile, $newfile or $logger->logconfess("Unable to rename $!");
                $renamed{$oldfile} = $newfile;
            }
        }
        $logger->debug(sub { "Rename:" . Dumper \%renamed});
        if ($self->{versioned}) {
            my $rc;
            $rc = $self->{_git}->run('add', values %renamed);
            $rc = $self->{_git}->run('rm', keys %renamed);
        }
    }
    $self->{versioned} && $self->{_git}->txn_commit($log);
    return 1;
}

=item I<delete([$log, $user])> - Deletes the HostDB Object

Returns 1 if successful.

STRING $log, $user - Optional. If specified, will commit the change to revision control with author "user" and commit message "log".

=cut

sub delete {
    my ($self, $log, $user) = @_;
    my $output = '';
    if (! -e $self->{_file}) {
        $logger->logconfess("4042: File doesn't exist: $self->{_file}");
    }
    if (! -d "$NAMESPACE_DIR/$self->{namespace}") {
        $logger->logconfess("4042: Resource $self->{namespace} does not exist.");
    }
    if (! $self->{key}) {
        # as of now, no allowed operation requires a 'delete' on directory 
        $logger->logconfess("4051: Writes are not allowed on $self->{id}");  
    }
    if ($self->{meta_info} && !$self->{record}) {
        $logger->logconfess("4051: Operation not allowed on $self->{id}");
    }
    
    defined $self->{versioned} || $self->_init_git({ user => $user });
    $self->{versioned} && $self->{_git}->txn_begin();
    if ($self->{_content_type} eq 'yaml/part') {
        open(my $fh, "+<", $self->{_file}) or $logger->logconfess("5032: Can't write to file: $self->{_file}. $!");
        flock($fh, 2);
        $output = do { local $/; <$fh> };
        my $data = Load($output);
        my $d = $data;
        my @parts = split /\//, $self->{record};
        my $last = pop @parts;
        foreach (@parts) {
            if (! exists $data->{$_}) {
                $logger->logconfess("4042: Resource $self->{id} does not exist.");
            }
            $d = $d->{$_};
        }
        if (ref $d eq 'HASH') {
            if (! exists $d->{$last}) {
                $logger->logconfess("4041: Resource $self->{id} does not exist.");
            }
            delete $d->{$last};
        }
        elsif (ref $d eq 'ARRAY') {
            my @items = ();
            while (my $item = shift @{$d}) {
                if ($item eq $last) {
                    last;
                }
                push @items, $_;
            }
            unshift @{$d}, @items;
        }
        $output = Dump($data);
        $logger->debug($output);
        seek($fh, 0, 0); truncate($fh, 0);
        print {$fh} $output;
        close $fh;
    }
    elsif ($self->{_content_type} eq 'list/part') {
        open(my $fh, "+<", $self->{_file}) or $logger->logconfess("5032: Can't write to file: $self->{_file}. $!");
        flock($fh, 2);
        my @records = ();
        while (<$fh>) {
            chomp;
            next if ($_ eq $self->{record});
            push @records, $_;
        }
        $output = join "\n", @records;
        $logger->debug($output);
        seek($fh, 0, 0); truncate($fh, 0);
        print {$fh} $output;
        close $fh;
    }
    else {
        my @files = ($self->{_file});
        foreach (keys %meta_info) {
            my $file = $meta_info{$_}->{file_spec};
            $file =~ s/NAMESPACE_DIR/$NAMESPACE_DIR/;
            $file =~ s/NAMESPACE/$self->{namespace}/;
            $file =~ s/KEY/$self->{key}/;
            if (-e $file) {
                push @files, $file;
            }
        }
        $logger->debug(sub {"Delete:\n" . Dumper \@files});
        if ($self->{versioned}) {
            my $rc;
            $rc = $self->{_git}->run('rm', @files);
        }
        else {
            unlink @files;
        }
    }
    $self->{versioned} && $self->{_git}->txn_commit($log);
}

=item I<revisions([$limit = 50])> - Returns recent revisions the HostDB Object as a list

In SCALAR context, returns a string with revisions separated by newline.

INTEGER $limit - Optional. If specified, returns last "$limit" revisions. Defaults to 50.

=cut

sub revisions {
    my ($self, $limit) = @_;
    my $out = '';
    if (! -e $self->{_file}) {
        $logger->logconfess("4041: Resource $self->{id} does not exist") if (!exists $self->{meta_info});
    }
    else {
        $self->_init_git({ user => 'dummy' });
        $limit = 50 if (! $limit);
        my @cmd = ('log', '--pretty=format:%h - %an, %ai : %s', '-' . $limit, $self->{_file});
        my $rc;
        ($rc, $out) = $self->{_git}->run(@cmd);
        $logger->logconfess("5002: git @cmd failed with code: $rc") if ($rc);
        chomp $out;
    }
    return wantarray ? split(/\R/, $out) : $out;
}

=item I<blame()> - Returns git blame of value represented by HostDB Object

Highly Git specific. Usage is discouraged.

=cut

sub blame {
    my ($self) = @_;
    $logger->logconfess("4041: Resource $self->{id} does not exist") if (! -e $self->{_file});
    $logger->logconfess("4051: Can't do blame on a directory") if (-d $self->{_file});
    $self->_init_git({ user => 'dummy' });
    my ($rc, $out) = $self->{_git}->run('blame', $self->{_file});
    $logger->logconfess("5002: git blame $self->{_file} failed") if ($rc);
    return $out;
}

=item I<mtime()> - Returns last modified time of HostDB Object

Time is specified as number of seconds since Epoch.

Also sets an attribute 'mtime' in the object.

=cut

sub mtime {
    my ($self) = @_;
    $self->{mtime} = (-e $self->{_file}) ? (stat($self->{_file}))[9] : undef;
    return $self->{mtime};
}

1;

__END__

=back

=head1 EXAMPLES

=head1 CAVEAT

This module leaks internal implementation and needs to be fixed.

