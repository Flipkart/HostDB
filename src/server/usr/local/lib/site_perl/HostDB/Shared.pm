#!/usr/bin/perl
package HostDB::Shared;

use strict;
use YAML::Syck;
use Log::Log4perl;
use Data::Dumper;
eval {
    require KeyDB::Client;
    KeyDB::Client->import();
};
my $use_keydb = $@ ? 0 : 1;

require Exporter;
use base qw(Exporter);
our @EXPORT_OK = qw(&load_conf &get_conf $logger);

my $conf;
our $logger;

# Try loading conf from default location
eval { load_conf('/etc/hostdb/server_conf.yaml') };

sub get_conf {
    my $param = shift;
    defined $conf or load_conf();
    my $val = $conf;
    foreach (split /\./, $param) {
        return undef if (! exists $val->{$_});
        $val = $val->{$_};
    }
    return ref($val) ? undef : $val;
}

sub load_conf {
    my $conf_file = shift;

    #print "Loading conf from $conf_file\n";
    $conf = LoadFile($conf_file);
    
    Log::Log4perl->init($conf->{logger}->{conf_file});
    $logger = Log::Log4perl->get_logger('HostDB');

    $logger->info("Loaded config from $conf_file");
    $logger->debug(sub { Dumper $conf });
    if ($use_keydb && exists $conf->{session}->{cipher_key_keydb_bucket} && $conf->{session}->{cipher_key_keydb_key}) {
        $conf->{session}->{cipher_key} = keydbgetkey($conf->{session}->{cipher_key_keydb_bucket}, $conf->{session}->{cipher_key_keydb_key});
    }
    else {
        open(my $fh, "<", $conf->{session}->{cipher_key_file})
            or $logger->logconfess("5000: Unable to open $conf->{session}->{cipher_key_file}. $!");
        flock($fh, 1);
        $conf->{session}->{cipher_key} = readline $fh;
        close $fh;
        chomp $conf->{session}->{cipher_key};
    }
}

1;

