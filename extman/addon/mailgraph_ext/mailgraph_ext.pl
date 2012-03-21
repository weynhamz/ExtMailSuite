#!/usr/bin/perl -w

# mailgraph -- an rrdtool frontend for mail statistics
# copyright (c) 2000-2005 David Schweikert <dws@ee.ethz.ch>
# released under the GNU General Public License

# mailgraph_ext -- an enhanced version of mailgraph
# copyright (c) 1998-2006 He zhiqiang <hzqbbc@hzqbbc.com>
# released under the GPL v2

######## Parse::Syslog 1.04 (automatically embedded) ########
package Parse::Syslog;
use Carp;
use Symbol;
use Time::Local;
use strict;

use vars qw($VERSION);
my %months_map = (
    'Jan' => 0, 'Feb' => 1, 'Mar' => 2,
    'Apr' => 3, 'May' => 4, 'Jun' => 5,
    'Jul' => 6, 'Aug' => 7, 'Sep' => 8,
    'Oct' => 9, 'Nov' =>10, 'Dec' =>11,
    'jan' => 0, 'feb' => 1, 'mar' => 2,
    'apr' => 3, 'may' => 4, 'jun' => 5,
    'jul' => 6, 'aug' => 7, 'sep' => 8,
    'oct' => 9, 'nov' =>10, 'dec' =>11,
);
# year-increment algorithm: if in january, if december is seen, decrement year
my $enable_year_decrement = 1;
# fast timelocal, cache minute's timestamp
# don't cache more than minute because of daylight saving time switch
my @str2time_last_minute;
my $str2time_last_minute_timestamp;
# 0: sec, 1: min, 2: h, 3: day, 4: month, 5: year
sub str2time($$$$$$$)
{
    my $GMT = pop @_;
    if(defined $str2time_last_minute[4] and
        $str2time_last_minute[0] == $_[1] and
        $str2time_last_minute[1] == $_[2] and
        $str2time_last_minute[2] == $_[3] and
        $str2time_last_minute[3] == $_[4] and
        $str2time_last_minute[4] == $_[5])
    {
        return $str2time_last_minute_timestamp + $_[0];
    }
    my $time;
    if($GMT) {
        $time = timegm(@_);
    }
    else {
        $time = timelocal(@_);
    }
    @str2time_last_minute = @_[1..5];
    $str2time_last_minute_timestamp = $time-$_[0];
    return $time;
}
sub _use_locale($)
{
    use POSIX qw(locale_h strftime);
    my $old_locale = setlocale(LC_TIME);
    for my $locale (@_) {
        croak "new(): wrong 'locale' value: '$locale'" unless setlocale(LC_TIME, $locale);
        for my $month (0..11) {
            $months_map{strftime("%b", 0, 0, 0, 1, $month, 96)} = $month;
        }
    }
    setlocale(LC_TIME, $old_locale);
}
sub new($$;%)
{
    my ($class, $file, %data) = @_;
    croak "new() requires one argument: file" unless defined $file;
    %data = () unless %data;
    if(not defined $data{year}) {
        $data{year} = (localtime(time))[5]+1900;
    }
    $data{type} = 'syslog' unless defined $data{type};
    $data{_repeat}=0;
    if(ref $file eq 'File::Tail') {
        $data{filetail} = 1;
        $data{file} = $file;
    }
    else {
        $data{file}=gensym;
        open($data{file}, "<$file") or croak "can't open $file: $!";
    }
    if(defined $data{locale}) {
        if(ref $data{locale} eq 'ARRAY') {
            _use_locale @{$data{locale}};
        }
        elsif(ref $data{locale} eq '') {
            _use_locale $data{locale};
        }
        else {
            croak "'locale' parameter must be scalar or array of scalars";
        }
    }
    return bless \%data, $class;
}
sub _year_increment($$)
{
    my ($self, $mon) = @_;
    # year change
    if($mon==0) {
        $self->{year}++ if defined $self->{_last_mon} and $self->{_last_mon} == 11;
        $enable_year_decrement = 1;
    }
    elsif($mon == 11) {
        if($enable_year_decrement) {
            $self->{year}-- if defined $self->{_last_mon} and $self->{_last_mon} != 11;
        }
    }
    else {
        $enable_year_decrement = 0;
    }
    $self->{_last_mon} = $mon;
}
sub _next_line($)
{
    my $self = shift;
    my $f = $self->{file};
    if(defined $self->{filetail}) {
        return $f->read;
    }
    else {
        return <$f>;
    }
}
sub _next_syslog($)
{
    my ($self) = @_;
    while($self->{_repeat}>0) {
        $self->{_repeat}--;
        return $self->{_repeat_data};
    }
    line: while(my $str = $self->_next_line()) {
        # date, time and host
        $str =~ /^
            (\S{3})\s+(\d+)   # date  -- 1, 2
            \s
            (\d+):(\d+):(\d+) # time  -- 3, 4, 5
            (?:\s<\w+\.\w+>)? # FreeBSD's verbose-mode
            \s
            ([-\w\.\@:]+)     # host  -- 6
            \s+
            (.*)              # text  -- 7
            $/x or do
        {
            warn "WARNING: line not in syslog format: $str";
            next line;
        };
        my $mon = $months_map{$1};
        defined $mon or croak "unknown month $1\n";
        $self->_year_increment($mon);
        # convert to unix time
        my $time = str2time($5,$4,$3,$2,$mon,$self->{year}-1900,$self->{GMT});
        if(not $self->{allow_future}) {
            # accept maximum one day in the present future
            if($time - time > 86400) {
                warn "WARNING: ignoring future date in syslog line: $str";
                next line;
            }
        }
        my ($host, $text) = ($6, $7);
        # last message repeated ... times
        if($text =~ /^(?:last message repeated|above message repeats) (\d+) time/) {
            next line if defined $self->{repeat} and not $self->{repeat};
            next line if not defined $self->{_last_data}{$host};
            $1 > 0 or do {
                warn "WARNING: last message repeated 0 or less times??\n";
                next line;
            };
            $self->{_repeat}=$1-1;
            $self->{_repeat_data}=$self->{_last_data}{$host};
            return $self->{_last_data}{$host};
        }
        # marks
        next if $text eq '-- MARK --';
        # some systems send over the network their
        # hostname prefixed to the text. strip that.
        $text =~ s/^$host\s+//;
        # discard ':' in HP-UX 'su' entries like this:
        # Apr 24 19:09:40 remedy : su : + tty?? root-oracle
        $text =~ s/^:\s+//;
        $text =~ /^
            ([^:]+?)        # program   -- 1
            (?:\[(\d+)\])?  # PID       -- 2
            :\s+
            (?:\[ID\ (\d+)\ ([a-z0-9]+)\.([a-z]+)\]\ )?   # Solaris 8 "message id" -- 3, 4, 5
            (.*)            # text      -- 6
            $/x or do
        {
            warn "WARNING: line not in syslog format: $str";
            next line;
        };
        if($self->{arrayref}) {
            $self->{_last_data}{$host} = [
                $time,  # 0: timestamp
                $host,  # 1: host
                $1,     # 2: program
                $2,     # 3: pid
                $6,     # 4: text
                ];
        }
        else {
            $self->{_last_data}{$host} = {
                timestamp => $time,
                host      => $host,
                program   => $1,
                pid       => $2,
                msgid     => $3,
                facility  => $4,
                level     => $5,
                text      => $6,
            };
        }
        return $self->{_last_data}{$host};
    }
    return undef;
}
sub _next_metalog($)
{
    my ($self) = @_;
    line: while(my $str = $self->_next_line()) {
	# date, time and host
	$str =~ /^
            (\S{3})\s+(\d+)   # date  -- 1, 2
            \s
            (\d+):(\d+):(\d+) # time  -- 3, 4, 5
	                      # host is not logged
            \s+
            (.*)              # text  -- 6
            $/x or do
        {
            warn "WARNING: line not in metalog format: $str";
            next line;
        };
        my $mon = $months_map{$1};
        defined $mon or croak "unknown month $1\n";
        $self->_year_increment($mon);
        # convert to unix time
        my $time = str2time($5,$4,$3,$2,$mon,$self->{year}-1900,$self->{GMT});
	my $text = $6;
        $text =~ /^
            \[(.*?)\]        # program   -- 1
           	             # no PID
	    \s+
            (.*)             # text      -- 2
            $/x or do
        {
	    warn "WARNING: text line not in metalog format: $text ($str)";
            next line;
        };
        if($self->{arrayref}) {
            return [
                $time,  # 0: timestamp
                'localhost',  # 1: host
                $1,     # 2: program
                undef,  # 3: (no) pid
                $2,     # 4: text
                ];
        }
        else {
            return {
                timestamp => $time,
                host      => 'localhost',
                program   => $1,
                text      => $2,
            };
        }
    }
    return undef;
}
sub next($)
{
    my ($self) = @_;
    if($self->{type} eq 'syslog') {
        return $self->_next_syslog();
    }
    elsif($self->{type} eq 'metalog') {
        return $self->_next_metalog();
    }
    croak "Internal error: unknown type: $self->{type}";
}

