#!/bin/sh
# vim: set cindent expandtab ts=4 sw=4:
exec ${PERL-perl} -Swx $0 ${1+"$@"}

#!/usr/bin/perl -w
# dispatch.fcgi - a small script to make common cgi into fast
#                 cgi progarme, reduce the forking overhead
#
# Author: He zhiqiang <hzqbbc@hzqbbc.com>
#   Date: 27 Dec 2005
# Update: 29 Aug 2009
#
# Support: nginx 0.x, Apache 2.x or lighttpd 1.3.x/1.4.x
use vars qw(%cache $root %children $FILENAME $prop);
use POSIX qw(setlocale LC_ALL setsid WNOHANG strftime);
use Getopt::Long;
use IO::Socket;
use IO::Select;
use IO::Handle;
my $fcgi_debug = 0;

$prop = {
    select => undef,
    request => undef,
    maxproc => 100,
    minspare => 4,
    logfh => undef,
    lockfh => undef,
    child_busy => 0,
    child_idle => 0,
    child_total => 0,
    check_intvl => 10,
    lastcheck => time(),
};

%cache = ();
$FILENAME = "dispatch.fcgi";

BEGIN {
    $root = $ENV{SCRIPT_FILENAME} || $0;
    if ($root =~/^\./) {
        print "Please run dispatch.fcgi with full path\n";
        print "    example: /path/to/dispatch.fcgi\n";
        exit (255);
    }
    $root =~ s#/*[^/]+$##;
    $root =~ s#/dispatch$/*$##;
    $root =~ m/^(.*)$/s;
    $root = $1; # untaint
    unshift @INC, "$1/dispatch/libs";
    require Ext::FCGI;
}

# initialize locale
setlocale(LC_ALL, "C");

my %opt;
Getopt::Long::Configure('no_ignore_case');
GetOptions(\%opt, 'help|h', 'port|p=i', 'maxserver=i', 'minspare=i',
                  'uid|u=s', 'gid|g=s', 'pid=s', 'request|r=i',
                  'timeout=i', 'host=s', 'server|s','log|l=s', 'debug|d')
    or exit(1);
if($opt{help}) {
    print "usage: /path/to/dispatch.fcgi [*option*]\n\n";
    print "  -h, --help       show this usage\n";
    print "  --host=HOST      FCGI server bind host, eg: localhost\n";
    print "  --port=PORT      FCGI server bind port, eg:8888\n";
    print "  --maxserver=n    maximum number of server to fork\n";
    print "  --minspare=n     minimum number of spare server to fork\n";
    print "  --request=NUMB   number of requests a child to handle\n";
    print "  --timeout=NUMB   how long for request timeout\n";
    print "  --server         run as FCGI server, default off\n";
    print "  -u, --uid        set real and effective user ID\n";
    print "  -g, --gid        set real and effective group ID\n";
    print "  --pid=file       the pid file of parent process\n";
    print "  --log=file       the FCGI server log file\n";
    print "  --debug          enable debug, useful for developer\n";
    exit (1);
}

# initialize properties

if ($opt{debug}) {
    $SIG{__WARN__} = sub { mylog(@_) };
} else {
    $SIG{__WARN__} = 'IGNORE';
}

$opt{'timeout'} ||= 120;

$prop->{maxproc} = $opt{maxserver} || 25;
$prop->{minidle} = $opt{minspare} || 1;

if ($prop->{maxproc} <= $prop->{minidle}) {
    warn "Maxserver is smaller than minspare, abort!\n";
    exit 255;
}

if ($prop->{minidle} <= 0) {
    warn "Minspare server can't be zero, abort!\n";
    exit 255;
}

