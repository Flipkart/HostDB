#!/usr/bin/perl
# A simple shared object cache.
# Written to replace the per-process cache of parents map.

# Why not IPC::Shareable? It did not work well for me because
# while objects were constructed, it created a lot of shm segments
# and reaches the OS limit quickly. Or may be I didnt use it the right way.

package HostDB::FileCache;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(cache_exists cache_get cache_set cache_delete);

use strict;
use HostDB::Shared qw( $logger &get_conf );
use Data::Dumper;
use Storable qw(lock_store lock_retrieve);

my $cache_dir = get_conf('server.cache_dir') || '/tmp/hostdb';
my $cache_ttl = get_conf('server.cache_ttl') || 3600;

if (! -d $cache_dir) {
    mkdir $cache_dir or $logger->logconfess("5032: Can't create dir: $cache_dir. $!");
}

my %mem_cache = (); # In-memory per-process cache which is filled from disk-cache objects
my %mem_mtime = (); # Timestamp of in-memory items used to check if it is older than disk cache and invalidate accordingly

sub cache_exists {
    my $key = shift;
    -e "$cache_dir/$key" || return;
    # invalidate if cache is old.
    my $exp = time - $cache_ttl;
    if ((stat("$cache_dir/$key"))[9] < $exp) {
        unlink "$cache_dir/$key" or $logger->logconfess("5032: Can't delete file: $cache_dir/$key. $!");
        return;
    }
    return 1;
}

sub cache_get {
    my $key = shift;
    return unless cache_exists($key);
    # Read from disk if in-memory cache doesnt exist or is stale
    if (!exists $mem_cache{$key} || (stat("$cache_dir/$key"))[9] > $mem_mtime{$key}) {
        $mem_cache{$key} = lock_retrieve("$cache_dir/$key") or $logger->logconfess("5032: Unable to retreive from $cache_dir/$key");
        $mem_mtime{$key} = time;
    }
    return $mem_cache{$key};
}

sub cache_set {
    my ($key, $object) = @_;
    lock_store($object, "$cache_dir/$key") or $logger->logconfess("5032: Unable to store in $cache_dir/$key");
    $mem_cache{$key} = $object;
    $mem_mtime{$key} = time;
    return 1;
}

sub cache_delete {
    my $key = shift;
    return 1 unless cache_exists($key);
    unlink "$cache_dir/$key" or $logger->logconfess("5032: Can't delete file: $cache_dir/$key. $!");
    exists $mem_cache{$key} && delete $mem_cache{$key};
    exists $mem_mtime{$key} && delete $mem_mtime{$key};
    return 1;
}

1;

