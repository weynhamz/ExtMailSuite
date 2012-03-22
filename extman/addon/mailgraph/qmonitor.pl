#!/usr/bin/perl -w
# vim: set cindent expandtab ts=4 sw=4:

# qmonitor -- an rrdtool enabled postfix queue monitor
# copyright (c) 1998-2006 He zhiqiang <hzqbbc@hzqbbc.com>
# released under the GPL v2

use RRDs;
use strict;
no strict qw(subs refs);
use Getopt::Long;
use POSIX 'setsid';

my $VERSION = "1.3_ext";

my $rrdstep = 60;
my $xpoints = 540;
my $points_per_sample = 3;

my $daemon_logfile = '/var/log/qmonitor.log';
my $daemon_pidfile = '/var/run/qmonitor.pid';
my $daemon_rrd_dir = '/var/lib';
my $rrd_queue = "$daemon_rrd_dir/mailgraph_queue.rrd";

my $this_minute;
my $rrd_inited=0;
my %opt = ();

use vars qw(%q %qm @queue $spool);
@queue = qw(incoming maildrop active deferred hold);
$spool = '/var/spool/postfix';

sub usage
{
    print "usage: qmonitor [*options*]\n\n";
    print "  -h, --help            display this help and exit\n";
    print "  -v, --verbose         be verbose about what you do\n";
    print "  -V, --version         output version information and exit\n";
    print "  -c, --cat             qmonitor only output queue stat and not monitored\n";
    print "  -d, --daemon          start in the background\n";
    print "  --daemon-pid=FILE     write PID to FILE instead of /var/run/qmonitor.pid\n";
    print "  --daemon-rrd=DIR      write RRDs to DIR instead of /var/log\n";
    print "  --daemon-log=FILE     write log to FILE instead of /var/log/qmonitor.log\n";
    print "  --disable-queue-rrd   don't update the queue rrd\n";
    print "  --rrd-name=NAME       use NAME_queue.rrd for the rrd files\n";
    print "  -f, --freq            frequency to check queue (default 0.05 s)\n";

    exit;
}

sub main
{
    Getopt::Long::Configure('no_ignore_case');
    GetOptions(\%opt, 'help|h', 'cat|c', 'version|V',
        'verbose|v+', 'daemon|d!', 'daemon_pid|daemon-pid=s',
        'daemon_rrd|daemon-rrd=s', 'daemon_log|daemon-log=s',
        'disable-queue-rrd','rrd_name|rrd-name=s','freq|f=i',
        ) or exit(1);
    usage if $opt{help};

    if($opt{version}) {
        print "qmonitor $VERSION by hzqbbc\@hzqbbc.com\n";
        exit;
    }

    $daemon_pidfile = $opt{daemon_pid} if defined $opt{daemon_pid};
    $daemon_logfile = $opt{daemon_log} if defined $opt{daemon_log};
    $daemon_rrd_dir = $opt{daemon_rrd} if defined $opt{daemon_rrd};
    $rrd_queue      = $opt{rrd_name}."_queue.rrd" if defined $opt{rrd_name};
    my $sleep       = $opt{freq} || $opt{f} || 0.05;

    if($opt{daemon} or $opt{daemon_rrd}) {
        chdir $daemon_rrd_dir or die "mailgraph: can't chdir to $daemon_rrd_dir: $!";
        -w $daemon_rrd_dir or die "mailgraph: can't write to $daemon_rrd_dir\n";
    }

    daemonize() if $opt{daemon};

    for (@queue) {
        $q{$_} = "$spool/$_"; # initialize
        my @dirs = init_dir($q{$_});
        unshift @dirs, { $q{$_} => (stat $q{$_})[9] };
        $qm{$_} = {
            LIST => \@dirs,
            QSIZE => scalar scan_dir($q{$_}),
        }
    }

    init_rrd(time);

    # the accuracy is 1 second, because the return value of (stat $dir)[9]
    # is epoch second, and can't return the micro second unit :(
    while (1) {
        my $change = 0;
        for (@queue) {
            if (dirchange($_)) {
                print "dir $_ changed!\n" if ($opt{verbose});
                $change = 1;
            }
        }
        if ($change) {
            update(time);
        }
        usleep($sleep);
    }
}

sub dirchange {
    my $type = shift;

    my $arr = $qm{$type}->{LIST};
    for (my $i=0; $i<scalar @$arr;$i++) {
        my $e = $arr->[$i];
        my $dir = (keys %$e)[0];
        my $mtime = $e->{$dir};
        my $now = (stat $dir)[9];
        next if ($now == $mtime);

        $qm{$type}->{QSIZE} = scalar scan_dir($q{$type});
        $qm{$type}->{LIST}->[$i]->{$dir} = $now;
        return 1;
    }
    0;
}

sub usleep {
    my $t = shift;
    select(undef, undef, undef, $t);
}

