# vim: set cindent expandtab ts=4 sw=4:
#
# Copyright (c) 1998-2005 Chi-Keung Ho. All rights reserved.
#
# This programe is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# ExtMan - web interface to manage virtual accounts
# $Id$
package Ext::MgrApp::Sysinfo;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
use Ext::Utils; # import url2str
use Ext::MgrApp;
use vars qw($lang_charset %lang_sys);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->register;
    $self->SUPER::init(@_);

    # ignore db/ldap connection initialize
    $self->{requires_login} = 0;

    return unless($self->valid||$self->permit);

    $self->add_methods(default => \&default);
    $self->{default_mode} = 'default';

    $self->_initme;

    unless($ENV{USERTYPE} eq 'admin') {
        $self->error('Access denied');
        return 0;
    }

    require Ext::Cmd::Client;
    my $cli = Ext::Cmd::Client->new(
        auth_code => $self->{sysconfig}->{SYS_CMDSERVER_AUTHCODE},
        peer => "unix:$self->{sysconfig}->{SYS_CMDSERVER_SOCK}",
    );
    $self->{client} = $cli;
    $self;
}

sub _initme {
    initlang($_[0]->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_sys );
}

sub default {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $cli = $self->{client};

    if (not $cli or $cli->error) {
        $tpl->assign(ERROR => $cli->error);
        return;
    }

    my %info = (
        os => '',
        kernel => '',
        hostname => '',
        cpu => '',
    );
    for my $param (keys %info) {
        $cli->send_cmd('os_info', $param);
        my $reply = $cli->readline;
        if (my $r = $cli->is_ok($reply)) {
            $info{$param} = $r;
        }
    }

    $cli->send_cmd('sysload');
    my $reply = $cli->readline;
    if (my $r = $cli->is_ok($reply)) {
        # 3:24PM  up 238 days,  3:11, 1 user, load averages: 0.06, 0.12, 0.06
        if ($r =~ /load average[s]*: (.*)/) {
            $info{sysload} = $1;
        }
        if ($r =~ /,\s*(\d+)\s*user[s]?,/) {
            $info{logon_users} = $1;
        }
        if ($r =~ /up (\d+) days/ || $r =~ /up ([^,]+),/) {
            $info{uptime} = $1;
        }
    }

    my $sys = $self->{sysconfig};
    my $lang = $sys->{SYS_LANG};
    my $dbtype = $sys->{SYS_BACKEND_TYPE} || 'unknown';
    my $crypt = $sys->{SYS_CRYPT_TYPE} || 'unknown';
    require Ext::Lang;

    $tpl->assign(
        SOFTNAME => 'ExtMail iServer',
        SOFTVER => $Ext::MgrApp::VERSION,
        LICENSE => 'GPLv2 - NonCommercial',
        DBTYPE => $dbtype,
        SYSLANG => $lang || guess_intl(),
        CRYPT => $crypt,
        CUR_USERNAME => $ENV{USERNAME},
        CUR_USERTYPE => $ENV{USERTYPE},
        OSTYPE => $info{os},
        KERNEL => $info{kernel},
        HOSTNAME => $info{hostname},
        CPU => $info{cpu},
        SYSLOAD => $info{sysload},
        LOGONUSERS => $info{logon_users},
        UPTIME => $info{uptime},
    );
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'sysinfo.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
