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
package Ext::Session;

use strict;
no strict qw(refs);

use Ext;
use Exporter;
use Ext::Utils;
use vars qw(@KEY_MAP $RANDED);
use vars qw($_RTYPE $_RFUNC);
$_RTYPE = '';
$_RFUNC = '';

our @ISA = qw(Exporter);
our @EXPORT = qw(
    gen_sid @KEY_MAP read_sess
    write_sess parse_sess
    kill_sid valid_sess
);

@KEY_MAP = (
    0,1,2,3,4,5,6,7,8,9,'A','B','C','D','E',
    'F','G','H','I','J','K','L','M','N','O',
    'P','Q','R','S','T','U','V','W','X','Y',
    'Z','a','b','c','d','e','f','g','h','i',
    'j','k','l','m','n','o','p','q','r','s',
    't','u','v','w','x','y','z'
);

# package init

sub sess_dir {
    my $dir = $Ext::Cfg{SYS_SESS_DIR};
    if (! defined $dir) {
        $dir = "/tmp/";
    }
    $dir;
}

# gen_rand_func - to generate proper random function, and do
# a little trick to cache the function name and type.
sub gen_rand_func {
    return if ($_RFUNC && $_RTYPE);

    eval { require 'sys/syscall.ph' };
    if ($@ or !defined &SYS_gettimeofday) {$_RTYPE = 'time' }
    else { $_RTYPE = 'syscall' }

    eval { require Digest::MD5 };
    if($@) {
        $_RFUNC = 'rand_time';
    } else {
        Digest::MD5->import(qw(md5_hex));
        if (-r '/dev/urandom') {
            $_RFUNC = 'rand_dev';
        } elsif ($_RTYPE eq 'syscall') {
            $_RFUNC = 'rand_md5';
        } else {
            $_RFUNC = 'rand_time';
        }
    }
}

# gen_sid - to generate unique Session id
# XXX FIXME - $RANDED is not safe under persistent envirement
#             , so this is an experimental tricks

sub gen_sid {
    # put require 'sys/syscall.ph' in function to advoid
    # Maildir.pm complain gettimeofday() undefined, but why?:(
    gen_rand_func();
    &$_RFUNC(@_)
}

sub rand_time {
    my ($sid, $len) = (undef, $_[0] ? $_[0]-1 : 23);

    if (!$RANDED) {
        srand(time() ^ $$);
        $RANDED = 1;
    }

    foreach(0...$len) {
        $sid .= $KEY_MAP[int rand(61)]; # total of $#KEY_MAP -1
    }
    $sid;
}

sub rand_md5 {
    my $start = pack('LL', ());
    syscall(&SYS_gettimeofday, $start, 0) != -1
        or die "gettimeofday: $!";
    my $str = join('/',unpack('LL', $start));
    md5_hex($str);
}

sub rand_dev {
    my $seed = '';
    my $len = 32;
    open (FD, '/dev/urandom') or die "open urandom error: $!\n";
    for(0...$len-1) {
        next unless sysread FD, my $buf, 1;
        $seed .= sprintf("%x", ord $buf);
    }
    md5_hex($seed);
}

sub kill_sid {
    my ($sid) = $_[0];
    my $dir = sess_dir();
    return 0 if not defined $sid or $sid eq "";
    if(-e "$dir/sid_$sid") {
        unlink untaint("$dir/sid_$sid")
            or die "Can't unlink $dir/sid_$sid, $!\n";
        return 1;
    }
    0;
}

sub write_sess {
    my ($sid, $info) = @_;
    my $dir = sess_dir();
    my $sfile = untaint ("$dir/sid_$sid");

    if(!-e $sfile) {
        open(my $FD, "> $sfile") or die "Can't open $sfile, $!\n";
        print $FD $info;
        close $FD;
        return 1;
    }else {
        return 0;
    }
    0;
}

sub read_sess {
    my ($sid) = $_[0];
    my $str = "";
    my $dir = sess_dir();
    my $sfile = "$dir/sid_$sid";

    if(-e $sfile) {
        open(my $FD, "< $sfile") or die "Can't open $sfile, $!\n";
        while(<$FD>) {
            $str .= $_;
        }
        close $FD;
    }
    "$str";
}

sub parse_sess {
    my ($sid) = $_[0];
    my $str = read_sess($sid);
    my %shash;

    if(length($str)<2) {# no content or in-compat
        return {};
    }else {
        foreach(split(/\n/, $str)) {
            /^([a-zA-Z0-9-_]+)\s*=\s*(.+)/;
            my ($k, $v) = ($1, $2);
            if(defined $k) {
                $shash{$k}=$v;
            }
        }
    }
    return \%shash;
}

sub valid_sess {
    my ($sid) = $_[0];
    my $dir = sess_dir();
    if(!-e "$dir/sid_$sid") {
        return 0;
    }

    if(!-r "$dir/sid_$sid") {
        return 0;
    }
    1;
}

1;
