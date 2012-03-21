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
package Ext::MgrApp::Domain;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
use POSIX qw(strftime);
use Ext::Utils; # import url2str
use Ext::MgrApp;
use vars qw($lang_charset %lang_domain $default_expire $nowdate);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(add_domain => \&add_domain);
    $self->add_methods(edit_domain => \&edit_domain);
    $self->add_methods(save_domain => \&save_domain);
    $self->add_methods(delete_domain => \&delete_domain);
    $self->{default_mode} = 'edit_domain';

    $self->_initme;

    # permission validation
    if ($ENV{USERTYPE} ne 'admin') {
        $self->error('Access denied');
        return 0;
    }

    $nowdate = strftime("%Y-%m-%d", localtime);
    $self->{tpl}->assign(NOWDATE => $nowdate);
    $default_expire = '0000-00-00';
    $self;
}

sub _initme {
    initlang($_[0]->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_domain );
}

sub add_domain {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $sys = $self->{sysconfig};

    $tpl->assign(
        HAVE_DOMAIN => 1,
        NEWADD => 1,
        ACTIVE => 1,
        MAXQUOTA => $sys->{SYS_DEFAULT_MAXQUOTA},
        MAXALIAS => $sys->{SYS_DEFAULT_MAXALIAS} || '0',
        MAXUSERS => $sys->{SYS_DEFAULT_MAXUSERS} || '0',
        MAXNDQUOTA => $sys->{SYS_DEFAULT_MAXNDQUOTA},
        DEFAULT_QUOTA => $sys->{SYS_USER_DEFAULT_QUOTA} || '5',
        DEFAULT_NDQUOTA => $sys->{SYS_USER_DEFAULT_NDQUOTA} || '5',
        EXPIRE => $default_expire,
    );

    for my $s ( split(/,/, $sys->{SYS_DEFAULT_SERVICES}) ) {
        $tpl->assign(
            "SERVICES_$s" => 1,
        );
    }
    $tpl->assign(DEFAULT_EXPIRE => $sys->{SYS_USER_DEFAULT_EXPIRE} || '1y');
}

sub edit_domain {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $multiplier = $self->{sysconfig}->{SYS_QUOTA_MULTIPLIER} || '1048576';

    my $di = $mgr->get_domain_info(lc $q->cgi('domain'));
    return 0 unless ($di);

    use Data::Dumper;
    $tpl->assign(HAVE_DOMAIN => 1);
    $tpl->assign(
        MAXUSERS => $di->{maxusers},
        MAXQUOTA => $self->quota2num($di->{maxquota})/$multiplier,
        MAXALIAS => $di->{maxalias},
        VDOMAIN => $di->{domain},
        TRANSPORT => $di->{transport},
        CANSIGNUP => ($di->{can_signup} ? 1 : 0 ),
        DEFAULT_QUOTA => $self->quota2num($di->{default_quota})/$multiplier,
        DEFAULT_NDQUOTA => $self->quota2num($di->{default_ndquota})/$multiplier,
        DEFAULT_EXPIRE => $di->{default_expire},
        EXPIRE => $di->{expire} || $default_expire,
        DESCRIPTION => $di->{description},
        MAXNDQUOTA => $self->quota2num($di->{maxndquota})/$multiplier,
        ACTIVE => $di->{active},
    );
    for my $srv (qw(smtpd smtp webmail netdisk imap pop3)) {
        if (!$di->{"disable$srv"}) {
            $tpl->assign( 'SERVICES_'.$srv => 1 );
        } else {
            $tpl->assign( 'SERVICES_'.$srv => 0 );
        }
    }
}

