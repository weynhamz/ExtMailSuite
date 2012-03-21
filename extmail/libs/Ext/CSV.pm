# vim: set cindent expandtab ts=4 sw=4:
# derive from: Alan Citterman <alan@mfgrtl.com>
package Ext::CSV;
require 5.002;
use strict;

use Exporter;
use vars qw(@ISA);
@ISA = qw(Exporter);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    $self->{'_STATUS'} = undef;
    $self->{'_ERROR_INPUT'} = undef;
    $self->{'_STRING'} = undef;
    $self->{'_FIELDS'} = undef;
    bless $self, $class;
    return $self;
}

sub error_input {
    shift->{'_ERROR_INPUT'};
}

sub string {
    shift->{'_STRING'};
}

sub fields {
    my $self = shift;
    if (ref($self->{'_FIELDS'})) {
        return @{$self->{'_FIELDS'}};
    }
    undef;
}

sub combine {
    my $self = shift;
    my @part = @_;
    $self->{'_FIELDS'} = \@part;
    $self->{'_ERROR_INPUT'} = undef;
    $self->{'_STATUS'} = 0;
    $self->{'_STRING'} = '';
    my $column = '';
    my $combination = '';
    my $skip_comma = 1;
    if ($#part >= 0) {
        # at least one argument was given for "combining"...
        for $column (@part) {
            if ($skip_comma) {
                # do not put a comma before the first argument...
                $skip_comma = 0;
            } else {
                # do put a comma before all arguments except the first argument...
                $combination .= ',';
            }
            $column =~ s/\042/\042\042/go; # convert to sigle quote
            $combination .= "\042";
            $combination .= $column;
            $combination .= "\042";
        }
        $self->{'_STRING'} = $combination;
        $self->{'_STATUS'} = 1;
    }
    return $self->{'_STATUS'};
}

sub parse {
    my $self = shift;
    $self->{'_STRING'} = shift;
    $self->{'_FIELDS'} = undef;
    $self->{'_ERROR_INPUT'} = $self->{'_STRING'};
    $self->{'_STATUS'} = 0;
    if (!defined($self->{'_STRING'})) {
        return $self->{'_STATUS'};
    }
    my $keepon = 1;
    my $good = 0;
    my $line = $self->{'_STRING'};
    if ($line =~ /\n$/) {
        chop($line);
        if ($line =~ /\r$/) {
            chop($line);
        }
    }
    my $mouthful = '';
    my @part = ();
    while ($keepon and ($good = $self->_bite(\$line, \$mouthful, \$keepon))) {
        push(@part, $mouthful);
    }
    if ($good) {
        $self->{'_ERROR_INPUT'} = undef;
        $self->{'_FIELDS'} = \@part;
    }
    return $self->{'_STATUS'} = $good;
}

sub _bite {
    my ($self, $line_ref, $piece_ref, $bite_again_ref) = @_;
    my $in_quotes = 0;
    my $ok = 0;
    $$piece_ref = '';
    $$bite_again_ref = 0;
    while (1) {
        if (length($$line_ref) < 1) {
            # end of string...
            if ($in_quotes) {
                # end of string, missing closing double-quote...
                last;
            } else {
                # proper end of string...
                $ok = 1;
                last;
            }
        } elsif ($$line_ref =~ /^\042/) {
            # double-quote...
            if ($in_quotes) {
                if (length($$line_ref) == 1) {
                    # closing double-quote at end of string...
                    substr($$line_ref, 0, 1) = '';
                    $ok = 1;
                    last;
                } elsif ($$line_ref =~ /^\042\042/) {
                    # an embedded double-quote...
                    $$piece_ref .= "\042";
                    substr($$line_ref, 0, 2) = '';
                } elsif ($$line_ref =~ /^\042,/) {
                    # closing double-quote followed by a comma...
                    substr($$line_ref, 0, 2) = '';
                    $$bite_again_ref = 1;
                    $ok = 1;
                    last;
                } else {
                    # double-quote, followed by undesirable character
                    # (bad character sequence)...
                    last;
                }
            } else {
                if (length($$piece_ref) < 1) {
                    # starting double-quote at beginning of string
                    $in_quotes = 1;
                    substr($$line_ref, 0, 1) = '';
                } else {
                    # double-quote, outside of double-quotes
                    # (bad character sequence)...
                    last;
                }
            }
        } elsif ($$line_ref =~ /^,/) {
            # comma...
            if ($in_quotes) {
                # a comma, inside double-quotes...
                $$piece_ref .= substr($$line_ref, 0 ,1);
                substr($$line_ref, 0, 1) = '';
            } else {
                # a comma, which separates values...
                substr($$line_ref, 0, 1) = '';
                $$bite_again_ref = 1;
                $ok = 1;
                last;
            }
        } else {
            # tolerate 8bit characters
            $$piece_ref .= substr($$line_ref, 0 ,1);
            substr($$line_ref, 0, 1) = '';
        }
    }
    $ok;
}

1;
