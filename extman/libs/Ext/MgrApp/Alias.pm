# vim: set cindent expandtab ts=4 sw=4:
#
# Copyright (c) 1998-2005 Chi-Keung Ho. All rights reserved.
#
# This programe is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# Extman - a high-performance webmail to maildir
# $Id$
package Ext::MgrApp::Alias;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
use POSIX qw(strftime);
use Ext::MgrApp;
use Ext::Utils;
use vars qw($lang_charset %lang_alias);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(add_alias => \&add_alias);
    $self->add_methods(edit_alias => \&edit_alias);
    $self->add_methods(save_alias => \&save_alias);
    $self->add_methods(delete_alias => \&delete_alias);
    $self->{default_mode} = 'edit_alias';

    $self->_initme;
    $self;
}

sub _initme {
    initlang($_[0]->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_alias );
}

sub add_alias {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};

    $tpl->assign(
        HAVE_ALIAS => 1,
        NEWADD => 1,
        ACTIVE => 1,
    );
    my $domains = [];

    if ($ENV{USERTYPE} eq 'admin') {
        my $alldomain = $mgr->get_domains_list || [];
        foreach my $d ( @$alldomain ) {
            push @$domains, $d->{domain};
        }
    } else {
        my $pm = $mgr->get_manager_info($ENV{USERNAME});
        $domains = $pm->{'domain'};
    }

    if ($domains) {
        $domains = [$domains] unless (ref $domains);
        foreach my $vd ( @$domains ) {
            $tpl->assign(
                'LOOP_DOMAIN',
                DOMAIN => $vd
            );
        }
    } else {
        # no permission or not assign domain
        $tpl->assign(NOPERM => 1);
        $tpl->assign(HAVE_USER => 0);
    }
}

sub edit_alias {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};

    my $alias = lc $q->cgi('alias');
    my ($domain) = ($alias=~ m!.*@(.*)!);
    my $ai = $mgr->get_alias_info($alias);

    return 0 unless($ai);

    # permission validation
    unless ($self->valid_perm($domain)) {
        $self->error('Access denied');
        return 0;
    }

    $tpl->assign(HAVE_ALIAS => 1);
    $tpl->assign(
        ALIAS => $ai->{alias},
        ACTIVE => $ai->{active},
        DOMAIN => $domain,
    );

    if (my $mail = $ai->{goto}) {
        my $goto = '';
        if (ref $mail && scalar @$mail >0) {
            foreach my $m (@$mail) {
                $goto .= "$m\n";
            }
        } else {
            $goto = $mail;
        }
        $tpl->assign( GOTO => $goto );
    }
}

sub save_alias {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};

    my ($alias, $domain) = (lc $q->cgi('alias'), lc $q->cgi('domain'));
    my $tmp = lc $q->cgi('goto');

    $alias =~ s! !!g;
    $alias =~ s![^a-zA-Z0-9-_\.=@]!!g;
    $tmp =~ s![^a-zA-Z0-9-_\.=,\n@]!!g;
    $tmp =~ s!\r!!g;
    $tmp =~ s! !!g;

    my $goto = '';
    foreach my $s ( split(/\n/, $tmp) ) {
        $goto .= "$s\n" if ($s);
    }

    unless ($alias && $goto) {
        $tpl->assign(ERROR => $lang_alias{'err_input'});
        return 0;
    }

    if (!$domain && $alias) {# no domain provide, may be in edit mode
        ($domain) = ($alias =~ m!.*@(.*)!);
    }

    unless ($self->valid_perm($domain)) {
        $self->error('Access denied');
        return 0;
    }

    if ($mgr->get_alias_info("$alias\@$domain") ||
        $mgr->get_alias_info($alias)) {
        if ($q->cgi('newadd')) {
            $tpl->assign(ERROR => $lang_alias{'alias_exist'});
            $self->add_alias;
            return 0;
        } else {
            # save the change
            if ($alias eq '@') {
                $alias = '';
            }

            my $rc = $mgr->modify_alias(
                alias => lc $q->cgi('alias'), # XXX
                goto => $goto,
                active => $q->cgi('active'),
            );

            if ($rc) {
                $tpl->assign(ERROR => sprintf($lang_alias{'modify_fail'}, $q->cgi('alias')).$rc);
            } else {
                $tpl->assign(SUCCESS => sprintf($lang_alias{'modify_ok'}, $q->cgi('alias')));
            }
            $self->edit_alias;
        }
    } else {
        # new add
        if ($q->cgi('newadd')) {
            my $rc = $self->domain_overusage(
                domain => $domain,
                alias => 1,
            ); # query the rc whether it overquota or not

            if ($alias eq '@') {
                $alias = ''; # catchAll or domain alias
            }

            $rc = $mgr->add_alias(
                alias => "$alias\@$domain",
                domain => $domain,
                goto => $goto,
                active => $q->cgi('active'),
                create => strftime("%Y-%m-%d %H:%M:%S", localtime),
            ) unless ($rc);

            if ($rc) {
                $tpl->assign(ERROR => sprintf($lang_alias{'add_fail'}, "$alias\@$domain").$rc);
            } else {
                $tpl->assign(SUCCESS => sprintf($lang_alias{'add_ok'}, "$alias\@$domain"));
            }
            $self->add_alias;
        } else {
            $tpl->assign(ERROR => $lang_alias{'no_such_alias'});
        }
    }
}

sub delete_alias {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $mgr = $self->{backend};
    my $alias = lc $q->cgi('alias');

    my ($domain) = ($alias =~ m!.*@(.*)!);
    # permission validation
    unless ($self->valid_perm($domain)) {
        $self->error('Access denied');
        return 0;
    }

    if ($mgr->get_alias_info($alias)) {
        my $rc = $mgr->delete_alias($alias);
        if ($rc) {
            $tpl->assign(ERROR => "Delete fail!");
        } else {
            $tpl->{noprint} = 1;
            $self->{redirect} = url2str($q->cgi('url'));
        }
    } else {
        $tpl->assign(ERROR => $lang_alias{'no_such_alias'});
    }
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'edit_alias.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
