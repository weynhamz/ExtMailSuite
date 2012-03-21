# vim: set ci et ts=4 sw=4:
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
package Ext;

# XXX README FIRST
# This is the top level parent package, all Ext::* packages will
# inherit methods from Ext.pm
use Ext::Config;
use vars qw(@EXPORT %Cfg);
use Exporter;

@EXPORT = qw(%Cfg);

my $ctx;

sub new {
    # cache the object if we has been initialized
    return $ctx if $ctx;

    my $this = shift;
    my %opt = @_;
    $ctx = bless {@_}, ref $this || $this;

    if (!$opt{config}) {
        die "No config file specify!\n";
    }

    if ($opt{directory}) {
        $ctx->{directory} = $opt{directory};
    }

    $ctx->{config} = $opt{config};

    if ($ENV{FCGI_ROLE} || $ENV{FCGI_APACHE_ROLE}) {
        require Ext::FCGI;
        Ext::FCGI::register_cleanup(\&cleanup);
    }

    my $config = Ext::Config->new(file => $opt{config});
    %Cfg = %{$config->dump};
    $ctx->{cfg} = \%Cfg;

    # init everything now, must call method directly!
    if ($ctx->can('init')) {
        $ctx->init;
    }
    $ctx;
}

sub cleanup {
    undef %Cfg;
    undef $ctx;
}

1;
