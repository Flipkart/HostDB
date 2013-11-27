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

use_ok('HostDB::Auth::LDAP');
ok(scalar HostDB::Auth::LDAP::groups('jain.johny') > 1, "Get LDAP groups of a user");
ok(! scalar HostDB::Auth::LDAP::groups('nouser'), "Groups of non-existing user");

done_testing();

