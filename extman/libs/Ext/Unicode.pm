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
package Ext::Unicode;

use strict;
use Ext::Unicode::IMAPUTF7 qw(imap_utf7_encode imap_utf7_decode);
use Ext::Unicode::UTF8 qw(ext_utf8_encode ext_utf8_decode);
use Ext::Unicode::Iconv qw(iconv);
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA = qw(Ext::Unicode::Iconv
          Ext::Unicode::IMAPUTF7
          Ext::Unicode::UTF8
          Exporter);

@EXPORT = qw(imap_utf7_encode imap_utf7_decode ext_utf8_encode ext_utf8_decode iconv);

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;

	$self;
}

sub set_charset {
    my ($self, $ch) = @_;
    $self->{_charset} = $ch || 'utf-8';
}

sub get_charset {
    shift->{_charset} || '';
}

sub utf8_encode {
    my ($self, $str, $charset) = @_;

    $charset ||= $self->get_charset;
    return ext_utf8_encode($str, $charset);
}

sub utf8_decode {
    my ($self, $str, $charset) = @_;

    $charset ||= $self->get_charset;
    return ext_utf8_decode($str, $charset);
}

sub encode_imap_utf7 {
    my ($self, $str, $charset) = @_;

    $str = ext_utf8_encode($str, $charset);
    $str = imap_utf7_encode($str);
    $str;
}

sub decode_imap_utf7 {
    my ($self, $str, $charset) = @_;

    $str = imap_utf7_decode($str);
    $str = ext_utf8_decode($str, $charset);
    $str;
}

1;
