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
package Ext::GlobalAbook::LDAP;

use Exporter;
use Net::LDAP;
use Ext::Utils;
use Ext::Lang;

use vars qw(@ISA @ABOOK);
@ISA = qw(Ext::GlobalAbook);
undef @ABOOK;

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;

    $self->init(@_);
    $self;
}

sub init {
    my $self = shift;
    my %opt = @_;

    $opt{host} = '127.0.0.1' if not defined $opt{host};
    $opt{base} = 'ou=AddressBook,dc=extmail.org' if not defined $opt{base};
    $opt{rootdn} = 'cn=Manager,dc=extmail.org'
        if not defined $opt{rootdn};
    $opt{rootpw} = 'rootpw' if not defined $opt{rootpw};
    $opt{bind} = 0 if not defined $opt{bind};
    $opt{filter} = 'objectClass=officePerson' if not defined $opt{filter};
    $opt{convert} = 0 if not defined $opt{convert};

    $self->{opt}=\%opt;

    my ($ldap, $msg);
    $ldap = Net::LDAP->new($opt{host}) or die "LDAP operation fail, $!\n";
    if($opt{bind}) {
        $msg = $ldap->bind(
            $opt{rootdn},
            password=>$opt{rootpw},
            version => 3
        );
        $self->{msg} = $msg;
    }
    $self->{ldap} = $ldap;
}

sub search {
    my $self = shift;
    my $key = $_[0];
    my $res = $self->_search("", [qw(cn mail o telephoneNumber)]);
    my $ref = [];

    return [] if ($key =~ /^\s*$/);

    $key = from_to($key, _getlang(), 'UTF-8');
    foreach my $r ($res->entries) {
        my @arr;
        my $match = 0;
        foreach (qw(cn mail o mobile)) {
            my $val = $r->get_value($_);
            if (!$match && $val =~ /$key/i) {
                $match = 1;
            }

            if ($self->{opt}{convert}) {
                $val = str2ncr('UTF-8',$val);
            }
            push @arr, $val;
        }
        push @$ref, \@arr if ($match);
    }
    $ref;
}

# XXX don't call this function directly, it try to get the
# current language and charset via Ext::Lang, convert to
# UTF-8, only necessary for LDAP v3, the %map is only a
# temporary solution, dirty and sucks!
my %map = (
    'zh_CN' => 'gb2312',
    'zh_TW' => 'big5',
    'en_US' => 'iso-8859',
);

sub _getlang {
    my $lang = curlang();
    if (my $charset = $map{$lang}) {
        return $charset;
    } else {
        return 'iso-8859';
    }
}

# XXX the low level search, should not call it directly
sub _search {
    my $self = shift;
    my $result = $self->{ldap}->search(
        base => $_[2] || $self->{opt}->{base},
        scope => "sub",
        filter => "$_[0]" || $self->{opt}->{filter},
        attrs => $_[1],
    );
    $result;
}

sub dump {
    my $self = shift;
    my $res = $self->_search("", [qw(cn mail o telephoneNumber)]);

    foreach my $r ($res->entries) {
        my $ref = [];
        for(qw(cn mail o telephoneNumber)) {
            my $val = $r->get_value($_);
            if ($self->{opt}{convert}) {
                $val = str2ncr('UTF-8',$val);
            }
            push @$ref, $val;
        }
        push @ABOOK, $ref;
    }
    \@ABOOK;
}

sub DESTROY {
    # XXX under persistent envirement we must destroy
    # anything left in the memory, or thing goes corupt
    undef @ABOOK;
}

1;
