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
package Ext::Storage::Maildir;
use strict;

# Maildir++ specification
# see http://www.inter7.com/courierimap/README.maildirquota.html
#
# Contents of maildirsize
# maildirsize contains two or more lines terminated by newline characters.
#
# The first line contains a copy of the quota definition as used by the
# system's mail server. Each application that uses the maildir must know
# what it's quota is. Instead of configuring each application with the
# quota logic, and making sure that every application's quota definition
# for the same maildir is exactly the same, the quota specification used
# by the system mail server is saved as the first line of the maildirsize
# file. All other application that enforce the maildir quota simply read
# the first line of maildirsize.
#
# The quota definition is a list, separate by commas. Each member of the
# list consists of an integer followed by a letter, specifying the nature
# of the quota. Currently defined quota types are 'S' - total size of all
# messages, and 'C' - the maximum count of messages in the maildir.
#
# For example, 10000000S,1000C specifies a quota of 10,000,000 bytes or
# 1,000 messages, whichever comes first.
#
# All remaining lines all contain two integers separated by a single space.
# The first integer is interpreted as a byte count. The second integer is
# interpreted as a file count. A Maildir++ writer can add up all byte
# counts and file counts from maildirsize and enforce a quota based either
# on number of messages or the total size of all the messages.
#

# Maildir specification
# see http://cr.yp.to/proto/maildir.html

# Update 2005-07-28, experimantal OO design, now use global varibles to
# store configuration and some information instead of using object, for
# performance reason. OO object new/del a hundred thousand times will
# be much slower than direct reference :-(

use Fcntl ':flock';
use Exporter;
use vars qw(@ISA @EXPORT %CFG $SORTORDER);
@ISA = qw(Exporter);
@EXPORT = qw(
    mk_maildir rm_maildir get_quota get_curquota reset_quota
    re_calculate update_quota is_overquota scan_dir get_dirs_list
    get_msgs_list get_msgs_cache set_msgs_cache get_dir_cnt
    check_new is_new get_status set_status is_subdir _name2mdir
    pos2file update_bmsgs_cache get_bmsgs_cache set_msg_status
    set_bmsgs_delete set_bmsgs_move parse_curcnt maildir_find
    update_quota_s gen_std_maildir has_attach get_sortorder
    rebuild_msgs_cache is_sys_maildir valid_maildir mv_maildir
    valid_dirname purge_maildir check_curcnt fixpath cvt2method
    parse_cache);

%CFG=();
use Ext::MIME; # _set_msgs_cache use it
use Ext::Utils qw(untaint _index _substr _length human_size);
use Ext::RFC822 qw(str2time); # import str2time
use Ext::DateTime qw(datefield2dateserial);
use constant CACHE_CNT_LIFE => 7200; # 60 minutes to renew cnt
use constant CACHE_CUR_LIFE => 7200; # 60 minutes to rebuild curcache

# init - init a Maildir, for read/write and quota maintains
sub init {
    my ($path, $mode, $warnlv) = @_;

    # XXX the magic to set default permission
    umask(0077);

    $CFG{path} = $path ? $path : "."; # relative path
    $CFG{mode} = $mode ? $mode : "O_RW";
    $CFG{warnlv} = $warnlv ? $warnlv : "0.9"; # 90% default

    chdir(untaint($CFG{path})) or die "Can't chdir to $CFG{path}, $!\n";

    mkdir "cur", 0700 if(!-d 'cur');
    mkdir "new", 0700 if(!-d 'new');
    mkdir "tmp", 0700 if(!-d 'tmp');

    # Check the default subdir and create them if not present
    mk_maildir('.Sent') if(!-d '.Sent');
    mk_maildir('.Drafts') if(!-d '.Drafts');
    mk_maildir('.Trash') if(!-d '.Trash');
    mk_maildir('.Junk') if(!-d '.Junk');

    if(! -e $CFG{path}.'/maildirsize') {
        re_calculate();
    }

    # re-calculate if more than 5120 bytes
    if((stat $CFG{path}.'/maildirsize')[7] >= 5120) {
        re_calculate();
    }

    1;
}

# mk_maildir - create maildir
sub mk_maildir {
    my $folder = _name2mdir($_[0]);

    return 0 unless valid_dirname($folder);
    return 0 if(-d $folder);

    $folder = untaint($folder);
    mkdir $folder, 0700;
    _touch("$folder/maildirfolder");
    mkdir "$folder/cur", 0700 if(!-d "$folder/cur");
    mkdir "$folder/new", 0700 if(!-d "$folder/new");
    mkdir "$folder/tmp", 0700 if(!-d "$folder/tmp");
    1;
}

# rm_maildir - delete maildir
sub rm_maildir {
    my $folder = $_[0];
    my $flag = $_[1];

    # not need to check folder name if $flag, because
    # it's internal function call, not called by other module
    return 0 if (!$flag && !valid_dirname($folder));
    $folder = _name2mdir($folder) unless($flag);

    if($folder =~/^\.(Inbox|Sent|Drafts|Trash|Junk|\.)$/) {
        # Ignore default folder
        return 0;
    }

    if(-d $folder) {
        my @entries = ();
        opendir DIR, $folder or die "Can't opendir, $!\n";
        @entries = grep { !/^\.$/ && !/^\..$/ } readdir(DIR);
        closedir DIR;

        for my $f (@entries) {
            if(-d "$folder/$f") {
                # the $flag is to indicate that whether we
                # are in recursive mode, if yes ignore all checks
                rm_maildir("$folder/$f", 1);
                next;
            }
            unlink untaint("$folder/$f");
        }
        rmdir untaint($folder); # this remove dir left
        return 1;
    }
    0;
}

sub mv_maildir {
    my ($from, $to) = @_;

    # folder name not valid? just return
    return 0 if (!valid_dirname($to) || !valid_dirname($from));

    $from = _name2mdir($from);
    $to = _name2mdir($to);
    if ($from =~ /^\.(Inbox|Sent|Drafts|Trash|Junk|\.)$/ ||
        $to =~ /^\.(Inbox|Sent|Drafts|Trash|Junk|\.)$/) {
        return 0;
    }

    if (-d $to) {
        return 0;
    }
    rename (untaint($from) , untaint($to)); # rename
    return 1;
}

sub purge_maildir {
    my $folder = $_[0];

    return 0 if (!valid_dirname($folder));
    $folder = _name2mdir($folder);

    if($folder =~/^\.(Inbox|Sent|Drafts|\.)$/) {
        # Ignore default folder
        return 0;
    }

    if(-d $folder) {
        for my $dir (qw(cur tmp new)) {
            my @entries = ();
            opendir DIR, "$folder/$dir" or die "Can't opendir, $!\n";
            @entries = grep { !/^\.$/ && !/^\..$/ } readdir(DIR);
            closedir DIR;

            for my $f (@entries) {
                unlink untaint("$folder/$dir/$f");
            }
        }
        for my $f (qw(extmail-curcache.db extmail-curcnt)) {
            unlink "$folder/$f";
        }
        return 1;
    }
    0;
}

