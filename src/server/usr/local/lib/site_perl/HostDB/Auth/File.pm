#!/usr/bin/perl
package HostDB::Auth::File;

use strict;
use HostDB::Shared qw( &get_conf $logger );
use Data::Dumper;
use YAML::Syck;
use NetAddr::IP;

# IMP: Do not confess/cluck in this module. Call trace will contain the password.
my $creds;

sub exists {
    my ($user) = @_;
    _get_creds();
    return exists $creds->{$user};
}

sub auth {
    my ($user, $pass) = @_;
    _get_creds();
    return 0 if ! exists $creds->{$user};
    my $md5sum = `echo -n '$pass' | /usr/bin/md5sum | cut -d' ' -f1`;
    chomp $md5sum;
    return ($md5sum eq $creds->{$user}->{password}) ? 1 : 0;
}

sub allowed {
    my ($user, $ip) = @_;
    _get_creds();
    return 0 if ! exists $creds->{$user};
    my $myip = NetAddr::IP->new($ip);
    foreach (@{$creds->{$user}->{allow}}) {
        my $range = NetAddr::IP->new($_);
        return 1 if $range->contains($myip);
    }
    return 0;
}

sub _get_creds {
    return if $creds;
    my $creds_file = get_conf('auth.file.creds_file') or $logger->logdie("5003: Config auth.file.creds_file not set");
    $creds = LoadFile($creds_file) or $logger->logdie("5001: Unable to load YAML in $creds_file");
}

1;
