#!/usr/bin/perl
# A simple shared object cache.
# Written to replace the per-process cache of parents map.

# Why not IPC::Shareable? It did not work well for me because
# while objects were constructed, it created a lot of shm segments
# and reaches the OS limit quickly. Or may be I didnt use it the right way.

package HostDB::FileCache;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw(cache_exists cache_get cache_set cache_purge cache_lock cache_unlock);

use strict;
use HostDB::Shared qw( $logger &get_conf );
use Data::Dumper;
use Storable qw(freeze thaw);

my $cache_dir = get_conf('server.cache_dir') || '/tmp/hostdb';
my $cache_ttl = get_conf('server.cache_ttl') || 3600;

if (! -d $cache_dir) {
    mkdir $cache_dir or $logger->logconfess("5032: Can't create dir: $cache_dir. $!");
}

my %mem_cache = (); # In-memory per-process cache which is filled from disk-cache objects
my %mem_mtime = (); # Timestamp of in-memory items used to check if it is older than disk cache and invalidate accordingly
my %mem_cache_serialized = ();
my %lock_fh = (); # Store FDs to exclusive locks to cache items

sub cache_exists {
    my $key = shift;
    -e "$cache_dir/$key" || return;
    # invalidate if cache is old.
    my $exp = time - $cache_ttl;
    if ((stat("$cache_dir/$key"))[9] < $exp) {
        unlink("$cache_dir/$key") or $logger->logconfess("5032: Can't delete file: $cache_dir/$key. $!");
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
    my ($key, $serialized) = @_;
    cache_exists($key) || return;
    # Read from disk if in-memory cache doesnt exist or is stale
    if (!exists $mem_cache{$key} || (stat("$cache_dir/$key"))[9] > $mem_mtime{$key}) {
        my $ref;
        open(my $fh, "<", "$cache_dir/$key");
        flock($fh, 1);
        my $data = do { local $/; <$fh> };
        close $fh;
        if ($serialized) {
            $ref = $data;
        }
        else {
            eval {
                $ref = thaw($data);
            };
            if ($@ || !$ref) {
                # Corrupted cache file
                $logger->logcluck("Unable to retreive from $cache_dir/$key. Moving it to $cache_dir/$key.bak. $@");
                rename("$cache_dir/$key", "$cache_dir/$key.bak") or $logger->logconfess("5032: Can't rename $cache_dir/$key to $cache_dir/$key.bak. $!");
                return;
            }
        }
        $mem_cache_serialized{$key} = $data;
        $mem_cache{$key} = $ref;
        $mem_mtime{$key} = time;
    }
    return ($serialized) ? $mem_cache_serialized{$key} : $mem_cache{$key};
}

sub cache_set {
    my ($key, $object) = @_;
    my $fh;
    if (-e "$cache_dir/$key") {
        open($fh, "+<", "$cache_dir/$key");
        flock($fh, 2);
        seek($fh, 0, 0); truncate($fh, 0);
    }
    else {
        open($fh, ">", "$cache_dir/$key");
    }
    if (ref($object)) {
        my $data = freeze $object;
        print {$fh} $data;
        $mem_cache{$key} = $object;
        $mem_cache_serialized{$key} = $data;
    }
    else {
        print {$fh} $object;
        $mem_cache{$key} = $object;
        $mem_cache_serialized{$key} = $object;
    }
    $mem_mtime{$key} = time;
    return 1;
}

sub cache_purge {
    opendir(my $dh, $cache_dir) or $logger->logconfess("5032: Unable to open $cache_dir");
    my @items = grep { !(/^\./ || /\.lock$/) } readdir($dh);
    closedir $dh;
    foreach my $key (@items) {
        cache_lock("$cache_dir/$key");
        unlink("$cache_dir/$key") or $logger->logconfess("5032: Can't delete file: $cache_dir/$key. $!");
        unlink("$cache_dir/$key.lock");
        cache_unlock("$cache_dir/$key");
    }
    return 1;
}

1;

