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
package Ext::App::Pref;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::App);
use Ext::App;
use Ext::Config;
use Ext::Utils;
use Fcntl qw(:flock);
use Ext::POP3;
use MIME::Base64;

use vars qw(%lang_pref $lang_charset); # load locale
use Ext::Lang; # locale handler

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(pref_list => \&pref_list);
    $self->add_methods(pref_save => \&pref_save);
    $self->add_methods(pop3_list => \&pop3_list);
    $self->add_methods(pop3_save => \&pop3_save);

    $self->{default_mode} = 'pref_list';
    Ext::Storage::Maildir::init($self->get_working_path);

    $self->_initme;
    $self;
}

sub _initme {
    initlang($_[0]->userconfig->{lang}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_pref );
}

sub pref_list {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};

    # 2005-09-07, bug fix
    # here we should use SUPER->userconfig to get user.cf,
    # if user.cf not exist, SUPER->userconfig will initialize
    # varibles, old code does not handle this procedure, local
    # $CFG to be compatible with other code, reduce typing :-)
    #
    # my $config = Ext::Config->new(file => $ENV{MAILDIR}.'/user.cf');
    my $CFG = $self->userconfig;

    # localize init the lang, because App level will asign the lang
    # undefined unless end user save preference the first time, so
    # we must initialize it, ouch XXX FIXME
    $CFG->{lang} = $CFG->{lang} ? $CFG->{lang} : guess_intl();

    $tpl->assign(
        #SID => $q->cgi('sid'),
        NICK_NAME => $CFG->{nick_name},
        FULL_HEADER => $CFG->{full_header},
        CCSENT => $CFG->{ccsent},
        TRYLOCAL => $CFG->{trylocal},
        SHOW_HTML => $CFG->{show_html},
        COMPOSE_HTML => $CFG->{compose_html},
        CONV_LINK => $CFG->{conv_link},
        ADDR2ABOOK => $CFG->{addr2abook},
        POP_ON => $CFG->{pop_on}, # XXX pop3
    );

    my $pref_page_size = pref_page_size();
    my $pref_sort = pref_sort();
    my $pref_lang = $self->pref_lang(); # method
    my $pref_theme = $self->pref_theme(); # method
    my $pref_poptimeout = $self->pref_poptimeout(); # method
    my $pref_popfiles = $self->pref_popfiles();

    # show prefer screen type
    foreach(@{$self->list_screen}) {
        my $selected = 0;
        $selected = 1 if ($CFG->{screen} eq $_);
        $tpl->assign(
            'LOOP_SCREEN',
            SCREEN_TYPE => $_,
            SCREEN_NAME => $self->get_screen($_)->[2],
            SCREEN_CHK => $selected,
        );
    }

    # mail delete mode
    if ($CFG->{delmode} && $CFG->{delmode} eq 'purge') {
        $tpl->assign(MAIL_PURGE => 1);
    } else {
        $tpl->assign(MAIL_DELETE => 1);
    }

    # show prefer page size
    foreach(@$pref_page_size ) {
        my $selected = 0;
        $selected = 1 if($CFG->{page_size} eq $_);
        $tpl->assign(
            'LOOP_PAGE_SIZE',
            PAGE_SIZE => $_,
            PAGE_SIZE_CHK => $selected,
        );
    }

    # show timezone
    my $pref_timezone = pref_timezone();
    foreach my $t (@$pref_timezone) {
        my $selected = 0;
        $selected = 1 if($CFG->{timezone} eq $t->{'value'});
        $tpl->assign(
            'LOOP_TIMEZONE',
            TIMEZONE_VALUE => $t->{value},
            TIMEZONE_NAME => $t->{key},
            TIMEZONE_CHK => $selected,
        );
    }

    # show sort order by default
    foreach (keys %$pref_sort) {
        my $selected = 0;
        $selected = 1 if($CFG->{sort} eq $pref_sort->{$_});
        $tpl->assign(
            'LOOP_SORT',
            SORT_NAME => $lang_pref{$_},
            SORT_VAL => $pref_sort->{$_},
            SORT_CHK => $selected,
        );
    }

    # show prefer language, for template language
    foreach (@$pref_lang) {
        my $selected = 0;
        $selected = 1 if ($CFG->{lang} eq $_->{lang});
        $tpl->assign(
            'LOOP_LANG',
            LANG => $_->{lang},
            LANG_DESC => $_->{desc},
            LANG_CHK => $selected,
        );
    }

    # show prefer template
    foreach (sort keys %$pref_theme) {
        my $selected = 0;
        my $desc = $pref_theme->{$_}->{$CFG->{lang}} || $_;
        $selected = 1 if ($CFG->{template} eq $_);
        $tpl->assign(
            'LOOP_THEME',
            THEME => $_,
            THEME_DESC => $desc,
            THEME_CHK => $selected,
        );
    }

    # show pop3 relate setting
    foreach (@$pref_poptimeout) {
        my $selected = 0;
        $selected = 1 if ($CFG->{pop_timeout} eq $_);
        $tpl->assign(
            'LOOP_POPTIMEOUT',
            TIMEOUT => $_,
            TIMEOUT_CHECK => $selected,
        );
    }

    foreach (@$pref_popfiles) {
        my $selected = 0;
        $selected = 1 if ($CFG->{pop_files} eq $_);
        $tpl->assign(
            'LOOP_POPFILES',
            POPFILES => $_,
            POPFILES_CHECK => $selected,
        );
    }

    my $auth;
    if (!$self->{auth_handler}) {
        $self->pre_auth;
    }
    $auth = $self->{auth_handler};

    if ($auth->can_change_info($ENV{USERNAME})) {
        my $r = $auth->get_user_info($ENV{USERNAME});
        $tpl->assign(
            CAN_CHANGE_INFO => 1,
            PWD_QUESTION => $r->{question},
            PWD_ANSWER => $r->{answer},
        );
    }

    $tpl->assign(
        SIGNATURE => read_signature()
    );
}

