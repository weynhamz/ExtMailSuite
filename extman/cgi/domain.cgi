#!/usr/bin/perl -w
# vim: set cindent expandtab ts=4 sw=4:
use vars qw($DIR);
BEGIN {
    if ($ENV{SCRIPT_FILENAME} =~ m!(.*/)cgi!) {
        $DIR = $1;
    }else {
        $DIR = '../';
    }
    unshift @INC, $DIR . 'libs';

    #print "Content-type: text/html\n\n";
    #$SIG{__DIE__} = $SIG{__WARN__} = sub { print "@_" };
}
use strict;

eval {
    require Ext::MgrApp::Domain;
    my $app = Ext::MgrApp::Domain->new( config => $DIR . 'webman.cf',
                                        directory => $DIR );
    $app->run;
};

if ($@) {
    print "Content-type: text/html\n\n";
    print "$@";
}
