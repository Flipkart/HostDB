#!/usr/bin/perl
package HostDB::Shared;

use strict;
use YAML::Syck;
use Log::Log4perl;
use Data::Dumper;
require Exporter;
use base qw(Exporter);
our @EXPORT_OK = qw(&read_config $conf $logger);

our ($conf, $logger);
my $HOSTDB_CONF = '/etc/hostdb/server_conf.yaml';

read_config();

sub read_config {
    $conf = LoadFile($HOSTDB_CONF);
    
    Log::Log4perl->init($conf->{LOGGER_CONF_FILE});
    $logger = Log::Log4perl->get_logger('HostDB');

    $logger->info("Loaded config from $HOSTDB_CONF");
    $logger->debug(sub { Dumper $conf });

    open(my $fh, "<", $conf->{SESSION_CIPHER_KEY_FILE})
        or $logger->logconfess("5000: Unable to open $conf->{SESSION_CIPHER_KEY_FILE}. $!");
    flock($fh, 1);
    $conf->{SESSION_CIPHER_KEY} = <$fh>;
    close $fh;
    chomp $conf->{SESSION_CIPHER_KEY};
}

1;

