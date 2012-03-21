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
    my $self = $class->SUPER::new(@_);
    $self;
}

sub process {
    my $self = shift;
    my $ui = $Ext::Cfg{'SYS_TEMPLATE_NAME'} || 'default';
    $self->SUPER::process("/$ui/"._safepath($_[0]));
}

# if no error occur, print it
sub print {
    my $self = shift;
    if (!$self->{errmsg} && !$self->{noprint}) {
        # XXX FIXME default to utf-8, sorry :0
        print "Content-type: text/html; charset=UTF-8\r\n\r\n";
        $self->SUPER::print;
    }
}

# this function advoid url security hole
sub _safepath {
    my $path = shift;
    $path =~ m#([a-zA-Z0-9\.\-_]+)$#;
    return ($1 ? $1 : 'error.html');
}

1;
