#!/usr/bin/perl

use strict;
use HostDB::Shared qw(&load_conf &get_conf $logger);
use CGI::Fast;
use Data::Dumper;

# Don't do actual config read inside signal handler.
# Make signal handler as quick as possible!
my $got_hup = 0;
$SIG{HUP} = sub { $got_hup = 1 };

while (my $cgi = new CGI::Fast) {
    if ($got_hup) {
        load_conf();
        $got_hup = 0;
    }
    my $uri = $ENV{REQUEST_URI};

# Handle Healthshecks
    if (! -e "/var/www/hostdb/status.html") {
	print "Status: 404 Server status file missing\n\n";
        next;
    }
    if ($uri =~ /health\/ro$/) {
        print "Content-type: text/html\n\nOK\n";
        next;
    }
    if ($uri =~ /health\/rw$/) {
        if (get_conf('server.read_only') ~~ ['1', 'on']) {
    	    print "Status: 404 HostDB is in read-only mode\n\n";
        }
        else {
    	    print "Content-type: text/html\n\nOK\n";
        }
        next;
    }
    print "Status: 404 Unknown status check\n\n";
}

