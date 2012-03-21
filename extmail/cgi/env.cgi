#!/usr/bin/perl -w
use vars qw($DIR);

BEGIN {
	if ($ENV{SCRIPT_FILENAME} =~ m!(.*/)cgi!) {
		$DIR = $1;
	}else {
		$DIR = '../';
	}
	my $path = $DIR . 'libs';
	unshift @INC, $DIR . 'libs' unless grep /^$path$/, @INC;

	#print "content-type: text/html\r\n\r\n";
	#$SIG{__WARN__} = $SIG{__DIE__} = sub { print @_ };
}
use strict;
use Ext::Lang;
use Ext::CGI;
my $q = Ext::CGI->new;

print "Content-type: text/html\r\n\r\n";
print "<h1>CGI/FCGI Envirement</h1>\n";

print "<br>\n";
print "<table width=100% border=1>\n";
foreach my $k (keys %ENV) {
    # select(undef, undef, undef, 0.5);
    my $val = $ENV{$k};
    if(not defined $val or $val eq "") {
        $val = "&nbsp;";
    }
    print "<tr><td>$k</td><td>$val</td></tr>\n";
}

print "<tr><td>Guessed I18n</td><td style=\"color: #FF0000\">".guess_intl()."</td></tr>\n";
print "<tr><td>SID in cookie</td><td style=\"color: #FF0000\n\">&nbsp; ".$q->get_cookie('sid')."</td></tr>\n";

print "<tr><td>Process ID</td><td>$$</td></tr>\n";
print "</table>\n";
