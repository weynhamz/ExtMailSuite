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
package Ext::MgrApp::GroupMail;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
use POSIX qw(strftime);
use Ext::Utils; # import url2str
use Ext::MgrApp;
use Ext::RFC822;
use MIME::Base64;
use Ext::CGI;
use vars qw($lang_charset %lang_groupmail);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(edit_mail => \&edit_mail);
    $self->add_methods(send_mail => \&send_mail);
    $self->{default_mode} = 'edit_mail';

    $self->_initme;
    $self;
}

sub _initme {
    initlang($_[0]->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_groupmail );
}

sub edit_mail {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $sys = $self->{sysconfig};
    my $domains = [];

    if ($ENV{USERTYPE} eq 'admin') {
        my $alldomain = $mgr->get_domains_list || [];
        foreach my $d ( @$alldomain ) {
            push @$domains, $d->{domain};
        }
    } else {
        my $pm = $mgr->get_manager_info($ENV{USERNAME});
        $domains = $pm->{domain};
    }

    if ($domains) {
        $domains = [$domains] unless (ref $domains);
        foreach my $vd ( @$domains ) {
            $tpl->assign(
                'LOOP_DOMAIN',
                DOMAIN => $vd
            );
        }
    } else {
        # no permission or not assign domain
        $tpl->assign(NOPERM => 1);
        $tpl->assign(HAVE_USER => 0);
    }
    $tpl->assign(
        SUBJECT => $q->cgi('subject'),
        BODY => $q->cgi('body'),
        RECIPIENT => $q->cgi('recipient'),
    );
}

sub send_mail {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $mgr = $self->{backend};
    my $q = $self->{query};
    my $charset = $lang_charset; # infact it's always utf-8

    my $recip = $q->cgi('recipient');
    my $subject = $q->cgi('subject');
    my $body = $q->cgi('body');
    my $domain = $q->cgi('domain');
    my $all = $q->cgi('alldomain') ? 1 : 0;

    # permission validation for specific domain
    unless ($self->valid_perm($domain)) {
        $self->error('Access denied');
        return 0;
    }

    my $addrs = [];
    my $rc = '';
    if ($all) {
        if ($ENV{USERTYPE} eq 'admin') { # supper user
            my $ds = $mgr->get_domains_list || [];
            foreach my $vd (@$ds) {
                my $us =  $mgr->get_users_list($vd->{domain}) || [];
                foreach my $u (@$us) {
                    push @$addrs, $u->{mail};
                }
            }
        } else {
            my $ref = $self->manager_owndomain($ENV{USERNAME});
            foreach my $vd ( @$ref ) {
                my $us = $mgr->get_users_list($vd) || [];
                foreach my $u (@$us) {
                    push @$addrs, $u->{mail};
                }
            }
        }
    } else {
        $recip =~ s![^a-zA-Z0-9-_\.=,\n@]!!sg;
        $recip =~ s!\r!!sg;
        $recip =~ s! !!sg;

        if ($recip =~ m#^[\n\s]*@[\n\s]*#s) {
            # only contain @, means group send to a domain
            my $us = $mgr->get_users_list($domain) || [];
            foreach my $u (@$us) {
                push @$addrs, $u->{mail};
            }
        } elsif ($recip =~ m/^[^\@]+$/s) {
            foreach my $r (split(/\n+/, $recip)) {
                push @$addrs, "$r\@$domain";
            }
        } else {
            $tpl->assign(ERROR => $lang_groupmail{'errinput'});
            $self->edit_mail;
            return 0;
        }
    }

    $rc = $self->send_groupmail($addrs);

    if ($rc) {
        $tpl->assign(ERROR => $rc);
    } else {
        $tpl->assign(SUCCESS => $lang_groupmail{'okmail'});
    }
    $self->edit_mail;
}

sub send_groupmail {
    my $self = shift;
    my $addrs = $_[0]; # must ref
    my $num = scalar @$addrs;
    my $limit = $self->{sysconfig}->{SYS_PERMAIL_LIMIT} || '100';
    my $buf = [];

    return $lang_groupmail{'noaddrs'} unless (scalar @$addrs);

    while (my $addr = pop @$addrs) {
        if (scalar @$buf < $limit) {
            push @$buf, $addr;
        } else {
            my $rc = $self->_mail($buf);
            $buf = []; # cleanup
            push @$buf, $addr; # still need to add!
            return $rc if ($rc);
        }
    }

    if (scalar @$buf > 0) {
        # still have some recip
        my $rc = $self->_mail($buf);
        return $rc if ($rc);
    }
    '0'; # default to success
}

