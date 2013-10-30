#!/usr/bin/perl
package HostDB::ACL;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(can_modify);

use strict;
use HostDB::Shared qw($logger);
use HostDB::FileStore;
use Data::Dumper;
use Log::Log4perl;
use YAML::Syck;

my %meta_info = (
    members => 1,
    perms   => 1,
);

sub _get_acl {
    my ($user, $namespace, $key) = @_;
    $logger->debug("$user:$namespace:$key");
    $key = '.global' if (! defined $key);
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
    if (exists $perms->{$user}) {
        return $perms->{$user};
    }
    return;   #undef
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
    
    my $view;
    my @groups;

    # First check key specific ACL if key is defined.
    if (defined $key) {
        $view = _get_acl($user, $namespace, $key);
        return 1 if (exists $view->{$resource} && $view->{$resource} eq 'RW');
        return 0 if (exists $view->{$resource} && $view->{$resource} eq 'RO');
        @groups = split (/\n/, `/usr/bin/getent group | grep "\[^a-z\]$user\[^a-z\]" | cut -d: -f1`);  #improve
        foreach (@groups) {
            $view = _get_acl($_, $namespace, $key);
            return 1 if (exists $view->{$resource} && $view->{$resource} eq 'RW');
        }
        foreach (@groups) {
            $view = _get_acl($_, $namespace, $key);
            return 0 if (exists $view->{$resource} && $view->{$resource} eq 'RO');
        }
    }

    # If there is no key specific ACL, check in namespace level.
    $view  = _get_acl($user, $namespace);
    return 1 if (exists $view->{$resource} && $view->{$resource} eq 'RW');
    return 0 if (exists $view->{$resource} && $view->{$resource} eq 'RO');
    if (! @groups) {
        @groups = split (/\n/, `/usr/bin/getent group | grep "\[^a-z\]$user\[^a-z\]" | cut -d: -f1`);  #improve
    }
    foreach (@groups) {
        $view = _get_acl($_, $namespace);
        return 1 if (exists $view->{$resource} && $view->{$resource} eq 'RW');
    }
    foreach (@groups) {
        $view = _get_acl($_, $namespace);
        return 0 if (exists $view->{$resource} && $view->{$resource} eq 'RO');
    }

    return 0;
}

1;

