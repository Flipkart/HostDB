#!/usr/bin/perl
use strict;
use Data::Dumper;
use Test::Most;
use YAML::Syck;
BEGIN {
    use lib '../server/usr/local/lib/site_perl';
    use lib '.';
    use TestEnv;
}
die_on_fail;

use_ok('HostDB::FileStore');
my $hdb = HostDB::FileStore->new('namespace/key/members/member');
isa_ok($hdb, 'HostDB::FileStore');
ok( $hdb->{id}        eq 'namespace/key/members/member' &&
    $hdb->{namespace} eq 'namespace' &&
    $hdb->{key}       eq 'key' &&
    $hdb->{meta_info} eq 'members' &&
    $hdb->{record}    eq 'member', "Check ID parsing" );

$hdb = HostDB::FileStore->new('hosts/web1.domain.com');
ok($hdb->set(make_host_config('web1.domain.com'), "test set config"), "Set");

# Tests on namespace level
$hdb = HostDB::FileStore->new('hosts');
my @hosts = $hdb->get();
ok('web1.domain.com' ~~ @hosts, "Get Hosts");
eval { $hdb->set("test", "test") };
like($@, qr/4051/, "Set not allowed on namespace");
eval { $hdb->rename("test", "test") };
like($@, qr/4051/, "Rename not allowed on namespace");
eval { $hdb->delete("test") };
like($@, qr/4051/, "Delete not allowed on namespace");
eval { $hdb->set("test", "test") };
like($@, qr/4051/, "Set not allowed on namespace");
my @revs;
ok(@revs = $hdb->revisions(), "Get revisions of namespace");
my $rev = (split / /, $revs[0])[0];
@hosts = $hdb->get($rev);
ok('web1.domain.com' ~~ @hosts, "Get Hosts - rev");

# Tests on key level
$hdb = HostDB::FileStore->new('hosts/web1.domain.com');
my $conf;
ok($conf = Load($hdb->get()), "Get host config");
is($conf->{Network}{IP}, '1.1.1.1', "Verify host config");
$conf->{Network}{IP} = '1.2.3.4';
ok($hdb->set(Dump($conf), "change ip"), "Set host config");
ok(@revs = $hdb->revisions(), "Get revs of host");
$rev = (split / /, $revs[0])[0];
$conf = Load($hdb->get($rev));
is($conf->{Network}{IP}, '1.2.3.4', "Verify set");
ok($hdb->rename('web2.domain.com', "rename host"), "Rename host");
ok($hdb = HostDB::FileStore->new('hosts/web2.domain.com'), "Rename successful");
ok($hdb->delete("delete host"), "Delete Host");
eval { $hdb->get() };
like($@, qr/404/, "Delete confirmed");

# Tests on sub-config level
$hdb = HostDB::FileStore->new('hosts/web1.domain.com');
ok($hdb->set(make_host_config('web1.domain.com'), "test set config"), "Set");
$hdb = HostDB::FileStore->new('hosts/web1.domain.com/Network/FQDN');
is(Load($hdb->get()), 'web1.domain.com', "Get sub config");
ok($hdb->rename('hostname', "test rename"), "sub config rename");
$hdb = HostDB::FileStore->new('hosts/web1.domain.com/Network/hostname');
is(Load($hdb->get()), 'web1.domain.com', "Verify Rename");
$hdb = HostDB::FileStore->new('hosts/web1.domain.com/Network/IP');
ok($hdb->set('1.2.3.4', "set ip"), "Set IP");
is(Load($hdb->get()), '1.2.3.4', "Verify set");
$hdb = HostDB::FileStore->new('hosts/web1.domain.com/Hardware/Memory');
ok($hdb->delete("test delete"), "Delete sub config");
eval { $hdb->get() };
like($@, qr/404/, "Delete confirmed");

# Tests on members
$hdb = HostDB::FileStore->new('tags/web_servers');
ok($hdb->set('--- testtag', 'test tag'), "Create Tag");
$hdb = HostDB::FileStore->new('tags/web_servers/members');
ok($hdb->set('web1.domain.com', "set members"), "Set Members");
is(scalar $hdb->get(), 'web1.domain.com', "Get Members");
eval {$hdb->delete("try deleting members")};
like($@, qr/405/, "Delete not allowed on members");
eval {$hdb->rename('MEMBERS', "try rename")};
like($@, qr/405/, "Rename not allowed on members");
ok(@revs = $hdb->revisions(), "Get revs of members");
$rev = (split / /, $revs[0])[0];
is(scalar $hdb->get($rev), 'web1.domain.com', "Get Members from revision");

# Tests on member
$hdb = HostDB::FileStore->new('tags/web_servers/members/@tag1');
ok($hdb->set('', "test"), "Set member");
is($hdb->get(), '@tag1', "Get on member just returns itself");
ok($hdb->rename('web3.domain.com', "rename"), "Rename Member");
$hdb = HostDB::FileStore->new('tags/web_servers/members/web3.domain.com');
ok($hdb->delete("test"), "Delete member");

done_testing();