#####################################################################
#####################################################################
#####################################################################

use RRDs;

use strict;

use File::Tail;
use Getopt::Long;
use POSIX 'setsid';

my $VERSION = "1.3_ext";

# config
my $rrdstep = 60;
my $xpoints = 540;
my $points_per_sample = 3;

my $daemon_logfile = '/var/log/mailgraph.log';
my $daemon_pidfile = '/var/run/mailgraph.pid';
my $daemon_rrd_dir = '/var/log';

# global variables
my $logfile;
my $rrd = "mailgraph.rrd";
my $rrd_virus = "mailgraph_virus.rrd";
my $rrd_bytes = "mailgraph_bytes.rrd";
my $rrd_courier = "mailgraph_courier.rrd";
my $rrd_webmail = "mailgraph_webmail.rrd";

my $year;
my $this_minute;
my %sum = (
	sent => 0,
	received => 0,
	bounced => 0,
	rejected => 0,
	virus => 0,
	spam => 0,
	pop3d=> 0,
	pop3d_ssl => 0,
	imapd => 0,
	imapd_ssl => 0,
	wmstat0 => 0,	# loginok
	wmstat1 => 0,   # loginfail
	wmstat2 => 0,   # disabled
	wmstat3 => 0,   # deactive
);

my $rrd_inited=0;

my %opt = ();

