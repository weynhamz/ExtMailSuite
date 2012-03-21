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
package Ext::Logger;
use POSIX qw(setlocale LC_ALL);
use vars qw($GLOB_FH);

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;

    setlocale(LC_ALL, "C");

    $self->init(@_);
}

sub init {
    my $self = shift;
    my %opt = @_;
    my $type = $opt{type};

    if ($type eq 'syslog') {
        eval {
            require Ext::Logger::Syslog;
            Ext::Logger::Syslog->import(qw(:all));
        };
        die "Unix::Syslog not found, please install it first!\n" if $@;
        init_syslog('extmail', 'MAIL');
        $self->{_func} = 'log_via_syslog';
    } elsif ($type eq 'file') {
        eval {
            require Ext::Logger::File;
            Ext::Logger::File->import(qw(:all));
        };
        die "Fcntl not found, please install it first!\n" if $@;

        $self->{_fh} = init_syslog($opt{log_file});
        $self->{_func} = 'log_via_file';
        $GLOB_FH = $self->{_fh};
    } else {
        die "$type not supported!\n";
    }

    if ($ENV{FCGI_ROLE} || $ENV{FCGI_APACHE_ROLE}) {
        require Ext::FCGI;
        Ext::FCGI::register_cleanup(\&cleanup);
    }

    $self;
}

sub log {
    my $self = shift;
    my $func = $self->{_func};

    $self->$func(@_);
}

sub log_via_syslog {
    my $self = shift;
    do_syslog('INFO', @_);
}

sub log_via_file {
    my $self = shift;
    do_syslog($self->{_fh}, @_);
}

sub cleanup {
    undef $GLOB_FH;
}

sub DESTROY {
    my $self = shift;
    if ($self->{_func} eq 'log_via_syslog') {
        do_closelog();
    } else {
        do_closelog($self->{_fh});
    }
}

1;
