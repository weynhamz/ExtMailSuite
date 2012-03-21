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
package Ext::App::Filter;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::App);
use Ext::App;
use Ext::MailFilter;
use Ext::Utils;
use Ext::Storage::Maildir;

use vars qw(%lang_filter $lang_charset);
use Ext::Lang;
use Ext::Unicode;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(add2list => \&add2list);
    $self->add_methods(filter_list => \&filter_list);
    $self->add_methods(filter_edit => \&filter_edit);
    $self->add_methods(rule_save => \&rule_save);
    $self->add_methods(extension_list => \&extension_list);
    $self->add_methods(extension_mgr => \&extension_mgr);
    $self->add_methods(edit_list => \&edit_list);
    $self->add_methods(edit_autoreply => \&edit_autoreply);

    $self->{default_mode} = 'filter_list';
    Ext::Storage::Maildir::init($self->get_working_path);

    $self->_initme;

    if (!$self->{sysconfig}->{SYS_MFILTER_ON}) {
        $self->error($lang_filter{'res_unavailable'} || "Mail Filter not available\n");
        return;
    }
    $self;
}

sub _initme {
    initlang($_[0]->userconfig->{lang}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_filter );
}

sub add2list {
    my $self = shift;
    my $obj = $_[0] || new Ext::MailFilter;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $r_blist = $obj->read_list('blacklist');
    my $r_wlist = $obj->read_list('whitelist');
    my $addr = lc $q->cgi('addr');

    unless ($q->cgi('white') || $q->cgi('black')) {
        $tpl->assign(ERRMSG => 'No such action');
        return;
    }

    for my $m (@$r_wlist, @$r_blist) {
        next unless $m eq $addr;
        $tpl->assign(ERRMSG => sprintf($lang_filter{add2list_exist}, $addr));
        return;
    }

    my $rv;
    if ($q->cgi('white')) {
        push @$r_wlist, $addr;
        $rv = $obj->save_list('whitelist', $r_wlist);
    }
    if ($q->cgi('black')) {
        push @$r_blist, $addr;
        $rv = $obj->save_list('blacklist', $r_blist);
    }

    if ($rv) {
        $tpl->assign(ERRMSG => sprintf($lang_filter{savefail}, $rv));
    } else {
        $tpl->assign(OKMSG => sprintf($lang_filter{saveok}));
    }
}

sub extension_list {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $obj = $_[0] || new Ext::MailFilter;

    # load extension
    my $whitelist = $obj->{whitelist};
    my $blacklist = $obj->{blacklist};
    my $spam2junk = $obj->{spam2junk};
    my $mail2sms  = $obj->{mail2sms};
    my $autoreply = $obj->{autoreply};
    my $forward = $obj->{forward};
    my $forwardcc = $obj->{forwardcc};

    $tpl->assign(
        WHITELIST_ON => $whitelist ? 1 : 0,
        BLACKLIST_ON => $blacklist ? 1 : 0,
        SPAM2JUNK_ON => $spam2junk ? 1 : 0,
        MAIL2SMS_ON  => $mail2sms ? 1 : 0,
        AUTOREPLY_ON => $autoreply ? 1 : 0,
        FORWARD_ON => $forward ? 1 : 0,
        FORWARD_ADDR => $forward,
        FORWARDCC_ON => $forwardcc ? 1 : 0,
    );

    #$self->{template} = 'filter_extension.html';
}

sub extension_mgr {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $obj = $_[0] || new Ext::MailFilter;

    if ($q->cgi('whitelist')) {
        if (!-r 'whitelist.cf') {
            $self->error($lang_filter{whitelist_error});
            return;
        }
        $obj->{whitelist} = 1;
    } else {
        $obj->{whitelist} = 0;
    }

    if ($q->cgi('blacklist')) {
        if (!-r 'blacklist.cf') {
            $self->error($lang_filter{blacklist_error});
            return;
        }
        $obj->{blacklist} = 1;
    } else {
        $obj->{blacklist} = 0;
    }

    if ($q->cgi('spam2junk')) {
        $obj->{spam2junk} = 1;
    } else {
        $obj->{spam2junk} = 0;
    }

    if ($q->cgi('mail2sms')) {
        $obj->{mail2sms} = 1;
    } else {
        $obj->{mail2sms} = 0;
    }

    if ($q->cgi('autoreply')) {
        if (!-r 'autoreply.cf') {
            $self->error($lang_filter{autoreply_error});
            return;
        }
        $obj->{autoreply} = 1;
    } else {
        $obj->{autoreply} = 0;
    }

    if ($q->cgi('forward')) {
        my $addr = $q->cgi('forwardaddr');
        if (!$addr or $addr=~ /^(\s+|)$/) {
            $self->error($lang_filter{forward_error});
            return;
        }
        $obj->{forward} = $addr;
        $obj->{forwardcc} = $q->cgi('forwardcc');
    } else {
        $obj->{forward} = '';
        $obj->{forwardcc} = '';
    }

    if (my $rv = $obj->save) {
        $tpl->assign(ERRMSG => sprintf($lang_filter{savefail}, $rv));
    } else {
        $tpl->assign(OKMSG => sprintf($lang_filter{saveok}));
    }
    $self->filter_list($obj);
}

