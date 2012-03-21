# vim: set cindent expandtab ts=4 sw=4:
#
# Copyright (c) 1998-2005 Chi-Keung Ho. All rights reserved.
#
# This programe is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# ExtMan - web interface to manage virtual accounts
# $Id$
use strict;
use DBI;

package Ext::Mgr::MySQL;
use Exporter;
use Ext::Mgr;
use POSIX qw(strftime);
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::Mgr);
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
    $self->{psize} = $opt{psize} || 10;
    $self->{crypt_type} = $opt{crypt_type} || 'crypt'; # default type
}

sub search {
    my $self = shift;
    my $filter = $_[0];
    my %res = ();
    my $username = $self->{opt}->{'table_attr_username'};
    my $SQL = "SELECT * FROM $self->{opt}->{table} WHERE $username=?";
    my $sth = $self->{dbh}->prepare($SQL);

    $sth->execute($filter);
    while(my $r=$sth->fetchrow_hashref()) {
        $res{$r->{$username}} = $r; # feedback all rows
    };
    $sth->finish();
    \%res; # return a REF
}

sub auth {
    my $self = shift;
    my ($username, $password) = (@_);
    my $res = $self->search($username);

    if(scalar keys %$res) {
        my $pwd = $res->{$username}->{$self->{opt}->{'table_attr_passwd'}};

        # this step is a must, or null userpassword record will cause hole
        # that anonymous can step in the system
        return 0 unless($password && $pwd);

        if($self->verify($password, $pwd)) {
            $self->{INFO} = $self->_fill_user_info($res->{$username});
            return 1;
        }else {
            return 0;
        }
    }

    0; # default ?:)
}