# pref_save must be called before any tpl was assign and output
# or some of tpl will have different value.
sub pref_save {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $user_config = './user.cf';
    my $config = Ext::Config->new(file => $user_config);
    my $CFG = $config->dump || {};
    my $oldconfig = $self->userconfig;

    $CFG->{nick_name} = $q->cgi('nick_name');
    $CFG->{full_header} = $q->cgi('full_header')? 1:0;
    $CFG->{ccsent} = $q->cgi('ccsent')? 1:0;
    $CFG->{trylocal} = $q->cgi('trylocal') eq 1? 1:0;
    $CFG->{show_html} = $q->cgi('show_html') ? 1:0;
    $CFG->{compose_html} = $q->cgi('compose_html') ?1:0;
    $CFG->{conv_link} = $q->cgi('conv_link') ? 1:0;
    $CFG->{addr2abook} = $q->cgi('addr2abook') ? 1:0;
    $CFG->{pop_on} = $q->cgi('pop_on') ? 1:0;
    $CFG->{pop_timeout} = $q->cgi('pop_timeout');
    $CFG->{pop_files} = $q->cgi('pop_files');

    $CFG->{page_size} = $q->cgi('page_size');
    $CFG->{screen} = $q->cgi('screen_type');
    $CFG->{timezone} = $q->cgi('timezone');
    $CFG->{sort} = $q->cgi('sort') || 'by_time';
    $CFG->{lang} = $q->cgi('lang');
    $CFG->{delmode} = $q->cgi('delmode');
    $CFG->{template} = $q->cgi('template');
    $CFG->{charset} = 'UTF-8'; # XXX :-) now everything is UTF8

    $config->{cfg} = $CFG; # XXX without it, newly create
                           # user.cf would be save correctly!
    $config->save(file => $user_config);
    save_signature($q->cgi('signature'));
    undef $config;

    # new update style mechanism - 2005-09-26, assign a refresh
    # flag to notice template to force update the whole world
    if($oldconfig->{template} ne $q->cgi('template') or
       $oldconfig->{lang} ne $q->cgi('lang')) {
        $tpl->assign(REFRESH => 1);
    }

    # after save all, force userconfig() to update cache to
    # currently locale, XXX
    $self->userconfig(1);

    # re-initialize the world
    $self->global_tpl;
    $self->_initme;

    # call password after re-initialize
    # must call change_info first, which need to verify old password
    # first, then change. be careful :-)
    $self->pref_change_info;
    $self->pref_change_passwd;
    $self->pref_list;

    # if you want to redirect, uncomment the following code
    #$self->{tpl}->{noprint} = 1;
    #$self->redirect("?__mode=pref_list&sid=".$q->cgi('sid'));
}

