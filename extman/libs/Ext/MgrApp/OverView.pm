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
package Ext::MgrApp::OverView;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
use Ext::MgrApp;
use vars qw($lang_charset %lang_overview);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(overview => \&overview); # overview domain
    $self->add_methods(overview_user => \&overview_user);
    $self->add_methods(overview_alias => \&overview_alias);
    $self->add_methods(overview_manager => \&overview_manager);
    $self->{default_mode} = 'overview';

    if ($self->{query}->cgi('domain') || $self->{query}->get_cookie('_domain')) {
        $self->{tpl}->assign(
            CUR_DOMAIN => $self->{query}->cgi('domain') || $self->{query}->get_cookie('_domain')
        );
    }

    $self->_initme;
    $self;
}

sub _initme {
    initlang($_[0]->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_overview );
}

# domain overview
sub overview {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $multiplier = $self->{sysconfig}->{SYS_QUOTA_MULTIPLIER} || '1048576';

    my @res = $self->domain_paging(
        page => $q->cgi('page'),
        filter => $q->cgi('keyword'),
        filter_type => $q->cgi('ftype'),
    );
    my $vd = $res[0];

    if (ref $vd && scalar @$vd) {
        $tpl->assign(
            TOTAL_DOMAIN => sprintf($lang_overview{stat_domain}, $self->ext_info->{total}),
            TOTAL_PAGES => $self->ext_info->{pages},
            TOTAL_MATCH => $self->ext_info->{match},
            HAVE_VDOMAIN => 1,
            HAVE_PREV => $res[1],
            PREV => $q->cgi('page')-1,
            NEXT => $q->cgi('page')+1,
            HAVE_NEXT => $res[2],
            KEYWORD => $q->cgi('keyword'),
            FTYPE => $q->cgi('ftype'),
            CHECK_DOMAIN => $q->cgi('ftype') eq 'domain' ? 1:0,
        );

        foreach my $info (@$vd) {
            # get domain info
            my $buf = '';
            my $m = $info->{domain};
            my $qhash = $self->get_domain_usage($m);
            my $maxalias = ($buf = $info->{maxalias}) ? $buf : $lang_overview{'unlimited'};
            my $maxusers = ($buf = $info->{maxusers}) ? $buf : $lang_overview{'unlimited'};
            my $maxquota = ($buf = $self->quota2num($info->{maxquota})) ? $buf/$multiplier : $lang_overview{'unlimited'};
            my $maxndquota = ($buf = $self->quota2num($info->{maxndquota})) ? $buf/$multiplier: $lang_overview{'unlimited'};
            my $curalias = ($buf = $mgr->get_aliases_list($m)) ? scalar @$buf : '0';
            my $curusers = ($buf = $mgr->get_users_list($m)) ? scalar @$buf : 0;
            my $curquota = ($buf = $self->quota2num($qhash->{quota})) ? $buf : 0;
            my $curndqt  = ($buf = $self->quota2num($qhash->{ndquota})) ? $buf : 0;

            $tpl->assign(
                'LOOP_VDOMAIN',
                VDOMAIN => $m,
                DOMAIN_MAXALIAS => $maxalias,
                DOMAIN_MAXUSERS => $maxusers,
                DOMAIN_MAXQUOTA => $maxquota,
                DOMAIN_MAXNDQUOTA => $maxndquota,
                DOMAIN_CURALIAS => $curalias,
                DOMAIN_CURUSERS => $curusers,
                DOMAIN_CURQUOTA => $curquota/$multiplier,
                DOMAIN_CURNDQUOTA => $curndqt/$multiplier,
            );
        }
    } else {
        $tpl->assign(HAVE_VDOMAIN => 0);
    }
}

