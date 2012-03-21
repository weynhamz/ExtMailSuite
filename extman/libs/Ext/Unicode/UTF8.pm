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
package Ext::Unicode::UTF8;

use strict;
use Exporter;
use Ext::Unicode::IMAPUTF7; # import imap_utf7_*()
use Ext::Unicode::Iconv qw(iconv);
use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(ext_utf8_encode ext_utf8_decode);

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;

	$self;
}

### method call ###
#
sub set_charset {
    my ($self, $ch) = @_;
    $self->{_charset} = $ch || 'utf8';
}

sub get_charset {
    shift->{_charset} || '';
}

sub encode {
    my ($self, $str, $charset) = @_;

    $charset ||= $self->get_charset;
    return ext_utf8_encode($str, $charset);
}

sub decode {
    my ($self, $str, $charset) = @_;

    $charset ||= $self->get_charset;
    return ext_utf8_decode($str, $charset);
}

### function call ###
#
sub ext_utf8_encode {
    my ($str, $charset) = @_;

    if (!$charset or ($charset && lc $charset eq 'utf8')) {
        # no charset? or already is utf8
        return $str;
    }

    eval { $str = iconv($str, $charset, 'utf8') };
    $str;
}

sub ext_utf8_decode {
    my ($str, $charset) = @_;

    if (!$charset or ($charset && lc $charset eq 'utf8')) {
        # no charset then will return it's orig value
        return $str;
    }
    eval { $str = iconv($str, 'utf8', $charset) };
    $str;
}

1;
