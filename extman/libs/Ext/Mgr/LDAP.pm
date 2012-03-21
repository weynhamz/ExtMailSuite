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
use Net::LDAP;

package Ext::Mgr::LDAP;
use Exporter;
use Ext::Mgr;
use vars qw(@ISA @EXPORT $BASE);
@ISA = qw(Exporter Ext::Mgr);
@EXPORT = qw(auth);
$BASE = 'extmail.org'; # default base

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

    $BASE = $opt{base}; # initialize global BASE varible

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

    $self->{psize} = $opt{psize} || 10;
    $self->{crypt_type} = $opt{crypt_type} || 'crypt';
    $self->{ldap} = $ldap;
}

sub encrypt {
    my $self = shift;
    my $type = uc shift;
    my $pass = shift;

    my $password = $self->SUPER::encrypt($type, $pass);
    if ($type eq 'CRYPT') {
        return '{CRYPT}'.$password;
    }
    $password;
}

# search($filter, $base, $attrs)
sub search {
    my $self = shift;
    my $result = $self->{ldap}->search(
        base => $_[1] || $self->{opt}->{base},
        scope => "sub",
        filter => "$_[0]" || $self->{opt}->{filter},
        attrs => $_[2]
    );
    $result;
}

sub auth {
    my $self = shift;
    my ($username, $password) = (@_);

    # here we don't use $self, for it init LDAP without bind, if the
    # auth operation can receive userPassword field without bind, then
    # we can simplly use $self->search not create a new obj.
    #
    # Caution: filter should advoid special quoted chars. if you must
    # do it, prepend \\\, eg: \\\@domain.tld
    my $res = $self->search("(&(mail=$username)(objectclass=extmailManager))", undef, undef);

    if($res->entry(0)) {
        my $attr_pwd = $self->{opt}->{'ldif_attr_passwd'};
        my $pwd = $res->entry(0)->get_value($attr_pwd);

        # this step is a must, or null userpassword record will cause hole
        # that anonymous can step in the system
        return 0 unless($password && $pwd);

        if($self->verify($password, $pwd)) {
            $self->{INFO} = $self->_fill_user_info($res->entry(0));
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
    my $ctype = $self->{crypt_type} || 'crypt';

    if($self->auth($username, $old)) {
        my $new = $self->encrypt($ctype, $new);
        my $res = $self->search("mail=$username", undef, undef);

        my $mesg = $self->{ldap}->modify(
            $res->entry(0)->dn,
            replace => {
                $self->{opt}->{'ldif_attr_passwd'} => $new,
            },
        );
        return 0 if($mesg->code); # error while modifying
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

    foreach my $attr ($entry->attributes) {
        $info{$attr} = join(",", $entry->get_value($attr));
    }

    $info{TYPE} = $info{'managerType'};

    \%info;
}

sub get_entry {
    my $self = shift;
    my ($filter, $base) = @_;
    my $entry;

    my $res = $self->search($filter, $base, undef);
    if ($res->entries) {
        my %hash = ();
        my $e = $res->entry(0);
        for my $attr ($e->attributes) {
            my $val = [$e->get_value($attr)];
            if (scalar @$val > 1) {
                $hash{$attr} = $val;
            }else {
                $hash{$attr} = $val->[0];
            }
        }
        return \%hash;
    }else {
        return undef;
    }
}

sub get_entries {
    my $self = shift;
    my ($filter, $base) = @_;
    my @entries;

    my $res = $self->search($filter, $base, undef);
    while (my $e = $res->shift_entry()) {
        my %hash = ();
        foreach my $attr ($e->attributes) {
            my $val = [$e->get_value($attr)];
            if (scalar @$val >1) {
                # save ARRAY ref
                $hash{$attr} = $val;
            }else {
                $hash{$attr} = $val->[0];
            }
        }
        push @entries, \%hash;
    }
    \@entries;
}

#==========================#
# extmailUser land handler #
#==========================#

sub by_domain {
    lc $a->{virtualDomain} cmp lc $b->{virtualDomain};
}

sub by_username {
    lc $a->{mail} cmp lc $b->{mail};
}

sub by_alias {
    lc $a->{mailLocalAddress} cmp lc $b->{mailLocalAddress};
}

sub by_manager {
    lc $a->{mail} cmp lc $b->{mail};
}

sub get_users_list {
    my $self = shift;
    my $filter = "(&(objectclass=extmailUser)(virtualdomain=$_[0]))";
    my $base = "o=extmailAccount,$BASE";

    my $rs = $self->get_entries($filter, $base);
    my $arr = []; # null ARRAY ref
    foreach my $ref ( sort by_username @$rs ) {
        push @$arr, {
            mail => $ref->{mail},
            cn => $ref->{cn},
            domain => $ref->{virtualDomain},
            uidnumber => $ref->{uidNumber},
            gidnumber => $ref->{gidNumber},
            uid => $ref->{uid},
            netdiskquota => $ref->{netdiskQuota},
            active => $ref->{active} ? 1 : 0,
            quota => $ref->{mailQuota},
            passwd => $ref->{userPassword},
            clearpw => $ref->{clearPassword},
            mailhost => $ref->{mailHost},
            maildir => $ref->{mailMessageStore},
            homedir => $ref->{homeDirectory},
            expire => $ref->{expireDate},
            create => $ref->{createDate},
            disablepwdchange => $ref->{disablePasswdChange},
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
    my $filter = '(objectclass=extmailDomain)';
    my $base = "o=extmailAccount,$BASE";

    my $rs = $self->get_entries($filter, $base);
    my $arr = []; # null ARRAY ref
    foreach my $ref ( sort by_domain @$rs ) {
        push @$arr, {
            domain => $ref->{virtualDomain},
            create => $ref->{createDate},
            expire => $ref->{expireDate},
            hashdirpath => $ref->{hashDirPath},
            description => $ref->{description},
            maxalias => $ref->{domainMaxAlias},
            maxusers => $ref->{domainMaxUsers},
            maxquota => $ref->{domainMaxQuota},
            maxndquota => $ref->{domainMaxNetStore},
            transport => $ref->{Transport},
            can_signup => $ref->{canSignup},
            default_quota => $ref->{defaultQuota},
            default_ndquota => $ref->{defaultNetStore},
            default_expire => $ref->{defaultExpire},
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
    my $filter = "(&(objectclass=extmailAlias)(virtualdomain=$_[0]))";
    my $base = "o=extmailAlias,$BASE";

    my $rs = $self->get_entries($filter, $base);
    my $arr = []; # null ARRAY ref
    foreach my $ref ( sort by_alias @$rs ) {
        push @$arr, {
            alias => $ref->{mailLocalAddress},
            domain => $ref->{virtualDomain},
            goto => $ref->{mail},
            active => $ref->{active} ? 1 : 0,
            create => $ref->{createDate},
        }
    }
    scalar @$arr ? $arr : undef;
}

sub get_managers_list {
    my $self = shift;
    my $filter = "(objectclass=extmailManager)";
    my $base = "o=extmailManager,$BASE";

    my $rs = $self->get_entries($filter, $base);
    my $arr = [];
    foreach my $ref ( sort by_manager @$rs ) {
        push @$arr, {
            manager => $ref->{mail},
            cn => $ref->{cn},
            question => $ref->{question},
            answer => $ref->{answer},
            disablepwdchange => $ref->{disablePasswdChange},
            create => $ref->{createDate},
            expire => $ref->{expireDate},
            type => $ref->{managerType},
            passwd => $ref->{userPassword},
            active => $ref->{active} ? 1 : 0,
            domain => (ref $ref->{virtualDomain} ? $ref->{virtualDomain} : [$ref->{virtualDomain}]),
        }
    }
    scalar @$arr ? $arr : undef;
}

sub add_user {
    my $self = shift;
    my %opt = @_;

    my $ctype = $self->{crypt_type};
    my $base = "o=extmailAccount,$BASE";
    my $dn = "mail=$opt{mail},virtualDomain=$opt{domain},$base";

    my $attr = [
        mail => $opt{mail},
        cn => $opt{cn},
        virtualDomain => $opt{domain},
        uidNumber => $opt{uidnumber} || '1000',
        gidNumber => $opt{gidnumber} || '1000',
        uid => $opt{uid},
        objectClass => ['top', 'uidObject', 'extmailUser'],
        netdiskQuota => $opt{netdiskquota},
        active => $opt{active} ? 1 : 0,
        mailQuota => $opt{quota},
        userPassword => $self->encrypt($ctype, $opt{passwd}),
        ];

    push @$attr, (clearPassword => $opt{passwd}) if $self->{opt}->{'ldif_attr_clearpw'};
    push @$attr, (mailHost => $opt{mailhost}) if ($opt{mailhost});

    push @$attr, (
        mailMessageStore => $opt{maildir},
        homeDirectory => $opt{homedir},
        expireDate => $opt{expire},
        createDate => $opt{create},
        disablePasswdChange => $opt{disablepwdchange},
        disablesmtpd => $opt{disablesmtpd},
        disablesmtp => $opt{disablesmtp},
        disablewebmail => $opt{disablewebmail},
        disablenetdisk => $opt{disablenetdisk},
        disableimap => $opt{disableimap},
        disablepop3 => $opt{disablepop3},
    );

    if ($opt{question} && $opt{answer}) {
        push @$attr, question => $opt{question};
        push @$attr, answer => $opt{answer};
    }

    my $mesg = $self->{ldap}->add($dn, attr => $attr);
    if ($mesg->code) {
        return $mesg->error;
    }else {
        return 0;
    }
}

sub add_domain {
    my $self = shift;
    my %opt = @_;

    my $base = "o=extmailAccount,$BASE";
    my $dn = "virtualDomain=$opt{domain},$base";

    my $attr = [
        virtualDomain => $opt{domain},
        createDate => $opt{create},
        expireDate => $opt{expire},
        description => $opt{description},
        domainMaxAlias => $opt{maxalias},
        domainMaxUsers => $opt{maxusers},
        domainMaxQuota => $opt{maxquota},
        domainMaxNetStore => $opt{maxndquota},
        Transport => $opt{transport},
        canSignup => $opt{can_signup} ? 1 : 0,
        defaultQuota => $opt{default_quota},
        defaultNetStore => $opt{default_ndquota},
        defaultExpire => $opt{default_expire},
        disablesmtpd => $opt{disablesmtpd},
        disablesmtp => $opt{disablesmtp},
        disablewebmail => $opt{disablewebmail},
        disablenetdisk => $opt{disablenetdisk},
        disableimap => $opt{disableimap},
        disablepop3 => $opt{disablepop3},
        active => $opt{active} ? 1 : 0,
        objectClass => ['top', 'extmailDomain'],
        ];

    # XXX FIXME
    unshift @$attr, (hashDirPath => $opt{hashdirpath}) if ($opt{hashdirpath});

    my $mesg = $self->{ldap}->add($dn, attr => $attr);
    if ($mesg->code) {
        return $mesg->error;
    } else {
        return 0;
    }
}

sub add_alias {
    my $self = shift;
    my %opt = @_;

    my $base = "o=extmailAlias,$BASE";
    my $dn = "mailLocalAddress=$opt{alias},$base";

    my $attr = [
        mailLocalAddress => $opt{alias},
        virtualDomain => $opt{domain},
        objectClass => ['top', 'extmailAlias'],
        mail => [split(/\n/, $opt{goto})],
        active => $opt{active} ? 1 : 0,
        createDate => $opt{create},
        ];

    my $mesg = $self->{ldap}->add($dn, attr => $attr);
    if ($mesg->code) {
        return $mesg->error;
    } else {
        return 0;
    }
}

sub add_manager {
    my $self = shift;
    my %opt = @_;

    my $base = "o=extmailManager,$BASE";
    my $dn = "mail=$opt{manager},$base";
    my $ctype = $self->{crypt_type};

    my $attr = [
        mail => $opt{manager},
        cn => $opt{cn},
        objectClass => ['top', 'extmailManager'],
        active => $opt{active} ? 1 : 0,
        disablePasswdChange => $opt{disablepwdchange},
        createDate => $opt{create},
        expireDate => $opt{expire},
        managerType => $opt{type},
        userPassword => $self->encrypt($ctype, $opt{passwd}),
        virtualDomain => $opt{domain},
        ];

    if ($opt{question} && $opt{answer}) {
        push @$attr, question => $opt{question};
        push @$attr, answer => $opt{answer};
    }

    my $mesg = $self->{ldap}->add($dn, attr => $attr);
    if ($mesg->code) {
        return $mesg->error;
    } else {
        return 0;
    }
}

sub delete_user {
    my $self = shift;
    my $user = $_[0];

    my ($domain) = ($user =~ m!.*@(.*)!);
    my $mesg = $self->{ldap}->delete("mail=$user,virtualDomain=$domain,o=extmailAccount,$BASE");
    if ($mesg->code) {
        return $mesg->error;
    } else {
        return 0;
    }
}

sub delete_alias {
    my $self = shift;
    my $mesg = $self->{ldap}->delete("mailLocalAddress=$_[0],o=extmailAlias,$BASE");
    if ($mesg->code) {
        return $mesg->error;
    } else {
        return 0;
    }
}

sub delete_domain {
    my $self = shift;
    my $mesg = $self->{ldap}->delete("virtualDomain=$_[0],o=extmailAccount,$BASE");
    if ($mesg->code) {
        return $mesg->error;
    } else {
        return 0;
    }
}

sub delete_manager {
    my $self = shift;
    my $mesg = $self->{ldap}->delete("mail=$_[0],o=extmailManager,$BASE");
    if ($mesg->code) {
        return $mesg->error;
    } else {
        return 0;
    }
}

sub modify_user {
    my $self = shift;
    my %opt = @_;

    my $ctype = $self->{crypt_type};
    my $base = "o=extmailAccount,$BASE";
    my $dn = "mail=$opt{user},virtualDomain=$opt{domain},$base";
    my $attr = [
        cn => $opt{cn},
        uidNumber => $opt{uidnumber} || '1000',
        gidNumber => $opt{gidnumber} || '1000',
        netdiskQuota => $opt{netdiskquota},
        active => $opt{active} ? 1 : 0,
        mailQuota => $opt{quota},
        expireDate => $opt{expire},
        disablePasswdChange => $opt{disablepwdchange},
        disablesmtpd => $opt{disablesmtpd},
        disablesmtp => $opt{disablesmtp},
        disablewebmail => $opt{disablewebmail},
        disablenetdisk => $opt{disablenetdisk},
        disableimap => $opt{disableimap},
        disablepop3 => $opt{disablepop3},
    ];

    my $mesg = $self->{ldap}->modify($dn,  replace => $attr);
    return $mesg->error if ($mesg->code);

    if ($opt{passwd}) {
        my $pwa = [ userPassword => $self->encrypt($ctype, $opt{passwd}) ];
        if ($self->{opt}->{'ldif_attr_clearpw'}){
            push @$pwa, (clearPassword => $opt{passwd});
        }

        $mesg = $self->{ldap}->modify(
            $dn,
            replace => $pwa,
        );
    }

    if ($opt{question} and $opt{answer}) {
        $mesg = $self->{ldap}->modify($dn,
            replace => [
                question => $opt{question},
                answer => $opt{answer},
            ]
        );
    }

    if ($mesg->code) {
        return $mesg->error;
    } else {
        return 0;
    }
}

sub modify_alias {
    my $self = shift;
    my %opt = @_;
    my $mgr = $self->{ldap}; # ldap obj

    my $base = "o=extmailAlias,$BASE";
    my $dn = "mailLocalAddress=$opt{alias},$base";

    $mgr->modify($dn, delete => [qw(mail)]); # ignore error!
    my $mesg = $mgr->modify($dn,
        add => {
            mail => [split(/\n/, $opt{goto})]
        }
    );
    return $mesg->error if ($mesg->code);

    $mesg = $mgr->modify($dn,
        replace => [
            active => $opt{active} ? 1:0,
        ]
    );
    return $mesg->error if ($mesg->code);
    0;
}

sub modify_domain {
    my $self = shift;
    my %opt = @_;

    my $base = "o=extmailAccount,$BASE";
    my $dn = "virtualDomain=$opt{domain},$base";

    my $attr = {
        virtualDomain => $opt{domain},
        expireDate => $opt{expire},
        description => $opt{description},
        domainMaxAlias => $opt{maxalias},
        domainMaxUsers => $opt{maxusers},
        domainMaxQuota => $opt{maxquota},
        domainMaxNetStore => $opt{maxndquota},
        Transport => $opt{transport},
        canSignup => $opt{can_signup} ? 1 : 0,
        defaultQuota => $opt{default_quota},
        defaultNetStore => $opt{default_ndquota},
        defaultExpire => $opt{default_expire},
        disablesmtpd => $opt{disablesmtpd},
        disablesmtp => $opt{disablesmtp},
        disablewebmail => $opt{disablewebmail},
        disablenetdisk => $opt{disablenetdisk},
        disableimap => $opt{disableimap},
        disablepop3 => $opt{disablepop3},
        active => $opt{active} ? 1 : 0,
    };

    my $mesg = $self->{ldap}->modify($dn, replace => $attr);
    if ($mesg->code) {
        return $mesg->error;
    } else {
        return 0;
    }
}

sub modify_manager {
    my $self = shift;
    my %opt = @_;

    my $base = "o=extmailManager,$BASE";
    my $dn = "mail=$opt{manager},$base";
    my $mgr = $self->{ldap};
    my $ctype = $self->{crypt_type};

    $mgr->modify($dn, delete => [qw(virtualDomain)]); # ignore error
    my $mesg = $mgr->modify($dn,
        add => {
            virtualDomain => $opt{domain},
        }
    );
    return $mesg->error if ($mesg->code);

    $mesg = $mgr->modify($dn,
        replace => [
            active => $opt{active} ? 1:0,
            expireDate => $opt{expire},
            cn => $opt{cn},
            disablePasswdChange => $opt{disablepwdchange},
        ]
    );

    if ($opt{question} and $opt{answer}) {
        $mesg = $self->{ldap}->modify($dn,
            replace => [
                question => $opt{question},
                answer => $opt{answer},
            ]
        );
    }

    if ($opt{passwd}) {
        $mgr->modify($dn,
            replace => [
            userPassword => $self->encrypt($ctype, $opt{passwd}),
            ]
        );
    }

    return $mesg->error if ($mesg->code);
    0;
}

sub get_user_info {
    my $self = shift;
    my $user = $_[0];
    my $domain = $user;

    $domain =~ s#^([^\@]+)@##;
    my $filter = "(&(objectclass=extmailUser)(mail=$user)(virtualdomain=$domain))";
    my $base = "o=extmailAccount,$BASE";

    my $ref = $self->get_entry($filter, $base);
    return undef unless ($ref);
    return {
        mail => $ref->{mail},
        cn => $ref->{cn},
        domain => $ref->{virtualDomain},
        uidnumber => $ref->{uidNumber},
        gidnumber => $ref->{gidNumber},
        uid => $ref->{uid},
        netdiskquota => $ref->{netdiskQuota},
        active => $ref->{active} ? 1 : 0,
        quota => $ref->{mailQuota},
        passwd => $ref->{userPassword},
        clearpw => $ref->{clearPassword},
        mailhost => $ref->{mailHost},
        maildir => $ref->{mailMessageStore},
        homedir => $ref->{homeDirectory},
        expire => $ref->{expireDate},
        create => $ref->{createDate},
        disablepwdchange => $ref->{disablePasswdChange},
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
    my $filter = "(&(objectclass=extmailDomain)(virtualDomain=$_[0]))";
    my $base = "o=extmailAccount,$BASE";

    my $ref = $self->get_entry($filter, $base);
    return undef unless ($ref);
    return {
        domain => $ref->{virtualDomain},
        create => $ref->{createDate},
        expire => $ref->{expireDate},
        hashdirpath => $ref->{hashDirPath},
        description => $ref->{description},
        maxalias => $ref->{domainMaxAlias},
        maxusers => $ref->{domainMaxUsers},
        maxquota => $ref->{domainMaxQuota},
        maxndquota => $ref->{domainMaxNetStore},
        transport => $ref->{Transport},
        can_signup => $ref->{canSignup},
        default_quota => $ref->{defaultQuota},
        default_ndquota => $ref->{defaultNetStore},
        default_expire => $ref->{defaultExpire},
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
    my $filter = "(&(objectclass=extmailAlias)(mailLocalAddress=$_[0]))";
    my $base = "o=extmailAlias,$BASE";

    my $ref = $self->get_entry($filter, $base);
    return undef unless ($ref);
    return {
        alias => $ref->{mailLocalAddress},
        domain => $ref->{virtualDomain},
        goto => $ref->{mail},
        active => $ref->{active} ? 1 : 0,
        create => $ref->{createDate},
    }
}

sub get_manager_info {
    my $self = shift;
    my $filter = "(&(objectclass=extmailManager)(mail=$_[0]))";
    my $base = "o=extmailManager,$BASE";

    my $ref = $self->get_entry($filter, $base);
    return undef unless ($ref);
    return {
        manager => $ref->{mail},
        cn => $ref->{cn},
        question => $ref->{question},
        answer => $ref->{answer},
        disablepwdchange => $ref->{disablePasswdChange},
        create => $ref->{createDate},
        expire => $ref->{expireDate},
        type => $ref->{managerType},
        passwd => $ref->{userPassword},
        active => $ref->{active} ? 1 : 0,
        domain => (ref $ref->{virtualDomain} ? $ref->{virtualDomain} : [$ref->{virtualDomain}]),
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

    # XXX ext_info
    $self->{_ext_info} = {
        total => scalar @$all,
        match => scalar @$arr,
        pages => $self->pages(scalar @$arr, $psize),
    };

    if ($page <= 0) { $has_prev = 0 };
    return ($res, $has_prev, $has_next);
}

sub ext_info {
    my $self = shift;
    return $self->{_ext_info};
}

sub domain_paging {
    die "use Ext::MgrApp::domain_paging() instead\n";
}

1;
