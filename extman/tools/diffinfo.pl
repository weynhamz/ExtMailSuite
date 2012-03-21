#!/usr/bin/perl -w
#   diffinfo.pl: diff user info and user homedir
#	 Author: chifeng <chifeng At gmail.com>
#	   Date: Fri Nov 16 14:45:06 CST 2007
#      Homepage: http://www.extmail.org
#	Version: 0.2
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

# use strict; # developing env
no warnings; # production environment
use POSIX qw(strftime);
use Ext::Mgr;
use CmdTools;
use Ext::DateTime qw(time2epoch epoch2time);

print "\nUsage: $0 domain.tld\n" and exit(255) unless $#ARGV == 0;

my $ctx = CmdTools->new( config => $DIR . '/webman.cf', directory => $DIR );
my $c = \%Ext::Cfg;
my $mgr = $ctx->ctx; # backend object
my $basedir = $c->{SYS_MAILDIR_BASE};

#home directory
my $homedir;
my $domain = "$ARGV[0]";
if(!($mgr->get_domain_info($domain))){
    print "$domain no exists!\n";
    exit ;
}
my $ul = $mgr->get_users_list($domain);
print "\n----No homedir users----------\n";
foreach my $u (@$ul) {
    $homedir = "$basedir/".$u->{homedir};
    if ( -e $homedir) {
	print "";
    }else{
	print $u->{mail}."\n";
    }
}

#Registration Information
my $unemail;
my $dir=$basedir."/".$domain;
opendir DIR, $dir or die "open $dir error: $!\n";
my @list = grep { !/^\.$/ && !/^\.\.$/ } readdir DIR;
closedir DIR;
print "\n----No reg_info users----------\n";
foreach my $un (@list){
    $unemail = $un."@"."$domain";
    if( !($mgr->get_user_info($unemail)) ){
	print "$unemail\n";
    }
}
