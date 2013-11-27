#!/usr/bin/perl
use strict;
use Data::Dumper;
BEGIN {
    use lib '../server/usr/local/lib/site_perl';
    use lib '.';
    use TestEnv;
}
use Test::Most;
die_on_fail;

use_ok('HostDB::Auth::File');

ok(HostDB::Auth::File::exists('user1'), "user1 should exist");
ok(HostDB::Auth::File::auth('user1', 'secret'), "Try auth user1:secret");
ok(HostDB::Auth::File::allowed('user1', '10.10.10.10'), "user1 is allowd from 10.10.10.10");
ok(HostDB::Auth::File::allowed('user1', '10.20.10.10'), "user1 is allowd from 10.20.10.0/24");
ok(! HostDB::Auth::File::allowed('user1', '10.10.10.20'), "user1 is not allowd from 10.10.10.20");

done_testing();

