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

use_ok('HostDB::ACL');

use HostDB::FileStore;
use HostDB::Auth::LDAP;

my $user = getpwuid($<);
my $group = (HostDB::Auth::LDAP::groups($user))[0];

my $conf = <<END;
---
$user:
  data: RW
END
my $hdb = HostDB::FileStore->new("tags/tag1/perms");
`echo "$conf" > $hdb->{_file}`;
ok(can_modify('tags/tag1', $user), "User can modify data");
ok(! can_modify('tags/tag1/members', $user), "User cant modify members");
$conf = <<END;
---
$group:
  data: RW
END
`echo "$conf" > $hdb->{_file}`;
ok(can_modify('tags/tag1', $user), "Group can modify data");
ok(! can_modify('tags/tag1/members', $user), "Group cant modify members");

$conf = <<END;
---
$user:
  members: RW
END
$hdb = HostDB::FileStore->new("tags/.global/perms");
`echo "$conf" > $hdb->{_file}`;
ok(can_modify('tags/tag1/members', $user), "Now user can modify members");
$conf = <<END;
---
$group:
  members: RW
END
ok(can_modify('tags/tag1/members', $user), "Now group can modify members");

done_testing();

