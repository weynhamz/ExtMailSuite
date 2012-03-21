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
package Ext::App::NetDisk;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::App);

use Ext::App;
use POSIX qw(strftime);
use Ext::Utils; # import human_size
use Ext::RFC822; # import date_fmt
use Ext::Storage::Fileman;
use Ext::Session; # import parse_sess()
use Ext::Storage::Maildir qw(valid_maildir _name2mdir pos2file maildir_find);
use Ext::MIME;
use Ext::Unicode::Iconv qw(iconv);
use Benchmark;

use vars qw(%lang_netdisk $lang_charset);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(list_dir => \&list_dir);
    $self->add_methods(file_mgr => \&file_mgr);
    $self->add_methods(download => \&download);
    $self->add_methods(att2ndisk => \&att2ndisk);

    $self->{default_mode} = 'list_dir';
    $self->{base} = $self->get_working_path;
    Ext::Storage::Maildir::init($self->{base});
    $self->_initme;

    if (!$self->{sysconfig}->{SYS_NETDISK_ON}) {
        $self->error($lang_netdisk{'res_unavailable'} || "Netdisk not available\n");
        return;
    }

    if ($ENV{OPTIONS} && $ENV{OPTIONS} =~ /disablenetdisk/i) {
        $self->error($lang_netdisk{'res_disabled'} || "Your netdisk disabled!\n");
        return;
    }

    $self->{base} = $self->{base} . '/fileman/';
    Ext::Storage::Fileman::init($self->{base});

    $self;
}

sub _initme {
    initlang($_[0]->userconfig->{lang}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_netdisk );
}

sub att2ndisk {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};

    my $folder = url2str($q->cgi('folder'));
    my $pos = $q->cgi('pos');
    my $msgfile = $ENV{MAILDIR}.'/'._name2mdir($folder);
    my $msgid = $q->cgi('msgid');
    my $mimeid = $q->cgi('mimeid');

    if(!valid_maildir($folder)) {
        $self->error("$folder invalid!");
        return;
    }

    my $file = pos2file($folder, $pos);
    if($file eq $msgid || !$msgid) {
        $msgfile .= "/cur/$file";
    } else {
        my $fname = maildir_find($ENV{MAILDIR}.'/'._name2mdir($folder), $msgid);
        if (!$fname) {
            $self->error("File id $pos or msgid $msgid invalid");
            return;
        }
        $msgid = $fname;
        $msgfile .= '/cur/'.$fname;
    }

    $tpl->assign(
        FOLDER => str2url($folder),
        POS => $pos,
        MSGID => $msgid,
        MIMEID => $mimeid,
    );

    if ($q->cgi('docopy')) {
        # XXX FIXME, get_parts() will save attachment filename as original
        # filename in local encoding, not utf8, so we must take care!
        my $p = get_msg_info($msgfile)->{body}{list}[$mimeid];
        my $filename = '';

        open(my $fh, "<$msgfile") or die "Can't open:$msgfile $!\n";
        my $raw_filename = dump_parts(
            $fh,
            $p->{pos_start},
            $p->{pos_end},
            $mimeid,
            'to_disk');
        close $fh;

        my $orig_filename = decode_words($raw_filename);

        if (my $charset = hdr_get_hash('charset', %{$p->{phead}})) {
            # we found the specific charset
            $filename = iconv($orig_filename, $charset, 'utf-8');
        } else {
            # try to decode if it's rfc2822 encoded
            $filename = decode_words_utf8($raw_filename);
        }
        # try to decode raw_filename to utf8, if it's rfc2822 encoded
        $filename = filename2std($filename);
        my $path = "/tmp/parts-$mimeid-$orig_filename";
        my $rc = op_addfile($path, url2str($q->cgi('dst_folder'))."/$filename");
        unlink untaint($path);

        $tpl->assign(
            FILENAME => $filename,
            DISTDIR => url2str($q->cgi('dst_folder')),
        );
        if ($rc) {
            $tpl->assign( ERRMSG => $rc );
        }
    } else {
        $tpl->assign(FILES_LIST=>1);
        my $list = fget_dirlist();
        for (@$list) {
            $tpl->assign(
                'LOOP_DIRLIST',
                DIRNAME => $_,
                DIR => str2url($_),
            );
        }
    }
    $tpl->{template} = 'att2ndisk.html';
    $self->show_curquota;
}

