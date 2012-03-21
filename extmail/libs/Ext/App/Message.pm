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
package Ext::App::Message;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT $MSGID $MSGFILE $FOLDER $POS $t0 $t1);
@ISA = qw(Exporter Ext::App);

use vars qw($CRLF); # XXX todo
$CRLF = "\012"; # \r \015, \n \012

use Ext::App;
use Ext::MIME;
use Ext::Storage::Maildir;
use Ext::Utils;
use MIME::Base64;
use Net::SMTP;
use Ext::RFC822;
use Ext::DateTime;
use MIME::QuotedPrint;

use vars qw(%lang_readmsg $lang_charset);
use Ext::Lang;
use Ext::Unicode;

undef $MSGID;
undef $MSGFILE;
undef $FOLDER;
undef $POS;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(send_notify => \&send_notify);
    $self->add_methods(readmsg_sum => \&readmsg_sum);
    $self->add_methods(readmsg_rawdt => \&readmsg_rawdt);
    $self->add_methods(readmsg_header => \&readmsg_header);
    $self->add_methods(delete => \&delete);
    $self->add_methods(report => \&report);
    $self->add_methods(download => \&download);

    $self->{default_mode} = 'readmsg_sum';
    Ext::Storage::Maildir::init($self->get_working_path);
    Ext::MIME::init(path => $self->get_working_path, debug=>0);

    $FOLDER = fixpath($self->{query}->cgi('folder'));
    $POS = $self->{query}->cgi('pos');
    $MSGID = fixpath($self->{query}->cgi('msgid'));
    $MSGFILE = $ENV{MAILDIR}; # XXX
    $MSGFILE .= '/'._name2mdir($FOLDER);

    $self->_initme;
    if(valid_maildir($FOLDER)) {
        if(my $file = pos2file($FOLDER, $POS)) {
            if($file eq $MSGID || !$MSGID){
                $MSGFILE .= '/cur/'.$file;
                $MSGID = $file;
            }else{
                my $fname = maildir_find($FOLDER, $MSGID); # try to find it
                $MSGFILE .= '/cur/'.$fname;
                $MSGID = $fname;
            }
            $self->{tpl}->assign( MSGID => $MSGID );
        }else {
            $self->{tpl}->assign(
                # must assign sid, App::global_tpl() has not been
                # called at this stage
                #SID => $self->{query}->cgi('sid'),
                REDIRECT => 1,
                FOLDER => str2url($FOLDER)
            );
            $self->error($lang_readmsg{'message_err'});
        }
    }else {
        $self->error($lang_readmsg{'folder_err'});
    }
    $self;
}

sub _initme {
    initlang($_[0]->userconfig->{lang}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_readmsg );
}

sub delete {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $sid = $q->cgi('sid') || $q->get_cookie('sid');

    # use global $POS
    if(defined $POS) {
        my $sort_order = get_sortorder($FOLDER);
        if ($self->userconfig->{delmode} eq 'purge' || $FOLDER eq 'Trash') {
            set_bmsgs_delete($FOLDER, $POS => $q->cgi('msgid'));
        } else {
            set_bmsgs_move($FOLDER, 'Trash', $POS => $q->cgi('msgid'));
        }
        set_msgs_cache($FOLDER, $sort_order);

        # flush the $MSGFILE to the current pos file
        $MSGFILE = $ENV{MAILDIR}; # XXX
        $MSGFILE .= '/'._name2mdir($FOLDER);
        my $file = "";
        while(!($file = pos2file($FOLDER, $POS))) {
            if($POS>0) { $POS-- }
            else { last }
        }
        if($file) {
            # still has file
            $tpl->{noprint} = 1;
            $FOLDER = str2url($FOLDER);
            $self->redirect("?__mode=readmsg_sum&sid=$sid&folder=$FOLDER&msgid=$file&pos=$POS");
        }else {
            # redirect to the folder message list mode, no more
            # message can show, abort
            $tpl->assign(
                REDIRECT => 1,
                FOLDER => str2url($FOLDER)
            );
            $self->error($lang_readmsg{'message_err'});
            return;
        }
        $self->readmsg_sum;
    }else {
        $self->error($lang_readmsg{'delete_err'});
    }
}

