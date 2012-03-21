#!/usr/bin/perl
# Reset Extman administrator mysql database password
# Author: fengyong
# date: 2007-09-26
# ver : 0.1
#
# forum: http://www.extmail.org/forum/thread-6657-1-2.html
use strict;
use lib "../libs";
use Ext::Passwd;
use DBI;
use Ext::Config;
use vars qw($SYS_CFG);
$Ext::Config::PF='../webman.cf';
if (!$SYS_CFG){
	Ext::Config::import;
}

my $dbh=DBI->connect("dbi:mysql:database=$SYS_CFG->{SYS_MYSQL_DB};host=$SYS_CFG->{SYS_MYSQL_HOST}",
	$SYS_CFG->{SYS_MYSQL_USER},$SYS_CFG->{SYS_MYSQL_PASS})
	or die "Can't connect MySQL server!\n";


my %hashmode= (
	help=>\&usage,
	list=>\&list,
	reset=>\&reset
);

if (exists $hashmode{$ARGV[0]}){
	my $sub=$hashmode{$ARGV[0]};
	&$sub;
}else{
	&usage;
}

sub list {
	my $sql=qq~SELECT * FROM `manager` ~;
	my $sth=$dbh->prepare($sql);
	$sth->execute();
	my $row;
	while ($row=$sth->fetchrow_hashref()){
		print $row->{username},"\n";
	}
}
sub reset {
	if ($#ARGV != 2){ &usage;};
	my $username=$ARGV[1];
	my $passwd=$ARGV[2];
	my $enpasswd=getpasswd($passwd);
	my $sql=qq~UPDATE `manager` SET `password`='$enpasswd' WHERE `username`='$username' LIMIT 1~;
	$dbh->do($sql);
	print "SUCCESS!\n Your new password is : $ARGV[2]\n";
}
sub getpasswd {
	my $encryptpasswd=shift;
	my %passwdmap = (
		crypt=>\&Ext::Passwd::encrypt_crypt,
		clerttext=>\&Ext::Passwdencrypt_clear,
		plain=>\&Ext::Passwd::encrypt_clear,
		md5=>\&Ext::Passwd::encrypt_md5,
		md5crypt=>\&Ext::Passwd::encrypt_md5,
		'plain-md5'=>\&Ext::Passwd::encrypt_plain_md5,
		'ldap-md5'=>\&Ext::Passwd::encrypt_ldap_md5,
		sha=>\&Ext::Passwd::encrypt_sha,
		sha1=>\&Ext::Passwd::encrypt_sha1
	);
	my $type=$SYS_CFG->{SYS_CRYPT_TYPE};
	if (exists $passwdmap{$type}){
		my $sub=$passwdmap{$type};
		return &$sub($encryptpasswd);
	}else{
		die "UNKNOW PASSWORD TYPE SEE: webman.cf -> SYS_CRYPT_TYPE option!\n";
	}
}

sub usage {
print qq~
	Usage:
	$0 reset <username> <newpassword>
	$0 list
	$0 help

	Command:
	reset --- Will reset ExtMan password for username.
	list  --- List of ExtMan administrator.
	help ---  print this message.

	Option:
	<username> --- Extman login user name,
	*if you unknow username please run "$0 list " before .
	<newpassword> --- set your new password to Extman  administrator.

	---fengyong 2007/09/25----
~;
	exit;
}
