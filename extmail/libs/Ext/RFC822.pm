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
package Ext::RFC822;

use Exporter;
use POSIX qw(strftime);
use MIME::Base64;
use MIME::QuotedPrint;

use vars qw(@ISA @month_map @EXPORT_OK @EXPORT);
@ISA = qw(Exporter);
@EXPORT_OK = qw(str2time);
@EXPORT = qw(rfc822_date rfc822_encode_str rfc822_encode_addr
            date_fmt rfc822_addr_parse);

%month_map = (
    Jan => "01",
    Feb => "02",
    Mar => "03",
    Apr => "04",
    May => "05",
    Jun => "06",
    Jul => "07",
    Aug => "08",
    Sep => "09",
    Oct => "10",
    Nov => "11",
    Dec => "12"
);

sub str2time {
    #eval { require Ext::DateTime };
    #unless ($@) {
    #    Ext::DateTime->import(qw(datefield2dateserial));
    #    return datefield2dateserial($_[0]);
    #}

    my $s = $_[0]; # RFC822 time format
    my @a = split (/\s+/, $s); # \s+ can handler more space

    return 0 if(scalar @a < 5 || $a[3]=~/[^\d]/ ||
        $a[1]=~/[^\d]/ || $a[4]=~/[^:\d]/ ||
        !$month_map{$a[2]});
    $a[3]+=1900 if($a[3]>=70 && $a[3]<100);
    $a[3]+=2000 if($a[3]<70);
    $a[1]='0'.$a[1] if(length($a[1])<2);

    # $a[4] =~s/://g; # convert 12:34:56 => 123456
    $a[4] = hms_fmt($a[4]); # convert 12:34:56 => 123456
    # year+mon+day+time
    my $str = "$a[3]".$month_map{$a[2]}."$a[1]$a[4]";
    return $str;
}

# format hour/min/second to standard xx:yy:zz
sub hms_fmt {
    my $s = $_[0]; # xx::yy::zz
    my @a = split(/:/, $s);
    my $len = scalar @a;
    if($len == 3) {#
        $a[0]="0$a[0]" if(length($a[0])<2);
        $a[1]="0$a[1]" if(length($a[1])<2);
        $a[2]="0$a[2]" if(length($a[2])<2);
    }elsif($len == 2) {
        # a hour/min/sec string without sec part:(
        $a[0]="0$a[0]" if(length($a[0])<2);
        $a[1]="0$a[1]" if(length($a[1])<2);
        push @a, "00";
    }elsif($len == 1) {
        $a[0]="0$a[0]" if(length($a[0])<2);
        push @a, "0000";
    }
    return "$a[0]$a[1]$a[2]";
}

sub date_fmt {
    my $fmt = shift; # format, eg: %s/%s
    my $date = shift; # RFC822 format
    my @a = split (/\s+/, $date); # \s+ can handler more space

    return $date if(scalar @a < 5 || $a[3]=~/[^\d]/ ||
        $a[1]=~/[^\d]/ || $a[4]=~/[^:\d]/);

    my @t = split(/:/, $a[4]);
    $a[1]='0'.$a[1] if(length($a[1])<2);

    # return format: Month day hour min
    return sprintf("$fmt", $a[2],$a[1],$t[0],$t[1]);
}

sub rfc822_date {
    my ($timezone) = $_[0] || '+0800';
    # XXX FIXME currently not support zone, ouch :-(
    return (strftime "%a, %d %b %Y %H:%M:%S $timezone", localtime);
}

sub _buf_b_encode {
    my ($charset, $buf) = @_;
    _utf8_off($buf);
    $buf = iconv($buf, 'utf-8', $charset) if ($charset !~ /utf-*8/i);
    $buf = encode_base64($buf);
    $buf =~ s/\r*\n$//;
    return $buf;
}

