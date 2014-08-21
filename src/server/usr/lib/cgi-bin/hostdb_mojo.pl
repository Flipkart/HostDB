#!/usr/bin/perl

# Using Mojolicious will reduce the throughput to half

use Data::Dumper;
use Mojolicious::Lite;

use HostDB::Shared qw(&load_conf &get_conf $logger);
use HostDB;
use HostDB::ACL;
my $mtime_header = 'Mtime';
my $HOSTS_DIR = '/var/lib/hostdb/namespaces/hosts';

app->secrets(['hdb_session_secret']);
app->sessions->cookie_name('HostDB');
app->sessions->cookie_domain('.nm.flipkart.com');
app->sessions->secure(1);

app->config(hypnotoad => {
    listen => ['http://*:8080'],
    workers => 10,
    accepts => 10000,
    pid_file => '/tmp/hypnotoad.pid',
});

# Routes
under '/v1';

# Not Implemented ==============================
any [qw(PUT POST DELETE)] => '/' => {
    text => '',
    status => 501,
};
any [qw(PUT POST DELETE)] => '/#namespace' => {
    text => '',
    status => 501,
};
post '/#namespace/#key/members' => {
    text => '',
    status => 501,
};
post '/#namespace/#key/perms' => {
    text => '',
    status => 501,
};
# =============================================
    
group {
    under '/auth';
    get '/can_modify' => sub {
        my $c = shift;
        unless ($c->req->param('user') && $c->req->param('id')) {
            render_exception($c, '4001: Missing username or resource ID');
            return;
        }
        my $response;
        eval {
            $response = can_modify($c->req->param('id'), $c->req->param('user'));
        };
        ($@) ? render_exception($c, $@) : $c->render(text => $response);
    };
};

get '*id' => sub {
    my $c = shift;
    my ($response, $mtime);
    my $params = $c->req->params->to_hash;
    eval {
        ($response, $mtime) = HostDB::get($c->stash('id'), $params);
    };
    if ($@) {
        render_exception($c, $@);
        return;
    }
    $c->res->headers->header($mtime_header => $mtime);
    $c->render(text => $response, status => '200');
};
get '/' => sub {
    my $c = shift;
    my ($response, $mtime);
    my $params = $c->req->params->to_hash;
    eval {
        ($response, $mtime) = HostDB::get('/', $params);
        };
    if ($@) {
        render_exception($c, $@);
        return;
    }
    $c->res->headers->header($mtime_header => $mtime);
    $c->render(text => $response, status => '200');
};

# Writes
group {
    my $params;
    under sub {
        my $c = shift;
        if (get_conf('server.read_only') ~~ ['1', 'on']) {
            render_exception($c, '4031: HostDB is in read-only mode');
            return;
        }
        if (!$c->session->{HostDB}) {
            my $user = (split ':', $c->req->url->to_abs->userinfo)[0];
            if ($user) {
                $c->session->{HostDB} = $user;
            }
            else {
                $c->res->headers->www_authenticate('Basic');
                $c->render(text => '', status => 401);
                return;
            }
        }
        if (!$c->req->param('log') || $c->req->param('log') =~ /^\s*$/) {
            render_exception($c, '4001: Missing parameter: log');
            return;
        }
        $params = $c->req->params->to_hash;
        $params->{user} = $c->session->{HostDB};
        return 1;
    };
    put '*id' => sub {
        my $c = shift;
        if (!exists $params->{value}) {
            $params->{value} = $c->req->body || '';
        }
        my ($response, $mtime);
        eval {
            ($response, $mtime) = HostDB::set($c->stash('id'), $params->{value}, $params);
        };
        if ($@) {
            render_exception($c, $@);
            return;
        }
        $c->res->headers->header($mtime_header => $mtime);
        $c->render(text => '', status => 201);
    };
    post '*id' => sub {
        my $c = shift;
        if (!exists $params->{newname}) {
            render_exception($c, '4001: Missing parameter: newname');
            return;
        }
        my ($response, $mtime);
        eval {
            ($response, $mtime) = HostDB::rename($c->stash('id'), $params->{newname}, $params);
        };
        if ($@) {
            render_exception($c, $@);
            return;
        }
        $c->res->headers->header($mtime_header => $mtime);
        $c->render(text => '', status => 200);
    };
    del '*id' => sub {
        my $c = shift;
        my $response;
        eval {
            $response = HostDB::delete($c->stash('id'), $params);
        };
        if ($@) {
            render_exception($c, $@);
            return;
        }
        $c->render(text => '', status => 200);
    };
};

