# vim: set cindent expandtab ts=4 sw=4:
#
# Copyright (c) 1998-2005 Chi-Keung Ho. All rights reserved.
#
# This programe is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# Extmail - a high-performance webmail to maildir
# $Id$
use strict;
use IO::Socket;

package Ext::Auth::Authlib;
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(auth);

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;
    $self->init(@_);
    $self;
}

sub init {
    my $self = shift;
    my %opt = @_;

    $opt{path} = '/var/spool/authdaemon/socket' if !$opt{path};
    $self->{opt}=\%opt;

    my $socket;
    $socket = IO::Socket::UNIX->new($opt{path}) or die "Authlib Error: $!\n";
    $self->{socket} = $socket;
}

sub _parse {
    my $str = shift;
    $str =~ s/\n+/\n/sxg;
    my %hash = ();

    for (split(/\n+/, $str)) {
        /^([^=]+)=(.*)/;
        $hash{$1} = $2;
    }
    \%hash;
}

sub search {
    my $self = shift;
    my $socket = $self->{socket};

    my ($user, $pass) = @_;
    my ($serv, $type) = ('extmail', 'login');
    my $len = length($user.$pass.$serv.$type)+4;

    printf($socket "AUTH %s\n%s\n%s\n%s\n%s\n\n",
        $len,
        $serv,
        $type,
        $user,
        $pass
    );

    my $result = '';
    while (<$socket>) {
        $result .= $_;
    }

    return undef unless $result;
    if ($result =~ /^(FAIL|ERROR)/s) {
        return undef;
    }
    _parse($result);
}

# return value redifination since 0.24-RC2
#
# $rv =  0  LOGIN_OK
# $rv = -1  LOGIN_FAIL
# $rv =  1  LOGIN_DISABLED
#
sub auth {
    my $self = shift;
    my ($username, $password) = (@_);
    my $res = $self->search($username,$password);
    my $rv = -1;

    if($res) {
        if ($res->{OPTIONS} && $res->{OPTIONS} =~ m/disablewebmail=1/i) {
            return 1;
        }
        $self->{INFO} = $self->_fill_user_info($res);
        return 0;
    }
    -1; # default ?:)
}

sub change_passwd {
    my $self = shift;
    my ($user, $old, $new) = @_;
    my $socket = $self->{socket};
    my ($serv, $type) = ('extmail', 'login');

    printf($socket "PASSWD %s\t%s\t%s\t%s\n",
        $serv,
        $user,
        $old,
        $new
    );

    my $result = '';
    while (<$socket>) {
        $result .= $_;
    }

    return 0 unless $result;
    if ($result =~ /^OK/s) {
        return 1;
    }
    0;
}

sub can_change_info {
    return 0;
}

sub get_user_info {
    return;
}

sub change_info {
    return 0;
}

sub _fill_user_info {
    my $self = shift;
    my $info = $_[0];

    $info->{MAILDIR} ||= "$info->{HOME}/Maildir";
    if ($info->{OPTIONS} && $info->{OPTIONS}=~ m/netdiskquota=([^\,]+)/i) {
        $info->{NETDISKQUOTA} = $1;
    }
    if ($info->{OPTIONS} && $info->{OPTIONS} =~ m/disablenetdisk=1/i) {
        $info->{OPTIONS} = 'disablenetdisk';
    }
    $info;
}

sub DESTROY {
    my $self = shift;
    $self->{socket}->close if ($self->{socket});
}

1;
