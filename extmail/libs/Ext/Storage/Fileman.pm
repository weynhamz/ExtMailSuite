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
package Ext::Storage::Fileman;
use strict;

# fileman specification
#
# XXX - fileman derive the Maildir++ protocol
#
# Contents of filesize
# filesize contains two or more lines terminated by newline characters.
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
# interpreted as a file count. A fileman writer can add up all byte
# counts and file counts from maildirsize and enforce a quota based either
# on number of messages or the total size of all the messages.
#

# Update 2005-07-28, experimantal OO design, now use global varibles to
# store configuration and some information instead of using object, for
# performance reason. OO object new/del a hundred thousand times will
# be much slower than direct reference :-(

use Fcntl qw(:flock SEEK_SET SEEK_END);
use Exporter;
use vars qw(@ISA @EXPORT %CFG $SORTORDER);
@ISA = qw(Exporter);
@EXPORT = qw(
    fget_dirlist op_rename fixslash
    op_addfile op_getfile op_mkdir op_rmdir op_move
    op_rmfile fget_quota fget_curquota freset_quota
    fre_calculate fupdate_quota fis_overquota fscan_dir
    get_files_list ext2mime fixpath fupdate_quota_s);

%CFG=();
use Ext::Utils qw(untaint); # import the untaint func
use Ext::RFC822 qw(str2time); # import str2time
use Ext::Storage::Maildir qw(valid_dirname); # import valid_dirname

# init - init a fileman, for read/write and quota maintains
#
# XXX $path is the base path, every I/O can't over collapse this
# limitaion, or it will become a big security hole.
sub init {
    my ($path, $mode, $warnlv) = @_;

    # XXX the magic to set default permission
    umask(0077);

    $CFG{path} = untaint ($path ? $path : "./fileman/"); # relative path
    $CFG{mode} = $mode ? $mode : "O_RW";
    $CFG{warnlv} = $warnlv ? $warnlv : "0.9"; # 90% default
    $CFG{ctrlfile} = fixslash("$CFG{path}/filesize");

    my $file = $CFG{path}.'/filesize';

    if (! -d $CFG{path}) {
        mkdir untaint ($CFG{path}), 0700; # raw mkdir call, so $CFG{path} must
                                          # be a security path
    }

    chdir($CFG{path}) or die "Can't chdir to $CFG{path}, $!\n";

    # re-calculate if not exist or bigger than 5120 bytes
    if(! -e $file ||  (stat $file)[7] >= 5120) {
        fre_calculate();
    }

    1;
}

# op_mkdir - create a directory
sub op_mkdir {
    my $folder = fixslash(fixpath($_[0]));

    return "$folder exists" if(-d "$CFG{path}/$folder");

    mkdir untaint("./$folder"), 0700;
    0;
}

# op_rmdir - delete a directory
sub op_rmdir {
    my $folder = untaint(fixpath($_[0]));
    my $flag = $_[1];

    if($folder =~/^(filesize|\.\.)$/) {
        # Ignore default folder
        return 'Can\'t remove system file';
    }

    # realdir => the real full path directory name
    # folder => the relative path name
    my $realdir = fixslash("$CFG{path}/$folder");

    if(-d $realdir) {
        my @entries = ();
        opendir DIR, $realdir or die "Can't opendir, $!\n";
        @entries = grep { !/^\.$/ && !/^\..$/ } readdir(DIR);
        closedir DIR;

        for my $f (@entries) {
            if(-d "$realdir/$f") {
                # the $flag is to indicate that whether we
                # are in recursive mode, if yes ignore all checks
                op_rmdir("$folder/$f", 1);
                next;
            }
            unlink untaint("$realdir/$f") or print "error: $!\n";
        }
        rmdir "$realdir" || return "op_rmdir() $folder: $!\n"; # this remove dir left
        return 0;
    }
    0;
}

