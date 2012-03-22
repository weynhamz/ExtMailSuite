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
package Ext::Utils;
use strict;
use Exporter;
use Fcntl qw(SEEK_CUR :flock);
use vars qw(@ISA @EXPORT @EXPORT_OK);

@ISA = qw(Exporter);
@EXPORT = qw(str2url url2str html_escape reset_working_path
    get_remoteip str2ncr from_to filename2std untaint nl2br
    _index _substr _length time_offset txt2link expire_calc
    human_size txt2html html2txt htmlsanity strsanity
    foldername_ok myceil name2sort sort2name
);

@EXPORT_OK = qw(lock unlock haslock);

# Converts a string into URL-encoded format
sub str2url {
    my $rv = $_[0];
    return $rv unless $rv;
    $rv =~ s/([^A-Za-z0-9])/sprintf("%%%2.2X", ord($1))/ge;
    return $rv;
}

# Converts a URL-encoded string to the original
sub url2str {
    my $rv = $_[0];
    return $rv unless $rv;
    $rv =~ s/\+/ /g;

    # if it's javascript escaped string, we call ucs4_to_utf8
    if ($rv =~ /%u([0-9a-fA-F]{4})/) {
        $rv=~ s/%u([0-9a-fA-F]{4})/ucs4_to_utf8(hex($1))/ge;
    }

    # XXX here we replace c with C, or perl will complain, but
    # we should take further research the difference between
    # c and C
    $rv =~ s/%(..)/pack("C",hex($1))/ge;
    return $rv;
}

# convert UCS4 to UTF8 - from openwebmail
# string passed by with javascript escape() will encode CJK char to unicode
# like %u5B78%u9577, this is used to turn %u.... back to the CJK char
# eg: $str=~ s/%u([0-9a-fA-F]{4})/ucs4_to_utf8(hex($1))/ge;
sub ucs4_to_utf8 {
    my $val=$_[0];
    my $c;
    if ($val < 0x7f){            #0000-007f
        $c .= chr($val);
    } elsif ($val < 0x800) {     #0080-0800
        $c .= chr(0xC0 | ($val / 64));
        $c .= chr(0x80 | ($val % 64));
    } else {                     #0800-ffff
        $c .= chr(0xe0 | (($val / 64) / 64));
        $c .= chr(0x80 | (($val / 64) % 64));
        $c .= chr(0x80 | ($val % 64));
    }
}

# get remote client ipv4 address
sub get_remoteip {
    $ENV{REMOTE_ADDR};
}

# html_escape - to escape from special HTML tags
sub html_escape {
    my $s = $_[0];
    my $o = $_[1] || 'NO_AMP';
    return $s unless($s);

    $s =~ s!&!&amp;!g unless ($o eq 'NO_AMP');
    $s =~ s!'!&#039;!g;
    $s =~ s!"!&quot;!g unless ($o eq 'NO_QUOTES');
    $s =~ s!>!&gt;!g unless ($o eq 'NO_QUOTE');
    $s =~ s!<!&lt;!g;
    $s =~ s! !&nbsp;!g unless ($o eq 'NO_SPACE');
    $s =~ s!\r?\n!</br>\n!g;
    $s;
}

sub human_size {
    my $s = $_[0];
    if($s<1024) {
        return sprintf("%0.2f", $s/1024)."K";
    }elsif($s<1024*1024) {
        return sprintf("%0.1f", $s/1024)."K";
    }else {
        return sprintf("%0.1f", $s/(1024*1024))."M";
    }
}

sub myceil {
    my $num = shift;
    return 0 if ($num ==0);
    return int($num)+1 if ($num =~ /\./);
    $num;
}

# html or text filter
#
# how to convert a text to html format ?
#
# step1: escape &, ', "", >, <, \r*\n
# step2: special convert space to &nbsp;
# step3: do txt2link conversion (with &nbsp; care)
# step4: convert space back to &nbsp;
sub txt2html {
    my $str = shift;
    my %opt = @_;

    if ($opt{html_escape}) {
        $str = html_escape($str, 'NO_SPACE');
    }
    if ($opt{txt2link}) {
        $str = txt2link($str);
        $str =~ s/ /&nbsp;/gs;
        $str =~ s/<a(?:&nbsp;)+href="/<a href="/gs;
    }
    $str;
}

