# vim: set cindent expandtab ts=4 sw=4:
#
# Copyright (c) 1998-2005 Chi-Keung Ho. All rights reserved.
#
# This programe is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# Extmail - a high-performance webmail to maildir
# $Id$
package Ext::POP3;
use strict;
use Mail::POP3Client;
use Ext::Storage::Maildir;
use MIME::Base64;
use Fcntl qw(:flock);
use Ext::Utils; # import untaint()

use constant PROC_TIMEOUT => 1*60;  # default processing timeout per account
use constant CHECK_INTVAL => 15*60; # default pop3 checking interval
use constant SOCK_TIMEOUT => 1*15;  # default socket operation timeout
use constant DEAD_TIMEOUT => 30*60; # when will we remove a dead lock file?
use constant MAX_FILES    => 30;    # max files per receive process

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(parse_pop3config);

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;

    $self->{uidlcf} = './pop3uidl.cf';
    $self; # return the obj Ext::POP3
}

sub error {
    my $self = shift;
    my $err = $_[0];
    if ($err) {
        $self->{err} .= "$err\n";
    }
    return $self->{err};
    0;
}

#
# XXX opt defination
#
# user
# passwd
# host
# port
# timeout
# check_intval
# max_files
# delete
sub init {
    my $self = shift;
    my %opt = @_;
    $opt{timeout} = $opt{timeout} || SOCK_TIMEOUT;
    $opt{max_files} = $opt{max_files} || MAX_FILES;

    # XXX save opt
    $self->{opt} = \%opt;

    if (!$opt{user} || !$opt{passwd} || !$opt{host}) {
        $self->error('Options not completed');
        return;
    }

    my $pop = new Mail::POP3Client(
        USER     => $opt{user},
        PASSWORD => $opt{passwd},
        HOST     => untaint($opt{host}),
        PORT     => untaint($opt{port}) || '110',
        DEBUG    => 0,
        TIMEOUT  => $opt{timeout},
        STRIPCR  => 1, # must strip, our lib can't handle crlf
        AUTH_MODE => 'PASS',
    );

    $self->{pop} = $pop;
}

# do we need to receive pop3 or not?
# rc value: 0 -> can not, 1 -> can
#
# Newly design, for multiple pop3 accounts, we need to build
# a new mechanism, it can identify different pop session
# the can_receive() will always return 1 we calling it within
# the same object
sub can_receive {
    my $self = shift;
    my $config = $self->{uidlcf};
    my $lockfile = "$config.lock";
    my $uncheck = 0;
    my $timeout = $self->{opt}->{check_intval} || CHECK_INTVAL;

    # reduce redundent checking
    return 1 if ($self->{can_receive});

    # check dead locking to pop3uidl.cf.lock
    if (-r "$lockfile") {
        open (my $fh, "<", $lockfile) or
            die "Error open $lockfile, $!\n";
        if ($self->haslock($fh)) {
            # somebody else locking it, we abort ?
            return 0;
        } else {
            unlink $lockfile;
            $uncheck = 1;
        }
    } else {
        if (-r $config) {
            my $mtime = (stat $config)[9];
            $uncheck = 1 if (time - $mtime >= $timeout);
        } else {
            open (FD, "> $config"); # ignore error?
            flock (FD, LOCK_EX);
            print FD "";
            flock (FD, LOCK_UN);
            close FD;
            $uncheck = 1;
        }
    }

    if ($uncheck) {
        # save pid
        open (my $fh, "> $lockfile") or die "$!\n";
        select((select($fh), $| = 1)[0]); # unbuffer
        flock ($fh, LOCK_EX);
        print $fh "$$";
        $self->lock($fh);
        $self->{lockfh} = $fh;
        $self->{can_receive} = 1;
    }

    $uncheck;
}

sub lock {
    my $self = shift;
    my $fh = $_[0] || $self->{lockfh};
    flock ($fh, LOCK_EX|LOCK_NB);
}

sub unlock {
    my $self = shift;
    my $fh = $_[0] || $self->{lockfh};
    flock ($fh, LOCK_UN);
    1;
}

sub haslock {
    my $self = shift;
    my $fh = $_[0] || $self->{lockfh};
    if ($self->lock($fh)) {
        $self->{_flock} = '1';
        $self->unlock($fh);
        return 0; # means no lock
    }
    1;
}

sub listsize {
    my $ref = shift->{pop}->ListArray;
    my @mid = (undef); # XXX redundent member

    for (split(/\n/, $ref)) {
        my ($id, $size) = (/^(\d+)\s*(\d+)\s*/);
        push @mid, $size;
    }
    \@mid;
}

sub listuidl {
    my $ref = shift->{pop}->Uidl;
    my @uidl = (undef); # redundent member

    return $ref if ($ref && ref $ref eq 'ARRAY');

    for (split(/\n/, $ref)) {
        my ($id, $uidl) = (/^(\d+)\s*(.*)\s*/);
        push @uidl, $uidl;
    }
    \@uidl;
}

sub _combine {
    my ($uidl, $size) = @_;
    my @arr = (undef); # redundent member
    return unless ($uidl && $size);

    for (my $i=1; $i< scalar @$uidl; $i++) {
        push @arr, {
            id => $i,
            uidl => $uidl->[$i],
            size => $size->[$i],
        };
    }
    \@arr;
}

