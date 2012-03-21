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
package Ext::MgrApp;

# This package design for simple interface to userland programe,
# it Inherite basic modules and methods.
use strict;

use Ext;
use vars qw(@ISA $VERSION);
@Ext::MgrApp::ISA=qw(Ext Ext::Template);

use Ext::CGI;
use Ext::Session; # import parse_sess()
use Ext::Template;
use Ext::Utils; # import get_remoteip()
use Ext::DateTime qw(time2epoch epoch2time);
use Benchmark;

$VERSION = '1.1';

# the Management packages
use Ext::Mgr;

use vars qw(%lang_global);
use Ext::Lang;

sub add_methods {
    my $self = shift;
    my %meths = @_;
    if(ref($self)) {
        for my $meth (keys %meths) {
            $self->{fcbl}{$meth} = $meths{$meth};
        }
    }
}

sub init {
    my $self = shift;

    # trace and store exception, install signal handler
    local $SIG{__DIE__} = $SIG{__WARN__} = sub { $self->trace(@_) };

    my $CGI = new Ext::CGI;
    $self->{query} = $CGI;
    $self->{requires_login} =1;

    # must initialize first
    $self->init_sysconfig;

    # begin to initialize other things
    $self->{tpl} = Ext::Template->new(
        root => $self->{sysconfig}->{SYS_TEMPLDIR},
        cache => 0,
        blind_cache => 0,
    );
    my $sid = $CGI->get_cookie('webman_sid'); # only trust cookie

    if($sid) {
        $self->{sid} = $sid;
        if ($self->valid_session) {
            $self->{error} = undef;
            $self->init_env($sid);
            $CGI->set_cookie(
                name => 'webman_sid',
                value => $sid,
            ); # cookie expire after the browser closed
        } else {
            $CGI->set_cookie(
                name => 'webman_sid',
                value => '',
                expires => $CGI->expires('-1y'),
            );
            $self->error('Session expired, please login again!');
            kill_sid($self->{sid}); # destory session what ever it's
        }
        return 1; # return
    }
    $self->error('Invalid session, try again!') unless($self->permit);
}

sub init_env {
    my $self = shift;
    # feed the sid, or $self->{sid}, for sometime user not login
    # while app calling init_env(), so need manual sid feed
    my $sid = $_[0] || $self->{sid};

    my $info=parse_sess($sid);
    $ENV{LOGTIME} = $info->{loginTime};
    $ENV{USERNAME} = $info->{User};
    $ENV{USERTYPE} = $info->{Type};
}

sub init_sysconfig {
    my $self = shift;
    my $c = \%Ext::Cfg; # after call MgrApp::run(), %Ext::Cfg will be initialized

    $c->{SYS_CONFIG} = $c->{SYS_CONFIG} || '/var/www/cgi-bin/extman/';
    $c->{SYS_LANGDIR} = $c->{SYS_LANGDIR} || $c->{SYS_CONFIG}.'/lang/';
    $c->{SYS_TEMPLDIR} = $c->{SYS_TEMPLDIR} || $c->{SYS_CONFIG}.'/html/';
    $c->{SYS_TEMPLATE_NAME} = $c->{SYS_TEMPLATE_NAME} || 'standard';
    $c->{SYS_BACKEND_TYPE} = $c->{SYS_BACKEND_TYPE} || 'mysql';
    $c->{SYS_PSIZE} = $c->{SYS_PSIZE} || 20;
    $c->{SYS_LANG} = $c->{SYS_LANG} || guess_intl(); # XXX auto detect?
    $c->{SYS_TEMPLATE} = $c->{SYS_TEMPLATE} || 'standard';
    $c->{SYS_CHARSET} = 'UTF-8'; # XXX only UTF-8
    $c->{SYS_MIN_PASS_LEN} = $c->{SYS_MIN_PASS_LEN} || 2;
    $c->{SYS_CRYPT_TYPE} = $c->{SYS_CRYPT_TYPE} || 'crypt';

    $self->{sysconfig}=$c;
}

