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
package Ext::Unicode::IMAPUTF7;

use strict;
use Encode::IMAPUTF7 qw(encode decode);
use Encode qw(from_to _utf8_on _utf8_off);
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(imap_utf7_encode imap_utf7_decode);

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;
	$self;
}

sub encode {
	my ($self, $str) = @_;
	my $r = Encode::encode('IMAP-UTF-7', $str);
	$r;
}

sub imap_utf7_encode {
    my $str = shift;
    my $r = Encode::encode('IMAP-UTF-7', $str);
    $r;
}

sub decode {
	my ($self, $str) = @_;
	my $r = Encode::decode('IMAP-UTF-7', $str);
	_utf8_off($r);
	$r;
}

sub imap_utf7_decode {
    my $str = shift;
    my $r = Encode::decode('IMAP-UTF-7', $str);
    _utf8_off($r);
    $r;
}

1;
