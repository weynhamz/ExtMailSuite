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
use DBI;

package Ext::Auth::MySQL;
use Exporter;
use Ext::Passwd;
use Ext::Utils qw(strsanity);
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
    $opt{dbname} = 'extmail_db' if not defined $opt{dbname};
    $opt{dbuser} = 'root' if not defined $opt{dbuser};
    $opt{dbpw} = 'password' if not defined $opt{dbpw};

    $self->{opt}=\%opt;

    my $connect = "DBI:mysql:database=$opt{dbname};host=$opt{host}";
    if ($opt{socket}) {
        $connect .= ";mysql_socket=$opt{socket}";
    }
    my $dbh = DBI->connect(
        $connect,$opt{dbuser}, $opt{dbpw}, {'RaiseError' => 1}
    );

    $self->{dbh} = $dbh;
    $self->{pwhandle} = Ext::Passwd->new(
        fallback_scheme => $opt{crypt_type} || 'crypt'
    ); # default type
}

# XXX meaningful for MySQL driver only
sub build_sql {
    my $self = shift;
    my $schema = $self->{opt}->{'schema'};
    my @params = @_;
    my $username = $self->{opt}->{'table_attr_username'};
    my $sql;

    # try to advoid SQL injection attack
    $params[0] = strsanity($params[0], 'eml');
    $params[1] = strsanity($params[1], 'eml') if defined $params[1];

    if ($schema eq 'vpopmail1') {
        my $domain = $self->{opt}->{'table_attr_domain'};
        $sql  = "SELECT * FROM $self->{opt}->{table} WHERE ";
        $sql .= "$username='$params[0]' AND $domain='$params[1]'";
    } elsif ($schema eq 'vpopmail2') {
        my $table_name = $params[1];
        $table_name =~ s![-\.]!_!g;
        $sql  = "SELECT * FROM $table_name WHERE ";
        $sql .= "$username='$params[0]'";
    } else {
        $sql = "SELECT * FROM $self->{opt}->{table} WHERE $username='$params[0]'";
    }
    $sql;
}

sub search {
    my $self = shift;
    my %res = ();
    my $username = $self->{opt}->{'table_attr_username'};
    my $SQL = $self->build_sql(@_);
    my $sth = $self->{dbh}->prepare($SQL);

    $sth->execute();
    while(my $r=$sth->fetchrow_hashref()) {
        $res{$r->{$username}} = $r; # feedback all rows
    };
    $sth->finish();
    \%res; # return a REF
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
    my $res;
    my $schema = $self->{opt}->{'schema'};

    if ($schema =~ m!^vpopmail!) {
        $username =~ /([^\@]+)@([^\@]+)/;
        $res = $self->search($1, $2);
        $username = $1; # XXX vpopmail
    } else {
        $res = $self->search($username); # XXX virtual
    }

    if(scalar keys %$res) {
        my $pwd = $res->{$username}->{$self->{opt}->{'table_attr_passwd'}};
        my $rv = -1; # flag to indicate authentication fail/ok/disabled
        my $handle = $self->{pwhandle}; # Ext::Passwd object

        # this step is a must, or null userpassword record will cause hole
        # that anonymous can step in the system
        return -1 unless($password && $pwd);

        if ($handle->verify($password, $pwd)) {
            if ($self->{opt}->{'table_attr_disablewebmail'} &&
                $res->{$username}->{$self->{opt}->{'table_attr_disablewebmail'}}) {
                return ($rv = 1);
            }
            if ($self->{opt}->{'table_attr_active'} &&
                !$res->{$username}->{$self->{opt}->{'table_attr_active'}}) {
                return ($rv = 2);
            }
            $self->{INFO} = $self->_fill_user_info($res->{$username});
            return 0;
        }else {
            return -1;
        }
    }

    -1; # default to fail
}

