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
package Ext::App::Login;
use strict;

@Ext::App::Login::ISA = qw( Ext::App );
use Ext::App;
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
            name => 'sid',
            value => '',
            expires => $self->{query}->expires('-1y'),
        );
        $self->{query}->send_cookie;
    }

    $self->add_methods(show_login => \&show_login);
    $self->add_methods(logout => \&logout);
    $self->add_methods(welcome => \&welcome);
    $self->{default_mode} = 'show_login';

    # dirty hack: init working path under valid session, and
    # cooperate with valid || permit mechanism, wait for fix
    # XXX FIXME
    if($self->{query}->cgi('sid')) {
        return unless($self->valid_session); # check session
        Ext::Storage::Maildir::init($self->get_working_path);
    }
    $self->_initme;
    $self;
}

sub _initme {
    initlang($_[0]->userconfig->{lang}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_login );
}

sub logout {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};

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
        my $error = $q->cgi('error');

        if (my $domain = $ENV{EXTMAIL_LOGINDOMAIN}) {
            $tpl->assign(LOGINDOMAIN => $domain);
        }

        return unless $error;
        if ($error eq 'badlogin') {
            $tpl->assign(ERRMSG => $lang_login{invalid_login} ||
                'Invalid email account or password');
        } elsif ($error eq 'disabled') {
            $tpl->assign(ERRMSG => $lang_login{login_disabled} ||
                'Your account disabled for webmail');
        } elsif ($error eq 'deactive') {
            $tpl->assign(ERRMSG => $lang_login{login_deactive} ||
                'Your account is deactive now');
        } else {
            $tpl->assign(ERRMSG => $lang_login{bad_login} ||
                'Bad login or invalid return code');
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
