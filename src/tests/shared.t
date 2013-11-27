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

use_ok('HostDB::Shared', qw( &load_conf &get_conf $logger ));

is(get_conf('session.cipher_key'), "abcdef", "Load server conf");

ok(! get_conf('non.existing'), "Bad param should fail");

our $logger;
isa_ok($logger, 'Log::Log4perl::Logger');

done_testing();

