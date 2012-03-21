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
package Ext::GlobalAbook::File;

use Exporter;
use Ext::CSV;
use Ext::Utils;
use Fcntl qw(:flock);

use vars qw(@ISA @ABOOK $REF);
@ISA = qw(Exporter);
undef @ABOOK;
$REF = undef;

sub new {
    my $class = shift;
    my %opt = @_;

    $opt{file} = '/var/www/cgi-bin/extmail/globabook.cf' unless $opt{file};
    $opt{convert} = 0 unless $opt{convert};
    $opt{charset} = 'iso-8859' unless $opt{charset};
    $opt{lock} = 0 unless $opt{lock};

    my $self = bless {@_}, ref $class || $class;

    $self->{opt} = \%opt;
    $REF = new Ext::CSV unless($REF);
    $self->parse; # XXX auto
    $self;
}

sub parse {
    my $self = shift;
    my $file = $self->{opt}{file};
    my $count = 0;
    open(FD, "< $file") or
        warn "$file not exists, abort\n" and return "";
    while(<FD>) {
        chomp;
        if ($REF->parse($_)) {
            my @field = $REF->fields;
            $ABOOK[$count] = \@field;
            $count ++;
        }else {
            warn $REF->error_input;
        }
    }
    shift @ABOOK; # XXX remove the first element !
    close FD;
}

sub dump {
    my $self = shift;
    if ($self->{opt}{convert}) {
        my $ref = [];
        my $charset = $self->{opt}{charset};
        foreach my $e (@ABOOK) {
            for (my $i=0; $i<scalar @$e;$i++) {
                $e->[$i] = str2ncr($charset, $e->[$i]);
            }
            push @$ref, $e;
        }
        return $ref;
    } else {
        return \@ABOOK;
    }
}

sub search {
    my $self = shift;
    my $key = $_[0];
    my @id;
    my $ref = [];

    foreach(my $k=0; $k < scalar @ABOOK; $k++) {
        # join to a big string
        my $s = join('', @{$ABOOK[$k]});
        if($s=~/$key/i) {
            if ($self->{opt}{convert}) {
                my $charset = $self->{opt}{charset};
                my $e = $ABOOK[$k];
                for (my $i=0; $i<scalar @$e;$i++) {
                    $e->[$i] = str2ncr($charset, $e->[$i]);
                }
                push @$ref, $e;
            } else {
                push @$ref, $ABOOK[$k];
            }
        }
    }
    $ref;
}

sub DESTROY {
    undef $REF;
    undef @ABOOK;
}

1;