sub rfc822_encode_str {
    my ($charset, $str) = @_;
    my ($split_str, $buf) = (1, '');
    my $need_conv = 0;
    my @m;

    $need_conv = 1 if ($charset !~ /utf-*8/);

    # check if we should split long line then encode them, need Encode
    # so check Encode module first, then do as RFC2047 says.
    # $split_str = 1 if $charset =~ /utf-*8/i;
    eval { require Encode; Encode->import(qw(_utf8_on _utf8_off)); };
    $split_str = 0 if $@;

    if ($split_str) {
        require Ext::Unicode::Iconv;
        Ext::Unicode::Iconv->import(qw(iconv));
        my $ustr = $str;
        $ustr = iconv($str, $charset, 'utf-8') if ($charset !~ /utf-*8/i);
        _utf8_on($ustr);
        my $BUF = '';
        my $maxlen = 13; # 13*3 = 39 <= 40 bytes
        my $count = 0;
        foreach my $ch (split(//, $ustr)) {
            $BUF .= $ch;
            $count ++;

            next unless $count>= $maxlen;
            $BUF = _buf_b_encode($charset, $BUF);
            push @m, $BUF;
            $BUF = '';
            $count = 0;
        }
        if ($BUF) {
            $BUF = _buf_b_encode($charset, $BUF);
            push @m, $BUF;
        }
        _utf8_off($ustr);
    } else {
        @m = split("\n", encode_base64($str));
    }

    foreach my $id (0...scalar @m-1) {
        # append a white space on the following line
        $buf .= ($id eq 0?"": ' 'x 4)."=?$charset?B?".$m[$id]."?=";
        $buf .= ($id eq scalar @m-1 ? "" : "\n");
    }
    $buf;
}

sub rfc822_encode_addr {
    my $name = '[^\'"]*'; # * match 0 or more times, compatible with
                          # some addr that without name part
    my $addr = '[a-z0-9A-Z\-_\.=]+@[a-z0-9A-Z-\_.]+';
    my ($charset, $str) = @_;

    $str=~s/(\r|)\n//g; # remove all CRLF
    my @m = split(/\s*,\s*/, $str);
    my $buf = "";
    foreach my $id (0...scalar @m -1) {
        $m[$id]=~s/^\s+//;
        $m[$id]=~s/\s+$//;
        next unless ($m[$id]);

        # if match continue, but if not match, next loop, if we continue
        # without any match, $1 or $3 will keep the old value, sucks!
        $m[$id] =~ m#\s*['"]*\s*($name)\s*['"]*(\s+|^)<*($addr)>*# or next;

        if(!$1) {
            next unless $3; # ignore those without addr part
            $buf .= ($id eq 0? '': ' 'x 4)."$3,\n"; # insert white space except
                                                    # first line
            next;
        }
        $buf .= ($id eq 0? '"':' 'x 4 .'"'); # insert white space except
                                             # first line
        $buf .= rfc822_encode_str($charset, $1).'" <'.$3.'>';
        $buf .= ",\n"; # always add the suffix
    }
    $buf=~s/\n{2,}/\n/sg; # bug fix and remove redundunt crlf
    $buf=~s/,\n$//; # remove the last suffix
    $buf;
}

sub rfc822_addr_parse {
    my $s = $_[0];
    my $ref = {};
    my $name = '[^\'"<>]*';# match 0 or more times, compatible with
                           # some addr that without name part
    my $addr = '[a-z0-9A-Z\-_\.=\+]+@[a-z0-9A-Z-\_.]+';
    $s =~ s/[\r\n]+//g;
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;

    if ($s =~ m#['"]#) {
        $s =~ m#['"]?\s*($name)\s*['"]?\s*<*\s*($addr)*\s*>*#;
        if ($1) {
            $ref = { name => $1, addr => $2 || $1 }
        } else {
            my $mail = $2;
            $mail =~ /^([^\@]+)@/;
            $ref = { name => $1 ? $1 : $mail, addr => $mail};
        }
    } elsif ($s =~ m#[<>]#) {
        $s =~ m#([^<>]*)<\s*($addr)*\s*>#;
        if ($1) {
            $ref = { name => $1 ? $1 : $2, addr => $2 }
        } else {
            my $mail = $2;
            $mail =~ /^([^\@]+)@/;
            $ref = { name => $1 ? $1 : $mail, addr => $mail};
        }
    } else {
        if ($s) {
            # there is a mysterious bug here, if $s is '', then
            # after regexp excution, $1 will set to 'S', FIXME XXX

            $s =~ s/($addr)//;
            my $addr = $1;

            if ($addr) {
                $s =~ s/^\s+//;
                $s =~ s/\s+$//;
                if (not $s) {
                    $addr =~ /([^\@\s]+)@/;
                    $ref = { name => $1 || $addr, addr => $addr };
                } else {
                    $ref = { name => $s , addr => $addr };
                }
            } else {
                $ref = { name => $s, addr => $s };
            }
        }
    }
    $ref;
}

1;
