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

use_ok('HostDB::Shared', qw( &get_conf $logger ));
use_ok('HostDB::Git');

my $ndir;
ok($ndir = get_conf('server.namespace_dir'), "Get namespace dir");
my $git = HostDB::Git->new();

isa_ok($git, 'HostDB::Git');

eval { $git->run('bad', 'command') };
like($@, qr/command.*failed/i, "Bad command fails");

`echo "test" > $ndir/testfile1`;
`echo "test" > $ndir/testfile2`;
$git->run('add', "$ndir/testfile1");

eval {$git->txn_commit("test")};
like($@, qr/Not in a transaction/, "Commit fails if not in txn");

ok($git->txn_begin(), "Begin transaction");
ok(! -e "$ndir/testfile1", "Uncommitted files removed");
ok(! -e "$ndir/testfile2", "Untracked files removed");

open(my $h1, ">", "$ndir/hosts/web1.domain.com") or die "Unable to open file. $!";
print {$h1} make_host_config("web1.domain.com");
close $h1;
$git->run('add', "$ndir/hosts/web1.domain.com");
eval {$git->txn_commit(" ")};
like($@, qr/Missing commit message/, "Mandatory commit message");
ok($git->txn_commit("test commit"), "Txn commit");
ok(-e "$ndir/hosts/web1.domain.com", "Transaction Successful");

$git->txn_begin();
open(my $h2, ">", "$ndir/hosts/web2.domain.com") or die "Unable to open file. $!";
print {$h2} make_host_config("web2.domain.com");
close $h2;
$git->run('add', "$ndir/hosts/web2.domain.com");
ok($git->txn_rollback(), "Txn rollback");
ok(! -e "$ndir/hosts/web2.domain.com", "Rollback Successful");

done_testing();