# op_move - move a file or directory to another directory
#
# from => file or directory
# to => destination directory
sub op_move {
    my ($from, $to) = @_;
    $from = fixpath($from);
    $to = fixpath($to);

    my $rfrom = fixslash("$CFG{path}/$from");
    my $rto = fixslash("$CFG{path}/$to");
    my $fromname;

    if ($rfrom eq $CFG{ctrlfile} || $rto eq $CFG{ctrlfile}) {
        return 'Can\'t move system control file';
    }

    # whether it's directory or file, get the basename
    if (-r $rfrom) {
        $from =~ s#/+$##;
        $rto =~ s#/+$##;   # XXX fix fromname and rto
        $from =~ m#([^\/]+)$#;
        $fromname = $1 || $from;
    } else {
        return "$from not exists";
    }

    return "$to or $from invalid" if ($to =~ m#^\.$# or $from =~ m#^\.\.$#);
    return "Directory $to not exists" unless (-d $rto);
    return 'Source equal Destination, Abort!' unless ($rfrom ne $rto);

    if ($from =~ m#^/filesize$#) {
        return 'Source or Destination name invalid';
    }

    rename(untaint($rfrom), untaint("$rto/$fromname")) ||
        return "rename $from to $to error, $!";
    return 0;
}

sub op_rename {
    my ($from, $to) = @_;

    $from = untaint($from);
    $to = untaint($to);

    my $rfrom = fixslash(fixpath("$CFG{path}/$from"));
    my $rto = fixslash(fixpath("$CFG{path}/$to"));

    $from = fixslash(fixpath($from));
    $to = fixslash(fixpath($from));

    if ($rfrom eq $CFG{ctrlfile} || $rto eq $CFG{ctrlfile}) {
        return "Can't rename system control file";
    }

    if (!-r $rfrom) {
        return "$from not exists";
    } elsif (-r $rto) {
        return "$to already exists";
    }

    rename($rfrom, $rto) || return "rename fail, $!\n";
    return 0;
}

sub op_addfile {
    my ($from, $dist, $op) = @_;

    $dist = untaint (fixslash("$CFG{path}/".fixpath($dist)));

    my $size = 0;
    if (ref $from) {
        # it's file handler

        seek($from, 0, SEEK_SET);
        seek($from, 0, SEEK_END);
        $size = tell $from;
        seek($from, 0, SEEK_SET);
    } else {
        $from = untaint (fixpath($from));
        $size = (stat $from)[7]; # size contain CGI header ?
    }

    my $rv = fis_overquota($size, '1');
    my $dist_size;

    if ($rv eq 2) {
        return "Storage over quota, abort!";
    }

    # ignore the filesize at the topdir, override it
    # is forbidden and dangous! XXX FIXME
    if ($dist eq $CFG{ctrlfile}) {
        return "Can't override filesize, abort!";
    }

    if (-r $dist) {
        # dist file exists, override!!
        $dist_size = (stat $dist)[7];
    }

    if (ref $from) {
        *IN = $from;
    } else {
        open (IN, "< $from") or return "$from open fail, $!\n";
    }

    open (OUT, "> $dist") or return "$dist write fail, $!\n";
    while (<IN>) {
        print OUT $_;
    }
    close IN;
    close OUT;

    if (defined $dist_size && $dist_size>=0) {
        fupdate_quota($dist_size, -1);
    }
    fupdate_quota($size >0 ? $size : 0 , 1);

    0;
}

sub op_getfile {
    my $file = shift;

    $file = "$CFG{path}/$file";
    $file = fixpath(fixslash($file));

    open (my $stream , " < $file") or die "$file open fail, $!\n";
    return $stream;
}

sub op_rmfile {
    my $file = untaint (fixpath($_[0])); # remove dangerous characters
    $file = "$CFG{path}/$file";
    $file = fixslash($file);
    return "Can't remove $file" if ($file eq $CFG{ctrlfile});

    my $size = (stat $file)[7];

    unlink $file or return "$file remove fail, $!";
    fupdate_quota("-$size", '-1');
    0; # success
}

sub fget_dirlist {
    my $dir = fixpath($_[0] || '/');
    my $rv = ['/'];
    push @$rv, @{_dirlist($dir)};
    $rv;
}

# private function
sub _dirlist {
    my $dir = fixpath($_[0]);
    my @entries;
    my $realdir = fixslash("$CFG{path}/$dir");

    if (-d $realdir) {
        opendir DIR, $realdir or die "Can't opendir, $!\n";
        my @rv = sort grep { !/^\./ && -d "$realdir/$_" } readdir(DIR);
        closedir DIR;

        for my $d (@rv) {
            push @entries, fixslash("$dir/$d/");
            my $rv2 = _dirlist("$dir/$d/");
            push @entries, @$rv2;
        }
    }
    \@entries;
}

# fget_quota - to get a Maildir quota limitation info, return a HASH
sub fget_quota {
    my $path = $CFG{path};
    my ($smax, $cmax);

    $path = untaint($path);

    # Update 2005-07-26, check maildirsize first, fallback to
    # $ENV{DEFAULT_QUOTA} if not present.
    if(-e "$path/filesize") {
        open(my $FD, "< $path/filesize") or
            die "Can't open filesize, $!\n";
        $_=<$FD> || "";
        close FD;
    }elsif($ENV{FILEMAN_QUOTA}) {
        $_=$ENV{FILEMAN_QUOTA};
    }else {
        $_=$ENV{DEFAULT_QUOTA}; # default quota
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

# fget_curquota - to get current quota usage, return a ARRAY not HASH
sub fget_curquota {
    my $path = $CFG{path};
    my ($size, $cnt) = (0,0);

    $path = untaint($path);

    open(FD, "<$path/filesize") or
        die "Can't open maildirsize, $!\n";
    my $s = <FD>; # omit the first line;
    seek(FD,0,0) unless($s=~/S|C/); # unget if no quota limit
    while(<FD>) {
        chomp;
        /\s*([\-]*\d+)\s+([\-]*\d+)/;
        $cnt = $cnt+$2; # include -xxx, perl will automaticlly
                        # handle nagetive value :)
        if ($2 == -1) {
            $size = $size - $1;
        } else {
            $size = $size + $1;
        }
    }
    return {
        size => $size,
        count => $cnt
    }; # return a ref of HASH
}

# set_quota - reset quota to a new value, mostly used by ADMIN API
sub freset_quota {
    my ($q_size, $q_cnt) = @_;
    my $path = $CFG{path};

    $path = untaint($path);
    open(FD, "< $path/filesize") or
        die "Can't open filesize, $!\n";
    my $s = <FD>;# omit the first line
    seek(FD,0,0) unless($s=~/S|C/); # unget if no quota limit
    local $/= undef;
    $s = <FD>;
    close FD;

    open(FD, "> $path/filesize.tmp") or
        die "Can't open filesize.tmp for write, $!\n";
    print FD "$q_size"."S";
    if($q_cnt) {
        print FD ",$q_cnt"."C";
    }
    print FD "\n"; # newline
    print FD $s;
    close FD;

    unlink untaint($path."/filesize") || die "unlink fail: $!\n";
    rename untaint($path."/filesize.tmp"), untaint($path."/filesize") or
        die "Can't rename:$!\n";
    1;
}

sub fre_calculate {
    my $inf2 = fscan_dir();
    my $inf = fget_quota;

    open(FD, "> $CFG{ctrlfile}.tmp") or
        die "Can't open filesize.tmp: $!\n";
    flock (FD, LOCK_EX);
    if($inf->{size} and $inf->{count}) {
        print FD $inf->{size}."S,".$inf->{count}."C\n";
    }elsif($inf->{size}) {
        print FD $inf->{size}."S\n";
    }elsif($inf->{count}) {
        print FD $inf->{count}."C\n";
    }

    my $str = _fmt2mds($inf2->{sizes}, $inf2->{files});
    print FD $str;
    flock (FD, LOCK_UN);
    close FD;

    rename (untaint($CFG{path}."/filesize.tmp"),
            untaint($CFG{path}."/filesize"))
        or die "Can't rename filesize, $!\n";
}

# fupdate_quota - do an append action to filesize file.
sub fupdate_quota {
    my ($size, $count) = @_;
    my $file = defined $CFG{mdspath} ?
                   $CFG{mdspath}: $CFG{path}.'/filesize';

    $file = untaint($file);

    open(FD, ">> $file") or
        die "Can't open filesize, $!\n";
    flock(FD, LOCK_EX);
    my $str = _fmt2mds($size, $count);
    print FD $str;
    flock(FD, LOCK_UN);
    close FD;

    # after update, check filesize file size;
    if((stat $file)[7] >= 5120) {
        fre_calculate();
    }
}

# fupdate_quota_s - update bunch of quota records
sub fupdate_quota_s {
    my $ref = $_[0];
    my $file = defined $CFG{mdspath} ?
                  $CFG{mdspath}: $CFG{path}.'/filesize';

    $file = untaint($file);
    open(my $FD, ">> $file") or
        die "Can't open filesize, $!\n";
    flock($FD, LOCK_EX);
    foreach(keys %$ref) {
        my($s,$c) = split(/\s/, $ref->{$_});
        my $str = _fmt2mds($s,$c);
        print $FD $str;
    }
    flock($FD, LOCK_UN);
    close $FD;

    # after update, check filesize file size;
    if((stat $file)[7] >= 5120) {
        fre_calculate();
    }
}

# _fmt2mds format given params into filesize record
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

# fis_overquota - check whether a Maildir is over quota, need fget_quota
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
sub fis_overquota {
    my ($addsize, $addcnt) = @_;
    my $cur = fget_curquota();
    my ($q_size, $q_cnt);
    my $sig = 0; # XXX NOT_OVER

    my $inf = fget_quota();
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

    $sig;
}

sub fscan_dir {
    my $rv = get_dir_cnt(''); # the top path?
    return $rv;
}

# get_files_list - a public func to get a formated files list
sub get_files_list {
    my $dir = fixpath(shift);
    my $path = fixslash($CFG{path}."/$dir");

    opendir DIR, $path || die "Can't opendir $path, $!\n";
    my (@dir, @files);
    my $ignore = ($dir =~ m#^\s*/*\s*$# ? 1 : 0);

    for (readdir DIR) {
        next if (/^\.$/ || /^\.\.$/);
        if (-d "$path/$_") {
            push @dir, $_;
        } else {
            # means we are in topdir, ignore ctrlfile
            next if ($ignore && /^filesize$/);
            push @files, $_;
        }
    }
    closedir DIR;

    @dir = sort { $a cmp $b } @dir;
    @files = sort { $a cmp $b } @files;
    (@dir, @files);
}

my %ext_maps = (
    'gz'    => 'zip',
    'zip'   => 'zip',
    'rar'   => 'zip',
    'tar'   => 'zip',
    'tgz'   => 'zip',
    'bz2'   => 'zip',
    'jpg'   => 'pic',
    'jpeg'  => 'pic',
    'gif'   => 'pic',
    'exe'   => 'exe',
    'com'   => 'exe',
    'bin'   => 'exe',
    'pl'    => 'txt',
    'php'   => 'txt',
    'jsp'   => 'txt',
    'asp'   => 'txt',
    'py'    => 'txt',
    'h'     => 'txt',
    'cpp'   => 'txt',
    'c'     => 'txt',
    'in'    => 'txt',
    'ini'   => 'ini',
    'html'  => 'html',
    'css'   => 'css',
    'js'    => 'txt',
    'csv'   => 'xls',
    'xls'   => 'xls',
    'ppt'   => 'ppt',
    'doc'   => 'doc',
    'pdf'   => 'pdf',
    'chm'   => 'chm',
    'au'    => 'au',
    'mp3'   => 'mp3',
    'rm'    => 'rm',
    'wav'   => 'au',
    'wmv'   => 'stream',
);

sub ext2mime {
    my $file = $_[0];
    if ($file =~ m!/!) {
        $file =~ s#.*/([^\/]+)$#$1#;
    }

    $file =~ m#\.([^\.]+)$#;
    if (my $ext = lc $1) {
        return $ext_maps{$ext} if ($ext_maps{$ext});
    }

    'txt';
}

sub _length_fmt {
    my ($s, $len) = @_;
    my $delta  = 0;
    if(length($s)<$len) {
        $delta = $len - length($s);
    }
    return ('0' x $delta).$s;
}

sub _parse_cache {
    my $s = $_[0];
    my %info = ();
    my @a = split(/\n/, $s);
    foreach(@a) {
        /^([^=]+)=(.*)/;
        $info{$1}=$2;
    }
    \%info;
}

# get_dir_cnt - get a specific directory sizes and file count
sub get_dir_cnt {
    my $dir = fixpath($_[0]); # XXX should be relative path?!
    my $rdir = fixslash("$CFG{path}/$dir");
    my %stat = (dirs => 0, files => 0, sizes => 0);

    opendir DIR, $rdir or die "$rdir open fail, $!\n";
    my @lists = grep { !/^\.$/ && !/^\.\.$/ } readdir DIR;
    close DIR;

    if ($dir =~ m#^\s*/*\s*$#) {
        # means we are in topdir, ignore ctrlfile
        @lists = grep { !/^filesize$/ } @lists;
    }

    for (@lists) {
        if (-d "$rdir/$_") { # a directory
            $stat{dirs} ++;
            my $rv = get_dir_cnt("$dir/$_");
            if ($rv) {
                $stat{dirs} += $rv->{dirs};
                $stat{files} += $rv->{files};
                $stat{sizes} += $rv->{sizes};
            }
        }else {
            $stat{files}++;
            $stat{sizes} += (stat "$rdir/$_")[7];
        }
    }

    return {
        dirs => $stat{dirs},
        files => $stat{files},
        sizes => $stat{sizes},
    };
}

# Utils funct*
#
# name2mdir - convert a given folder name, aka 'Inbox' or 'Trash' etc,
# to a dir, which makes sense to low level operation.

sub fixslash {
    my $path = shift;
    $path =~ s#/{2,}#/#g;
    $path;
}

# fixpath - an important function to remove dangerous
sub fixpath {
    my $path = shift;
    # fix bug, old bug code: $path =~ s#\.{2,}/##g;
    $path =~ s#/\.+##g; # strip /.. or /... etc
    $path =~ s#\.+/##g; # strip ../ or .../ etc
    $path =~ s#\\\.+##g; # strip \. or \... etc
    $path =~ s#\\+##g;   # strip \\ or \\\ etc
    $path;
}

1;
