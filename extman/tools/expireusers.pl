#!/usr/bin/perl
# vim: set ci et ts=4 sw=4:
# expireusers.pl: find expired users and disable them completely
#                 this script is base on chifeng's expireuser.pl
#                 and rewritten completely
#
#      Author: He zhiqiang <hzqbbc@hzqbbc.com>
# Last Update: Sun Mar 23 2008 20:03:30
#     Version: 0.6

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

use POSIX qw(strftime);
use Ext::Mgr;
use CmdTools;
use Ext::DateTime qw(time2epoch epoch2time);

die "Usage: $0 [domain|-all] [recipient]\n" unless $#ARGV == 1;

my $ctx = CmdTools->new( config => $DIR . '/webman.cf', directory => $DIR );
my $c = \%Ext::Cfg;
my $mgr = $ctx->ctx; # backend object

my $SENDMAIL = '/usr/sbin/sendmail -t -oi';
my $backend = $c->{SYS_BACKEND_TYPE};
my $domain = "$ARGV[0]";
my $recip = $ARGV[1];
my $now = strftime ("%Y-%m-%d %H:%M:%S", localtime);

$ctx->_lock;

open(CMD, "|$SENDMAIL") or die "sendmail command error: $!\n";

print CMD "Content-type: text/html; charset=UTF-8\n";
print CMD "To: $recip\n";
print CMD "Subject: [$now] Expiration report for $domain domain\n";
print CMD "\n";

$now = time2epoch ($now);

print CMD "<style>
    .red td{ background: #ff0000; color: #fff }
    .grey td{ background: #cccccc; }
    </style>\n";

print CMD "<table border=1 width=100%>\n";

if ($domain eq '-all') {
    # check all
    my $all = $mgr->get_domains_list || [];
    for my $dm (@$all) {
        check_domain($dm->{domain});
    }
} else {
    check_domain($domain);
}

print CMD "</table>\n";
close CMD;

# terminate normally
$ctx->_unlock;
exit (0);

sub check_domain {
    my $domain = shift;
    my $di = $mgr->get_domain_info($domain);
    my $expire;
    my $domain_expired = 0;

    eval {
        if ($di->{expire} ne '0000-00-00') {
            if (is_new_dt($di->{expire})) {
                $di->{expire} = $di->{expire}. " 00:00:00";
            }
            $expire = time2epoch($di->{expire});
        } else {
            # domain expire is unlimit
            $expire = '9999999999';
        }
    };

    if ($@) {
        print CMD "<tr class=red><td>$domain Bad expire value!</td></tr>\n";
        return;
    }

    $domain_expired = 1 if ($expire - $now <=0);

    # now we can check user's expire
    my $ul = $mgr->get_users_list($domain);
    for my $u (@$ul) {
        my $user = $u->{mail};
        my $expire;
        my $user_expired = 0;
        my $dt = $u->{expire};

        if ($dt eq '0000-00-00') {
            print CMD "<tr class=normal>
            <td>$user</td>
            <td>alive</td>
            <td>-</td>\n";
            print CMD "</tr>\n";
            next;
        }

        if (is_new_dt($dt)) {
            $dt = $dt . " 00:00:00";
        }
        eval { $expire = time2epoch($dt) };
        if ($@) {
            print CMD "<tr class=red>
                <td>$user</td>
                <td>fail</td.
                <td>ERROR: $@</td>
                </tr>";
            next;
        }
        $user_expired = 1 if ($expire - $now <=0);
        $user_expired = 1 if ($domain_expired);

        if ($u->{active} && $user_expired) {
            print CMD "<tr class=red>
                <td>$user</td>
                <td>expired</td>
                <td>updated</td>";
            disable_user($u); # send ref
        } elsif ($user_expired) {
            print CMD "<tr class=grey>
                <td>$user</td>
                <td>expired</td>
                <td>-</td>";
        } else {
            print CMD "<tr class=normal>
                <td>$user</td>
                <td>alive</td>
                <td>-</td>";
        }
        print CMD "</tr>\n";
    }
}

sub disable_user {
    my $r = shift;
    my $user = $r->{mail};

    $rc = $mgr->modify_user(
        user => $user,
        cn => $r->{cn},
        uidnumber => $r->{uidnumber},
        gidnumber => $r->{gidnumber},
        expire => $r->{expire},
        quota => $r->{quota},
        netdiskquota => $r->{netdiskquota},
        active => 0,
        disablesmtpd => $r->{disablesmtpd},
        disablesmtp => $r->{disablesmtp},
        disablewebmail => $r->{disablewebmail},
        disablenetdisk => $r->{disablenetdisk},
        disablepop3 => $r->{disablepop3},
        disableimap => $r->{disableimap},
    );
    if ($rc) {
        print CMD "modify $user fail: $rc\n";
    }
}

sub is_new_dt {
    my $dt = shift;
    if ($dt =~ /^\d{4}-\d{2}-\d{2}$/) {
        return 1;
    }
    0;
}