sub run {
    my $app = shift;
    my $q = $app->{query};

    eval {
        REQUEST:
        {
            if($app->{requires_login}) {
                $app->pre_backend; # prepare backend
            LOGIN:
            {
                my $user = lc $q->cgi("username");
                last LOGIN if $app->already_login;
                if($user and $q->cgi('action')) {
                    if ($app->{sysconfig}->{SYS_CAPTCHA_ON}) {
                        require Ext::CaptCha;
                        my $data = $q->get_cookie('scode');
                        my $raw = $q->cgi('vcode'); # verify code
                        my $key = $app->{sysconfig}->{SYS_CAPTCHA_KEY} || 'extmail';
                        my $cap = Ext::CaptCha->new(key => $key);

                        if (!$cap->verify(lc $raw, $data)) {
                            $app->{redirect} = "?__mode=show_login&error=vcode";
                            last LOGIN;
                        }
                    }
                    my($status, $ref) = $app->login;
                    if($status) {
                        # if login ok, re_calculate Quota, this is trick
                        # to udpate quota, only once after login. XXX

                        $app->init_env; # must initialize %ENV
                        $app->{redirect} = "?__mode=welcome&sid=$ref->{sid}";
                    }else {
                        $app->{redirect} = '?__mode=show_login&error=badlogin';
                    }
                }
            } # LOGIN block END
            }

            my $mode = $q->cgi("__mode") || $app->{default_mode};
            my $code = $app->{fcbl}{$mode} or
                $app->error("No such action: $mode"), last REQUEST;

            if(($code && $app->valid) || $app->permit) {
                $q->send_cookie;
                unless ($app->{redirect}) {
                    $app->pre_run;
                    my $t0 = new Benchmark;
                    $app->global_tpl;
                    $code->($app);
                    my $t1 = new Benchmark;
                    my $t = timediff($t1,$t0);
                    my $f = "%3d secs"; # full format: "%3d wsecs (%5.2f usr + %5.2f sys)";

                    # t->[0] wall clock
                    # t->[1] user clock
                    # t->[2] sys clock
                    $app->{tpl}->assign(
                        TIME => sprintf($f, $t->[0])
                    );
                    $app->post_run;
                }
            }

            if(my $url = $app->{redirect}) {
                $app->redirect($url);
            }
        } # END of REQUEST
    };

    if ($@) {
        $app->error($@);
    }

    if($app->{sysconfig}->{SYS_SHOW_WARN}) {
        $app->trace($app->{sysconfig}->{SYS_SHOW_WARN});
        $app->warn($app->{_trace});
    }
}

sub register {
    my $app = shift;
    my $pkg = caller;
    $pkg =~ s!Ext::App(::)*!!;
    $app->{pkg} = $pkg if($pkg && !$app->{pkg});
}

sub permit {
    return 1 if(shift->{pkg}=~/(Login|Signup|ChangePwd|ForgetPwd)/);
    return 0;
}

sub warn {
    my $self = shift;
    if($self->{tpl}->{noprint}) {
        print "Content-type: text/html\n\n";
    }
    print $self->{_trace};
}

sub error {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $hdr = $self->{sent_headers};

    $self->{query}->send_cookie;

    # if(not defined $hdr or !$hdr=~m#text/html#) {
    #   print "Content-type: text/html\n\n";
    #   $self->{sent_headers} = 'text/html';
    # }
    $tpl->assign(ERR => "@_");
    $tpl->process('error.html');
    $tpl->print;
    $tpl->{errmsg} = @_; # set errmsg and disable follow print
}

sub trace {
    my $self = shift;
    $self->{_trace} .= "@_";
    $self->{tpl}->{_trace} .= "@_"; # XXX
}

# prepare backend information, eg: mysql/ldap connectoin and bind info
sub pre_backend {
    my $self = shift;
    my $a = "";
    my $c = $self->{sysconfig};

    if ($c->{SYS_BACKEND_TYPE} eq 'mysql') {
        $a = Ext::Mgr->new(
            type => 'mysql',
            host => $c->{SYS_MYSQL_HOST},
            socket => $c->{SYS_MYSQL_SOCKET},
            dbname => $c->{SYS_MYSQL_DB},
            dbuser => $c->{SYS_MYSQL_USER},
            dbpw => $c->{SYS_MYSQL_PASS},
            table => $c->{SYS_MYSQL_TABLE},
            table_attr_username => $c->{SYS_MYSQL_ATTR_USERNAME},
            table_attr_passwd => $c->{SYS_MYSQL_ATTR_PASSWD},
            table_attr_clearpw => $c->{SYS_MYSQL_ATTR_CLEARPW},
            crypt_type => $c->{SYS_CRYPT_TYPE},
            psize => $c->{SYS_PSIZE} || 10,
        );
    } elsif ($c->{SYS_BACKEND_TYPE} eq 'ldap') {
        $a = Ext::Mgr->new(
            type => 'ldap',
            host => $c->{SYS_LDAP_HOST},
            base => $c->{SYS_LDAP_BASE},
            rootdn => $c->{SYS_LDAP_RDN},
            rootpw => $c->{SYS_LDAP_PASS},
            ldif_attr_username => $c->{SYS_LDAP_ATTR_USERNAME},
            ldif_attr_passwd => $c->{SYS_LDAP_ATTR_PASSWD},
            ldif_attr_clearpw => $c->{SYS_LDAP_ATTR_CLEARPW},
            crypt_type => $c->{SYS_CRYPT_TYPE},
            psize => $c->{SYS_PSIZE} || 10,
            bind => 1);
    }else {
        return 0; # auth type not support, abort
    }

    return 0 unless($a);

    # store backend object to public use
    $self->{backend} = $a;
    # return handler
    return 1;
}

