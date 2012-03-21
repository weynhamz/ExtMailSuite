#!/usr/bin/perl -w
#
# maildirmake.pl - A small script to make maildir, as an alternative
# 		   to the maildirmake tools of courier-maildrop
#
# Author: He zhiqiang <hzqbbc@hzqbbc.com>
# Copyright (c) 1998-2005 hzqbbc.com
#
# Create Time: Mon Oct 31, 2005
use strict;
my $curdir = '';
umask(0077);

print "$0 /path/to/Maildir/\n" and exit(255) unless (scalar @ARGV >0);

foreach my $dir (split(/\//, $ARGV[0])) {
	$curdir .= "$dir/";
	print "dir=$curdir\n" if ($ARGV[1] && $ARGV[1] eq '--debug');
	mkdir $curdir;
}

mkdir "$ARGV[0]/new";
mkdir "$ARGV[0]/cur";
mkdir "$ARGV[0]/tmp";