# prototypes
sub daemonize();
sub process_line($);
sub event_sent($);
sub event_received($);
sub event_bounced($);
sub event_rejected($);
sub event_virus($);
sub event_spam($);
sub init_rrd($);
sub update($);

use vars qw(%queue_active %queue_deferred);
use vars qw(%bytes_in %bytes_out);

# XXX DEBUG only
$SIG{INT} =
sub {
	open (FD, "> active.log") or die $!;
	foreach my $m (keys %queue_active) {
		print FD "active=$m '$queue_active{$m}'\n";
	}
	close FD;

	open (FD, "> deferred.log") or die $!;
	foreach my $m (keys %queue_deferred) {
		print FD "deferred=$m\n";
	}
	close FD;
	die @_;
};

sub usage
{
	print "usage: mailgraph_ext [*options*]\n\n";
	print "  -h, --help            display this help and exit\n";
	print "  -v, --verbose         be verbose about what you do\n";
	print "  -V, --version         output version information and exit\n";
	print "  -c, --cat             causes the logfile to be only read and not monitored\n";
	print "  -l, --logfile f       monitor logfile f instead of /var/log/syslog\n";
	print "  -t, --logtype t       set logfile's type (default: syslog)\n";
	print "  -y, --year            starting year of the log file (default: current year)\n";
	print "      --host=HOST       use only entries for HOST (regexp) in syslog\n";
	print "  -d, --daemon          start in the background\n";
	print "  --daemon-pid=FILE     write PID to FILE instead of /var/run/mailgraph.pid\n";
	print "  --daemon-rrd=DIR      write RRDs to DIR instead of /var/log\n";
	print "  --daemon-log=FILE     write verbose-log to FILE instead of /var/log/mailgraph.log\n";
	print "  --ignore-localhost    ignore mail to/from localhost (used for virus scanner)\n";
	print "  --ignore-host=HOST    ignore mail to/from HOST (used for virus scanner)\n";
	print "  --disable-mail-rrd    don't update the mail rrd\n";
	print "  --disable-virus-rrd   don't update the virus rrd\n";
	print "  --disable-courier-rrd don't update the courier rrd\n";
	print "  --disable-bytes-rrd   don't update the bytes rrd\n";
	print "  --disable-webmail-rrd don't update the webmail rrd\n";
	print "  --rrd-name=NAME       use NAME.rrd and NAME_virus.rrd for the rrd files\n";
	print "  --rbl-is-spam         count rbl rejects as spam\n";
	print "  --virbl-is-virus      count virbl rejects as viruses\n";

	exit;
}

