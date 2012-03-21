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
package Ext::CGI;
use Exporter;

# XXX FIXME - a trick to manually specify upload temp dir
BEGIN { $ENV{'TMPDIR'} = '\DIR_NOT_EXIST' }

# we need to redefine uploadInfo, so disable such kind of warning
no warnings 'redefine';
use CGI qw(:standard);
use Ext::Utils qw(expire_calc);
use Ext::MIME qw(hdr_fmt_hash);
use vars qw(@ISA);

@ISA = qw(Exporter CGI);

sub new {
    my $self = shift;
    my %opt = @_;

    if ($ENV{FCGI_ROLE} || $ENV{FCGI_APACHE_ROLE}) {
        require Ext::FCGI;
        Ext::FCGI::register_cleanup(\&cleanup);
        CGI::private_tempfiles(1);
    }

    if (defined $opt{tmpdir}) {
        $CGITempFile::TMPDIRECTORY = $opt{tmpdir};

        # remove the upload temp dir specification
        splice(@_, 0, 2);
    }
    return $CGI::Q = $self->SUPER::new(@_);
}

sub allfiles {
    my $self = shift;
    my @lists;
    for my $m (@{$self->cgi_full_names}) {
        my $fh = $self->upload($m);
        next unless $fh;
        push @lists, $fh;
    }
    return unless scalar @lists;
    \@lists;
}

sub cgi {
    my $self = shift;
    if (wantarray) {
        my @r = $self->param(@_);
        return $r[0] if scalar @r <= 1;
        return @r if scalar @r > 1;
    } else {
        my $r = $self->param(@_);
        return $r;
    }
}

sub cgi_full_names {
    my $self = shift;
    my @names = $self->param;
    \@names;
}

sub expires {
    my $self = shift;
    my ($time, $format) = @_;
    $format ||= 'http';

    my(@MON)=qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
    my(@WDAY) = qw/Sun Mon Tue Wed Thu Fri Sat/;

    $time = expire_calc($time);
    return $time unless $time =~ /^\d+$/;

    my $sp = ' ';
    $sp = '-' if ($format eq 'cookie');
    my($sec,$min,$hour,$mday,$mon,$year,$wday) = gmtime($time);
    $year += 1900;
    return sprintf("%s, %02d$sp%s$sp%04d %02d:%02d:%02d GMT",
        $WDAY[$wday],$mday,$MON[$mon],$year,$hour,$min,$sec);
}

sub set_cookie {
    my $self = shift;
    my %opt = @_;
    $self->{__cookie} = $self->cookie(
        -name => $opt{name},
        -value => $opt{value},
        -expires => $opt{expires},
        -secure => $opt{secure},
        -path => $opt{path},
    );
    0;
}

sub send_cookie {
    my $self = shift;

    return if $self->{cookie_sent};

    my $cookie = $self->{__cookie};
    my(@cookie) = ref($cookie) && ref($cookie) eq 'ARRAY' ? @{$cookie} : $cookie;
    foreach (@cookie) {
        my $cs = UNIVERSAL::isa($_,'CGI::Cookie') ? $_->as_string : $_;
        print "Set-Cookie: $cs\r\n" if $cs ne '';
    }
    $self->{cookie_sent} = 1;
    1;
}

sub set_tmp {
    my $self = shift;
    my $dir = shift;

    $CGITempFile::TMPDIRECTORY = $dir;
}

sub get_cookie {
    my $self = shift;
    my $name = shift;
    return unless $name;
    return $self->cookie($name);
}

sub uploadInfo {
    my $self = shift;
    my $header = $self->SUPER::uploadInfo(shift);
    return unless ref $header && scalar keys %$header;
    my %header = hdr_fmt_hash("Content-Disposition: ".$header->{'Content-Disposition'});
    $header{'Content-Type'} = $header->{'Content-Type'};
    %header;
}

sub cleanup {
    CGI::initialize_globals();
    CGI::DESTROY();
}

sub DESTROY { }

1;
