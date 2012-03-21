#!/usr/bin/perl -w

my $dir = $ARGV[0];

if (!-w $dir) {
	print "$0 /path/to/delete\n";
	print "   /path/to/delete must be writable!\n";
	exit 255;
}

my $rc = system("/bin/rm -rf $dir");
if ($rc) {
	die "Bad status code: $rc\n";
}

exit 0;
