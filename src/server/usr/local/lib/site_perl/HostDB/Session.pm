#!/usr/bin/perl
package HostDB::Session;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(generate_session validate_credentials validate_session);

use strict;
use HostDB::Shared qw($conf $logger);
use Data::Dumper;
use Log::Log4perl;
use Crypt::CBC;
use Net::LDAP;
use YAML::Syck;

my $APP_USERS_CONF_FILE = $conf->{APP_USERS_CONF_FILE};

my $cipher = Crypt::CBC->new (
    -key    => $conf->{SESSION_CIPHER_KEY},
    -cipher => "Blowfish",
);

sub generate_session {
    my ($user, $ip) = @_;
    return $cipher->encrypt_hex("$user:$ip:" . time);
}

sub validate_credentials {
    # IMP: Do not confess/cluck in this function. Call trace will contain the password.
    my ($user, $pass, $ip) = @_;
    my $clients = LoadFile($APP_USERS_CONF_FILE) or $logger->logdie("5001: Unable to load YAML in $APP_USERS_CONF_FILE");
    # Check if user is a registered system user.
    if (exists $clients->{$user}) {
        my %allowed_ips = map {$_ => 1} @{$clients->{$user}->{allow}};
        my $md5sum = `echo "$pass" | /usr/bin/md5sum - | cut -d' ' -f1`;
        chomp $md5sum;
        if ($md5sum ne $clients->{$user}->{password}) {
            $logger->logdie("4011: Invalid Credentials");
        }
        if (!exists $allowed_ips{$ip}) {
            $logger->logdie("4034: $user is not allowed to login from this IP");
        }
        return 1; # success
    }
    # Else, do LDAP auth
    my $LDAP_SERVER = $conf->{LDAP_SERVER};
    my $LDAP_PORT   = $conf->{LDAP_PORT};
    my $LDAP_BASE   = $conf->{LDAP_BASE};
    my $userDN      = 'uid='.$user.','.$LDAP_BASE;
    my $ldap = Net::LDAP->new($LDAP_SERVER, port => $LDAP_PORT) or $logger->logdie("5030: Could not create LDAP object because:\n$!");
    my $ldapMsg = $ldap->bind($userDN, password => $pass);
    my $ldapSearch = $ldap->search(base => $LDAP_BASE, filter => "uid=$user");
    if($ldapMsg->is_error) {
        $logger->logdie("4011: Invalid Credentials"); # failure
    }
    return 1;  # success
}

sub validate_session {
    my ($digest, $ip) = @_;
    my $session;
    eval { $session = $cipher->decrypt_hex($digest) };
    $logger->debug("decrypted session data: $session");
    if ($@) {
        $logger->logconfess("4012: Session token seems to be corrupted $@");
    }
    my $clients = LoadFile($APP_USERS_CONF_FILE) or $logger->logconfess("5001: Unable to load YAML in $APP_USERS_CONF_FILE");
    my ($s_user, $s_ip, $s_time);
    if ($session =~ /(.*):([0-9.]+):(\d+)/) {
        $s_user = $1;
        $s_ip = $2;
        $s_time = $3;
        if ($ip ne $s_ip) {
            $logger->logconfess("4013: Session token IP mismatch");
        }
        if (!exists $clients->{$s_user} && (time - $s_time) > 86400 ) { # Check expiry only for LDAP user cookies.
            $logger->logconfess("4014: Session token expired");
        }
        return $s_user;  # valid cookie
    }
    # Couldn't parse session token
    $logger->logconfess("4012: Session token seems to be corrupted");
}

1;
