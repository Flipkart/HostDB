#!/usr/bin/perl
# A simple shared object cache.
# Written to replace the per-process cache of parents map.

# Why not IPC::Shareable? It did not work well for me because
# while objects were constructed, it created a lot of shm segments
# and reaches the OS limit quickly. Or may be I didnt use it the right way.

package HostDB::FileCache;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(cache_exists cache_get cache_set cache_delete cache_lock cache_unlock);

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
my %lock_fh = (); # Store FDs to exclusive locks to cache items

sub cache_exists {
    my $key = shift;
    -e "$cache_dir/$key" || return;
    # invalidate if cache is old.
    my $exp = time - $cache_ttl;
    if ((stat("$cache_dir/$key"))[9] < $exp) {
        cache_delete($key);
        return;
    }
    return 1;
}

sub cache_lock {
    my $key = shift;
    $lock_fh{$key} && return 1;
    open($lock_fh{$key}, '>', "$cache_dir/$key.lock") or return;
    flock($lock_fh{$key}, 2);
}

sub cache_unlock {
    my $key = shift;
    if (exists $lock_fh{$key} && $lock_fh{$key}) {
        close $lock_fh{$key};
	delete $lock_fh{$key};
    }
}

sub cache_get {
    my $key = shift;
    cache_exists($key) || return;
    # Read from disk if in-memory cache doesnt exist or is stale
    if (!exists $mem_cache{$key} || (stat("$cache_dir/$key"))[9] > $mem_mtime{$key}) {
        my $ref;
        eval {
            $ref = lock_retrieve("$cache_dir/$key");
        };
        if ($@ || !$ref) {
            # Corrupted cache file
            $logger->logcluck("Unable to retreive from $cache_dir/$key. Moving it to $cache_dir/$key.bak. $@");
            cache_delete($key, 1);
            return;
        }
        $mem_cache{$key} = $ref;
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
    my ($key, $backup) = @_;
    -e "$cache_dir/$key" || return 1;
    if ($backup) {
        rename("$cache_dir/$key", "$cache_dir/$key.bak") or $logger->logconfess("5032: Can't rename $cache_dir/$key to $cache_dir/$key.bak. $!");
    }
    else {
        unlink("$cache_dir/$key") or $logger->logconfess("5032: Can't delete file: $cache_dir/$key. $!");
    }
    return 1;
}

1;