# get_quota - to get a Maildir quota limitation info, return a HASH
sub get_quota {
    my $path = $CFG{path};
    my ($smax, $cmax);

    # Update 2005-07-26, check maildirsize first, fallback to
    # $ENV{DEFAULT_QUOTA} if not present.
    if(-e "$path/maildirsize") {
        open(my $FD, "< $path/maildirsize") or
            die "Can't open maildirsize, $!\n";
        $_=<$FD> || "";
        close FD;
    }elsif($ENV{QUOTA}) {
        $_=$ENV{QUOTA};
    }else {
        $_=$ENV{DEFAULT_QUOTA};
    }

    if(!length($_)) {
        return {
            size => undef,
            count => undef
        }
    }
    if(/(\d+)C/i) {
        # has a count quota
        $cmax = $1;
    }elsif(/(\d+)S/i) {
        # has a size quota
        $smax = $1;
    }

    return {
        size =>$smax,
        count => $cmax
    }; # return a ref of HASH
}

# get_curquota - to get current quota usage, return a ARRAY not HASH
sub get_curquota {
    my $path = $CFG{path};

    my ($size, $cnt) = (0,0);
    open(FD, "<$path/maildirsize") or
        die "Can't open maildirsize, $!\n";
    my $s = <FD>; # omit the first line;
    seek(FD,0,0) unless($s=~/S|C/); # unget if no quota limit
    while(<FD>) {
        chomp;
        /\s*([\-]*\d+)\s+([\-]*\d+)/;
        $cnt = $cnt+$2;
        $size = $size+$1; # include -xxx, perl will automaticlly
                          # handle nagetive value :)
    }
    return {
        size => $size,
        count => $cnt
    }; # return a ref of HASH
}

# set_quota - reset quota to a new value, mostly used by ADMIN API
sub reset_quota {
    my ($q_size, $q_cnt) = @_;
    my $path = $CFG{path};

    open(FD, "< $path/maildirsize") or
        die "Can't open maildirsize, $!\n";
    my $s = <FD>;# omit the first line
    seek(FD,0,0) unless($s=~/S|C/); # unget if no quota limit
    local $/= undef;
    $s = <FD>;
    close FD;

    open(FD, "> $path/tmp/maildirsize.tmp") or
        die "Can't open maildirsize.tmp for write, $!\n";
    print FD "$q_size"."S";
    if($q_cnt) {
        print FD ",$q_cnt"."C";
    }
    print FD "\n"; # newline
    print FD $s;
    close FD;

    unlink untaint("$path/maildirsize") || die "unlink fail: $!\n";
    rename untaint($path."/tmp/maildirsize.tmp"), untaint($path."/maildirsize") or
        die "Can't rename:$!\n";
    1;
}

sub re_calculate {
    open(my $FD, "> $CFG{path}/tmp/maildirsize.tmp") or
        die "Can't open maildirsize.tmp: $!\n";
    my $inf = get_quota;
    if($inf->{size} and $inf->{count}) {
        print $FD $inf->{size}."S,".$inf->{count}."C\n";
    }elsif($inf->{size}) {
        print $FD $inf->{size}."S\n";
    }elsif($inf->{count}) {
        print $FD $inf->{count}."C\n";
    }
    close $FD;

    $inf = scan_dir();
    $CFG{mdspath} = $CFG{path}."/tmp/maildirsize.tmp";
    update_quota($inf->{size}, $inf->{new}+$inf->{seen});
    delete $CFG{mdspath}; # clean it after usage

    rename (untaint($CFG{path}."/tmp/maildirsize.tmp"),
            untaint($CFG{path}."/maildirsize"))
        or die "Can't rename maildirsize, $!\n";
}

# update_quota - do an append action to maildirsize file.
sub update_quota {
    my ($size, $count) = @_;
    my $file = defined $CFG{mdspath} ?
                   $CFG{mdspath}: $CFG{path}.'/maildirsize';

    $file = untaint ($file);
    open(FD, ">> $file") or
        die "Can't open maildirsize, $!\n";
    flock(FD, LOCK_EX);
    my $str = _fmt2mds($size, $count);
    print FD $str;
    flock(FD, LOCK_UN);
    close FD;

    # after update, check maildirsize file size;
    if((stat $file)[7] >= 5120) {
        re_calculate();
    }
}

# update_quota_s - update bunch of quota records
sub update_quota_s {
    my $ref = $_[0];
    my $file = defined $CFG{mdspath} ?
                  $CFG{mdspath}: $CFG{path}.'/maildirsize';

    $file = untaint ($file);
    open(my $FD, ">> $file") or
        die "Can't open maildirsize, $!\n";
    flock($FD, LOCK_EX);
    foreach(keys %$ref) {
        my($s,$c) = split(/\s/, $ref->{$_});
        my $str = _fmt2mds($s,$c);
        print $FD $str;
    }
    flock($FD, LOCK_UN);
    close $FD;

    # after update, check maildirsize file size;
    if((stat $file)[7] >= 5120) {
        re_calculate();
    }
}

# _fmt2mds format given params into maildirsize record
sub _fmt2mds {
    my $smaxlen = 8; # recommand 10 digitals
    my $cmaxlen = 5; # recommand 6 digitals
    my $put = "";
    my($s,$c) = @_; # size can be nagetive, like -1260
    if(length($s) < $smaxlen) {
        my $delta = $smaxlen - length($s);
        $put .= " " x $delta . "$s";
    }else {
        $put .="$s";
    }

    if(length($c) < $cmaxlen) {
        my $delta = $cmaxlen - length($c);
        $put .=" ". " " x $delta . "$c";
    }else {
        $put .=" $c";
    }

    return "$put\n";
}

# is_overquota - check whether a Maildir is over quota, need get_quota
# this function will automatically set overquota flag to a file:
# $HOME/Maildir/quotawarn.
#
# Tricks: if any of (size, count) is 'undef' or '0', means no limit!
#
# Update: 2005-07-31 use SOFT/HARD_OVER to identify whether a maildir
# is nearly overquota or already overquota
#
# 2005-08-05 add two params to calculate where it's overquota, while
# writing a new email
use constant NO_OVERQT => 0;
use constant SOFT_OVER => 1;
use constant HARD_OVER => 2;
sub is_overquota {
    my ($addsize, $addcnt) = @_;
    my $cur = get_curquota();
    my ($q_size, $q_cnt);
    my $sig = 0; # XXX NOT_OVER

    my $inf = get_quota();
    $q_size = $inf->{size} ? $inf->{size} : 0;
    $q_cnt = $inf->{count} ? $inf->{count} : 0;

    $cur->{size} += $addsize if(defined $addsize && $addsize>0);
    $cur->{count} += $addcnt if(defined $addcnt && $addcnt>0);

    if($q_cnt) { # quota set
        if($cur->{count} >= $q_cnt) {
            $sig = 2; # XXX HARD_OVER
        }elsif($cur->{count} >= int($q_cnt*$CFG{warnlv})) {
            $sig = 1; # XXX SOFT_OVER
        }
    }

    if($q_size) { # quota set
        # XXX all SOFT_OVER
        unless ($sig>1) { # if not HARD_OVER
            if($cur->{size} >= $q_size) { # HARD_OVER
                $sig = 2;
            }else {
                if($cur->{size} >= $q_size*$CFG{warnlv}) {
                    $sig = 1;
                }
            }
        }
    }

    if($sig) {
        _touch("quotawarn");
    }else {
        my $qf = $CFG{path}.'/quotawarn';
        if(-e $qf) {
            unlink untaint($qf);
        }
    }
    $sig;
}

