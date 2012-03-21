# vim: set cindent expandtab ts=4 sw=4:
package APF::Plugins;
use strict;
use vars qw(@_PLUGINS);
use POSIX qw(strftime);

sub new {
	my $class = shift;
	my $self = {@_};
	bless $self, $class;
	$self;
}

# transaction resource
sub tr {
    shift->{_tr};
}

# apf resource
sub ar {
    shift->{_ar};
}

sub config {
    shift->{_config};
}

# define KERN_EMERG    "<0>"  /* system is unusable               */
# define KERN_ALERT    "<1>"  /* action must be taken immediately */
# define KERN_CRIT     "<2>"  /* critical conditions              */
# define KERN_ERR      "<3>"  /* error conditions                 */
# define KERN_WARNING  "<4>"  /* warning conditions               */
# define KERN_NOTICE   "<5>"  /* normal but significant condition */
# define KERN_INFO     "<6>"  /* informational                    */
# define KERN_DEBUG    "<7>"  /* debug-level messages             */

# $Net::Server::syslog_map = {0 => 'err',
#                             1 => 'warning',
#                             2 => 'notice',
#                             3 => 'info',
#                             4 => 'debug'};
sub debug {
    my $self = shift;
    my ($level, @msg) = @_;
    #          the parent class     the child class
    my $config = $self->{config} || $self->config;

    # the following code wait for fix, currently no loglevel available
    my $method = $config->{debug_method} || 'stderr';
    my $enable = ($config->{debug} && $config->{debug} eq 'yes' ? 1:0);
    my $log_level = $config->{debug_level} || '0'; # err

    return unless $enable;
    die "Error log_level\n" if ($log_level !~ /^\d$/ && $log_level > 4);

    chomp @msg;
    unshift @msg, $level unless ($level =~/^\d$/);

    if ($method eq 'syslog') {
        $self->{_tr}->log(@_);
    } else {
        my $t = strftime "%m-%d %H:%M:%S", localtime;
        my $app = $APF::Server::App;
        # ignore error
        $level = 0 if ($level !~ /^\d$/);
        warn sprintf("%s [%s]: @msg\n", $t, $$)
            if ($level <= $log_level);
    }
}

# only for parent class
sub _config {
    my $self = shift;
    my $file = $self->{plugin_conf};
    my %config;
    my @plugs;

    open (FD, $file) or die "Error open $file, $!\n";
    my $continue = 0;
    my $lastkey = '';
    my $num = 0;
    while (<FD>) {
        $num ++;
        chomp;
        next if /^\s*#/ or /^\s*$/;

        if (/^\s*([^= ]+)\s*=\s*(.*)\s*/) {
            my ($key , $val) = ($1, $2);
            $lastkey = $key;
            if ($val =~ /,/) { # contain ','
                my @arr;
                for my $m (split(/\s*,\s*/, $val)) {
                    $m =~ s/\s+//g;
                    push @arr, $m;
                }
                $config{$lastkey} = \@arr;
            } elsif ($val =~ /\s+/) {
                my @arr;
                for my $m (split(/\s+/, $val)) {
                    $m =~ s/\s*,\s*//g;
                    push @arr, $m;
                }
                $config{$lastkey} = \@arr;
            } else {
                $config{$lastkey} = $val;
            }

            if ($key=~ /_plugin/ & $val eq 'yes') {
                my $subkey = $key;
                $subkey =~ s/_plugin//;
                push @plugs, $subkey;
            }
            # print "lastkey = $lastkey\n";
        } elsif (/\s+([^=, ]+)\s*,*\s*$/) {
            defined $config{$lastkey} or next; # ignore malform info
            ref $config{$lastkey} or $config{$lastkey} = [$config{$lastkey}];

            $config{$lastkey}->[0] or ($config{$lastkey} = [$1] and next);
            push @{$config{$lastkey}}, $1;
        } else {
            # XXX FIXME can only call warn to throw to stderr
            warn "malform configuration at line: $num\n";
        }
    }
    $self->{config} = \%config;
    $self->{_plugins} = \@plugs;
}

