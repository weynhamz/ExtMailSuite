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
package Ext::App::Compose;
use strict;
use Exporter;

use vars qw($VERSION);
use vars qw(@ISA @EXPORT $usercfg $tmp_draft);
@ISA = qw(Exporter Ext::App);

$usercfg = undef;
$tmp_draft = undef;

use Fcntl qw(:flock);
use Ext::App;
use Ext::MIME;
use Ext::Storage::Maildir;
use Ext::Utils;
use Ext::Abook;
use Ext::RFC822; # import rfc822_* func
use MIME::Base64; # XXX use XS if possible, perl version sucks
use MIME::QuotedPrint;
use Net::SMTP;

use vars qw(%lang_compose $lang_charset);
use Ext::Lang;
use Ext::Unicode;
use Encode::PPUniDetector;

# import from Ext::App
$VERSION = $Ext::App::VERSION;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(edit_compose => \&edit_compose); # no draft
    $self->add_methods(edit_drafts => \&edit_drafts); # has draft
    $self->add_methods(attach_mgr => \&attach_mgr); # alias
    $self->add_methods(edit_reply => \&edit_reply); # reply
    $self->add_methods(edit_forward => \&edit_forward); # forward
    $self->add_methods(edit_import => \&edit_import); # import attaches!

    $self->{default_mode} = 'edit_compose';
    Ext::Storage::Maildir::init($self->get_working_path);
    Ext::MIME::init(path => $self->get_working_path);

    # load usercfg from App.pm userconfig(), it will initialize everything.
    $usercfg = $self->userconfig;
    $self->_initme;
    $self;
}

sub _initme {
    initlang($_[0]->userconfig->{lang}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_compose );
}

# edit_compose - write a new email message, dummy function
sub edit_compose {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};

    $tpl->assign(FOLDER => fixpath($q->cgi('folder')));
    $tpl->assign(
        TO => html_fmt($q->cgi('to')),
        CC => html_fmt($q->cgi('cc')),
        BCC => html_fmt($q->cgi('bcc')),
        SUBJECT  => html_fmt($q->cgi('subject')),
        CCSENT => $usercfg->{'ccsent'},
        BODY => "\n\n". $self->get_signature,
        RTE_ON => $usercfg->{compose_html} ? 1 : 0,
        BODY_IS_HTML => $usercfg->{compose_html} ? 1 : 0,
    );
1;
}

# CORE function for message compose/rewrite XXX
sub edit_drafts {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $sid = $self->{sid};
    my $draft = $q->cgi('draft') ? $q->cgi('draft') : undef;

    $tpl->assign(
        SID => $sid,
        CCSENT => $usercfg->{'ccsent'},
        RTE_ON => $usercfg->{'compose_html'} ? 1 : 0,
    );

    if($self->submited) {
        if($q->cgi('dosave')) {
            $self->rebuild_attach('update');
            $tpl->assign(FOLDER => 'Drafts');

            # XXX call attach_mgr() now
            $self->attach_mgr();
            # show attach now

            # on the first time no new draft create, we should
            # use $tmp_draft instead of draft
            $draft = $tmp_draft if ($tmp_draft);
            $self->show_attach('.Drafts/cur/'.$draft);

            reset_working_path();
            $tpl->{template} = 'saveok.html';
        }elsif($q->cgi('dosend')) {
            $self->rebuild_attach('update');
            my $newdraft = $self->attach_mgr();

            $tpl->assign(FOLDER => 'Drafts');
            if ($newdraft) {
                $self->sendmail($newdraft) unless ($self->{_errmsg});
            } else {
                $self->error('SendMail Error: Disk full or filesystem error');
                return;
            }

            reset_working_path();
            $tpl->{template} = 'sendok.html';
        }elsif($q->cgi('attachmgr')) { # it's a hidden field
            if($q->cgi('return')) {
                # back to compose
                $self->show_draft($draft);
                return;
            }

            if($draft) {
                $tpl->assign(HAVE_DRAFT => 1, DRAFT => $draft);
            }
            $self->rebuild_attach('update');

            reset_working_path();
            $tpl->{template} = 'attachmgr.html';
        }else {
            $self->error('Sucks, no valid __mode specify');
            return;
        }
    }else {
        if($draft) {
            $self->show_draft($draft);
        }else {
            $self->error('No draft specify or no such draft');
        }
    }
}