sub login {
    my $self = shift;
    my $login_ok = 0;
    my $q = $self->{query};
    my $user = lc $q->cgi("username");
    my $pass = $q->cgi("password");
    my $nosameip = $q->cgi("nosameip");

    my $a = $self->{backend};
    my $c = $self->{sysconfig};

    if($a->auth($user, $pass)) {
        my $sid = gen_sid();

        $self->{sid} = $sid; # save the sid and pass to other app/func*
        $a->{sid} = $sid; # this is need by $ref in run();
        save_sess($sid,
        {
            User => $user,
            IPaddr => $ENV{REMOTE_ADDR},
            Nosameip => ($nosameip?1:0),
            loginTime => time,
            Type => $a->{INFO}->{TYPE} || 'postmaster',
        });
        $q->set_cookie(
            name => 'webman_sid',
            value => $sid,
        ); # expire after the browser closed
        $login_ok = 1;
    }else {
        $login_ok = 0;
    }

    return (1, $a) if($login_ok);
    "";
}

# already_login - current it's not function, only check sid file
sub already_login {
    my $self = shift;
    my $q = $self->{query};
    return if not $self->{sid};
    if (parse_sess($self->{sid})) {
        return 1;
    }
    0;
}

# valid_session - check the validity of current session
sub valid_session {
    my $self = shift;
    my $sid = $_[0] || $self->{sid};
    my $sdata = parse_sess($sid);

    if (keys %$sdata && ($sdata->{Nosameip}?get_remoteip() eq $sdata->{IPaddr}:1)) {
        return 1;
    } else {
        return 0; # invalid or expire
    }
}

# valid - valid the request
sub valid {
    my $self = shift;
    return 0 if($self->{tpl}->{errmsg});
    return 0 if($self->{error});
    1;
}