if ($opt{server}) {
    $SIG{CHLD} = \&reap_child;
    $SIG{TERM} = \&kill_all;
    daemonize();

    my $socket = FCGI::OpenSocket( "$opt{host}:$opt{port}", 512);
    $prop->{request} = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR,
        \%ENV, $socket );
    open ($prop->{lockfh}, "< $0") or die $!;

    set_master();
    if ($opt{uid} && $opt{gid}) {
        set_gid($opt{gid});
        set_uid($opt{uid});
    }

    pipe(_READ,_WRITE);
    _READ->autoflush(1);
    _WRITE->autoflush(1);

    %children = ();
    $prop->{select} = IO::Select->new(\*_READ);

    mylog("Starting child process, host=$opt{host}:$opt{port}");

    run_n_children($prop->{minidle});

    run_parent();

    close $prop->{lockfh};
} else {
    set_idle();
    set_gid($opt{gid});
    set_uid($opt{uid});
    $prop->{request} = Ext::FCGI::Request();
    open ($prop->{lockfh}, "< $0") or die $!;
    main_loop();
    close $prop->{lockfh};
}

exit 0;

sub run_n_children {
    my $n = shift;
    for (1..$n) {
        my $pid = fork;
        if (not defined $pid) {
            warn "Fork error: $!\n";
        } elsif ($pid) {
            mylog("Child $pid forked");
            $children{$pid} = 1;
            $children{$pid}->{status} = 'idle';
            $children{$pid}->{checktime} = time();
            $prop->{child_idle}++;
        } else {
            set_idle(1);
            main_loop();
            exit (0);
        }
    }
    1;
}

sub kill_n_children {
    my $n = shift;
    return unless $n;

    my $time = time();
    for my $pid (keys %children) {
	# mylog("pid=$pid status=$children{$pid}->{status} time=$children{$pid}->{checktime}");
        next unless ($children{$pid}->{status} eq 'idle');
        next if ($time - $children{$pid}->{checktime} < 10);
        $n --;
        $prop->{child_idle} --;
        kill('HUP', $pid) or delete_child($pid);
        mylog("waiting $pid to exit");
        last if $n <=0;
    }
}

sub run_parent {
    local *_READ = _READ;
    while (1) {
        my @fh = $prop->{select}->can_read(2);
        if (! @fh) {
            handle_children();
            next;
        }

        for my $fh (@fh) {
            if ($fh == \*_READ) {
                my $line = <$fh>;
                next if not defined $line;
                chomp $line;
                my ($pid, $sth) = split(/ /, $line);
                if ($sth eq 'busy') {
                    $children{$pid}->{status} = 'busy';
                    $prop->{child_busy} ++;
                    $prop->{child_idle} -- if $prop->{child_idle};
                } elsif ($sth eq 'idle') {
                    $children{$pid}->{status} = 'idle';
                    $children{$pid}->{checktime} = time();
                    $prop->{child_busy} -- if $prop->{child_busy};
                    $prop->{child_idle} ++;
                } elsif ($sth eq 'exit') {
                    $prop->{child_idle} -- if $prop->{child_idle};
                    delete_child($pid);
                    # will let reap child do it
                } else {
                    mylog("garbage sth=$sth");
                }
            }
            # child is talking to me?
        }
        handle_children();
    }
}

sub handle_children {
    my $now = time();
    my $busy = $prop->{child_busy} || 0;
    my $idle = $prop->{child_idle} || 0;
    my $total = scalar keys %children;

    $busy = $prop->{child_busy} = 0 if ($busy <0);
    $idle = $prop->{child_idle} = 0 if ($idle <0);

    # mylog("begin to check children status, busy=$busy, idle=$idle, total=$total");

    if ($now - $prop->{lastcheck} > $prop->{check_intvl}) {
        # check child live and send signal
        for my $pid (keys %children) {
            if (!kill 0, $pid) {
                mylog("Abnormal child $pid status=$children{$pid}->{status}");
                delete_child($pid);
		next unless $children{$pid}->{status};
                $prop->{'child_' . $children{$pid}->{status}} --;
            }
        }
        $busy = $prop->{child_busy} || 0;
        $idle = $prop->{child_idle} || 0;
        $total = scalar keys %children;
    }

    if ($busy + $idle ne $total) {
        mylog("stat not sync to children info, recalculate");
        $prop->{child_idle} = $prop->{child_busy} = 0;
        for my $pid (keys %children) {
	    if (not $children{$pid}->{status}) {
		mylog("$pid has no status");
	    } elsif ($children{$pid}->{status} eq 'busy') {
                $prop->{child_busy} ++;
            } elsif ($children{$pid}->{status} eq 'idle') {
                $prop->{child_idle} ++;
            } else {
                mylog("Unknonw status $children{$pid}->{status}");
            }
        }
        $busy = $prop->{child_busy} || 0;
        $idle = $prop->{child_idle} || 0;
    }

    if ($idle < $prop->{minidle} && $total < $prop->{maxproc}) {
        mylog("minspare=$prop->{minidle}, idle=$idle, busy=$busy");
        run_n_children($prop->{minidle} - $idle);
    }

    # to check whether any child to kill
    if ($idle > $prop->{minidle} && $now - $prop->{lastcheck} > $prop->{check_intvl}) {
        mylog("kill idle=$idle, minspare=$prop->{minidle}");
        mylog("now=$now, lastcheck=$prop->{lastcheck}");
        kill_n_children($idle - $prop->{minidle});
        $prop->{lastcheck} = $now;
    }
}