# Maildir files and messages handl func*
#
# Scheme defination:
# 2 types of special folders, Inbox and SubBox. typeglob:
#
# $maildir/cur
# $maildir/new
# $maildir/tmp
# $maildir/.Drafts/cur
# $maildir/.Drafts/new
# $maildir/.Drafts/tmp
#
# subBox of subBox:
# $maildir/.SubBox1/cur
# $maildir/.SubBox1/new
# $maildir/.SubBox1/tmp
# $maildir/.SubBox1::SubBox2/cur
# $maildir/.SubBox1::SubBox2/new
# $maildir/.SubBox1::SubBox2/tmp
#
# So we provide several func* to get the following info:
# 1) Total of sizes, seens, news  => scan_dir();
# 2) A certain SubBox's size, seen, new => get_dir_cnt($dir);
# 3) Inbox size, seen, new => get_dir_cnt('Inbox');
sub scan_dir {
    my @dir = get_dirs_list();
    my ($new, $seen, $tsize) = (0,0,0);

    # Include Inbox, in fact that append a "."
    foreach(@dir) {
        check_new($_);
        my $inf = get_dir_cnt($_);
        $new = $new + $inf->{new};
        $seen = $seen + $inf->{seen};
        $tsize = $tsize + $inf->{size};
    }
    return {
        new => $new,
        seen => $seen,
        size => $tsize
    }; # return a ref
}

# get_dirs_list - a public func to get a formated folder/subfolders list
sub get_dirs_list {
    my @dir = _get_dirs_list();# only get the none sysdefault dir :)
    my @sysdir = ("Inbox", "Sent", "Drafts", "Trash", "Junk");
    unshift @dir, @sysdir;
    @dir;
}

# _get_dirs_list - get the whole Maildir++ folder/subfolder list
# exclude the special "INBOX", "Trash", "Drafts", "Sent", "Junk"
sub _get_dirs_list {
    my $path = $CFG{path};
    opendir DIR, $path || die "Can't opendir $path, $!\n";
    my @dir = sort {$a cmp $b} grep {
                     !/^\.Drafts$/ && !/^\.Sent$/ && !/^\.Junk$/
                     && !/^\.Trash$/ && !/^\.$/ && !/^\..$/
                     && -d $_ && -e "$_/maildirfolder"
              } readdir DIR; # assume that we've chdir!!
    close DIR;

    $dir[$_]=~ s/^\.// for(0...$#dir);
    @dir;
}

# get_msg_list - get an ref to ARRAY to lists the specify dir
sub get_msgs_list {
    my $dir = _name2mdir($_[0]);
    return _get_msgs_list($dir);
}

sub _get_msgs_list {
    my $dir = $CFG{path}."/$_[0]/cur";

    #_check_new($_[0]);
    opendir DIR, $dir || die "Can't opendir $dir, $!\n";
    my @f = grep { !/^\./ } readdir DIR;
    close DIR;

    \@f; # return a ref ARRAY :-)
}

# MSG_CACHE handle functions
#
# the following routines handle most of curcache operation, include:
# 1) get the seen/new counts of a certain dir, eg: Inbox
# 2) get the savetime of cache file
# 3) get the specify msgs cache info in a certain offset.
# 3) get a bunch of msgs cache information base on pos ids.
#
# XXX CACHE design
#
# XXX HEAD:
#
# SAVETIME=%s\n     * cache savetime
# COUNT=%s\n        * seen messages count
# NEWCOUNT=%s\n     * unseen messages count
# SORT=%s\n         * sort method
# VERSION=%s\n      * the cache algorithm version
#
# XXX REC$i:
#
# FILENAME=%s\n
# FROM=%s\n
# TO=%s\n           * multiple values concat with space
# SUBJECT=%s\n
# SIZES=%s\n
# DATE=%s\n
# DATETIME=%s\n     * result of str2time($DATE)
# STATUS=%s\n
# TIME=%s\n
# INODE=%s\n
# CONTENTTYPE=%s\n  * the content type
# CHARSET=%s\n      * the charset found in header
# LABEL=%s\n        * marked as a certain label
# EXTENSION=%s\n    * for future use
sub get_msgs_cache {
    my ($fd, $nfiles, $pos) = @_;
    my $cache_file = $CFG{path}.'/'._name2mdir($fd).'/extmail-curcache.db';

    if(-r $cache_file) {
        use Ext::DB;
        my %hash = ();
        my $db = Ext::DB->new(file => "Btree:$cache_file");

        my $info = parse_cache($db->lookup('HEADER'));
        my $end = ($pos+$nfiles)>= ($info->{COUNT}+$info->{NEWCOUNT}) ?
            $info->{COUNT}+$info->{NEWCOUNT} : $pos+$nfiles;

        # update in 2005-08-19, return a flag to indicate whether
        # there are more entires in cache
        my $nomore = ($pos+$nfiles)>= ($info->{COUNT}+$info->{NEWCOUNT}) ?
            1 : 0;

        foreach(my $i=$pos; $i<$end; $i++) {
            $hash{$i} = parse_cache($db->lookup("REC$i"));
        }
        return (\%hash, $nomore);
    }else {
        die "Can't read $cache_file, $!\n";
    }
    1;
}

# get a bunch msgs cache info, useful while implementing setting a bunch
# of msgs to READED or UNREAD, or other type. But this task can be imple-
# mented by focusing on file name FLAG, etc.
sub get_bmsgs_cache {
    my ($fd, @pos) = @_;
    my $cache_file = $CFG{path}.'/'._name2mdir($fd).'/extmail-curcache.db';

    if(-r $cache_file) {
        use Ext::DB;
        my %hash = ();
        my $db = Ext::DB->new(file => "Btree:$cache_file");

        foreach(@pos) {
            $hash{$_} = parse_cache($db->lookup("REC$_"));
        }
        return \%hash;
    }else {
        die "Can't read $cache_file, $!\n";
    }
    1;
}