sub pref_change_info {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $sys = $self->{sysconfig};

    return unless (my $oldpwd = $q->cgi('oldpw'));

    my $auth;
    if (!$self->{auth_handler}) {
        $self->pre_auth;
    }
    $auth = $self->{auth_handler};

    return unless $auth;

    if ($auth->can_change_info($ENV{USERNAME})) {
        my $rc = $auth->change_info(
            username => $ENV{USERNAME},
            oldpwd => $oldpwd,
            question => $q->cgi('pwd_question'),
            answer => $q->cgi('pwd_answer'));
        if ($rc) {
            $tpl->assign(CHGINFO_FAIL => $rc);
        } else {
            $tpl->assign(CHGINFO_OK => $lang_pref{'change_info_ok'});
        }
    } else {
        $tpl->assign(CHGINFO_FAIL => $lang_pref{'change_info_fail'});
    }
}

sub pref_change_passwd {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $sys = $self->{sysconfig};

    return unless((my $oldpwd = $q->cgi('oldpw')) &&
        $q->cgi('newpw1') && $q->cgi('newpw2'));

    my $pass_fail = $lang_pref{'change_passwd_fail'};
    my $pass_ok = $lang_pref{'change_passwd_ok'};
    my $pass_short = $lang_pref{'change_passwd_short'};

    if($q->cgi('newpw1') eq $q->cgi('newpw2')) {
        my $newpwd = $q->cgi('newpw1');
        return unless($self->pre_auth); # prepare auth

        # check new password length
        if(length($newpwd) < $sys->{SYS_MIN_PASS_LEN}) {
            $pass_short = sprintf($pass_short, $sys->{SYS_MIN_PASS_LEN});
            $tpl->assign( CHGPWD_FAIL => $pass_short);
            return;
        }

        if ($ENV{OPTIONS} =~ /disablepwdchange/) {
            $tpl->assign( CHGPWD_FAIL => $lang_pref{'change_passwd_disabled'} );
            return;
        }

        my $auth = $self->{auth_handler};
        if($auth->change_passwd($ENV{USERNAME}, $oldpwd, $newpwd)) {
            $tpl->assign( CHGPWD_OK => $pass_ok );
        }else {
            $tpl->assign( CHGPWD_FAIL => $pass_fail );
        }
    }else {
        $tpl->assign( CHGPWD_FAIL => $pass_fail );
    }
}

sub pref_page_size {
    my @pref_page_size = (10,20,50,100,200,300);
    \@pref_page_size;
}

sub pref_sort {
    my %sort_order = (
        'by_time' => 'Ts',
        'by_date' => 'Dt',
        'by_size' => 'Sz',
        'by_from'=> 'Fr',
        'by_subject' => 'Sj',
        'by_status' => 'Fs');
    \%sort_order;
}

sub pref_lang {
    my $self = shift;
    my $ref = langlist(); # func in Ext::Lang
    $ref;
}

