#!/usr/bin/perl
# vim: set ci et ts=4 sw=4:
# reportusage.pl: a script to report storage usage of a specific domain or
#                 all domain(s), can send user a email about it.
#
#      Author: He zhiqiang <hzqbbc@hzqbbc.com>
# Last Update: Tue Nov 20 2007 20:19:00
#     Version: 0.3

use vars qw($DIR $base);

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
    unshift @INC, $DIR .'../extmail/libs';

    select((select(STDOUT), $| = 1)[0]);
};

use strict;
use CmdTools;
use POSIX qw(strftime);
use Ext::Utils qw(human_size);

die "Warning: you need to install extmail at the same top direcotry\n".
    "         in order to call extmail modules.\n\n".
    "Usage: $0 [domain|-all] mailbase [recipient]\n" unless $#ARGV == 2;

$base = $ARGV[1];

my $recip = $ARGV[2];
my $domain = "$ARGV[0]";
my $SENDMAIL = '/usr/sbin/sendmail -t -oi';
my $ctx = CmdTools->new( config => $DIR .'/webman.cf', directory => $DIR );
my $mgr = $ctx->ctx; # backend object
my $now = strftime("%Y-%m-%d %H:%M:%S", localtime);

$ctx->_lock;

open (CMD, "|$SENDMAIL") or die "Sendmail fail: $!\n";

print CMD "Content-type: text/html; charset=UTF-8\n";
print CMD "To: $recip\n";
print CMD "Subject: [$now] Disk usage report for $domain domain\n";
print CMD "\n"; # terminator;

print CMD "<style>
    .red td{ background: #ff0000; color: #fff }
    .blue td{ background: blue; color: #fff }
    .grey td{ background: #cccccc; color: #000000 }
    </style>\n";

print CMD "<table border=1 width=100%>\n";
if ($domain eq '-all') {
    # check all
    my $all = $mgr->get_domains_list || [];
    for my $dm (@$all) {
        report_domain($dm->{domain});
    }
} else {
    report_domain($domain);
}

print CMD "</table>\n";
close CMD;

$ctx->_unlock;
exit 0;

sub report_domain {
    my $domain = shift;
    my $ul = $mgr->get_users_list($domain);

    return unless (defined $ul && ref $ul);
    return unless scalar @$ul;

    for my $u (@$ul) {
        my $user = $u->{mail};
        my $quota = $u->{quota};
        my $netdiskquota = $u->{netdiskquota};
        my $maildir = $u->{maildir};

        require Ext::Storage::Maildir;
        Ext::Storage::Maildir->import(qw(get_quota get_curquota));
        $Ext::Storage::Maildir::CFG{path} = "$base/$maildir";

        $ENV{QUOTA} = $quota || '1024000S';

        my ($qst, $ref);
        eval {
            $qst = get_quota();
            $ref = get_curquota();
        };

        if ($@) {
            print CMD "<tr class=grey>
                <td>$user</td>
                <td>QUOTA[0/0]</td>
                <td>USAGE[0/0]</td>
                <td>(0%)</td>
                <td>ERROR: $@</td>
                </tr>\n";
        } else {
            my $unlimit = 0;
            my $qsize = $qst->{size} || 0;
            my $qcount = $qst->{count} || 0;
            my $csize = $ref->{size} || 0;
            my $ccount = $ref->{count} || 0;

            $unlimit = 1 if (!$qsize && !$qcount);
            my $quota_pc = ($qsize ? sprintf("%.2f",($csize/$qsize)) : 0)*100;
            $qsize = human_size($qsize);
            $csize = human_size($csize);
            my $class = ($quota_pc >= 85 ? ( $quota_pc >= 95 ? 'red' : 'blue') : 'normal');
            print CMD "<tr class=$class>
                <td>$user</td>
                <td>QUOTA[$qsize/$qcount]</td>
                <td>USAGE[$csize/$ccount]</td>
                <td>($quota_pc%)</td>
                <td>&nbsp;</td>
                </tr>\n";
        }
    }
}

1;
