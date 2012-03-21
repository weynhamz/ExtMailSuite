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

    #print "content-type: text/html\n\n";
    #$SIG{__WARN__} = $SIG{__DIE__} = sub { print @_ };
}
use strict;

eval {
    require Ext::MgrApp::ForgetPwd;
    my $app = Ext::MgrApp::ForgetPwd->new( config => $DIR . 'webman.cf',
                                       directory => $DIR );
    $app->run;
};

if ($@) {
    print "Content-type: text/html\n\n";
    print "$@";
}