under '/';
under '/api';
get '/tag/#tag' => sub {
    my $c = shift;
    my $resp;
    eval {
        $resp = HostDB::get("tags/" . $c->stash('tag'));
    };
    if ($@) {
        render_exception($c, $@);
        return;
    }
    $c->render(text => $resp, status => 200);
};
get '/host/#host' => sub {
    my $c = shift;
    my $host;
    my $h = $c->stash('host');
    if (-f "$HOSTS_DIR/$h") {
        $host = $h;
    }
    elsif (-f "$HOSTS_DIR/$h.nm.flipkart.com") {
        $host = "$h.nm.flipkart.com";
    }
    elsif (-f "$HOSTS_DIR/$h.ch.flipkart.com") {
        $host = "$h.ch.flipkart.com";
    }
    else {
        $host = $h;
    }
    my $resp;
    eval {
        $resp = HostDB::get("hosts/$host");
    };
    if ($@) {
        render_exception($c, $@);
        return;
    }
    $c->render(text => $resp, status => 200);
};
get '/alltags' => sub {
    my $c = shift;
    my $resp;
    eval {
        $resp = HostDB::get("tags");
    };
    if ($@) {
        render_exception($c, $@);
        return;
    }
    $c->render(text => $resp, status => 200);
};
get '/allhosts2' => sub {
    my $c = shift;
    my $resp;
    eval {
        $resp = HostDB::get("hosts");
    };
    if ($@) {
        render_exception($c, $@);
        return;
    }
    $c->render(text => $resp, status => 200);
};
get '/allhosts' => sub {
    my $c = shift;
    my $resp;
    eval {
        $resp = HostDB::get("hosts");
    };
    if ($@) {
        render_exception($c, $@);
        return;
    }
    my $out = join("\n", map { s/.[nc][mh].flipkart.com$//; $_ } split(/\n/, $resp));
    $c->render(text => $out, status => 200);
};
get '/tagof/#host' => sub {
    my $c = shift;
    my $h = $c->stash('host');
    my $resp;
    my $host;
    if (-f "$HOSTS_DIR/$h") {
        $host = $h;
    }
    elsif (-f "$HOSTS_DIR/$h.nm.flipkart.com") {
        $host = "$h.nm.flipkart.com";
    }
    elsif (-f "$HOSTS_DIR/$h.ch.flipkart.com") {
        $host = "$h.ch.flipkart.com";
    }
    else {
        $host = $h;
    }
    eval {
        $resp = HostDB::get("hosts/$host", { meta => 'parents', from => 'tags' });
    };
    if ($@) {
        render_exception($c, $@);
        return;
    }
    $c->render(text => $resp, status => 200);
};
get '/hostof2/#tag' => sub {
    my $c = shift;
    my $tag = $c->stash('tag');
    my $resp;
    eval {
        $resp = HostDB::get("tags/$tag/members");
    };
    if ($@) {
        render_exception($c, $@);
        return;
    }
    $c->render(text => $resp, status => 200);
};
get '/hostof/#tag' => sub {
    my $c = shift;
    my $tag = $c->stash('tag');
    my $resp;
    eval {
        $resp = HostDB::get("tags/$tag/members");
    };
    if ($@) {
        render_exception($c, $@);
        return;
    }
    my $out = join("\n", map { s/.[nc][mh].flipkart.com$//; $_ } split(/\n/, $resp));
    $c->render(text => $out, status => 200);
};


app->start;

sub render_exception {
    my ($c, $ex) = @_;
    my $msg = (ref $ex) ? $ex->message : $ex;
    my @frames = grep { $_ !~ /Mojo/ } split("\n", $msg);
    my $code = 500;
    my $status = $frames[0];
    $status =~ s/ at .*$//;
    if ($status =~ /^(\d{3})\d: (.*)/) {
        $code = $1;
        $status = $2;
    }
    $c->res->headers->header('CallTrace' => join(" \n", @frames));
    $c->res->message($status);
    $c->render(text => '', status => $code);
}

