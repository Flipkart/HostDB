#!/usr/bin/perl
package TestEnv;

require Exporter;
use base qw(Exporter);
our @EXPORT = qw( make_host_config );

use strict;
use File::Temp qw( tempdir );
use File::Path qw( make_path );
my $root_dir = tempdir( '/tmp/hostdb-XXXX', CLEANUP => 1 );
make_path("$root_dir/namespaces/hosts/.perms");
make_path("$root_dir/namespaces/tags/.perms");
make_path("$root_dir/namespaces/tags/.members");
open(my $fh, ">", "$root_dir/namespaces/hosts/host1");
print {$fh} make_host_config('host1');
close $fh;
`echo "--- test" > $root_dir/namespaces/hosts/.perms/host1`;
`echo "test" > $root_dir/namespaces/tags/tag1`;
`echo "--- test" > $root_dir/namespaces/tags/.perms/tag1`;
`echo "test" > $root_dir/namespaces/tags/.members/tag1`;
`pushd $root_dir/namespaces && git init . && git add * && git commit -am "init" && popd`;

my $server_conf = <<END;
---
server:
  read_only: off
  namespace_dir: $root_dir/namespaces
git:
  path: /usr/bin/git
  lock_file: $root_dir/hostdb-git.lock
  lock_timeout: 10
users:
  system:
    auth_method: file
  human:
    auth_method: ldaps
    email_domain: domain.com
    cookie_domain: domain.com
auth:
  file:
    creds_file: $root_dir/creds
  ldaps:
    server: ldap.yourdomain.com
    users_dn: "ou=People,dc=domain,dc=com"
    groups_dn: "ou=Groups,dc=domain,dc=com"
session:
  cipher_key_file: $root_dir/cipher_key
logger:
  conf_file: $root_dir/logger.conf
END

my $logger_conf = <<END;
log4perl.logger.HostDB=DEBUG, Buffer
log4perl.appender.A1                          = Log::Dispatch::File
log4perl.appender.A1.filename                 = $root_dir/server.log
log4perl.appender.A1.mode                     = append
log4perl.appender.A1.layout                   = Log::Log4perl::Layout::PatternLayout
log4perl.appender.A1.layout.ConversionPattern = %d %p> %F{1}:%L %M - %m%n
log4perl.appender.Buffer               = Log::Log4perl::Appender::Buffer
log4perl.appender.Buffer.appender      = A1
log4perl.appender.Buffer.trigger_level = DEBUG
END

my $creds = <<END;
---
user1:
  password: dd02c7c2232759874e1c205587017bed
  allow: [10.10.10.10, 10.20.10.0/24]
END

open(my $conf_fh, '>', "$root_dir/server_conf.yaml");
open(my $cipher_fh, '>', "$root_dir/cipher_key");
open(my $logger_fh, '>', "$root_dir/logger.conf");
open(my $creds_fh, '>', "$root_dir/creds");
print {$cipher_fh} "abcdef";
print {$logger_fh} $logger_conf;
print {$conf_fh} $server_conf;
print {$creds_fh} $creds;
close $cipher_fh;
close $logger_fh;
close $conf_fh;
close $creds_fh;

use lib '../server/usr/local/lib/site_perl';
use HostDB::Shared qw( &load_conf &get_conf $logger );
load_conf("$root_dir/server_conf.yaml");

END {
#    print "Keep test data? (y/N) ";
#    my $resp = readline;
#    chomp $resp;
#    if ($resp ~~ ['y', 'Y']) {
        my $data_dir = get_conf('server.namespace_dir');
        $data_dir =~ s|/namespaces$||;
        my $bkp_dir = '/tmp/hostdb-' . getpwuid($<);
        `rm -rf $bkp_dir`;
        `cp -r $data_dir $bkp_dir`;
        print "Backed up data at $bkp_dir\n";
#    }
}

sub make_host_config {
    my $hostname = shift;
    return <<END;
--- 
Hardware: 
  CPU Speed: 2.40Ghz
  Memory: 8x8GB
  Storage: 600GB*4
Network: 
  FQDN: $hostname
  IP: 1.1.1.1
  cname: 'null'
END
}

1;