sub compile {
    my $self = shift;
    my $pkg = $_[0];
    my $code = $_[1];

    my $src = join(
        "\n",
        "package $pkg;",
        'use strict;',
        'use vars qw(@ISA);',
        '@ISA=qw(APF::Plugins);',
        "sub plugin_name { qq[$pkg] }",
        'local $/ = "\n";',
        $code,
        "\n",
        "1;\n",
    );

    eval $src;
    $@;
}

sub load_plugin {
    my $self = shift;
    return if ($self->{loaded});

    $self->_load_plugin; # reload _plugins
    $self->{loaded} = 1;
    $self->{_plugins} = \@_PLUGINS; # XXX FIXME
}

sub _load_plugin {
    my $self = shift;
    my $dir = $self->{plugin_dir};
    my $fatal = $self->{fatal_error};
    my @_plugs = @{delete $self->{_plugins}};

    @_plugs = grep { s/_plugin$// } keys %{$self->{config}} unless @_plugs;

    for my $f (@_plugs) {
        next if (!-r "$dir/$f");
        #next if ($self->{config}->{"$f\_plugin"} ne 'yes');

        local $/ = undef;
        open (FH, "$dir/$f") or ($fatal ? die $! : next );
        my $code = <FH>;
        close FH;

        $dir eq $self->{plugin_dir} or $f = "$dir/$f";
        $f =~ s!([^A-Za-z0-9_\/])!sprintf("_%2x",unpack("C",$1))!eg;
        $f =~ s!/!::!g;
        $f = "APF::Plugin::$f";

        $self->debug(4,"Loading $f");
        my $rc = $self->compile($f, $code);
        if ($fatal && $rc) { die $rc };

        my $plug = $f->new;
        push @_PLUGINS, $plug;
    }
    1;
}

# setting resource on parent class
sub set_r {
    my $self = shift;
    my $method = shift;

    for my $plug (@_PLUGINS) {
        $plug->{"_$method"} = $_[0];
    }
}

sub init_hook {
    my $self = shift;
    for my $plug (@_PLUGINS) {
        next unless $plug->can('init');
        $self->debug(4,"initing ", $plug->plugin_name, " init_hook");
        $plug->init;
    }
    'DUNNO';
}

sub pre_run_hook {
    my $self = shift;

    my $rc = 'DUNNO';
    for my $plug (@_PLUGINS) {
        next unless $plug->can('pre_hook');
        $self->debug(4,"processing ", $plug->plugin_name, " pre_run_hook");
        $rc = $plug->pre_hook || 'DUNNO';
        unless ($rc eq 'DUNNO') {
            $self->debug(3, "Stop at ",$plug->plugin_name, " pre_hook");
	    $self->{_stop_hook} = $plug->{plugin_name} || $plug->plugin_name;
            return $rc;
        }
    }
    $rc;
}

sub post_run_hook {
    my $self = shift;

    my $rc = 'DUNNO';
    for my $plug (@_PLUGINS) {
        next unless $plug->can('post_hook');
        $self->debug(4,"processing ", $plug->plugin_name, " post_hook");
        $rc = $plug->post_hook || 'DUNNO';
        unless ($rc eq 'DUNNO') {
            $self->debug(3, "Stop at ",$plug->plugin_name, " post_hook");
	    $self->{_stop_hook} = $plug->{plugin_name} || $plug->plugin_name;
            return $rc;
        }
    }
    $rc;
}

sub run_hook {
    my $self = shift;

    my $rc = 'DUNNO';
    for my $plug (@_PLUGINS) {
        next unless $plug->can('hook');
        $self->debug(4,"processing ", $plug->plugin_name, " hook");
        $rc = $plug->hook || 'DUNNO';
        unless ($rc eq 'DUNNO') {
            $self->debug(3, "Stop at ",$plug->plugin_name, " hook");
	    $self->{_stop_hook} = $plug->{plugin_name} || $plug->plugin_name;
            return $rc;
        }
    }
    $rc;
}

sub cleanup_hook {
    my $self = shift;

    for my $plug (@_PLUGINS) {
        next unless $plug->can('cleanup');
        $self->debug(4,"processing ", $plug->plugin_name, " cleanup");
        $plug->cleanup;
    }
    'DUNNO';
}

sub unload_plugin {
    my $self = shift;
    for my $plug (@_PLUGINS) {
        undef $plug;
    }
}

1;

__END__

A very very simple plugin implemention, it just work
