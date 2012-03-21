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
package Ext::MgrApp::Sysctrl;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
use Ext::Utils; # import url2str
use Ext::MgrApp;
use vars qw($lang_charset %lang_sys @srv);
use Ext::Lang;

@srv = ('mta', 'web', 'fcgi', 'slockd', 'dspam', 'mysql', 'ldap');

sub init {
    my $self = shift;
    $self->register;
    $self->SUPER::init(@_);

    # ignore db/ldap connection initialize
    $self->{requires_login} = 0;

    return unless($self->valid||$self->permit);

    $self->add_methods(showall => \&showall);
    $self->add_methods(srvctrl => \&srvctrl);
    $self->{default_mode} = 'showall';

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

    my $list = $self->{sysconfig}->{SYS_IGNORE_SERVER_LIST};
    if ($list) {
        my @ilist = split(/,/, $list);
        $self->{ignore_list} = \@ilist;
    }
    $self;
}

sub _initme {
    initlang($_[0]->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_sys );
}

sub showall {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $cli = $self->{client};

    if (not $cli or $cli->error) {
        $tpl->assign(ERROR => $cli->error);
        return;
    }

    my %stat = ();
    my $ignlist = $self->{ignore_list};
    for my $cmd (@srv) {
        $cli->send_cmd($cmd .'_status');
        my $reply = $cli->readline;
        if ($cli->is_ok($reply)) {
            $stat{$cmd} = 'ok';
        } else {
            $stat{$cmd} = 'fail';
        }
        my $ignore = 0;
        if ($ignlist && ref $ignlist) {
            $ignore = 1 if (grep (/^$cmd$/, @$ignlist));
        }
        $tpl->assign(
            'LOOP_SRVCTRL',
            SRVOK => $stat{$cmd} eq 'ok' ? 1 : 0,
            IGNORE => $ignore,
            SRVNAME => ucfirst $cmd,
            SRVDESC => $lang_sys{"sys_$cmd"} || $cmd,
            SRVSYMBOL => $cmd,
        );
    }
    $tpl->assign(TOTAL_SERVER => scalar @srv);
}

sub srvctrl {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $cli = $self->{client};

    if (my $action = $q->cgi('action')) {
        my $name = $q->cgi('srvname');
        if (not grep (/^$name$/, @srv)) {
            $tpl->assign(ERROR => "No such server: $name");
        } else {
            if (not $cli or $cli->error) {
                $tpl->assign(ERROR => $cli->error);
                return;
            }

            my $ignlist = $self->{ignore_list};
            if ($ignlist && ref $ignlist && grep (/^$name$/, @$ignlist)) {
                $tpl->assign(ERROR => 'Operation not permit!');
                $self->showall;
                return;
            }
            $cli->send_cmd($name . "_" . $action);
            my $reply = $cli->readline;
            if ($cli->is_ok($reply)) {
                $tpl->assign(SUCCESS => 'Command send ok');
            } else {
                $tpl->assign(ERROR => 'Command send fail');
            }
        }
    } else {
        $tpl->assign(ERROR => 'No action specify');
    }
    $self->showall;
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'sysctrl.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
