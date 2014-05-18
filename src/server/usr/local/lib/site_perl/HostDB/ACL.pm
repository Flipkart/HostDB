#!/usr/bin/perl
package HostDB::ACL;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(can_modify);

use strict;
use HostDB::Shared qw( $logger );
use HostDB::FileStore;
use HostDB::Auth::LDAP;
use Data::Dumper;
use YAML::Syck;

my %meta_info = (
    members => 1,
    perms   => 1,
);

sub _get_acl {
    my ($namespace, $key) = @_;
    $logger->debug("$namespace:$key");
    $key = '.default' if (! defined $key);
    my $id = "$namespace/$key/perms";
    my $store = HostDB::FileStore->new($id);
    my $resp;
    eval {
        $resp = $store->get();
    };
    if ($@ or !defined $resp) {
        return;
    }
    
    my $perms = Load($resp) or $logger->logconfess("5001: Unable to load YAML: $id");
    $logger->debug(sub { Dumper $perms});
    return $perms;
}

sub can_modify {
    # Check in user permissions - first in key specific and then in namespace level
    my ($id, $user) = @_;
    
    $id =~ s/\/+$//; # remove / at end
    $id =~ s/^\/+//; # remove / at start
    
    my ($namespace, $key, $resource) = split '/', $id;
    $resource = 'data' if (! defined $resource or !exists $meta_info{$resource});
    
    $logger->logconfess('4051: Cannot check permissions outside a namespace') if (! defined $namespace);
    $logger->logconfess('4001: Invalid username') if (!defined $user || $user =~ /^\s*$/);
    $logger->debug("$resource:$user:$namespace:$key");
    
    my $perms;
    my @groups;

    # First check key specific ACL if key is defined.
    if (defined $key) {
        $perms = _get_acl($namespace, $key);
        return 1 if (exists $perms->{$user}->{$resource} && $perms->{$user}->{$resource} eq 'RW');
        return 0 if (exists $perms->{$user}->{$resource} && $perms->{$user}->{$resource} eq 'RO');
        @groups = HostDB::Auth::LDAP::groups($user);
        foreach (@groups) {
            return 1 if (exists $perms->{$_}->{$resource} && $perms->{$_}->{$resource} eq 'RW');
        }
        foreach (@groups) {
            return 0 if (exists $perms->{$_}->{$resource} && $perms->{$_}->{$resource} eq 'RO');
        }
    }

    # If there is no key specific ACL, check in namespace level.
    $perms  = _get_acl($namespace);
    return 1 if (exists $perms->{$user}->{$resource} && $perms->{$user}->{$resource} eq 'RW');
    return 0 if (exists $perms->{$user}->{$resource} && $perms->{$user}->{$resource} eq 'RO');
    @groups = HostDB::Auth::LDAP::groups($user) if ! @groups;
    foreach (@groups) {
        return 1 if (exists $perms->{$_}->{$resource} && $perms->{$_}->{$resource} eq 'RW');
    }
    foreach (@groups) {
        return 0 if (exists $perms->{$_}->{$resource} && $perms->{$_}->{$resource} eq 'RO');
    }

    return 0;
}

1;