sub txt2link {
    my $s = $_[0];
    my $re1 = 'http|ftp|news|rss';
    my $re2 = '[^ <>\r\n"\']+';

    $s =~ s!($re1)://($re2)!<a href="$1://$2" target=_blank>$1://$2</a>!gs;
    $s;
}

sub html2txt {
    my $s = shift;
    $s =~ s!\r*\n!!g;
    $s =~ s!</li>!\r\n!gi;
    $s =~ s!</p>!\r\n\r\n!gi;
    $s =~ s!</div>!\r\n!gi;
    $s =~ s!<script[^>]*?>.*?</script>!!gsi;
    $s =~ s!<\s*/?\s*br\s*/?\s*>!\r\n!gsi;
    $s =~ s!<[\!]*?[^<>]*?>!!gsi;
    $s =~ s!&(quot|\#34);!"!gi;
    $s =~ s!&(amp|\#38);!&!gi;
    $s =~ s!&(lt|\#60);!<!gi;
    $s =~ s!&(gt|\#62);!>!gi;
    $s =~ s!&(nbsp|\#160);! !gi;
    $s =~ s!&(iexcl|\#161);!chr(161)!egi;
    $s =~ s!&(cent|\#162);!chr(162)!egi;
    $s =~ s!&(pound|\#163);!chr(163)!egi;
    $s =~ s!&(copy|\#169);!chr(169)!egi;
    $s =~ s!&\#(\d+);!chr($1)!egi;
    $s;
}

# js removement code from openwebmail
my @jsevents=('onAbort', 'onBlur', 'onChange', 'onClick', 'onDblClick',
    'onDragDrop', 'onError', 'onFocus', 'onKeyDown', 'onKeyPress',
    'onKeyUp', 'onLoad', 'onMouseDown', 'onMouseMove', 'onMouseOut',
    'onMouseOver', 'onMouseUp', 'onMove', 'onReset', 'onResize',
    'onSelect', 'onSubmit', 'onUnload', 'window.open',
    '@import', 'window.location', 'location.href',
    'document.url', 'document.location', 'document.referrer');

sub htmlsanity {
    my $html = shift;
    my $op = shift || '';

    $html =~ s!<head>.*</head>!!gsi if ($op eq 'NO_HEAD');
    # $html =~ s!<script[^<>]*>.*</script>!!gsi;

    foreach my $event (@jsevents) {
        $html=~s/$event\s*(=*)/x_$event$1/isg;
    }
    $html=~s/<script([^\<\>]*?)>/<disable_script$1>\n<!--\n/isg;
    $html=~s/<!--\s*<!--/<!--/isg;
    $html=~s/<\/script>/\n\/\/-->\n<\/disable_script>/isg;
    $html=~s/\/\/-->\s*\/\/-->/\/\/-->/isg;
    $html=~s/<([^\<\>]*?)javascript:([^\<\>]*?)>/<$1disable_javascript:$2>/isg;

    if ($op eq 'NO_HEAD' && $html =~ m!<body[^<>]*>(.*)</body>!is) {
        $html = $1;
    }
    $html;
}

sub strsanity {
    my $str = shift;
    my $type = shift || 'eml';

    # valid type is 'eml', 'num', 'letter'
    # eml: '0-9', 'a-z', 'A-Z', '-', '_', '@', '.', '#', '!', '='
    # num: '0-9',
    # letter: '0-9', 'a-z', 'A-Z'
    if ($type eq 'eml') {
        $str =~ s/[^0-9a-zA-Z@\-_\.#!=]+//gm;
    } elsif ($type eq 'num') {
        $str =~ s/[^0-9]//gm;
    } elsif ($type eq 'letter') {
        $str =~ s/[^a-zA-Z]//gm;
    }
    $str;
}

# nl2br - convert newline to <br />\n, same as php4 nl2br()
sub nl2br {
    my $s = $_[0];
    $s =~ s!(<br />)*\r*\n!<br />\n!gm;
    $s;
}

sub reset_working_path {
    my $src=$ENV{SCRIPT_FILENAME};
    $src=~s#(.*)/[^\/]+$#$1#;
    chdir(untaint($src));
    undef $src;
}

sub untaint {
    local $_ = shift;    # this line makes param into a new variable. don't remove it.
    local $1;            # fix perl $1 taintness propagation bug
    m/^(.*)$/s;
    return $1;
}

# str2ncr => string to NCR (Numeric character reference)
# need perl 5.8.0 abover or Text::Iconv
sub str2ncr {
    my($chst, $str) = @_;
    my $nstr = "";
    my $cvt = "";
    return $str unless($str);

    $chst = _fixcharset($chst);

    eval {
        require Text::Iconv;
        $cvt = Text::Iconv->new($chst, 'UTF-16');
    };
    if($@=~/Can't locate/) {# means not found
        undef $@; # cleanup
        $nstr = $str; # save a copy
        eval {
            require Encode;
            Encode::from_to($nstr, $chst, 'UTF-16LE');
        };
        return $str if($@);
    }elsif($@) {
        return $str;
    }else {
        $nstr = $cvt->convert($str);
        return $str unless($nstr); # return if nstr null
    }

    my @s = split(//,$nstr);
    my $out = "";
    for(my $i=0;$i<scalar @s;$i++,$i++) {
        # according to RFC2781, 256 => 0x100(00)
        my $code = ord($s[$i+1])*256+ord($s[$i]);
        if($code < 128) {
            $out .= chr($code);
        }elsif($code != 65279) { # UTF16 prefix
            $out .= '&#'.$code.';';
        }
    }
    $out;
}

# a small enhanced function to do iconv(3)
sub from_to {
    my ($str, $fchar, $tchar) = @_;
    my $nstr = '';
    my $cvt = '';
    return $str unless($str);

    $fchar = _fixcharset($fchar);
    $tchar = _fixcharset($tchar);

    eval {
        require Text::Iconv;
        $cvt = Text::Iconv->new($fchar, $tchar);
    };

    if($@=~/Can't locate/) {# means not found
        undef $@; # cleanup
        $nstr = $str; # save a copy
        eval {
            require Encode;
            Encode::from_to($nstr, $fchar, $tchar);
        };
        return $str if($@);
    }elsif($@) {
        return $str;
    }else {
        $nstr = $cvt->convert($str);
        return $str unless($nstr); # return if nstr null
    }

    $nstr;
}

# normalize filename to a standard one
sub filename2std {
    my $filename = shift;
    if($filename=~/\\/) { # win32 filename, eg: c:\\doc\\test.gif
        $filename=~ s#.*\\+([^\\]+)$#$1#;
    }elsif($filename=~/\//) { # Unix path name, eg: /path/to/test.gif
        $filename=~ s#.*\/+([^\/]+)$#$1#;
    }else {
        $filename=~ s#\s##g; # remove all space
    }
    $filename
}

# it will fix a bug in some c iconv(3) lib, that can't handle
# gb2312 + some GBlized big5 characters, wait for new fix
sub _fixcharset {
    my $char = shift;
    if ($char =~ /^gb2312$/i) {
        return 'GBK';
    }
    $char;
}

# a filehandler oriented pseudo index function
# _index FILEHANDLE SUBSTR POSITION

sub _index {
    my ($fh, $substr, $pos) = @_;
    my $BUFSIZ = 65536;
    my ($buf, $offset);

    if (defined($pos)) {
        seek($fh, $pos, 0);
        $offset = $pos;
    } else {
        $offset = tell $fh;
    }

    my ($i, $len);
    while (read($fh,$buf,$BUFSIZ)) {
        $i = index($buf,$substr);

        # found it and return
        if($i != -1) {
            $offset += $i;
            return $offset;
        }

        # search the last new line
        $i = rindex($buf, "\n");
        $len = length($buf);
        if ($len == $BUFSIZ && $i<($len-1) && ($i!=-1)) {
            seek($fh, $i+1-$len, 0);
            $offset += $i+1;
            next;
        }
        $offset += $BUFSIZ;
    }
    -1;
}

# a filehandler oriented pseudo substr function
# _substr FILEHANDLE OFFSET LENGTH
sub _substr {
    my ($fh, $offset, $len) = @_;
    my $pos = tell $fh;
    # XXX FIXME the $len
    if (not defined($len) or $len <=0) {
        seek($fh, 0, 2); # to the end
        $len = tell($fh)-$offset+1;
    }
    my $buf;
    seek($fh, $offset, 0);
    # if the $len set to very large, this read
    # will eat a lot of memory, be careful
    read($fh, $buf, $len);
    seek($fh, $pos, 0);
    return $buf;
}

# a filehanlder oriented pseudo leng function
# _length FILEHANDLE
sub _length {
    my $fh = $_[0];
    my $pos = tell $fh;
    seek ($fh,0,2); # to the end
    my $len = tell ($fh) + 1;
    seek ($fh, $pos, 0);
    return $len;
}

# a function similar to tell() for sys* call
sub systell {
    sysseek($_[0], 0, SEEK_CUR)
}

# locking / unlocking function, simple but useful for
# unique process.
sub lock {
    my $fh = $_[0];
    flock ($fh, LOCK_EX|LOCK_NB);
}

sub unlock {
    my $fh = $_[0];
    flock ($fh, LOCK_UN);
    1;
}

sub haslock {
    my $fh = $_[0];
    if (lock($fh)) {
        unlock($fh);
        return 0; # means no lock
    }
    1;
}

# a function to convert timezone to time offset compare to GMT
sub time_offset {
    my $timez = shift;
    $timez =~ s/ //g;
    if ($timez =~ /^(-|\+)(\d+)/) {
        my ($tok, $hour) = ($1, $2);

        $hour =~ s/0//g;
        $hour ||= 0;
        return $tok.$hour * 3600;
    }
    0;
}

sub expire_calc {
    my $time = shift;
    my %multi = ( 's' => 1,
                  'm' => 60,
                  'h' => 60*60,
                  'd' => 60*60*24,
                  'M' => 60*60*24*30,
                  'y' => 60*60*24*30*365,
                );

    my $offset;
    if (!$time || (lc $time eq 'now')) {
        $offset = 0;
    } elsif ($time =~ /^\d+$/) { # advoid 6h return!
        return $time;
    } elsif ($time =~ /^([+-]?(?:\d+|\d*\.\d*))([mhdMy]?)/) {
        $offset = ($multi{$2} || 1)*$1;
    } else {
        return $time;
    }
    return (time + $offset);
}

sub foldername_ok {
    my ($dir, $len) = @_;
    if ($dir =~ /[!~#\$\%\^\&\(\)\<\>\?\/\\]/) {
        # [\^\%\/\#\!\~(\)]/) {
        return 0;
    }
    if (defined $len && $len >0) {
        # utf8 will use 3 bytes as one charactor
        return 0 if (length $dir > $len);
    }
    1;
}

# sorting and paging utils funct*
sub sort2name {
    my $method = shift;
    my %map = (
        Dt => 'by_date',
        Ts => 'by_time',
        Sz => 'by_size',
        Fr => 'by_from',
        Sj => 'by_subject',
        Fs => 'by_status',
        rDt => 'by_date_rev',
        rTs => 'by_time_rev',
        rSz => 'by_size_rev',
        rFr => 'by_from_rev',
        rSj => 'by_subject_rev',
        rFs => 'by_status_rev'
    );
    $map{$method} || 'by_time'; # if null, try by_time
}

sub name2sort {
    my $name = shift;
    my %map = (
        'by_date' => 'Dt',
        'by_time' => 'Ts',
        'by_size' => 'Sz',
        'by_from' => 'Fr',
        'by_subject' => 'Sj',
        'by_status' => 'Fs',
        'by_date_rev' => 'rDt',
        'by_time_rev' => 'rTs',
        'by_size_rev' => 'rSz',
        'by_from_rev' => 'rFr',
        'by_subject_rev' => 'rSj',
        'by_status_rev' => 'rFs'
    );
    $map{$name} || 'Ts'; # if null, try Ts
}

1;
