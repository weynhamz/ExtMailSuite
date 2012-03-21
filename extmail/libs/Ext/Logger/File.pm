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
package Ext::Logger::File;
use POSIX qw(strftime);
use Fcntl qw(:flock);
use Exporter;
use vars qw(@EXPORT_OK %EXPORT_TAGS @ISA);

@ISA = qw(Exporter);

@EXPORT_OK = qw(init_syslog do_syslog do_closelog);

%EXPORT_TAGS = ("all" => [qw(init_syslog do_syslog do_closelog)]);

sub init_syslog {
    my $file = shift;

    open (my $fh, ">> $file") or die "$file not writable: $!\n";
    # unbuffer file handle
    select((select($fh), $| = 1)[0]);
    return $fh;
}

sub do_syslog {
    my $fh = shift;
    my $msg = shift;
    my $time = (strftime "%b %e %H:%M:%S", localtime);

    my $host = (POSIX::uname)[1];
    ($host) = ($host =~ /^([^\.]+)/);
    $host = 'localhost' unless $host;

    $msg =~ s/[\r?\n]+/ /;

    flock ($fh, LOCK_EX);
    printf $fh "$time $host extmail[$$]: $msg\n", @_;
    flock ($fh, LOCK_UN);
}

sub do_closelog {
    my $fh = shift;
    close $fh if defined fileno $fh;
}

1;
