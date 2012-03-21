# vim: set ci et sw=4 ts=4:
package Ext::Cmd::Protocol;

use strict;
use Exporter;
use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;

    die "Need AUTH code!" unless $self->{auth_code};
    die "Need a valid Socket!" unless $self->{socket};

    $self;
}

sub is_authenticated {
    my $self = shift;
    return 1 if $self->{authenticated};

    my $r = $self->readline;
    if($r =~ /^AUTH=(.+)$/) {
        my $code = $1;
        if ($code eq $self->{auth_code}) {
            $self->{authenticated} = 1;
            $self->set_reply('250','AUTH OK');
            return 1;
        }
        $self->set_reply('553', 'AUTH FAIL');
        return 0;
    }
    0;
}

sub readline {
    my $self = shift;
    my $sock = $self->{socket};
    my $line = <$sock>;

    return unless $line;
    $line =~ s/\r?\n$//;
    $line;
}

sub set_reply {
    my $self = shift;
    my $sock = $self->{socket};
    my $code = shift;
    my $msg = shift;

    $msg =~ s/\r?\n$//;
    print $sock "$code $msg\n";
}

1;