# receive - retrieve mails from remote pop3 server
sub receive {
    my $self = shift;
    my $timeout = PROC_TIMEOUT; # hard code here! XXX FIXME
    my %opt = %{$self->{opt}};

    eval {
        # install ALRM signal handler
        local $SIG{ALRM} = sub {
            # the object timeout, let everybody know it!
            $self->{timeout} =1;
            die "Time out\n"
        };

        alarm ($timeout);
        $self->pop2maildir;
        alarm (0);
    };

    if ($@ =~/Time out/) {
        $self->error('POP3 operation timeout!');
    }

    # error message handler, know err from Mail::POP3Client are:
    # ERR= POP3 command LIST may be given only in the 'TRANSACTION'
    #      state (current state is 'AUTHORIZATION').
    # ERR= could not connect xxxxxxx
    $_ = $self->{pop}->Message;
    return $self->error unless ($_);
    if (/AUTHORIZATION/) {
        $self->error("$opt{user} authentication fail");
    }
    if (/^could not connect [^\:]+: (.*)/) {
        my $res = $1;
        if ($res =~ /in progress/) {
            $res = 'time out';
        }
        $self->error("$opt{host} connection fail: $res\n");
    }
    $self->error;
}

sub pop2maildir {
    my $self = shift;
    my $max = $self->{opt}->{max_files};
    my $pop = $self->{pop};
    my $user = lc $pop->User; # get username

    # Stage 1 - combine uidl with size and id, parse uidlcf
    my $info = _combine($self->listuidl, $self->listsize);
    my $uidl = _parse($self->{uidlcf});
    my $counter = 0;

    open (UIDL, ">> $self->{uidlcf}") or die "$!\n";
    flock (UIDL, LOCK_EX);

    for (my $i=1; $i < scalar @$info; $i++) {
        last if ($counter >= $max);
        last if ($self->{timeout});

        my $u = $info->[$i]->{uidl};
        next if ($uidl->{"$user/$u"});

        my $tmpdraft = _gen_maildir_filename();
        open (my $FD, "> ./tmp/$tmpdraft");
        my $ok = $pop->RetrieveToFile($FD, $i);
        close ($FD);

        if ($ok) {
            my $newdraft = _gen_maildir_filename("./tmp/$tmpdraft", 1);
            my $size = (stat "./tmp/$tmpdraft")[7];
            my $distname=$newdraft.",S=$size"; # marked as new

            # Not overquota and file is completed
            if ($size > 0 && is_overquota($size, 1) < 2) {
                rename "./tmp/$tmpdraft", "./new/$distname";
                print UIDL "$user/$u\n"; # save uild to uidlcf
                update_quota_s({a => "$size 1"});

                if (!$self->{opt}->{backup}) {
                    $pop->Delete($i); # mark the message delete
                }
                $counter ++;
            } else {
                $self->error("The uidl='$u' message retrieve broekn, $!\n");
                unlink "./tmp/$tmpdraft";
            }
        } else {
            unlink "./tmp/$tmpdraft"; # cleanup
            $self->error($pop->Message);
        }
    }
    flock (UIDL, LOCK_UN);

    # update the modification timestamp
    my $time = time;
    utime $time, $time, $self->{uidlcf};
    1;
}

sub _parse {
    my $config = $_[0]; # must feed a file name
    my %hash;

    open (FD, "< $config") or return undef; # ignore error
    while (<FD>) {
        chomp;
        $hash{$_} = 1;
    }
    close FD;
    \%hash;
}

# this function tell Ext::POP3 we hit the end
# of object, time to destroy anything
sub finish {
    my $self = shift;
    delete $self->{finish};
    delete $self->{_flock};
    if ($self->{can_receive}) {
        $self->unlock($self->{lockfh});
        unlink './pop3uidl.cf.lock';
    }
    delete $self->{lockfh};
    delete $self->{can_receive};
}

sub close {
    my $self = shift;
    my $pop = $self->{pop};

    if ($pop) {
        $pop->Close;
        $self->{timeout} = 0;
        $self->{err} = undef;
    }
}

sub _gen_maildir_filename {
    # according to http://cr.yp.to/proto/maildir.html and compatible
    # with sqwebmail or maildrop etc, include postfix
    my ($oldname, $flag) = @_;
    if($oldname && $flag) { # get the standard maildir name
        return gen_std_maildir($oldname);
    }elsif($oldname) { # only strip status information
        $oldname=~ s#([^,]+),S=.*#$1#;
        return $oldname;
    }else { # return the initial filename
        return sprintf "%s_P%s_%s", time, $$, 'extmail';
    }
}

sub _gen_name_tpart {
    eval {
        require 'sys/syscall.ph';
    };

    if($@) { return time; }
    return time unless (defined &SYS_gettimeofday);

    my $start = pack('LL', ());
    syscall(&SYS_gettimeofday, $start, 0) != -1
        or die "gettimeofday: $!";
    my @start = unpack('LL', $start);
    $start[0].'.M'.$start[1];
}

# parse pop3config.cf, storage struct
# An entry per line
#
# uid passwd host port option \n(newline)
#
# option => backup=on|off, color=#abcdef, active=on|off
# passwd => must base64 encoded (some password is space?)
sub parse_pop3config {
    my $config = './pop3config.cf';
    my @accounts;

    if (-r $config) {
        open (FD, "< $config") or die "$!\n";
        while (my $buf = <FD>) {
            chomp;
            my @arr = split(/\s+/, $buf);
            my $hash = {
                uid => $arr[0],
                passwd => decode_base64($arr[1]),
                host => $arr[2],
                port => $arr[3],
            };

            for (split(/,/, $arr[4])) {
                /^([^=]+)=(.*)/;
                $hash->{$1} = $2;
            }
            push @accounts, $hash;
        }
        return \@accounts;
    }
    [];
}

sub DESTROY {
    my $self = shift;
    $self->finish;
}

1;