sub mylog {
    return unless $opt{log};
    return unless $opt{debug};

    my $time = strftime "%Y-%m-%d %H:%M:%S",localtime;
    if (not $prop->{logfh}) {
        open($prop->{logfh}, ">> $opt{log}") or (warn "Log failed: $!\n" and return);
        $prop->{logfh}->autoflush(1);
    }
    my $fh = $prop->{logfh};
    print $fh "$time @_\n";
}

#
# main_loop - the core function for fcgi
sub main_loop {
    my $count = 0;
    my $getSig = 0;
    my $working = 0;

    %children = ();
    delete $prop->{$_} for qw(logfh child_busy child_idle lastcheck);

    $SIG{PIPE} = 'IGNORE';
    $SIG{TERM} = $SIG{__WARN__} = 'DEFAULT';

    my $sigset = POSIX::SigSet->new();
    my $action = POSIX::SigAction->new(
        sub {
            if (not $working) {
                set_exit();
                exit;
            }
            $getSig = 1;
        }, $sigset, &POSIX::SA_NODEFER);
    POSIX::sigaction(&POSIX::SIGHUP, $action);

    while (Ext::FCGI::accept($prop->{request}, $prop->{lockfh})>=0) {
        $working = 1;
        set_busy();
        my $file = request_file();

        print "content-type: text/html\r\n\r\n" if ($fcgi_debug);

        my $last_alarm = alarm($opt{'timeout'});

        # XXX begin eval() and timeout detection
        eval {
            local $SIG{ALRM} = sub { die "Execution timeout\n" };
            if (cached($file)) {
                print "$file cached\n" if ($fcgi_debug);
                compile($cache{$file}->{code});
            } else {
                print "first time run $file\n" if ($fcgi_debug);
                my $code = file2code($file);
                $cache{$file}->{code} = $code;
                $cache{$file}->{mtime} = -M $file;
                compile($code);
            }
            if ($@) {
                print "content-type: text/html\r\n\r\n";
                print "Error: $@\n";
            }
        };
        $working = 0;
        # XXX end of timeout detection
        alarm(0);

        Ext::FCGI::request_cleanup;
        $count++;

        # exit main loop to end child process, free
        # memory and other resources
        last if $count >= ($opt{request}||100);
        last if $getSig;
        set_idle();
    }
    set_exit();
}

# request_file - initialize file path and ENV
sub request_file {
    my $file = $ENV{SCRIPT_FILENAME};

    # we get PATH_INFO ? possible it's Apache
    if (my $path = $ENV{PATH_INFO}) {
        my $sname = $ENV{SCRIPT_NAME};
        $sname =~ s#^/+##; # remove /extmail/cgi => extmail/cgi
        $path =~ s#^/+##; # remove /index.cgi => index.cgi
        $file = "$root/$sname/$path";
    # or it's lighttpd, well we just guess :D
    } else {
        $file = $ENV{SCRIPT_NAME};
        $file =~ s!^/!!;
        $file = "$root/$file";
    }
    $ENV{SCRIPT_FILENAME} = $file;
    $file;
}

