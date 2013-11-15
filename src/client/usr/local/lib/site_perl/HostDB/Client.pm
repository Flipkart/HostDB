#!/usr/bin/perl

=pod

=head1 NAME

HostDB::Client - Client library for HostDB

This module provides an OO interface over HostDB REST API.

=head1 SYNOPSIS

use HostDB::Client;

my $hdb = HostDB::Client->new(\%options);

my $output = $hdb->get($id[, $revision, $raw]);

my $output = $hdb->revisions($id[, $limit]);

my $output = $hdb->blame($id);

my $success = $hdb->set($id, $value, $log);

my $success = $hdb->set($id, $log); # to add a member

my $success = $hdb->rename($id, $newname, $log);

my $success = $hdb->delete($id, $log);

=cut

package HostDB::Client;

use strict;
use Carp;
use Data::Dumper;
use LWP::UserAgent;
#use HTTP::Cookies;
use HTTP::Request::Common;
use HTTP::Request;
use YAML::Syck;

#disabled ssl verification
$ENV{"PERL_LWP_SSL_VERIFY_HOSTNAME"} = 0;

my $conf = LoadFile('/etc/hostdb/client_conf.yaml');
my $server = $conf->{SERVER};
my $proto = 'https';
my $version = 'v1';

=head1 CONSTRUCTOR

=over 8

=item I<HostDB::Client->new(\%options)> - Returns a blessed perl object to interact with HostDB.

You may pass these optional attributes in a hash ref to new():

=over 8

server      =>  HostDB server name.

user        =>  Username for write operations.

password    =>  Password of the above user. A session will be created and cached on disk.

session     =>  If you already have a session ID, use it instead of user/password.

die_on_error=>  Boolean. die() if an error occured. Default is true.

=back

The returned object will have these public attributes:

=over 8

server      =>  HostDB server name.

read_only   =>  0 if auth is successful. 1 otherwise.

user        =>  Username if read_only is 0.

session     =>  Session ID if read_only is 0.

last_status =>  HASHREF { code => 'last status code', message => 'last status message' , trace => 'stacktrace'}

die_on_error=>  Boolean. die() if an error occured. Default is true.

=back

=back

=cut

sub new {
    my ($class, $opt) = @_;
    (defined $opt && ref($opt) ne 'HASH')
        and croak("Options to HostDB::Client should be a hash reference.");
    
    my $self = bless {
        api          => defined $opt->{"server"} ? "$proto://$opt->{server}/$version" : "$proto://$server/$version",
        read_only    => 1,
        user         => undef,
        session      => undef,
        last_status  => {},
        die_on_error => defined $opt->{"die_on_error"} ? $opt->{"die_on_error"} : 1,
    };
    if (defined $opt->{session}) {
        $self->authenticate($opt->{session});
    }
    elsif (defined $opt->{user} && defined $opt->{password}) {
        $self->authenticate($opt->{"user"}, $opt->{"password"});
    }
    #print Data::Dumper->Dumper($self),"\n\n\n";
    return $self;
}

=head1 METHODS

=over 8

=item I<authenticate($user, $password)> - Try to authenticate with HostDB with provided username and password.

=item I<authenticate($session)> - Validates the provided session ID.

STRING $user - LDAP username

STRING $password - user's password

STRING $session - Previously generated session id

Returns boolean indicating success or failure.

Sets $self->{read_only}, $self->{session} and $self->{user} if successful

=cut

sub authenticate {
    my ($self, $arg1, $arg2) = @_;
    $self->{read_only} = 1;
    if (defined $arg1 && defined $arg2) {  # username and password are provided
        my $response = $self->_ua_request('POST', "$self->{api}/auth/session", { "username"=>$arg1, "password"=>$arg2 });
        if ($response->is_success) {
            my $content = $response->content;
            chomp $content;
            $self->{read_only} = 0;
            $self->{session} = $content;
            $self->{user} = $arg1;
        }
    }
    elsif (defined $arg1) {  # session id is provided
        my $response = $self->_ua_request('GET', "$self->{api}/auth/session/$arg1");
        if ($response->is_success) {
            my $content = $response->content;
            chomp $content;
            $self->{read_only} = 0;
            $self->{session} = $arg1;
            $self->{user} = $content;
        }
    }
    croak("Auth Failed.") if ($self->{read_only} && $self->{die_on_error});
    return $self->{read_only} ? 0 : 1;
}