sub edit_list {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $obj = $_[0] || new Ext::MailFilter;

    if ($q->cgi('save')) {
        if ($q->cgi('white')) {
            my $str = $q->cgi('whitelists');
            my @arr = split(/\s+/, $str);
            my $rv = $obj->save_list('whitelist', \@arr);
            if ($rv) {
                $tpl->assign(ERRMSG => sprintf($lang_filter{savefail}, $rv));
            } else {
                $tpl->assign(OKMSG => sprintf($lang_filter{saveok}));
                if ($q->cgi('wlenable') eq 'enable') {
                    $obj->{whitelist} = 1;
                } else {
                    $obj->{whitelist} = 0;
                }
            }
        }
        if ($q->cgi('black')) {
            my $str = $q->cgi('blacklists');
            my @arr = split(/\s+/, $str);
            my $rv = $obj->save_list('blacklist', \@arr);
            if ($rv) {
                $tpl->assign(ERRMSG => sprintf($lang_filter{savefail}, $rv));
            } else {
                $tpl->assign(OKMSG => sprintf($lang_filter{saveok}));
                 if ($q->cgi('blenable') eq 'enable') {
                     $obj->{blacklist} = 1;
                 } else {
                     $obj->{blacklist} = 0;
                 }
            }
        }
        # save filtering settings
        if (my $rv = $obj->save) {
            $tpl->assign(ERRMSG => sprintf($lang_filter{savefail}, $rv));
        } else {
            $tpl->assign(OKMSG => sprintf($lang_filter{saveok}));
        }
    }
    if ($q->cgi('white')) {
        my $ref = $obj->read_list('whitelist');
        for (@$ref) {
            $tpl->assign(
                'WHITELIST_LOOP',
                ADDR => $_,
            );
        }
    }

    if ($q->cgi('black')) {
        my $ref = $obj->read_list('blacklist');
        for (@$ref) {
            $tpl->assign(
                'BLACKLIST_LOOP',
                ADDR => $_,
            );
        }
    }
    $self->filter_list($obj);
    1;
}

sub edit_autoreply {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $obj = $_[0] || new Ext::MailFilter;
    my $reply_text = $q->cgi('content');

    if ($q->cgi('save')) {
        # currently only support text/plain, sorry
        my $type = 'text/plain';
        my $charset = $self->userconfig->{charset} || 'us-ascii';
        my $header = "Content-type: $type; charset=$charset\n";
        $header .= "Content-Transfer-Encoding: 8bit\n\n";

        my $rv = $obj->save_autoreply($header . $reply_text);
        if ($rv) {
            $tpl->assign(ERRMSG => sprintf($lang_filter{savefail}, $rv));
        } else {
            $tpl->assign(OKMSG => sprintf($lang_filter{saveok}));
            $obj->{autoreply} = $q->cgi('autoreply');
            $obj->save; # ignore error?
        }
    } else {
        $reply_text = $obj->read_autoreply;
    }

    # bug fix under FCGI, must convert \r\n => \n, but why?
    # $reply_text =~ s/\r+//sg;

    $tpl->assign(
        REPLY_TEXT => $reply_text,
        AUTOREPLY_ON => $obj->{autoreply} ? 1:0,
    );
    $self->{template} = 'autoreply.html';
}

