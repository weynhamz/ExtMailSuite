#!/usr/bin/perl -w
# vim: set ci et ts=4 sw=4:
use vars qw($DIR);
BEGIN {
    if ($ENV{SCRIPT_FILENAME} =~ m!(.*/)cgi!) {
        $DIR = $1;
    }else {
        $DIR = '../';
    }
    my $path = $DIR . 'libs';
    unshift @INC, $path unless grep /^$path$/, @INC;

    #print "Content-type: text/html\r\n\r\n";
    #$SIG{__WARN__} = $SIG{__DIE__} = sub { print "@_" };
}

use strict;
use vars qw($VERSION);
use Ext;
use Ext::CaptCha;
use Ext::CGI;
use Ext::GD;

$VERSION = '0.3';

Ext->new( config => $DIR . 'webman.cf' );

my $q = Ext::CGI->new;
my $cap = Ext::CaptCha->new(
    key => $Ext::Cfg{SYS_CAPTCHA_KEY} || 'extmail',
    length => $Ext::Cfg{SYS_CAPTCHA_LEN} || 6,
);

if (my $raw = $q->cgi('code')) {
    print "content-type: text/html\n\n";
    print "OK!\n" if ($cap->verify(lc $raw, $q->get_cookie('scode')));
} else {
    my $code = $cap->gen_code;
    my $data = $cap->encrypt(lc $code);

    $q->set_cookie(
        name => 'scode',
        value => $data,
        expires => $q->expires('24h'), # much longer than 3h
        path => '/',
    );
    $q->send_cookie;
    print "Content-type: image/png\n\n";

    my $im_length = (length($code)+1) * 10;
    my $im = Ext::GD->new($im_length, 25);

    my $c_background =  $im->colorAllocate('f0f0f0');
    my $c_border =      $im->colorAllocate('000000');
    my $c_line =        $im->colorAllocate('c0c0c0');
    my $color1 =        $im->colorAllocate('336699');
    my $color2 =        $im->colorAllocate('ff0000');

    $im->fill(50, 50, $c_background);

    for (my $i=0;$i < $im_length; $i += (2+int rand 10)) {
        $im->line($i, 0, $i, 24, $c_line);
    }

    for (my $i=0;$i < 25; $i += (2+int rand 5)) {
        $im->line(0, $i+5, $im_length-1, $i, $c_line);
    }

    $im->rectangle(0, 0, $im_length-1, 24, $c_border);

    my $xp = 1;
    my $font = "$DIR/addon/font.ttf";
    while (length (my $chr = substr($code, 0, 1))) {
        $code = substr($code, 1);
        my $flag = int rand 2 == 0;
        my $color = $flag ? $color1 : $color2;

        if (-r $font) {
            my $pie = 3.1415926;
            my $onedg = $pie/180;
            my $flag = int rand 2 == 0;
            my $rotate = ($flag?'-':'+').10 * $onedg;
            $im->stringFT(
                $color,             # color to draw
                $font,              # TTF font path
                14,                 # font size
                $rotate,            # rotate radian
                $xp,                # x point
                12+int rand 9,      # y point
                $chr,               # character to draw
            );
        } else {
            $im->string(
                'gdLargeFont',      # gd format font name
                $xp,                # x point
                int rand 9,         # y point
                $chr,               # character to draw
                $color,             # color to draw
            );
        }
        $xp += 10 + (int rand 3);
    }

    binmode STDOUT;
    print $im->png;
}