sub global_tpl {
    my $self = shift;
    my $tpl = $self->{tpl};

    # do some global template tag assignment
    $tpl->assign(
        USER => $ENV{USERNAME},
        SID => $self->{sid},
        VERSION => "ExtMan/$VERSION",
        NVERSION => $VERSION,
        LANG => $self->{sysconfig}->{'SYS_LANG'},
        CAPTCHA_ON => ($self->{sysconfig}->{SYS_CAPTCHA_ON} ? 1 : 0),
    );

    if ($ENV{USERTYPE} eq 'admin') { # super user type
        $tpl->assign(ADMIN => 1);
    } else {
        $tpl->assign(ADMIN => 0);
    }

    initlang($self->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $tpl->assign(\%lang_global);
}

sub valid_perm {
    my $self = shift;
    my $domain = $_[0];

    return 1 if ($ENV{USERTYPE} eq 'admin'); # always true
    my $ref = $self->manager_owndomain($ENV{USERNAME});

    if ($ref) {
        if (grep(/^$domain$/, @$ref)) {
            return 1;
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

sub manager_owndomain {
    my $self = shift;
    my $mgr = $self->{backend};

    my $user = $_[0]; # manager username
    my $res = $mgr->get_manager_info($user);
    my $vd = $res->{domain};

    if (ref $vd) {
        if (scalar @$vd >0) {
            return $vd; # return ARRAY not ref !
        }
    } else {
        return [$vd];
    }
    # null
    []; # null ARRAY elemenet
}

# core function to get quota information of a specify domain
sub get_domain_usage {
    my $self = shift;
    my $domain = $_[0];
    my $quota = 0;
    my $us = $self->{backend}->get_users_list($domain) || [];
    my %info = (); # cleanup

    foreach my $m (@$us) {
        if (my $qt = $m->{quota}) {
            $qt =~ s/S$//;
            $info{quota} += $qt;
        }
        if (my $nd = $m->{netdiskquota}) {
            $nd =~ s/S$//;
            $info{ndquota} += $nd;
        }
    }

    my $as = $self->{backend}->get_aliases_list($domain);
    if ($as) {
        $info{alias} = scalar @$as;
    }
    if ($us) {
        $info{user} = scalar @$us;
    }
    \%info;
}

sub domain_overusage {
    my $self = shift;
    my $mgr = $self->{backend};
    my %opt = @_;
    my $cur = $self->get_domain_usage($opt{domain});
    my $top = $mgr->get_domain_info($opt{domain});
    my $rc = 0 ; # $lang_global{'overusage_default'}; # default rc to overquota

    if ($opt{alias}) {
       my $qa = $top->{maxalias} || '0';
       if ($qa && ($cur->{alias}+$opt{alias} > $qa)) {
           return $lang_global{'overusage_alias'};
       }
    }

    if ($opt{user}) {
        my $qu = $top->{maxusers} || '0';
        if ($qu && ($cur->{user}+$opt{user} > $qu)) {
            return $lang_global{'overusage_user'};
        }
    }

    if ($opt{quota}) {
        my $qq = $top->{maxquota} || '0';
        $qq =~ s/S//gi; # remove size flag

        if ($qq) {
            $cur->{quota} =~ s/S//gi;
            $opt{quota} =~ s/S//gi;
            if ($cur->{quota}+$opt{quota} > $qq) {
                return $lang_global{'overusage_quota'};
            }
        }
    }

    if ($opt{ndquota}) {
        my $qd = $top->{maxndquota} || '0';
        $qd =~ s/S//gi;

        if ($qd) {
            $cur->{ndquota} =~ s/S//gi;
            $opt{ndquota} =~ s/S//gi;
            if ($cur->{ndquota}+$opt{ndquota} > $qd) {
                return $lang_global{'overusage_ndquota'};
            }
        }
    }
    $rc;
}

# the important paging function merge from Mgr/* to MgrApp.pm
#
# $self, %opt => (
#   filter => $filter,
#   page => $page
# )

sub domain_lists {
    my $self = shift;
    my $mgr = $self->{backend};
    my $all = [];

    return $self->{_dlists} if $self->{_dlists};

    if ($ENV{USERTYPE} eq 'postmaster') {
        my $list = $self->manager_owndomain($ENV{USERNAME});
        for my $e (@$list) {
            push @$all, $mgr->get_domain_info($e);
        }
    } elsif ($ENV{USERTYPE} eq 'admin') {
        $all = $mgr->get_domains_list || [];
    }
    $self->{_dlists} = $all;
    $all;
}

sub domain_paging {
    my $self = shift;
    my %opt = @_;
    my $mgr = $self->{backend};

    my $page = $opt{page} || 0;
    my $filter = $opt{filter};
    my $filter_type = $opt{filter_type};
    my ($has_prev, $has_next) = (1, 0);

    my $psize = $mgr->{psize}; # page size
    my $begin = $page*$psize;

    my $all = [];
    if ($ENV{USERTYPE} eq 'postmaster') {
        my $list = $self->manager_owndomain($ENV{USERNAME});
        for my $e (@$list) {
            push @$all, $mgr->get_domain_info($e);
        }
    } elsif ($ENV{USERTYPE} eq 'admin') {
        $all = $mgr->get_domains_list || [];
    }

    # save all domain lists for all MgrApp::* modules
    $self->{_dlists} = $all;

    my $arr = [];

    delete $self->{_ext_info};

    for(my $i=0; $i<scalar @$all; $i++) {
        my $e = $all->[$i];
        if ($filter) {
            next unless $e->{$filter_type} =~ /\Q$filter\E/i;
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

    # XXX FIXME
    $self->{_ext_info} = {
        total => scalar @$all,
        match => scalar @$arr,
        pages => $mgr->pages(scalar @$arr, $psize),
    };
    return ($res, $has_prev, $has_next);
}

sub ext_info {
    return shift->{_ext_info};
}

# ISP / HashDir relate functions*
sub get_domain_hashdir {
    my $self = shift;
    my $domain = shift;
    my $mgr = $self->{backend};
    return undef unless $domain;

    my $info = $mgr->get_domain_info($domain);
    return $info->{hashdirpath};
}

sub gen_domain_hashdir {
    my $self = shift;
    my $sys = $self->{sysconfig};

    eval { require Ext::HashDir };
    die 'Need Ext::HashDir' if ($@);

    Ext::HashDir->import(qw(hashdir));

    return undef if ($sys->{SYS_ISP_MODE} ne 'yes');

    my $domain_deep = $sys->{SYS_DOMAIN_HASHDIR_DEPTH} || '2x1';
    my ($len, $size) = ($domain_deep =~ /^(\d+)x(\d+)$/);
    return hashdir($len, $size);
    '';
}

sub gen_user_hashdir {
    my $self = shift;
    my $sys = $self->{sysconfig};

    eval { require Ext::HashDir };
    die 'Need Ext::HashDir' if ($@);

    Ext::HashDir->import(qw(hashdir));

    return undef if ($sys->{SYS_ISP_MODE} ne 'yes');

    my $user_deep = $sys->{SYS_USER_HASHDIR_DEPTH} || '2x1';
    my ($len, $size) = ($user_deep =~ /^(\d+)x(\d+)$/);
    return hashdir($len, $size);
    '';
}

sub num2quota {
    my $self = shift;
    my $type = $self->{sysconfig}->{SYS_QUOTA_TYPE} || 'vda';
    my $quota = $_[0]; # must be number

    if ($type eq 'vda') {
        return $quota ? $quota : '0';
    } else {
        return $quota.'S';
    }
}

sub quota2num {
    my $self = shift;
    my $quota = $_[0];

    $quota =~ s/S$//i;
    return $quota;
}

# api defination
#
# $time, $expire
#
# $expire => 0 - unlimit, [digital]+[ymd], undef -> default
sub cvt2expire {
    my $self = shift;
    my $default = $self->{sysconfig}->{SYS_DEFAULT_EXPIRE} || '1y';
    my ($time, $expire) = @_;

    if (!defined $expire || ($expire && $expire !~ /^\d+[ymd]$/)) {
        $expire = $default;
    }

    if ($expire>0 && $expire) { # have expire setting

        $time = time2epoch($time);

        if (my $y = _digi_y($expire)) {
            $time += _digi_y($expire);
        }
        if (my $m = _digi_m($expire)) {
            $time += _digi_m($expire);
        }
        if (my $d = _digi_d($expire)) {
            $time += _digi_d($expire);
        }

        $time = epoch2time($time);

    } else {
        $time = '';
    }
    $time; # return it, if null, means forever
}

sub valid_time {
    my $self = shift;
    my $dt = shift;

    return 1 if ($dt eq '0' || $dt eq '0000-00-00');
    return 0 unless ($dt =~ /^\d{4}-\d{2}-\d{2}$/);

    $dt = "$dt 00:00:00"; # add suffix
    eval { time2epoch($dt) };
    return if ($@);
    1;
}

sub valid_expire {
    my $self = shift;
    my ($domain, $t) = @_;
    my $mgr = $self->{backend};

    return 1 if ($t eq 0 or $t eq '0000-00-00');

    my $dn = $mgr->get_domain_info($domain);
    my $ok = 0;

    return 1 if ($dn->{expire} eq '0000-00-00'); # ignore checks

    eval {
        $ok = 1 if time2epoch($dn->{expire})-time2epoch($t)>=0;
    };
    if ($@) {
        return 0;
    }
    $ok;
}

sub _digi_y {
    my $digi = shift;
    if ($digi =~ /(\d+)y/i) {
        return $1*365*24*3600;
    } else {
        return undef;
    }
}

sub _digi_m {
    my $digi = shift;
    if ($digi =~ /(\d+)m/i) {
        return $1*30*24*3600;
    } else {
        return undef;
    }
}

sub _digi_d {
    my $digi = shift;
    if ($digi =~ /(\d+)d/i) {
        return $1*24*3600;
    } else {
        return undef;
    }
}

# only effect for user and alias local part
sub sanity_username {
    my $self = shift;

    return 0 unless ($_[0]);

    # contain invalid characters
    if ($_[0] =~ /[^a-zA-Z0-9_\.-]/) {
        return 0;
    }
    1;
}

# only effect for manager account, eg: foo@bar.com
sub sanity_manager {
    my $self = shift;

    return 0 unless ($_[0]);

    if ($_[0] =~ /[^\@a-zA-Z0-9_\.-]/) {
        return 0;
    }
    1;
}

sub pre_run { 1 };

sub post_run { 1 };

sub redirect {
    my $self = shift;
    my ($url, $mode) = @_;
    print "Status: 301 Moved Permanantly\n";
    print "Location: $url\n\n";
    print "<html><head><META HTTP-EQUIV=refresh content=\"0;url=$url\"></head></html>";
}

sub save_sess {
    my ($sid, $hash) = @_;
    my $str;
    $str .= "$_ = $hash->{$_}\n" for(keys %$hash);
    write_sess($sid, $str);
}

1;