sub filter_list {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $obj = $_[0] || new Ext::MailFilter;
    my $rules = $obj->{rules};

    $self->extension_list($obj); # show extension config
    return unless (scalar @$rules);

    $tpl->assign( HAVE_FILTER_LIST => 1 );
    for (my $i=0; $i<scalar @$rules; $i++) {
        my $rule = $rules->[$i];
        my $cond = '';
        my $exec = '';

        if ($rule->{from}) {
            $cond .= " from($rule->{from}) ";
        }
        if ($rule->{recipient}) {
            $cond .= " to($rule->{recipient}) ";
        }
        if ($rule->{subject}) {
            $cond .= " subj($rule->{subject}) ";
        }
        if ($rule->{options} =~ /Hasattach/) {
            $cond .= " has:attachment ";
        }

        for my $dir (@{$rule->{folder}}) {
            my $flag = substr($dir,0,1);
            my $folder = substr($dir,1);
            if ($flag eq '!') {
                $exec .= " cc($folder) ";
            } elsif ($flag eq '*') {
                $exec .= " bounce($folder) ";
            } elsif ($flag eq '.') {
                if ($folder eq '') {
                    $folder = 'Inbox';
                }
                $folder = imap_utf7_decode($folder);
                $exec .= " saveto($folder) ";
            }
        }
        if ($rule->{options}=~/Delete/) {
            $exec .= ' delete ';
        }
        $tpl->assign(
            'FILTER_LIST_LOOP',
            FILTER_NAME => $rule->{name},
            FILTER_ID => $i,
            FILTER_COND => $cond,
            FILTER_EXEC => $exec,
        );
    }
    1;
}

#
# How to works with edit/newadd in one function? use flag :-)
#
# filter_edit() --> cgi('add') --> rule_edit('newadd') -->
#               assign( NEWADD => 1 ) ==> rule_save() -->
#               rule_append() --> save()
#
# filter_edit() --> cgi('edit') --> rule_edit() -->
#               rule_save() --> rule_append() --> save()
sub filter_edit {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $obj = $_[0] || new Ext::MailFilter;
    my $rules = $obj->{rules};
    my $id = $q->cgi('fid');
    my $newadd = $q->cgi('add') || '0';

    if ($newadd) {
        $self->rule_edit('newadd');
        return;
    }

    unless ($id=~/^\d+$/ && $id>=0 && $id<= scalar @$rules-1) {
        $self->error('Invalid filter id');
        return;
    }

    if ($q->cgi('up')) {
        $obj->rules_up($id);
        $obj->save;
    } elsif ($q->cgi('down')) {
        $obj->rules_down($id);
        $obj->save;
    } elsif ($q->cgi('remove')) {
        $obj->rules_remove($id);
        $obj->save;
    } elsif ($q->cgi('edit')) {
        $self->rule_edit;
    }
    $self->filter_list;
}

sub rule_edit {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $obj = new Ext::MailFilter;
    my $rules = $obj->{rules};
    my $id = $q->cgi('fid');
    my $newadd = $_[0]; # new add or not?
    my $utf8 = Ext::Unicode->new;

    if ($newadd) {
        $tpl->assign(NEWADD => 1);
    } else {
        unless ($id=~/^\d+$/ && $id>=0 && $id<= scalar @$rules-1) {
            $self->error('Invalid filter id');
            return;
        }
    }

    my @dirs = get_dirs_list;
    my $rule = undef;
    unless ($newadd) {
        $rule = $rules->[$id];
    }
    $tpl->assign(RULE_NAME => $rule->{name});

    $tpl->assign(
        FROM => $rule->{from},
        TO => $rule->{recipient},
        SUBJECT => $rule->{subject},
        HASATTACH => $rule->{hasattach},
    );

    my $saveto = 0;
    my $savefolder;
    my $forwardto = 0;
    my $forwardaddr;
    my $delete = 0;
    my $bounce = 0;
    my $bouncemsg;

    for my $dir (@{$rule->{folder}}) {
        my $flag = substr($dir, 0, 1);
        if ($flag eq '.') {
            $saveto = 1;
            $savefolder = substr($dir, 1);
            # If null, we found Inbox
            $savefolder = 'Inbox' if (!$savefolder);
        } elsif ($flag eq '!') {
            $forwardto = 1;
            $forwardaddr = substr($dir, 1);
        } elsif ($flag eq '*') {
            $bounce = 1;
            $bouncemsg = substr($dir, 1);
        }
    }

    $tpl->assign(
        SAVETO => $saveto,
        FORWARD_VALUE => $forwardaddr,
        FORWARDTO => $forwardto,
        BOUNCE => $bounce,
        REJECT_VALUE => $bouncemsg,
    );

    for (@dirs) {
        my $name = $lang_filter{$_};
        my $check = $savefolder;
        $tpl->assign(
            'FOLDER_LIST_LOOP',
            FOLDER => str2url($_),
            FOLDER_NAME => $name ? $name : $utf8->decode_imap_utf7($_),
            FOLDER_THIS_CHECK => ($check eq $_ ? 1 : 0),
        )
    }

    if ($rule->{options}) {
        for my $o (split(/ /, $rule->{options})) {
            if ($o eq 'Delete') {
                $tpl->assign(DELETE => 1);
                $delete = 1;
            } elsif ($o eq 'Hasattach') {
                $tpl->assign(HASATTACH => 1);
            }
        }
    }

    $tpl->assign( FID => $id );
    $self->{template} = 'filter_edit.html';
}

