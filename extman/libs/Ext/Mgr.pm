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
package Ext::Mgr;
use strict;
use Exporter;
use Ext::Passwd qw(@SCHEMES);

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::Passwd);
@EXPORT = qw();

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;
    $self->init(@_);
}

sub init {
    my $self = shift;
    my %opt = @_;
    my $type = $opt{type};
    my $tcrypt = uc $opt{crypt_type};

    die "$tcrypt not suuport!" unless(grep(/^$tcrypt$/, @SCHEMES));
    die "No Mgr module defined!" unless defined $opt{type};

    if($type eq 'mysql') {
        require Ext::Mgr::MySQL;
        $self = Ext::Mgr::MySQL->new(@_);
    }
    if($type eq 'ldap') {
        require Ext::Mgr::LDAP;
        $self = Ext::Mgr::LDAP->new(@_);
    }

    # XXX FIXME here we inherit Ext::Passwd, so we must setup
    # fallback_scheme at the same object we create :-)
    $self->{_fallback_scheme} = $tcrypt;
    $self;
}

sub pages {
    my $self = shift;
    my ($total, $psize) = @_;

    return 0 unless ($psize && $total);

    my $rest = $total % $psize;
    my $page = ($total - $rest) / $psize + ($rest ? 1 : 0);

    $page;
}

sub DESTORY {}

1;