sub pref_theme {
    my $self = shift;
    my $html_dir = $self->{sysconfig}->{SYS_TEMPLDIR};
    my %theme;

    opendir(DIR, $html_dir) or die "Can't opendir $html_dir, $!\n";
    foreach my $d ( grep { !/^\./ } readdir DIR) {
        if(-d "$html_dir/$d" && -r "$html_dir/$d/README") {
            open(FD, "< $html_dir/$d/README"); # ignore error
            while(<FD>) {
                next if(/^#/); # ignore comments
                chomp;
                my($i18n, $desc) = (/([^:]+):(.*)/);
                $theme{$d}->{$i18n} = ($desc?$desc:$i18n);
            }
            close FD;
        }
    }
    close DIR;
    \%theme;
}

sub save_signature {
    my $s = shift;
    open (FD, "> signature.cf") or die "Can't write to signature.cf, $!\n";
    print FD $s;
    close FD;
}

sub read_signature {
    return "" if (!-r 'signature.cf');
    open (FD, "< signature.cf"); # ignore error
    local $/ = undef;
    my $buf = <FD>;
    close FD;
    return $buf;
}

sub pop3_list {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};

    my $arr = parse_pop3config();
    if (scalar @$arr) {
        my $num = 1;
        for my $hash (@$arr) {
            $tpl->assign(
                'POP3LIST_LOOP',
                NUM => $num,
                POP3_UID => $hash->{uid},
                POP3_BACKUP => ($hash->{backup} eq 'on' ? 1 : 0),
                POP3_ACTIVE => ($hash->{active} eq 'on' ? 1 : 0),
                POP3_SERVER => "$hash->{host}:$hash->{port}",
            );
            $num ++;
        }
    } else {
        $tpl->assign( NOPOP3DEF => 'No pop3 accounts defined!');
    }

    if (my $uid = $q->cgi('edit')) {
        my $edit = '';
        for my $hash (@$arr) {
            next if (lc $hash->{uid} ne lc $uid);
            $edit = $hash;
            last;
        }

        if ($edit) {
            $tpl->assign(
                EDIT_ACCOUNT => 1,
                EDIT_UID => $edit->{uid},
                EDIT_HOST => $edit->{host},
                EDIT_PORT => $edit->{port},
                EDIT_BACKUP => $edit->{backup} eq 'on' ? 1 : 0,
                EDIT_ACTIVE => $edit->{active} eq 'on' ? 1 : 0,
            );
        } else {
            $tpl->assign( ERROR => "No such $uid" );
        }
    }

    $tpl->{template} = 'pref_pop3.html';
    1;
}

sub pop3_save {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $arr = parse_pop3config();
    my $err = '';

    my $uid = $q->cgi('username');
    my $pass = $q->cgi('passwd');
    my $host = $q->cgi('host');
    my $port = $q->cgi('port');
    my $backup = $q->cgi('backup');
    my $active = $q->cgi('active');

    # fallback setting;
    if (!$host or !$host =~ /[^\.]/) {
        $uid =~ /@(.*)$/;
        if (my $domain = $1) {
            $host = "pop3.$domain";
        }
    }

    if (!$port =~ /^\d+$/) {
        $port = '110';
    }

    if ($q->cgi('doedit')) {
        if (scalar @$arr) {
            my $write = 0;

            if (!($uid =~ /^[^@]+@\S+$/) || !$pass) {
                $err = $lang_pref{'err_pop3_account'};
            }

            # check for modification to the specific entry
            for (my $i=0; $i < scalar @$arr; $i++) {
                my $h = $arr->[$i];
                if ( lc $h->{uid} eq lc $uid ) {
                    if (length $pass) {
                        $pass = encode_base64($pass);
                        $pass =~ s/[\r\n\s]+//g;
                        $h->{passwd} = $pass;
                    } else {
                        $h->{passwd} = encode_base64($h->{passwd});
                        $h->{passwd} =~ s/[\r\n\s]+//g;
                    }

                    $h->{uid} = $uid;
                    $h->{host} = $host;
                    $h->{port} = $port || '110';
                    $h->{backup} = $backup ? 'on' : 'off';
                    $h->{active} = $active ? 'on' : 'off';

                    $arr->[$i] = $h;
                    $write = 1;
                } else {
                    $h->{passwd} = encode_base64($h->{passwd});
                    $h->{passwd} =~ s/[\r\n\s]+//g;
                    $arr->[$i] = $h;
                }
            }

            if ($write) {
                open (FD, "> pop3config.cf")
                    or die "Can't write to pop3config.cf, $!\n";
                flock (FD, LOCK_EX);
                for my $h (@$arr) {
                    my $option ='';
                    $option .= 'backup='.($h->{backup} eq 'on' ? 'on' : 'off').',';
                    $option .= 'active='.($h->{active} eq 'on' ? 'on' : 'off').',';
                    $option .= 'color=cccccc'; # XXX FIXME

                    print FD "$h->{uid} $h->{passwd} $h->{host} $h->{port} $option\n";
                }
                flock (FD, LOCK_UN);
                close FD;
            } else {
                $err = $lang_pref{'err_pop3_request'};
            }
        } else {
            $err = 'Empty pop3config, should add new entry first';
        }
    } elsif ($q->cgi('doadd')) {
        if (my $total = scalar @$arr) {
            if ($total >= 6) {
                $err = $lang_pref{'err_pop3_entry'};
            }elsif (!($uid=~/^[^@]+@\S+$/) || !$pass) {
                $err = $lang_pref{'err_pop3_badinfo'};
            }

            for my $hash (@$arr) {
                if (lc $hash->{uid} eq lc $uid) {
                    $err = sprintf($lang_pref{'err_pop3_exists'}, $uid);
                    last;
                }
            }

            if (!$err) {
                open (FD, ">> ./pop3config.cf") or die "$!\n";
                flock (FD, LOCK_EX);
                $pass = encode_base64($pass);
                $pass =~ s/[\r\n\s]+//g;
                my $option ='';

                $option .= 'backup='.($backup? 'on' : 'off').',';
                $option .= 'active='.($active? 'on' : 'off').',';
                $option .= 'color=cccccc'; # XXX FIXME

                print FD "$uid $pass $host $port $option\n";
                flock (FD, LOCK_UN);
                close FD;
            }
        } else {
            if (!($uid =~ /^[^@]+@\S+$/) || !$pass) {
                $err = $lang_pref{'err_pop3_account'};
            } else {
                # new add
                open (FD, " > ./pop3config.cf") or die "$!\n";
                flock (FD, LOCK_EX);
                $pass = encode_base64($pass);
                $pass =~ s/[\r\n\s]+//g;
                my $option = '';

                $option .= 'backup='.($backup? 'on' : 'off').',';
                $option .= 'active='.($active? 'on' : 'off').',';
                $option .= 'color=cccccc'; # XXX FIXME

                print FD "$uid $pass $host $port $option\n";
                flock (FD, LOCK_UN);
                close FD;
            }
        }
    } elsif ($q->cgi('dodelete')) {
        my $a = $q->cgi_full_names;
        my @del = grep { /^REMOVE-/ } @$a;

        open (FD, " > ./pop3config.cf") or die "$!\n";
        flock (FD, LOCK_EX);
        for my $h (@$arr) {
            my $remove = 0;
            for my $d (@del) {
                if (lc $h->{uid} eq lc $q->cgi($d)) {
                    $remove= 1;
                    last;
                }
            }
            if (!$remove) {
                $h->{passwd} = encode_base64($h->{passwd});
                $h->{passwd} =~ s/[\r\n\s]+//g;
                my $option = '';

                $option .= 'backup='.($h->{backup} eq 'on' ? 'on' : 'off').',';
                $option .= 'active='.($h->{active} eq 'on' ? 'on' : 'off').',';
                $option .= 'color=cccccc'; # XXX FIXME

                print FD "$h->{uid} $h->{passwd} $h->{host} $h->{port} $option\n";
            }
        }
        flock (FD, LOCK_UN);
        close FD;
    }
    if ($err) {
        $tpl->assign(ERRMSG => $err);
    }
    $self->pop3_list;
}

