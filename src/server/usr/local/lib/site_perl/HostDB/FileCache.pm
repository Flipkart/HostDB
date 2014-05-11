#!/usr/bin/perl
# A simple file based global cache.
# Written to replace the per-process cache of parents map.
# But this is much slower due to added overhead of
# serialization and desetialization of objects stored.
package HostDB::FileCache;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(cache_exists cache_get cache_set cache_delete);

use strict;
use HostDB::Shared qw( $logger &get_conf );
use Data::Dumper;

my $cache_dir = get_conf('server.cache_dir') || '/tmp/hostdb';

if (-d $cache_dir) {
    # invalidate more than 1 hr old cache entries.
    opendir(my $dh, $cache_dir)
	|| $logger->logconfess("5031: Can't read directory: $cache_dir. $!");
    my @files = sort grep { ! /^\./ } readdir($dh);
    closedir $dh;
    my $exp = time - 3600;
    foreach my $key (@files) {
        if ((stat("$cache_dir/$key"))[9] < $exp) {
            unlink "$cache_dir/$key" or $logger->logconfess("5032: Can't delete file: $cache_dir/$key. $!");
        }
    }
}
else {
    mkdir $cache_dir or $logger->logconfess("5032: Can't create dir: $cache_dir. $!");
}

sub cache_exists {
    my $key = shift;
    return -e "$cache_dir/$key";
}

sub cache_get {
    my $key = shift;
    return unless cache_exists($key);
    open (my $fh, "<", "$cache_dir/$key") or $logger->logconfess("5031: Can't read file $cache_dir/$key. $!");
    flock($fh, 1);
    my $value = do { local $/; <$fh> };
    close $fh;
    return $value;
}

sub cache_set {
    my ($key, $value) = @_;
    my $fh;
    if (cache_exists($key)) {
        open($fh, "+<", "$cache_dir/$key") or $logger->logconfess("5032: Can't write to file: $cache_dir/$key. $!");
        flock($fh, 2);
        seek($fh, 0, 0); truncate($fh, 0);
    }
    else {
        open ($fh, ">", "$cache_dir/$key") or $logger->logconfess("5032: Can't create file: $cache_dir/$key. $!");
        flock($fh, 2);
    }

    print {$fh} $value;
    close $fh;
    return 1;
}

sub cache_delete {
    my $key = shift;
    return 1 unless cache_exists($key);
    unlink "$cache_dir/$key" or $logger->logconfess("5032: Can't delete file: $cache_dir/$key. $!");
    return 1;
}

1;

