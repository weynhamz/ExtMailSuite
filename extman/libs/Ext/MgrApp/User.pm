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
package Ext::MgrApp::User;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
use POSIX qw(strftime);
use Ext::Utils; # import url2str
use Ext::MgrApp;
use vars qw($lang_charset %lang_user $default_expire $nowdate);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(add_user => \&add_user);
    $self->add_methods(edit_user => \&edit_user);
    $self->add_methods(save_user => \&save_user);
    $self->add_methods(delete_user => \&delete_user);
    $self->{default_mode} = 'edit_user';

    $default_expire = '0000-00-00';
    $nowdate = strftime("%Y-%m-%d", localtime);
    $self->{tpl}->assign(NOWDATE => $nowdate);
    $self->_initme;
    $self;
}

sub _initme {
    initlang($_[0]->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_user );
}

sub add_user {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $sys = $self->{sysconfig};
    my $domain = lc $q->cgi('domain');
    my $domains = [];

    if ($ENV{USERTYPE} eq 'admin') {
        my $alldomain = $mgr->get_domains_list;
        foreach my $d ( @$alldomain ) {
            push @$domains, $d->{domain};
        }
    } else {
        my $pm = $mgr->get_manager_info($ENV{USERNAME});
        $domains = $pm->{domain};
    }

    if (!$domain) {
        $domain = $domains->[0]; # the first?
    }

    my $info = $mgr->get_domain_info($domain);

    if (keys %$info) {
        my $multiplier = $self->{sysconfig}->{SYS_QUOTA_MULTIPLIER} || '1048576';

        if ($info->{default_quota}) {
            $info->{default_quota} = $self->quota2num($info->{default_quota})/$multiplier;
        }
        if ($info->{default_ndquota}) {
            $info->{default_ndquota} = $self->quota2num($info->{default_ndquota})/$multiplier;
        }
    }

    $tpl->assign(
        HAVE_USER => 1,
        NEWADD => 1,
        EXPIRE => $default_expire,
        ACTIVE => 1,
        QUOTA => $info->{default_quota} || $sys->{SYS_USER_DEFAULT_QUOTA} || '0',
        NDQUOTA => $info->{default_ndquota} || $sys->{SYS_USER_DEFAULT_NDQUOTA} || '0',
        UID => $sys->{SYS_DEFAULT_UID},
        GID => $sys->{SYS_DEFAULT_GID},
    );

    for my $s ( split(/,/, $sys->{SYS_USER_ROUTING_LIST}) ) {
        $s =~ s/\s+//;
        $tpl->assign(
            'LOOP_ROUTING_LIST',
            MAILHOST => $s,
        );
    }

    if (keys %$info) {
        for my $s (qw(smtpd smtp webmail netdisk imap pop3)) {
            $tpl->assign( "SERVICES_$s" => $info->{"disable".$s} ? 0 : 1 );
            $tpl->assign( "NOCHK_$s" => $info->{"disable".$s} ? 1 : 0 )
                if ($ENV{USERTYPE} ne 'admin');
        }
    } else {
        for my $s ( split(/,/, $sys->{SYS_DEFAULT_SERVICES}) ) {
            $tpl->assign( "SERVICES_$s" => 1 );
        }
    }

    if ($domains) {
        $domains = [$domains] unless (ref $domains);
        foreach my $vd ( @$domains ) {
            $tpl->assign(
                'LOOP_DOMAIN',
                DOMAIN => $vd,
                DOMAIN_CHK => ($vd eq lc $domain ? 1 : 0),
            );
        }
    } else {
        # no permission or not assign domain
        $tpl->assign(NOPERM => 1);
        $tpl->assign(HAVE_USER => 0);
    }
}

