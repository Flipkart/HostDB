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

use_ok('HostDB::Session', qw(generate_session validate_credentials validate_session) );
ok(validate_credentials('user1', 'secret', '10.10.10.10'), "Try auth user1:secret");
my $session;
ok($session = generate_session('user1', '10.10.10.10'), "Generate Session token");
is(validate_session($session, '10.10.10.10'), 'user1', 'Validate token');


done_testing();