# update_bmsgs_cache - update msgs filename(flag) and etc..
# format: $hash => key => pos, value => FLAG(+/- A-Z)
sub update_bmsgs_cache {
    my ($fd, %hash) = @_;
    my $cache_file = $CFG{path}.'/'._name2mdir($fd).'/extmail-curcache.db';

    if(-r $cache_file) {
        use Ext::DB;
        my $db = Ext::DB->new(
            file => "Btree:$cache_file",
            flags => 'write');
        foreach my $pos (keys %hash) {
            $db->update("REC$pos", $hash{$pos});
        }
        return 1;
    }else {
        return 0;
    }
}

sub pos2file {
    my ($fd, $pos) = @_;
    my $cache = get_bmsgs_cache($fd, $pos);
    $cache->{$pos}->{'FILENAME'};
}

sub gen_std_maildir {
    my $tmpfile = shift;
    my $time = _gen_time_part();
    my @a = _gen_file_part($tmpfile);
    return $time.'P'.$$.'V'.$a[0].'I'.$a[1];
}

sub _length_fmt {
    my ($s, $len) = @_;
    my $delta  = 0;
    if(length($s)<$len) {
        $delta = $len - length($s);
    }
    return ('0' x $delta).$s;
}

sub _gen_time_part {
    eval {
        require 'sys/syscall.ph';
    };
    if($@) { return time; }
    return time unless (defined &SYS_gettimeofday);

    my $start = pack('LL', ());
    syscall(&SYS_gettimeofday, $start, 0) != -1
        or die "gettimeofday: $!";
    my @start = unpack('LL', $start);
    return $start[0].'.M'.$start[1];
}

sub _gen_file_part {
    my @a = map { uc(sprintf "%x",$_) } (stat $_[0])[0,1];
    my $dev = _length_fmt($a[0], 16);
    my $inode = _length_fmt($a[1], 8);
    return($dev, $inode);
}
# this function is very important while a given message filename
# not actually exist in cache, it will try to search a file, which
# is most to be close to the given name.
sub maildir_find {
    my ($fd, $file) = @_;
    return "" unless($file); # check $file null or not
    return $file if (-r _name2mdir($fd).'/cur/'.$file);

    $file =~ s/(:?,S=\d+)*:2,.*$//; # the static part
    opendir DIR, _name2mdir($fd).'/cur/' or die "Error $!\n";
    my @lists = grep { !/^\./ } readdir DIR;
    close DIR;
    for(@lists) {
        my $tmpname = $_;
        $tmpname =~ s/(:?,S=\d+)*:2,.*$//;
        if($tmpname eq $file) {
            if(m#/#) {
                s/.*\/([^\/]+)$/$1/; # save the filename
            }
            return $_;
        }
    }
    ""; # not found similar
}

sub parse_cache {
    my $s = $_[0];
    my %info = ();
    foreach (split(/\n/, $s)) {
        my $tk = index($_, '=');
        my $len = length $_;
        $info{substr($_, -$len, $tk)} = substr($_, $tk+1);
    }
    \%info;
}

# XXX with pos id resort function, slow ?! has been optimize
# using hash ref and smart tech:(
sub _delete_bmsgs_cache {
    my ($dir, @pos) = @_;
    my $poshash = _array2hash(@pos);
    my $cache = $CFG{path}."/"._name2mdir($dir)."/extmail-curcache.db";

    use Ext::DB;
    my $db = Ext::DB->new(
        file => "Btree:$cache",
        flags => "write"
    );

    my $info = parse_cache($db->lookup('HEADER'));
    my $nums = $info->{NEWCOUNT}+$info->{COUNT};
    my %newhash = (); # XXX new copy
    my $npos = 0;
    foreach(0...$nums-1) {
        if(_exist_pos_id($_, $poshash)) {
            my $lv = parse_cache($db->lookup("REC$_"));
            $db->delete("REC$_");
            if(is_new($lv->{FILENAME})) {
                $info->{NEWCOUNT}--;
            }else {
                $info->{COUNT}--;
            }
        }else {
            $newhash{$npos} = $db->lookup("REC$_");
            $npos++;
        }
    }

    undef $db; # destory the object
    unlink untaint($cache); # XXX rebuild now
    $db = Ext::DB->new(
        file => "Btree:$cache",
        flags => 'write'
    );
    my $nheader = sprintf "SAVETIME=%s\nCOUNT=%s\nNEWCOUNT=%s\n".
         "SORT=%s\n",time,$info->{COUNT},$info->{NEWCOUNT},
         $info->{SORT};
    $db->update('HEADER', $nheader);
    for(0...$npos) {
        $db->insert("REC$_", $newhash{$_});
    }
}

# convert an array to hash, for big loop compare using
# XXX
sub _array2hash {
    my @a = @_;
    my %h = ();
    for(@a) {
        $h{$_} = 1;
    }
    \%h;
}

# compare pos id with given parameter
sub _exist_pos_id {
    my ($key, $ref) = @_;
    if($ref->{$key}) { # exist
        delete $ref->{$key};
        return 1;
    }
    0;
}

sub get_sortorder {
    my $dir = _name2mdir($_[0]);
    my $cache = "$dir/extmail-curcache.db";

    use Ext::DB;
    my $db = Ext::DB->new(file => "Btree:$cache");
    my $header = parse_cache($db->lookup('HEADER'));
    undef $db;
    return $header->{SORT};
}

sub rebuild_msgs_cache {
    my $dir = _name2mdir($_[0]);
    $SORTORDER = $_[1] || 'Dt'; # default to Dt
    my $cache = "$dir/extmail-curcache.db";

    if(!-e $cache) {
        _set_msgs_cache($dir, 1); # full build it here
    }else {
        if(-r $cache) {
            my $mtime = (stat $cache)[9];
            if(time - $mtime > CACHE_CUR_LIFE or
                (stat "$dir/extmail-curcnt")[9] - $mtime >0) {
                _set_msgs_cache($dir, 0);
            }else {
                _rebuild_msgs_cache($dir);
            }
        }else {
            die "Can't read $cache, $!\n";
        }
    }
    1;
}

sub set_msgs_cache {
    my $dir = _name2mdir($_[0]);
    $SORTORDER = $_[1] || 'Dt'; # XXX see SORTORDER defination
    my $cache = "$dir/extmail-curcache.db"; # relative path?

    if(!-e $cache) {
        _set_msgs_cache($dir, 1); # full build cache
    }else {
        if(-r $cache) {
            my $mtime = (stat $cache)[9];

            if(time - $mtime > CACHE_CUR_LIFE or
                (stat "$dir/extmail-curcnt")[9] - $mtime >=1 or
                (stat "$dir/cur")[9] - $mtime >=1 or # XXX FIXME if >=0 will
                                                    # cause del/mv msgs rebuild
                                                    # cache duplicated:(
                (stat "$dir/new")[9] - $mtime >=0) {
                # mtime of curcnt > cache db, or mtime of cur/new
                # maildir > cache db indicate that may be new mail
                # or pop3 server delete some messages, bug! but
                # this design will cause cache.db update too offen,
                # waiting for fix, damn it!
                #
                # add check_new() here, because if new/ change, means
                # that some new mails arrive, we must move them to cur
                # then if check_new return 0, means there is no new
                # mail, but we need to update curcnt to sync mail info
                if(check_new($dir) == 0) {
                    _check_cache_curcnt($dir);
                }
                _set_msgs_cache($dir, 0);
            }
        }else {
            die "Can't read $cache, $!\n";
        }
    }
    1;
}