sub edit_user {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $multiplier = $self->{sysconfig}->{SYS_QUOTA_MULTIPLIER} || '1048576';
    my $user = $q->cgi('user') || $q->cgi('username').'@'.$q->cgi('domain');
    my $ui = $mgr->get_user_info($user);

    return 0 unless($ui);

    # permission validation
    unless ($self->valid_perm($ui->{domain})) {
        $self->error('Access denied');
        return 0;
    }

    my ($uname) = ($ui->{mail} =~ m!(.*)@.*!);

    $tpl->assign(HAVE_USER => 1);
    $tpl->assign(
        MAIL => $ui->{mail},
        UNAME => $uname,
        NAME => $ui->{cn} || $ui->{username},
        DOMAIN => $ui->{domain},
        MAILHOST => $ui->{mailhost},
        UID => $ui->{uidnumber},
        GID => $ui->{gidnumber},
        EXPIRE => $ui->{expire},
        PASSWD => "",
        CLEARPWD => $ui->{clearpw},
        QUOTA => $self->quota2num($ui->{quota})/$multiplier,
        NDQUOTA => $self->quota2num($ui->{netdiskquota})/$multiplier,
        ACTIVE => $ui->{active},
        DISABLEPWDCHANGE => $ui->{disablepwdchange},
        QUESTION => $ui->{question},
        ANSWER => $ui->{answer},
    );

    if ($ENV{USERTYPE} ne 'admin') {
        $tpl->assign(CAN_VIEW_CLEARPWD => 0);
    } else {
        $tpl->assign(CAN_VIEW_CLEARPWD => 1);
    }

    my $info = $mgr->get_domain_info($ui->{domain});
    for my $srv (qw(smtpd smtp webmail netdisk imap pop3)) {
        $tpl->assign( 'SERVICES_'.$srv => $ui->{"disable$srv"} ? 0 : 1 );
        $tpl->assign( 'NOCHK_'.$srv => $info->{"disable$srv"} ? 1 : 0 )
            if ($ENV{USERTYPE} ne 'admin');
    }
}