sub edit_forward {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};

    my $folder = fixpath($q->cgi('folder')) || 'Inbox';
    my $pos = $q->cgi('pos') || 0;
    my $msgid = fixpath($q->cgi('msgid'));
    my $msgfile = pos2file($folder, $pos);
    my $file;
    if($msgfile eq $msgid || !$msgid){
        $file = _name2mdir($folder).'/cur/'.$msgfile;
    }else{
        my $fname = maildir_find($folder, $msgid); # try to find it
        $file = _name2mdir($folder).'/cur/'.$fname;
    }

    my $parts = get_msg_info($file);
    my $hdr = $parts->{head}{hash};

    # UTF-8 handling
    my $utf8 = Ext::Unicode->new;
    my $charset = hdr_get_hash('Charset', %$hdr);
    $utf8->set_charset($charset);

    my $subj = decode_words_utf8(hdr_get_hash('Subject', %$hdr));
    my $from = decode_words_utf8(hdr_get_hash('From', %$hdr));
    my $oldto = decode_words_utf8(hdr_get_hash('To', %$hdr));
    my $as_attach = $q->cgi('asattach') || 0; # default to 0
    my $has_attach = 0; # XXX default to false

    my $boundary = undef;
    my $tmpdraft = _gen_maildir_filename();
    my $nick = $usercfg->{'nick_name'} || rfc822_addr_parse($ENV{USERNAME})->{name};

    my $pftype = $usercfg->{compose_html} ? 'text/html' : 'text/plain';
    my $bodyref = _getbody($parts, $file, $pftype);

    my $part0;
    if ($pftype =~ /$bodyref->{type}/i) {
        # yes we found the prefered type
        if ($bodyref->{id} >=0) {
           $part0 = ${$parts->{body}{list}}[$bodyref->{id}];
       } else {
           $part0 = {};
       }
    } else {
        # oops, we fallback to the first part
        $part0 = ${$parts->{body}{list}}[0];
    }

    my $obody_type = hdr_get_hash('Content-Type', %{$part0->{phead}}) || 'text/plain';

    my $sjchar;
    TRY: {
        my $subject = decode_words(hdr_get_hash('Subject', %$hdr));
        $subject =~ s/\s+//; # remove space
        my $c = charset_detect($subject);
        if ($c =~ /^(windows-1252|iso-8859-)/ && length $subject < 6) {
            $sjchar = charset_detect(decode_words(hdr_get_hash('From', %$hdr)));
        } else {
            $sjchar = $c;
        }
    }

    $subj = iconv($subj, $sjchar, 'utf-8') if charset_detect($subj) ne 'utf-8';
    $from = iconv($from, $sjchar, 'utf-8') if charset_detect($from) ne 'utf-8';

    # XXX FIXME terrible bad perl code to do encoding detect, wait for rewrite :(
    my $chst;
    {
        my $tmp_body = '';
        # doing urgly checks :(
        if ($bodyref->{id}>=0) {
            $tmp_body = get_parts($file, $bodyref->{id}, 'to_string');
            if ($bodyref->{charset}) {
                $tmp_body = iconv($tmp_body, $bodyref->{charset}, 'utf-8');
            } else {
                $tmp_body = iconv($tmp_body, $charset||$sjchar, 'utf-8');
            }
        }
        $chst = $self->myiconv_setup($subj.$from.$oldto.$tmp_body.$nick);
    }

    $utf8->set_charset($sjchar) unless ($charset);

    $tpl->assign(
        CCSENT => $usercfg->{'ccsent'},
        RTE_ON => $usercfg->{'compose_html'} ? 1 : 0,
        BODY_IS_HTML => ($obody_type =~ /html/i?1:0),
    );
    my $type = ($usercfg->{'compose_html'} && $obody_type=~/html/i) ?
                'text/html' : 'text/plain';
    my $crlf = $type eq 'text/html' ? "</br>\n" : "\n";

    open(my $NEW, "> .Drafts/tmp/$tmpdraft")
        or die "Can't write to $tmpdraft";
    print $NEW 'From: "'.rfc822_encode_str($chst,$self->myiconv($nick)).'"';
    print $NEW " <".$ENV{USERNAME}.">\n";
    print $NEW 'To: '.rfc822_encode_addr($chst, $self->myiconv($q->cgi('to')))."\n";
    print $NEW 'Subject: '.rfc822_encode_str($chst,$self->myiconv('Fwd: '.$subj))."\n";
    print $NEW 'Date: '.rfc822_date($self->userconfig->{'timezone'})."\n";
    print $NEW "Mime-version: 1.0\n";
    print $NEW "X-Originating-Ip: [$ENV{REMOTE_ADDR}]\n";
    if(my $ver = $VERSION ? "ExtMail $VERSION" : '') {
        print $NEW "X-Mailer: $ver\n";
    }

    $has_attach = 1 if (has_attach($file) ||
        hdr_get_hash('Content-Disposition', %{$parts->{head}{hash}}) =~ /(attach|name)/i);

    if($as_attach or defined $parts->{head}{hash}->{boundary} or $has_attach
        or scalar @{$parts->{body}{list}} >1 ) { # XXX buggy, alternative part
                                                 # will have more parts!
        $type = 'multipart/mixed';
    }

    print $NEW 'Content-Type: '.$type.'; ';
    print $NEW "charset=\"$chst\";\n"; # XXX bug?
    if($as_attach) {
        $boundary = _gen_boundary(); # must new a boundary;
        print $NEW " boundary=\"$boundary\"\n"; # more white space
    }else {
        if (hdr_get_hash('boundary', %{$parts->{head}{hash}})) {
            # on normal forward mode, can use old boundary:)
            $boundary = hdr_get_hash('boundary', %{$parts->{head}{hash}});
            print $NEW " boundary=\"$boundary\"\n";
        } elsif($has_attach) {
            # XXX FIXME new state
            $boundary = _gen_boundary();
            print $NEW " boundary=\"$boundary\"\n";
        } else {
            print $NEW 'Content-Transfer-Encoding: base64'."\n";
        }
    }
    print $NEW "\n"; # terminate header

    if($as_attach) {
        # Null body part XXX
        my $type = $usercfg->{'compose_html'} ? 'text/html' : 'text/plain';
        print $NEW "--$boundary\n";
        print $NEW "Content-Type: $type; charset=\"$chst\";\n";
        print $NEW "Content-Transfer-Encoding: base64\n\n";
        print $NEW encode_base64($self->myiconv($self->get_signature($type))); # must has newline

        open(my $OLD, "< $file") or die "Can't open $file, $!\n";
        print $NEW "--$boundary\n";
        print $NEW "Content-Type: message/rfc822\n\n";
        while(<$OLD>) {
            print $NEW $_;
        }
        close $OLD;
        print $NEW "\n";
        print $NEW "--$boundary--\n";
    }else {
        if($boundary) { # has attach?
            open(my $OLD, "< $file") or
                die "Can't open $file, $!\n";

            # build body
            print $NEW "--$boundary\n";
            # my $part0 = ${$parts->{body}{list}}[0]; # XXX

            my $bodytype = ($usercfg->{'compose_html'} && $obody_type=~/html/i) ?
                            'text/html' : 'text/plain';
            # convert encoding from old to new , must 8bit, currently only
            # support text/plain, so 8bit is suitable
            print $NEW "Content-Type: $bodytype; charset=\"$chst\";\n";
            print $NEW "Content-Transfer-Encoding: base64\n\n";
            # print $NEW "\n";

            my $body = '';
            my $qtext = '';
            my $fwd = "$crlf-------- Forwarded Messages --------$crlf";

            if ($obody_type =~ /html/i && $usercfg->{compose_html}) {
                    # the body is html and we enable compose_html
                    $from =~ s![<>]+!!g;
                    $oldto =~ s![<>]+!!g;
                    $from = txt2html($from, html_escape=>1);
                    $oldto = txt2html($oldto, html_escape=>1);
            }
            $qtext .= "From: $from $crlf";
            $qtext .= "To: $oldto $crlf$crlf";

            if ($obody_type =~ /html/i && !$usercfg->{compose_html}) {
                $body = html2txt($body);
            }

            if ($bodyref->{id}>=0) {
                $body = get_parts($file, $bodyref->{id}, 'to_string');
            }

            if ($bodyref->{charset}) {
                # body has specific charset, we use it
                $utf8->set_charset($bodyref->{charset});
            }
            $body = htmlsanity($utf8->utf8_encode($body)); # remove html page header etc..

            $body = "$qtext\n$body";
            $body = $self->html_quote($body) if ($obody_type =~ /html/i && $usercfg->{compose_html});

            # it's time to do myiconv :)
            $body = $self->myiconv($self->get_signature($obody_type) . $fwd . $body);
            print $NEW encode_base64($body) . "\n";

            # build attach part
            my $cnt = 0;

            foreach my $p (@{$parts->{body}{list}}) {

                # XXX will ignore non-attachment part
                if((!$p->{phead}->{filename} && !$p->{phead}->{name} &&
                    !$p->{phead}->{'Content-Disposition'} &&
                    $p->{phead}->{'Content-Disposition'} !~/attach/i) && $cnt<2) {
                    $cnt ++; # increase
                    next;
                }
                my ($a,$b) = ($p->{pos_start}, $p->{pos_end});
                seek($OLD, $a, 0); # seek to the begin of part
                print $NEW "--$boundary\n";
                while(<$OLD>) {
                    print $NEW $_;
                    last if(tell $OLD>= $b);
                }
                $cnt++;
            }
            print $NEW "\n";
            print $NEW "--$boundary--\n";
        }else {
            # no attach, normal body, we just want the normal body, part0
            # my $part0 = ${$parts->{body}{list}}[0]; # XXX
            open(my $OLD, "< $file") or
                die "Can't open $file, $!\n";

            my $body = '';
            my $qtext = '';
            if ($obody_type =~ /html/i && $usercfg->{compose_html}) {
                # the body is html and we enable compose_html
                $from =~ s![<>]+!!g;
                $oldto =~ s![<>]+!!g;
                $from = txt2html($from, html_escape=>1);
                $oldto = txt2html($oldto, html_escape=>1);
            }

            my $fwd = "$crlf-------- Forwarded Messages --------$crlf";
            $qtext .= "From: $from $crlf";
            $qtext .= "To: $oldto $crlf$crlf";

            if ($bodyref->{id}>=0) {
                $body = get_parts($file, $bodyref->{id}, 'to_string');
            }

            if ($obody_type =~ /html/i && !$usercfg->{compose_html}) {
                $body = html2txt($body);
            }

            if ($bodyref->{charset}) {
                # body has specific charset, we use it
                $utf8->set_charset($bodyref->{charset});
            }
            $body = htmlsanity($utf8->utf8_encode($body)); # remove html page header etc..

            $body = "$qtext\n$body";
            $body = $self->html_quote($body) if ($obody_type =~ /html/i && $usercfg->{compose_html});

            # it's time to do myiconv
            $body = $self->myiconv($self->get_signature($obody_type) . $fwd . $body);
            print $NEW encode_base64($body ). "\n";
        }
    }
    close $NEW;

    $self->myiconv_close;

    my $newdraft = _gen_maildir_filename(".Drafts/tmp/$tmpdraft", '1');
    rename(".Drafts/tmp/$tmpdraft", ".Drafts/tmp/$newdraft");
    my $size = (stat '.Drafts/tmp/'.$newdraft)[7];
    my $distname = "";

    my ($is_oversize, $is_overquota);
    my $errbuf = '';

    if ($size > 0) {
        if (my $sz = $self->is_oversize($size)) {
            $is_oversize = 1;
            $errbuf = sprintf($lang_compose{oversize}, human_size($sz));
        } elsif (is_overquota($size, 1)>1) {
            $is_overquota = 1;
            $errbuf = $lang_compose{overquota};
        }
    }

    if ($is_overquota || $is_oversize) {
        $self->{_errmsg} = $errbuf;
        $tpl->assign(OPMSG => $errbuf, ERRMSG => $errbuf);
        unlink untaint(".Drafts/tmp/$newdraft");
        return 0; # return on failure
    }else {
        $distname=$newdraft.",S=$size:2,S";

        # XXX has performance problem FIXME
        if (has_attach(".Drafts/tmp/$newdraft")) {
            $distname .= 'A'; # if multipart, set flag to Attach
        }
        rename('.Drafts/tmp/'.$newdraft, '.Drafts/cur/'.$distname);
        my @a = parse_curcnt('.Drafts');
        $a[0] += $size; # if nagetive, perl will handle it:)
        $a[1] ++;
        open(FD, "> .Drafts/extmail-curcnt")
            or die "Can't write to extmail-curcnt, $!\n";
        flock(FD, LOCK_EX);
        print FD "$a[0] $a[1] $a[2]\n";
        flock(FD, LOCK_UN);
        close FD;

        my %quota = ();
        $quota{a} = "$size 1";
        update_quota_s(\%quota);
    }
    $self->show_draft($distname);
}