sub _rebuild_msgs_cache {
    my $fd = $_[0];
    my $cache_file = _name2mdir($fd)."/extmail-curcache.db";
    my $i = 0;

    use Ext::DB;
    my @cache; # ARRAY
    my $db = Ext::DB->new(file => "Btree:$cache_file");

    my $info = parse_cache($db->lookup('HEADER'));
    my $tmp_cache_file = $cache_file.".tmp"; # XXX

    for($i=0;$i<$info->{COUNT}+$info->{NEWCOUNT};$i++) {
        # bug fix, newly design cache struct should convert
        # to a HASH ref instead of raw data
        $cache[$i] = parse_cache($db->lookup("REC$i"));
    }
    undef $db; # destory Ext::DB object

    $db = Ext::DB->new(
        file => "Btree:$tmp_cache_file",
        flags => 'write'
    );

    my $header = sprintf "SAVETIME=%s\nCOUNT=%s\nNEWCOUNT=%s\nSORT=%s\n",
        time, $info->{COUNT}, $info->{NEWCOUNT}, $SORTORDER||'Dt';
    $db->insert('HEADER', $header);
    $i = 0;
    my $method = cvt2method($SORTORDER);
    foreach(($method? sort $method @cache : @cache)) {
        $db->insert("REC$i", sprintf("FILENAME=%s\nFROM=%s\n".
                "SUBJECT=%s\nSIZES=%s\nDATE=%s\nDATETIME=%s\nSIZEN=%s\n".
                "TIME=%s\nINODE=%s\n",
                $_->{FILENAME},
                $_->{FROM},
                $_->{SUBJECT},
                $_->{SIZES},
                $_->{DATE},
                $_->{DATETIME}, # XXX str2time() ed
                $_->{SIZEN},
                $_->{TIME},
                $_->{INODE})
        );
        $i++;
    }
    undef @cache;
    undef $db;
    rename(untaint($tmp_cache_file), untaint($cache_file));
}

sub _set_msgs_cache {
    my $fd = _name2mdir(shift);

    my $list = [];
    my @cache; # XXX ARRAY
    my $prefix = $CFG{path}."/$fd/cur";
    my ($pos,$seen,$new)=(0,0,0);

    my $full_build = shift; # 1 -> full, 0 -> increase

    if ($full_build) {
        $list = get_msgs_list($fd);
    } else {
        # do incremental build
        use Ext::DB;
        my $cache = "$fd/extmail-curcache.db";
        my $db = Ext::DB->new(
            file => "Btree:$cache",
            flags => "write"
        );

        my $info = parse_cache($db->lookup('HEADER'));
        my $nums = $info->{NEWCOUNT}+$info->{COUNT};
        # map file list(array) to hash, make it easy to compare :)
        my %files = map { $_ => 1 } @{get_msgs_list($fd)};

        foreach (0...$nums-1) {
            my $record=$db->lookup("REC$_");
            next unless($record); # ignore null or corupted record

            my $lv = parse_cache($record);

            # if record and file both exist, and file not modified
            # we can keep the cache :-)
            if ($lv->{FILENAME} && $files{$lv->{FILENAME}} &&
                ((stat "$prefix/$lv->{FILENAME}")[9] == $lv->{TIME})) {
                delete $files{$lv->{FILENAME}};
                $cache[$pos] = {
                    FILENAME => $lv->{FILENAME},
                    FROM => $lv->{FROM},
                    SUBJECT =>$lv->{SUBJECT},
                    SIZES =>$lv->{SIZES},
                    DATE => $lv->{DATE},
                    DATETIME => $lv->{DATETIME},
                    SIZEN => $lv->{SIZEN},
                    TIME =>$lv->{TIME},
                    INODE =>$lv->{INODE},
                };
                $pos++;
            } else {
                $db->delete("REC$_"); #file not exist,just del it
                if (is_new($lv->{FILENAME})) {
                    $info->{NEWCOUNT}--;
                } else{
                    $info->{COUNT}--;
                }
            }
        }
        @$list = keys %files;
        $seen = $info->{COUNT};
        $new = $info->{NEWCOUNT};
    }

    foreach(@$list) {
        my ($path, $file) = ("$prefix/$_", $_);
        my ($size_n, $time, $inode) = (stat "$prefix/$file")[7,9,1];
        my $size_s = human_size($size_n); # a convertion :-)
        my ($from, $subject, $date);

        # a faster method to get header than get_msg_info or
        # get_msg_header, but still need to optimize :)
        my $hdrs = get_msg_hdr_fast($path, $fd =~ /^\.(Drafts|Sent)$/ ? 1 : 0);

        if(is_new($file)) { $new++; }
        else { $seen++; }

        # The following code eat a lot of CPU when building
        # cache for a large Maildir, need to rewrite to reduce
        # too much loop / find.. :(
        #
        # Here i remove decode_words call to reduce overhead, but
        # should i ? wait for fix XXX, but in benchmark, 55k emails
        # under PIII 1G *2 1G RAM, use about 52s (or 76s without FS
        # cache the first time runs) time, is better than using
        # decode_words call which used about 57s-58s
        ($from, $subject, $date) = (
            $hdrs->{From},
            $hdrs->{Subject},
            $hdrs->{Date}
        );

        $from = (defined $from ? $from : "");
        $subject = (defined $subject ? $subject : "");
        $date = (defined $date ? $date : $time); # fallback

        $cache[$pos] = {
            FILENAME => $file,
            FROM => $from,
            SUBJECT => $subject,
            SIZES => $size_s,
            DATE => $date,
            DATETIME => str2time($date) || datefield2dateserial($date), # XXX
            SIZEN => $size_n,
            TIME => $time,
            INODE => $inode,
        };

        $pos++;
    }

    $cache[$pos] = {
        SAVETIME => time,
        COUNT => $seen,
        NEWCOUNT => $new,
        SORT => $SORTORDER || 'Dt',
    };

    _set_msgs_cache_do($CFG{path}."/$fd", \@cache);
}

# XXX XXX XXX
# SORTORDER routine