sub _mail {
    my $self = shift;
    my $buf = $_[0]; # must ref
    my $q = $self->{query};
    my $chst = $self->{sysconfig}->{SYS_CHARSET} || 'us-ascii';
    my $sender = $self->{sysconfig}->{SYS_GROUPMAIL_SENDER} || $ENV{USERNAME};
    my $sendmail = "/usr/sbin/sendmail -oi -t -f \"$sender\"";

    # Code from ExtMail
    my $errbuf;

    open(WFH, "|$sendmail") or
        die $lang_groupmail{'errmail'}."broken pipe: $!\n";

    my $body = $q->cgi('body');
    my $html = $q->cgi('html');
    my $boundary;
    my $attach = $q->allfiles ? 1: 0;
    my $type = ($attach ? 'multipart/mixed' : ($html ? 'text/html' : 'text/plain'));

    $boundary = sprintf "=_%s_%s_%s", int(rand(100)), $$, time if ($attach);

    print WFH 'From: "'.rfc822_encode_str($chst, $sender)."\" <$sender>\n";
    print WFH 'Bcc: '.rfc822_encode_addr($chst,join(',',@$buf))."\n";
    print WFH 'Subject: '.rfc822_encode_str($chst,$q->cgi('subject'))."\n";
    print WFH "To: \"NO-REPLY\" <>\n"; # NULL
    print WFH 'Date: '.rfc822_date($self->{sysconfig}->{SYS_TIMEZONE})."\n";
    print WFH "Mime-Version: 1.0\n";
    print WFH "X-Originating-Ip: [$ENV{REMOTE_ADDR}]\n";
    print WFH "X-Mailer: ExtMan - GroupMail\n";
    print WFH "Content-Type: $type; charset=$chst";
    if ($attach) {
        print WFH "; boundary=\"$boundary\"\n";
    } else {
        print WFH "\n";
    }
    print WFH "Content-Transfer-Encoding: 8bit\n\n";

    if ($attach) {
        my $type = ($html ? 'text/html' : 'text/plain');
        print WFH "This is a MIME-formatted message.  If you see this text it means that your\n";
        print WFH "mail software cannot handle MIME-formatted messages.\n\n";
        print WFH "--$boundary\n";
        print WFH "Content-Type: $type; charset=\"$chst\";\n";
        print WFH "Content-Transfer-Encoding: 8bit\n\n";
    }

    # it's the right time to parse template from body
    my $list = '';
    foreach my $l (@$buf) {
        $list .= "    $l\n";
    }
    $body =~ s!\$ALL!$list!g;
    print WFH "$body\n";

    if ($attach) {
        my $lists = $q->allfiles;
        foreach my $fh (@$lists) {
            my %header = $q->uploadInfo($fh);
            $header{filename} = filename2std($header{filename});

            print WFH "--$boundary\n";
            print WFH "Content-Disposition: attachment; filename=\"$header{filename}\"\n";
            print WFH 'Content-Type: '.$header{'Content-Type'}."; charset=\"$chst\"; name=\"$header{filename}\"\n";
            print WFH "Content-Transfer-Encoding: base64\n\n";
            while(read($fh, my $buf, 60*57)) {
                print WFH encode_base64($buf);
            }
            close $fh;
            print WFH "\n"; # need?
        }
        print WFH "--$boundary--\n";
    }

    close WFH or $errbuf = "Send fail, return code $?";

    if ($errbuf) {
        $errbuf =~ s#\n#</br>\n#g;
        die "$errbuf";
    }

    '0'; # default to success
}

sub _cvt2formal {
    my $filename = shift;
    if($filename=~/\\/) { # win32 filename, eg: c:\\doc\\test.gif
        $filename=~ s#.*\\+([^\\]+)$#$1#;
    }elsif($filename=~/\//) { # Unix path name, eg: /path/to/test.gif
        $filename=~ s#.*\/+([^\/]+)$#$1#;
    }else {
        $filename=~ s#\s##g; # remove all space
    }
    $filename
}

sub hdr_fmt_hash {
    my @a = hdr_fmt_list($_[0]);
    my %head;
    foreach(@a) {
        next unless (ref $_ eq 'HASH');
        foreach my $k (keys %$_) {
            if($k=~/^Content/) {
                my @temp = split(/; /,$$_{$k});
                $head{$k} = $temp[0];
                foreach(@temp) {
                    s/\t//g;
                    if(/=/) {
                        my($k,$v)=m/([a-zA-Z0-9-_]+)="*([^\"]*)"*/;
                        $head{$k} = $v if not defined $head{$k};
                    }
                }
            }else {# common header(may be in mail head
                if(not defined $head{$k}) {
                    $head{$k} = $$_{$k};
                }else {
                    if(ref $head{$k} eq 'ARRAY') {
                        push @{$head{$k}}, $$_{$k};
                    }else {
                        $head{$k} = [$head{$k}, $$_{$k}];
                    }
                }
            }
        }
    }
    %head;
}

sub hdr_fmt_list {
    my $s = $_[0];
    $s =~ s/\n\s+/ /g; # cat \n\t or \n[:space]+ together
    my @a = split(/\n/, $s);

    foreach (0...(scalar @a-1)) {
        my($k, $v) = ($a[$_]=~ m/^([^:]+):\s*(.*)\s*$/g);
        next if (not defined $k);
        if(defined $v and $v=~/=\?[^?]*\?[QB]\?[^?]*\?=/) {
            $v=~s/(\?=)\s+(=\?)/$1$2/g; # cat multiple Q/B encode strs into one.
        }
        $a[$_] = {$k=>$v};
    }

    @a;
}

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'edit_groupmail.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
