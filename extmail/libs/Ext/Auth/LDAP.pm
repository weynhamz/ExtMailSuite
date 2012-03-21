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
use strict;
use Net::LDAP;

package Ext::Auth::LDAP;
use Exporter;
use Ext::Passwd;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(auth);

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
    $opt{base} = 'dc=extmail.org' if not defined $opt{base};
    $opt{rootdn} = 'cn=Manager,dc=extmail.org'
        if not defined $opt{rootdn};
    $opt{rootpw} = 'rootpw' if not defined $opt{rootpw};
    $opt{bind} = 0 if not defined $opt{bind};
    $opt{filter} = 'mail=*' if not defined $opt{filter};

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

    $self->{pwhandle} = Ext::Passwd->new(
        fallback_scheme => $opt{crypt_type} || 'crypt'
    );
    $self->{ldap} = $ldap;
}

sub search {
    my $self = shift;
    my $result = $self->{ldap}->search(
        base => $_[2] || $self->{opt}->{base},
        scope => "sub",
        filter => "$_[0]" || $self->{opt}->{filter},
        attrs => $_[1]
    );
    $result;
}

# return value redifination since 0.24-RC2
#
# $rv =  0  LOGIN_OK
# $rv = -1  LOGIN_FAIL
# $rv =  1  LOGIN_DISABLED
# $rv =  2  LOGIN_DEACTIVE
# $rv =  3  LOGIN_EXPIRED
sub auth {
    my $self = shift;
    my ($username, $password) = (@_);

    # here we don't use $self, for it init LDAP without bind, if the
    # auth operation can receive userPassword field without bind, then
    # we can simplly use $self->search not create a new obj.
    #
    # Caution: filter should advoid special quoted chars. if you must
    # do it, prepend \\\, eg: \\\@domain.tld
    my $res = $self->search("mail=$username", undef, undef);

    if($res->entry(0)) {
        my $attr_pwd = $self->{opt}->{'ldif_attr_passwd'};
        my $pwd = $res->entry(0)->get_value($attr_pwd);
        my $rv = -1; # flag to indicate authentication ok/fail
        my $handle = $self->{pwhandle}; # Ext::Passwd object

        # this step is a must, or null userpassword record will cause hole
        # that anonymous can step in the system
        return -1 unless($password && $pwd);

        if($handle->verify($password, $pwd)) {
            if ($self->{opt}->{'ldif_attr_disablewebmail'} &&
                $res->entry(0)->get_value($self->{opt}->{'ldif_attr_disablewebmail'})) {
                return ($rv = 1);
            }
            if ($self->{opt}->{'ldif_attr_active'} &&
                !$res->entry(0)->get_value($self->{opt}->{'ldif_attr_active'})) {
                return ($rv = 2);
            }
            $self->{INFO} = $self->_fill_user_info($res->entry(0));
            return 0;
        }else {
            return -1;
        }
    }

    -1; # default ?:)
}

sub change_passwd {
    my $self = shift;
    my ($username, $old, $new) = @_;

    if($self->auth($username, $old) == 0) {
        my $handle = $self->{pwhandle};
        my $type = $handle->{_scheme};

        my $cnew = $handle->encrypt($type, $new);

        # according to RFC2307/2256 must prepend password type
        if ($type eq 'MD5' and substr($cnew, 0, 3) eq '$1$') {
            $cnew = '{CRYPT}'.$cnew;
        }
        if ($type eq 'CRYPT') {
            $cnew = '{CRYPT}'.$cnew;
        }
        my $res = $self->search("mail=$username", undef, undef);
        my $pwa = [ $self->{opt}->{'ldif_attr_passwd'} => $cnew ];

        if ($self->{opt}->{'ldif_attr_clearpw'}) {
            # fillin clear password if the attribute defined
            push @$pwa, ($self->{opt}->{'ldif_attr_clearpw'} => $new);
        }

        my $mesg = $self->{ldap}->modify(
            $res->entry(0)->dn,
            replace => $pwa,
        );
        return 0 if($mesg->code); # error while modifying
        return 1;
    }else {
        return 0;
    }
}

sub can_change_info {
    my $self = shift;
    my $username = shift;

    if ($self->{opt}->{'ldif_attr_pwd_question'} &&
        $self->{opt}->{'ldif_attr_pwd_answer'}) {
        return 1;
    }
    0;
}

sub get_user_info {
    my $self = shift;
    my $username = shift;

    if (not defined $self->{INFO}) {
        my $res = $self->search("mail=$username", undef, undef);
        if ($res->entry(0)) {
            $self->{INFO} = $self->_fill_user_info($res->entry(0));
            return {
                question => $self->{INFO}->{PWD_QUESTION},
                answer => $self->{INFO}->{PWD_ANSWER},
            };
        }
    } else {
        return {
            question => $self->{INFO}->{PWD_QUESTION},
            answer => $self->{INFO}->{PWD_ANSWER},
        };
    }
}

sub change_info {
    my $self = shift;
    my %opt = @_;
    my $username = $opt{username};
    my $oldpwd = $opt{oldpwd};
    my $ldap = $self->{ldap};

    if($self->auth($username, $oldpwd) == 0) {
        my $res = $self->search("mail=$username", undef, undef);
        my $dn = $res->entry(0)->dn;
        my $mesg = '';
        if (defined $opt{question} && defined $opt{answer}) {
            if (!$opt{question} || !$opt{answer}) {
                # defined but one of them are empty, we must delete
                # the ldap attributes
                $mesg = $self->{ldap}->modify($dn,
                    delete => ['question', 'answer']
                );
                delete $self->{INFO}->{PWD_QUESTION};
                delete $self->{INFO}->{PWD_ANSWER};
            } else {
                # both not empty, modify it
                $mesg = $self->{ldap}->modify($dn,
                    replace => [
                        question => $opt{question},
                        answer => $opt{answer},
                    ]
                );
                $self->{INFO}->{PWD_QUESTION} = $opt{question};
                $self->{INFO}->{PWD_ANSWER} = $opt{answer};
            }
            return $mesg->error if ($mesg->code);
            return 0;
        } else {
            return 'Question or answer not supplied';
        }
    } else {
        return 'Old password verification failed!';
    }
}

sub _fill_user_info {
    my $self = shift;
    my $opt = $self->{opt};
    my $entry = $_[0];
    my %info = ();

    foreach my $attr ($entry->attributes) {
        $info{$attr} = join(",", $entry->get_value($attr));
    }

    $info{QUOTA} = $info{$opt->{'ldif_attr_quota'}};
    $info{NETDISKQUOTA} = $info{$opt->{'ldif_attr_netdiskquota'}};
    $info{HOME} = $info{$opt->{'ldif_attr_home'}}; # must exist
    $info{MAILDIR} = $info{$opt->{'ldif_attr_maildir'}} || "$info{HOME}/Maildir";

    if ($info{$opt->{'ldif_attr_disablenetdisk'}}) {
        $info{OPTIONS} = 'disablenetdisk';
    }
    if ($info{$opt->{'ldif_attr_disablepwdchange'}}) {
        $info{OPTIONS} = ($info{OPTIONS} ? $info{OPTIONS}.',' : '') .'disablepwdchange';
    }
    if ($self->can_change_info($ENV{USERNAME})) {
        $info{PWD_QUESTION} = $info{$opt->{'ldif_attr_pwd_question'}};
        $info{PWD_ANSWER} = $info{$opt->{'ldif_attr_pwd_answer'}};
    }
    \%info;
}

1;
