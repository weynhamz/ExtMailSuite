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
package Ext::MIME;
use strict;

# PARSER design 2005-02-18(*)
# ===========================
# please refer to the detail function in App/Message.pm

use Exporter;
use vars qw(@ISA @EXPORT %CFG);
@ISA = qw(Exporter);
@EXPORT = qw(
    mydumper get_msg_info get_msg_hdr_fast get_msg_header get_header
    hdr_fmt_list hdr_fmt_hash hdr_get_hash hdr_get_list part_parse
    get_parts get_parts_name dump_parts decode_words decode_it
    html_fmt decode_words_utf8
);

use Ext::Utils;
use MIME::Base64;
use MIME::QuotedPrint;
use Benchmark;
use Ext::Lang qw(charset_detect);
use Ext::Unicode qw(iconv);

%CFG = ();

sub init {
    my %opt = @_;
    if(defined $opt{debug}) {
        $CFG{debug} = $opt{debug};
    }else {
        $CFG{debug} = 0;
    }

    $CFG{path} = $opt{path} ? $opt{path} : "$ENV{HOME}/Maildir";
}

# debug to STDERR
sub _debug {
    my $debug = $CFG{debug};

    if($debug) {
        if($ENV{SCRIPT_NAME}) {
            print "Debug &lt;";
        }else {
            print "Debug <";
        }
        printf @_;
        if($ENV{SCRIPT_NAME}) {
            print "&gt;<BR>\n";
            print "</br>\n";
        }else {
            #print ">\n";
        }
    }
}

sub mydumper {
    my $in = $_[0];
    use Data::Dumper;
    my $s = Dumper($in);

    if($ENV{SCRIPT_NAME}) {# we are in CGI
        $s =~ s/\n/<br>\n/g;
        $s =~ s/    /&nbsp;/g;
    }
    $s;
}

# get_msg_info - return all *info* from the specify message
sub get_msg_info {
    my $file = $_[0];
    my ($str, %info, @hdr, @mtp, %hdr);

    open(my $FD, "<$file") or die "Can't open $file\: $!\n";
    $str = _hdr_read($FD);
    @hdr = hdr_fmt_list($str);
    %hdr = hdr_fmt_hash($str);

    # initialize content-type, set it to text/plain for some broken header!
    @mtp = part_parse($FD, (
                'Content-Type' => hdr_get_hash("Content-Type", %hdr)||'text/plain',
                boundary=> hdr_get_hash("boundary", %hdr)),
                'Content-Transfer-Encoding' => hdr_get_hash('Content-Transfer-Encoding', %hdr)||'8bit',
                filename => hdr_get_hash('filename', %hdr), # XXX
                name => hdr_get_hash('name', %hdr),         # XXX
        );

    # we will fill all duplicate key's value into one key
    # eg: if we have 3 Received hdr, then Received is an array
    # with 3 members. use ref $hdr{$k} to determinate.

    $info{head}{list} = \@hdr;
    $info{head}{hash} = \%hdr;
    $info{body}{list} = \@mtp;
    close $FD;
    \%info;
}

# Update: performance improve.
#
# the original get_msg_header return all hash/list, but it's too
# much wasting CPU cycles. list is much faster than hash.
# get_msg_header - return all *HEADER* info from the specify message

# high performance version
#
# Tip1: use in function FD operation, instead of calling _hdr_read()
#       Because every 7k times calling _hdr_read() will add about
#       1 second overhead!
#
# Tip2: use in function header parse, instead of calling _hdr_fmt_list()
#       Because every 7k times calling _hdr_fmt_list will add about
#       1 second overhead.

