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
package Ext::Config;
use strict;
use Exporter;

# This varible are private, can only access by class method
my $token_key = "[a-zA-Z0-9-_]+";
my $token_val = ".+";
my $token_sep = "\\s*=\\s*";

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(dump_cfg);

sub new {
    my $this = shift;
    my $self = bless {}, ref $this || $this;

    $self->{cfg} = _load(@_); # XXX use per object storage
    $self;
}

sub _load {
    my %opt = @_;
    my $cfg;

    return undef unless($opt{file});

    # if config not exist, don't die, return instead
    if(!-r $opt{file}) {
        warn "$opt{file} not exists or not readable";
        return undef;
    }

    open(my $FD, "< $opt{file}") or
        die "Can't open $opt{file}, $!\n";
    $cfg = _parse($FD);
    close $FD;

    $cfg;
}

sub dump {
    shift->{cfg};
}

sub dump_cfg {
    my $file = $_[0];
    open(my $FD, "< $file") or die "Can't open $file, $!\n";
    my $cf = _parse($FD);
    close $FD;
    $cf;
}

sub get {
    my $self = shift;
    my $key = $_[0];
    my $cfg = $self->{cfg}; # XXX HASH ref

    foreach(keys %$cfg) {
        if(lc $key eq lc $_) {
            return $cfg->{$_};
        }
    }
    "";
}

sub set {
    my $self = shift;
    my ($key, $value) = @_;
    $self->{cfg}->{$key} = $value;
    1;
}

sub del {
    my $self = shift;
    my $key = $_[0];
    delete $self->{cfg}->{$key};
    1;
}

sub add {
    shift->set(@_);
}

# save must be able to new a config file if it not
# exist :-) , waiting to fix
sub save {
    my $self = shift;
    my %opt = @_;
    my $new;
    my $tconfig = $self->{cfg};

    return unless ($opt{file});

    if(!-r $opt{file}) {
        # means new a config file
        open(FD, "> $opt{file}") or die "Can't write to $opt{file}, $!\n";
        foreach(keys %$tconfig) {
            print FD "$_ = $tconfig->{$_}\n";
        }
        close FD;
        return;
    }

    open(my $FD, "< $opt{file}") or die "Can't open $opt{file}, $!\n";
    while(<$FD>) {
        chomp;
        $new .= _save_line($_, $tconfig);
    }
    close $FD;

    if(scalar keys %$tconfig>0) {
        # op=add (line not exists)
        $new .= "$_ = $tconfig->{$_}\n" for(keys %$tconfig);
    }

    open($FD, "> $opt{file}.tmp") or
        die "Can't write $opt{file}.tmp, $!\n";
    print $FD $new;
    close $FD;

    rename("$opt{file}.tmp", "$opt{file}") or
        die "Can't rename, $!\n";
}

sub _parse {
    my $FD = $_[0];
    my $token = "\\s*=\\s*";
    my %cfg = ();

    while(<$FD>) {
        next if (/^\s*#|^\s*;|^\s*$|^\s*\n/);
        my ($k, $v) = /\s*($token_key)$token_sep($token_val)\s*/;
        $v =~ s/^\s*//;
        $v =~ s/\s*$//;
        $cfg{$k} = $v;
    }
    \%cfg;
}

sub _save_line {
    my ($str,$cfg) = @_;
    my $flag = 0;

    $str=~/^\s*($token_key)$token_sep($token_val)\s*$/;
    my($k, $v) = ($1, $2);

    if($str=~/(^\s*#|^\s*;|^\s*$|^\s*\n)/) {
        return "$str\n";
    }

    foreach(keys %$cfg) {
        if(lc $_ eq lc $k) {
            # op=set (key exists)
            my ($kk, $vv) = ($_, $cfg->{$_});
            delete $cfg->{$_}; # clean up
            return "$kk = $vv\n";
        }
    }
    # if we got here, means no key in cfg match, this line
    # should be abort/delete.
    # op=del (key not exists)
    return "";
}

1;