sub edit_reply {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};

    my $folder = fixpath($q->cgi('folder')) || 'Inbox';
    my $pos = $q->cgi('pos') || 0;

    my $msgid = fixpath($q->cgi('msgid'));
    my $msgfile = pos2file($folder, $pos);
    my $file;

    if($msgfile eq $msgid || !$msgid){
        $file = _name2mdir($folder).'/cur/'.$msgfile;
    }else{
        my $fname = maildir_find($folder, $msgid); # try to find it
        $file = _name2mdir($folder).'/cur/'.$fname;
    }

    my $parts = get_msg_info($file);
    my $hdr = $parts->{head}{hash};

    my $utf8 = Ext::Unicode->new;
    my $charset = hdr_get_hash('Charset', %$hdr);
    my $date = hdr_get_hash('Date', %$hdr);
    my $from = decode_words_utf8(hdr_get_hash('From', %$hdr));
    my $replyto = decode_words_utf8(hdr_get_hash('Reply-To', %$hdr));
    my $return = decode_words_utf8(hdr_get_hash('Return-Path', %$hdr));
    my ($to, $cc, $bcc) = (
        decode_words_utf8(hdr_get_hash('To', %$hdr)),
        decode_words_utf8(hdr_get_hash('Cc', %$hdr)),
        decode_words_utf8(hdr_get_hash('Bcc', %$hdr)),
        );
    my $subj = decode_words_utf8(hdr_get_hash('Subject', %$hdr));

    # XXX FIXME charset auto detect part
    my $sjchar;
    TRY: {
        my $subject = decode_words(hdr_get_hash('Subject', %$hdr));
        $subject =~ s/\s+//; # remove space
        my $c = charset_detect($subject);
        if ($c =~ /^(windows-1252|iso-8859-)/ && length $subject < 6) {
            $sjchar = charset_detect(decode_words(hdr_get_hash('From', %$hdr)));
        } else {
            $sjchar = $c;
        }
    }
    $from = iconv($from, $sjchar, 'utf-8') if charset_detect($from) ne 'utf-8';
    $to = iconv($to, $sjchar, 'utf-8') if charset_detect($to) ne 'utf-8';
    $cc = iconv($cc, $sjchar, 'utf-8') if charset_detect($cc) ne 'utf-8';
    $bcc = iconv($bcc, $sjchar, 'utf-8') if charset_detect($bcc) ne 'utf-8';
    $replyto = iconv($replyto, $sjchar, 'utf-8') if charset_detect($replyto) ne 'utf-8';
    $return = iconv($replyto, $sjchar, 'utf-8') if charset_detect($return) ne 'utf-8';
    $subj = iconv($subj, $sjchar, 'utf-8') if charset_detect($subj) ne 'utf-8';

    # XXX FIXME set charset to subject charset if it's unavailable
    $charset = $sjchar unless $charset;

    my $pftype = $usercfg->{compose_html} ? 'text/html' : 'text/plain';
    my $bodyref = _getbody($parts, $file, $pftype);

    my $part0;
    if ($pftype =~ /$bodyref->{type}/i) {
        # yes we found the prefered type
        $part0 = ${$parts->{body}{list}}[$bodyref->{id}]; # XXX
    } else {
        # oops, we fallback to the first part
        $part0 = ${$parts->{body}{list}}[0];
    }

    $utf8->set_charset($bodyref->{charset} || $charset);
    my $ctype = hdr_get_hash('Content-Type', %{$part0->{phead}}) || 'text/plain';
    my $text = $utf8->utf8_encode($bodyref->{body});# the body text!
    my $body_is_html = 0;

    $date =~ s/\s*[-+]\d+\s*.*//;
    my $quotetpl = $lang_compose{'quotetpl'} || '%s at %s wrote:';

    if ($ctype =~ /html/i) {
        $body_is_html = 1;
        # format body text to reply style XXX to be fix
        if (!$usercfg->{'compose_html'}) {
            $text = html2txt($text);
            $text =~ s#^(.{1})#>$1#;
            $text =~ s#\n#\n>#g;
            $text = sprintf("\n$quotetpl\n\%s", $from, $date, $text);
        } else {
            #$text =~ s!\r*\n!!gsi;
            #$text =~ s!<\s*/?\s*br\s*/?\s*>!</br>\n!gsi;
            #$text =~ s!</li>!</li>\n!gi;
            #$text =~ s!</p>!</p>\r\n\r\n!gi;
            #$text =~ s!</div>!\r\n!gi;
            #$text =~ s!^(.{1})!&gt;$1!;
            #$text =~ s!\n!\n&gt;!gsi;
            # the following is waiting for fix, can't input under IE
            # FIXME XXX the following code need to do subject auto focus()
            # when everything loaded, but i don't know why, need help!
            $text = $self->html_quote($text);
            $text = sprintf("</br>\n$quotetpl\n\%s", $from, $date, $text);
        }
    } else {
        $text =~ s#^(.{1})#>$1#;
        $text =~ s#\n#\n>#g;
        $text = sprintf("\n$quotetpl\n\%s", $from, $date, $text);
    }

    $tpl->assign(BODY_IS_HTML => $body_is_html);

    if ($self->remove_addr($ENV{USERNAME}, $from)) {
        # not from me
        $cc = $self->remove_addr($ENV{USERNAME}, $cc);
        $to = $self->remove_addr($ENV{USERNAME}, $to);
        $cc .= ','.$to;

        $cc =~ s/^\s*,//;
        $cc =~ s/\s*,\s*$//;
        $to = $from;
    } else {
        # from me
        $cc = $self->remove_addr($ENV{USERNAME}, $cc);
        $to = $self->remove_addr($ENV{USERNAME}, $to);
    }

    if($q->cgi('replyall')) {
        $tpl->assign(
            CC => html_fmt($cc),
            TO => html_fmt($to),
        );
    } else {
        $tpl->assign(
            TO => html_fmt($replyto || $from || $return),
        );
    }

    $tpl->assign(
        ORG_CHARSET => $charset,
        CCSENT => $usercfg->{'ccsent'},
        SUBJECT => html_fmt('Re: '.$subj),
        BODY=> "\n". $self->get_signature($ctype) . "\n" . $text,
        RTE_ON => $usercfg->{'compose_html'},
    );
}