# XXX another version of get_msg_hdr_fast, use system api
#
# sysopen + readline version:
# use Fcntl qw(:DEFAULT);
# sysopen (FD, $file, O_RDONLY);
# local $/ = "\n\n";
# $s = readline(FD);
# $s =~ s/\n\s+/ /g;
sub get_msg_hdr_fast {
    my $file = $_[0];
    my $flag = $_[1];
    my ($s, %hdr);
    my $done = 0;
    my $vhead = $flag ? 'To' : 'From';
    my $vlen = $flag ? 2 : 4;

    # XXX FIXME a temporary solution to handle \r\n and \n line break
    open (FD, "< $file") or die "Can't open $file: $!\n";
    local $/ = "\n\n";
    $s = <FD>;
    if (length $s >= (stat $file)[7] - 4) {
        local $/ = "\r\n\r\n";
        seek(FD, 0, 0); # seek to begin
        $s = <FD>;
    }

    $s =~ s/\r*\n[ \t]+/ /g;
    close FD;

    foreach (split(/\n/, $s)) {
        my $len = index($_, ':');
        if ($len == 7 || $len == $vlen || $len == 4) {
            my $k = ucfirst substr($_, 0, $len);
            my $v = substr($_, $len+1); # XXX BUG FIX, old: +2
            if ($k eq 'Subject' || $k eq 'Date' || $k eq $vhead) {
                if ($k eq 'To') {
                    $hdr{'From'} = "$v";
                } else {
                    $hdr{$k}="$v";
                }
                $done++;
            }
        }
        last if ($done>=3);
    }
    \%hdr;
}

sub get_msg_header {
    my $file = $_[0];
    my ($str, %info, @hdr, %hdr);

    open(my $FD, "<$file") or die "Can't open $file\: $!\n";
    $str = _hdr_read($FD);
    @hdr = hdr_fmt_list($str);
    %hdr = hdr_fmt_hash($str);

    $info{head}{list} = \@hdr;
    $info{head}{hash} = \%hdr;

    close FD;
    \%info;
}

#
# hdr_parse_list() -> return hdr_fmt_list() (@)
# hdr_parse_hash() -> return hdr_fmt_hash() (%)
# parse mail header.
sub get_header {
    my $file = "$CFG{path}/$_[0]/cur/$_[1]";
    open(my $FD, "< $file") or die "open $file fail, $!\n";
    return _hdr_read($FD);
    close FD;
}

sub _hdr_read {
    my $FD = $_[0];
    my $seek = $_[1] ? $_[1] : 0;

    my($t0,$t1);
    if($CFG{debug}) {
        $t0 = new Benchmark;
    }
    my $pos = tell $FD;

    # XXX FIXME a temporary solution to deal with CRLF or LF
    my $crlf = 0;
    {
        my $line = <$FD>;
        $crlf = 1 if $line =~ /\r\n$/m;
        seek ($FD, $pos, 0);
    }

    local $/ = $crlf ? "\r\n\r\n": "\n\n";

    $_ = <$FD>;
    if($CFG{debug}) {
        $t1 = new Benchmark;
        print "_hdr_read(): ".timestr(timediff($t1, $t0))."\n";
    }
    seek($FD, $pos, 0) if($seek); # unget the header.
    return ($_);
}

# format mail header into an array HASH
# if you want faster access, see get_msg_hdr_fast()
sub hdr_fmt_list {
    my $s = $_[0];
    $s =~ s/\n[\ \t]+/ /g; # cat \n\t or \n[:space]+ together
    my @a = split(/\r*\n/, $s);

    foreach (0...(scalar @a-1)) {
        my($k, $v) = ($a[$_]=~ m/^([^:]+):\s*(.*)\s*$/g);
        next if (not defined $k);
        # mechanism update: see get_msg_hdr_fast()
        # if($k=~/^subject\s*/i) {
        if(defined $v and $v=~/=\?[^?]*\?[QB]\?[^?]*\?=/) {
            # regexp update: 2005-08-24
            # original code only strip white space in the value, but
            # if this white space is meaning information, then space
            # will lost, so we only cat the space between two Q/B encoded
            # string, this trick help us keep meaning information :-)
            $v=~s/(\?=)\s+(=\?)/$1$2/g; # cat multiple Q/B encode strs into one.
        }
        # }
        $a[$_] = {$k=>$v};
    }
    @a;
}

