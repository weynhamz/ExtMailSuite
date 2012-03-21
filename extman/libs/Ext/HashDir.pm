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
package Ext::HashDir;
use Exporter;

use vars qw(@ISA @EXPORT $level);
@ISA = qw(Exporter);
@EXPORT = qw(hashdir);

srand(time);

# build map
my @MAP = (qw(0 1 2 3 4 5 6 7 8 9 A B C D E F));

sub hashdir {
    die "wrong parameters\n" unless (!@_ or scalar @_ == 2);
    my $size = shift || $level;
    my $deep = shift || $level;

    my $dir = '';
    for(0..$deep-1) {
        if ($dir) { $dir .= '/'. _hashdir($size) }
        else { $dir = _hashdir($size) }
    }
    $dir;
}

sub _hashdir {
    my $size = shift;
    my $dir = '';
    for (0...$size-1) {
        $dir .= mychr();
    }
    $dir;
}

sub mychr {
    $MAP[int rand(scalar @MAP)];
}

1;
