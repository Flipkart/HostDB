#!/usr/bin/perl

package HostDB::Git;

use strict;
use HostDB::Shared qw($conf $logger);
use Carp;
use Log::Log4perl;
use Data::Dumper;

my $GIT = $conf->{GIT_PATH} || 'git';
my $lock_file = $conf->{GIT_LOCK_FILE} || '/var/lock/hostdb-git.lock';
my $timeout = $conf->{GIT_LOCK_TIMEOUT} || 10;
my $user_domain = $conf->{USER_EMAIL_DOMAIN} || 'nodomain';

$SIG{ALRM} = sub { $logger->logconfess("5034: Timed out waiting for lock") };

sub new {
    my ($class, $work_tree, $author) = @_;
    my $self = {
        work_tree => $work_tree || $conf->{NAMESPACE_DIR},
        author    => $author || getpwuid($<),
    };
    -x $GIT || $logger->logconfess("5002: $GIT is not executable.");
    bless $self;
}

sub txn_begin {
    my ($self) = @_;
    return if exists $self->{_lock_fh}; #already in transaction
    open($self->{_lock_fh}, '>', $lock_file);
    alarm $timeout;
    flock($self->{_lock_fh}, 2); # Exclusive Lock
    alarm 0; # Disable alarm if lock is acquired
    #discard uncommitted local changes if any
    my $out = ($self->run('reset', '--hard'))[1]; # $out will look like 'HEAD is now at 14aa753 commit_msg'
    $self->{_git_head} = (split(' ', $out))[4];
    $self->run('clean', '-fd');
}

sub txn_commit {
    my ($self, $log) = @_;
    $self->run('commit', '-am', $log);
    $self->txn_end();
}

sub txn_rollback {
    my ($self) = @_;
    exists $self->{_lock_fh} || $logger->logcroak("5002: Not in a transaction");
    $self->run('reset', '--hard', $self->{_git_head});
    $self->run('clean', '-fd');
    $self->txn_end();
}

sub txn_end {
    my ($self) = @_;
    close  $self->{_lock_fh};
    delete $self->{_lock_fh};
    delete $self->{_git_head};
}

sub run {
    my ($self, @args) = @_;
    $ENV{GIT_AUTHOR_NAME}  = $self->{author};
    $ENV{GIT_AUTHOR_EMAIL} = "$self->{author}\@$user_domain";
    $ENV{GIT_WORK_TREE}    = $self->{work_tree};
    $ENV{GIT_DIR}          = "$self->{work_tree}/.git";
    $logger->debug("Running $GIT @args");
    # nice read: http://blog.0x1fff.com/2009/09/howto-execute-system-commands-in-perl.html
    open(my $CMD, '-|', $GIT, @args);
    my $output = do { local $/; <$CMD> };
    close $CMD;
    my $rc = $? >> 8; # get actual command exit status
    $rc && $logger->logconfess("Command: '$GIT @args' failed with RC: $rc");
    return (wantarray) ? ($rc, $output) : $rc;
}

sub DESTROY {
    # http://perldoc.perl.org/perlobj.html#Destructors
    my ($self) = @_;
    local $@;
    exists $self->{_git_head} && $self->txn_rollback();
}

1;
