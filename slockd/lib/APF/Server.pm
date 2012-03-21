#!/usr/bin/perl -w
# vim: set cindent expandtab ts=4 sw=4:
# Spam Locker - A policy server using Net::Server to rewrite
#               powerby APF technology
#
# Author: He zhiqiang <hzqbbc@hzqbbc.com>
# Rewrite: 2006-04-08
#
package APF::Server;

use APF::Plugins;
use APF::Color; # do color logging
use base qw(Net::Server::PreFork);
use vars qw(%CONCUR $App);
use strict;

sub child_init_hook {
    my $self = shift;
    my $server = $self->{server};
    warn "starting child $$\n";

    $0 = "$App (idle)";

    my $plug = $self->{_plugin} = APF::Plugins->new(
            plugin_dir => $server->{plugin_dir},
            fatal_error => $server->{fatal_error},
            plugin_conf => $server->{plugin_conf},);

    $plug->_config; # load config
    $plug->load_plugin;
    $plug->set_r('tr', $self); # XXX FIXME
    $plug->set_r('config', $plug->{config});
}

sub child_finish_hook {
    my $self = shift;
    warn "closing child $$\n";

}

sub child_is_talking_hook {
    my $self = shift;
    my $sock = shift;

    my @rv = $self->recv_child($sock);
    @rv or return;

    $self->send_child($sock, @rv);
}

sub configure_hook {
    my $self = shift;
#    $self->{serialize} = 'semaphore2';
    $App = 'slockd'; # XXX
}

sub post_configure_hook {
    $0 = "$App (master)";
}

### process the request
sub process_request {
    my $self = shift;
    local $/ = "\n\n";

    $0 = "$App (busy)";

    while (my $rp = <STDIN>) {
        my %attr = ();
        $rp =~ s/\n+$//;

        # warn "rp => '$rp'\n";
        for (split(/\n+/, $rp)) {
            /^([^=]+)=(.*)/;
            $attr{$1} = $2;
        }

        # setting apf resource
        $self->{_plugin}->set_r('ar', \%attr);

        my $res;

        { # XXX start of HOOK block
            local $/ = "\n"; # temperary set $ to "\n"
            # before main hook, do some initialize
            $self->{_plugin}->init_hook;

            for my $p (qw(pre_run run post_run)) {
                my $p2 = $p.'_hook';
                $res = $self->{_plugin}->$p2;
                last if !dunno($res);
            }

            # after main hook, do some cleanup
            $self->{_plugin}->cleanup_hook;
        } # XXX end of HOOK block

        my $client_info = $self->gen_info(%attr);
        if (ok($res) || dunno($res)) {
            $self->{_plugin}->debug(0,darkc("[$res ,$client_info]",'green'));

	    if ($self->{_plugin}->{config}->{action_type} &&
	    	$self->{_plugin}->{config}->{action_type} eq 'learn' &&
		$self->{_plugin}->{config}->{action_ham}) {

		my $filter = $self->{_plugin}->{config}->{action_ham};

		$filter = join(" ", @$filter) if ref $filter;
		$self->{_plugin}->debug(0, darkc("Learn mode: $filter", 'green'));
		print STDOUT "action=$filter\n\n";
	    } else {
                print STDOUT "action=$res\n\n";
	    }
        } else {
            $self->{_plugin}->debug(0,darkc("[$res ,$client_info]",'red'));

	    if ($self->{_plugin}->{config}->{action_type} &&
		$self->{_plugin}->{config}->{action_type} eq 'header') {

	    	my $plug = $self->{_plugin}->{_stop_hook};
		my $why = $self->{_plugin}->{_stop_why};
		$plug =~ s/^APF::Plugin:://;
		$plug = ucfirst $plug;

	    	print STDOUT "action=PREPEND X-Slockd-Result: blocked by $plug";

		$self->{_plugin}->debug(0, darkc("Header mode: blocked by $plug", 'yellow'));

		if ($why) {
		    print STDOUT ", why=$why\n\n";
	        } else {
		    print STDOUT "\n\n";
	        }
	    } elsif ($self->{_plugin}->{config}->{action_type} &&
		     $self->{_plugin}->{config}->{action_type} eq 'learn' &&
	     	     $self->{_plugin}->{config}->{action_spam}) {

		my $filter = $self->{_plugin}->{config}->{action_spam};
		my $plug = lc $self->{_plugin}->{_stop_hook};
		$plug =~ s/^APF::Plugin:://;

		$filter = join(" ", @$filter) if ref $filter;

		# Ignore Greylisting system, just retrain those blocked by hard
		# reject DSN code.
		if ($plug eq 'greylist') {
		    print STDOUT "action=$res\n\n";
	        } else {
		    $self->{_plugin}->debug(0, darkc("Learn mode: $filter", 'yellow'));
		    print STDOUT "action=$filter\n\n";
	        }
	    } else {
		print STDOUT "action=$res\n\n";

		$self->{_plugin}->debug(0, darkc("Policy mode: Nope", 'yellow'));
	    }
        }
    }

    $self->{_plugin}->debug(0,darkc("[Session ended and closing socket]",'yellow'));

    fileno(STDOUT) and close STDOUT;
    $0 = "$App (idle)";
    1;
}

sub gen_info {
    my $self = shift;
    my %ar = @_;
    return "from=<$ar{sender}> to=<$ar{recipient}> helo=<$ar{helo_name}> ip=<$ar{client_address}> client=<$ar{client_name}>";
}

sub dunno {
    # case sensitive
    my $res = lc shift;
    return 1 if $res eq 'dunno';
    0;
}

sub ok {
    # case sensitive
    my $res = lc shift;
    return 1 if $res eq 'ok';
    0;
}

sub send_parent {
    my $self = shift;
    my $msg = shift;
    my $sock = $self->{server}->{parent_sock};

    print $sock "$msg\n";
}

sub recv_parent {
    my $self = shift;
    my $sock = $self->{server}->{parent_sock};

    local $/ = "\n";
    my $response = <$sock>;
    chomp $response;
    $response;
}

sub send_child {
    my $self = shift;
    my $sock = shift;
    my ($life_t, $msg) = @_; # lifetime + ip
    my $now = time;

    $life_t or $life_t = 360;

    if (defined $CONCUR{$msg}) {
        if ($now - $CONCUR{$msg}{time} > $life_t) {
            $CONCUR{$msg}{stat} = 1;
            $CONCUR{$msg}{time} = $now;
        } else {
            $CONCUR{$msg}{stat} += 1;
        }
    } else {
        $CONCUR{$msg}{stat} = 1;
        $CONCUR{$msg}{time} = $now;
    }

    print $sock $CONCUR{$msg}{stat}, "\n";
}

sub recv_child {
    my $self = shift;
    my $sock = shift;

    defined fileno($sock) or return undef;
    my $info = <$sock>;
    defined $info or return undef;

    chomp $info;

    $info =~ /^(\d+) (.*)/;
    ($1, $2);
}

1;
