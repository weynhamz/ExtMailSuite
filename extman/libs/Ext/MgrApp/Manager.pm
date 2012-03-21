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
package Ext::MgrApp::Manager;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
use POSIX qw(strftime);
use Ext::Utils; # import url2str
use Ext::MgrApp;
use vars qw($lang_charset %lang_manager $default_expire $nowdate);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(add_manager => \&add_manager);
    $self->add_methods(edit_manager => \&edit_manager);
    $self->add_methods(save_manager => \&save_manager);
    $self->add_methods(delete_manager => \&delete_manager);
    $self->{default_mode} = 'edit_manager';

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
    $_[0]->{tpl}->assign( \%lang_manager );
}

sub add_manager {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};

    $tpl->assign(
        HAVE_MANAGER => 1,
        NEWADD => 1,
        ACTIVE => 1,
        EXPIRE => $default_expire,
    );

    my $domains = $mgr->get_domains_list || [];
    foreach my $vd ( @$domains ) {
        $tpl->assign(
            'LOOP_DOMAIN',
            VDOMAIN => $vd->{domain},
        );
    }
    # then nothing to do :-)
}

sub edit_manager {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};

    my $mi = $mgr->get_manager_info(lc $q->cgi('manager'));
    return 0 unless ($mi);

    my $owndomains = $mi->{domain};

    if (!ref $owndomains) {
        $owndomains = [$owndomains]; # force to ARRAY ref
    }

    $tpl->assign(HAVE_MANAGER => 1);
    $tpl->assign(
        USERNAME => $mi->{manager},
        NAME => $mi->{cn},
        TYPE => $mi->{type},
        EXPIRE => $mi->{expire},
        ACTIVE => $mi->{active},
    );

    my $domains = $mgr->get_domains_list || [];
    foreach my $vd ( @$domains ) {
        $tpl->assign(
            'LOOP_DOMAIN',
            CHECK => (grep(/^$vd->{domain}$/,@$owndomains) ? 1 : 0),
            VDOMAIN => $vd->{domain},
        );
    }

    $tpl->assign(
        QUESTION => $mi->{question},
        ANSWER => $mi->{answer},
        DISABLEPWDCHANGE => $mi->{disablepwdchange} ? 1 : 0,
    );
}

sub save_manager {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $manager = lc $q->cgi('manager');

    if (!$self->sanity_manager($manager)) {
        $self->error('Bad Manager Name');
        return 0;
    }

    if (!$self->valid_time($q->cgi('expire'))) {
        $tpl->assign(ERROR => $lang_manager{'err_time'});
        $self->edit_manager;
        return;
    }

    if ($mgr->get_manager_info($manager)) {
        if ($q->cgi('newadd')) {
            $tpl->assign(ERROR => sprintf($lang_manager{'manager_exist'}, $manager));
            $self->add_manager;
            return 0;
        } else {
            my $pwd1 = $q->cgi('passwd1');
            my $pwd2 = $q->cgi('passwd2');

            if ($pwd1 ne $pwd2) {
                $tpl->assign(ERROR => $lang_manager{'errinput_passwd'});
                $self->edit_manager;
                return 0;
            }

            my @ow = $q->cgi('owndomain');
            my $rc = $mgr->modify_manager(
                manager => $manager,
                cn => $q->cgi('cn'),
                expire => $q->cgi('expire'),
                active => $q->cgi('active'),
                domain => \@ow,
                question => $q->cgi('question'),
                answer => $q->cgi('answer'),
                disablepwdchange => ($q->cgi('disablepwdchange') ? 1 : 0),
                passwd => $pwd1,
            );

            if ($rc) {
                $tpl->assign(ERROR => sprintf($lang_manager{'modify_fail'}, $manager).$rc);
            } else {
                $tpl->assign(SUCCESS => sprintf($lang_manager{'modify_ok'}, $manager));
            }
            $self->edit_manager;
        }
    } else {
        if ($q->cgi('newadd')) {
            # save the change
            my $pwd1 = $q->cgi('passwd1');
            my $pwd2 = $q->cgi('passwd2');

            if (!$pwd1 or !$pwd2 or ($pwd1 ne $pwd2)) {
                # pwd1 != pwd2, password modification fail, abort
                $tpl->assign(ERROR => $lang_manager{'errinput_passwd'});
                return 0;
            }

            my @ow = $q->cgi('owndomain');
            my $rc = $mgr->add_manager(
                manager => $manager,
                cn => $q->cgi('cn'),
                expire => $q->cgi('expire'),
                create => strftime("%Y-%m-%d %H:%M:%S", localtime),
                active => $q->cgi('active'),
                domain => \@ow,
                question => $q->cgi('question'),
                answer => $q->cgi('answer'),
                disablepwdchange => ($q->cgi('disablepwdchange') ? 1 : 0),
                type => 'postmaster', # XXX
                passwd => $pwd1,
            );

            if ($rc) {
                $tpl->assign(ERROR => sprintf($lang_manager{'add_fail'}, $manager).$rc);
            } else {
                $tpl->assign(SUCCESS => sprintf($lang_manager{'add_ok'}, $manager));
            }
            $self->add_manager;
        } else {
            $tpl->assign(ERROR => $lang_manager{'no_such_manager'});
        }
    }
}

sub delete_manager {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $mgr = $self->{backend};
    my $manager = lc $q->cgi('manager');

    if ($mgr->get_manager_info($manager)) {
        my $rc = '';

        # can not delete self
        if ($ENV{USERNAME} eq $manager) {
            $rc = $lang_manager{'delete_self_fail'} || 'Can\'t delete yourself';
        } else {
            $rc = $mgr->delete_manager($manager);
        }

        if ($rc) {
            $tpl->assign(ERROR => "Delete fail ! reason: ".$rc);
        } else {
            $tpl->{noprint} = 1;
            $self->{redirect} = url2str($q->cgi('url'));
        }
    } else {
        $tpl->assign(ERROR => $lang_manager{'no_such_manager'});
    }
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'edit_manager.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