# Dt => date Date: header, slow
# Ts => file timestamp, the most fast
# Sz => file size, normal speed
# Fr => From header, slow
# Sj => Subject header, slow
# Fs => File status, seen or not
#
# if prepend 'r' to SORTORDER means reverse, eg:
# rDt => reverse Date
# rTs => reverse Timestamp

# XXX by_date* func has different mechanism, in general words:
# latest messages should be place at first, but in code level
# it's contrary

sub by_date {
    #str2time($b->{DATE}) <=> str2time($a->{DATE});
    $b->{DATETIME} <=> $a->{DATETIME};
}

sub by_date_rev {
    #str2time($a->{DATE}) <=> str2time($b->{DATE});
    $a->{DATETIME} <=> $b->{DATETIME};
}

sub by_size {
    $a->{SIZEN} <=> $b->{SIZEN};
}

sub by_size_rev {
    $b->{SIZEN} <=> $a->{SIZEN};
}

sub by_from {
    lc ($a->{FROM}) cmp lc ($b->{FROM});
}

sub by_from_rev {
    lc ($b->{FROM}) cmp lc ($a->{FROM});
}

sub by_subject {
    lc ($a->{SUBJECT}) cmp lc ($b->{SUBJECT});
}

sub by_subject_rev {
    lc ($b->{SUBJECT}) cmp lc ($a->{SUBJECT});
}

sub by_status {
    my $vara = $a->{FILENAME};
    my $varb = $b->{FILENAME};

    ($vara) = ($vara=~/:2,.*S.*/ ? 1:0);
    ($varb) = ($varb=~/:2,.*S.*/ ? 1:0);
    $vara <=> $varb;
}

sub by_status_rev {
    my $vara = $a->{FILENAME};
    my $varb = $b->{FILENAME};

    ($vara) = ($vara=~/:2,.*S.*/ ? 1:0);
    ($varb) = ($varb=~/:2,.*S.*/ ? 1:0);
    $varb <=> $vara;
}

sub by_time {
    $b->{TIME} <=> $a->{TIME};
}

sub cvt2method {
    my ($type) = shift;
    if($type =~/(r*)Dt/) {
        return ($1 ? 'by_date_rev':'by_date');
    }elsif ($type=~/(r*)Sz/) {
        return ($1 ? 'by_size_rev':'by_size');
    }elsif ($type=~/(r*)Fr/) {
        return ($1 ? 'by_from_rev':'by_from');
    }elsif ($type=~/(r*)Sj/) {
        return ($1 ? 'by_subject_rev':'by_subject');
    }elsif ($type=~/(r*)Fs/) {
        return ($1 ? 'by_status_rev':'by_status');
    }else {
        # default to 'Ts'
        return 'by_time'; # by_time => Time stamp
    }
}

# END of SORTORDER sub routine
sub _set_msgs_cache_do {
    my ($fd, $cache) = @_;
    my $cache_file = "$fd/extmail-curcache.db";

    if(-w $fd) {
        use Ext::DB;
        my $db = Ext::DB->new(
            file => "Btree:$cache_file",
            flags => "write"
        );

        # XXX XXX XXX do an experimental sorting.. SORT
        my $buf = pop @$cache;
        $db->insert('HEADER', sprintf("SAVETIME=%s\nCOUNT=%s\n".
                "NEWCOUNT=%s\nSORT=%s\n",
            $buf->{SAVETIME},
            $buf->{COUNT},
            $buf->{NEWCOUNT},
            $buf->{SORT})
        );

        my $i = 0;
        my $method = cvt2method($SORTORDER); # get sort method
        foreach($method ? sort $method @$cache : @$cache) {
            $db->insert("REC$i", sprintf("FILENAME=%s\nFROM=%s\n".
                    "SUBJECT=%s\nSIZES=%s\nDATE=%s\nDATETIME=%s\nSIZEN=%s\n".
                    "TIME=%s\nINODE=%s\n",
                    $_->{FILENAME},
                    $_->{FROM},
                    $_->{SUBJECT},
                    $_->{SIZES},
                    $_->{DATE},
                    $_->{DATETIME}, # XXX
                    $_->{SIZEN},
                    $_->{TIME},
                    $_->{INODE})
            );
            $i++;
        }
        undef @$cache; # cleanup, maybe useful in persistent env
        #foreach(keys %$cache) {
        #    db->insert($_, $cache->{$_});
        #}
        #$db->sync; # sync to disk?
        #$db->close;
    }else {
        die "Can't write curcache to $fd, $!\n";
    }

    1;
}

# get_dir_cnt - public func of _get_dir_cnt()
sub get_dir_cnt {
    my $dir = _name2mdir($_[0]);
    return _get_dir_cnt($dir);
}

# _get_dir_cnt - get a specify dir's new / seen counts
sub _get_dir_cnt {
    my $fd_dir = $_[0]; # XXX should be relative path?!

    # XXX FIXME old design: call _check_cache_curcnt(), new design
    # will only return the cached data instead of update it. the
    # update task will leave to check_new() or other func
    my ($tsize, $seen, $new) = parse_curcnt($fd_dir);

    return {
        new => $new,
        seen => $seen,
        size => $tsize
    };
}

sub _get_dir_cnt_do {
    my $cur_dir = $CFG{path}."/$_[0]/cur";
    my ($tsize, $seen, $new) = (0,0,0);

    # XXX not need check_new($_[0]); old XXX
    opendir DIR, $cur_dir || die "Can't opendir $cur_dir, $!\n";
    my @f = sort {$a cmp $b} grep { !/^\.$/ && !/^\..$/ } readdir DIR;
    close DIR;

    foreach (@f) {
        if(is_new($_)) { $new++ }
        else { $seen++ }

        if(/S=(\d+)/) {
            $tsize = $tsize + $1;
        }else {
            $tsize = $tsize + (stat "$cur_dir/$_")[7];
        }
    }

    return($tsize, $seen, $new);
}

# API change since 0.24-RC2, only accept folder name,
sub parse_curcnt {
    my $folder = shift;
    my $cache = untaint($CFG{path}.'/'._name2mdir($folder).'/extmail-curcnt');
    if (!-e $cache) {
        my ($tsize, $seen, $new) = _get_dir_cnt_do($folder);
        open(my $FD, "> $cache") or
        die "Can't write to $cache $!\n";
        print $FD "$tsize $seen $new\n";
        close $FD;
    }
    _parse_curcnt(untaint($cache));
}

sub _parse_curcnt {
    my $file = $_[0];
    open(my $FD, "< $file") or die "Can't open $file, $!\n";
    local $/="\n";
    my $str = <$FD>;
    close $FD;
    chomp $str;
    $str =~ m/^(\d+) (\d+) (\d+)/;
    return($1, $2, $3);
}

# public function name for _check_cache_curcnt()
sub check_curcnt {
    my $fd_dir = shift;
    my ($tsize, $seen, $new) = _check_cache_curcnt($fd_dir);

    return {
        new => $new,
        seen => $seen,
        size => $tsize
    };
}

