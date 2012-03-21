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
package Ext::FCGI;
use strict;
use Exporter;
use FCGI;
use Fcntl qw(:flock);

use vars qw(@ISA @handlers);
@ISA = qw(Exporter FCGI);

# load the FCGI::function
sub AUTOLOAD {
    my $sub = our $AUTOLOAD;
    my $pkg = __PACKAGE__;
    return if $AUTOLOAD =~ /::DESTROY$/;
    $sub =~ s/$pkg\:\://;
    $AUTOLOAD = "FCGI::$sub";
    goto &$AUTOLOAD;
}

sub accept {
    my $req = shift;
    my $fh = shift;
    if ($fh) {
        flock($fh, LOCK_EX);
        my $rc = $req->Accept();
        flock($fh, LOCK_UN);
        return $rc;
    }
    return $req->Accept();
}

sub register_cleanup {
    my $func = shift;
    if (!grep /^\Q$func\E$/, @handlers) {
        push @handlers, $func;
    }
}

sub request_cleanup {
    for (@handlers) {
        next unless (ref $_ and ref $_ eq 'CODE');
        &$_;
        # uncomment this line if u want debug information, but
        # some html/javascript would be broken, use as your own risk!
        # print "calling $_ to cleanup\n";
    }
}

1;