sub hdr_fmt_hash {
    my @a = hdr_fmt_list($_[0]);
    my %head;
    foreach(@a) {
        # 2005-09-30 Bug fix, ignore garbage string unless
        # it's a HASH reference, useful for irregular header
        next unless (ref $_ eq 'HASH');
        foreach my $k (keys %$_) {
            if($k=~/^Content/i) {
                my @temp = split(/; /,$$_{$k});
                $head{$k} = $temp[0];
                foreach(@temp) {
                    s/\t//g; # bug fix, old code: s/ |\t//g will kill
                             # some boundary="=_alternative 00F44677W889_="
                             # for there is a space, wait for more fix
                    if(/=/) {
                        # This is very important step..careful
                        # it will handle boundary="_xxxx" or boundary = \n\s+"_xxxx"
                        my($k,$v)=m/([a-zA-Z0-9-_]+)\s*=\s*"*([^\"]*)"*\s*/;
                        $head{$k} = $v if not defined $head{$k};
                    }
                }
            }else {# common header(may be in mail head
                if(not defined $head{$k}) {
                    $head{$k} = $$_{$k};
                }else {
                    if(ref $head{$k} eq 'ARRAY') {
                        push @{$head{$k}}, $$_{$k};
                    }else {
                        $head{$k} = [$head{$k}, $$_{$k}];
                    }
                }
            }
        }
    }
    %head;
}

# get a given header name value
sub hdr_get_hash {
    my ($n, %h) = @_;
    foreach (keys %h) {
        if((lc $_) eq (lc $n)) {
            return $h{$_};
        }
    }
    "";
}

sub hdr_get_list {
    my ($n, @h) = @_;
    # $n = lc $n; this is slow
    foreach (@h) {
        foreach my $k (keys %$_) {
            # performance improve, old statement:
            # if((lc $k)=~ /^$n$/)
            #
            # Oops, why did i design such stupid compare? :-)
            # now compare with case sensitive
            if($k eq $n) {
                return $$_{$k};
            }
        }
    }
    "";
}

# parse multipart and return the list to an array.
# -- no any decode process execute
use vars qw(@bdr_depth %bdr_flag);
use vars qw($level_depth $pcnt);

sub part_parse {
    my ($FD, %opt) = (shift, @_);
    my @parts;

    # initialize global varibles, this must be done, or
    # some garbage will still available for the next _mtp_parse()
    # calling, update in 2005-10-03
    undef @bdr_depth;
    undef %bdr_flag;
    $pcnt = 0;
    $level_depth = 0;

    if($opt{'Content-Type'} =~/multipart/i) {
        @parts = _mtp_parse($FD, %opt);
    }else {
        @parts = _stp_parse($FD, %opt);
    }
    @parts;
}

sub _stp_parse {
    my ($FD, %opt) = (shift, @_);
    my (@parts, %part_hdrs);

    # XXX FIXME if content-type fail, then curpos will set to 0,
    # this is false, it should be tell $FD.
    my $curpos = 0;
    seek ($FD, 0, 2);
    my $end = tell $FD;

    push @parts, {
        'size' => $end-$curpos,
        'phead' => \%opt, # XXX still need to optimize here
        'pos_start' => $curpos,
        'pos_end' => $end
    };
    @parts;
}

use vars qw(@bdr_depth %bdr_flag);
undef @bdr_depth;
undef %bdr_flag;
my $pcnt = 0;

use vars qw($level_depth);
$level_depth = 0;

