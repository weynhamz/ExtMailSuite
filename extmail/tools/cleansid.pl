#!/usr/bin/perl -w
# cleansid.pl - a simple script to cleanup session file
#
# Author: Chi-Keung Ho (He zhiqiang) <hzqbbc@hzqbbc.com>
use strict;
my $timeout = 24*3600; # 24 hours
my $curtime = time;
my $dir = $ARGV[0];

die "$0 /path/to/session/dir\n" unless $dir;

opendir DIR, $dir or die "opendir: $!\n";
my @files = grep { /^sid_/ || /^tmp_/ } readdir DIR;
close DIR;

for my $f (@files) {
	next unless ( -e "$dir/$f" );

	my ($p, $key) = ($f =~ m/^(sid|tmp)_(.*)/);
	if ($p eq 'sid') {
		$f = "tmp_$key" if -e "$dir/tmp_$key";
	}
	my $t = (stat "$dir/$f")[9];
	if ($curtime-$t > $timeout) {
		print "$key has been deleted\n";
		cleanup($dir, $key);
	}else {
		print STDERR "$key still alive\n";
	}
}

####################
# subroutine       #
####################

sub filelist {
	my $dir = shift;
	return unless -d $dir;
	opendir DIR, $dir;
	my @files = grep { !/^\.$/ && !/^\.\.$/ } readdir DIR;
	closedir DIR;

	@files;
}

sub cleanup {
	my ($base, $sid) = @_;
	unlink "$base/sid_$sid";
	for my $f (filelist("$base/tmp_$sid")) {
		unlink "$base/tmp_$sid/$f";
	}
	rmdir "$base/tmp_$sid";
}