sub _check_cache_curcnt {
    my ($fd_dir) = _name2mdir($_[0]);
    my ($write, $cache) = (0, "$fd_dir/extmail-curcnt");
    my ($tsize, $seen, $new) = (0,0,0);

    # Setuid programe untaint checks
    $cache = untaint($cache);
    if(-e $cache) {
        # update cache
        my $mtime = (stat $cache)[9];
        if( time - $mtime > CACHE_CNT_LIFE or
            (stat "$fd_dir/cur")[9] - $mtime >=0 or
            (stat "$fd_dir/new")[9] - $mtime >=0) {
            $write = 1;
        }
    }else { $write = 1; }

    if($write) {
        ($tsize, $seen, $new) = _get_dir_cnt_do($fd_dir);
        open(my $FD, "> $cache") or
            die "Can't write to $cache $!\n";
        print $FD "$tsize $seen $new\n";
        close $FD;
    }else {
        ($tsize, $seen, $new) = parse_curcnt($fd_dir);
    }

    return($tsize, $seen, $new);
}

sub _set_cache_curcnt {
    my ($fd_dir, @info) = @_;
    my $cache = _name2mdir($fd_dir).'/extmail-curcnt';

    $cache = untaint($cache);
    open(my $FD, "> $cache") or die "Can't open $cache, $!\n";
    flock($FD, LOCK_EX);
    # size seen new newline
    print $FD "$info[0] $info[1] $info[2]\n";
    flock($FD, LOCK_UN);
    close $FD;

    1;
}

# check_new - to check new messages in a specify folder
sub check_new {
    my $dir = _name2mdir($_[0]);
    if(_check_new($dir)) {
        my $cache = untaint("$CFG{path}/$dir/extmail-curcnt");
        my ($tsize, $seen, $new) = _get_dir_cnt_do($dir);
        open(my $FD, "> $cache") or
        die "Can't write to $cache $!\n";
        print $FD "$tsize $seen $new\n";
        close $FD;
        return 1;
    }
    return 0;
}

sub _check_new {
    my $dir = $CFG{path}."/$_[0]";

    opendir DIR, $dir."/new" || die "Can't opendir $dir/new, $!\n";
    my @f = grep {!/^\./} readdir DIR;
    close DIR;
    return 0 unless(scalar @f>0);

    foreach(@f) {
        my $has_mime = has_attach("$dir/new/$_");
        my $tf = $_.":2," . ($has_mime?'A':""); # flag to a file in cur
        rename(untaint("$dir/new/$_"), untaint("$dir/cur/$tf")) or
            warn "Can't rename $_\n" if (!-e "$dir/cur/$tf");
    }
    1;
}

sub has_attach {
    my $file = untaint ($_[0]);
    open(my $fh, "< $file") || die "Can't open $file, $!\n";
    my $hlen = _index($fh, "\n\n", 0)+2; # include the 2 newline
    my $header = _substr($fh, 0, $hlen);

    my $boundary;
    if($header=~/boundary="*([^"\r\n]+)"*/i) {
        $boundary = $1;
        return 0 unless ($boundary);
    } else {
        return 0;
    }

    my $start = $hlen;
    my $nstart; # nstart - next start pos
    while (($nstart= _index($fh, "--$boundary\n", $start))!=-1) {
        my $end = _index($fh, "\n\n", $nstart);
        my $head = _substr($fh, $nstart, $end - $nstart);
        $start = $end;
        if ($head =~ m!(filename|name)=!i) {
            return 1;
        }
        if ($head =~ m!message/rfc822!i) {
            return 1;
        }
    }
    0;
}

sub is_new {
    my $file = $_[0];

    # see maildir info section on http://cr.yp.to/proto/maildir.html
    # bug fix here, old code: /2,.*S.*$/, it will fail to match
    # must have the : character
    if($file=~/:2,.*S.*$/) { # original PRSTDF, we only check S(seen) flag
        return 0;
    }
    return 1;
}

sub is_sys_maildir {
    my $dir = $_[0];
    my @sysdir = ("Inbox", "Sent", "Drafts", "Trash", "Junk");
    for(@sysdir) {
        return 1 if($_ eq $dir);
    }
    0;
}

# set bunch of msgs to delete
sub set_bmsgs_delete {
    _set_bmsgs_delete(shift,1,@_);
}

sub _set_bmsgs_delete {
    my ($dir, $unlink, %pos) = @_;
    my $info = get_bmsgs_cache($dir, keys %pos);
    my ($nsizes, $nseen, $nnew) = (0,0,0);
    my %quota = ();
    my $recheck = 1;

    for (keys %$info) {
        my $file = _name2mdir($dir).'/cur/'.$info->{$_}->{FILENAME};
        my $tsz = 0;
        my $pfile = _name2mdir($dir).'/cur/'.$pos{$_};

        if ($pfile ne $file) {
            $file = maildir_find($dir, $pos{$_});
            next unless $file;

            $file = _name2mdir($dir).'/cur/'.$file;
            $recheck = 1;
            $tsz = (stat $file)[7];
            $nsizes += $tsz;
        } else {
            $tsz = $info->{$_}->{SIZEN};
            $nsizes += $tsz;
        }
        if($unlink) { # a flag to unlink
            unlink(untaint($file));
            $quota{$_} = '-'.$tsz.' -1';
        }
        if(is_new($file)) {
            $nnew++;
        }else {
            $nseen++;
        }
    }

    # after delete, recalculate curcnt and store
    # format: size seen new
    my @curcnt = parse_curcnt($dir);
    $curcnt[0] -= $nsizes;
    $curcnt[1] -= $nseen;
    $curcnt[2] -= $nnew;
    _set_cache_curcnt($dir, @curcnt);
    if ($recheck) {
        _set_msgs_cache($dir, 0);
    } else {
        _delete_bmsgs_cache($dir, keys %pos);
    }

    if($unlink) {
        # update maildirsize if we truelly unlink
        # update_quota("-$nsizes", '-'.$nseen+$nnew);
        update_quota_s(\%quota);
    }
}

