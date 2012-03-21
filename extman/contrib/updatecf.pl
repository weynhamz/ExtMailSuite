#!/usr/bin/perl
# author :fengyong
# mail: fengyongchuang@yahoo.com.cn
# date: 2008-03-31
# version: 0.01
#
# forum: http://www.extmail.org/forum/thread-7323-1-1.html
use strict;

my $token_key="[a-zA-Z0-9-_]+";
my $token_val=".+";
my $token_sep ="\\s*=\\s*";

# get old file
my $mode= shift;
my %cmds=(
	help=>\&help,
	start=>\&start
);
if (exists $cmds{$mode}){
	$cmds{$mode}->();
}else{
	&help;
}


# read old config
sub start {
	my $cl=cmdline();
	my $ocf = read_old_cf($cl->{old});
	#foreach (keys(%$cf)){
	#		print " == $_=>$cf->{$_}\n"
	#};
	open (FH,"$cl->{def}") or die "can't open default config file $cl->{def} :$!\n";

	foreach my $line (<FH>){
		#print "DEF: $line";
		if ($line =~/^\#|^\s+$|^\s+\n/){
			print "$line";
		}else{
			my ($k,$v)=parse($line);
			if (exists $ocf->{$k}){
				print "$k = $ocf->{$k} \n";
			}else{
				print $line;
			}
		}
	}

}

sub cmdline {
	my %arr=();
	foreach my $a (@ARGV){
			#print "$a\n";
		if ($a=~/--(\S+)=(\S+)/){
			$arr{$1}=$2;
			#	print "K=$1,V=$2\n";
		}
	}
	return \%arr;
}

sub read_old_cf {
	my $file =shift;
	open (FH,"$file") or die "can't open old config file $file : $!\n";
	my %cf;
	while (<FH>){
		next if (/^\s*#|^\s*;|^\s*$|^\s*\n/);
		#print ;
		my ($k,$v)=parse($_);
		$cf{$k}=$v;
	}
	return \%cf;
}

sub parse {
	my $l=shift;
	if ($l=~/\s*($token_key)$token_sep($token_val)\s*/){
		my ($k,$v)=($1,$2);
		$v=~s/^\s*//;
		$v=~s/\s*$//;
		#print "*** K=$k ,V=$v\n";
		return $k,$v;
	}
	return "";
}

sub help {
	print <<H;
	$0 start --old=/path/to/extold.cf --def=/path/to/ext.cf >newfile.cf
	$0 help

	Command:
		start start auto update config file.
		help show this message.

	Option:
		--old old config file .
		--def default config file,this is new version config file.

	this is  extmail/extman cf file  auto update program.
	author : fengyong
	date : 2008-03-31
H
	exit;
}