sub edit_import {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $itype = $q->cgi('type'); # import type
    my %files;
    my $nick = $usercfg->{'nick_name'} || rfc822_addr_parse($ENV{USERNAME})->{name};

    if ($itype eq 'netdisk') {
        my $base = url2str(fixpath($q->cgi('base')));
        my $a = $q->cgi_full_names;
        my @arr = grep { /^FILE-/ } @$a;
        if (@arr) {
            for (@arr) {
                my $file = url2str(fixpath($q->cgi($_)));
                my $path = "./fileman/$base/$file";
                my $size = (stat $path)[7];
                $files{$file} = $path; # store it
            }
        }
    }

    return unless keys %files; # abort unless there is files

    my $type = $usercfg->{compose_html} ? 'text/html' : 'text/plain';
    # add the signature part
    my $sig = $self->get_signature($type);
    my $chst = $self->myiconv_setup($sig.$nick);
    $nick = $self->myiconv($nick);

    # XXX initialize
    $tpl->assign(
        CCSENT => $usercfg->{'ccsent'},
        BODY => "\n\n". $sig,
        RTE_ON => $self->userconfig->{compose_html} ? 1 : 0,
        BODY_IS_HTML => $usercfg->{compose_html} ? 1: 0,
    );

    # XXX the following code derive from rebuild_attach()
    my $tmpdraft = _gen_maildir_filename();
    my $boundary = _gen_boundary();

    open(my $FD, "> .Drafts/tmp/$tmpdraft")
        or die "Can't write to $tmpdraft, $!\n";
    select((select($FD), $| = 1)[0]);
    print $FD 'From: "'.rfc822_encode_str($chst, $nick).'"';
    print $FD " <".$ENV{USERNAME}.">\n";
    print $FD 'To: '.rfc822_encode_addr($chst, $self->myiconv($q->cgi('to')))."\n";
    print $FD 'Subject: '.rfc822_encode_str($chst, $self->myiconv($q->cgi('subject')))."\n";
    print $FD 'Date: '.rfc822_date($self->userconfig->{'timezone'})."\n";
    print $FD "Mime-version: 1.0\n";
    print $FD "X-Originating-Ip: [$ENV{REMOTE_ADDR}]\n";
    if(my $ver = $VERSION ? "ExtMail $VERSION" : '') {
        print $FD "X-Mailer: $ver\n";
    }
    print $FD 'Content-Type: multipart/mixed; ';
    print $FD "boundary=$boundary; charset=\"$chst\"\n";
    print $FD "Content-Transfer-Encoding: base64\n\n";
    print $FD "This is a MIME-formatted message.  If you see this text it means that your\n";
    print $FD "mail software cannot handle MIME-formatted messages.\n\n";

    print $FD "--$boundary\n";
    print $FD "Content-Type: $type; charset=\"$chst\";\n";
    print $FD "Content-Transfer-Encoding: base64\n\n";

    $sig = $self->myiconv($sig);
    print $FD encode_base64($sig)."\n";
    print $FD "\n";

    # build the attachment parts
    foreach my $f (keys %files) {
        $chst = $self->myiconv_setup($f);
        my $lf = $self->myiconv($f);
        print $FD "--$boundary\n";
        print $FD "Content-Disposition: attachment; filename=\"$lf\"\n";
        print $FD "Content-Type: application/octet-stream; charset=\"$chst\"; name=\"$lf\"\n";
        print $FD "Content-Transfer-Encoding: base64\n\n";
        open (my $ATT, "< $files{$f}") or die "open $files{$f} fail, $!\n";
        while(read($ATT, my $buf, 60*57)) {
            print $FD encode_base64($buf);
        }
        close $ATT;
        print $FD "\n"; # need?
    }
    print $FD "--$boundary--\n";
    close $FD;

    $self->myiconv_close;

    # get the standard maildir name according to the official standard
    # see http://cr.yp.to/maildir.html
    my $newdraft = _gen_maildir_filename(".Drafts/tmp/$tmpdraft", '1');
    rename(".Drafts/tmp/$tmpdraft", ".Drafts/tmp/$newdraft");

    my $newsize = (stat '.Drafts/tmp/'.$newdraft)[7];
    my $distname = $newdraft.",S=$newsize:2,SA"; # Attach flag
    my $oldsize = 0;

    # overquota or oversize (message) checks
    my ($is_oversize, $is_overquota);
    my $errbuf = '';

    if ($newsize > 0) {
        if (my $sz = $self->is_oversize($newsize)) {
            $is_oversize = 1;
            $errbuf = sprintf($lang_compose{oversize}, human_size($sz));
        } elsif (is_overquota($newsize, 1)>1) {
            $is_overquota = 1;
            $errbuf = $lang_compose{overquota};
        }
    }

    if ($is_overquota || $is_oversize) {
        $self->{_errmsg} = $errbuf;
        $tpl->assign(OPMSG => $errbuf, ERRMSG => $errbuf);
        unlink untaint(".Drafts/tmp/$newdraft");
        return 0; # return on failure
    } else {
        rename('.Drafts/tmp/'.$newdraft, '.Drafts/cur/'.$distname);
        my @a = parse_curcnt('.Drafts');
        # calculate the delta size
        $a[0] += $newsize;
        $a[1] ++; # new add situation
        open(FD, "> .Drafts/extmail-curcnt")
            or die "Can't write to extmail-curcnt, $!\n";
        flock(FD, LOCK_EX);
        print FD "$a[0] $a[1] $a[2]\n";
        flock(FD, LOCK_UN);
        close FD;

        # Update system maildirsize file now
        update_quota($newsize, 1);
    }
    my $newparts = get_msg_info('.Drafts/cur/'.$distname);
    $self->show_attach('.Drafts/cur/'.$distname);

    $tpl->assign(
        'HAVE_DRAFT' => 1,
        DRAFT => $distname,
        OPMSG => $self->{opmsg},
    );
    1;
}

# attach_mgr() - manage attachment
sub attach_mgr {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $draft = $q->cgi('draft') ? $q->cgi('draft') : ($tmp_draft ? $tmp_draft : undef);

    # avoid url attack
    $draft = fixpath($draft);

    $tpl->assign(
        CCSENT => $usercfg->{'ccsent'},
        RTE_ON => $usercfg->{'compose_html'},
    );
    if($q->cgi('doattach')) {
        # XXX yes, upload now - by nick - FIXME, why append then remove?
        $self->rebuild_attach('append');
        return $self->rebuild_attach('remove');
    }elsif($q->cgi('delete')) {
        # XXX delete some attch
        return $self->rebuild_attach('remove');
    }elsif($q->cgi('return')) {
        # XXX return to compose page
        $self->edit_drafts;
        return;
    }elsif ($q->cgi('dosend') || $q->cgi('dosave')) {
        return;
    }else {
        $self->error('No valid action taken');
    }
    reset_working_path();
    $tpl->{template} = 'attachmgr.html';
}

sub show_attach {
    my $self = shift;
    $_[0]=~ m#([^\/]+)$#; # only name part, must match!
    my $filename = maildir_find('.Drafts', $1); # try to find it
    my $draft = '.Drafts/cur/'.$filename;
    my $utf8 = Ext::Unicode->new;
    my $tpl = $self->{tpl};

    return unless($draft);

    my $parts = get_msg_info($draft);
    if(scalar @{$parts->{body}{list}} >1) {
        $tpl->assign(LIST_ATTACH => 1);
        my $cnt = 0;
        my $files = get_parts_name($parts);
        my $part;

        foreach (1... scalar @$files-1) { # omit body
            my $part = $files->[$_];
            my $hdr = $part->{phead};
            my $charset = hdr_get_hash('charset', %$hdr);
            my $filename = decode_words_utf8($part->{name});

            $utf8->set_charset($charset);
            $tpl->assign(
                'LOOP_ATTACH',
                CNT => $cnt,
                NAME => $charset ? $utf8->utf8_encode(decode_words($part->{name})) : $filename,
                HSIZE => human_size($files->[$_]->{size})
            );
            $cnt ++;
        }
    }
}

sub show_draft {
    my $self = shift;
    my $draft = $_[0];
    my $q = $self->{query};
    my $tpl = $self->{tpl};

    $draft = maildir_find('.Drafts', $draft); # try to find it
    my($from,$to,$cc,$bcc,$subject,$body);
    my $parts = get_msg_info('.Drafts/cur/'.$draft);
    my $body_is_html = 0;
    my $utf8 = Ext::Unicode->new;

    $tpl->assign(
        HAVE_DRAFT => 1,
        DRAFT => $draft
    );

    my $part0 = ${$parts->{body}{list}}[0];
    if($self->submited && !$q->cgi('return')) {
        # XXX submited action, may be has attach or do/send etc.
        $from = $q->cgi('from');
        $to = $q->cgi('to');
        $cc = $q->cgi('cc');
        $bcc = $q->cgi('bcc');
        $subject = $q->cgi('subject');
        $body = $q->cgi('body');
    }else {
        # XXX call from Drafts folder messages list
        # my $parts = get_msg_info('.Drafts/cur/'.$draft); XXX meaningless
        my $hdr = $parts->{head}{hash};
        my $pftype = $usercfg->{compose_html} ? 'text/html' : 'text/plain';
        my $bodyref = _getbody($parts, ".Drafts/cur/$draft", $pftype);
        my $charset = hdr_get_hash('charset', %$hdr);

        $utf8->set_charset($bodyref->{charset} || $charset);

        $from = $utf8->utf8_encode(decode_words(hdr_get_hash('From', %$hdr)));
        $to = $utf8->utf8_encode(decode_words(hdr_get_hash('To', %$hdr)));
        $cc = $utf8->utf8_encode(decode_words(hdr_get_hash('Cc', %$hdr)));
        $bcc = $utf8->utf8_encode(decode_words(hdr_get_hash('Bcc', %$hdr)));
        $subject = $utf8->utf8_encode(decode_words(hdr_get_hash('Subject', %$hdr)));

        if ($pftype =~ /$bodyref->{type}/i) {
            # yes we found the prefered type
            $part0 = ${$parts->{body}{list}}[$bodyref->{id}]; # XXX
        } # if not match, use the default setting above

        $body = $utf8->utf8_encode($bodyref->{body});# the body text!
        chomp $body; # XXX remove last \n added in rebuild

        my $priority = hdr_get_hash('X-Priority', %$hdr);
        my $notification = hdr_get_hash('Disposition-Notification-To', %$hdr);
        if ($priority) {
            $tpl->assign(X_PRIORITY => 1);
        }
        if ($notification) {
            $tpl->assign(NEED_NOTIFICATION => 1);
        }
    }

    if ($part0->{phead}->{'Content-Type'} =~ /html/i or $q->cgi('html')) {
        $body_is_html = 1;
        # convert body to text if we are not in RTF mode
        $body = html2txt($body) if !$usercfg->{compose_html};
    }
    $tpl->assign( BODY_IS_HTML => $body_is_html );

    $tpl->assign(
        FROM => $from,
        TO => html_fmt($to),
        CC => html_fmt($cc),
        BCC => html_fmt($bcc),
        SUBJECT => html_fmt($subject),
        BODY => $body,
    );
    $self->show_attach('.Drafts/cur/'.$draft);
}