sub _mtp_parse {
    my ($t0, $t1);
    if($CFG{debug}) {
        $t0 = new Benchmark;
    }
    my ($FD, %opt) = (shift, @_);
    my ($boundary, @parts, $type);

    $opt{'Content-Type'}=~m!([^\/]+)/([^\/]+)!;
    my $idflag = $2;
    if($1=~/multipart/i) {
        if(scalar @bdr_depth >0) {
            $boundary = $bdr_depth[scalar @bdr_depth -1];
        }else {
            $boundary = $opt{boundary};
        }
    }

    # increase the depth
    if ($boundary and scalar @bdr_depth <1) {
        push @bdr_depth, $boundary;
    }

    # public varible outside the loop
    my ($flag, $lastpos, $lasthdr);
    my ($end, $curpos);
    while(<$FD>) {
        my $curline = $_;
        if(/^--\Q$boundary\E(--)*/) { # use \n is faster than [^-]
                                  # XXX old code: /^--$boundary(--)*$/
                                  # now remove the $, because some mail
                                  # would contain garbage after boundary,
                                  # without $ will just ignore them :)
            ($end, $curpos) = ($1, tell $FD);
            my %part_hdrs = ();

            if(!$end) {
                %part_hdrs = hdr_fmt_hash(_hdr_read($FD,1));# unget header
                my $ttype = hdr_get_hash("Content-Type", %part_hdrs);
                my $tbdr = hdr_get_hash("boundary", %part_hdrs);

                ## XXX recusive parse MIME, update in 2005-08-16
                $ttype=~~m!([^\/]+)/([^\/]+)!;
                if($1 =~/multipart/i) {
                    # recursive get this *big* part ?
                    push @bdr_depth, $tbdr;
                    $level_depth ++;
                    push @parts, _mtp_parse($FD, ('Content-Type'=>$ttype, boundary=>$tbdr));
                    $level_depth --;
                    $pcnt++;
                    next; # must next, to ignore alternative etc..
                }

                if(!$bdr_flag{$boundary}) {
                    $bdr_flag{$boundary} = 1; # set it and find the begin
                    ($lastpos, $lasthdr) = ($curpos, \%part_hdrs);
                    next; # skip this line
                }else {
                    $pcnt++;
                }
            }else {
                # This is the end of current boundary
                pop @bdr_depth; # remove the lastest members;
                delete $bdr_flag{$boundary};
                push @parts, {
                    'size' => $curpos-$lastpos-length($curline),
                    'phead' => $lasthdr,
                    'pos_start' => $lastpos,
                    'pos_end' => $curpos-length($curline),
                    'idflag' => $idflag.'-'.$level_depth
                };
                return @parts;
                # exit() now, return to the parent call
            }
            push @parts, {
                'size' => $curpos-$lastpos-length($curline),
                'phead' => $lasthdr,
                'pos_start' => $lastpos,
                'pos_end' => $curpos-length($curline),
                'idflag' => $idflag.'-'.$level_depth
                };
            ($lastpos, $lasthdr) = ($curpos, \%part_hdrs);
        }else {
            # print "blah blah blah...\n";
        }
    }

    if($CFG{debug}) {
        $t1 = new Benchmark;
        print "_mtp_parse(): ".timestr(timediff($t1, $t0))."\n";
    }
    if(!$end) {# no end boundary, broken part
        $curpos = tell $FD;
        push @parts, {
            'phead' => $lasthdr,
            'pos_start' => $lastpos,
            'pos_end' => $curpos,
            'size' => $curpos - $lastpos,
            'idflag' => 'broken-0',
        };
    }
    # return parts;
    @parts;
}

sub get_parts {
    my ($file, $mimeid, $mode) = @_;
    my $p = get_msg_info($file)->{body}{list}[$mimeid];

    open(my $FD, "<$file") or die "Can't open:$file $!\n";
    my $rt = dump_parts(
        $FD,
        $p->{pos_start},
        $p->{pos_end},
        $mimeid,
        $mode);
    close $FD;

    $rt;
}

# api: return phead for future use
sub get_parts_name {
    my $parts = shift;
    my (@file);
    foreach my $k (@{$parts->{body}{list}}) {
        my ($name, $size) = _get_part_name($k);
        push @file, {name => $name,
                     size => $k->{'size'},
                     phead => $k->{phead},
                     idflag => $k->{idflag}
                 };
    }
    \@file;
}

sub _get_part_name {
    my $obj = $_[0];
    my $name = $obj->{phead}{'filename'} || $obj->{phead}{'name'};
    my $size = $obj->{'size'};

    if (not defined $name) {
        $name = hdr_get_hash(
                    'Content-Type', %{$obj->{phead}}
                ); # must lc it!:( some urgly mail use some unusual case
        $name = _type2sfx($name);
    }
    return($name, $size);
}

# _type2sfx - return a correct MIME name + suffix from the Content-Type
#             for multipart that missing or without filename
sub _type2sfx {
    my $type = $_[0];
    my $dn = 'unknow';
    $_ = $type;

    if(/text/i) {
        if(/html/i) {
            return "$dn.html";
        }else {
            return "$dn.txt";
        }
    }elsif(/rfc822/i) {
        return "message.eml";
    }elsif(/delivery-status/i) {
        return "delivery-status.txt";
    }elsif(/image/i) {
        if(/jpe*g/i) {
            return "$dn.jpg";
        }elsif(/gif/i) {
            return "$dn.gif";
        }elsif(/png/i) {
            return "$dn.png";
        }
    }elsif(/pgp-signature/) {
        return "$dn.asc";
    }else {
        return "$dn.bin";
    }
}

