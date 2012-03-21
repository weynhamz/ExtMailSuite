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
package Ext::MgrApp::ChangePwd;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
use Ext::Utils; # import url2str
use Ext::MgrApp;
use Ext::CaptCha;
use vars qw($lang_charset %lang_changepwd);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->register;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(step1 => \&step1);   # show main windowverify username
    $self->add_methods(step2 => \&step2);    # verify username
    $self->add_methods(dosave => \&dosave); # verify answer and question, change pwd
    $self->{default_mode} = 'step1';

    $self->_initme;
    $self;
}

sub _initme {
    initlang($_[0]->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_changepwd );
}

sub step1 {
    my $self = shift;
    my $tpl = $self->{tpl};

    $tpl->assign(  STEP1 => 1 );
}

sub step2 {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $user = $q->cgi('username');
    my $ui = $mgr->get_user_info($user);

    if (!$ui) {
        $tpl->assign(
            ERROR => "No such $user",
            STEP1 => 1,
        );
        return;
    } elsif ($ui->{disablepwdchange}) {
        $tpl->assign(
            ERROR => "$user ". $lang_changepwd{'errpwd_nochange'},
            STEP1 => 1,
        );
        return;
    }

    $tpl->assign(
        STEP2 => 1,
        USERNAME => $ui->{mail},
        MAIL => $ui->{mail},
        NAME => $ui->{cn} || $ui->{username},
    );
}

sub dosave {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $user = lc $q->cgi('username');
    my $username = $user;
    my ($domain) = ($user =~ m!.*@(.*)!);
    my $sys = $self->{sysconfig};

    $user =~ s/@.*$//;

    if (!$self->sanity_username($user)) {
        $self->error('Bad username');
        return 0;
    }

    if (my $ui = $mgr->get_user_info("$user\@$domain")) {
        # save the change
        my $pwd1 = $q->cgi('passwd1');
        my $pwd2 = $q->cgi('passwd2');

        if ( !$pwd1 or !$pwd2 or ($pwd1 ne $pwd2) ) {
            # pwd1 != pwd2, password modification fail, abort
            $tpl->assign(ERROR => $lang_changepwd{'errinput_passwd'});
            $self->step2;
            return 0;
        }

        if ($ui->{disablepwdchange}) {
            $tpl->assign(ERROR => 'Not permit to change password');
            $tpl->assign(STEP3 => 1);
            return 0;
        }

        if ($sys->{SYS_CAPTCHA_ON}) {
            my $data = $q->get_cookie('scode');
            my $raw = $q->cgi('vcode'); # verify code
            my $key = $sys->{SYS_CAPTCHA_KEY} || 'extmail';
            my $cap = Ext::CaptCha->new(key => $key);

            if (!$cap->verify(lc $raw, $data)) {
                $tpl->assign(ERROR => $lang_changepwd{'err_vcode'}||'Bad verify Code');
                $self->step2;
                return 0;
            }
        }

        my $oldpwd = $q->cgi('oldpasswd');
        my $type = uc $sys->{SYS_CRYPT_TYPE};
        my $p2 = $ui->{passwd};
        my $pwd = Ext::Passwd->new( fallback_scheme => $type );
        my $rv = $pwd->verify($oldpwd, $p2);
        my $rc;

        if($rv){
            $rc = $mgr->modify_user(
            user => "$user\@$domain",
            domain => $domain,
            cn => $ui->{'cn'},
            uidnumber => $ui->{'uidnumber'},
            gidnumber => $ui->{'gidnumber'},
            expire => $ui->{'expire'},
            passwd => $pwd2,
            quota => $ui->{'quota'},
            netdiskquota => $ui->{'netdiskquota'},
            active => $ui->{'active'},
            disablepwdchange => $ui->{'disablepwdchange'} ? 1 : 0,
            disablesmtpd => $ui->{'disablesmtpd'} ? 1 : 0,
            disablesmtp => $ui->{'disablesmtp'} ? 1 : 0,
            disablewebmail => $ui->{'disablewebmail'} ? 1 : 0,
            disablenetdisk => $ui->{'disablenetdisk'} ? 1 : 0,
            disablepop3 => $ui->{'disablepop3'} ? 1 : 0,
            disableimap => $ui->{'disableimap'} ? 1 : 0,
            question => $ui->{question},
            answer => $ui->{answer},
            ) unless ($rc);
        }else{
            $tpl->assign(ERROR => $lang_changepwd{'auth_vcode'}||'Auth Faild');
            $self->step2;
            return 0;
        }
        if ($rc) {
            $tpl->assign(ERROR => sprintf($lang_changepwd{'modify_fail'}, $q->cgi('username')).$rc);
            $tpl->assign(STEP2 => 1);
        }else {
            $tpl->assign(SUCCESS => sprintf($lang_changepwd{'modify_ok'}, $q->cgi('username')));
            $tpl->assign(STEP3 => 1);
        }
    } else {
        # no such user
        $tpl->assign(ERROR => $lang_changepwd{'no_such_user'});
        $tpl->assign(STEP2 => 1);
    }
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'changepwd.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
