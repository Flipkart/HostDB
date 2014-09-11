#!/usr/bin/perl
package HostDB::Auth::LDAP;

use strict;
use HostDB::Shared qw( &get_conf $logger );
use Data::Dumper;
use Net::LDAP;

sub auth {
    # IMP: Do not confess/cluck in this function. Call trace will contain the password.
    my ($user, $pass) = @_;
    $user or $logger->logcroak("4001: Missing parameter - username");
    my $server = get_conf('auth.ldaps.server') or $logger->logdie("5003: Config auth.ldaps.server not set");
    my $port = get_conf('auth.ldaps.port') || 636;
    my $users_dn = get_conf('auth.ldaps.users_dn') or $logger->logdie("5003: Config auth.ldaps.users_dn not set");
    my $user_dn = "uid=$user,$users_dn";
    my $ldap = Net::LDAP->new("ldaps://$server", port => $port) or $logger->logdie("5030: Could not create LDAP object because:\n$!");
    my $msg = $ldap->bind($user_dn, password => $pass);
    #my $ldapSearch = $ldap->search(base => $LDAP_BASE, filter => "uid=$user");
    return ($msg->is_error) ? 0 : 1;
}

sub groups {
    my $user = shift or $logger->logcroak("4001: Missing parameter - username");
    #my @groups = map { chomp; $_ } `/usr/bin/getent group | grep -E "(:| |,|)$user(,| |\$)" | cut -d: -f1`; # improve
    my @groups = map { chomp; $_ } `id $user | tr ' ' "\n" | grep "^groups=" | cut -f2 -d= | tr ',' "\n" | cut -f2 -d"(" | cut -f1 -d")"`;
    return @groups;
}

1;