sub pref_timezone {
    my @t = (
        {key => '+13:00', value => '+1300'},
        {key => '+12:00', value => '+1200'},
        {key => '+11:00', value => '+1100'},
        {key => '+10:00', value => '+1000'},
        {key => '+09:00', value => '+0900'},
        {key => '+08:00', value => '+0800'},
        {key => '+07:00', value => '+0700'},
        {key => '+06:00', value => '+0600'},
        {key => '+05:00', value => '+0500'},
        {key => '+04:00', value => '+0400'},
        {key => '+03:00', value => '+0300'},
        {key => '+02:00', value => '+0200'},
        {key => '+01:00', value => '+0100'},
        {key => '00:00', value => '+0000'},
        {key => '-01:00', value => '-0100'},
        {key => '-02:00', value => '-0200'},
        {key => '-03:00', value => '-0300'},
        {key => '-04:00', value => '-0400'},
        {key => '-05:00', value => '-0500'},
        {key => '-06:00', value => '-0600'},
        {key => '-07:00', value => '-0700'},
        {key => '-08:00', value => '-0800'},
        {key => '-09:00', value => '-0900'},
        {key => '-10:00', value => '-1000'},
        {key => '-11:00', value => '-1100'},
    );
    \@t;
}

sub pref_poptimeout {
    shift;
    ['15','30'];
}

sub pref_popfiles {
    shift;
    ['15','30','50','100'];
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || $_[0]->{tpl}->{template} || 'pref.html';
    reset_working_path();
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
