#!/usr/bin/perl

package HostDB::Git;

use strict;
use HostDB::Shared qw( &get_conf $logger );
use Carp;
use Data::Dumper;

$SIG{ALRM} = sub { $logger->logconfess("5034: Timed out waiting for lock") };

sub new {
    my ($class, $work_tree, $author) = @_;
    my $self = {
        git          => get_conf('git.path') || 'git',
        work_tree    => $work_tree || get_conf('server.namespace_dir'),
        author       => $author || getpwuid($<),
        domain       => get_conf('users.human.email_domain') || 'nodomain',
        lock_file    => get_conf('git.lock_file') || '/var/lock/hostdb-git.lock',
        lock_timeout => get_conf('git.lock_timeout') || 10,
    };
    -x $self->{git} || $logger->logconfess("5002: $self->{git} is not executable.");
    bless $self;
}

sub txn_begin {
    my ($self) = @_;
    return 1 if exists $self->{_lock_fh}; #already in transaction
    open($self->{_lock_fh}, '>', $self->{lock_file});
    alarm $self->{lock_timeout};
    flock($self->{_lock_fh}, 2); # Exclusive Lock
    alarm 0; # Disable alarm if lock is acquired
    #discard uncommitted local changes if any
    my $out = ($self->run('reset', '--hard'))[1]; # $out will look like 'HEAD is now at 14aa753 commit_msg'
    $self->{_git_head} = (split(' ', $out))[4];
    $self->run('clean', '-fd');
    return 1;
}

sub txn_commit {
    my ($self, $log) = @_;
    exists $self->{_lock_fh} || $logger->logcroak("5002: Not in a transaction");
    $logger->logcroak("4001: Missing commit message") if (!$log || $log =~ /^\s*$/);
    $self->run('commit', '-am', $log);
    $self->_txn_end();
}

sub txn_rollback {
    my ($self) = @_;
    exists $self->{_lock_fh} || $logger->logcroak("5002: Not in a transaction");
    $self->run('reset', '--hard', $self->{_git_head});
    $self->run('clean', '-fd');
    $self->_txn_end();
}

sub _txn_end {
    my ($self) = @_;
    close  $self->{_lock_fh};
    delete $self->{_lock_fh};
    delete $self->{_git_head};
    return 1;
}

sub run {
    my ($self, @args) = @_;
    $ENV{GIT_AUTHOR_NAME}  = $self->{author};
    $ENV{GIT_AUTHOR_EMAIL} = "$self->{author}\@$self->{domain}";
    $ENV{GIT_WORK_TREE}    = $self->{work_tree};
    $ENV{GIT_DIR}          = "$self->{work_tree}/.git";
    $logger->debug("Running $self->{git} @args");
    # nice read: http://blog.0x1fff.com/2009/09/howto-execute-system-commands-in-perl.html
    open(my $cmd, '-|', $self->{git}, @args);
    my $output = do { local $/; <$cmd> };
    close $cmd;
    my $rc = $? >> 8; # get actual command exit status
    $rc && $logger->logconfess("Command: '$self->{git} @args' failed with RC: $rc");
    return (wantarray) ? ($rc, $output) : $rc;
}

sub DESTROY {
    # http://perldoc.perl.org/perlobj.html#Destructors
    my ($self) = @_;
    local $@;
    exists $self->{_git_head} && $self->txn_rollback();
}

1;
