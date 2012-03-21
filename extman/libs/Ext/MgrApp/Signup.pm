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
package Ext::MgrApp::Signup;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
use POSIX qw(strftime);
use Ext::Utils; # import url2str
use Ext::MgrApp;
use Ext::CaptCha;
use vars qw($lang_charset %lang_signup);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->register;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(step1 => \&step1);
    $self->add_methods(step2 => \&step2);
    $self->add_methods(do_signup => \&do_signup);
    $self->{default_mode} = 'step1';
    $self->_initme;
    $self->{tpl}->assign( DOMAIN => $self->{query}->cgi('domain') );

    $self;
}

sub _initme {
    initlang($_[0]->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_signup );
}

sub check {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $domain = $q->cgi('domain');

    if (!$domain) {
        $tpl->assign( ERROR => $lang_signup{'err_domain'} );
        return;
    }

    my $info = $mgr->get_domain_info($domain);
    if (!$info) {
        $tpl->assign( ERROR => sprintf($lang_signup{'err_nosuch_domain'}, $domain) );
        return;
    }

    if (!$info->{can_signup}) {
        $tpl->assign( ERROR => sprintf($lang_signup{'err_nosignup'}, $domain) );
        return;
    }
    $self->{_curinfo} = $info;
}

sub step1 {
    my $self = shift;
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $tpl = $self->{tpl};

    $self->check;
    $tpl->assign( STEP1 => 1);
}

sub step2 {
    my $self = shift;
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my ($user, $domain) = (lc $q->cgi('username'), lc $q->cgi('domain'));

    if (!$self->check) {
        $tpl->assign(STEP1 => 1);
        return 0;
    }

    if (!$self->sanity_username($user)) {
        $tpl->assign(ERROR => $lang_signup{'bad_username'});
        $tpl->assign(DOMAIN => $domain);
        $tpl->assign(STEP1 => 1);
        return 0;
    }

    if ($mgr->get_user_info("$user\@$domain")) {
        $tpl->assign(ERROR => sprintf($lang_signup{'user_exist'}, $user));
        $self->step1;
        return 0;
    }

    $tpl->assign(
        STEP2 => 1,
        USERNAME => $user,
        SUCCESS => sprintf($lang_signup{hint_can_signup}, "$user"),
    );
}

sub do_signup {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $multiplier = $self->{sysconfig}->{SYS_QUOTA_MULTIPLIER} || '1048576';
    my ($user, $domain) = (lc $q->cgi('username'), lc $q->cgi('domain'));
    my $sys = $self->{sysconfig};

    # recall step 1 again
    $self->check;

    if (!$self->sanity_username($user)) {
        $tpl->assign(ERROR => $lang_signup{'bad_username'});
        $tpl->assign(STEP1 => 1); # goto step1
        $tpl->assign(DOMAIN => $domain);
        return 0;
    }

    if ($mgr->get_user_info("$user\@$domain")) {
        $tpl->assign(ERROR => sprintf($lang_signup{'user_exist'}, $user));
        $self->step1;
        return 0;
    } else {
        # new add user
        my $info = $self->{_curinfo}; # XXX current domain info structure
        my $pwd1 = $q->cgi('passwd1');
        my $pwd2 = $q->cgi('passwd2');

        $tpl->assign(
            NAME => $q->cgi('cn'),
            DOMAIN => $domain,
            USERNAME => $user,
        );
        # include all possible state:
        # 1) pwd1 null, pwd2 not null
        # 2) pwd2 null, pwd1 not null
        # 3) pwd2 and pwd1 not null, but not eq
        # 4) pwd1 null, pwd2 null
        if ( (!$pwd1 and !$pwd2) or ($pwd1 ne $pwd2) ) {
            $tpl->assign(ERROR => $lang_signup{'errinput_passwd'});
            $tpl->assign(STEP2 => 1);
            return 0;
        }

        if (!$q->cgi('cn')) {
            $tpl->assign(ERROR => $lang_signup{'errinput_cn'});
            $tpl->assign(STEP2 => 1);
            return 0;
        }

        if ($sys->{SYS_CAPTCHA_ON}) {
            my $data = $q->get_cookie('scode');
            my $raw = $q->cgi('vcode'); # verify code
            my $key = $sys->{SYS_CAPTCHA_KEY} || 'extmail';
            my $cap = Ext::CaptCha->new(key => $key);

            if (!$cap->verify(lc $raw, $data)) {
                $tpl->assign(ERROR => $lang_signup{'err_vcode'}||'Bad verify Code');
                $tpl->assign(STEP2 => 1);
                return 0;
            }
        }

        my $rc = $self->domain_overusage(
            domain => $domain,
            quota => $info->{default_quota} || $self->num2quota(5*$multiplier),
            user => 1, # new add, must exists
            ndquota => $info->{default_ndquota} || $self->num2quota(5*$multiplier),
        );

        my $d_hashdir = $self->get_domain_hashdir($domain);
        my $u_hashdir = $self->gen_user_hashdir;
        my $path;
        if ($sys->{SYS_ISP_MODE} eq 'yes') {
            $path = ($d_hashdir ? "$d_hashdir/" : "").
            "$domain/" .($u_hashdir? "$u_hashdir/" : "").
                $user;
        } else {
            $path = "$domain/$user";
        }

        my $uid = $sys->{SYS_DEFAULT_UID};
        my $gid = $sys->{SYS_DEFAULT_GID};

        $rc = $mgr->add_user(
            mail => "$user\@$domain",
            domain => $domain,
            uid => $user,
            cn => $q->cgi('cn'),
            uidnumber => $uid,
            gidnumber => $gid,
            # new user attributes here
            create => strftime("%Y-%m-%d %H:%M:%S", localtime),
            expire => '0000-00-00', # set to unlimited/auto, then it will follow domain expire:)
            passwd => $pwd1,
            quota => $info->{default_quota} || $self->num2quota(5*$multiplier),
            maildir => "$path/Maildir/",
            homedir => $path,
            netdiskquota => $info->{default_ndquota} || $self->num2quota(5*$multiplier),
            active => 1,
            disablepwdchange => 0,
            disablesmtpd => $info->{disablesmtpd} ? 1 : 0,
            disablesmtp => $info->{disablesmtp} ? 1 : 0,
            disablewebmail => $info->{disablewebmail} ? 1 : 0,
            disablenetdisk => $info->{disablenetdisk} ? 1 : 0,
            disablepop3 => $info->{disablepop3} ? 1 : 0,
            disableimap => $info->{disableimap} ? 1 : 0,
        ) unless ($rc);

        if ($rc) {
            $tpl->assign(ERROR => sprintf($lang_signup{'add_fail'}, "$user\@$domain").$rc);
        } else {
            $tpl->assign(SUCCESS => sprintf($lang_signup{'add_ok'}, "$user\@$domain"));
            my $dir = $sys->{SYS_CONFIG};
            my $base = $sys->{SYS_MAILDIR_BASE};
            system("$dir/tools/maildirmake.pl $base/$path/Maildir/");
            $tpl->assign(STEP3 => 1);
        }
    }
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'signup.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
