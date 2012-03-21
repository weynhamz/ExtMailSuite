#!/usr/bin/perl -w
# vim: set cindent expandtab ts=4 sw=4:
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
    #$SIG{__DIE__} = $SIG{__WARN__} = sub { print "@_" };
}
use strict;

eval {
    require Ext::App::Compose;
    my $app = Ext::App::Compose->new( config => $DIR . 'webmail.cf',
                                      directory => $DIR );
    $app->run;
};

if ($@) {
    print "Content-type: text/html\r\n\r\n";
    print "$@";
}
