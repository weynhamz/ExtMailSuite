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
package Ext::CaptCha;

use strict;
use vars qw(@MAPS);

@MAPS = (
    'A','B','C','D','E','F','G','H','I','J',
    'K','L','M','N','O','P','Q','R','S','T',
    'U','V','W','X','Y','Z','a','b','c','d',
    'e','f','g','h','i','j','k','l','m','n',
    'o','p','q','r','s','t','u','v','w','x',
    'y','z'
);

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;

    $self->init(@_);
}

sub init {
    my $self = shift;
    my %opt = @_;
    my $len = $opt{length};

    $self->{length} = $len || 6;
    $self->{key} = $opt{key} or die "You must provide a KEY!\n";

    my $type;

    eval {
        require Digest::MD5;
        Digest::MD5->import(qw(md5_hex));
    };
    if ($@) {
        eval {
            require Digest::SHA;
            Digest::SHA->import(qw(sha1_base64));
        };
        die "No MD5 or SHA support available, abort!\n" if $@;
        $type = 'sha1';
    } else {
        $type = 'md5';
    }
    $self->{type} = $type;
    $self;
}

sub gen_code {
    my $self = shift;
    my $len = $self->{length};

    my $code = '';
    foreach(0...$len-1) {
        # total of $#MAPS - 1
        $code .= $MAPS[int rand(51)];
    }
    $code;
}

sub encrypt {
    my $self = shift;
    my $type = $self->{type};
    my $key = $self->{key};

    if ($type eq 'md5') {
        return md5_hex($key.$_[0]);
    }
    if ($type eq 'sha1') {
        return sha1_base64($key.$_[0]).'=';
    }
}

sub verify {
    my $self = shift;
    my $type = $self->{type};
    my ($raw, $data) = @_;

    if ($self->encrypt($raw) eq $data) {
        return 1;
    }
    0;
}

1;
