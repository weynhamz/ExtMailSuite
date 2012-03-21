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
package Ext::Template;

use Ext;
use Exporter;
use Ext::Lang;

use vars qw(@ISA @EXPORT $lang $ui);
@ISA = qw(Exporter HTML::KTemplate);
$lang = 'en_US'; # set default
$ui = 'default'; # set default

use HTML::KTemplate;
$HTML::KTemplate::VAR_START_TAG = '<%';
$HTML::KTemplate::VAR_END_TAG = '%>';
$HTML::KTemplate::BLOCK_START_TAG = '<!--';
$HTML::KTemplate::BLOCK_END_TAG = '-->';
$HTML::KTemplate::CHOMP = 1;

sub new {
    my $class = shift;
    my %opt = @_;
    if(my $env = $ENV{EXTMAIL_TEMPLDIR}) {
        $opt{root} = $env;
    }
    my $self = $class->SUPER::new(%opt);
    $self->{http_cache} = 1 if $opt{http_cache};
    $self;
}

sub process {
    my $self = shift;
    my $ui = "";
    eval {
        $ui = Ext::App::userconfig()->{template};
    };

    if($@ or !$ui or !-d $Ext::Cfg{'SYS_TEMPLDIR'}."/$ui") {
        $ui = $Ext::Cfg{'SYS_USER_TEMPLATE'} || 'default';
    }
    $self->SUPER::process("/$ui/"._safepath($_[0]));
}

# if no error occur, print it
sub print {
    my $self = shift;

    return if ($self->{errmsg} || $self->{noprint});

    if (not $self->{http_cache}) {
        print "Expires: Mon, 26 Jul 1997 05:00:00 GMT\n";
        print "Cache-Control: no-cache, must-revalidate\n";
        print "Pragma: no-cache\n";
    }

    # XXX FIXME default to utf-8, sorry :0
    print "Content-type: text/html; charset=UTF-8\r\n\r\n";
    $self->SUPER::print;
}

# this function advoid url security hole
sub _safepath {
    my $path = shift;
    $path =~ m#([a-zA-Z0-9\.\-_]+)$#;
    return ($1 ? $1 : 'error.html');
}

1;
