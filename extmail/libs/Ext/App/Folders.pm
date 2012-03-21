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
package Ext::App::Folders;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT $t0 $t1 $t2 $t3 $t4);
use vars qw($user_page_size);
@ISA = qw(Exporter Ext::App);

use Ext::App;
use Ext::MIME;
use Ext::DateTime;
use Ext::Utils;
use Ext::MailFilter;
use Ext::RFC822; # import date_fmt
use Ext::POP3;
use Ext::Abook; # to support friends display
use Ext::Storage::Maildir;
use Benchmark;

use vars qw(%lang_folders $lang_charset);
use Ext::Lang;
use Ext::Unicode;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(folders_list => \&folders_list);
    $self->add_methods(messages_list => \&messages_list);
    $self->add_methods(folders_mgr => \&folders_mgr);
    $self->add_methods(messages_mgr => \&messages_mgr);

    $self->{default_mode} = 'folders_list';
    Ext::Storage::Maildir::init($self->get_working_path);
    $t0 = new Benchmark;

    $self->_initme;

    if(my $FOLDER = $self->{query}->cgi('folder')) {
        if (!valid_maildir($FOLDER)) {
            $self->error($lang_folders{'err_name_invalid'});
        }
    }
    $self;
}

sub _initme {
    initlang($_[0]->userconfig->{lang}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_folders );
}

# varibles defination:
# edit => the dir to edit(delete or rename)
# foldername => the input field, for rename or mkdir
# oldfolder => original folder name
sub folders_mgr {
    my $self = shift;
    my $q = $self->{query};
    my $dir = fixpath($q->cgi('foldername'));
    my $edit = $q->cgi('edit');
    my $sid = fixpath($q->cgi('sid'));
    my $errmsg = undef;
    my $filter = '';
    my $utf8 = Ext::Unicode->new;

    if ($edit) {
        $self->{tpl}->assign(
            MOD_EDIT => 1,
            OLDFOLDER => str2url($edit),
            OLDFOLDER_NAME => $utf8->decode_imap_utf7($edit),
        );
    }

    $dir =~ s/\s+//g; # remove space
    # return if no foldername specify
    # return 0 unless($dir);

    if ($q->cgi('__combine_mode')) {
        eval {
            my $func = $q->cgi('__combine_mode');
            $self->$func;
        };
        if ($@) {
            $self->error("$@");
            return;
        }
    }

    # XXX check is the request in filtering rules or not,
    # if yes , stop processing the request because some
    # rules need the folder, if change or delete, filtering
    # programe will fail to process filter rule
    if ($self->{sysconfig}->{SYS_MFILTER_ON}) {
        $filter = new Ext::MailFilter;
    }

    if ($q->cgi('mkdir')) {
        if (length($dir)<2) {
            $self->error($lang_folders{err_tooshort});
            return;
        }
        if (!foldername_ok($dir, 45)) {
            $self->error($lang_folders{err_name_invalid});
            return;
        }
        my $utf7_dir = $utf8->encode_imap_utf7($dir);
        $errmsg = sprintf($lang_folders{err_mkdir}, $dir)
            unless mk_maildir($utf7_dir);
    } elsif ($q->cgi('rmdir')) {
        my $del = fixpath($q->cgi('oldfolder'));

        # if is_subdir() fail, then the folder name maybe utf7 encoded
        if (! is_subdir($del)) {
            # we are handling utf7 encoded maildir name
            $del = $utf8->encode_imap_utf7($utf8->decode_imap_utf7($del));
        }

        if (!$del or length($del)<2) {
            $self->error($lang_folders{err_tooshort});
            return;
        }
        if ($filter && (my $rv = $filter->dir_inrule($del))) {
            $self->error(sprintf($lang_folders{err_rmdir_inrule}, $utf8->decode_imap_utf7($del),$rv));
            return;
        }
        $errmsg = sprintf($lang_folders{err_rmdir}, $utf8->decode_imap_utf7($del))
            unless rm_maildir($del);
        re_calculate();
    } elsif ($q->cgi('rename')) {
        my $old = fixpath(url2str($q->cgi('oldfolder')));
        my $new = $dir;
        my $utf7_old;

        if (! is_subdir($old)) {
            # we are handling utf7 encoded maildir name
            # XXX FIXME decode it first then encode it, see explanation below
            $utf7_old = $utf8->encode_imap_utf7($utf8->decode_imap_utf7($old));
        } else {
            $utf7_old = $old;
        }

        if (length($new)<2) {
            $self->error($lang_folders{err_tooshort});
            return;
        }
        if ($filter && (my $rv = $filter->dir_inrule($utf7_old))) {
            $self->error(sprintf($lang_folders{err_rename_inrule}, $utf8->decode_imap_utf7($old), $rv));
            return;
        }
        if (!foldername_ok($new, 45)) {
            $self->error($lang_folders{err_name_invalid});
            return;
        }
        # XXX FIXME decode it first then encode it, if we are handling utf7 encoded
        # folder name, then we must decode it then encode it; if we are handling
        # non-utf7 encoded folder name, then we still need to encode it again.

        my $utf7_new = $utf8->encode_imap_utf7($new);

        $errmsg = sprintf($lang_folders{err_rename}, $old)
            unless mv_maildir($utf7_old, $utf7_new);
    } elsif ($q->cgi('purge')) {
        my $utf7_dir = $utf8->encode_imap_utf7($utf8->decode_imap_utf7($dir));

        $errmsg = sprintf($lang_folders{err_purge}, $utf8->decode_imap_utf7($dir))
            unless purge_maildir($utf7_dir);
        re_calculate();
    }

    if (defined $errmsg) {
        $self->error($errmsg);
        return;
    }

    if($q->cgi('redirect')) {
        $self->{tpl}->{noprint} = 1;
        $self->redirect("?__mode=folders_list&sid=$sid");
    }
}