sub dump_parts {
    my ($t0, $t1);
    if($CFG{debug}) {
        $t0 = new Benchmark;
    }
    my ($FD, $pos1, $pos2, $pnum, $mode) = @_;
    seek($FD, $pos1, 0); # seek to the begin of part
    my %hdr = hdr_fmt_hash(_hdr_read($FD, 0));
    my $charset = hdr_get_hash('charset', %hdr);
    my $ctype = hdr_get_hash('Content-Transfer-Encoding', %hdr);
    my $raw_name = hdr_get_hash('filename', %hdr) || hdr_get_hash('name', %hdr);

    $pnum = untaint($pnum);
    _debug("Decoding.. part$pnum");
    my $name = $raw_name ? decode_words($raw_name) : _type2sfx(hdr_get_hash('Content-Type',%hdr));

    if($mode eq 'to_disk') {
        open(WD, "> /tmp/parts-$pnum-$name") or
            die "Can't write to:$pnum\n";
        my $rem = '';
        while(<$FD>) {
            if (length $rem) {
                $_ = $rem . $_;
                $rem = '';
            }
            print WD decode_it($_, $ctype, $charset, \$rem);
            last if(tell $FD >= $pos2);
        }
        close WD;
    }elsif($mode eq 'to_std') {
        if ($ENV{HTTP_USER_AGENT} =~ /MSIE/i) {
            if (($charset && $charset =~ /^utf-*8$/i) or  # match UTF-8 ?
                charset_detect($name) eq 'utf-8')       { # match UTF-8 ?
                $name =~ /(.*)\.([^\.]+)$/;
                $name = str2url($1).".$2" if $2;
            }
        }
        # dont use printf, or $name after str2url will convert to bad string
        print STDOUT "Content-Disposition: attachment; filename=\"$name\"\n";
        printf STDOUT "Content-Type: %s\n\n", hdr_get_hash('Content-Type', %hdr);

        my $rem = '';
        while(<$FD>) {
            if (length $rem) {
                $_ = $rem . $_;
                $rem = '';
            }
            print STDOUT decode_it($_, $ctype, $charset, \$rem);
            last if(tell $FD >= $pos2);
        }
    }elsif($mode eq 'to_string') {
        my $str = '';
        my $rem = '';
        while(<$FD>) {
            if (length $rem) {
                $_ = $rem . $_;
                $rem = '';
            }
            $str .= decode_it($_, $ctype, $charset, \$rem);
            last if(tell $FD >= $pos2);
        }
        # in general, developer would like to decode string while
        # calling this section :-) XXX
        return $str;
    }

    if($CFG{debug}) {
        $t1 = new Benchmark;
        _debug("dump_parts() use ".timestr(timediff($t1, $t0)));
    }

    $raw_name; # return filename
}

# Experimental multi-charset support in HTML area

# code from Encode::CN::HZ
sub decode_hz {
    my $str = shift;
    my $in_ascii = 1;
    my $ret = '';

    while (length $str) {
        if ($in_ascii) {
            if ($str =~ s/^([\x00-\x7D\x7F]+)//) { # no '~' => ASCII
                $ret .= $1;
            } elsif ($str =~ s/^\x7E\x7E//) { # escaped tilde
                $ret .= '~';
            } elsif ($str =~ s/^\x7E\cJ//) { # '\cJ' == LF in ASCII
                1;
            } elsif ($str =~ s/^\x7E\x7B//) { # '~{'
                $in_ascii = 0; # to GB
            } else { # encounters an invalid escape, \x80 or greater
                last;
            }
        } else {
            # GB mode; the byte ranges are as in RFC 1843.
            if ($str =~ s/^((?:[\x21-\x77][\x21-\x7E])+)//) {
                my $st = $1;
                $st =~ s/(.)/_hz2c($1)/ge;
                $ret .= $st;
            } elsif ($str =~ s/^\x7E\x7D//) { # '~}'
                $in_ascii = 1;
            } else {
                last;
            }
        }
    }
    return $ret;
}

sub _hz2c {
    my $b = sprintf("%b", ord shift);
    return pack('B*', _bto8($b));
}

sub _bto8 {
    my $bit = shift;
    my $len = length $bit;
    if ($len < 7) {
        my $delta = 7 - $len;
        return '1'.('0'x$delta).$bit;
    } elsif ($len == 7) {
        return "1$bit";
    } else {
        return $bit;
    }
}