sub rule_save {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $obj = new Ext::MailFilter;
    my $rules = $obj->{rules};
    my $id = $q->cgi('fid');
    my $newadd = $q->cgi('newadd');

    if ($id=~/^\d+$/) {
        if ($id<0 or $id>scalar @$rules-1) {
            $self->error('No such filter id');
            return;
        }
    }

    my $rule = ();
    my $rulename = $q->cgi('rulename');
    my $from = $q->cgi('from');
    my $subject = $q->cgi('subject');
    my $to = $q->cgi('to');
    my $hasattach = $q->cgi('hasattach');

    my $saveto = $q->cgi('saveto');
    my $savefolder = $q->cgi('savefolder');
    my $forwardto = $q->cgi('forwardto');
    my $forwardaddr = $q->cgi('forwardaddr');
    my $delete = $q->cgi('delete');
    my $bounce = $q->cgi('bounce');
    my $bouncemsg = $q->cgi('bouncemsg');

    if ($rulename =~/^(\s+|)$/ or (
            !$from &&
            !$subject &&
            !$to &&
            !$hasattach) or (
            !$saveto &&
            !$forwardto &&
            !$delete &&
            !$bounce)) {
        $self->error($lang_filter{'input_err'});
        return;
    }

    $rule->{name} = $rulename;
    $rule->{from} = $from;
    $rule->{subject} = $subject;
    $rule->{recipient} = $to;
    $rule->{hasattach} = $hasattach;

    if ($saveto) {
        # XXX must unescape it, savefolder is escaped
        my $folder = url2str($q->cgi('savefolder'));
        if ($folder eq 'Inbox') {
            $rule->{folder} = ['.'];
        } else {
            $rule->{folder} = [".$folder"];
        }
    }
    if ($forwardto) {
        if (!$forwardaddr or $forwardaddr =~ /^\s+$/) {
            $self->error($lang_filter{'input_err'});
            return;
        }
        if ($rule->{folder}) {
            push @{$rule->{folder}}, "!$forwardaddr";
        } else {
            $rule->{folder} = ["!$forwardaddr"];
        }
    }
    if ($bounce) {
        if (!$bouncemsg) {
            $self->error($lang_filter{'input_err'});
            return;
        }
        if ($rule->{folder}) {
            push @{$rule->{folder}}, "*$bouncemsg";
        } else {
            $rule->{folder} = ["*$bouncemsg"];
        }
    }

    if ($delete) {
        $rule->{options} = 'Delete';
        if ($rule->{folder}) {
            push @{$rule->{folder}}, "exit";
        } else {
            $rule->{folder} = ['exit'];
        }
    }

    if ($hasattach) {
        if ($rule->{options}) {
            $rule->{options} .= ' Hasattach';
        } else {
            $rule->{options} = 'Hasattach';
        }
    }

    if ($newadd) {
        $obj->rules_append($rule);
    } else {
        $rules->[$id] = $rule;
    }

    my $rc = $obj->save;
    if ($rc) {
        $tpl->assign( ERRMSG => sprintf($lang_filter{'savefail'}, $rc));
    } else {
        $tpl->assign( OKMSG => $lang_filter{'saveok'} || 'Save Ok!' );
    }
    $self->filter_list;
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || $_[0]->{template} || 'filter.html';
    reset_working_path();
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
