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
package Ext::Unicode::Iconv;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(iconv);

sub iconv {
    my ($str, $fchar, $tchar) = @_;
    my $nstr = '';
    my $cvt = '';
    return $str unless($str);

    $fchar = _fixcharset($fchar);
    $tchar = _fixcharset($tchar);

    eval {
        require Text::Iconv;
        $cvt = Text::Iconv->new($fchar, $tchar);
    };

    if ($@=~/Can't locate/) {# means not found
        undef $@; # cleanup
        $nstr = $str; # save a copy
        eval {
            require Encode;
            Encode::from_to($nstr, $fchar, $tchar);
        };
        return $str if($@);
    } elsif ($@) {
        return $str;
    } else {
        $nstr = $cvt->convert($str);
        return $str unless($nstr); # return if nstr null
    }
    $nstr;
}

# it will fix a bug in some c iconv(3) lib, that can't handle
# # gb2312 + some GBlized big5 characters, wait for new fix
sub _fixcharset {
    my $char = shift;
    if ($char =~ /^gb2312$/i) {
        return 'GBK';
    }
    $char;
}

1;