sub report {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $sys = $self->{sysconfig};
    my $sid = $q->cgi('sid') || $q->get_cookie('sid');

    # use global $POS
    if(defined $POS) {
        my $sort_order = get_sortorder($FOLDER);
        my $app = $sys->{SYS_SPAM_REPORT_TYPE} || 'dspam';
        my $msg = $MSGFILE;

        local $ENV{PATH} = ''; # must untaint
        if ($FOLDER ne 'Junk') {
            my $cmd = "$sys->{SYS_CONFIG}/tools/spam_report.pl --type=$app --report_spam --single --msg=$msg";
            my $rc = system(untaint($cmd));
            if ($rc) {
                $self->error('Report Error!');
                return;
            }
        } else {
            my $cmd = "$sys->{SYS_CONFIG}/tools/spam_report.pl --type=$app --report_nonspam --single --msg=$msg";
            my $rc = system(untaint($cmd));
            if ($rc) {
                $self->error('Report Nonspam error!');
                return;
            }
        }

        # move message
        my $distdir = $FOLDER eq 'Junk' ? 'Inbox' : 'Junk';
        set_bmsgs_move($FOLDER, ($FOLDER eq 'Junk' ? 'Inbox' : 'Junk'), $POS => $q->cgi('msgid'));
        set_msgs_cache($FOLDER, $sort_order);

        # flush the $MSGFILE to the current pos file
        $MSGFILE = $ENV{MAILDIR}; # XXX
        $MSGFILE .= '/'._name2mdir($FOLDER);

        my $file = "";
        while(!($file = pos2file($FOLDER, $POS))) {
            if($POS>0) { $POS-- }
            else { last }
        }
        if($file) {
            # still has file
            $tpl->{noprint} = 1;
            $FOLDER = str2url($FOLDER);
            $self->redirect("?__mode=readmsg_sum&sid=$sid&folder=$FOLDER&msgid=$file&pos=$POS");
            return;
        } else {
            # redirect to the folder message list mode, no more
            # message can show, abort
            $tpl->assign(
                REDIRECT => 1,
                FOLDER => str2url($FOLDER)
            );
            $self->error($lang_readmsg{'message_err'});
            return;
        }
        $self->readmsg_sum;
    } else {
        $self->error($lang_readmsg{'report_err'});
    }
}

sub send_notify {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $sys = $self->{sysconfig};
    my $smtp_host = $sys->{SYS_SMTP_HOST} || '127.0.0.1';
    my $smtp_port = $sys->{SYS_SMTP_PORT} || '25';

    if (my $to = $q->cgi('notifyto')) {
        my $smtp = Net::SMTP->new(
            $smtp_host,
            Port => $smtp_port,
            Timeout => $sys->{SYS_SMTP_TIMEOUT} || '5',
        ) or die "Connect to $smtp_host:$smtp_port fail, $@\n";
        $smtp->mail($ENV{USERNAME});
        $smtp->to($to);
        my $msg = $smtp->message;
        my $rc = $smtp->status;
        if ($rc != 2) {
            chomp $msg;
            $tpl->assign(ERRMSG => "SMTP rcpt error: $msg");
            return;
        }

        $smtp->data();
        my $buf = '';
        $buf .= "From: $ENV{USERNAME}\n";
        $buf .= "To: $to\n";
        $buf .= "Subject: ".rfc822_encode_str('UTF-8', $lang_readmsg{'notify_subject'})."\n";
        $buf .= "Date: ".rfc822_date($self->userconfig->{'timezone'})."\n";
        $buf .= "Mime-version: 1.0\n";
        if(my $ver = $Ext::App::VERSION ? "ExtMail $Ext::App::VERSION" : '') {
            $buf .= "X-Mailer: $ver\n";
        }
        $buf .= "Content-type: text/plain; charset=\"UTF-8\"\n";
        $buf .= "Content-Transfer-Encoding: 8bit\n\n";
        $buf .= $lang_readmsg{'notify_body'} || 'NOTIFY_BODY';

        $smtp->datasend($buf);
        $smtp->dataend;
        $smtp->quit;

        set_msg_status($FOLDER, $POS, 'Replied');
    } else {
        $tpl->assign(ERRMSG => $lang_readmsg{'notify_fail'});
    }
}

sub download {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};

    my $mimeid = $q->cgi("mimeid");
    if($mimeid eq '') {
        $mimeid = 1;
    }
    $tpl->{noprint} = 1; # disable output buffer;
    get_parts($MSGFILE, $mimeid, 'to_std');
}

