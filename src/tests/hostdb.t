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

use_ok('HostDB');

use HostDB::FileStore;
use HostDB::Git;

my $user = getpwuid($<);

my $conf = <<END;
---
$user:
  data: RW
  members: RW
END
my $git = HostDB::Git->new();
$git->txn_begin();
my $hdb = HostDB::FileStore->new("tags/.global/perms");
`echo "$conf" > $hdb->{_file}`;
$git->run('add', $hdb->{_file});
$hdb = HostDB::FileStore->new("hosts/.global/perms");
`echo "$conf" > $hdb->{_file}`;
$git->run('add', $hdb->{_file});
$git->txn_commit("perms");
my $opt = { user => $user, log => "test" };
foreach ('web1', 'web2', 'db1', 'db2') {
    ok(HostDB::set("hosts/$_.domain.com", make_host_config("$_.domain.com"), $opt), "Create hosts/$_.domain.com");
}

foreach ( 'web', 'db' ) {
    ok(HostDB::set("tags/${_}_servers", "--- $_", $opt), "Create tags/${_}_servers");
    ok(HostDB::set("tags/${_}_servers/members", "${_}1.domain.com\n${_}2.domain.com", $opt), "Create tags/${_}_servers/members");
}

ok(HostDB::set("tags/all_servers", "--- all", $opt), "Create tags/all_servers");
ok(HostDB::set("tags/all_servers/members", "\@web_servers\n\@db_servers", $opt), "Create tags/all_servers/members");

like(HostDB::get("tags/all_servers/members"), qr/web1.domain.com/, "Get members");
like(HostDB::get("tags/all_servers/members", {raw => 1}), qr/db_servers/, "Get members raw");
like(HostDB::get("hosts/web1.domain.com", {meta => 'derived', from => 'tags'}), qr/web_servers: web/, "Get derived config");

ok(HostDB::rename("hosts/web1.domain.com", "web3.domain.com", $opt), "Rename host");
like(HostDB::get("tags/all_servers/members"), qr/web3.domain.com/, "Member is automatically renamed");
ok(HostDB::rename("tags/db_servers", "database_servers", $opt), "Rename tag");
like(HostDB::get("tags/all_servers/members"), qr/db1.domain.com/, "Member is automatically renamed");

ok(HostDB::delete("tags/database_servers", $opt), "Delete tag");
is(HostDB::get("hosts/db1.domain.com", {meta => 'parents', from => 'tags'}), '', "No parents for db1.domain.com");

like(HostDB::get("hosts/*/Network/IP", {foreach => 'hosts'}), qr/1.1.1.1/, "Experimental multi-get api");

done_testing();