sub list_dir {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $base = url2str($q->cgi('base'));
    my @list;
    my $is_edit; # which is been editing

    # XXX security alarm, don't forget to untaint
    # the $base parameter, or will be very dangous!
    $base = fixslash(fixpath($base));
    $base = '' if ($base eq '/');

    $tpl->assign(FILES_LIST=>1);
    $tpl->assign(BASE_DIR => str2url($base)); # force to str2url

    if (my $name = $q->cgi('edit_filename')) {
        if ($name =~ m!/!) {
            $self->error("$name invalid!");
            return;
        }
        $is_edit = url2str($name);
    }

    my @arr = split(/\//, $base);
    my $pointer = '';

    my $list = fget_dirlist();
    for (@$list) {
        $tpl->assign(
            'LOOP_DIRLIST',
            DIRNAME => $_,
            DIR => str2url($_),
        );
    }

    $tpl->assign(
        'LOOP_NAV',
        NAV_NAME => $lang_netdisk{'root'} || 'root',
        NAV => '/',
    );

    for (my $i=1; $i< scalar @arr; $i++) {
        $tpl->assign(
            'LOOP_NAV',
            HAVE_NEXT => 1,
            NAV_NAME => $arr[$i], # display name
            NAV => str2url("$pointer/$arr[$i]"),
        );
        $pointer = "$pointer/$arr[$i]";
    }

    if ($base) {
        @list = get_files_list($base);
    } else {
        @list = get_files_list();
    }

    # path => the real meaningful file path, relative to the
    # current pwd, caution: here we have been chdir to $self->{base}
    my $i = 0;
    foreach (@list) {
        my $path = "./$base/$_";
        my ($size, $mtime) = (stat "$path")[7,9];
        my $is_dir = -d $path ? 1 : 0;

        if($size>1024) {
            if($size < 1024*1024) {
                $size = int($size/1024).'K';
            }else {
                # convert to Mbytes
                $size = sprintf("%.1fM", $size/1048576);
            }
        }

        $tpl->assign(
            'LOOP_LIST',
            FID => $i,
            FILE => $is_dir ? str2url("$base/$_") : str2url($_),
            FILE_NAME => $_,
            FILE_BASENAME => str2url($_),
            IS_EDITING => $is_edit eq $_ ? 1 : 0,
            IS_DIR => ($is_dir ? 1 : 0),
            ICON => ext2mime($_),
            MTIME => strftime ("%Y-%m-%d %H:%M",
                gmtime ($mtime + time_offset($self->userconfig->{'timezone'}))
            ),
            SIZE => $size,
        );
        $i++;
    }

    $self->show_curquota;
}

sub download {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};

    $tpl->{noprint} = 1; # disable output buffer;
    my $base = $q->cgi('base');
    my $file = $q->cgi('file');

    # open the file with raw filename first, or later operation
    # will corrupt the filename, thanks jacke2003 report
    my $stream = op_getfile("$base/$file");

    if ($ENV{HTTP_USER_AGENT} =~ /MSIE/i) {
        # netdisk contains all utf8 filename, so need to str2url
        # all filename
        $file =~ /(.*)\.([^\.]+)$/;
        $file = str2url($1).".$2" if $2;
    }
    print STDOUT "Content-Disposition: attachment; filename=\"$file\"\r\n";
    print STDOUT "Content-Type: application/octet-stream; name=\"$file\"\r\n\r\n";

    while(<$stream>) {
        print STDOUT $_;
    }
    close $stream;
}