sub readmsg_rawdt {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};

    # disable template output bufffer
    $tpl->{noprint} = 1;

    print "Content-type: text/plain\r\n";
    print "Content-Disposition: filename=\"rawdata.txt\"\r\n\r\n";
    open(FD, "<$MSGFILE") or die "can't open $MSGFILE\n";
    while(<FD>) {
        print;
    }
    close FD;
}

sub readmsg_header {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $dir = fixpath($q->cgi('folder'));

    $tpl->{noprint} = 1;
    open(FD, "< $MSGFILE") or
        die "Can't open $MSGFILE, $!\n";
    local $/=$CRLF.$CRLF;
    my $h = <FD>;
    close FD;

    print "Content-Type: text/plain\r\n";
    print "Content-Disposition: filename=\"header.txt\"\r\n\r\n";
    print $h;
}

sub readmsg_sum {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $sid = $self->{sid};
    my $usercfg = $self->userconfig();
    my $utf8 = Ext::Unicode->new;

    $tpl->assign(READMSG_SUM=>1);
    my $parts = get_msg_info($MSGFILE);
    my $hdr = $parts->{head}{hash};

    # XXX FIXME we define a forced charset flag, it will override all
    # sub charset detection, this will simplify the whole procedure
    my $fchar = $q->cgi('charset');
    my $charset = $fchar || hdr_get_hash('charset', %$hdr);

    $utf8->set_charset($charset); # charset

    if($q->cgi("detail")) {
        $tpl->assign(DETAIL=>1);
        $tpl->assign(PARTS => mydumper($parts));
    }

    my $notify_to = hdr_get_hash('Disposition-Notification-To', %$hdr);
    my $flag_replied = ($MSGFILE =~ /:.*(R).*/) ? 1:0;
    if ($notify_to and not $flag_replied) {
        $notify_to = rfc822_addr_parse($notify_to);
        $tpl->assign(NOTIFY_TO => $notify_to->{addr});
    }

    my ($from, $to, $subject, $date) = (
        decode_words_utf8(hdr_get_hash('From', %$hdr)),
        decode_words_utf8(hdr_get_hash('To', %$hdr)),
        decode_words_utf8(hdr_get_hash('Subject', %$hdr)),
        hdr_get_hash('Date', %$hdr)
    );
    my $mailbody = ''; # the final body text

    # XXX FIXME experimental code
    my @cp_maps = qw(gb2312 gbk gb18030 big5 utf-8 iso-2022-jp shift-jis euc-jp euc-kr iso-2022-kr);
    my $matched = (grep(/^$charset$/i, @cp_maps) ? 1 : 0);

    $tpl->assign('SEL_CHARSET_LOOP', SRC_CHARSET => 'auto', CHECKED => !$matched);

    # for spam / nonspam report
    if ($self->{sysconfig}->{SYS_SPAM_REPORT_ON}) {
        $tpl->assign(CAN_REPORT_SPAM => 1);
        if ($FOLDER ne 'Junk') {
            $tpl->assign(REPORT_AS_SPAM => 1);
        } else {
            $tpl->assign(REPORT_AS_NONSPAM => 1);
        }
    }

    for (@cp_maps) {
        $tpl->assign(
            'SEL_CHARSET_LOOP',
            SRC_CHARSET => $_,
            CHECKED => lc $charset eq lc $_ ? 1 : 0,
        );
    }

    # XXX FIXME - experimental detect code - urgly !
    my $sjchar;
    TRY: {
        if ($fchar) {
            $sjchar = $fchar; # force to CGI charset parameter
            last TRY;
        }
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
    $subject = iconv($subject, $sjchar, 'utf-8') if charset_detect($subject) ne 'utf-8';

    # XXX FIXME set charset to subject charset if it's unavailable
    $charset = $sjchar unless $charset;

    my $timezone = $self->userconfig->{'timezone'};
    $tpl->assign(
        SID => $sid,
        FOLDER => str2url($FOLDER), # XXX should str2url
        POS => $POS,
        SUBJECT => html_escape($subject),
        FROM => html_escape($from),
        TO => html_escape($to),
        DATE => dateserial2str(datefield2dateserial($date), $timezone, 'auto','yyyy-mm-dd', 24),
    );

    if (my $cc = decode_words_utf8(hdr_get_hash('Cc', %$hdr))) {
        $tpl->assign( CC => html_escape($cc));
    }
    if (my $bcc = decode_words_utf8(hdr_get_hash('Bcc', %$hdr))) {
        $tpl->assign( BCC => html_escape($bcc));
    }

    my ($ref, $nomore) = get_msgs_cache($FOLDER,1,$POS);

    $tpl->assign(
        HAVE_NEXT => $nomore?0:1,
        NEXT => $nomore?$POS:$POS+1,
        HAVE_PREV => $POS eq 0?0:1,
        PREV => $POS eq 0?0:$POS-1
    );

    if($usercfg->{'page_size'}>=$POS) {
        $tpl->assign(PAGE=>0);
    }else {
        # the system int() will work for us :-)
        my $rv = int ($POS / $usercfg->{'page_size'});
        $tpl->assign(PAGE=>$rv);
    }

    # hash to indicate which part should be ignore, in general
    # they are email text/body or html
    my %ignore = ();
    if(scalar @{$parts->{body}{list}} >1) {
        # Here is the most complex part that handle email text/body
        # displaying, Hmm it should be redesign one day, ouch :-(
        my ($cnt, %th) = (0, ()); # text + html = th
        my $last_idflag;
        foreach my $p ( @{get_parts_name($parts)} ) {
            $last_idflag = $p->{idflag} unless($last_idflag); # init
            hdr_get_hash('Content-Type', %{$p->{phead}}) =~ m#(text/.*)#i;
            my $subtype = $1 || 'message/unknow';
            # Infact we should check every part's charset, but for simplify
            # reason, use the first part(text or html)'s charset
            my $char = $fchar || ${get_parts_name($parts)}[0]->{phead}{charset} || $charset;

            if( $cnt < 2 && $subtype =~ /text/i &&
                $last_idflag =~ /alternative/i &&
                $p->{idflag} eq $last_idflag) {

                # XXX experimental multi-charset handling, wait for fix
                my $print = {id=>0, type=>'text'}; # default;

                $th{text} = $cnt if($subtype=~/plain/i);
                $th{html} = $cnt if($subtype=~/html/i);

                if(exists $th{text} && exists $th{html}) {
                    if($usercfg->{show_html}) {
                        $print->{id} = $th{html};
                        $print->{type} = 'html';
                    }else {
                        $print->{id} = $th{text};
                        $print->{type} = 'text';
                    }
                }elsif(exists $th{text}) {
                    $print->{id} = $th{text};
                    $print->{type} = 'text';
                }elsif(exists $th{html}) {
                    $print->{id} = $th{html};
                    $print->{type} = 'html';
                }else {
                    # not match anything, goto attchment handling
                    goto HANDLE;
                }

                # XXX FIXME performance degrade here, get_parts will
                # call get_msg_info again, damn it, wait for fix!!
                my $body = get_parts($MSGFILE, $print->{id}, 'to_string');

                if($print->{type} eq 'text') {
                    # dirty hack on iso-2022-jp, Thanks ken lau<kenkenqd@msn.com>
                    # if we encouter iso-2022-jp, html_escape() will fail to convert
                    # and return null to caller, so we had to use <pre></pre> to
                    # display body, to be fix :-(
                    if($char=~ /iso-2022-jp/) {
                        $body = '<pre>'.$body.'</pre>';
                    }else {
                        # XXX FIXME convert to web link
                        if ($usercfg->{conv_link} && $subtype =~ /plain/i) {
                            $body = txt2html($body, html_escape=>1, txt2link=>1);
                        } else {
                            $body = html_escape($body);
                        }
                    }
                }elsif ($print->{type} eq 'html') {
                    $body = htmlsanity($body);
                }

                $utf8->set_charset($char) if ($char);
                $mailbody = $utf8->utf8_encode($body);
                $ignore{$cnt} = 1;
                $cnt++;
                next;
            }elsif($cnt < 1 && $subtype=~/text/i) {
                # only one text/plain or text/html part, no
                # alternative, compatible with some sucks MUA
                my $print = { id => 0, type => 'text'};
                if($subtype=~/html/i) {
                    $print->{type} = 'html';
                }
                my $body = get_parts($MSGFILE, $print->{id}, 'to_string');

                if($print->{type} eq 'text') {
                    if($char=~ /iso-2022-jp/) {
                        $body = '<pre>'.$body.'</pre>';
                    }else {
                        # XXX FIXME convert to web link
                        if ($usercfg->{conv_link} && $subtype =~ /plain/i) {
                            $body = txt2html($body, html_escape=>1, txt2link=>1);
                        } else {
                            $body = html_escape($body);
                        }
                    }
                } elsif ($print->{type} eq 'html') {
                    $body = htmlsanity($body);
                }

                $utf8->set_charset($char) if ($char);
                # $tpl->assign(BODY => $utf8->utf8_encode($body));
                $mailbody = $utf8->utf8_encode($body);
                $ignore{$cnt} = 1;
                $cnt++;
                next;
            }

            HANDLE:
            {
            my $cid = hdr_get_hash('Content-ID', %{$p->{phead}});
            if ($cid) {
                my $folder = str2url($FOLDER);
                my $pos = $POS;
                $cid =~ s/[<>]+//g;
                # XXX FIXME the replacement regexp now is fixed :(
                $mailbody =~ s/(cid\:$cid)/readmsg.cgi?sid=$sid&__mode=download&folder=$folder&pos=$pos&mimeid=$cnt/img;
                $cnt++ and next if ($1);
            }

            my $part_char = $fchar || hdr_get_hash('charset', %{$p->{phead}}) || $char;
            my $filename = decode_words_utf8($p->{name});

            if (charset_detect($filename) ne 'utf-8') {
                $utf8->set_charset($part_char);
                $filename = $utf8->utf8_encode($filename);
            }

            $tpl->assign(ATTACHMENT => 1);
            $tpl->assign(
                'LOOP_ATTACH',
                CNT => $cnt,
                # NAME => str2ncr($charset, $p->{name}),
                NAME => $filename,
                MSGID => $MSGID,
                HSIZE => human_size($p->{size})
            );
            $cnt ++;
            } # END of HANDLE

            $last_idflag = $p->{idflag}; # XXX
        }
        $tpl->assign(BODY => $mailbody);
    } else {
        my $type = hdr_get_hash('Content-Type', %$hdr) || 'text/plain';# top type
        my $phdr = $parts->{body}{list}->[0]->{phead};
        my $subtype = hdr_get_hash('Content-Type', %$phdr) || 'plain';
        my $charset = $fchar || hdr_get_hash('charset', %$hdr) || $sjchar; # get the charset
        my $print = {id => 0, type => 'text'};

        # if toptype or subtype match html, display it. this mechanism
        # make sense to some bad RFC compatible email, most of them are
        # spam :-) But we can disply it if user want to review.

        if (hdr_get_hash('filename', %$phdr) || hdr_get_hash('name', %$phdr)) {
            my $char = $fchar || ${get_parts_name($parts)}[0]->{phead}{charset} || $charset;
            my $p = ${get_parts_name($parts)}[0];

            $utf8->set_charset($char) if ($char);
            $tpl->assign(ATTACHMENT => 1);
            $tpl->assign(
                'LOOP_ATTACH',
                CNT => 0,
                NAME => $utf8->utf8_encode(decode_words($p->{name})),
                HSIZE => human_size($p->{size})
            );
            set_msg_status($FOLDER, $POS, 'Seen');
            return;
        }

        my $body = get_parts($MSGFILE, 0, 'to_string');
        if (hdr_get_hash('charset', %$phdr) and !$fchar) {
            $charset = hdr_get_hash('charset', %$phdr);
        }
        $utf8->set_charset($charset) if $charset;

        if (($type=~/html/ or $subtype=~/html/) && $usercfg->{show_html}) {
            $print->{type} = 'html';
            $body = htmlsanity($body);
        } else {
            if($charset=~ /iso-2022-jp/) {
                $body = '<pre>'.$body.'</pre>';
            }else {
                # $body = html_escape($body);
                #  XXX FIXME convert to web link
                if ($usercfg->{conv_link} && $subtype =~ /plain/i) {
                    $body = txt2html($body, txt2link=>1, html_escape=>1);
                } else {
                    $body = html_escape($body) if ($subtype =~ /plain/i);
                }
            }
        }
        # XXX FIXME $tpl->assign(BODY => str2ncr($charset, $body));
        $tpl->assign(BODY => $utf8->utf8_encode($body));
    }
    # update file status
    set_msg_status($FOLDER, $POS, 'Seen'); # XXX wait for fix
}

sub pre_run { 1 }
sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'readmsg.html';
    # dirty hack, to fallback original working path, ouch :-(
    reset_working_path();
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

sub DESTORY {
}

1;