sub main
{
	Getopt::Long::Configure('no_ignore_case');
	GetOptions(\%opt, 'help|h', 'cat|c', 'logfile|l=s', 'logtype|t=s', 'version|V',
		'year|y=i', 'host=s', 'verbose|v+', 'daemon|d!',
		'daemon_pid|daemon-pid=s', 'daemon_rrd|daemon-rrd=s',
		'daemon_log|daemon-log=s', 'ignore-localhost!', 'ignore-host=s',
		'disable-mail-rrd', 'disable-virus-rrd','disable-courier-rrd',
		'disable-bytes-rrd', 'disable-webmail-rrd', 'rrd_name|rrd-name=s',
		'rbl-is-spam', 'virbl-is-virus'
		) or exit(1);
	usage if $opt{help};

	if($opt{version}) {
		print "mailgraph $VERSION by dws\@ee.ethz.ch and hzqbbc\@hzqbbc.com \n";
		exit;
	}

	$daemon_pidfile = $opt{daemon_pid} if defined $opt{daemon_pid};
	$daemon_logfile = $opt{daemon_log} if defined $opt{daemon_log};
	$daemon_rrd_dir = $opt{daemon_rrd} if defined $opt{daemon_rrd};
	$rrd		= $opt{rrd_name}.".rrd" if defined $opt{rrd_name};
	$rrd_virus	= $opt{rrd_name}."_virus.rrd" if defined $opt{rrd_name};
	$rrd_courier	= $opt{rrd_name}."_courier.rrd" if defined $opt{rrd_name};
	$rrd_webmail	= $opt{rrd_name}."_webmail.rrd" if defined $opt{rrd_name};
	$rrd_bytes	= $opt{rrd_name}."_bytes.rrd" if defined $opt{rrd_name};

	if($opt{daemon} or $opt{daemon_rrd}) {
		chdir $daemon_rrd_dir or die "mailgraph: can't chdir to $daemon_rrd_dir: $!";
		-w $daemon_rrd_dir or die "mailgraph: can't write to $daemon_rrd_dir\n";
	}

	daemonize if $opt{daemon};

	my $logfile = defined $opt{logfile} ? $opt{logfile} : '/var/log/syslog';
	my $file;
	if($opt{cat}) {
		$file = $logfile;
	}
	else {
		$file = File::Tail->new(name=>$logfile, tail=>-1);
	}
	my $parser = new Parse::Syslog($file, year => $opt{year}, arrayref => 1,
		type => defined $opt{logtype} ? $opt{logtype} : 'syslog');

	if(not defined $opt{host}) {
		while(my $sl = $parser->next) {
			process_line($sl);
		}
	}
	else {
		my $host = qr/^$opt{host}$/i;
		while(my $sl = $parser->next) {
			process_line($sl) if $sl->[1] =~ $host;
		}
	}
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
	setsid			or die "mailgraph: can't start a new session: $!";
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

	# mail rrd
	if(! -f $rrd and ! $opt{'disable-mail-rrd'}) {
		RRDs::create($rrd, '--start', $m, '--step', $rrdstep,
				'DS:sent:ABSOLUTE:'.($rrdstep*2).':0:U',
				'DS:recv:ABSOLUTE:'.($rrdstep*2).':0:U',
				'DS:bounced:ABSOLUTE:'.($rrdstep*2).':0:U',
				'DS:rejected:ABSOLUTE:'.($rrdstep*2).':0:U',
				"RRA:AVERAGE:0.5:$day_steps:$realrows",   # day
				"RRA:AVERAGE:0.5:$week_steps:$realrows",  # week
				"RRA:AVERAGE:0.5:$month_steps:$realrows", # month
				"RRA:AVERAGE:0.5:$year_steps:$realrows",  # year
				"RRA:MAX:0.5:$day_steps:$realrows",   # day
				"RRA:MAX:0.5:$week_steps:$realrows",  # week
				"RRA:MAX:0.5:$month_steps:$realrows", # month
				"RRA:MAX:0.5:$year_steps:$realrows",  # year
				);
		$this_minute = $m;
	}
	elsif(-f $rrd) {
		$this_minute = RRDs::last($rrd) + $rrdstep;
	}

	# virus rrd
	if(! -f $rrd_virus and ! $opt{'disable-virus-rrd'}) {
		RRDs::create($rrd_virus, '--start', $m, '--step', $rrdstep,
				'DS:virus:ABSOLUTE:'.($rrdstep*2).':0:U',
				'DS:spam:ABSOLUTE:'.($rrdstep*2).':0:U',
				"RRA:AVERAGE:0.5:$day_steps:$realrows",   # day
				"RRA:AVERAGE:0.5:$week_steps:$realrows",  # week
				"RRA:AVERAGE:0.5:$month_steps:$realrows", # month
				"RRA:AVERAGE:0.5:$year_steps:$realrows",  # year
				"RRA:MAX:0.5:$day_steps:$realrows",   # day
				"RRA:MAX:0.5:$week_steps:$realrows",  # week
				"RRA:MAX:0.5:$month_steps:$realrows", # month
				"RRA:MAX:0.5:$year_steps:$realrows",  # year
				);
		$this_minute = $m unless $this_minute;
	}
	elsif(-f $rrd_virus and ! defined $rrd_virus) {
		$this_minute = RRDs::last($rrd_virus) + $rrdstep;
	}

	if(! -f $rrd_courier and !$opt{'disable-courier-rrd'}) {
		RRDs::create($rrd_courier, '--start', $m, '--step', $rrdstep,
				'DS:imapd_ssl_login:ABSOLUTE:'.($rrdstep*2).':0:U',
				'DS:imapd_login:ABSOLUTE:'.($rrdstep*2).':0:U',
				'DS:pop3d_ssl_login:ABSOLUTE:'.($rrdstep*2).':0:U',
				'DS:pop3d_login:ABSOLUTE:'.($rrdstep*2).':0:U',
				"RRA:AVERAGE:0.5:$day_steps:$realrows",   # day
				"RRA:AVERAGE:0.5:$week_steps:$realrows",  # week
				"RRA:AVERAGE:0.5:$month_steps:$realrows", # month
				"RRA:AVERAGE:0.5:$year_steps:$realrows",  # year
				"RRA:MAX:0.5:$day_steps:$realrows",   # day
				"RRA:MAX:0.5:$week_steps:$realrows",  # week
				"RRA:MAX:0.5:$month_steps:$realrows", # month
				"RRA:MAX:0.5:$year_steps:$realrows",  # year
				);
		$this_minute = $m unless $this_minute;
	}
	elsif(-f $rrd_courier and ! defined $rrd_courier) {
		$this_minute = RRDs::last($rrd_courier) + $rrdstep;
	}

	if(! -f $rrd_webmail and !$opt{'disable-webmail-rrd'}) {
		RRDs::create($rrd_webmail, '--start', $m, '--step', $rrdstep,
				'DS:wmstat0:ABSOLUTE:'.($rrdstep*2).':0:U',
				'DS:wmstat1:ABSOLUTE:'.($rrdstep*2).':0:U',
				'DS:wmstat2:ABSOLUTE:'.($rrdstep*2).':0:U',
				'DS:wmstat3:ABSOLUTE:'.($rrdstep*2).':0:U',
				"RRA:AVERAGE:0.5:$day_steps:$realrows",   # day
				"RRA:AVERAGE:0.5:$week_steps:$realrows",  # week
				"RRA:AVERAGE:0.5:$month_steps:$realrows", # month
				"RRA:AVERAGE:0.5:$year_steps:$realrows",  # year
				"RRA:MAX:0.5:$day_steps:$realrows",   # day
				"RRA:MAX:0.5:$week_steps:$realrows",  # week
				"RRA:MAX:0.5:$month_steps:$realrows", # month
				"RRA:MAX:0.5:$year_steps:$realrows",  # year
				);
		$this_minute = $m unless $this_minute;
	}
	elsif (-f $rrd_webmail and ! defined $rrd_webmail) {
		$this_minute = RRDs::last($rrd_webmail) + $rrdstep;
	}

	if(! -f $rrd_bytes and ! $opt{'disable-bytes-rrd'}) {
		RRDs::create($rrd_bytes, '--start', $m, '--step', $rrdstep,
				'DS:bytesin:ABSOLUTE:'.($rrdstep*2).':0:U',
				'DS:bytesout:ABSOLUTE:'.($rrdstep*2).':0:U',
				"RRA:AVERAGE:0.5:$day_steps:$realrows",   # day
				"RRA:AVERAGE:0.5:$week_steps:$realrows",  # week
				"RRA:AVERAGE:0.5:$month_steps:$realrows", # month
				"RRA:AVERAGE:0.5:$year_steps:$realrows",  # year
				"RRA:MAX:0.5:$day_steps:$realrows",   # day
				"RRA:MAX:0.5:$week_steps:$realrows",  # week
				"RRA:MAX:0.5:$month_steps:$realrows", # month
				"RRA:MAX:0.5:$year_steps:$realrows",  # year
				);
		$this_minute = $m unless $this_minute;
	}
	elsif(-f $rrd_bytes and ! defined $rrd_bytes) {
		$this_minute = RRDs::last($rrd_bytes) + $rrdstep;
	}

	$rrd_inited=1;
}