sub cached {
    my $file = shift;
    if ($cache{$file}) {
        my $mtime = $cache{$file}->{mtime};
        if (-M $file >= $mtime) {
            return 1;
        }
    } else {
        return 0;
    }
}

sub compile {
    my $code = shift;
    $code =~ m/^(.*)$/s;
    eval $1;
}

sub file2code {
    my $file = shift;
    if (-r $file) {
        open (FD, "< $file") or die "$!\n";
        local $/ = undef;
        my $code = <FD>;
        close FD;
        return $code;
    } else {
        return "print \"content-type: text/html\r\n\r\nRequest file $file not exists\"";
    }
}

#
# Multi process fastcgi server functions

sub set_exit {
    print _WRITE "$$ exit\n";
}

sub set_busy {
    my $no = shift;
    $0 = "$FILENAME (busy)";
    print _WRITE "$$ busy\n" unless $no;
}

sub set_idle {
    my $no = shift;
    $0 = "$FILENAME (idle)";
    print _WRITE "$$ idle\n" unless $no;
}

sub set_master {
    $0 = "$FILENAME (master)";
}

sub delete_child {
    my $pid = shift;
    delete $children{$pid};
}

sub reap_child {
    while( (my $pid = waitpid(-1, WNOHANG)) > 0 ) {
        next unless $pid;
        delete_child($pid);
        mylog("reap child $pid");
    }
}

sub kill_all {
    for my $pid (keys %children) {
        next unless kill 0, $pid; # if it's alive
        kill 9, $pid;
    }
    1 while waitpid(-1, WNOHANG) > 0;
    exit 0;
}

sub daemonize {
    open STDIN, '/dev/null' or die "mailgraph: can't read /dev/null: $!";
    open STDOUT, '>/dev/null'
        or die "Can't write to /dev/null: $!";
    defined(my $pid = fork) or die "Can't fork: $!";
    if($pid) {
        # parent
        my $pidfile = $opt{pid} || "$0.pid";
        open PIDFILE, "> $pidfile" or die "Can't write to $0.pid: $!\n";
        print PIDFILE "$pid\n";
        close(PIDFILE);
        exit;
    }
    # child
    setsid                  or die "Can't start a new session: $!";
    open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";
}

# the following functions derive from suid-perl
sub numberp { defined $_[0] && $_[0] =~ m/^-?\d+$/o; }

sub group2gid {
    my $g = shift;
    return $g if numberp ($g);
    my $gid = getgrnam ($g);
    return $gid if defined $gid && numberp ($gid);
    die "no such group: $g";
}

sub user2uid {
    my $u = shift;
    return $u if numberp ($u);
    my $uid = getpwnam ($u);
    return $uid if defined $uid && numberp ($uid);
    die "no such user: $u";
}

sub set_gid {
    my $sgid = group2gid (shift);
    my $rgid = $( + 0;
    my $egid = $) + 0;

    if ($^O ne 'aix') {
        $( = $sgid;
        die "cannot set rgid $sgid: $!\n" if ($( == $rgid && $rgid != $sgid);
    }
    $) = $sgid;
    die "cannot set egid $sgid: $!\n" if ($) == $egid && $egid != $sgid);
}

sub set_uid {
    my $suid = user2uid (shift);
    my $ruid = $<;
    my $euid = $>;

    if ($^O ne 'aix') {
        $< = $suid;
        die "cannot set ruid $suid: $!\n" if ($< == $ruid && $ruid != $suid);
    }
    $> = $suid;
    die "cannot set euid $suid: $!\n" if ($> == $euid && $euid != $suid);
}

1;
__END__

Update
======

In Aug 2009, I redesign dispatch.fcgi, now it is able to automatically
adjust process forking and limit just like Apache, performance is much
better than before.

Orignal notes
=============

I wrote this programe for extmail project, the mechanism derive
from Embed::Persistent, using eval() and FCGI, it works :-)