sub save_domain {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $multiplier = $self->{sysconfig}->{SYS_QUOTA_MULTIPLIER} || '1048576';

    my $domain = lc $q->cgi('domain');

    if (!$self->sanity_username($domain)) {
        $self->error("Bad domain name");
        return 0;
    }

    if ($q->cgi('defaultexpire') !~ /^\d+[mydw]$/) {
        $self->error("Bad default expire value");
        return;
    }

    if ($mgr->get_domain_info($domain)) {
        if ($q->cgi('newadd')) {
            $tpl->assign(ERROR => sprintf($lang_domain{'domain_exist'}, $domain));
            $self->add_domain;
            return 0;
        } else {
            if (!$self->valid_time($q->cgi('expire'))) {
                $tpl->assign(ERROR => $lang_domain{'err_time'});
                $self->edit_domain;
                return;
            }

            my $rc = $mgr->modify_domain(
                domain => $domain,
                description => $q->cgi('description'),
                maxusers => $q->cgi('maxusers'),
                maxalias => $q->cgi('maxalias'),
                maxquota => $self->num2quota($multiplier*$q->cgi('maxquota')),
                maxndquota => $self->num2quota($multiplier*$q->cgi('maxndquota')),
                transport => $q->cgi('transport'),
                can_signup => $q->cgi('cansignup') ? 1 : 0,
                default_quota => $self->num2quota($multiplier*$q->cgi('defaultquota')),
                default_ndquota => $self->num2quota($multiplier*$q->cgi('defaultndquota')),
                default_expire => $q->cgi('defaultexpire'),
                disablesmtpd => $q->cgi('SERVICES_smtpd') ? 0 : 1,
                disablesmtp => $q->cgi('SERVICES_smtp') ? 0 : 1,
                disablewebmail => $q->cgi('SERVICES_webmail') ? 0 : 1,
                disablenetdisk => $q->cgi('SERVICES_netdisk') ? 0 : 1,
                disablepop3 => $q->cgi('SERVICES_pop3') ? 0 : 1,
                disableimap => $q->cgi('SERVICES_imap') ? 0 : 1,
                expire => $q->cgi('expire'),
                active => $q->cgi('active'),
            );

            if ($rc) {
                $tpl->assign(ERROR => sprintf($lang_domain{'modify_fail'}, $domain).$rc);
            } else {
                $tpl->assign(SUCCESS => sprintf($lang_domain{'modify_ok'}, $domain));
            }
            $self->edit_domain;
        }
    } else {
        if ($q->cgi('newadd')) {
            my $description = $q->cgi('description') || sprintf($lang_domain{'default_description'}, $domain);

            if (!$self->valid_time($q->cgi('expire'))) {
                $tpl->assign(ERROR => $lang_domain{'err_time'});
                $self->add_domain;
                return;
            }

            my $rc = $mgr->add_domain(
                domain => $domain,
                description => $description,
                hashdirpath => $self->gen_domain_hashdir(),
                maxusers => $q->cgi('maxusers'),
                maxalias => $q->cgi('maxalias'),
                maxquota => $self->num2quota($multiplier*$q->cgi('maxquota')),
                maxndquota => $self->num2quota($multiplier*$q->cgi('maxndquota')),
                transport => $q->cgi('transport'),
                can_sign => $q->cgi('cansignup') ? 1 : 0,
                default_quota => $self->num2quota($multiplier*$q->cgi('defaultquota')),
                default_ndquota => $self->num2quota($multiplier*$q->cgi('defaultndquota')),
                default_expire => $q->cgi('defaultexpire'),
                disablesmtpd => $q->cgi('SERVICES_smtpd') ? 0 : 1,
                disablesmtp => $q->cgi('SERVICES_smtp') ? 0 : 1,
                disablewebmail => $q->cgi('SERVICES_webmail') ? 0 : 1,
                disablenetdisk => $q->cgi('SERVICES_netdisk') ? 0 : 1,
                disablepop3 => $q->cgi('SERVICES_pop3') ? 0 : 1,
                disableimap => $q->cgi('SERVICES_imap') ? 0 : 1,
                expire => $q->cgi('expire'),
                create => strftime("%Y-%m-%d %H:%M:%S", localtime),
                active => $q->cgi('active'),
            );

            if ($rc) {
                $tpl->assign(ERROR => sprintf($lang_domain{'add_fail'}, $domain).$rc);
            } else {
                $tpl->assign(SUCCESS => sprintf($lang_domain{'add_ok'}, $domain));
            }
            $self->add_domain;
        } else {
            $tpl->assign(ERROR => $lang_domain{'no_such_domain'});
        }
    }
}

sub delete_domain {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $mgr = $self->{backend};
    my $domain = lc $q->cgi('domain');

    if ($mgr->get_domain_info($domain)) {
        # could not delete a domain that associate alias or users
        if ($mgr->get_aliases_list($domain)) {
            $tpl->assign(
                ERROR => sprintf($lang_domain{'delete_fail_alias'}, $domain),
                OLDURL => $q->cgi('url'),
            );
            return 0;
        }

        if ($mgr->get_users_list($domain)) {
            $tpl->assign(
                ERROR => sprintf($lang_domain{'delete_fail_user'}, $domain),
                OLDURL => $q->cgi('url'),
            );
            return 0;
        }

        my $rc = $mgr->delete_domain($domain);
        if ($rc) {
            $tpl->assign(
                ERROR => sprintf($lang_domain{'delete_fail'},$domain).$rc,
                OLDURL => $q->cgi('url'),
            );
        } else {
            $tpl->{noprint} = 1;
            $self->{redirect} = url2str($q->cgi('url'));
        }
    } else {
        $tpl->assign(ERROR => $lang_domain{'no_such_domain'});
    }
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'edit_domain.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
