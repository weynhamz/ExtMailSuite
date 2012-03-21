#!/usr/bin/perl -w
#
# makeglobabook.pl
# make extmail globa book for mysql server.
# author :fengyong fengyongchuang@yahoo.com.cn
# 2007-01-22
# ver 0.1
#
# forum: http://www.extmail.org/forum/thread-3749-1-2.html

use strict;
use DBI;
use IO::File;
use lib "../libs";
use POSIX qw(strftime);
use vars qw(@ISA $usercfg $sysconfig);
use Ext::Config;

my $gbook="../globabook.cf";
my $time = strftime ("%Y\-%m\-%d\_%H\:%M\:%S", localtime);
$Ext::Config::PF= "../webmail.cf";

system("mv $gbook $gbook.$time") if -f $gbook;

if (!$SYS_CFG) {
	    Ext::Config::import;
}
$sysconfig = $SYS_CFG;

my $dbuser = $sysconfig->{SYS_MYSQL_USER};
my $dbpassword = $sysconfig->{SYS_MYSQL_PASS};
my $dbname = $sysconfig->{SYS_MYSQL_DB};

my $dbh = DBI->connect("dbi:mysql:database=$dbname",$dbuser,$dbpassword)
    or die "Can not connect DB server!\n";

my $query=qq~SELECT `username`,`name` FROM mailbox ~;
my $sth=$dbh->prepare($query);
$sth->execute();

my $fh=IO::File->new(">$gbook");
print $fh "Name,Mail,Company,Phone\n";

while (my @row=$sth->fetchrow_array()){
	print $fh "\"$row[1]\",\"$row[0]\"\n";
}
