#!/usr/bin/perl
package HostDB::Session;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(generate_session validate_credentials validate_session);

use strict;
use HostDB::Shared qw( &get_conf $logger );
use HostDB::Auth::File;
use HostDB::Auth::LDAP;
use Data::Dumper;
use Crypt::CBC;
use YAML::Syck;

my $cipher = Crypt::CBC->new (
    -key    => get_conf('session.cipher_key'),
    -cipher => "Blowfish",
);

sub generate_session {
    my ($user, $ip) = @_;
    return $cipher->encrypt_hex("$user:$ip:" . time);
}

sub validate_credentials {
    # IMP: Do not confess/cluck in this function. Call trace will contain the password.
    my ($user, $pass, $ip) = @_;
    if (HostDB::Auth::File::auth($user, $pass)) {
        if (HostDB::Auth::File::allowed($user, $ip)) {
            return 1;
        }
        else {
            $logger->logdie("4034: $user is not allowed to login from this IP");
        }
    }
    elsif (HostDB::Auth::LDAP::auth($user, $pass)) {
        return 1;
    }
    else {
        $logger->logdie("4011: Invalid Credentials");
    }
}

sub validate_session {
    my ($digest, $ip) = @_;
    my $session;
    eval { $session = $cipher->decrypt_hex($digest) };
    $@ and $logger->logconfess("4012: Session token seems to be corrupted $@");
    $logger->debug("decrypted session data: $session");
    if ($session =~ /(?<user>.*):(?<ip>[\d.]+):(?<time>\d+)/) {
        if ($ip ne $+{'ip'}) {
            $logger->logconfess("4013: Session token IP mismatch");
        }
        if (! HostDB::Auth::File::exists($+{'user'}) && (time - $+{'time'}) > 86400 ) { # Check expiry only for LDAP user cookies.
            $logger->logconfess("4014: Session token expired");
        }
        return $+{'user'};  # valid cookie
    }
    # Couldn't parse session token
    $logger->logconfess("4012: Session token seems to be corrupted");
}

1;
