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
package Ext::Logger::Syslog;
use Unix::Syslog qw(:macros :subs);
use Exporter;
use vars qw(@EXPORT_OK %EXPORT_TAGS @ISA);

@ISA = qw(Exporter);

@EXPORT_OK = qw(init_syslog do_syslog do_closelog);

%EXPORT_TAGS = ("all" => [qw(init_syslog do_syslog do_closelog)]);

sub init_syslog {
    my $indent = shift || 'extmail_logger';
    my $facility = shift;

    if ($facility eq 'MAIL') {
        $facility = LOG_MAIL;
    } elsif ($facility eq 'USER') {
        $facility = LOG_USER;
    } elsif ($facility =~ /^LOCAL(\d+)$/) {
        $facility = "LOG_LOCAL$1";
    } else {
        $facility = LOG_USER;
    }

    openlog($indent, LOG_PID|PERROR, $facility);
}

# a simple wrapper
sub do_syslog {
    my $level = shift || LOG_INFO;
    my $msg = shift;

    if ($level eq 'INFO') {
        $level = LOG_INFO;
    } else {
        $level = "LOG_$level";
    }

    syslog $level, $msg, @_;
}

sub do_closelog { closelog }

1;