sub _bfix {
    my $str = shift;

    return $str if ($MIME::Base64::VERSION > 2.2);

    # remove Base64 (v 2.10) stupid *] or \29 non printable char padding
    my $re = "\\x7\\x5d|\\x1d";
    $str =~ s/$re//g;
    $str;
}

sub _qbfix {
    my $str = shift;

    return $str if ($MIME::Base64::VERSION > 2.2);

    # concat 2 QP/B64 string is not standard, this is useful when our
    # Q/B lib is too old, eg: 2.10 that will do bad encoding, this method
    # will correctly recover result and fix a lot :)
    $str =~ s/\?==\?[^?]*\?[QB]\?//g;
    $str;
}

# decode_xx_conv() - decoder for utf8/non-utf8 qp/base64
#
# ($str, $chst) => $str must present, $chst optional
sub decode_qp_conv {
    my($str, $chst) = @_;
    if ($chst) {
        if ($chst =~ /^(hz|hz-gb|hz-gb-2312)/i) {
            $str = decode_hz(decode_qp($str));
        } else {
            $str = decode_qp($str);
        }
        return iconv($str, $chst, 'utf-8');
    }
    decode_qp($str);
    # str2ncr($chst,decode_qp($str));
}

sub decode_base64_conv {
    my($str, $chst) = @_;
    if ($chst) {
        if ($chst =~ /^(hz|hz-gb|hz-gb-2312)/i) {
            $str = decode_hz(decode_base64($str));
        } else {
            $str  = decode_base64($str);
        }
        return iconv($str, $chst, 'utf-8');
    }
    decode_base64($str);
    # str2ncr($chst,decode_base64($str));
}

sub decode_words {
    my $s = $_[0];
    my $res = undef;

    return if not defined $s; # null

    # remove spacing between 2 QP/B64 string
    $s =~ s/(\?=)\s+(=\?)/$1$2/g;
    $s = _qbfix($s);
    my @parts = split(/(=\?[^?]*\?[QB]\?[^?]*\?=)/i, $s);
    foreach(@parts) {
        # Ignore null or space part.
        next if(/^ $/ or /^$/);
        s/=\?[^?]*\?Q\?([^?]*)\?=/decode_qp_conv($1)/gie;
        s/=\?[^?]*\?B\?([^?]*)\?=/decode_base64_conv($1)/gie;
        $res .= $_;
    }
    _bfix($res);
}

sub decode_words_utf8 {
    my $s = $_[0];
    my $res = undef;

    return if not defined $s;

    # remove spacing between 2 QP/B64 string
    $s =~ s/(\?=)\s+(=\?)/$1$2/g;
    $s = _qbfix($s);
    my @parts = split(/(=\?[^?]*\?[QB]\?[^?]*\?=)/i, $s);
    foreach(@parts) {
        next if (/^\s+$/ or /^$/);
        s/=\?([^?]*)\?Q\?([^?]*)\?=/decode_qp_conv($2, $1)/gie;
        s/=\?([^?]*)\?B\?([^?]*)\?=/decode_base64_conv($2, $1)/gie;
        $res .= $_;
    }
    _bfix($res);
}

sub decode_it {
    my ($s, $type, $charset, $ref) = @_;

    if ($type=~/base64/i) {
        $s =~ s/\r?\n//gs;
        if (my $mod = (length($s) % 4)) {
            $$ref = substr($s, -$mod);
            if (substr($$ref,-1) ne '=') {
                $s = substr($s, 0, -$mod);
            } else {
                $$ref = '';
            }
        }
        return decode_base64($s);
    }
    if ($type=~/quoted-printable/i) {
        return decode_qp($s);
    }
    if ($type=~/7bit/) {
        if ($charset =~/^(hz|hz-gb|hz-gb-2312)/i) {
            return decode_hz($s);
        }
        return $s;
    }
    if ($type=~/8bit/) {
        return $s;
    }
    return $s;
}

sub html_fmt {
    my $s = $_[0];
    return $s unless($s);
    $s=~s#&#&amp;#g;
    $s=~s#<#&lt;#g;
    $s=~s#>#&gt;#g;
    $s=~s#"#&quot;#g;
    $s
}

1;