sub file_mgr {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};

    # dir => the sub directory to operate
    # file => the request file name
    # base => the base or current directory
    my $dir = fixpath($q->cgi('dir'));
    my $file = fixpath($q->cgi('file'));
    my $base = fixpath(url2str($q->cgi('base'))); # XXX must url2str

    my $rc;
    if ($q->cgi('delete')) {
        my $a = $q->cgi_full_names;
        my @arr = grep { /^(DIR|FILE)-/ } @$a; # get multiple files
        for (@arr) {
            my $filename = url2str($q->cgi($_));
            if ($_ =~ /^DIR/) { # a directory
                # XXX remove everything before slash(/)
                # it's a dirty hack
                ($filename) = ($filename =~ /([^\/]+)$/);
                $rc = op_rmdir("$base/$filename");
            } else { # a file
                $rc = op_rmfile("$base/$filename");
            }
            next if ($rc); # abort :-(
        }
        fre_calculate(); # re-calculate the quota XXX
    } elsif ($q->cgi('mkdir')) {
        if (!foldername_ok($dir, 40) or $dir =~ /^\s+$/) {
            $rc = $lang_netdisk{err_name_invalid} || 'Invalid foldername';
        } elsif ($dir) {
            $rc = op_mkdir("$base/$dir");
        } else {
            $rc = $lang_netdisk{'err_mkdir'} || 'No dir to create';
        }
    } elsif ($q->cgi('upload')) {
        # XXX handle upload file
        if (my $lists = $q->allfiles) {
            foreach my $fh (@$lists) {
                my %header = $q->uploadInfo($fh);
                $header{filename} = filename2std($header{filename});
                $rc = op_addfile($fh, "$base/$header{filename}");
            }
        }
    } elsif ($q->cgi('rename')) {
        my $fromname = url2str($q->cgi('fromname')); # full path
        my $toname = $q->cgi('toname'); # relative path

        if ($toname =~ /^\s+$/) {
            $rc = 'Rename failed';
        }
        if ($fromname !~ m!/!) {
            # not a sub dir, then
            $fromname = "$base/$fromname";
        }
        $rc = op_rename($fromname, "$base/$toname") if (!$rc);
    } elsif ($q->cgi('moveto')) {
        my $to = url2str($q->cgi('distdir'));
        my $a = $q->cgi_full_names;
        my @arr = grep { /^(DIR|FILE)-/ } @$a; # get multiple files

        for (@arr) {
            my $from = url2str($q->cgi($_));
            if ($_ =~ /^DIR/) {
                $rc = op_move($from, $to);
            } else {
                $rc = op_move("$base/$from", $to);
            }
            next if ($rc);
        }
    } else {
        $rc = 'Bad operation request';
    }

    if ($rc) {
        $tpl->assign( ERRMSG => $rc);
    }
    $self->list_dir;
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') ||
        $_[0]->{tpl}->{template} || 'netdisk.html';
    # dirty hack, to fallback original working path, ouch :-(
    reset_working_path();
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

sub show_curquota {
    my $self = shift;
    my $tpl = $self->{tpl};

    my $inf = fget_curquota;
    my $cursize = $inf->{size};
    $tpl->assign(
        NDK_CUR_QSIZE => human_size($inf->{size}),
        NDK_CUR_QCOUNT=> $inf->{count},
    );

    $inf = fget_quota;
    # if not quota information, means permit noquota
    # over user account, so return and ignore quota calculation
    return if(!$inf->{size} && !$inf->{count});

    $self->{tpl}->assign(
        NDK_QUOTA_SIZE => human_size($inf->{size}),
        NDK_QUOTA_COUNT => $inf->{count}
    );

    my $quota_pc = $inf->{size} ? sprintf("%.2f",($cursize/$inf->{size})) : 0;

    $tpl->assign(
        NDK_QUOTA_PC => $quota_pc*100
    );

    if(my $rv = fis_overquota) {
        my $msg = $lang_netdisk{'quota_warn'};
        $tpl->assign(NDK_OVERQUOTA => 1);

        if($rv eq 2) {
            # Mailbox overquota, ouch :-(
            $msg = $lang_netdisk{'quota_over'};
        }
        $tpl->assign(NDK_OVERQUOTA_MSG => $msg);
    }else {
        $tpl->assign(NDK_OVERQUOTA => 0);# disable the tpl if statement
    }
}

sub DESTORY {
}

1;