# set bunch of msgs to move
sub set_bmsgs_move {
    my ($srcdir, $distdir, %pos) = @_;

    my $mvinfo = get_bmsgs_cache(_name2mdir($srcdir), keys %pos);
    my ($nsizes, $nseen, $nnew) = (0,0,0);
    my $recheck = 0;

    foreach my $c (keys %$mvinfo) {
        my $file = $mvinfo->{$c}->{'FILENAME'};
        my $src = _name2mdir($srcdir).'/cur/'.$file;
        my $dst = _name2mdir($distdir).'/cur/'.$file;

        $c =~ s/REC//; # only left the pos number
        my $psrc = _name2mdir($srcdir).'/cur/'.$pos{$c};
        if ($psrc ne $src) {
            # cache info may changed
            $file = maildir_find($srcdir, $pos{$c});
            $src = _name2mdir($srcdir).'/cur/'.$file;
            $dst = _name2mdir($distdir).'/cur/'.$file;
            $nsizes += (stat $src)[7];
            $recheck = 1;
        } else {
            $nsizes += $mvinfo->{$c}->{SIZEN};
        }
        rename (untaint($src), untaint($dst)); # omit error

        if(is_new($file)) {
            $nnew++;
        }else {
            $nseen++;
        }
    }
    _set_bmsgs_delete($srcdir,0,keys %pos); # set src dir

    # dist directory curcnt cache file
    my @curcnt = parse_curcnt($distdir);
    $curcnt[0] += $nsizes;
    $curcnt[1] += $nseen;
    $curcnt[2] += $nnew;
    _set_cache_curcnt($distdir, @curcnt);
    # force srcdir to do incremental check :( maybe slow
    _set_msgs_cache($srcdir, 0) if $recheck;
}

# file flag handler func*
sub set_msg_status {
    my ($dir, $pos, $flag) = @_;
    my $c = get_bmsgs_cache($dir, $pos); # already parsed
    $c = $c->{$pos}; # now the real ref

    $flag ||= 'Seen';

    # _check_cache_curcnt first, then set_status, see below explnation
    my ($tsize, $seen, $new) = _check_cache_curcnt($dir);

    my $nname = '';
    if ($flag eq 'Seen') {
        $nname = set_status($dir, $c->{FILENAME}, '+S'); # XXX ?
    } elsif ($flag eq 'Unseen') {
        $nname = set_status($dir, $c->{FILENAME}, '-S');
    } elsif ($flag eq 'Replied') {
        $nname = set_status($dir, $c->{FILENAME}, '+S');
        $nname = set_status($dir, $nname, '+R');
    } else {
        die "Unsupport flag: $flag\n";
    }

    return if($c->{FILENAME} eq $nname); # XXX if the same
    $c->{FILENAME}=$nname; # update to new name
    my $cc = sprintf "FILENAME=%s\nFROM=%s\n".
                    "SUBJECT=%s\nSIZES=%s\nDATE=%s\nDATETIME=%s\nSIZEN=%s\n".
                    "TIME=%s\nINODE=%s\n",
                    $c->{FILENAME},$c->{FROM},$c->{SUBJECT},$c->{SIZES},
                    $c->{DATE},$c->{DATETIME},$c->{SIZEN},$c->{TIME},$c->{INODE};

    undef $c; $c->{$pos} = $cc;
    update_bmsgs_cache($dir, %$c);

    # race condition: after set_status, if check_cache_curcnt ocationally
    # recheck the curcnt and couting new/seen files, say if original it's
    # '1840 2 1', then it turn to be '1840 3 0', if we increase seen then
    # the finally result is '1840 4 0', ouch :-( Try to advoid, solution:
    #
    # move _check_cache_curcnt ahead of set_status!
    # my ($tsize, $seen, $new) = _check_cache_curcnt($dir);
    if($new>0) {
        if ($flag eq 'Seen' || $flag eq 'Replied') {
            $new--;
            $seen++;
        } elsif ($flag eq 'Unseen') {
            $new++;
            $seen-- if $seen>0;
        }
    }
    my @curcnt=($tsize, $seen, $new);
    _set_cache_curcnt($dir, @curcnt);

    use Ext::DB;
    my $cache_file = $CFG{path}.'/'._name2mdir($dir).'/extmail-curcache.db';
    my $db = Ext::DB->new(
        file => "Btree:$cache_file",
        flags => 'write');
    my $info = parse_cache($db->lookup('HEADER'));
    my $nheader = sprintf "SAVETIME=%s\nCOUNT=%s\nNEWCOUNT=%s\n".
            "SORT=%s\n",time,$seen,$new,$info->{SORT};
    $db->update('HEADER', $nheader);
    undef $db;

    return 1;
}

sub get_status {
    my $file = $_[0];

    $file =~ m/2,([A-Z]+)/;
    $1;
}

sub set_status {
    my ($dir, $srcfile, $flag) = @_;
    my $distfile = $srcfile;

    $dir = $CFG{path}.'/'._name2mdir($dir).'/cur';
    my($op, $F) = ($flag=~/([-+])(.*)/);

    # XXX FIXME
    if ($distfile !~ /:2,/) {
        $distfile .= ':2,';
    }
    if($op eq '-') {
        $distfile=~s/:2,(.*)$F(.*)$/:2,$1$2/g;
    }
    if($op eq '+') {
        if($distfile=~/:2,.*$F.*$/) {
            return $srcfile; # skip if flag exist
        }
        $distfile=$distfile.$F;
    }
    rename(untaint("$dir/$srcfile"), untaint("$dir/$distfile"))
        or die "set_status() fail, $!\n";
    $distfile; # return the new file name
}

sub is_subdir {
    my $dir = _name2mdir($_[0]);

    if(-r "$dir/maildirfolder") {
        return 1;
    }
    0;
}

# validate the given maildir name is secure and valid
sub valid_maildir {
    my $dir = shift;

    if ($dir =~ m!(\.\./|/\.\.|/|^\.+$)!) {
        return 0;
    }

    $dir = _name2mdir($dir);
    $dir = $ENV{MAILDIR}.'/'.$dir if $dir !~ m!^/!;

    if(-d $dir) {
        return 1;
    }
    0;
}

# Utils funct*
#
# name2mdir - convert a given folder name, aka 'Inbox' or 'Trash' etc,
# to a dir, which makes sense to low level operation.
sub _name2mdir {
    my $name = $_[0];
    if(!defined $name or $name eq ""
       or $name eq 'Inbox') {
        ".";
    }else {
        # bug fix, check name first if it has been name2mdir :)
        if($name=~m#(^\.|^/)#) {
            $name;
        }else {
            ".$name";
        }
    }
}

# function to check whether a given dir is valid or not
sub valid_dirname {
    my $dir = $_[0];
    $dir =~ s/\s+//g; # remove all space

    # ouch, we found invalid directory name,
    # contains / or .. as prefix
    if ($dir =~ m!(/|^\.{2,})!) {
        return 0;
    } else {
        return 1;
    }
}

sub _touch {
    my $file = untaint ($CFG{path}."/$_[0]");

    return 1 if(-e $file);
    open(my $FD, "> $file") or die "Can't touch $file, $!\n";
    close $FD;
    1;
}

# fixpath - an important function to remove dangerous
sub fixpath {
    my $path = shift;
    $path =~ s#/\.+##g; # strip /.. or /... etc
    $path =~ s#\.+/##g; # strip ../ or .../ etc
    $path =~ s#\\\.+##g; # strip \. or \... etc
    $path =~ s#\\+##g;   # strip \\ or \\\ etc
    $path;
}

1;