# rebuild_attach() - rebuild attachment parts, not include header
sub rebuild_attach {
    my $self = shift;
    my $mode = $_[0];
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $draft = $q->cgi('draft') ? $q->cgi('draft') : ($tmp_draft ? $tmp_draft : undef);
    my $type = $q->cgi('html') ? 'text/html' : 'text/plain';
    $draft = maildir_find('.Drafts', $draft); # try to find it

    # avoid url attack
    $draft = fixpath($draft);

    $self->{opmsg} = "Default information"; # operation message
    my($newdraft) = ""; # function field varible
    my($delta_size) = 0; # data size change(add/remove)

    #$tpl->assign(SID => $q->cgi('sid')); # XXX must exists
    if($draft) {# XXX already save or build draft
        $tpl->assign(
            'HAVE_DRAFT' => 1,
            DRAFT => $draft
        );

        $newdraft = untaint(_gen_maildir_filename($draft));
        # sucks, pass FD via object will cause more cleanup work,
        # may be pass newdraft name is better? tobe fix
        #
        # remove $newdraft from tmp/ must be done whether we hit
        # the bottom of rebuild_attach, so it's urgly implement:(
        open($self->{newfd}, "> .Drafts/tmp/$newdraft") or
            die "Can't write to $newdraft, $!\n";

        if($mode eq 'append') {
            unless($q->allfiles) {
                close $self->{newfd};
                delete $self->{newfd};
                unlink untaint(".Drafts/tmp/$newdraft");
                return $draft;
                # $self->show_attach('.Drafts/cur/'.$draft);
                # return 1;
            }
            $self->rebuild_append_attach($draft);
        }elsif($mode eq 'remove') {
            my @a = grep { s/^REMOVE-// } @{$q->cgi_full_names};
            unless(@a) {
                close $self->{newfd};
                delete $self->{newfd};
                unlink untaint(".Drafts/tmp/$newdraft");
                # $self->show_attach('.Drafts/cur/'.$draft);
                return $draft;
            }
            $self->rebuild_remove_attach($draft);
        }elsif($mode eq 'update') {
            $self->rebuild_update_message($draft);
        }else {
            close $self->{newfd};
            delete $self->{newfd};
            unlink untaint(".Drafts/tmp/$newdraft");
            $self->error('Unknow method: '. $mode);
            return 0;
        }

        my $TMP = $self->{newfd};
        if($self->{boundary}) {
             print $TMP '--'.$self->{boundary}."--\n";
        }
        close $TMP;
    }else {# XXX the first time, no $draft
        $type = $q->cgi('html') ? 'text/html' : 'text/plain';
        # The following code is deprecated, not need to gen newdraft
        # here, from compose to attachmgr, newdraft will be create
        # automatically
        #
        #if($q->cgi('doattach') or $q->cgi('dosave') or !$draft) {
        # upload attach
        #    $newdraft = _gen_maildir_filename();
        #}
        #unless($draft) {
        # new create if no draft
        #}
        my $tmpdraft = _gen_maildir_filename();
        my $chst = $self->myiconv_setup;# $self->userconfig->{'charset'} || 'UTF-8';
        my $nick = $self->myiconv($usercfg->{'nick_name'} || rfc822_addr_parse($ENV{USERNAME})->{name});

        open(FD, "> .Drafts/tmp/$tmpdraft")
            or die "Can't write to $tmpdraft, $!\n";
        select((select(FD), $| = 1)[0]);
        print FD 'From: "'.rfc822_encode_str($chst, $nick).'"';
        print FD " <".$ENV{USERNAME}.">\n";
        print FD 'To: '.rfc822_encode_addr($chst, $self->myiconv($q->cgi('to')))."\n";
        if($q->cgi('cc')) {
            print FD 'Cc: '.rfc822_encode_addr($chst, $self->myiconv($q->cgi('cc')))."\n";
        }
        if($q->cgi('bcc')) {
            print FD 'Bcc: '.rfc822_encode_addr($chst, $self->myiconv($q->cgi('bcc')))."\n";
        }
        print FD 'Subject: '.rfc822_encode_str($chst, $self->myiconv($q->cgi('subject')))."\n";
        print FD 'Date: '.rfc822_date($self->userconfig->{'timezone'})."\n";
        print FD "Mime-version: 1.0\n";
        print FD "X-Originating-Ip: [$ENV{REMOTE_ADDR}]\n";

        my $priority = $q->cgi('priority') ? 1 : 0;
        my $notify = $q->cgi('notification') ? 1 : 0;
        if ($notify){
            print FD 'Disposition-Notification-To: '.$ENV{USERNAME}."\n";
        }
        if ($priority){
            print FD 'X-Priority: 1'."\n";
        }

        if(my $ver = $VERSION ? "ExtMail $VERSION" : '') {
            print FD "X-Mailer: $ver\n";
        }
        print FD 'Content-Type: '.$type.'; ';
        print FD "charset=\"$chst\"\n";
        print FD "Content-Transfer-Encoding: base64\n";
        print FD "\n";
        print FD encode_base64($self->myiconv(($q->cgi('html') ? $q->cgi('body') : $q->cgi('plaintext')||$q->cgi('body')))),"\n\n";
        close FD;

        # get the standard maildir name according to the official standard
        # see http://cr.yp.to/maildir.html
        $newdraft = _gen_maildir_filename(".Drafts/tmp/$tmpdraft", '1');
        rename(".Drafts/tmp/$tmpdraft", ".Drafts/tmp/$newdraft");

        $self->{opmsg} = $lang_compose{msgsaved} || 'Message Saved';

        # XXX add by nick This var is for load attach_mgr() in draft_edit()
        # Now we can add attach and save or send mail in one cgi request!
        $tmp_draft = $newdraft.",S=".(stat '.Drafts/tmp/'.$newdraft)[7].":2,S";
    }

    # is_overquota part here should be redesign, the schema not clear!
    my $newsize = (stat '.Drafts/tmp/'.$newdraft)[7];
    my $distname = $newdraft.",S=$newsize:2,S";
    my $oldsize = ( $draft ? (stat '.Drafts/cur/'.$draft)[7] : 0 );
    $delta_size = ($newsize - $oldsize);

    # XXX performance problem FIXME
    if (has_attach(".Drafts/tmp/$newdraft")) {
        $distname .= 'A'; # set Attach flag
    }
    # new mechanism, check delta whether it's >0 or not, if gt 0, we will
    # check is_overquota, if lt 0, doest not need to check

    my ($is_oversize, $is_overquota);
    my $errbuf = '';

    if ($delta_size > 0) {
        if (my $sz = $self->is_oversize($newsize)) {
            $is_oversize = 1;
            $errbuf = sprintf($lang_compose{oversize}, human_size($sz));
        } elsif (is_overquota($delta_size, $oldsize ? 0 : 1)>1) {
            $is_overquota = 1;
            $errbuf = $lang_compose{overquota};
        }
    }

    if ($is_overquota || $is_oversize) {
        $self->{_errmsg} = $errbuf;
        $tpl->assign(OPMSG => $errbuf, ERRMSG => $errbuf);
        unlink untaint(".Drafts/tmp/$newdraft");
        return 0; # return on failure
    } else {
        # unlink '.Drafts/cur/'.$distname if (-r '.Drafts/cur/'.$distname);
        rename(untaint(".Drafts/tmp/$newdraft"), untaint(".Drafts/cur/$distname"));
        my @a = parse_curcnt('.Drafts');

        # calculate the delta size
        $a[0] += $delta_size; # if nagetive, perl will handle it:)
        $a[1] ++ unless($draft); # add if new create

        open(FD, "> .Drafts/extmail-curcnt")
            or die "Can't write to extmail-curcnt, $!\n";
        flock(FD, LOCK_EX);
        print FD "$a[0] $a[1] $a[2]\n";
        flock(FD, LOCK_UN);
        close FD;

        # Update system maildirsize file now
        my %quota = ();
        $quota{a} = "-$oldsize -1" if($draft);
        $quota{b} = "$newsize 1";
        update_quota_s(\%quota);
    }

    my $newparts = get_msg_info('.Drafts/cur/'.$distname);
    # print Dumper($newparts);
    # final clean up.., then curcnt timestamp newer than cache, so
    # cache will be rebuild after return to the Drafts folder
    # messages list :-( a bad trick?
    unlink untaint(".Drafts/cur/$draft") if($draft ne $distname);
    # XXX FIXME $self->show_attach('.Drafts/cur/'.$distname);

    $tpl->assign(
        'HAVE_DRAFT' => 1,
        DRAFT => $distname,
        OPMSG => $self->{opmsg}
    );
    delete $self->{opmsg}; # cleanup after usage
    delete $self->{boundary};
    delete $self->{newfd};
    $distname;
}

sub rebuild_append_attach {
    my $self = shift;
    my $q = $self->{query};
    my $draft = $_[0]; # already maildir_find() ?
    my $type = 'multipart/mixed';
    my $chst = $self->userconfig->{'charset'} || 'UTF-8';

    unless($q->allfiles) {
        $self->{opmsg} = $lang_compose{noattupload} || 'No attch upload!';
        return; # return if no attach, ouch
    }

    my $parts = get_msg_info('.Drafts/cur/'.$draft);
    open(FD, "< .Drafts/cur/$draft") or die "Can't open $draft\n";
    my $old = $/;
    local $/ = "\n\n";
    my $header = <FD>;
    $/ = $old; # restore $/

    unless($self->{boundary} = $parts->{head}{hash}->{boundary}) {
        $self->{boundary} = _gen_boundary();
        $header=~s#Content-Type: [^;]+;#Content-Type: $type;#;
        $header=~s#charset="*([^\"]+)"*#charset="$1";\n boundary="$self->{boundary}"#;
        $chst = $1 if $1;
        $header=~s#Content-Transfer-encoding: \S+\n##; # remove this filed
    }

    my $TMP = $self->{newfd};
    print $TMP $header;
    print $TMP "This is a MIME-formatted message.  If you see this text it means that your\n";
    print $TMP "mail software cannot handle MIME-formatted messages.\n\n";

    my $old_att_list = $parts->{body}{list};
    foreach(0...scalar @$old_att_list -1) {
        # print "this is the old $_ part</br>\n";
        my $pos1 = $old_att_list->[$_]{pos_start};
        my $pos2 = $old_att_list->[$_]{pos_end};

        my $orig_type = $old_att_list->[$_]{phead}->{'Content-Type'};
        my $orig_chst = $old_att_list->[$_]{phead}->{'charset'} || $chst;
        my $orig_enc = $old_att_list->[$_]->{phead}->{'Content-Transfer-Encoding'} || '8bit';
        if($orig_type =~/text/ and $_ eq 0) {
            seek(FD, $pos1, 0);
            my $old = $/;
            local $/ = "\n\n";
            <FD>; # remove head
            $/ = $old;
            print $TMP '--'.$self->{boundary}."\n";
            print $TMP "Content-Type: $orig_type; charset=\"$orig_chst\";\n";
            print $TMP "Content-Transfer-Encoding: $orig_enc\n\n";
            my $buf = '';
            while(<FD>) {
                $buf .= $_;
                last if(tell FD>=$pos2);
            }
            print $TMP $buf, "\n";
            next;# next attach?
        }
        seek(FD, $pos1, 0); # seek to the begin, and ignore boundary
        print $TMP "--$self->{boundary}\n";
        while(<FD>) {
            print $TMP $_;
            last if(tell FD >= $pos2);
        }
    }

    # insert the new attach into the newdraft
    my $lists = $q->allfiles();
    foreach my $fh (@$lists) {
        my %header = $q->uploadInfo($fh);
        $header{filename} = filename2std($header{filename});

        ($chst, $header{filename}) = $self->myiconv2($header{filename});
        print $TMP "--$self->{boundary}\n";
        print $TMP "Content-Disposition: attachment; filename=\"$header{filename}\"\n";
        print $TMP 'Content-Type: '.$header{'Content-Type'}."; charset=\"$chst\"; name=\"$header{filename}\"\n";
        print $TMP "Content-Transfer-Encoding: base64\n\n";
        while(read($fh, my $buf, 60*57)) {
            print $TMP encode_base64($buf);
        }
        close $fh;
        print $TMP "\n"; # need?
    }
    $self->{opmsg} = $lang_compose{attuploadok} || 'Attachment upload successfully';
}

sub rebuild_remove_attach {
    my $self = shift;
    my $q = $self->{query};
    my $draft = $_[0];
    my $type = $q->cgi('html') ? 'text/html' : 'text/plain';

    my $parts = get_msg_info('.Drafts/cur/'.$draft);
    $self->{boundary} = $parts->{head}{hash}->{boundary};
    my $a = $q->cgi_full_names;
    my @mimeid = grep { s/^REMOVE-// } @$a; # get mime id
    open(FD, "< .Drafts/cur/$draft") or die "Can't open $draft\n";
    my $old = $/;
    local $/ = "\n\n";
    my $header = <FD>;
    $/ = $old; # restore $/

    my $TMP = $self->{newfd};
    print $TMP $header;
    my $old_att_list = $parts->{body}{list};
    foreach(0...scalar @$old_att_list -1) {
        my $remove = 0;
        foreach my $id (@mimeid) {
            if($_ eq $id+1) {
                $remove = 1;
                last;
            }
        }
        next if ($remove); # XXX
        # print "this is the old $_ part</br>\n";
        my $pos1 = $old_att_list->[$_]{pos_start};
        my $pos2 = $old_att_list->[$_]{pos_end};
        seek(FD, $pos1, 0);
        print $TMP "--$self->{boundary}\n";
        while(<FD>) {
            print $TMP $_;
            last if(tell FD >= $pos2);
        }
    }
    $self->{opmsg} = $lang_compose{removeok};
}

sub rebuild_update_message {
    my $self = shift;
    my $q = $self->{query};
    my $draft = $_[0];
    my $type = $q->cgi('html') ? 'text/html' : 'text/plain';

    my $parts = get_msg_info('.Drafts/cur/'.$draft);
    my $chst = $self->myiconv_setup; # $self->userconfig->{'charset'} || 'UTF-8';
    my $nick = $self->myiconv($usercfg->{'nick_name'} || rfc822_addr_parse($ENV{USERNAME})->{name});

    if(scalar @{$parts->{body}{list}}>0 && $parts->{head}{hash}->{boundary}) {
        $type = 'multipart/mixed';
    }

    open(FD, "< .Drafts/cur/$draft") or die "dam ..$!\n";

    $self->{boundary} = $parts->{head}{hash}->{boundary}; # may be undef
    my $TMP = $self->{newfd};
    print $TMP 'From: "'.rfc822_encode_str($chst,$nick).'"';
    print $TMP " <".$ENV{USERNAME}.">\n";
    print $TMP 'To: '.rfc822_encode_addr($chst,$self->myiconv($q->cgi('to')))."\n";
    if($q->cgi('cc')) {
        print $TMP 'Cc: '.rfc822_encode_addr($chst,$self->myiconv($q->cgi('cc')))."\n";
    }
    if($q->cgi('bcc')) {
        print $TMP 'Bcc: '.rfc822_encode_addr($chst,$self->myiconv($q->cgi('bcc')))."\n";
    }
    print $TMP 'Subject: '.rfc822_encode_str($chst,$self->myiconv($q->cgi('subject')))."\n";
    print $TMP 'Date: '.rfc822_date($self->userconfig->{'timezone'})."\n";
    print $TMP "Mime-version: 1.0\n";
    print $TMP "X-Originating-Ip: [$ENV{REMOTE_ADDR}]\n";

    my $priority = $q->cgi('priority') ? 1 : 0;
    my $notify = $q->cgi('notification') ? 1 : 0;

    if ($notify){
        print $TMP 'Disposition-Notification-To: '.$ENV{USERNAME}."\n";
    }
    if ($priority){
        print $TMP 'X-Priority: 1'."\n";
    }

    if(my $ver = $VERSION ? "ExtMail $VERSION" : '') {
        print $TMP "X-Mailer: $ver\n";
    }
    print $TMP 'Content-Type: '.$type.'; ';

    if($self->{boundary}) {
        print $TMP 'boundary="'.$self->{boundary}.'";'."\n";
        print $TMP " charset=$chst\n\n";
        print $TMP "This is a MIME-formatted message.  If you see this text it means that your\n";
        print $TMP "mail software cannot handle MIME-formatted messages.\n";
    }else {
        print $TMP "charset=\"$chst\"\n";
        print $TMP "Content-Transfer-Encoding: base64\n";
    }
    print $TMP "\n";

    if($self->{boundary}) {
        # restore the original content-type ? No, now extmail can
        # support html/plain mail, so check html flag
        my $body_type = $q->cgi('html') ? 'text/html' : 'text/plain';
        print $TMP "--$self->{boundary}\n";
        print $TMP "Content-Type: $body_type; charset=\"$chst\"\n";
        print $TMP "Content-Transfer-Encoding: base64\n\n";
    }
    print $TMP encode_base64($self->myiconv(($q->cgi('html')? $q->cgi('body'): $q->cgi('plaintext')||$q->cgi('body')))), "\n";

    if($self->{boundary}) {
        my $old_att_list = $parts->{body}{list};
        foreach(1...scalar @$old_att_list -1) {
            # print "this is the old $_ part</br>\n";
            my $pos1 = $old_att_list->[$_]{pos_start};
            my $pos2 = $old_att_list->[$_]{pos_end};

            my $orig_type = $old_att_list->[$_]{phead}->{'Content-Type'};
            my $orig_chst = $old_att_list->[$_]{phead}->{'charset'};
            my $orig_enc = $old_att_list->[$_]->{phead}->{'Content-Transfer-Encoding'} || '8bit';
            if($orig_type =~/text/ and $_ eq 0) {
                seek(FD, $pos1, 0);
                my $old = $/;
                local $/ = "\n\n";
                <FD>; # remove head
                $/ = $old;
                print $TMP "--$self->{boundary}\n";
                print $TMP "Content-Type: $orig_type; charset=\"$orig_chst\";\n";
                print $TMP "Content-Transfer-Encoding: $orig_enc\n\n";
                my $buf = '';
                while(<FD>) {
                    $buf .= $_;
                    last if(tell FD>=$pos2);
                }
                print $TMP $buf, "\n";
                next;# next attach?
            }
            seek(FD, $pos1, 0); # seek to the begin, and ignore boundary
            print $TMP "--$self->{boundary}\n";
            while(<FD>) {
                print $TMP $_;
                last if(tell FD >= $pos2);
            }
        }
    }
    $self->{opmsg} = $lang_compose{msgupdated} || 'Message updated';
    $self->{opmsg} = $lang_compose{draftsaved} || 'Draft saved' if($q->cgi('dosave')); # XXX
}

sub sendmail {
    my $self = shift;
    my $q = $self->{query};
    my $file = $_[0];
    my $from = $ENV{USERNAME} || 'extmail@localhost';
    my $opmsg = 'Message Send fail!';
    my $sys = $self->{sysconfig};

    my $smtp_host = $sys->{SYS_SMTP_HOST} || '127.0.0.1';
    my $smtp_port = $sys->{SYS_SMTP_PORT} || '25';
    my $smtp = Net::SMTP->new(
        $smtp_host,
        Port => $smtp_port,
        Timeout => $sys->{SYS_SMTP_TIMEOUT} || '5',
    ) or die "Connect to $smtp_host:$smtp_port fail, $@\n";

    $smtp->mail($from);

    my $rlists = {};
    my $to = $q->cgi('to');
    my $cc = $q->cgi('cc');
    my $bcc = $q->cgi('bcc');
    my $header = '';
    my ($rc, $msg);
    my $flag = 0;

    # a dirty email address pickup routine :-)
    sub _rcpt { my ($a, $r) = @_; $r->{lc $a} = 1 }

    my $alladdr = "$to, $cc, $bcc";

    $alladdr =~ s/['"][^'"]?['"]//gs;
    $alladdr =~ s/(:?[a-z0-9A-Z\-_\.=]+@[a-z0-9A-Z-\_.]+)/_rcpt($1,$rlists)/gex;

    for my $r (keys %$rlists) {
        next unless $r;
        $smtp->to($r);
        $msg = $smtp->message;
        $rc = $smtp->status;

        if ($rc != 2) {
            chomp $msg;
            die "SMTP rcpt error: $msg\n";
        }
    }

    $smtp->data();
    $rc = $smtp->status;
    $msg = $smtp->message;

    if ($rc != 3) {
        chomp $msg;
        die "SMTP data error: $msg\n";
    }

    local $ENV{PATH} = '';
    open(FD, "< .Drafts/cur/".$file) or die "Can't open $file, $!\n";
    {
        local $/ = "\n\n";
        $header = <FD>;
    }

    # strip bcc header
    for my $line (split(/\n+/, $header)) {
        chomp $line;
        if ($line =~ /^Bcc:.*/) {
            $flag = 1;
            next;
        }
        if ($flag) {
            next if ($line =~ /^\s+/);
            $smtp->datasend("$line\n");
            $flag = 0;
        } else {
            $smtp->datasend("$line\n");
        }
    }

    # fast network I/O code, don't miss sys* func with <> or read/write
    # perl I/O layer functions, if you miss them, sys* will not work
    my $chunk = '';
    while (read(FD, $chunk, 1024*64)>0) {
        $smtp->datasend($chunk);
    }
    $smtp->datasend("\n");
    $smtp->dataend();

    $rc = $smtp->status;
    $msg = $smtp->message;

    if ($rc != 2) {
        chomp $msg;
        die "SMTP Error: $msg\n";
    }

    $smtp->quit;

    close FD;

    $opmsg = $lang_compose{msgsent} || 'Message Sent!';

    # update curcnt cache and reflect to maildirsize, must do it
    my @a = parse_curcnt('.Drafts');
    my @b = parse_curcnt('.Sent');

    # bugfix: use $q->cgi('ccsent') only, don't check user.cf
    my $fcc = $q->cgi('ccsent') || 0;

    # calculate the delta size
    my $dsize = (stat '.Drafts/cur/'.$file)[7];
    $a[0]-=$dsize;
    $a[1]-=1;

    $b[0]+=$dsize;
    $b[1]+=1;
    if($fcc) {
        rename(untaint(".Drafts/cur/$file"), untaint(".Sent/cur/$file")); # move
        open(FD, "> .Sent/extmail-curcnt")
            or die "Can't write to extmail-curcnt, $!\n";
        flock(FD, LOCK_EX);
        print FD "$b[0] $b[1] $b[2]\n";
        flock(FD, LOCK_UN);
        close FD;

        if(has_attach('.Sent/cur/'.$file)) {
            my $tf = "";
            if($file=~!/:2,.*A.*/) {# not flag
                $file=~/([^\:]+):2,(.*)/;
                $tf = $1.':2,A'.$2;
            }
            rename(untaint(".Sent/cur/$file"), untaint(".Sent/cur/$tf"));
        }
        $opmsg .= $lang_compose{fccdone} || ' FCC to Sent done!';
    }else {
        unlink untaint(".Drafts/cur/$file"); # delete it
        my %quota = ();
        $quota{a} = "-$dsize -1";
        update_quota_s(\%quota);
    }

    open(FD, "> .Drafts/extmail-curcnt")
        or die "Can't write to extmail-curcnt, $!\n";
    flock(FD, LOCK_EX);
    print FD "$a[0] $a[1] $a[2]\n";
    flock(FD, LOCK_UN);
    close FD;

    # do the cc/bcc/to auto save to abook
    if ($usercfg->{addr2abook}) {
        my $obj = Ext::Abook->new(file=>'abook.cf', type => 'abook');
        my $abook = $obj->ab_dump;
        my $save = 0;
        my @addr2save;

        for my $v ($to,$cc,$bcc) {
            my @ar = split(/\s*,\s*/, $v);
            for my $m (@ar) {
                my $ref = rfc822_addr_parse($m);
                my $match = 0;
                for(my $k=1;$k<scalar @$abook; $k++) {
                    my $e = $abook->[$k];
                    if (lc $ref->{addr} eq lc $e->[1]) {# addr match?
                        $match = 1;
                        last;
                    }
                }
                next if $match;
                $obj->ab_append([$ref->{name},$ref->{addr},'','']);
                $save ||= 1;
                push @addr2save, $ref->{addr};
            }
            # end of loop, do we need to call save?
        }
        if ($save) {
            for (@addr2save) {
                $self->{tpl}->assign(
                    'ADDR2SAVE',
                    ADDR => $_,
                );
            }
            $obj->ab_save;
        }
    }
    $self->{tpl}->assign( OPMSG => $opmsg);
}

sub submited {
    my $self = shift;
    my $q = $self->{query};

    return 0 unless($q->cgi('doattach') or $q->cgi('dosave')
            or $q->cgi('dosend') or $q->cgi('attachmgr'));
    1;
}

#--------------------------------------------------------------------#
# utility function defined below                                     #
#--------------------------------------------------------------------#

sub _gen_boundary {
    return sprintf "=_%s_%s_%s", int(rand(100)), $$, time;
}

sub _gen_maildir_filename {
    # according to http://cr.yp.to/proto/maildir.html and compatible
    # with sqwebmail or maildrop etc, include postfix
    my ($oldname, $flag) = @_;
    if($oldname && $flag) { # get the standard maildir name
        return gen_std_maildir($oldname);
    }elsif($oldname) { # only strip status information
        $oldname=~ s#([^,]+),S=.*#$1#;
        return $oldname;
    }else { # return the initial filename
        return sprintf "%s_P%s_%s", time, $$, 'extmail';
    }
}

sub _gen_name_tpart {
    eval {
        require 'sys/syscall.ph';
    };
    if($@) { return time; }
    return time unless (defined &SYS_gettimeofday);

    my $start = pack('LL', ());
    syscall(&SYS_gettimeofday, $start, 0) != -1
        or die "gettimeofday: $!";
    my @start = unpack('LL', $start);
    $start[0].'.M'.$start[1];
}

sub _getsizes {
    my $file = shift;
    return (stat $file)[7];
}

sub _getbody {
    my $parts = shift; # the parsed strcture
    my $file = shift; # the maildir file
    my $pftype = shift || 'plain'; # prefer body type
    my $body = '';

    $pftype =~ s!text/!!;

    my @arr = @{get_parts_name($parts)}; # generate part
    if (scalar @arr >1 && $arr[0]->{idflag} =~/alternative/i &&
                       $arr[0]->{idflag} eq $arr[1]->{idflag}) {
        # we found something alternative
        for (my $i=0;$i<2;$i++) {
            my $ctype = hdr_get_hash('Content-Type', %{$arr[$i]->{phead}});
            my $char = hdr_get_hash('charset', %{$arr[$i]->{phead}});
            next if $ctype !~ /$pftype/i;

            $body = get_parts($file, $i, 'to_string');

            if ($ctype =~/html/i) {
                $body = htmlsanity($body);
            }
            return {
                body => $body,
                type => $ctype,
                id => $i,
                charset => $char,
            };
        }
    } else {
        my $ctype = hdr_get_hash('Content-Type', %{$arr[0]->{phead}});
        my $char = hdr_get_hash('charset', %{$arr[0]->{phead}});
        if ($ctype !~ /text/i) {
            return {
                body => '',
                charset => $char,
                type => "text/$pftype",
                id => -1,
            };
        }

        $body = get_parts($file, 0, 'to_string');

        if ($ctype =~ /html/i) {
            $body = htmlsanity($body);
        }
        return {
            body => $body,
            type => $ctype,
            charset => $char,
            id => 0,
        };
    }
}

sub is_oversize {
    my $self = shift;
    my $sys = $self->{sysconfig};
    my $maxsize = $sys->{SYS_MESSAGE_SIZE_LIMIT};
    my $tsize = shift;

    return 0 unless defined $maxsize and $maxsize > 0;
    return 0 unless defined $tsize and $tsize > 0;

    if ($tsize >= $maxsize) {
        return $maxsize;
    }
    0;
}

sub get_signature {
    my $self = shift;
    my $ctype = shift;
    my $htmlize = 0;
    my $buf;

    # bug XXX FIXME
    if (defined $ctype) {
        if ($ctype =~ /html/ && $usercfg->{compose_html}) {
            $htmlize = 1;
        }
    } elsif ($usercfg->{compose_html}) {
        $htmlize = 1;
    }

    return "" unless (-r 'signature.cf'); # current directory
    open (FD, "< signature.cf"); # ignore error
    while (<FD>) {
        if ($htmlize) {
            s#<#&lt; #g;
            s#># &gt;#g;
            s#"# &quot; #g;
            s#\n#</br>\n#g;
        }
        $buf .= $_;
    }
    $buf = txt2link($buf) if ($htmlize);

    if ($htmlize) {
        $buf = "<br>\n<br>\n$buf<br>\n";
    } else {
        $buf = "\n\n$buf\n";
    }
    $buf;
}

sub html_quote {
    my $self = shift;
    my $text = shift; # text to quote?
    my $quote_start = $lang_compose{'div_quote_start'} ||
            '</br><div><blockquote style="border-left: 1px solid '.
            'rgb(204, 204, 204); margin: 0pt 0pt 0pt 0.8ex; '.
            'padding-left: 1ex;">';
    my $quote_end = $lang_compose{'div_quote_end'} ||
            '</blockquote></div></br>';
    $text = "</br>\n$quote_start\n".
            "$text\n".
            "$quote_end\n";
    $text;
}

sub myiconv_setup {
    my $self = shift;
    my $buf = shift;
    my $lang = $usercfg->{lang};
    my $need_local = $usercfg->{trylocal};
    my $q = $self->{query};

    if (!$need_local) {
        $self->{_prefer_charset} = 'UTF-8';
        return 'UTF-8';
    }

    if (!$buf) {
        $buf .= $q->cgi('to').$q->cgi('cc').$q->cgi('bcc');
        $buf .= ($q->cgi('body') || $q->cgi('plaintext'));
        $buf .= $usercfg->{'nick_name'} . $q->cgi('subject');
    }

    # supported local encoding maps, return null if not supported
    my $intl = intl2euc($lang);

    if (!$buf and $intl and $need_local) {
        $self->{_prefer_charset} = $intl;
        return $intl;
    }

    # XXX FIXME dont' turun on perl tain mode perl -wT, or it
    # will break the width char regexp !!
    my $rv = Encode::PPUniDetector::trylocal2($buf, $intl);
    if ($rv) {
        $self->{_prefer_charset} = $rv;
    } else {
        $self->{_prefer_charset} = 'UTF-8';
    }
    return $self->{_prefer_charset};
}

# intergrated with setup and conv and close .hehe~
sub myiconv2 {
    my $self = shift;
    my $buf = shift;
    my $prefer_euc = intl2euc($usercfg->{lang});

    return ('UTF-8', $buf) unless $buf;

    my $rv = Encode::PPUniDetector::trylocal2($buf, $prefer_euc);
    if ($rv && uc $rv ne 'UTF-8') {
        $buf = iconv($buf, 'utf-8', $rv);
    }
    return ($rv||'UTF-8', $buf);
}

sub myiconv {
    my $self = shift;
    my $str = shift;

    if (uc $self->{_prefer_charset} ne 'UTF-8') {
        # need to convert
        $str = iconv($str, 'utf-8', $self->{_prefer_charset});
    }
    # return string
    return $str;
}

sub myiconv_close {
    my $self = shift;
    delete $self->{_prefer_charset};
}

sub remove_addr {
    my $self = shift;
    my $addr = lc shift;
    my $buf = shift;
    my $str = '';

    for my $m (split (/,|;/, $buf)) {
        if ($m =~ /(^$addr$|\s+<*$addr>*)/i) {
            next;
        }
        next unless $m;
        if ($str) {
            $str .= ','. $m;
        } else {
            $str = $m;
        }
    }
    $str;
}

sub pre_run { 1 }

sub post_run {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};

    # dirty hack, to fallback original working path, ouch :-(
    unless($tpl->{noprint}) {
        my $template = $q->cgi('screen') || $tpl->{template} || 'compose.html';
        reset_working_path();
        $tpl->process($template);
        $tpl->print;
    }
}

sub DESTORY {
}

1;