sub change_passwd {
    my $self = shift;
    my ($username, $old, $new) = @_;

    # verify old password
    if($self->auth($username, $old)) {
        # encrypt new password and update it
        my $crypted_new = $self->encrypt($self->{crypt_type}, $new);
        my $table = $self->{opt}->{table};
        my $attr_pw = $self->{opt}->{table_attr_passwd};
        my $attr_un = $self->{opt}->{table_attr_username};

        my $SQL = "UPDATE $table set $attr_pw=? WHERE $attr_un=?";
        my $sth = $self->{dbh}->prepare($SQL);

        $sth->execute($crypted_new, $username);

        $sth->finish();

        return 1;
    }else {
        return 0;
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

    $info{TYPE} = $info{'type'};

    \%info;
}

sub get_entry {
    my $self = shift;
    my $sth = $self->{dbh}->prepare(shift);

    # use placeholder to advoid SQL injection
    if (@_) {
        $sth->execute(@_);
    } else {
        $sth->execute();
    }
    $sth->fetchrow_hashref(); # the first entry if multiplies return
}

sub get_entries {
    my $self = shift;
    my $sth = $self->{dbh}->prepare(shift);
    my $arr = [];

    # use placeholder to advoid SQL injection
    if (@_) {
        $sth->execute(@_);
    } else {
        $sth->execute();
    }
    while (my $r=$sth->fetchrow_hashref()) {
        push @$arr, $r;
    }
    $arr;
}

#==========================#
# extmailUser land handler #
#==========================#

sub by_domain {
    lc $a->{domain} cmp lc $b->{domain};
}

sub by_username {
    lc $a->{username} cmp lc $b->{username};
}

sub by_alias {
    lc $a->{address} cmp lc $b->{address};
}

sub by_manager {
    lc $a->{username} cmp lc $b->{username};
}

sub get_users_list {
    my $self = shift;
    my $SQL = "SELECT * FROM mailbox WHERE domain=?";
    my $rs = $self->get_entries($SQL, $_[0]);
    my $arr = []; # null ARRAY ref
    foreach my $ref (sort by_username @$rs) {
        push @$arr, {
            mail => $ref->{username},
            cn => $ref->{name},
            domain => $ref->{domain},
            uidnumber => $ref->{uidnumber},
            gidnumber => $ref->{gidnumber},
            uid => $ref->{uid},
            netdiskquota => $ref->{netdiskquota},
            active => $ref->{active} ? 1 : 0,
            quota => $ref->{quota},
            passwd => $ref->{password},
            clearpw => $ref->{clearpwd},
            mailhost => $ref->{mailhost},
            maildir => $ref->{maildir},
            homedir => $ref->{homedir},
            expire => $ref->{expiredate},
            create => $ref->{createdate},
            disablepwdchange => $ref->{disablepwdchange} ? 1 : 0,
            disablesmtpd => $ref->{disablesmtpd},
            disablesmtp => $ref->{disablesmtp},
            disablewebmail => $ref->{disablewebmail},
            disablenetdisk => $ref->{disablenetdisk},
            disableimap => $ref->{disableimap},
            disablepop3 => $ref->{disablepop3},
            question => $ref->{question},
            answer => $ref->{answer},
        }
    }
    scalar @$arr ? $arr : undef;
}

sub get_domains_list {
    my $self = shift;
    my $SQL = 'SELECT * FROM domain';
    my $rs = $self->get_entries($SQL);

    my $arr = [];
    foreach my $ref ( sort by_domain @$rs ) {
        push @$arr, {
            domain => $ref->{domain},
            create => $ref->{createdate},
            expire => $ref->{expiredate},
            description => $ref->{description},
            hashdirpath => $ref->{hashdirpath},
            maxalias => $ref->{maxalias},
            maxusers => $ref->{maxusers},
            maxquota => $ref->{maxquota},
            maxndquota => $ref->{maxnetdiskquota},
            transport => $ref->{transport},
            can_signup => $ref->{can_signup},
            default_quota => $ref->{default_quota},
            default_ndquota => $ref->{default_netdiskquota},
            default_expire => $ref->{default_expire},
            disablesmtpd => $ref->{disablesmtpd},
            disablesmtp => $ref->{disablesmtp},
            disablewebmail => $ref->{disablewebmail},
            disablenetdisk => $ref->{disablenetdisk},
            disableimap => $ref->{disableimap},
            disablepop3 => $ref->{disablepop3},
            active => $ref->{active} ? 1 : 0,
        }
    }
    scalar @$arr ? $arr : undef;
}

sub get_aliases_list {
    my $self = shift;
    my $SQL = "SELECT * FROM alias where domain=?";
    my $rs = $self->get_entries($SQL, $_[0]);
    my $arr = [];
    foreach my $ref ( sort by_alias @$rs ) {
        my $goto = $ref->{goto}; # XXX
        push @$arr, {
            alias => $ref->{address},
            domain => $ref->{domain},
            goto => ($goto =~ m!,!) ? [split(/,/,$goto)] : $goto,
            active => $ref->{active} ? 1 : 0,
            create => $ref->{createdate},
        }
    }
    scalar @$arr ? $arr : undef;
}

sub get_managers_list {
    my $self = shift;
    my $SQL = 'SELECT * FROM manager';
    my $rs = $self->get_entries($SQL);
    my $arr = [];

    foreach my $ref (sort by_manager @$rs) {
        push @$arr, {
            manager => $ref->{username},
            cn => $ref->{name},
            question => $ref->{question},
            answer => $ref->{answer},
            disablepwdchange => $ref->{disablepwdchange},
            create => $ref->{createdate},
            expire => $ref->{expiredate},
            type => $ref->{type},
            passwd => $ref->{password},
            active => $ref->{active} ? 1 : 0,
        }
    }
    scalar @$arr ? $arr : undef;
}

sub add_user {
    my $self = shift;
    my %opt = @_;
    my $db = $self->{dbh};

    my $ctype = $self->{crypt_type};
    my $passwd = $self->encrypt($ctype, $opt{passwd});
    my $clearpw = ($self->{opt}->{'table_attr_clearpw'} ? $opt{passwd} : '');
    my $active = $opt{active} ? 1 : 0;

    my $sth = $db->prepare("INSERT into mailbox(
            username,
            uid,
            password,
            clearpwd,
            name,
            mailhost,
            maildir,
            homedir,
            quota,
            netdiskquota,
            domain,
            uidnumber,
            gidnumber,
            createdate,
            expiredate,
            active,
            disablepwdchange,
            disablesmtpd,
            disablesmtp,
            disablewebmail,
            disablenetdisk,
            disableimap,
            disablepop3,
            question,
            answer) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");

    $sth->execute(
            "$opt{mail}",
            "$opt{uid}",
            "$passwd",
            "$clearpw",
            "$opt{cn}",
            "$opt{mailhost}",
            "$opt{maildir}",
            "$opt{homedir}",
            "$opt{quota}",
            "$opt{netdiskquota}",
            "$opt{domain}",
            "$opt{uidnumber}",
            "$opt{gidnumber}",
            "$opt{create}",
            "$opt{expire}",
            "$active",
            "$opt{disablepwdchange}",
            "$opt{disablesmtpd}",
            "$opt{disablesmtp}",
            "$opt{disablewebmail}",
            "$opt{disablenetdisk}",
            "$opt{disableimap}",
            "$opt{disablepop3}",
            "$opt{question}",
            "$opt{answer}",
            );

    if ($db->err) {
        return $db->errstr;
    } else {
        return 0;
    }
}

sub add_domain {
    my $self = shift;
    my %opt = @_;
    my $db = $self->{dbh};

    my $active = $opt{active} ? 1 : 0;
    my $sth = $db->prepare("INSERT into domain(
            domain,
            description,
            hashdirpath,
            maxalias,
            maxusers,
            maxquota,
            maxnetdiskquota,
            transport,
            can_signup,
            default_quota,
            default_netdiskquota,
            default_expire,
            disablesmtpd,
            disablesmtp,
            disablewebmail,
            disablenetdisk,
            disableimap,
            disablepop3,
            createdate,
            expiredate,
            active) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");

    $sth->execute(
            "$opt{domain}",
            "$opt{description}",
            "$opt{hashdirpath}",
            "$opt{maxalias}",
            "$opt{maxusers}",
            "$opt{maxquota}",
            "$opt{maxndquota}",
            "$opt{transport}",
            "$opt{can_signup}",
            "$opt{default_quota}",
            "$opt{default_ndquota}",
            "$opt{default_expire}",
            "$opt{disablesmtpd}",
            "$opt{disablesmtp}",
            "$opt{disablewebmail}",
            "$opt{disablenetdisk}",
            "$opt{disableimap}",
            "$opt{disablepop3}",
            "$opt{create}",
            "$opt{expire}",
            "$active",
            );

    if ($db->err) {
        return $db->errstr;
    } else {
        return 0;
    }
}

sub add_alias {
    my $self = shift;
    my %opt = @_;
    my $db = $self->{dbh};

    my $active = $opt{active} ? 1 : 0;
    my $goto = join(',', split(/\n/, $opt{goto}));

    my $sth = $db->prepare("INSERT into alias(
            address,
            goto,
            domain,
            createdate,
            active) VALUES(?,?,?,?,?)");
    $sth->execute(
            "$opt{alias}",
            "$goto",
            "$opt{domain}",
            "$opt{create}",
            "$active",
            );

    if ($db->err) {
        return $db->errstr;
    } else {
        return 0;
    }
}

sub add_manager {
    my $self = shift;
    my %opt = @_;
    my $db = $self->{dbh};

    my $ctype = $self->{crypt_type};
    my $passwd = $self->encrypt($ctype, $opt{passwd});

    my $active = $opt{active} ? 1 : 0;
    my $sth = $db->prepare("INSERT into manager(
                username,
                password,
                type,
                uid,
                name,
                question,
                answer,
                disablepwdchange,
                createdate,
                expiredate,
                active) VALUES(?,?,?,?,?,?,?,?,?,?,?)");

    $sth->execute(
                "$opt{manager}",
                "$passwd",
                "$opt{type}",
                '',
                "$opt{cn}",
                "$opt{question}",
                "$opt{answer}",
                "$opt{disablepwdchange}",
                "$opt{create}",
                "$opt{expire}",
                "$active",
                );

    return $db->errstr if ($db->err);

    foreach my $vd (@{$opt{domain}}) {
        my $sth = $db->prepare("INSERT into domain_manager(
                username,
                domain,
                createdate,
                active) VALUES(?,?,?,?)");
        $sth->execute(
                "$opt{manager}",
                "$vd",
                "$opt{create}",
                '1',
                );
        return $db->errstr if ($db->err);
    }
    0; # success
}

sub delete_user {
    my $self = shift;
    my $user = $_[0];
    my $db = $self->{dbh};

    my $sth = $db->prepare("DELETE FROM mailbox where username=?");
    $sth->execute($user);

    if ($db->err) {
        return $db->errstr;
    } else {
        return 0;
    }
}

sub delete_alias {
    my $self = shift;
    my $db = $self->{dbh};

    my $sth = $db->prepare("DELETE FROM alias where address=?");
    $sth->execute($_[0]);

    if ($db->err) {
        return $db->errstr;
    } else {
        return 0;
    }
}

sub delete_domain {
    my $self = shift;
    my $db = $self->{dbh};

    my $sth = $db->prepare("DELETE FROM domain where domain=?");
    $sth->execute($_[0]);

    if ($db->err) {
        return $db->errstr;
    } else {
        return 0;
    }
}

sub delete_manager {
    my $self = shift;
    my $db = $self->{dbh};

    my $sth = $db->prepare("DELETE FROM manager WHERE username=?");
    $sth->execute($_[0]);

    return $db->errstr if ($db->err);

    $sth = $db->prepare("DELETE FROM domain_manager WHERE username=?");
    $sth->execute($_[0]);

    if ($db->err) {
        return $db->errstr;
    } else {
        return 0;
    }
}

sub modify_user {
    my $self = shift;
    my %opt = @_;
    my $db = $self->{dbh};
    my $active = $opt{active} ? 1 : 0;

    if ($opt{passwd}) {
        my $ctype = $self->{crypt_type};
        my $passwd = $self->encrypt($ctype, $opt{passwd});
        my $SQL = "UPDATE mailbox set password=?";

        if ($self->{opt}->{'table_attr_clearpw'}) {
            $SQL .= ",clearpwd=?";
        }
        $SQL .= " WHERE username=?";
        my $sth = $db->prepare($SQL);

        if ($self->{opt}->{'table_attr_clearpw'}) {
            $sth->execute($passwd, $opt{passwd}, $opt{user});
        } else {
            $sth->execute($passwd, $opt{user});
        }

        return $db->errstr if ($db->err);
    }

    my $sth = $db->prepare("UPDATE mailbox set
            name=?,
            quota=?,
            netdiskquota=?,
            uidnumber=?,
            gidnumber=?,
            expiredate=?,
            active=?,
            disablepwdchange=?,
            disablesmtpd=?,
            disablesmtp=?,
            disablewebmail=?,
            disablenetdisk=?,
            disableimap=?,
            disablepop3=?,
            question=?,
            answer=? WHERE username=?");

    $sth->execute(
            "$opt{cn}",
            "$opt{quota}",
            "$opt{netdiskquota}",
            "$opt{uidnumber}",
            "$opt{gidnumber}",
            "$opt{expire}",
            "$active",
            "$opt{disablepwdchange}",
            "$opt{disablesmtpd}",
            "$opt{disablesmtp}",
            "$opt{disablewebmail}",
            "$opt{disablenetdisk}",
            "$opt{disableimap}",
            "$opt{disablepop3}",
            "$opt{question}",
            "$opt{answer}",
            "$opt{user}",
            );

    if ($db->err) {
        return $db->errstr;
    } else {
        return 0;
    }
}

sub modify_alias {
    my $self = shift;
    my %opt = @_;
    my $db = $self->{dbh};

    my $active = $opt{active} ? 1 : 0;
    my $goto = join(',', split(/\n/, $opt{goto}));

    my $sth = $db->prepare("UPDATE alias set goto=?,active=? WHERE address=?");
    $sth->execute($goto, $active, $opt{alias});

    if ($db->err) {
        return $db->errstr;
    } else {
        return 0;
    }
}

sub modify_domain {
    my $self = shift;
    my %opt = @_;
    my $db = $self->{dbh};

    my $active = $opt{active} ? 1 : 0;
    my $sth = $db->prepare("UPDATE domain set
            maxusers=?,
            maxalias=?,
            maxquota=?,
            maxnetdiskquota=?,
            transport=?,
            can_signup=?,
            default_quota=?,
            default_netdiskquota=?,
            default_expire=?,
            disablesmtpd=?,
            disablesmtp=?,
            disablewebmail=?,
            disablenetdisk=?,
            disableimap=?,
            disablepop3=?,
            expiredate=?,
            active=?,
            description=? WHERE domain=?");

    $sth->execute(
            "$opt{maxusers}",
            "$opt{maxalias}",
            "$opt{maxquota}",
            "$opt{maxndquota}",
            "$opt{transport}",
            "$opt{can_signup}",
            "$opt{default_quota}",
            "$opt{default_ndquota}",
            "$opt{default_expire}",
            "$opt{disablesmtpd}",
            "$opt{disablesmtp}",
            "$opt{disablewebmail}",
            "$opt{disablenetdisk}",
            "$opt{disableimap}",
            "$opt{disablepop3}",
            "$opt{expire}",
            "$active",
            "$opt{description}",
            "$opt{domain}",
            );

    if ($db->err) {
        return $db->errstr;
    } else {
        return 0;
    }
}

sub modify_manager {
    my $self = shift;
    my %opt = @_;
    my $db = $self->{dbh};
    my $time = strftime("%Y-%m-%d %H:%M:%S", localtime);

    # update password if set
    if ($opt{passwd}) {
        my $ctype = $self->{crypt_type};
        my $passwd = $self->encrypt($ctype, $opt{passwd});
        my $sth = $db->prepare("UPDATE manager set password=? WHERE username=?");
        $sth->execute($passwd, $opt{manager});
        return $db->errstr if ($db->err);
    }

    # update main information
    my $active = $opt{active} ? 1 : 0;
    my $sth = $db->prepare("UPDATE manager set
            name=?,
            question=?,
            answer=?,
            disablepwdchange=?,
            expiredate=?,
            active=? WHERE username=?");

    $sth->execute(
            "$opt{cn}",
            "$opt{question}",
            "$opt{answer}",
            "$opt{disablepwdchange}",
            "$opt{expire}",
            "$active",
            "$opt{manager}",
            );

    return $db->errstr if ($db->err);

    # delete old owndomain, to simplify procedure
    $sth = $db->prepare("DELETE FROM domain_manager where username=?");
    $sth->execute($opt{manager});
    return $db->errstr if ($db->err);

    # add new owndomain
    foreach my $vd (@{$opt{domain}}) {
        $sth = $db->prepare("INSERT into domain_manager
            (username,
            domain,
            createdate,
            active) VALUES(?,?,?,?)");

        $sth->execute(
            "$opt{manager}",
            "$vd",
            "$time",
            '1',
            );
        # ignore errstr even with some err, sucks
    }

    if ($db->err) {
        return $db->errstr;
    } else {
        return 0;
    }
}

sub get_user_info {
    my $self = shift;
    my $user = $_[0];
    my $domain = $user;

    $domain =~ s#^([^\@]+)@##;
    my $SQL = "SELECT * FROM mailbox where username=?";
    my $ref = $self->get_entry($SQL, $user);
    return undef unless ($ref);
    return {
        mail => $ref->{username},
        cn => $ref->{name},
        domain => $ref->{domain},
        uidnumber => $ref->{uidnumber},
        gidnumber => $ref->{gidnumber},
        uid => $ref->{uid},
        netdiskquota => $ref->{netdiskquota},
        active => $ref->{active} ? 1 : 0,
        quota => $ref->{quota},
        passwd => $ref->{password},
        clearpw => $ref->{clearpwd},
        mailhost => $ref->{mailhost},
        maildir => $ref->{maildir},
        homedir => $ref->{homedir},
        expire => $ref->{expiredate},
        create => $ref->{createdate},
        disablepwdchange => $ref->{disablepwdchange} ? 1 : 0,
        disablesmtpd => $ref->{disablesmtpd},
        disablesmtp => $ref->{disablesmtp},
        disablewebmail => $ref->{disablewebmail},
        disablenetdisk => $ref->{disablenetdisk},
        disableimap => $ref->{disableimap},
        disablepop3 => $ref->{disablepop3},
        question => $ref->{question},
        answer => $ref->{answer},
    }
}

sub get_domain_info {
    my $self = shift;
    my $SQL = "SELECT * FROM domain WHERE domain=?";
    my $ref = $self->get_entry($SQL, $_[0]);
    return undef unless ($ref);
    return {
        domain => $ref->{domain},
        create => $ref->{createdate},
        expire => $ref->{expiredate},
        description => $ref->{description},
        hashdirpath => $ref->{hashdirpath},
        maxalias => $ref->{maxalias},
        maxusers => $ref->{maxusers},
        maxquota => $ref->{maxquota},
        maxndquota => $ref->{maxnetdiskquota},
        transport => $ref->{transport},
        can_signup => $ref->{can_signup},
        default_quota => $ref->{default_quota},
        default_ndquota => $ref->{default_netdiskquota},
        default_expire => $ref->{default_expire},
        disablesmtpd => $ref->{disablesmtpd},
        disablesmtp => $ref->{disablesmtp},
        disablewebmail => $ref->{disablewebmail},
        disablenetdisk => $ref->{disablenetdisk},
        disableimap => $ref->{disableimap},
        disablepop3 => $ref->{disablepop3},
        active => $ref->{active} ? 1 : 0,
    }
}

sub get_alias_info {
    my $self = shift;
    my $SQL = "SELECT * FROM alias WHERE address=?";
    my $ref = $self->get_entry($SQL, $_[0]);
    return undef unless ($ref);
    my $goto = $ref->{goto};

    return {
        alias => $ref->{address},
        domain => $ref->{domain},
        goto => ($goto =~ m!,!) ? [split(/,/,$goto)] : $goto,
        active => $ref->{active} ? 1 : 0,
        create => $ref->{createdate},
    }
}

sub get_manager_info {
    my $self = shift;
    my $SQL = "SELECT * FROM manager where username=?";
    my $ref = $self->get_entry($SQL, $_[0]);

    return undef unless ($ref);
    $SQL = "SELECT domain from domain_manager WHERE username=?";
    my $ds = $self->get_entries($SQL, $_[0]);
    my $arr = []; # convert to array ref
    foreach (@$ds) {
        push @$arr, $_->{domain};
    }

    return {
        manager => $ref->{username},
        cn => $ref->{name},
        question => $ref->{question},
        answer => $ref->{answer},
        disablepwdchange => $ref->{disablepwdchange} ? 1 : 0,
        create => $ref->{createdate},
        expire => $ref->{expiredate},
        type => $ref->{type},
        passwd => $ref->{password},
        active => $ref->{active} ? 1 : 0,
        domain => $arr,
    }
}

#---------------------------------#
# search and sort, paging handler #
#---------------------------------#

# method and parameters
#
# $self, %opt => (
#   domain => $domain,
#   page => $page,
#   filter => $filter,        # NULL means retreive all
#   filter_type => $type      # mail or name(cn) is ok
#   );
sub user_paging {
    my $self = shift;
    my %opt = @_;

    my $domain = $opt{domain};
    my $page = $opt{page} || 0;
    my $filter = $opt{filter};
    my $filter_type = $opt{filter_type};

    my ($has_prev, $has_next) = (1, 0);
    my $psize = $self->{psize}; # page size
    my $begin = $page*$psize;

    # all un-filltered result
    my $all = $self->get_users_list($domain) || [];
    # array to contain filltered result
    my $arr = [];

    delete $self->{_ext_info};

    for(my $i=0; $i<scalar @$all; $i++) {
        my $e = $all->[$i];
        if ($filter) {
            next unless $e->{$filter_type} =~ /\Q$filter\E/i;
        }
        push @$arr, $e;
    }

    # the result array
    my $res = [];
    for(my $i=$begin;$i<scalar @$arr;$i++) {
        push @$res, $arr->[$i];
        last if (scalar @$res>= $psize);
    }

    if (scalar @$res == $psize && $begin + $psize < scalar @$arr) {
        $has_next =1;
    }
    if ($page <= 0) { $has_prev = 0 };

    # XXX ext_info
    $self->{_ext_info} = {
        total => scalar @$all,
        match => scalar @$arr,
        pages => $self->pages(scalar @$arr, $psize),
    };

    return ($res, $has_prev, $has_next);
}

#
# $self, %opt => (
#   domain => $domain,
#   page => $page,
#   filter => $filter,    # NULL means all
# )
sub alias_paging {
    my $self = shift;
    my %opt = @_;

    my $domain = $opt{domain};
    my $page = $opt{page} || 0;
    my $filter = $opt{filter};
    my ($has_prev, $has_next) = (1, 0);

    my $psize = $self->{psize}; # page size
    my $begin = $page*$psize;

    # all un-filltered result
    my $all = $self->get_aliases_list($domain) || [];
    # array to contain filltered result
    my $arr = [];

    delete $self->{_ext_info};

    for(my $i=0; $i<scalar @$all; $i++) {
        my $e = $all->[$i];
        if ($filter) {
            next unless ($e->{alias} =~ /\Q$filter\E/i ||
               $e->{goto} =~ /\Q$filter\E/i);
        }
        push @$arr, $e;
    }

    my $res = [];
    for(my $i=$begin; $i<scalar @$arr; $i++) {
        push @$res, $arr->[$i];
        last if (scalar @$res>= $psize);
    }

    if (scalar @$res == $psize && $begin + $psize < scalar @$arr) {
        $has_next =1;
    }
    if ($page <= 0) { $has_prev = 0 };

    # XXX ext_info
    $self->{_ext_info} = {
        total => scalar @$all,
        match => scalar @$arr,
        pages => $self->pages(scalar @$arr, $psize),
    };

    return ($res, $has_prev, $has_next);
}

#
# $self, %opt => (
#   filter => $filter,          # NULL means all
#   filter_type => $filter_type # admin or postmaster
# )
#
# $self->ext_info() - return extend info for counting
sub manager_paging {
    my $self = shift;
    my %opt = @_;

    my $page = $opt{page} || 0;
    my $filter = $opt{filter};
    my $filter_type = $opt{filter_type};
    my ($has_prev, $has_next) = (1, 0);

    my $psize = $self->{psize}; # page size
    my $begin = $page*$psize;

    # all un-filltered result
    my $all = $self->get_managers_list || [];
    # array to contain filltered result
    my $arr = [];

    delete $self->{_ext_info};

    for(my $i=0; $i<scalar @$all; $i++) {
        my $e = $all->[$i];
        if ($filter) {
            next unless ($e->{manager} =~ /\Q$filter\E/i ||
                $e->{cn} =~ /\Q$filter\E/i) and
                $e->{type} eq $filter_type;
        }
        push @$arr, $e;
    }

    my $res = [];
    for(my $i=$begin; $i<scalar @$arr;$i++) {
        push @$res, $arr->[$i];
        last if (scalar @$res>= $psize);
    }

    if (scalar @$res == $psize && $begin + $psize < scalar @$arr) {
        $has_next =1;
    }
    if ($page <= 0) { $has_prev = 0 };

    # XXX ext_info
    $self->{_ext_info} = {
        total => scalar @$all,
        match => scalar @$arr,
        pages => $self->pages(scalar @$arr, $psize),
    };

    return ($res, $has_prev, $has_next);
}

sub ext_info {
    my $self = shift;
    return $self->{_ext_info};
}

sub domain_paging {
    die "use Ext::MgrApp::domain_paging() instead\n";
}

sub DESTORY {
    my $self = shift;
    $self->{dbh}->disconnect();
    undef $self;
}
1;
