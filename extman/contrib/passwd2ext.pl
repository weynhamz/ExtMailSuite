#
# passwd2ext.pl - a small script to import /etc/password or shadow
# 		  accounts into extmail/webman
#
# written in: 22 Dec 2005
# Update  in: 25 Sep 2008
#
# Copyright (c) 1998-2008 He zhiqiang <hzqbbc@hzqbbc.com>
use strict;
use POSIX qw(strftime);
use DBI;

# please modify the following varibles to
# suit your real server configuration
my $sock		= '/var/lib/mysql/mysql.sock';
my $dbname 		= 'extmail';
my $dbuser 		= 'webman';
my $dbpass		= 'webman';
my $host		= 'localhost';
my $quota		= '10485760S'; # 10MB
my $netdisk_quota	= '10485760S'; # 10MB
my $uid			= '1000';
my $gid			= '1000';

die "$0 default_domain\n" unless ( scalar @ARGV > 0);

my $dbh = DBI->connect("DBI:mysql:database=$dbname;host=$host;mysql_socket=$sock",
    $dbuser, $dbpass, {'RaiseError' => 1});

my $domain = $ARGV[0];
open (FD, "< /etc/shadow") or die "$!\n";
while (<FD>) {
    chomp;
    my @arr = split(/\:/, $_);
    my $name = $arr[0];
    my $pass = $arr[1];

    my $createdate = strftime("%Y-%m-%d %H:%M:%S", localtime);

    my $SQL = "INSERT into mailbox VALUES (
    	'$name\@$domain',
	'$name',
	'{CRYPT}$pass',
	'$name',
	'',
	'$domain/$name/Maildir/',
	'$domain/$name',
	'$quota',
	'$netdisk_quota',
	'$domain',
	'$uid',
	'$gid',
	'$createdate',
	'0000-00-00',
	'0',
	'0',
	'0',
	'0',
	'0',
	'1',
	'0',
	'',
	'',
	)";

    unless ($pass =~ /(!!|\*)/ or $name eq 'root') {
	$dbh->do($SQL);
	print $dbh->errstr if ($dbh->err);
    }
}

close FD;