sub overview_user {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $mgr = $self->{backend};
    my $domain = $q->cgi('domain') || $q->get_cookie('_domain');
    my $multiplier = $self->{sysconfig}->{SYS_QUOTA_MULTIPLIER} || '1048576';

    if (not $domain) {
        my $lists = $self->domain_lists;
        $domain = $lists->[0]->{domain} if $lists;
    }

    # permission validation
    unless ($self->valid_perm($domain)) {
        $self->error('Access denied');
        return 0;
    }

    # list all domains available
    foreach my $vd ( @{$self->domain_lists} ) {
        $tpl->assign(
            'LOOP_DOMAIN',
            DOMAIN => $vd->{domain},
        );
    }

    my @res = $mgr->user_paging(
        domain =>$domain,
        page => $q->cgi('page'),
        filter => $q->cgi('keyword'),
        filter_type => $q->cgi('ftype'),
    );
    my $us = $res[0];

    $tpl->assign(
        TOTAL_USER => sprintf($lang_overview{stat_user}, $mgr->ext_info->{total}),
        TOTAL_PAGES => $mgr->ext_info->{pages},
        TOTAL_MATCH => $mgr->ext_info->{match},
        DOMAIN => $domain,
        CUR_DOMAIN => $domain,
        HAVE_PREV => $res[1],
        PREV => $q->cgi('page')-1,
        NEXT => $q->cgi('page')+1,
        HAVE_NEXT => $res[2],
        KEYWORD => $q->cgi('keyword'),
        FTYPE => $q->cgi('ftype'),
        CHECK_MAIL => $q->cgi('ftype') eq 'mail' ? 1:0,
        PURGE_DATA => $self->{sysconfig}->{SYS_PURGE_DATA} ? 1:0,
    );

    if (ref $us && scalar @$us >0) {
        $tpl->assign(HAVE_USERS => 1);
        foreach my $u (@$us) {
            $tpl->assign(
                'LOOP_USER',
                MAIL => $u->{mail},
                NAME => $u->{cn} || $u->{username},
                QUOTA => $self->quota2num($u->{quota})/$multiplier,
                NDQUOTA => $self->quota2num($u->{netdiskquota})/$multiplier,
                EXPIRE => $u->{expire},
                ACTIVE => $u->{active},
            );
        }
    } else {
        $tpl->assign(HAVE_USERS => 0);
    }

}

sub overview_alias {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $mgr = $self->{backend};
    my $domain = $q->cgi('domain') || $q->get_cookie('_domain');
    my $maxlen = 45; # 45 bytes

    if (not $domain) {
        my $lists = $self->domain_lists;
        $domain = $lists->[0]->{domain} if $lists;
    }

    # permission validation
    unless ($self->valid_perm($domain)) {
        $self->error('Access denied');
        return 0;
    }

    # list all domains available
    foreach my $vd ( @{$self->domain_lists} ) {
        $tpl->assign(
            'LOOP_DOMAIN',
            DOMAIN => $vd->{domain},
        );
    }

    my @res = $mgr->alias_paging(
        domain => $domain,
        page => $q->cgi('page'),
        filter => $q->cgi('keyword'),
    );
    my $as = $res[0];

    $tpl->assign(
        TOTAL_ALIAS => sprintf($lang_overview{stat_alias}, $mgr->ext_info->{total}),
        TOTAL_PAGES => $mgr->ext_info->{pages},
        TOTAL_MATCH => $mgr->ext_info->{match},
        DOMAIN => $domain,
        CUR_DOMAIN => $domain,
        HAVE_PREV => $res[1],
        PREV => $q->cgi('page')-1,
        NEXT => $q->cgi('page')+1,
        HAVE_NEXT => $res[2],
        KEYWORD => $q->cgi('keyword'),
    );

    if (ref $as && scalar @$as >0) {
        $tpl->assign(HAVE_ALIAS => 1);
        foreach my $a (@$as) {
            my $goto = '';
            my $mail = $a->{goto};

            if (ref $mail && scalar @$mail >1) {
                $goto = join(',', @$mail);
            } else {
                $goto = $mail;
            }

            if (length $goto >= $maxlen) {
                $goto = substr($goto, 0, $maxlen) . '......';
            }
            $tpl->assign(
                'LOOP_ALIAS',
                ALIAS => $a->{alias},
                GOTO => $goto,
                EXPIRE => $a->{expire},
                ACTIVE => $a->{'active'},
            );
        }
    } else {
        $tpl->assign(HAVE_ALIAS => 0);
    }
}

sub overview_manager {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $mgr = $self->{backend};

    unless($ENV{USERTYPE} eq 'admin') {
        $self->error('Access denied');
        return 0;
    }

    my @res = $mgr->manager_paging(
        page => $q->cgi('page'),
        filter => $q->cgi('keyword'),
        filter_type => $q->cgi('ftype'),
    );

    my $ms = $res[0];
    return 0 unless (scalar @$ms);

    $tpl->assign(
        TOTAL_MANAGER => sprintf($lang_overview{stat_manager}, $mgr->ext_info->{total}),
        TOTAL_PAGES => $mgr->ext_info->{pages},
        TOTAL_MATCH => $mgr->ext_info->{match},
        HAVE_PREV => $res[1],
        PREV => $q->cgi('page')-1,
        NEXT => $q->cgi('page')+1,
        HAVE_NEXT => $res[2],
        KEYWORD => $q->cgi('keyword'),
        FTYPE => $q->cgi('ftype'),
        CHECK_ADMIN => $q->cgi('ftype') eq 'admin' ? 1:0,
    );

    $tpl->assign(HAVE_MANAGER => 1);
    foreach my $man ( @$ms ) {
        $tpl->assign(
            'LOOP_MANAGER',
            USERNAME => $man->{manager},
            NAME => $man->{cn},
            TYPE => $man->{type},
            EXPIRE => $man->{expire},
            ACTIVE => $man->{active},
        );
    }
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'overview.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
