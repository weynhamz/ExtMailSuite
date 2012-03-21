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
package Ext::App;

# This package design for simple interface to userland programe,
# it Inherite basic modules and methods.
use strict;
use vars qw($VERSION);

use vars qw($usercfg $sysconfig);
@Ext::App::ISA=qw( Ext );

use Ext;
use Ext::CGI;
use Ext::Session; # import parse_sess()
use Ext::Template;
use Ext::Config;
use Ext::Utils; # import get_remoteip()
use Ext::Storage::Maildir;
use Benchmark;

use vars qw(%lang_global);
use Ext::Lang;
use Ext::Unicode;
use Ext::Logger;

# Extmail version
$VERSION = '1.2';

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

    local $SIG{__DIE__} = $SIG{__WARN__} = sub { $self->trace(@_) };

    # XXX get the initialized global config hash
    $sysconfig = \%Ext::Cfg;

    # must initialize first
    $self->init_sysconfig;

    my $tmpdir = $self->{sysconfig}->{SYS_UPLOAD_TMPDIR};

    my $CGI = Ext::CGI->new(tmpdir => $tmpdir);

    $self->{query} = $CGI;
    $self->{requires_login} =1;

    # begin to initialize other things
    $self->{tpl} = Ext::Template->new(
        root => $self->{sysconfig}->{SYS_TEMPLDIR},
        cache => 1,
        blind_cache => 1,
        http_cache => $self->{sysconfig}->{SYS_HTTP_CACHE},
    );

    my $LOG;

    if ($self->{sysconfig}->{SYS_LOG_ON}) {
        $LOG = Ext::Logger->new(
            type => $self->{sysconfig}->{SYS_LOG_TYPE},
            log_file => $self->{sysconfig}->{SYS_LOG_FILE},
        );
    }
    $self->{logger} = $LOG;

    my $cookie_only = $self->{sysconfig}->{SYS_SESS_COOKIE_ONLY};
    my $sid = $cookie_only ? $CGI->get_cookie('sid') : $CGI->cgi('sid') || $CGI->get_cookie('sid');

    # in some special case, sid from cookie will contain ',' and strange info,
    # we must remove them before we process sid, or session will be expired
    $sid =~ s/,.*//;
    $sid =~ s/^\s+//;
    $sid =~ s/\s+//;

    if($sid) {
        # keep the sid even not valid, as soon as possible
        $self->{sid} = $sid;
        if($self->valid_session) {
            $self->{error} = undef;
            $self->init_env($sid);

            if ($cookie_only) {
                # update cookie every time if we check cookie only, this
                # will last the user's expiration every request :) happy~
                my $timeout = $self->{sysconfig}->{SYS_SESS_TIMEOUT};
                $CGI->set_cookie(
                    name => 'sid',
                    value => $sid,
                    expires => $timeout == 0 ? undef : $CGI->expires($timeout),
                );
            }
        }else {
            # destroy anything - unset cookie
            $CGI->set_cookie(
                name => 'sid',
                value => '',
                expires => $CGI->expires('-1y'),
            );
            $self->error('Session expired, please login again!');
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
    $ENV{HOME}= $info->{HOME};
    $ENV{MAILDIR} = $info->{MAILDIR} || $ENV{HOME}."/Maildir";
    $ENV{LOGTIME} = $info->{loginTime};
    $ENV{USERNAME} = $info->{User};
    $ENV{OPTIONS} = $info->{OPTIONS} if ($info->{OPTIONS});

    # FIXME XXX some mail system does not compatible with Maildir++
    # specification or *traditional*, a quota string without S or C
    # so we have to format it to what we want.
    $ENV{QUOTA} = qtstr_fmt($info->{mailQuota}); # 0S is acceptable
    if (!$self->{sysconfig}->{SYS_PERMIT_NOQUOTA} or !$ENV{QUOTA}) {
        $ENV{DEFAULT_QUOTA} = "104857600S"; # 100MB default
    }
    $ENV{FILEMAN_QUOTA} = qtstr_fmt($info->{NetDiskQuota}) || '10485760S'; # 10MB default for fileman
}

sub init_sysconfig {
    my $self = shift;
    my $c = \%Ext::Cfg || $sysconfig; # after call App::run(), %Ext::Cfg will be initialized

    $c->{SYS_CONFIG} = $c->{SYS_CONFIG} || '/var/www/cgi-bin/extmail/';
    $c->{SYS_LANGDIR} = $c->{SYS_LANGDIR} || $c->{SYS_CONFIG}.'/lang/';
    $c->{SYS_TEMPLDIR} = $c->{SYS_TEMPLDIR} || $c->{SYS_CONFIG}.'/html/';
    $c->{SYS_SESS_DIR} = $c->{SYS_SESS_DIR} || '/tmp';
    $c->{SYS_UPLOAD_TMPDIR} = $c->{SYS_UPLOAD_TMPDIR} || '/tmp';
    $c->{SYS_AUTH_TYPE} = $c->{SYS_AUTH_TYPE} || 'mysql';
    $c->{SYS_USER_PSIZE} = $c->{SYS_USER_PSIZE} || 20;
    $c->{SYS_USER_LANG} = $c->{SYS_USER_LANG} || 'en_US';
    $c->{SYS_USER_TEMPLATE} = $c->{SYS_USER_TEMPLATE} || 'default';
    $c->{SYS_USER_CHARSET} = $c->{SYS_USER_CHARSET} || 'iso-8859-1';
    $c->{SYS_MIN_PASS_LEN} = $c->{SYS_MIN_PASS_LEN} || 2;
    $c->{SYS_CRYPT_TYPE} = $c->{SYS_CRYPT_TYPE} || 'crypt';
    $c->{SYS_SPAM_REPORT_ON} = $c->{SYS_SPAM_REPORT_ON} || '0';
    $c->{SYS_IP_SECURITY_ON} = $c->{SYS_IP_SECURITY_ON} || '0';

    $self->{sysconfig}=$c;
}

sub run {
    my $app = shift;
    my $q = $app->{query};

    eval {
        REQUEST:
        {
            if($app->{requires_login}) {
            LOGIN:
            {
                my $user = lc $q->cgi("username");
                last LOGIN if $app->already_login;
                if($user) {
                    $app->pre_auth; # prepare auth
                    my ($status, $ref) = $app->login;
                    my $logmsg = "user=<$app->{_username}>, client=".get_remoteip().", module=login,";

                    if ($status == 0) {
                        # if login ok, re_calculate Quota, this is trick
                        # to udpate quota, only once after login. XXX

                        $app->log("$logmsg status=loginok");

                        $app->init_env; # must initialize %ENV
                        my $maildir = $app->get_working_path;
                        Ext::Storage::Maildir::init($maildir);
                        unlink $maildir.'/maildirsize';
                        unlink $maildir.'/fileman/filesize'; # ignore error
                        re_calculate();

                        $app->{redirect} = "?__mode=welcome&sid=$ref->{sid}";
                    } elsif ($status == 1) {
                        $app->log("$logmsg status=disabled");
                        $app->{redirect} = "?__mode=show_login&error=disabled";
                    } elsif ($status == 2) {
                        $app->log("$logmsg status=deactive");
                        $app->{redirect} = "?__mode=show_login&error=deactive";
                    } else {
                        $app->log("$logmsg status=badlogin");
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
                    # $q->send_cookie; # XXX FIXME send cookie
                    $app->pre_run;
                    my $t0 = new Benchmark;
                    $app->global_tpl;
                    $code->($app);
                    $app->mailbox_folders_list unless ($app->permit); # ignore some module
                    my $t1 = new Benchmark;
                    my $t = timediff($t1,$t0);
                    my $f = "%3d wsecs (%5.2f usr + %5.2f sys)";

                    $app->{tpl}->assign(
                        TIME => sprintf($f,$t->[0], $t->[1],$t->[2])
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
    return 1 if(shift->{pkg}=~/Login/);
    return 0;
}

sub warn {
    my $self = shift;
    if($self->{tpl}->{noprint}) {
        print "Content-type: text/html\r\n\r\n";
    }
    print $self->{_trace};
}

sub error {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $hdr = $self->{sent_headers};

    # if(not defined $hdr or !$hdr=~m#text/html#) {
    #   print "Content-type: text/html\n\n";
    #   $self->{sent_headers} = 'text/html';
    # }
    my $buf = "@_";
    $buf =~ s/[\r\n]+/ /gs;
    $buf =~ s/'/\\'/gs;

    $tpl->assign(
        JSERR => $buf,
        ERR => "@_",
        goback => $lang_global{goback} || 'Go Back',
        relogin => $lang_global{relogin} || 'Re-Login',
    );
    if ($ENV{HTTP_REFERER}) {
        $tpl->assign( REFERER => $ENV{HTTP_REFERER} );
    }

    $self->{query}->send_cookie;
    $tpl->process('error.html');
    $tpl->print;
    $tpl->{errmsg} = @_; # set errmsg and disable follow print
}

sub trace {
    my $self = shift;
    $self->{_trace} .= "@_";
    $self->{tpl}->{_trace} .= "@_"; # XXX
}

# prepare auth information, eg: mysql/ldap connectoin and bind info
sub pre_auth {
    my $self = shift;
    my $a = "";
    my $c = $self->{sysconfig};
    my $schema = $c->{SYS_AUTH_SCHEMA};

    if (!$schema =~/^(vpopmail\d+|virtual)$/) {
        die "Unsupported auth_schema type $schema\n";
    }

    if($c->{SYS_AUTH_TYPE} eq 'mysql') {
        require Ext::Auth::MySQL;
        $a = Ext::Auth::MySQL->new(
            type => 'mysql',
            schema => $schema,
            host => $c->{SYS_MYSQL_HOST},
            socket => $c->{SYS_MYSQL_SOCKET},
            dbname => $c->{SYS_MYSQL_DB},
            dbuser => $c->{SYS_MYSQL_USER},
            dbpw => $c->{SYS_MYSQL_PASS},
            table => $c->{SYS_MYSQL_TABLE},
            table_attr_username => $c->{SYS_MYSQL_ATTR_USERNAME},
            table_attr_domain => $c->{SYS_MYSQL_ATTR_DOMAIN},
            table_attr_passwd => $c->{SYS_MYSQL_ATTR_PASSWD},
            table_attr_clearpw => $c->{SYS_MYSQL_ATTR_CLEARPW},
            table_attr_quota => $c->{SYS_MYSQL_ATTR_QUOTA},
            table_attr_netdiskquota => $c->{SYS_MYSQL_ATTR_NDQUOTA},
            table_attr_home => $c->{SYS_MYSQL_ATTR_HOME},
            table_attr_maildir => $c->{SYS_MYSQL_ATTR_MAILDIR},
            table_attr_disablewebmail => $c->{SYS_MYSQL_ATTR_DISABLEWEBMAIL},
            table_attr_disablenetdisk => $c->{SYS_MYSQL_ATTR_DISABLENETDISK},
            table_attr_disablepwdchange => $c->{SYS_MYSQL_ATTR_DISABLEPWDCHANGE},
            table_attr_active =>  $c->{SYS_MYSQL_ATTR_ACTIVE},
            table_attr_pwd_question => $c->{SYS_MYSQL_ATTR_PWD_QUESTION},
            table_attr_pwd_answer => $c->{SYS_MYSQL_ATTR_PWD_ANSWER},
            crypt_type => $c->{SYS_CRYPT_TYPE},
        );
    }elsif($c->{SYS_AUTH_TYPE} eq 'ldap') {
        require Ext::Auth::LDAP;
        $a = Ext::Auth::LDAP->new(
            type => 'ldap',
            host => $c->{SYS_LDAP_HOST},
            schema => $schema,
            base => $c->{SYS_LDAP_BASE},
            rootdn => $c->{SYS_LDAP_RDN},
            rootpw => $c->{SYS_LDAP_PASS},
            ldif_attr_username => $c->{SYS_LDAP_ATTR_USERNAME},
            ldif_attr_domain => $c->{SYS_LDAP_ATTR_DOMAIN},
            ldif_attr_passwd => $c->{SYS_LDAP_ATTR_PASSWD},
            ldif_attr_clearpw => $c->{SYS_LDAP_ATTR_CLEARPW},
            ldif_attr_quota => $c->{SYS_LDAP_ATTR_QUOTA},
            ldif_attr_netdiskquota => $c->{SYS_LDAP_ATTR_NDQUOTA},
            ldif_attr_home => $c->{SYS_LDAP_ATTR_HOME},
            ldif_attr_maildir => $c->{SYS_LDAP_ATTR_MAILDIR},
            ldif_attr_disablewebmail => $c->{SYS_LDAP_ATTR_DISABLEWEBMAIL},
            ldif_attr_disablenetdisk => $c->{SYS_LDAP_ATTR_DISABLENETDISK},
            ldif_attr_disablepwdchange => $c->{SYS_LDAP_ATTR_DISABLEPWDCHANGE},
            ldif_attr_active => $c->{SYS_LDAP_ATTR_ACTIVE},
            ldif_attr_pwd_question => $c->{SYS_LDAP_ATTR_PWD_QUESTION},
            ldif_attr_pwd_answer => $c->{SYS_LDAP_ATTR_PWD_ANSWER},
            crypt_type => $c->{SYS_CRYPT_TYPE},
            bind => 1, );
    }elsif($c->{SYS_AUTH_TYPE} eq 'authlib') {
        require Ext::Auth::Authlib;
        $a = Ext::Auth::Authlib->new(
            type => 'authlib',
            path => $c->{SYS_AUTHLIB_SOCKET},
            schema => $schema
        );
    }else {
        return 0; # auth type not support, abort
    }

    return 0 unless($a);
    $self->{auth_handler} = $a;
    # return handler
    return 1;
}

# return value:
#
# rv = -1 LOGIN_FAIL
# rv =  0 LOGIN_OK
# rv =  1 LOGIN_DISABLED
# rv =  2 LOGIN_DEACTIV
sub login {
    my $self = shift;
    my $login_ok = 0;
    my $q = $self->{query};
    my $user = lc $q->cgi("username");
    my $domain = lc $q->cgi("domain");
    my $pass = $q->cgi("password");
    my $nosameip = $q->cgi("nosameip");

    $user =~ s/^\s*//;
    $user =~ s/\s*$//;
    if (! $self->sanity_username($user)){
        return -1;
    }

    $domain =~ s/^\s*//;
    $domain =~ s/\s*$//;
    if (! $self->sanity_domain($domain)){
        return -1;
    }

    $user = "$user\@$domain"; # XXX

    $self->{_username} = $user;

    my $a = $self->{auth_handler};
    my $c = $self->{sysconfig};
    my $rv = $a->auth($user, $pass);

    if($rv == 0) {
        my $sid = gen_sid();
        my $prepend = ($c->{SYS_MAILDIR_BASE}? $c->{SYS_MAILDIR_BASE} : "");

        $self->{sid} = $sid; # save the sid and pass to other app/func*
        $a->{sid} = $sid; # this is need by $ref in run();
        save_sess($sid,
        {
            User => $user,
            IPaddr => $ENV{REMOTE_ADDR},
            MAILDIR => $prepend.'/'.$a->{INFO}->{MAILDIR},
            mailQuota => qtstr_fmt($a->{INFO}->{QUOTA}), # format to standard
            NetDiskQuota => qtstr_fmt($a->{INFO}->{NETDISKQUOTA}),
            Nosameip => ($nosameip?1:0),
            loginTime => time,
            HOME => $prepend.'/'.$a->{INFO}->{HOME},
            OPTIONS => $a->{INFO}->{OPTIONS}, # option include disablenetdisk etc..
        });

        my $timeout = $c->{SYS_SESS_TIMEOUT};
        # XXX cookie
        $q->set_cookie(
            name => 'sid',
            value => $sid,
            expires => $timeout == 0 ? undef : $q->expires($timeout),
        );

        # successful login
        return (0, $a);
    } elsif ($rv == 1) {
        # account disabled for webmail
        return 1;
    } elsif ($rv == 2) {
        # account is deactive
        return 2;
    } else {
        # failure login
        return -1;
    }
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

sub log {
    my $self = shift;
    my $logger = $self->{logger};

    return unless $logger;
    $logger->log(@_);
}

# qtstr_fmt - format quota string into standard Maildir++
sub qtstr_fmt {
    my $q = $_[0];
    return '' unless ($q);

    $q =~ m#^\d+(S*)$#;
    unless ($1) {
        $q =~ s/[a-zA-Z]//g; # remove all characters if exists
        $q = $q.'S';
    }
    $q;
}

# valid_session - check the validity of current session
sub valid_session {
    my $self = shift;
    my $sid = $_[0] || $self->{sid};
    my $timeout = $self->{sysconfig}->{SYS_SESS_TIMEOUT};
    my $cookie_only = $self->{sysconfig}->{SYS_SESS_COOKIE_ONLY};
    my $sdata = parse_sess($sid);

    if (keys %$sdata && ($sdata->{Nosameip}?get_remoteip() eq $sdata->{IPaddr}:1)) {
        if ($cookie_only) {
            return 1;
        }
        # expire_calc() will return offset + time, so we must remove
        # the effect of time() :-) stupid ~
        return 1 if (time - $sdata->{loginTime} <= expire_calc($timeout) - time);
    } else {
        return 0;
    }
    0;
}

# valid - valid the request
sub valid {
    my $self = shift;
    return 0 if($self->{tpl}->{errmsg});
    return 0 if($self->{error});
    1;
}

sub mailbox_curquota {
    my $self = shift;
    my $tpl = $self->{tpl};

    my $inf = get_curquota;
    my $cursize = $inf->{size};
    $tpl->assign(
        MBX_CUR_QSIZE => human_size($inf->{size}),
        MBX_CUR_QCOUNT=> $inf->{count},
    );
    $inf = get_quota;
    # if not quota information, means permit noquota
    # over user account, so return and ignore quota calculation
    return if(!$inf->{size} && !$inf->{count});

    $self->{tpl}->assign(
        MBX_QUOTA_SIZE => human_size($inf->{size}),
        MBX_QUOTA_COUNT => $inf->{count}
    );

    my $quota_pc = $inf->{size} ? sprintf("%.2f",($cursize/$inf->{size})) : 0;
    $tpl->assign( MBX_QUOTA_PC => $quota_pc*100 );

    if(my $rv = is_overquota) {
        my $msg = $lang_global{'quota_warn'};
        $tpl->assign(MBX_OVERQUOTA => 1);

        if($rv eq 2) {
            # Mailbox overquota, ouch :-(
            $msg = $lang_global{'quota_over'};
        }
        $tpl->assign(MBX_OVERQUOTA_MSG => $msg);
    }else {
        $tpl->assign(MBX_OVERQUOTA => 0);# disable the tpl if statement
    }
}

sub mailbox_folders_list {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $utf8 = Ext::Unicode->new;
    my %options = @_;

    # XXX FIXME oops, urgly design, we should completely redesign the
    # working path pattern, wait for fixing
    Ext::Storage::Maildir::init($self->get_working_path);

    my @list = get_dirs_list;
    my $total_new = 0;
    my $total_seen = 0;
    my $total_size = 0;

    foreach (@list) {
        # XXX FIXME must get from cache ONLY
        my $inf = check_curcnt($_); # XXX old: get_dir_cnt();
        my ($size, $new, $seen) = (
            $inf->{size},
            $inf->{new},
            $inf->{seen}
        );

        $total_new += $new;
        $total_seen += $seen;
        $total_size += $size;

        if($size>1024) {
            if($size < 1024*1024) {
                $size = int($size/1024).'K';
            }else {
                # convert to Mbytes
                $size = sprintf("%.1fM", $size/1048576);
            }
        }
        my $name = $lang_global{$_}; # folder name translation, useful for
                                      # system default maildir, eg: Inbox.

        my $dsp_name = $_;
        if (not defined $lang_global{$_}) {
            $dsp_name = $utf8->decode_imap_utf7($dsp_name);
        }

        $tpl->assign(
            'LOOP_ALLFOLDERS_LIST',
            FOLDER => str2url($_),
            FOLDER_NAME => $name ? $name : $utf8->decode_imap_utf7($_),
            CUSTOM_ICON => $name?1:0,
            CAN_PURGE => $name?($_ =~/^(Junk|Trash)$/?1:0):1,
            SIZE => $size,
            NEW => $new,
            SEEN => $seen
        );

        # system default folders
        if ($name) {
            $tpl->assign(
                'LOOP_SYSFD_LIST',
                FOLDER => str2url($_),
                FOLDER_NAME => $name,
                CUSTOM_ICON => 1,
                SIZE => $size,
                NEW => $new,
                SEEN => $seen,
            );
        } else {
            $tpl->assign(
                'LOOP_USRFD_LIST',
                FOLDER => str2url($_),
                FOLDER_NAME => $utf8->decode_imap_utf7($_),
                CUSTOM_ICON => 0,
                SIZE => $size,
                NEW => $new,
                SEEN => $seen,
            );
        }
    }
    $tpl->assign(
        MBX_CUR_QNEW => $total_new,
        MBX_CUR_QSEEN => $total_seen,
        MBX_CUR_QSIZE => $total_size
    );
    $self->mailbox_curquota;
}

sub global_tpl {
    my $self = shift;
    my $tpl = $self->{tpl};

    # do some global template tag assignment
    $tpl->assign(
        USER_NICK => $self->userconfig->{nick_name} || $ENV{USERNAME},
        USER => $ENV{USERNAME},
        SID => $self->{sid},
        VERSION => "ExtMail $VERSION",  # string version
        NVERSION => $VERSION,           # numeric version
        LANG => curlang(),
        MFILTER_ON => $self->{sysconfig}->{SYS_MFILTER_ON} ? 1 : 0,
        DEBUG_ON => $self->{sysconfig}->{SYS_DEBUG_ON} ? 1 : 0,
        SIGNUP_ON => $self->{sysconfig}->{SYS_SHOW_SIGNUP} ? 1 : 0,
        IPSEC_ON => $self->{sysconfig}->{SYS_IP_SECURITY_ON} ? 1 : 0,
    );
    if ($ENV{OPTIONS} && $ENV{OPTIONS} =~ /disablenetdisk/i) {
        $tpl->assign(NETDISK_ON => 0);
    } else {
        $tpl->assign(NETDISK_ON => $self->{sysconfig}->{SYS_NETDISK_ON} ? 1 : 0);
    }

    initlang($self->userconfig->{lang}, __PACKAGE__);
    $tpl->assign(\%lang_global);
}

sub pre_run { 1 };

sub post_run { 1 };

sub userconfig {
    my $app = shift;
    my $sys = $app->{sysconfig};
    if(!$usercfg or $_[0]) {
        # init userconfig if it does't cache
        if($ENV{MAILDIR}) {
            my $config = Ext::Config->new(
                file => $ENV{MAILDIR}.'/user.cf'
            );
            # save CFG immediately, or $CFG may be tained in
            # some envirement, this is a stupid trick :-(
            $usercfg = $config->dump;
        }
        # must check $ENV{MAILDIR}, if present means login ok
        # and in user land mode, or perl will fail on some
        # uninitialize value or other exception
    }
    my $c = $usercfg;

    $c->{full_header} = $usercfg->{full_header} || 0;
    #$c->{ccsent} = (defined $usercfg->{ccsent}?$usercfg->{ccsent}:1);
    #$c->{show_html} = $usercfg->{show_html} || 0; # must set to 0
    #$c->{compose_html} = $usercfg->{compose_html} || 0; # must set to 0
    $c->{page_size} = $usercfg->{page_size} || $sys->{SYS_USER_PSIZE} || 20;
    $c->{timezone} = $usercfg->{timezone} || $sys->{SYS_USER_TIMEZONE} || '+0800';
    $c->{sort} = $usercfg->{sort} || 'Dt'; # by Date
    #$c->{lang} = $usercfg->{lang} || $sys->{SYS_USER_LANG} || 'en_US';
    $c->{lang} = $usercfg->{lang};
    $c->{delmode} = $usercfg->{delmode} || 'delete'; # default to trash

    $c->{trylocal} = (defined $usercfg->{trylocal}? $usercfg->{trylocal}:
                      (defined $sys->{SYS_USER_TRYLOCAL}?$sys->{SYS_USER_TRYLOCAL}:0)); # XXX FIXME
    #$c->{conv_link} = (defined $usercfg->{conv_link}? $usercfg->{conv_link}:1);
    #$c->{addr2abook} = (defined $usercfg->{addr2abook}?$usercfg->{addr2abook}:1);
    # should not initialize user space template with 'standard' fallback
    # or Template.pm will return wrong template name
    $c->{template} = $usercfg->{template} || $sys->{SYS_USER_TEMPLATE};
    $c->{charset} = 'UTF-8'; # default to UTF-8, and only UTF-8

    $c->{screen} = $usercfg->{screen} || $sys->{SYS_USER_SCREEN};
    $c->{ccsent} = (defined $usercfg->{ccsent}?$usercfg->{ccsent}:
                    (defined $sys->{SYS_USER_CCSENT}?$sys->{SYS_USER_CCSENT}:1));
    $c->{show_html} = (defined $usercfg->{show_html}?$usercfg->{show_html}:
                       (defined $sys->{SYS_USER_SHOW_HTML}?$sys->{SYS_USER_SHOW_HTML}:0));
    $c->{compose_html} = (defined $usercfg->{compose_html}?$usercfg->{compose_html}:
                          (defined $sys->{SYS_USER_COMPOSE_HTML}?$sys->{SYS_USER_COMPOSE_HTML}:0));
    $c->{conv_link} = (defined $usercfg->{conv_link}?$usercfg->{conv_link}:
                       (defined $sys->{SYS_USER_CONV_LINK}?$sys->{SYS_USER_CONV_LINK}:1));
    $c->{addr2abook} = (defined $usercfg->{addr2abook}?$usercfg->{addr2abook}:
                        (defined $sys->{SYS_USER_ADDR2ABOOK}?$sys->{SYS_USER_ADDR2ABOOK}:1));
    # XXX newly added parameters
    $c->{pop_on} = $usercfg->{pop_on} || 0; # defualt to off
    $c->{pop_files} = $usercfg->{pop_files} || 30; # default 20 files per account
    $c->{pop_timeout} = $usercfg->{pop_timeout} || 30; # timeout for pop

    $c;
}

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

sub get_working_path {
    my $self = shift;
    my $inf = parse_sess($self->{sid});
    if(scalar keys %$inf) {
        return $inf->{MAILDIR};
    }else {
        # may be sid not present or parse error
        return "" unless($ENV{HOME}); # fail back to null
        return "$ENV{HOME}/Maildir";
    }
}

my %screen = (
    'screen1' => [22, 40, '800x600'],
    'screen2' => [22, 80, '1024x768'],
    'screen3' => [22, 110, '1280x1024'],
    'auto'    => [0, 0, $lang_global{auto_screen} || 'Auto'],
);

sub get_screen {
    my $self = shift;
    my $str = shift;

    return $screen{screen1} unless ($str && $screen{$str});
    $screen{$str};
}

sub list_screen {
    my $self = shift;
    return ['auto', 'screen1', 'screen2', 'screen3'];
}

sub sanity_username {
    my $self = shift;
    return 0 unless ($_[0]);

    if ($_[0] =~ /[^a-zA-Z0-9_\.-]/) {
        return 0;
    }
    1;
}

sub sanity_domain {
    my $self = shift;
    return 0 unless ($_[0]);

    if ($_[0] =~ /[^a-zA-Z0-9\.-]/) {
        return 0;
    }
    1;
}

sub DESTROY {
    undef $usercfg;
}

1;
