# vim: set ci et ts=4 sw=4:
#
# Copyright (c) 1998-2007 Chi-Keung Ho. All rights reserved.
#
# This programe is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# Extmail - a high-performance webmail to maildir
# $Id$
package Ext::GD;

use GD;
use vars qw($AUTOLOAD);

sub AUTOLOAD {
    my $sub = our $AUTHLOAD;

    return unless $sub;

    $sub =~ s/Ext::GD:://;
    return if ($sub eq 'DESTROY');
    return if ($sub =~ /^gd.*Font$/);

    *$AUTOLOAD = shift->{_hdl}->$sub(@_);
}

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;
    $self->{_hdl} = new GD::Image (@_);
    $self;
}

sub line {
    my $self = shift;
    my $img = $self->{_hdl};

    return $img->line(@_);
}

sub fill {
    my $self = shift;
    my $img = $self->{_hdl};

    return $img->fill(@_);
}

sub colorAllocate {
    my $self = shift;
    my $img = $self->{_hdl};
    my @rgb = @_;

    if (scalar @rgb == 3) {
        return $img->colorAllocate(@rgb);
    }
    if (scalar @rgb == 1) {
        return $img->colorAllocate($self->hex2ord($_[0]));
    }
    die "Usage: Ext::GD::colorAllocate(image, r, g, b)\n";
}

sub rectangle {
    my $self = shift;
    my $img = $self->{_hdl};

    return $img->rectangle(@_);
}

sub string {
    my $self = shift;
    my $img = $self->{_hdl};
    my $font = shift;

    return $img->string($font->(), @_);
}

sub stringFT {
    my $self = shift;
    my $img = $self->{_hdl};

    return $img->stringFT(@_);
}

sub png {
    my $self = shift;
    my $img = $self->{_hdl};

    return $img->png(@_);
}

sub hex2ord {
    shift;
    my $hex = shift;
    my $len = length $hex;
    my @colors;

    die "Bad hex format or length\n" unless $len == 6;

    while (my $str = substr($hex, 0, 2)) {
        $hex = substr($hex, 2);
        push @colors, hex ($str);
    }
    @colors;
}

1;