sub _ua_request {
    my ($self, $method, $url, $postdata) = @_;
    my $ua = new LWP::UserAgent;
    my $response;
    if ($method eq 'GET') {
        $response = $ua->get($url);
    }
    elsif ($method eq 'PUT') {
        my $req = POST($url, $postdata);
        $req->method('PUT');
        $response = $ua->request($req);
    }
    elsif ($method eq 'POST') {
        $response = $ua->post($url, $postdata);
    }
    elsif ($method eq 'DELETE') {
        $response = $ua->request(HTTP::Request->new('DELETE', $url));
    }
    $self->{last_status} = {
        code    => $response->code,
        message => $response->message,
        trace   => undef,
    };
    #print Dumper $response;
    if (! $response->is_success) {
        $self->{last_status}->{trace} = $response->header('Error');
        $self->{die_on_error} ? croak $response->message : carp $response->message;
    }
    return $response;
}

=item I<get($id[, $revision, $raw])> - Gets value of HostDB object identified by $id.

STRING $id - Hostdb resource ID

STRING $revision - revision id obtained by calling revisions($id)

BOOLEAN $raw - Get raw format. Makes sense only when id is for 'members'

=cut

sub get {
    my ($self, $id, $revision, $raw) = @_;
    my $uri = "$self->{api}/$id";
    my $sep = '?';
    if (defined $revision) {
        $uri .= $sep . "revision=$revision";
        $sep = '&';
    }
    $uri .= $sep . "raw=true" if (defined $raw);
    my $response = $self->_ua_request('GET', $uri);
    return $response->is_success ? $response->content : undef;
}

=item I<parents($host, $namespace)> - Gets parents of a host in the given namespace.

STRING $host - Hostname. ID hosts/$host must exist

STRING $namespace - Namespace to search for $host. Cannot be 'hosts'

=cut

sub parents {
    my ($self, $host, $namespace) = @_;
    my $response = $self->_ua_request('GET', "$self->{api}/hosts/$host?meta=parents&from=$namespace");
    return $response->is_success ? $response->content : undef;
}

=item I<derived($host, $namespace)> - Gets derived config of a host in the given namespace.

STRING $host - Hostname. ID hosts/$host must exist

STRING $namespace - Namespace to search for $host. Cannot be 'hosts'

=cut

sub derived {
    my ($self, $host, $namespace) = @_;
    my $response = $self->_ua_request('GET', "$self->{api}/hosts/$host?meta=derived&from=$namespace");
    return $response->is_success ? $response->content : undef;
}

=item I<revisions($id[, $limit])> - Gets revisions of a HostDB object.

STRING $id - hostdb resource ID

INTEGER $limit - Max mumber of revisions to return. Default is 50.

=cut

sub revisions {
    my ($self, $id, $limit) = @_;
    my $url = "$self->{api}/$id?meta=revisions";
    $url .= "&limit=$limit" if (defined $limit);
    my $response = $self->_ua_request('GET', $url);
    return $response->is_success ? $response->content : undef;
}

#=item I<blame($id)> - Gets git blame of a HostDB object.
#
#=cut
#
#sub blame {
#    my ($self, $id) = @_;
#    my $response = $self->_ua_request('GET', "$self->{api}/$id?meta=blame");
#    return $response->is_success ? $response->content : undef;
#}

=item I<set($id, $value, $log)> - Sets value of a HostDB object.

=item I<set($id, $log)> - If $id represents a member, $value is not needed.

STRING $id - HostDB resource ID

STRING $value - YAML or LIST value of the hostdb resource

STRING $log - commit message

=cut

sub set {
    my ($self, $id, $value, $log) = @_;
    if ($id =~ /\/members\//) {
        $log = $value;
        $value = '';
    }
    my $params = {
        'value'   => $value,
        'log'     => $log,
        'session' => $self->{session},
    };
    my $response = $self->_ua_request('PUT', "$self->{api}/$id", $params);
    return $response->is_success ? $response->content : undef;
}

=item I<rename($id, $newname, $log)> - Renames a HostDB object.

STRING $id - HostDB resource ID

STRING $newname - new name for the resource

STRING $log - commit message

=cut

sub rename {
    my ($self, $id, $newname, $log) = @_;
    my $params = {
        'newname'   => $newname,
        'log'       => $log,
        'session'   => $self->{session},
    };
    my $response = $self->_ua_request('POST', "$self->{api}/$id", $params);
    return $response->is_success ? $response->content : undef;
}

=item I<delete($id, $log)> - Deletes a HostDB object.

STRING $id - HostDB resource ID

STRING $log - commit message

=cut

sub delete {
    my ($self, $id, $log) = @_;
    my $response = $self->_ua_request('DELETE', "$self->{api}/$id?log=$log&session=$self->{session}");
    return $response->is_success ? $response->content : undef;
}

1;