sub change_passwd {
    my $self = shift;
    my ($username, $old, $new) = @_;

    # verify old password
    if($self->auth($username, $old) == 0) {
        # encrypt new password and update it
        my $handle = $self->{pwhandle};
        my $type = $handle->{_scheme};

        my $crypted_new = $handle->encrypt($type, $new);

        my $table = $self->{opt}->{table};
        my $schema = $self->{opt}->{'schema'};

        if ($schema =~ /^vpopmail/) {
            $username =~ /([^\@]+)@([^\@]+)/;
            $username = $1; # XXX vpopmail style
            if ($schema eq 'vpopmail2') {
                $table = $2;
                $table =~ s![-\.]!_!g;
            }
        }
        my $attr_pw = $self->{opt}->{table_attr_passwd};
        my $clearpw = $self->{opt}->{table_attr_clearpw};
        my $attr_un = $self->{opt}->{table_attr_username};

        # use placeholder to advoid SQL injection attack
        my $SQL = "UPDATE $table set $attr_pw=?";
        if ($clearpw) {
            $SQL .= ",$clearpw=?";
        }
        $SQL .= " WHERE $attr_un=?";

        my $sth = $self->{dbh}->prepare($SQL);
        if ($clearpw) {
            $sth->execute($crypted_new, $new, $username);
        } else {
            $sth->execute($crypted_new, $username);
        }
        $sth->finish();
        return 1;
    }else {
        return 0;
    }
}

sub can_change_info {
    my $self = shift;
    my $username = shift;

    if ($self->{opt}->{table_attr_pwd_question} &&
        $self->{opt}->{table_attr_pwd_answer}) {
        return 1;
    }

    0;
}

sub get_user_info {
    my $self = shift;
    my $username = shift;

    if (not defined $self->{INFO}) {
        my $res = $self->search($username);
        if (scalar keys %$res) {
            $self->{INFO} = $self->_fill_user_info($res->{$username});
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

    if($self->auth($username, $oldpwd) == 0) {
        my $table = $self->{opt}->{table};
        my $attr_pwd_question = $self->{opt}->{table_attr_pwd_question};
        my $attr_pwd_answer = $self->{opt}->{table_attr_pwd_answer};
        my $SQL = "UPDATE $table set question=?,answer=? where username='$ENV{USERNAME}'";
        my $sth = $self->{dbh}->prepare($SQL);
        $sth->execute($opt{question}, $opt{answer});
        $sth->finish();
        $self->{INFO}->{PWD_QUESTION} = $opt{question};
        $self->{INFO}->{PWD_ANSWER} = $opt{answer};
        return $self->{dbh}->error if ($self->{dbh}->err);
        return 0;
    } else {
        return 'Old password verification failded';
    }
}

sub _fill_user_info {
    my $self = shift;
    my $opt = $self->{opt};
    my $entry = $_[0];
    my %info = ();

    # original infomation filling
    foreach my $key (keys %$entry) {
        $info{$key} = $entry->{$key};
    }

    # compatible with ExtMail ldap version
    $info{QUOTA} = $info{$opt->{'table_attr_quota'}};
    $info{NETDISKQUOTA} = $info{$opt->{'table_attr_netdiskquota'}};
    $info{HOME} = $info{$opt->{'table_attr_home'}}; # must exists
    $info{MAILDIR} = $info{$opt->{'table_attr_maildir'}} || "$info{HOME}/Maildir";

    if ($info{$opt->{'table_attr_disablenetdisk'}}) {
        $info{OPTIONS} = 'disablenetdisk';
    }
    if ($info{$opt->{'table_attr_disablepwdchange'}}) {
        $info{OPTIONS} = ($info{OPTIONS} ? $info{OPTIONS}.',' : '') .'disablepwdchange';
    }
    if ($self->can_change_info($ENV{USERNAME})) {
        $info{PWD_QUESTION} = $info{$opt->{'table_attr_pwd_question'}};
        $info{PWD_ANSWER} = $info{$opt->{'table_attr_pwd_answer'}};
    }
    \%info;
}

sub DESTORY {
    my $self = shift;
    $self->{dbh}->disconnect();
    undef $self;
}

1;
