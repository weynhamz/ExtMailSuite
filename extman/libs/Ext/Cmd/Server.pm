# vim: set ci et ts=4 sw=4:
package Ext::Cmd::Server;
use strict;
use IO::Handle;
use POSIX qw(WNOHANG setsid strftime uname);
use IO::Socket;
use Ext::Cmd::Protocol;
use vars qw(%CHILD);

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;
    $self->{max_conn} ||= '5';
    $self->{auth_code} ||= 'eExXtTMmAaIiLl';
    $self;
}

$SIG{CHLD} = sub {
    my $pid = 0;
    while (($pid = waitpid(-1, WNOHANG)) > 0) {
        delete $CHILD{$pid};
    }
};

$SIG{PIPE} = sub { warn "PERROR: $!\n" and return 'IGNORE' };

sub daemonize {
    my $self = shift;

    open STDIN, '/dev/null' or die "Can't read /dev/null: $!";

    if($self->{verbose}) {
        open STDOUT, ">>$self->{logfile}"
            or die "Can't write to $self->{logfile}: $!";
    } else {
        open STDOUT, '>/dev/null'
            or die "Can't write to /dev/null: $!";
    }

    if (-r $self->{pidfile}) {
        open (FD, "< $self->{pidfile}") or die "can' read $self->{pidfile}: $!\n";
        my $opid = <FD>;
        close FD;
        chomp $opid;
        die "Found an server instance pid=$opid is running, abort..\n"
            if (kill 0, $opid);
    }

    defined(my $pid = fork) or die "Can't fork: $!";

    if($pid) {
        # parent
        open PIDFILE, ">$self->{pidfile}"
            or die "Can't write to $self->{pidfile}: $!\n";
        print PIDFILE "$pid\n";
        close(PIDFILE);
        exit;
    }

    # child
    setsid  or die "Can't start a new session: $!";
    open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";
    STDOUT->autoflush(1);
}

sub log {
    my $self = shift;
    my $msg = shift;
    my $time = (strftime "%b %e %H:%M:%S", localtime);
    my $host = (POSIX::uname)[1];
    my $prog = $self->{progname} || 'server';

    ($host) = ($host =~ /^([^\.]+)/);
    $host = 'localhost' unless $host;
    $msg =~ s/[\r?\n]+/ /;

    print STDERR "$time $host $prog\[$$\]: $msg\n";
}

sub start {
    my $self = shift;
    my $unix = $self->{listen};
    my $path;

    if ($unix !~ /^unix:(.+)/i) {
        die "Listen info incorrect!";
    }
    $path = $1;
    my $srv = IO::Socket::UNIX->new(Local => $path, Listen => SOMAXCONN) || die "Can't create socket: $path\n";
    $srv->autoflush(1);
    chmod 0777, $path;
    $self->{socket} = $srv;
}

sub start_child {
    my $self = shift;
    if (scalar keys %CHILD>= $self->{max_conn}) {
        return undef;
    }
    if (defined (my $pid = fork)) {
        $CHILD{$pid} = 1;
        return $pid;
    }
    die "Error fork: $!\n";
}

sub main_loop {
    my $self = shift;
    my $cmd = shift;

    while (1) {
        my $cli = $self->{socket}->accept;
        next unless $cli;

        my $child = $self->start_child;
        if (not defined $child) {
            print $cli "554 Server busy or error: $!\n";
            $cli->shutdown(2);
            next;
        }

        print "staring $child\n" if $child;
        next if $child; # if parent
        $self->{client} = $cli;
        $self->run_child($cmd);
        exit 0;
    }
}

sub run_child {
    my $self = shift;
    my $cmd = shift;
    my $sock = $self->{client};

    require Ext::Cmd::Protocol;
    my $proto = Ext::Cmd::Protocol->new(
        auth_code => $self->{auth_code},
        socket => $sock,
    );
    my $quit = 0;

    while (!$quit) {
        $quit = 1 if not $proto->is_authenticated;
        my $input = $proto->readline;
        if (!$input) {
            $quit = 1;
        } elsif ($input =~ /^([^ ]+)\s*(.*)/) {
            my ($command, $param) = ($1, $2);
            if (exists $cmd->{$command}) {
                eval { $cmd->{$command}->($proto, $param) };
                if ($@) {
                    $proto->set_reply('502', "Command exec failed: $@");
                }
            } else {
                $proto->set_reply('501', "Unknown command: $command");
            }
        } else {
            $proto->set_reply('503', "Malform command");
        }
    }
}

1;
