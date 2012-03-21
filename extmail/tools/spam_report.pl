#!/usr/bin/perl -w
#
# spam_report.pl - a small script to interface with Dspam or SpamAssassin
#
# Author: He zhiqiang <hzqbbc@hzqbbc.com>
#   Date: Apr 11, 2009, 21:34:11
#
# $Id$
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
}
no strict;
use Getopt::Long;
use Ext::MIME;
use Ext::Storage::Maildir qw(maildir_find);
use POSIX qw(strftime);

# without the following path secification, some time calling command
# will simply exit with 256 or other exit code
$ENV{PATH} = '/bin:/usr/bin:/usr/local/bin:/usr/local/dspam/bin';
my %opt = ();
my $dspam = '/usr/bin/dspamc --client --user extmail';
my $spamassassin ='/usr/bin/sa-learn';

Getopt::Long::Configure('no_ignore_case');
Getopt::Long::GetOptions(\%opt,
	'type|t=s',
	'report_spam',
	'report_nonspam',
	'single|s',
	'multiple|m',
	'msg=s',
);

open (FD, ">> /tmp/spam_report.log");

sub mylog {
	my $msg = shift;
	chomp $msg;
	print FD strftime("%Y-%m-%D %H:%M:%S", localtime);
	print FD " $msg\n";
}

if (not keys %opt) {
    print "Usage: $0 [options]\n";
    print "\t--type=[dspam|spamassassin]          \"Report backend type, dspam or spamassassin\"\n";
    print "\t--[report_spam|report_nonspam]       \"Report as spam or non spam mail\"\n";
    print "\t--[single|multiple]                  \"process one msg or more, multiple mode need\n";
    print "\t                                      feed file path via STDIN, one msg per line\"\n";
    print "\t--msg=/path/to/message               \"absolute path to the message\"\n";
    exit 255;
}

if ($opt{type} eq 'dspam') {
	my @lists;
	my $rc;
	if ($opt{multiple}) {
		while (my $f = <STDIN>) {
			chomp $f;
			push @lists, $f;
		}
	} else {
		push @lists, $opt{msg};
	}
	my $filename = '';
	for my $f (@lists) {
		$f =~ s/\/cur\/([^\/]+)$//;
		$filename = $1;
		$filename = maildir_find($f, $filename);
		next unless $filename;
		$filename = "$f/cur/$filename";

		my $parts = get_msg_info($filename);
		my $hdr = $parts->{head}{hash};
		my $res = hdr_get_hash('X-DSPAM-Result', %$hdr);
		my $sig = hdr_get_hash('X-DSPAM-Signature', %$hdr);
		if ($opt{report_spam}) {
			if ($sig) {
				$rc = system("$dspam --class=spam --source=error --signature=$sig");
			} else {
				$rc = system("cat $filename | $dspam --mode=teft --source=corpus --class=spam --feature=noise");
			}
			mylog("rc=$rc $? sig=$sig report_spam file=$filename");
		}
		if ($opt{report_nonspam}) {
			if ($sig) {
				$rc = system("$dspam --class=innocent --source=error --signature=$sig");
			} else {
				$rc = system("cat $filename | $dspam --mode=teft --source=corpus --class=innocent --feature=noise");
			}
			mylog("rc=$rc $? sig=$sig report_nonspam file=$filename");
		}
	}
} elsif ($opt{type} eq 'spamassassin') {
	my @lists;
	my $rc;

	if ($opt{multiple}) {
		while (my $f = <STDIN>) {
			chomp $f;
			push @lists, $f;
		}
	} else {
		push @lists, $opt{msg};
	}
	my $filename = '';
	for my $f (@lists) {
		$f =~ s/\/cur\/([^\/]+)$//;
		$filename = $1;
		$filename = maildir_find($f, $filename);
		next unless $filename;
		$filename = "$f/cur/$filename";

		if ($opt{report_spam}) {
			$rc = `$spamassassin --spam $filename`;
			mylog("$rc report_spam file=$filename");
		}
		if ($opt{report_nonspam}) {
			$rc = `$spamassassin --ham $filename`;
			mylog("$rc report_nonspam file=$filename");
		}
	}
}

exit (0);
