#!/usr/bin/perl -w
#   userinfo.pl: make a extmail global book, created from fengyong's script.
#	 Author: chifeng <chifeng At gmail.com>
#	   Date: Sat Nov 24 17:08:42 CST 2007
#      Homepage: http://www.extmail.org
#	Version: 0.1
#
#
use vars qw($DIR);

BEGIN {
    my $path = $0;
    if ($path =~ s/tools\/[0-9a-zA-Z\-\_]+\.pl$//) {
	if ($path !~ /^\//) {
	    $DIR = "./$path";
	} else {
            $DIR = $path;
        }
    } else {
        $DIR = '../';
    }
    unshift @INC, $DIR .'libs';
};

use POSIX qw(strftime);
use Ext::Mgr;
use CmdTools;
use Ext::DateTime qw(time2epoch epoch2time);

print "\nUsage: $0 domain.tld\n" and exit(255) unless $#ARGV == 0;

my $ctx = CmdTools->new( config => $DIR . '/webman.cf', directory => $DIR );
my $c = \%Ext::Cfg;
my $mgr = $ctx->ctx; # backend object

my $domain = "$ARGV[0]";
if(!($mgr->get_domain_info($domain))){
    print "$domain no exists!\n";
    exit ;
}
print "Name,Mail,Company,Phone\n";
my $ul = $mgr->get_users_list($domain);
foreach my $u (@$ul) {
    print "\"$u->{cn}\"".",\"$u->{mail}\""."\n";
}
