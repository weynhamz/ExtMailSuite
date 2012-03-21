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
package Ext::MgrApp::Login;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
# @EXPORT=@Ext::Session::EXPORT; # export for use
use Ext::MgrApp;
use Ext::Session;
use vars qw($lang_charset %lang_login);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->register;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    # XXX FIXME force to cleanup whatever it's ok or not
    if ($self->{query}->cgi('__mode') eq 'logout') {
        $self->{query}->set_cookie(
            name => 'webman_sid',
            value => '',
        );
        $self->{query}->send_cookie;
    }

    $self->add_methods(change_passwd => \&change_passwd);
    $self->add_methods(show_login => \&show_login);
    $self->add_methods(logout => \&logout);
    $self->add_methods(welcome => \&welcome);
    $self->{default_mode} = 'show_login';

    # dirty hack: init working path under valid session, and
    # cooperate with valid || permit mechanism, wait for fix
    # XXX FIXME
    $self->_initme;
    if($self->{query}->cgi('sid')) {
        return unless($self->valid_session); # check session
    }
    $self;
}

sub _initme {
    initlang($_[0]->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_login );
}

sub change_passwd {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $sys = $self->{sysconfig};
    my $mgr = $self->{backend};
    my $info = $mgr->get_manager_info($ENV{USERNAME});

    $tpl->assign(
        QUESTION => $info->{question},
        ANSWER => $info->{answer},
    );

    if ($info->{disablepwdchange}) {
        $tpl->assign( CHGPWD_FAIL => $lang_login{'pwd_nochange'});
        return;
    }
    return unless(my $oldpwd = $q->cgi('oldpw'));

    my $pass_fail = $lang_login{'change_passwd_fail'};
    my $pass_ok = $lang_login{'change_passwd_ok'};
    my $pass_short = $lang_login{'change_passwd_short'};

    if($mgr->auth($ENV{USERNAME}, $oldpwd)) {
        if ( ($q->cgi('newpw1') || $q->cgi('newpw2')) and
             ($q->cgi('newpw1') eq $q->cgi('newpw2')) ) {
            my $newpwd = $q->cgi('newpw1');
            return unless($self->{backend}); # prepare auth

            # check new password length
            if(length($newpwd) < $sys->{SYS_MIN_PASS_LEN}) {
                $pass_short = sprintf($pass_short, $sys->{SYS_MIN_PASS_LEN});
                $tpl->assign( CHGPWD_FAIL => $pass_short);
                return;
            }

            if($mgr->change_passwd($ENV{USERNAME}, $oldpwd, $newpwd)) {
                $tpl->assign( CHGPWD_OK => $pass_ok );
            }else {
                $tpl->assign( CHGPWD_FAIL => $pass_fail );
            }
        }
        $mgr->modify_manager(
            manager => lc $ENV{USERNAME},
            cn => $info->{cn},
            question => $q->cgi('question'),
            answer => $q->cgi('answer'),
            disablepwdchange => $info->{disablepwdchange} ? 1 : 0,
            expire => $info->{expire},
            active => $info->{active},
            domain => \@{$info->{domain}},
        );
    }else {
        $tpl->assign( CHGPWD_FAIL => $pass_fail );
    }
}

sub logout {
    my $self = shift;
    my $tpl = $self->{tpl};

    if (!kill_sid($self->{sid})) {
        $tpl->assign(ERR_LOGOUT=>"Config fail or ".$self->{sid}." not exists;");
    }else {
        $tpl->assign(LOGOUT_OK => 1);
    }
    $tpl->assign(LOGIN => 0);
    $tpl->assign(LOGOUT => 1);
}

sub show_login {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};

    $tpl->assign(LOGIN => 1);

    if ($self->valid_session) {
        $tpl->assign(ALREADY_LOGIN =>1);
    } else {
        if (my $domain = $ENV{EXTMAIL_LOGINDOMAIN}) {
            $tpl->assign(LOGINDOMAIN => $domain);
        }

        if ($q->cgi("error") eq 'badlogin') {
            $tpl->assign(ERRMSG => $lang_login{'badlogin'} || 'Invalid account or password');
        } elsif ($q->cgi('error') eq 'vcode') {
            $tpl->assign(ERRMSG => $lang_login{'badvcode'} || 'Bad verify code');
        }
    }
}

sub welcome {
    my $self = shift;
    my $tpl = $self->{tpl};

    $tpl->assign(
        LOGIN => 0,
        LOGIN_RESULT => $lang_login{'login_ok'},
        SID => $self->{sid}
    );
}

sub pre_run {
    # set sent_headers is useful under FCGI/MOD_PERL env, but this mechanism
    # should be waited for fix
    # $_[0]->{tpl}->clear; clear will destory all tpl varibles
    $_[0]->{sent_headers} = 'text/html';
}

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'index.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
