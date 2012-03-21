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
package Ext::App::GlobalAbook;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::App);
use Ext::App;
use Ext::GlobalAbook;
use Ext::Utils;
use Ext::MIME; # import html_fmt()

use vars qw(%lang_globalabook $lang_charset);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(abook_show => \&abook_show);
    $self->add_methods(abook_export => \&abook_export);
    $self->add_methods(abook_search => \&abook_search);

    $self->{default_mode} = 'abook_show';
    Ext::Storage::Maildir::init($self->get_working_path);

    $self->_initme;
    $self->_init_obj;
    $self;
}

sub _initme {
    initlang($_[0]->userconfig->{lang}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_globalabook );
}

sub _init_obj {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $sysconfig = $self->{sysconfig};
    my $type = $sysconfig->{SYS_G_ABOOK_TYPE};
    my $obj = '';

    if ($type eq 'ldap') {
        $obj = Ext::GlobalAbook->new(
            type => 'ldap',
            base => $sysconfig->{SYS_G_ABOOK_LDAP_BASE},
            rootdn => $sysconfig->{SYS_G_ABOOK_LDAP_ROOTDN},
            rootpw => $sysconfig->{SYS_G_ABOOK_LDAP_ROOTPW},
            filter => $sysconfig->{SYS_G_ABOOK_LDAP_FILTER},
            host => $sysconfig->{SYS_G_ABOOK_LDAP_HOST},
            convert => 1, # XXX this must exist for LDAP v3
            bind => 1,
        );
    } elsif ($type eq 'file') {
        $obj = Ext::GlobalAbook->new(
            type => 'file',
            file => $sysconfig->{SYS_G_ABOOK_FILE_PATH},
            lock => $sysconfig->{SYS_G_ABOOK_FILE_LOCK},
            convert => $sysconfig->{SYS_G_ABOOK_FILE_CONVERT},
            charset => $sysconfig->{SYS_G_ABOOK_FILE_CHARSET},
        );
    }else {
        die "$type not support still";
    }
    $self->{obj} = $obj;
}

sub abook_show {
    my $self = shift;
    my $obj = $self->{obj};
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $abook = $obj->dump;

    $tpl->assign(
        HAVE_ABOOK => (scalar @$abook>0?1:0),
        #SID => $self->{query}->cgi('sid'),
    );

    for(my $k=0; $k < scalar @$abook; $k++) {
        my $e = $abook->[$k];
        $tpl->assign(
            'LOOP_ABOOK',
            ID => $k,
            NAME => $e->[0],
            MAILADDR => $e->[1],
            COMPANY => $e->[2],
            MOBILE => $e->[3]
        );
    }

    # return url support
    if($q->cgi('url')) {
        $tpl->assign( RETURN_URL => $q->cgi('url') );
    }
}

sub abook_search {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $obj = $self->{obj};

    my $key = $q->cgi('keyword');
    my $abook = $obj->search($key);

    if(scalar @$abook) {
        $tpl->assign( HAVE_ABOOK => 1 );
    }else {
        $tpl->assign( SEARCH_NULL => 1 );
        return 0;
    }

    for(my $k=0; $k < scalar @$abook; $k++) {
        my $e = $abook->[$k];
        $tpl->assign(
            'LOOP_ABOOK',
            ID => $k,
            NAME => $e->[0],
            MAILADDR => $e->[1],
            COMPANY => $e->[2],
            MOBILE => $e->[3]
        );
    }
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'globabook.html';
    reset_working_path();
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