sub save_user {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $multiplier = $self->{sysconfig}->{SYS_QUOTA_MULTIPLIER} || '1048576';
    my ($user, $domain) = (lc $q->cgi('username'), lc $q->cgi('domain'));

    # permission validation
    unless ($self->valid_perm($domain)) {
        $self->error('Access denied');
        return 0;
    }

    if (!$self->sanity_username($user)) {
        $self->error('Bad username');
        return 0;
    }

    if (!$self->valid_expire($domain, $q->cgi('expire'))) {
        $tpl->assign(ERROR => $lang_user{'err_expire'});
        $self->edit_user;
        return 0;
    }

    if ($mgr->get_user_info("$user\@$domain")) {
        if ($q->cgi('newadd')) {
            $tpl->assign(ERROR => $lang_user{'user_exist'});
            $self->add_user;
            return 0;
        }else {
            # save the change
            my $pwd1 = $q->cgi('passwd1');
            my $pwd2 = $q->cgi('passwd2');

            if ($pwd1 ne $pwd2) {
                # pwd1 != pwd2, password modification fail, abort
                $tpl->assign(ERROR => $lang_user{'errinput_passwd'});
                return 0;
            }

            if (!$self->valid_time($q->cgi('expire'))) {
                $tpl->assign(ERROR => $lang_user{'err_time'});
                $self->edit_user;
                return;
            }

            my $old = $mgr->get_user_info("$user\@$domain");
            my $oldquota = $self->quota2num($old->{quota});
            my $oldndquota = $self->quota2num($old->{netdiskquota});
            my $newquota = $multiplier*$q->cgi('quota'); # number
            my $newndquota = $multiplier*$q->cgi('netdiskquota'); # number

            #die "$newndquota $oldndquota\n";
            my $rc = $self->domain_overusage(
                domain => $domain,
                quota => ($newquota - $oldquota > 0 ? $newquota - $oldquota : 0 ),
                ndquota => ($newndquota - $oldndquota > 0 ? $newndquota - $oldndquota : 0 ),
            );

            $rc = $mgr->modify_user(
                user => "$user\@$domain",
                domain => $domain,
                cn => $q->cgi('cn'),
                uidnumber => $q->cgi('uid'),
                gidnumber => $q->cgi('gid'),
                expire => $q->cgi('expire'),
                passwd => $pwd1,
                quota => $self->num2quota($multiplier*$q->cgi('quota')),
                netdiskquota => $self->num2quota($multiplier*$q->cgi('netdiskquota')),
                active => $q->cgi('active'),
                disablepwdchange => $q->cgi('disablepwdchange') ? 1 : 0,
                disablesmtpd => $q->cgi('SERVICES_smtpd') ? 0 : 1,
                disablesmtp => $q->cgi('SERVICES_smtp') ? 0 : 1,
                disablewebmail => $q->cgi('SERVICES_webmail') ? 0 : 1,
                disablenetdisk => $q->cgi('SERVICES_netdisk') ? 0 : 1,
                disablepop3 => $q->cgi('SERVICES_pop3') ? 0 : 1,
                disableimap => $q->cgi('SERVICES_imap') ? 0 : 1,
                question => $q->cgi('question'),
                answer => $q->cgi('answer'),
            ) unless ($rc);

            if ($rc) {
                $tpl->assign(ERROR => sprintf($lang_user{'modify_fail'}, $q->cgi('username')).$rc);
            }else {
                $tpl->assign(SUCCESS => sprintf($lang_user{'modify_ok'}, $q->cgi('username')));
            }
            $self->edit_user;
        }
    } else {
        # no such user
        if ($q->cgi('newadd')) {
            # new add user
            my $pwd1 = $q->cgi('passwd1');
            my $pwd2 = $q->cgi('passwd2');

            # include all possible state:
            # 1) pwd1 null, pwd2 not null
            # 2) pwd2 null, pwd1 not null
            # 3) pwd2 and pwd1 not null, but not eq
            if ((!$pwd1 or !$pwd2) or ($pwd1 ne $pwd2)) {
                $tpl->assign(ERROR => $lang_user{'errinput_passwd'});
                return 0;
            }

            if (!$self->valid_time($q->cgi('expire'))) {
                $tpl->assign(ERROR => $lang_user{'err_time'});
                $self->add_user;
                return;
            }

            my $rc = $self->domain_overusage(
                domain => $domain,
                quota => $multiplier*$q->cgi('quota'),
                user => 1, # new add, must exists
                ndquota => $multiplier*$q->cgi('netdiskquota'),
            );

            my $d_hashdir = $self->get_domain_hashdir($domain);
            my $u_hashdir = $self->gen_user_hashdir;
            my $path;
            if ($self->{sysconfig}->{SYS_ISP_MODE} eq 'yes') {
                $path = ($d_hashdir ? "$d_hashdir/" : "").
                        "$domain/" .($u_hashdir? "$u_hashdir/" : "").
                        $user;
            } else {
                $path = "$domain/$user";
            }

            $rc = $mgr->add_user(
                mail => "$user\@$domain",
                domain => $domain,
                uid => $user,
                cn => $q->cgi('cn'),
                uidnumber => $q->cgi('uid'),
                gidnumber => $q->cgi('gid'),
                # new user attributes here
                create => strftime("%Y-%m-%d %H:%M:%S", localtime),
                expire => $q->cgi('expire'),
                passwd => $pwd1,
                quota => $self->num2quota($multiplier*$q->cgi('quota')),
                mailhost => $q->cgi('mailhost'),
                maildir => "$path/Maildir/",
                homedir => $path,
                netdiskquota => $self->num2quota($multiplier*$q->cgi('netdiskquota')),
                active => $q->cgi('active'),
                disablepwdchange => $q->cgi('disablepwdchange') ? 1 : 0,
                disablesmtpd => $q->cgi('SERVICES_smtpd') ? 0 : 1,
                disablesmtp => $q->cgi('SERVICES_smtp') ? 0 : 1,
                disablewebmail => $q->cgi('SERVICES_webmail') ? 0 : 1,
                disablenetdisk => $q->cgi('SERVICES_netdisk') ? 0 : 1,
                disablepop3 => $q->cgi('SERVICES_pop3') ? 0 : 1,
                disableimap => $q->cgi('SERVICES_imap') ? 0 : 1,
                question => $q->cgi('question'),
                answer => $q->cgi('answer'),
            ) unless ($rc);

            if ($rc) {
                $tpl->assign(ERROR => sprintf($lang_user{'add_fail'}, "$user\@$domain").$rc);
            } else {
                $tpl->assign(SUCCESS => sprintf($lang_user{'add_ok'}, "$user\@$domain"));
                my $dir = $self->{sysconfig}->{SYS_CONFIG};
                my $base = $self->{sysconfig}->{SYS_MAILDIR_BASE};
                system("$dir/tools/maildirmake.pl $base/$path/Maildir/");
            }
            $self->add_user;
        } else {
            $tpl->assign(ERROR => $lang_user{'no_such_user'});
        }
    }
}

sub delete_user {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $mgr = $self->{backend};
    my $user = lc $q->cgi('user');

    my ($domain) = ($user =~ m!.*@(.*)!);
    # permission validation
    unless ($self->valid_perm($domain)) {
        $self->error('Access denied');
        return 0;
    }

    if (my $ui = $mgr->get_user_info($user)) {
        my $base = $self->{sysconfig}->{SYS_MAILDIR_BASE};
        my $dir = $self->{sysconfig}->{SYS_CONFIG};
        my $path = $base .'/'.$ui->{homedir};

        my $rc = $mgr->delete_user($user);

        if ($rc) {
            $tpl->assign(ERROR => "Delete fail!");
        } else {
            if ($q->cgi('purge')) {
                # complete delete mailbox data from disk!
                system("$dir/tools/purgeuser.pl $path");
            }
            $tpl->{noprint} = 1;
            $self->{redirect} = url2str($q->cgi('url'));
        }
    } else {
        $tpl->assign(ERROR => $lang_user{'no_such_user'});
    }
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'edit_user.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
