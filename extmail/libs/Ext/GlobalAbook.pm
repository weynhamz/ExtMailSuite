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
package Ext::GlobalAbook;

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;

    $self->init(@_);
}

sub init {
    my $self = shift;
    my %opt = @_;
    my $type = $opt{type};

    if ($type eq 'ldap') {
        require Ext::GlobalAbook::LDAP;
        $self = Ext::GlobalAbook::LDAP->new(@_);
    } elsif ($type eq 'file') {
        require Ext::GlobalAbook::File;
        $self = Ext::GlobalAbook::File->new(@_);
    } else {
        die "$type not supported!\n";
    }

    $self;
}

1;