sub delete_queue($)
{
	my $qid = shift;
	my @sizes;

	if (defined $queue_active{$qid}) {
		push @sizes, delete $queue_active{$qid};
	}
	if (defined $queue_deferred{$qid}) {
		push @sizes, delete $queue_deferred{$qid};
	}
	scalar @sizes ? @sizes : 0;
}

sub active($)
{
	my $qid = shift;
	defined $queue_active{$qid} ? $queue_active{$qid} : 0;
}

sub deferred($)
{
	my $qid = shift;
	defined $queue_deferred{$qid} ? $queue_deferred{$qid} : 0;
}

sub active2deferred($)
{
	my $qid = shift;
	# if $queue_active{$qid} null means multiple call
	# this function with same qid, must assign a true value
	$queue_deferred{$qid} = delete $queue_active{$qid} || 1;
}

sub process_line($)
{
	my $sl = shift;
	my $time = $sl->[0];
	my $prog = $sl->[2];
	my $text = $sl->[4];

	if($prog =~ /^postfix\/(.*)/) {
		my $prog = $1;
		if($prog eq 'smtp') {
			$text =~ /^([^:]+): .*\bstatus=(sent|bounced|deferred)\b/ or return;
			my $qid = $1;
			my $status = $2;

			if($status eq 'sent') {
				return if $opt{'ignore-localhost'} and
					$text =~ /\brelay=[^\s\[]*\[127\.0\.0\.1\]/;
				return if $opt{'ignore-host'} and
					$text =~ /\brelay=[^\s,]*$opt{'ignore-host'}/oi;
				$bytes_out{$qid} = $queue_active{$qid};
				delete_queue($qid);
				event($time, 'sent');
			}
			elsif($status eq 'bounced') {
				delete_queue($qid);
				event($time, 'bounced');
			}
			elsif($status eq 'deferred') {
				if (not deferred($qid)) {
					# delete if this is the first time
					active2deferred($qid);
				}
				event($time, 'deferred');
			}
		}
		elsif($prog eq 'local') {
			$text =~ /^([^:]+): .*\bstatus=(sent|bounced|deferred)\b/ or return;
			my $qid = $1;
			my $status = $2;

			if($status eq 'bounced') {
				delete_queue($qid);
				event($time, 'bounced');
			}
			if($status eq 'sent') {
				if (my $size = active($qid)) {
					$bytes_in{$qid} = $size;
				}
				delete_queue($qid);
				event($time, 'received');
			}
		}
		elsif($prog eq 'smtpd') {
			if($text =~ /^([0-9A-F])+: client=(\S+)/) {
				my $qid = $1;
				my $client = $2;

				return if $opt{'ignore-localhost'} and
					$client =~ /\[127\.0\.0\.1\]$/;
				return if $opt{'ignore-host'} and
					$client =~ /$opt{'ignore-host'}/oi;
				$bytes_in{$qid} = 'received'; # XXX
				event($time, 'received');
			}
			elsif($opt{'virbl-is-virus'} and $text =~ /^(?:[0-9A-F]+: |NOQUEUE: )?reject: .*: 554.* blocked using irbl.dnsbl.bit.nl/) {
				event($time, 'virus');
			}
			elsif($opt{'rbl-is-spam'} and $text    =~ /^(?:[0-9A-F]+: |NOQUEUE: )?reject: .*: 554.* blocked using/) {
				event($time, 'spam');
			}
			elsif($text =~ /^(?:[0-9A-F]+: |NOQUEUE: )?reject: /) {
				event($time, 'rejected');
			}
		}
		elsif($prog eq 'error') {
			if($text =~ /^([^:]+):.*\bstatus=bounced\b/) {
				delete_queue($1);
				event($time, 'bounced');
			}
		}
		elsif($prog eq 'cleanup') {
			if($text =~ /^([0-9A-F]+): (?:reject|discard): /) {
				delete_queue($1) if ($2 && $2 eq 'discard');
				event($time, 'rejected');
			}
		}
		elsif($prog eq 'qmgr' || $prog eq 'postsuper') {
			$text =~ /^([^\:]+): (.*)/;
			my $qid = $1;
			my $qtext = $2;

			if ($qtext =~ /from=<[^>]*>, size=(\d+).*nrcpt=(\d+).*queue active/) {
				# counting the size
				$queue_active{$qid} = $1*$2; # total size
				if ($bytes_in{$qid} && $bytes_in{$qid} eq 'received') {
					$bytes_in{$qid} = $queue_active{$qid};
				} else {
					$bytes_out{$qid} = $queue_active{$qid};
				}
				delete $queue_deferred{$qid}; # XXX some mail will retry from
							      # deferred queue to active queue
				event($time, 'active');
			}
			elsif ($qtext =~ /removed/) {
				if (active($qid)) {
					delete_queue($qid);
				}
				if (deferred($qid)) {
					delete_queue($qid);
				}
				event($time, 'active');
			}
			elsif ($qtext =~ /status=(expired|bounced|deferred)/) {
				my $status = $1;
				if ($status eq 'expired') {
					delete_queue($qid);
					event($time, 'expired');
				}elsif ($status eq 'bounced') {
					delete_queue($qid);
					event($time, 'bounced');
				}elsif ($status eq 'deferred') {
					active2deferred($qid);
					event($time, 'deferred');
				}
			}
		}elsif($prog eq 'pipe' || $prog eq 'virtual' || $prog eq 'lmtp') {
			# XXX FIXME fallback for maildrop, amavisd  etc. via pipe
			$text =~ /^([^\:]+): .*\bstatus=(sent|deferred|bounced)\b/ or return;
			my $qid = $1;
			my $status = $2;

			if ($status eq 'sent' || $status eq 'bounced') {
				$bytes_in{$qid} = $queue_active{$qid};
				delete_queue($qid);
				event($time, 'other');
			}
		}
	}
	elsif($prog eq 'sendmail' or $prog eq 'sm-mta') {
		if($text =~ /\bmailer=local\b/ ) {
			event($time, 'received');
		}
                elsif($text =~ /\bmailer=relay\b/) {
                        event($time, 'received');
                }
		elsif($text =~ /\bstat=Sent\b/ ) {
			event($time, 'sent');
		}
                elsif($text =~ /\bmailer=esmtp\b/ ) {
                        event($time, 'sent');
                }
		elsif($text =~ /\bruleset=check_XS4ALL\b/ ) {
			event($time, 'rejected');
		}
		elsif($text =~ /\blost input channel\b/ ) {
			event($time, 'rejected');
		}
		elsif($text =~ /\bruleset=check_rcpt\b/ ) {
			event($time, 'rejected');
		}
                elsif($text =~ /\bstat=virus\b/ ) {
                        event($time, 'virus');
                }
		elsif($text =~ /\bruleset=check_relay\b/ ) {
			if (($opt{'virbl-is-virus'}) and ($text =~ /\bivirbl\b/ )) {
				event($time, 'virus');
			} elsif ($opt{'rbl-is-spam'}) {
				event($time, 'spam');
			} else {
				event($time, 'rejected');
			}
		}
		elsif($text =~ /\bsender blocked\b/ ) {
			event($time, 'rejected');
		}
		elsif($text =~ /\bsender denied\b/ ) {
			event($time, 'rejected');
		}
		elsif($text =~ /\brecipient denied\b/ ) {
			event($time, 'rejected');
		}
		elsif($text =~ /\brecipient unknown\b/ ) {
			event($time, 'rejected');
		}
		elsif($text =~ /\bUser unknown$/i ) {
			event($time, 'bounced');
		}
		elsif($text =~ /\bMilter:.*\breject=55/ ) {
			event($time, 'rejected');
		}
	}
	elsif($prog eq 'amavis' || $prog eq 'amavisd') {
		if(   $text =~ /^\([0-9-]+\) (Passed|Blocked) SPAM\b/) {
			event($time, 'spam'); # since amavisd-new-2004xxxx
		}
		elsif($text =~ /^\([0-9-]+\) (Passed|Not-Delivered)\b.*\bquarantine spam/) {
			event($time, 'spam'); # amavisd-new-20030616 and earlier
		}
		### UNCOMMENT IF YOU USE AMAVISD-NEW <= 20030616 WITHOUT QUARANTINE:
		#elsif($text =~ /^\([0-9-]+\) Passed, .*, Hits: (\d*\.\d*)/) {
		#	if ($1 >= 5.0) {      # amavisd-new-20030616 without quarantine
		#		event($time, 'spam');
		#	}
		#}
		elsif($text =~ /^\([0-9-]+\) (Passed |Blocked )?INFECTED\b/) {
			if($text !~ /\btag2=/) { # ignore new per-recipient log entry (2.2.0)
				event($time, 'virus');# Passed|Blocked inserted since 2004xxxx
			}
		}
		elsif($text =~ /^\([0-9-]+\) (Passed |Blocked )?BANNED\b/) {
			if($text !~ /\btag2=/) {
			       event($time, 'virus');
			}
		}
#		elsif($text =~ /^\([0-9-]+\) Passed|Blocked BAD-HEADER\b/) {
#		       event($time, 'badh');
#		}
		elsif($text =~ /^Virus found\b/) {
			event($time, 'virus');# AMaViS 0.3.12 and amavisd-0.1
		}
	}
	elsif($prog eq 'vagatefwd') {
		# Vexira antivirus (old)
		if($text =~ /^VIRUS/) {
			event($time, 'virus');
		}
	}
	elsif($prog eq 'hook') {
		# Vexira antivirus
		if($text =~ /^\*+ Virus\b/) {
			event($time, 'virus');
		}
		# Vexira antispam
		if($text =~ /\bcontains spam\b/) {
			event($time, 'spam');
		}
	}
	elsif($prog eq 'avgatefwd') {
		# AntiVir MailGate
		if($text =~ /^Alert!/) {
			event($time, 'virus');
		}
		elsif($text =~ /blocked\.$/) {
			event($time, 'virus');
		}
	}
	elsif($prog eq 'avcheck') {
		# avcheck
		if($text =~ /^infected/) {
			event($time, 'virus');
		}
	}
	elsif($prog eq 'spamd') {
		if($text =~ /^(?:spamd: )?identified spam/) {
			event($time, 'spam');
		}
	}
	elsif($prog eq 'dspam') {
		if($text =~ /spam detected from/) {
			event($time, 'spam');
		}
	}
	elsif($prog eq 'spamproxyd') {
		if($text =~ /^\s*SPAM/ or $text =~ /^identified spam/) {
			event($time, 'spam');
		}
	}
	elsif($prog eq 'drweb-postfix') {
		# DrWeb
		if($text =~ /infected$/) {
			event($time, 'virus');
		}
	}
	elsif($prog eq 'BlackHole') {
		if($text =~ /Virus/) {
			event($time, 'virus');
		}
		if($text =~ /(?:RBL|Razor|Spam)/) {
			event($time, 'spam');
		}
	}
	elsif($prog eq 'MailScanner') {
		if($text =~ /quarantine/ ) {
			event($time, 'virus');
		}
		# you need to turn on "Detail Spam Report = yes" in
		# MailScanner.conf (Gabriele Oleotti_
		elsif($text =~ /SpamAssassin/ ) {
			event($time, 'spam');
		}
		if($text =~ /Bounce to/ ) {
			event($time, 'bounced');
		}
	}
	elsif($prog eq 'clamsmtpd') {
		if($text =~ /status=VIRUS/) {
			event($time, 'virus');
		}
	}
	elsif($prog eq 'clamav-milter') {
		if($text =~ /Intercepted/) {
			event($time, 'virus');
		}
	}
	elsif ($prog eq 'smtp-vilter') {
		if ($text =~ /clamd: found/) {
			event($time, 'virus');
		}
	}
	elsif($prog eq 'avmilter') {
		# AntiVir Milter
		if($text =~ /^Alert!/) {
			event($time, 'virus');
		}
		elsif($text =~ /blocked\.$/) {
			event($time, 'virus');
		}
	}
	elsif($prog eq 'bogofilter') {
		if($text =~ /Spam/) {
			event($time, 'spam');
		}
	}
	elsif($prog eq 'filter-module') {
		if($text =~ /\bspam_status\=yes/) {
			event($time, 'spam');
		}
	}
	# XXX add courier imap/pop3 login stat support
	elsif ($prog eq 'courierpop3login' || $prog eq 'pop3d') {
		if($text =~ /LOGIN,/) {
			event($time, 'pop3d');
		}
	}
	elsif ($prog eq 'imaplogin' || $prog eq 'imapd') {
		if($text =~ /LOGIN,/) {
			event($time, 'imapd');
		}
	}
	elsif ($prog eq 'pop3d-ssl') {
		if($text =~ /LOGIN,/) {
			event($time, 'pop3d_ssl');
		}
	}
	elsif ($prog eq 'imapd-ssl') {
		if($text =~ /LOGIN,/) {
			event($time, 'imapd_ssl');
		}
	}
	# XXX add extmail webmail login stat support
	elsif ($prog eq 'extmail') {
		if($text =~ /module=login/) {
			if ($text =~ /loginok/) {
				# loginok
				event($time, 'wmstat0');
			} elsif ($text =~ /deactive/) {
				# deactive
				event($time, 'wmstat3');
			} elsif ($text =~ /disabled/) {
				# disabled
				event($time, 'wmstat2');
			} else {
				# loginfail
				event($time, 'wmstat1');
			}
		}
	}
}

sub event($$)
{
	my ($t, $type) = @_;
	update($t) and $sum{$type}++;
}

# returns 1 if $sum should be updated
sub update($)
{
	my $t = shift;
	my $m = $t - $t%$rrdstep;
	init_rrd($m) unless $rrd_inited;
	return 1 if $m == $this_minute;
	return 0 if $m < $this_minute;

	$sum{bytesin} = $sum{bytesout} = 0;

	for (keys %bytes_in) {
		next unless $bytes_in{$_};
		next if ($bytes_in{$_} eq 'received');
		$sum{bytesin} += $bytes_in{$_};
		delete $bytes_in{$_};
	}
	for (keys %bytes_out) {
		next unless $bytes_out{$_};
		$sum{bytesout} += $bytes_out{$_};
		delete $bytes_out{$_};
	}

	print "update $this_minute:$sum{imapd_ssl}:$sum{imapd}:$sum{pop3d_ssl}:$sum{pop3d}\n" if $opt{verbose};
	print "update webmail $this_minute:$sum{wmstat0}:$sum{wmstat1}:$sum{wmstat2}:$sum{wmstat3}\n" if $opt{verbose};
	print "update $this_minute:$sum{sent}:$sum{received}:$sum{bounced}:$sum{rejected}:$sum{virus}:$sum{spam}\n" if $opt{verbose};

	RRDs::update $rrd, "$this_minute:$sum{sent}:$sum{received}:$sum{bounced}:$sum{rejected}" unless $opt{'disable-mail-rrd'};
	RRDs::update $rrd_virus, "$this_minute:$sum{virus}:$sum{spam}" unless $opt{'disable-virus-rrd'};
	RRDs::update $rrd_bytes, "$this_minute:$sum{bytesin}:$sum{bytesout}" unless $opt{'disable-bytes-rrd'};
	RRDs::update $rrd_courier, "$this_minute:$sum{imapd_ssl}:$sum{imapd}:$sum{pop3d_ssl}:$sum{pop3d}" unless ($opt{'disable-courier-rrd'});
	RRDs::update $rrd_webmail, "$this_minute:$sum{wmstat0}:$sum{wmstat1}:$sum{wmstat2}:$sum{wmstat3}" unless ($opt{'disable-webmail-rrd'});

	if ($m > $this_minute+$rrdstep) {
		for (my $sm=$this_minute+$rrdstep;$sm<$m;$sm+=$rrdstep) {
			print "update $sm:0:0:0:0:0:0 (SKIP)\n" if $opt{verbose};
			RRDs::update $rrd, "$sm:0:0:0:0" unless $opt{'disable-mail-rrd'};
			RRDs::update $rrd_virus, "$sm:0:0" unless $opt{'disable-virus-rrd'};
			print "update $sm:0:0 (SKIP)\n" if $opt{verbose};
			print "update $sm:0:0:0:0 (SKIP)\n" if $opt{verbose};
			print "update $sm:0:0:0:0 (SKIP)\n" if $opt{verbose};
			RRDs::update $rrd_bytes, "$sm:0:0" unless $opt{'disable-bytes-rrd'};
			RRDs::update $rrd_courier, "$sm:0:0:0:0" unless $opt{'disable-courier-rrd'};
			RRDs::update $rrd_webmail, "$sm:0:0:0:0" unless $opt{'disable-webmail-rrd'};
		}
	}
	$this_minute = $m;

	$sum{sent}=0;
	$sum{received}=0;
	$sum{bounced}=0;
	$sum{rejected}=0;
	$sum{virus}=0;
	$sum{spam}=0;
	$sum{bytesin}=0;
	$sum{bytesout}=0;
	$sum{imapd_ssl}=0;
	$sum{imapd}=0;
	$sum{pop3d_ssl}=0;
	$sum{pop3d}=0;
	$sum{wmstat0} = 0;
	$sum{wmstat1} = 0;
	$sum{wmstat2} = 0;
	$sum{wmstat3} = 0;
	$sum{active}=0;
	$sum{deferred}=0;
	$sum{other}=0;
	$sum{expired}=0;
}

main;

__END__

=head1 NAME

mailgraph_ext.pl - rrdtool frontend for mail statistics

=head1 SYNOPSIS

B<mailgraph> [I<options>...]

     --man             show man-page and exit
 -h, --help            display this help and exit
     --version         output version information and exit
 -h, --help            display this help and exit
 -v, --verbose         be verbose about what you do
 -V, --version         output version information and exit
 -c, --cat             causes the logfile to be only read and not monitored
 -l, --logfile f       monitor logfile f instead of /var/log/syslog
 -t, --logtype t       set logfile's type (default: syslog)
 -y, --year            starting year of the log file (default: current year)
     --host=HOST       use only entries for HOST (regexp) in syslog
 -d, --daemon          start in the background
 --daemon-pid=FILE     write PID to FILE instead of /var/run/mailgraph.pid
 --daemon-rrd=DIR      write RRDs to DIR instead of /var/log
 --daemon-log=FILE     write verbose-log to FILE instead of /var/log/mailgraph.log
 --ignore-localhost    ignore mail to/from localhost (used for virus scanner)
 --ignore-host=HOST    ignore mail to/from HOST (used for virus scanner)
 --disable-mail-rrd    don't update the mail rrd
 --disable-virus-rrd   don't update the virus rrd
 --disable-courier-rrd don't update the courier rrd
 --disable-bytes-rrd   don't update the bytes rrd
 --rrd-name=NAME       use NAME.rrd and NAME_*.rrd for the rrd files
 --rbl-is-spam         count rbl rejects as spam
 --virbl-is-virus      count virbl rejects as viruses

=head1 DESCRIPTION

This script does parse syslog and updates the RRD database (mailgraph.rrd) in
the current directory.

=head2 Log-Types

The following types can be given to --logtype:

=over 10

=item syslog

Traditional "syslog" (default)

=item metalog

Metalog (see http://metalog.sourceforge.net/)

=back

=head1 COPYRIGHT

Copyright (c) 2004-2005 by ETH Zurich. All rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=head1 AUTHOR

S<David Schweikert E<lt>dws@ee.ethz.chE<gt>>

S<He zhiqiang E<lt>hzqbbc@hzqbbc.comE<gt>>

=head1 HISTORY

 2002-03-19 ds Version 0.20
 2004-10-11 ds Initial ISGTC version (1.10)
 2006-05-01 hzqbbc ext version (1.12_ext)

=cut

# vi: sw=8
