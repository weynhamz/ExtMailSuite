# vim: set ci et sw=4 ts=4:
package Ext::Cmd::Client;

use strict;
use IO::Socket;
use IO::Handle;

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;

    die "Need AUTH code!" unless $self->{auth_code};
    die "Need a valid Peer Info" unless $self->{peer};

    $self->connect;

    $self;
}

sub auth {
    my $self = shift;
    my $code = $self->{auth_code};
    my $sock = $self->{socket};

    print $sock "AUTH=$code\n";
    my $reply = $self->readline;
    if ($self->is_2xx($reply)) {
        return 1;
    } else {
        $reply =~ s/^\d*\s*//;
        $self->error($reply);
    }
    0;
}

sub error {
    my $self = shift;
    my $msg = shift;

    if ($msg) {
        $self->{error} = $msg;
    } else {
        return $self->{error};
    }
}

sub connect {
    my $self = shift;
    my $peer = $self->{peer};

    if ($peer =~ /^unix:(.+)$/i) {
        my $cli = IO::Socket::UNIX->new(Peer => $1);
        unless ($cli) {
            $self->error($!);
            return undef;
        }
        $cli->autoflush(1);
        $self->{socket} = $cli;

        return 1 if $self->auth;
    } else {
        $self->error("Peer info not know");
    }
}

sub readline {
    my $self = shift;
    my $sock = $self->{socket};
    my $line = <$sock>;

    $line =~ s/\r?\n$//;
    $line;
}

sub is_2xx {
    my $self = shift;
    my $msg = shift;

    $msg =~ s/\r?\n$//;
    if ($msg =~ /^2[0-9]+\s(.*)/) {
        return $1;
    }
    undef;
}

sub is_ok {
    shift->is_2xx(@_);
}

sub send_cmd {
    my ($self, $cmd, $param) = @_;
    my $sock = $self->{socket};

    $cmd =~ s/\r?\n$//;
    print $sock "$cmd $param\n";
}

sub datasend {
    my ($self, $data) = @_;
    my $sock = $self->{socket};
}

1;