sub daemonize()
{
    open STDIN, '/dev/null' or die "mailgraph: can't read /dev/null: $!";
    if($opt{verbose}) {
        open STDOUT, ">>$daemon_logfile"
            or die "mailgraph: can't write to $daemon_logfile: $!";
    }
    else {
        open STDOUT, '>/dev/null'
            or die "mailgraph: can't write to /dev/null: $!";
    }
    defined(my $pid = fork) or die "mailgraph: can't fork: $!";
    if($pid) {
        # parent
        open PIDFILE, ">$daemon_pidfile"
            or die "mailgraph: can't write to $daemon_pidfile: $!\n";
        print PIDFILE "$pid\n";
        close(PIDFILE);
        exit;
    }
    # child
    setsid            or die "mailgraph: can't start a new session: $!";
    open STDERR, '>&STDOUT' or die "mailgraph: can't dup stdout: $!";
}

sub init_rrd($)
{
    my $m = shift;
    my $rows = $xpoints/$points_per_sample;
    my $realrows = int($rows*1.1); # ensure that the full range is covered
    my $day_steps = int(3600*24 / ($rrdstep*$rows));
    # use multiples, otherwise rrdtool could choose the wrong RRA
    my $week_steps = $day_steps*7;
    my $month_steps = $week_steps*5;
    my $year_steps = $month_steps*12;

    if(! -f $rrd_queue and ! $opt{'disable-queue-rrd'}) {
        RRDs::create($rrd_queue, '--start', $m, '--step', $rrdstep,
                'DS:incoming:ABSOLUTE:'.($rrdstep*2).':0:U',
                'DS:maildrop:ABSOLUTE:'.($rrdstep*2).':0:U',
                'DS:active:ABSOLUTE:'.($rrdstep*2).':0:U',
                'DS:deferred:ABSOLUTE:'.($rrdstep*2).':0:U',
                'DS:hold:ABSOLUTE:'.($rrdstep*2).':0:U',
                "RRA:AVERAGE:0.5:$day_steps:$realrows",   # day
                "RRA:AVERAGE:0.5:$week_steps:$realrows",  # week
                "RRA:AVERAGE:0.5:$month_steps:$realrows", # month
                "RRA:AVERAGE:0.5:$year_steps:$realrows",  # year
                "RRA:MAX:0.5:$day_steps:$realrows",   # day
                "RRA:MAX:0.5:$week_steps:$realrows",  # week
                "RRA:MAX:0.5:$month_steps:$realrows", # month
                "RRA:MAX:0.5:$year_steps:$realrows",  # year
                );
        my $ERR=RRDs::error;
        print "ERROR: $ERR\n" if $ERR;
        $this_minute = $m;
    }
    elsif(-f $rrd_queue) {
        $this_minute = RRDs::last($rrd_queue) + $rrdstep;
    }

    $rrd_inited=1;
}

sub init_dir {
    my $dir = shift;
    opendir DIR, $dir or die "$!\n";
    my @dirs;
    for (readdir DIR) {
        next if (/^\./);
        next if (!-d "$dir/$_");
        push @dirs, { "$dir/$_" => (stat "$dir/$_")[9] };
        push @dirs, init_dir("$dir/$_");
    }
    closedir DIR;
    @dirs;
}

sub scan_dir {
    my $dir = shift;
    opendir DIR, $dir or die "$!\n";
    my @files ;
    for (readdir DIR) {
        next if (/^\./);
        if (-d "$dir/$_") {
            push @files, scan_dir("$dir/$_");
        } else {
            # my $mode = sprintf("%04o",(stat "$dir/$_")[2] & 07777);
            push @files, $_;
        }
    }
    closedir DIR;
    return @files;
}

# returns 1 if $sum should be updated
sub update($)
{
    my $t = shift;
    my $mt = $t - $t%$rrdstep;
    init_rrd($mt) unless $rrd_inited;
    return 1 if $mt == $this_minute;
    return 0 if $mt < $this_minute;

    my $a = $qm{active}->{QSIZE} ||0;
    my $d = $qm{deferred}->{QSIZE} ||0;
    my $i = $qm{incoming}->{QSIZE} ||0;
    my $m = $qm{maildrop}->{QSIZE} ||0;
    my $h = $qm{hold}->{QSIZE} ||0;

    print "update $this_minute:$i:$m:$a:$d:$h\n" if $opt{verbose};
    RRDs::update $rrd_queue, "$this_minute:$i:$m:$a:$d:$h" unless $opt{'disable-queue-rrd'};
    if ($mt > $this_minute+$rrdstep) {
        for (my $sm=$this_minute+$rrdstep;$sm<$mt;$sm+=$rrdstep) {
            print "update $sm:$i:$m:$a:$d:$h (SKIP)\n" if $opt{verbose};
            RRDs::update $rrd_queue, "$sm:$i:$m:$a:$d:$h" unless $opt{'disable-queue-rrd'};
        }
    }
    $this_minute = $mt;
}

main;