sub messages_mgr {
    my $self = shift;
    my $q = $self->{query};
    my $dir = fixpath($q->cgi('folder'));
    my $sid = fixpath($q->cgi('sid'));
    my $page = $q->cgi('page');

    $self->{tpl}->{noprint} = 1;

    my %pos = ();
    my $a = $q->cgi_full_names;
    for my $p (grep { s/^MOVE-// } @$a) {
        my $msgid = $q->cgi("MOVE-$p");
        $pos{$p} = $msgid;
    }
    if($q->cgi('delete')) {
        if ($self->userconfig->{delmode} eq 'purge') {
            set_bmsgs_delete($dir, %pos);
        } else {
            # mode == delete then move to trash
            if ($dir eq 'Trash') {
                set_bmsgs_delete($dir, %pos);
            } else {
                set_bmsgs_move($dir, 'Trash', %pos);
            }
        }
    }
    if($q->cgi('move')) {
        # interface params: srcdir distdir @pos
        set_bmsgs_move($dir, fixpath($q->cgi('distfolder')), %pos);
    }
    if($q->cgi('setmsg')) {
        my $op = $q->cgi('msgflag');
        for my $p (keys %pos) {
            set_msg_status($dir, $p, $op);
        }
    }
    if ($q->cgi('report')) {
        my $app = $self->{sysconfig}->{SYS_SPAM_REPORT_TYPE} || 'dspam';
        my $app_root = "$self->{sysconfig}->{SYS_CONFIG}/tools";
        my $prefix = $ENV{MAILDIR} . '/' . _name2mdir($dir) . '/cur';

        local $ENV{PATH} = '';

        if ($dir ne 'Junk') {
            my $cmd = untaint("$app_root/spam_report.pl --type=$app --report_spam --multiple");
            open (CMD, "|$cmd") or die "Report Error";
            for my $p (keys %pos) {
                my $file = Ext::Storage::Maildir::pos2file($dir, $p);
                print CMD "$prefix/$file\n";
            }
            close CMD;

            set_bmsgs_move($dir, 'Junk', %pos);
        } else {
            my $cmd = untaint("$app_root/spam_report.pl --type=$app --report_nonspam --multiple");
            open (CMD, "|$cmd") or die "Report Error";
            for my $p (keys %pos) {
                my $file = Ext::Storage::Maildir::pos2file($dir, $p);
                print CMD "$prefix/$file\n";
            }
            close CMD;

            set_bmsgs_move($dir, 'Inbox', %pos);
        }
    }

    # must encode as url
    $dir = str2url($dir);
    $self->redirect("?__mode=messages_list&sid=$sid&folder=$dir&page=$page");
}

sub folders_list {
    my $self = shift;
    my $tpl = $self->{tpl};

    $t1 = new Benchmark;
    my @list = get_dirs_list;

    $tpl->assign(FOLDERS_LIST=>1);

    # pop3 here
    my $pp;
    if ($self->userconfig->{pop_on}) {
        $pp= parse_pop3config();
    }

    if (scalar $pp && $self->{query}->cgi('chkpop')) {
        my $timeout = $self->userconfig->{pop_timeout};
        my $files = $self->userconfig->{pop_files};

        my $obj = new Ext::POP3;
        my $checked = 0;

        for my $pop (@$pp) {
            if ($pop->{active} ne 'on') {
                next;
            }
            if ($obj->can_receive) {
                $checked = 1 unless ($checked);

                $obj->init(
                    user => $pop->{uid},
                    passwd => $pop->{passwd},
                    host => $pop->{host},
                    port => $pop->{port} || '110',
                    backup => $pop->{backup} eq 'on' ? 1 : 0,
                    timeout => $timeout,
                    max_files => $files,
                );

                my $rc = $obj->receive;
                $obj->close;
            }
        }

        $obj->finish; # kill the pop session
        # XXX end of pop3
        if ($checked) {
            if (my $err = $obj->error) {
                for (split(/\n/, $err)) {
                    $tpl->assign(
                        'LOOP_POP3ERR',
                        POP3ERR => ref $_ ? "@$_" : $_
                    );
                }
            } else {
                $tpl->assign(POP3OK => 'POP3 Retrieve OK!');
            }
        }
    }

    foreach (@list) {
        my $t0 = new Benchmark;
        check_new($_); # check_new first
        my $t1 = new Benchmark;
        my ($diff) = (timestr(timediff($t1, $t0)) =~ /= (.*) CPU/);
    }

    $t2 = new Benchmark;
}

sub messages_list {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $utf8 = Ext::Unicode->new;
    my %abook = map { lc $_->[1] => ( $_->[1] ? 1: 0 ) } @{
        Ext::Abook->new(
            file => 'abook.cf',
            type => 'abook')->ab_dump
    };

    my $fd = fixpath($q->cgi("folder"));
    my $sid = fixpath($self->{sid});
    my $list = undef;
    my ($nonext, $noprev, $nofirst, $nolast);
    my $prefix = $ENV{MAILDIR}.'/'.($fd eq 'Inbox'?'.':".$fd").'/cur';

    $tpl->assign(MESSAGES_LIST=>1);
    # for spam / nonspam report
    if ($self->{sysconfig}->{SYS_SPAM_REPORT_ON}) {
        $tpl->assign(CAN_REPORT_SPAM => 1);
        if ($fd ne 'Junk') {
            $tpl->assign(REPORT_AS_SPAM => 1);
        } else {
            $tpl->assign(REPORT_AS_NONSPAM => 1);
        }
    }

    $t1 = new Benchmark;

    # Sort cache on demand
    my $sort_order = $self->userconfig->{sort};
    if($q->cgi('resort')) {
        $sort_order = name2sort($q->cgi('resort'));
        rebuild_msgs_cache($fd, $sort_order);
    }else {
        set_msgs_cache($fd, $sort_order);
    }

    # show purge hint or not
    if ($self->userconfig->{delmode} eq 'purge' || $fd eq 'Trash') {
        $tpl->assign( HINT_PURGE => 1);
    } else {
        $tpl->assign( HINT_PURGE => 0);
    }

    # show sort order, using i18n XXX
    # Internal mechanism: check $order for by_xxx_rev <--, if found, set
    # flag_rev true, then strip out sort type(exclude _rev), then template
    # can easily identify which sort type is currently used and whether
    # in reverse mode or not
    my $order = Ext::Utils::sort2name(get_sortorder($fd)); # Dt, rSz etc...
    $tpl->assign(SORT_ORDER => $lang_folders{$order});
    my($flag_rev) = ($order =~/_rev/?1:0);
    $order =~s/_rev//; # this only indicate sort type, not asc/desc
    $tpl->assign(
        'flag_'.$order.'_rev' => $flag_rev,
        'flag_'.$order => 1,
        CURPAGE => $q->cgi('page'),
    );

    $t2 = new Benchmark;
    ($list, $nonext) = $self->paging($self, $fd, $q->cgi('page'));
    $tpl->assign(FOLDER => str2url($fd)); # XXX str2url
    $tpl->assign(R_FOLDER => $fd); # raw folder name, XXX must exist

    if($fd =~ /^(Drafts|Sent)$/) {
        $tpl->assign(REV_FROM => 1);

        # XXX change link to edit drafts for user
        $tpl->assign(FOLDER_DRAFTS => 1) if ($fd eq 'Drafts');
    }

    $tpl->assign(HAVEMSGLIST => 1) if (keys %$list);

    foreach my $pos (sort {$a<=>$b} keys %$list) {
        my $file = $list->{$pos}->{FILENAME};
        my ($size) = $list->{$pos}->{SIZES};
        my $flag_att = ($file =~ /:.*(A).*/) ? 1:0;
        my $flag_new = ($file =~ /:.*(S).*/) ? 0:1;

        # XXX advoid special char corupt the html output, caution:
        # do not use my($var1, $var2..) = xxx, it will fall into a
        # trap. If one of the values is "" or null, then the later
        # value will replace it, causing value mismatch XXX

        for (qw(FROM SUBJECT)) {
            next unless $list->{$pos}->{$_};
            next unless $list->{$pos}->{$_} =~ /=\?[^?]*\?[QB]\?[^?]*\?=/;
            $list->{$pos}->{$_} =~ s/(\?=)\s+(=\?)/$1$2/g;
        }

        # die $list->{$pos}->{FROM} if length $list->{$pos}->{FROM} > 20;
        my $addr = rfc822_addr_parse(decode_words_utf8($list->{$pos}->{FROM}));
        my $from = $addr->{name}; # get the name part only
        my $subject = decode_words_utf8($list->{$pos}->{SUBJECT});
        my $date = $list->{$pos}->{DATE};
        my $timezone = $self->userconfig->{timezone};

        my $sjchar;
        TRY: {
            my $subject = decode_words($list->{$pos}->{SUBJECT});
            $subject =~ s/\s+//; # remove space
            my $c = charset_detect($subject);
            if ($c =~ /^(windows-1252|iso-8859-)/ && length $subject < 6) {
                $sjchar = charset_detect(decode_words($list->{$pos}->{FROM}));
            } else {
                $sjchar = $c;
            }
        }
        $from = iconv($from, $sjchar, 'utf-8') if charset_detect($from) ne 'utf-8';
        $subject = iconv($subject, $sjchar, 'utf-8') if charset_detect($subject) ne 'utf-8';

        # truncate to a limit size, or long line will break the
        # view of html, but truncate function should rewrite to beter
        # display characters
        my $tr = $self->get_screen($self->userconfig->{screen});

        if ($tr->[0] && length $from > $tr->[1]) {
            $from=substr($from, 0, $tr->[0])."...";
        }

        if($tr->[1] && length $subject > $tr->[1]) {
            $subject=substr($subject,0, $tr->[1])."...";
        }

        $tpl->assign(
            'LOOP_SUBLIST', # Must be quote, or die under strict
            POS => $pos,
            FILE => $file,
            MSGID => $file,
            SUBJECT => html_escape($subject=~/\S+/ ? $subject : $lang_folders{notitle} || 'No Title'),
            FROM => html_escape($from),
            DATE => date_fmt('%s, %s %s:%s', $date), # XXX FIXME
            SHORTDATE => dateserial2str(datefield2dateserial($date), $timezone, 'auto','stime', 12),
            SIZE => $size,
            FATT => $flag_att,
            FNEW => $flag_new,
            FROMCONTACT => $abook{$addr->{addr}} ? 1 : 0,
        );
    }

    # page index
    my $inf = get_dir_cnt($fd);
    my $usercfg = $self->userconfig();
    # global varible initialize
    $user_page_size = $usercfg->{page_size};

    # jklin use ceil() from POSIX, here we use myceil() from Utils.pm
    my $total_pages = myceil(($inf->{new}+$inf->{seen})/$user_page_size);

    for(my $i = 1; $i <= $total_pages; $i++) {
        $tpl->assign(
            'LOOP_PAGES',
            PAGE_VALUE => $i-1,
            PAGE_TEXT => "$i / $total_pages",
            IS_SELECTED => ($i-1)==$q->cgi('page')?1:0
        );
    }

    $t3 = new Benchmark;
    my $prev = ($q->cgi("page") ? $q->cgi("page") -1 : 0);
    my $next = ($q->cgi("page") ? $q->cgi("page") +1 : 1);
    my $first = 0;
    my $last = $total_pages-1;

    if($q->cgi('page') eq $prev) {
        $noprev = 1;
    }
    if(!$q->cgi('page')) {
        $noprev = 1;
    }

    $nofirst = $q->cgi('page') <= 0?1:0;
    $nolast = ($q->cgi('page') >= ($total_pages-1)) || ($total_pages<=1)?1:0;

    my $curdir = fixpath($q->cgi('folder'));

    # setting up default conversion charset
    $utf8->set_charset($lang_charset);

    $tpl->assign(
        FOLDER2=> str2url($curdir), # XXX should str2url
        FOLDER2_NAME => $lang_folders{$curdir} ? $lang_folders{$curdir} : $utf8->decode_imap_utf7($curdir),
        PREV => $prev,
        NEXT => $next,
        FIRST => $first,
        LAST => $last,
        HAVE_PREV => $noprev?0:1,
        HAVE_NEXT => $nonext?0:1,
        HAVE_FIRST => $nofirst?0:1,
        HAVE_LAST => $nolast?0:1,
        NEED_PAGING => $total_pages <=1?0:1,
    );

    my @list = get_dirs_list;
    for(@list) {
        next if($fd eq $_); # ignore the current folder XXX
        # caution, template currently not support same VAR resuing
        # in the loop, ouch :-(
        my $name = $lang_folders{$_};
        $tpl->assign(
            'LOOP_FOLDERS',
            DISTFOLDER => $_,
            DISTNAME => $name ? $name : $utf8->decode_imap_utf7($_));
    }
    # $self->show_curquota;
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'folders.html';
    # dirty hack, to fallback original working path, ouch :-(
    reset_working_path();
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

sub paging {
    my $self = shift;
    my $usercfg = $self->userconfig();
    # global varible initialize
    $user_page_size = $usercfg->{page_size};
    my($obj, $dir, $page) = @_;

    if (!$page) { $page = 0; }
    my ($c,$nomore) = get_msgs_cache(
        $dir,
        $user_page_size,
        $user_page_size*$page
    );
    ($c, $nomore);
}

sub perf_time {
    my $tpl = shift->{tpl};
    if($t1 and $t0) {
        $tpl->assign(TIME1=> timestr(timediff($t1, $t0)));
    }

    if($t2 and $t1) {
        $tpl->assign(TIME2=> timestr(timediff($t2, $t1)));
    }

    if($t3 and $t2) {
        $tpl->assign(TIME3=> timestr(timediff($t3, $t2)));
    }
    if($t4 and $t3) {
        $tpl->assign(TIME4=> timestr(timediff($t4, $t3)));
    }
}

sub DESTORY {
}

1;
