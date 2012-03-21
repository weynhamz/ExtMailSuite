# vim: set ci et ts=4 sw=4:
package Ext::Storage::Search;
use strict;

use Fcntl ':flock';
use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(
    mk_search_db rebuild_search_db get_search_msgs_db get_charset
    get_search_db_sort update_search_db_inmove update_search_db
    del_search_bmsgs_db get_search_db_hdr
);
use Ext::Storage::Maildir;
use Ext::Utils;

sub mk_search_db{
    my ($cache,$sort_order,$subject,$sender,$receiver,$cont)=@_;
    my $cache_file=$ENV{MAILDIR}.'/'.'search-cache.db';

    if(-w $ENV{MAILDIR}) {
        use Ext::DB;
        my $db = Ext::DB->new(
            file => "Btree:$cache_file",
            flags => "write"
        );

        $cont->{is_advance}=$cont->{is_advance}?$cont->{is_advance}:0;
        $cont->{sel_folder}=$cont->{sel_folder}?str2url($cont->{sel_folder}):'';
        $cont->{daterange}=$cont->{daterange}?$cont->{daterange}:"-1";

        #insert header first
        $db->insert('HEADER', sprintf("SAVETIME=%s\nTOTALCOUNT=%s\n".
             "SORT=%s\nSUBJECT=%s\nSENDER=%s\nRECEIVER=%s\nIS_ADVANCE=%s\n".
            "SER_FOLDER=%s\nDATERANGE=%s\n",
            time,
            scalar @$cache,
            $sort_order,
            $subject,
            $sender,
            $receiver,
            $cont->{is_advance},
            $cont->{sel_folder},
            $cont->{daterange}
            )
        );
        my $i = 0;
        my $method = cvt2method($sort_order); # get sort method
        foreach($method ? sort $method @$cache : @$cache) {
            $db->insert("REC$i",
                 sprintf("FILENAME=%s\nFROM=%s\n".
                    "SUBJECT=%s\nSIZES=%s\nDATE=%s\nDATETIME=%s\nSIZEN=%s\n".
                    "TIME=%s\nINODE=%s\nPRIORITY=%s\nFOLDER=%s\nFDPOS=%s\n",
                    $_->{FILENAME},
                    $_->{FROM},
                    $_->{SUBJECT},
                    $_->{SIZES},
                    $_->{DATE},
                    $_->{DATETIME}, # XXX
                    $_->{SIZEN},
                    $_->{TIME},
                    $_->{INODE},
                    $_->{PRIORITY}||'',
                    $_->{FOLDER},
                    $_->{FDPOS},
                 )
            );
            $i++;
        }
        undef @$cache; # cleanup, maybe useful in persistent env
    } else {
        die "Can't write curcache to $ENV{MAILDIR}, $!\n";
    }
    1;
}

sub rebuild_search_db {
    my $sort_order = shift || 'Dt';
    my $cache_file = $ENV{MAILDIR}."/search-cache.db";
    my $i = 0;

    use Ext::DB;
    my @cache; # ARRAY
    my $db = Ext::DB->new(file => "Btree:$cache_file");

    my $info = parse_cache($db->lookup('HEADER'));
    my $tmp_cache_file = $cache_file.".tmp"; # XXX

    for($i=0;$i<$info->{TOTALCOUNT};$i++) {
        # bug fix, newly design cache struct should convert
        # to a HASH ref instead of raw data
        $cache[$i] = parse_cache($db->lookup("REC$i"));
    }
    undef $db; # destory Ext::DB object

    $db = Ext::DB->new(
        file => "Btree:$tmp_cache_file",
        flags => 'write'
    );

    my $header = sprintf "SAVETIME=%s\nTOTALCOUNT=%s\n".
             "SORT=%s\nSUBJECT=%s\nSENDER=%s\nRECEIVER=%s\n",
            time,scalar @cache,$info->{SORT},$info->{SUBJECT},$info->{SENDER},$info->{RECEIVER};

    $db->insert('HEADER', $header);
    $i = 0;
    my $method = cvt2method($sort_order);
    foreach(($method? sort $method @cache : @cache)) {
        $db->insert("REC$i",
            sprintf("FILENAME=%s\nFROM=%s\n".
                "SUBJECT=%s\nSIZES=%s\nDATE=%s\nDATETIME=%s\nSIZEN=%s\n".
                "TIME=%s\nINODE=%s\nPRIORITY=%s\nFOLDER=%s\nFDPOS=%s\n",
                $_->{FILENAME},
                $_->{FROM},
                $_->{SUBJECT},
                $_->{SIZES},
                $_->{DATE},
                $_->{DATETIME}, # XXX
                $_->{SIZEN},
                $_->{TIME},
                $_->{INODE},
                $_->{PRIORITY}||'',
                $_->{FOLDER},
                $_->{FDPOS},
            )
        );
        $i++;
    }
    undef @cache;
    undef $db;
    rename(untaint($tmp_cache_file), untaint($cache_file));
}

sub get_charset{
    my $str = shift;
    if ($str =~ /=\?([^?]*)\?[QB]\?([^?]*)\?=/) {
        return $1;
    }
}

sub _exist_pos_id {
    my ($key, $ref) = @_;
    if($ref->{$key}) { # exist
        delete $ref->{$key};
        return 1;
    }
    0;
}

sub _array2hash {
    my @a = @_;
    my %h = ();
    for(@a) {
        $h{$_} = 1;
    }
    \%h;
}

sub update_search_db{
    my ($flag, @pos)=@_;
    my $poshash = _array2hash(@pos);
    my $cache = $ENV{MAILDIR}.'/search-cache.db';
    use Ext::DB;
    my $db = Ext::DB->new(
        file => "Btree:$cache",
        flags => "write"
    );
    my $info = parse_cache($db->lookup('HEADER'));
    my $nums = $info->{TOTALCOUNT};
    foreach(0...$nums-1) {
        if(_exist_pos_id($_, $poshash)) {
            my $currec=parse_cache($db->lookup("REC$_"));
            $db->delete("REC$_");
            my $nname;
            if ($flag eq 'Unseen'){
                $nname = set_status($currec->{FOLDER}, $currec->{FILENAME}, '-S');
            }elsif ($flag eq 'Seen'){
                $nname = set_status($currec->{FOLDER}, $currec->{FILENAME}, '+S');
            }
            $db->insert("REC$_",
                sprintf("FILENAME=%s\nFROM=%s\n".
                    "SUBJECT=%s\nSIZES=%s\nDATE=%s\nDATETIME=%s\nSIZEN=%s\n".
                    "TIME=%s\nINODE=%s\nPRIORITY=%s\nFOLDER=%s\nFDPOS=%s\n",
                    $nname,#here syn filename
                    $currec->{FROM},
                    $currec->{SUBJECT},
                    $currec->{SIZES},
                    $currec->{DATE},
                    $currec->{DATETIME}, # XXX
                    $currec->{SIZEN},
                    $currec->{TIME},
                    $currec->{INODE},
                    $currec->{PRIORITY}||'',
                    $currec->{FOLDER},
                    $currec->{FDPOS},
                )
            );
        }
    }
    undef $db;
}

sub update_search_db_inmove{
    my ($distdir,@pos) = @_;
    my $poshash = _array2hash(@pos);
    my $cache = $ENV{MAILDIR}.'/search-cache.db';
    use Ext::DB;
    my $db = Ext::DB->new(
        file => "Btree:$cache",
        flags => "write"
    );
    my $info = parse_cache($db->lookup('HEADER'));
    my $nums = $info->{TOTALCOUNT};
    foreach(0...$nums-1) {
        if(_exist_pos_id($_, $poshash)) {
            my $currec=parse_cache($db->lookup("REC$_"));
            $db->delete("REC$_");
            $db->insert("REC$_",
                sprintf("FILENAME=%s\nFROM=%s\n".
                    "SUBJECT=%s\nSIZES=%s\nDATE=%s\nDATETIME=%s\nSIZEN=%s\n".
                    "TIME=%s\nINODE=%s\nPRIORITY=%s\nFOLDER=%s\nFDPOS=%s\n",
                    $currec->{FILENAME},
                    $currec->{FROM},
                    $currec->{SUBJECT},
                    $currec->{SIZES},
                    $currec->{DATE},
                    $currec->{DATETIME}, # XXX
                    $currec->{SIZEN},
                    $currec->{TIME},
                    $currec->{INODE},
                    $currec->{PRIORITY}||'',
                    $distdir,
                    $currec->{FDPOS},
                )
            );
        }
    }
    undef $db;
}

sub del_search_bmsgs_db {
    my (@pos) = @_;
    my $poshash = _array2hash(@pos);
    my $cache = $ENV{MAILDIR}.'/search-cache.db';

    use Ext::DB;
    my $db = Ext::DB->new(
        file => "Btree:$cache",
        flags => "write"
    );

    my $info = parse_cache($db->lookup('HEADER'));
    my @newcache; # XXX new copy
    my $npos = 0;
    my $nums = $info->{TOTALCOUNT};
    foreach(0...$nums-1) {
        if(_exist_pos_id($_, $poshash)) {
            my $lv = parse_cache($db->lookup("REC$_"));
            # $db->delete("REC$_");
        }else {
            $newcache[$npos] = $db->lookup("REC$_");
            $npos++;
        }
    }

    undef $db; # destory the object
    unlink untaint($cache); # XXX rebuild now
    $db = Ext::DB->new(
        file => "Btree:$cache",
        flags => 'write'
    );
    my $nheader = sprintf "SAVETIME=%s\nTOTALCOUNT=%s\n".
            "SORT=%s\nSUBJECT=%s\nSENDER=%s\nRECEIVER=%s\n",
            time,scalar @newcache,$info->{SORT},$info->{SUBJECT},$info->{SENDER},$info->{RECEIVER};
    $db->update('HEADER', $nheader);
    for(0...$npos) {
        $db->insert("REC$_", $newcache[$_]);
    }
}

sub get_search_db_hdr {
    my $cache_file = $ENV{MAILDIR}.'/search-cache.db';
    if(-r $cache_file) {
        use Ext::DB;
        my %hash = ();
        my $db = Ext::DB->new(file => "Btree:$cache_file");
        my $info = parse_cache($db->lookup('HEADER'));
        return $info;
    }
    "";
}

sub get_search_db_sort{
    my $dir = _name2mdir($_[0]);
    my $cache = "$dir/extmail-curcache.db";
    if(!-e $cache) {
        return 'Dt';
    }

    use Ext::DB;
    my $db = Ext::DB->new(
        file => "Btree:$cache",
        flags => "write"
    );
    my $info = parse_cache($db->lookup('HEADER'));
    return $info->{SORT}||'Dt';
}

sub get_search_msgs_db {
    my ($nfiles, $pos) = @_;
    my $cache_file = $ENV{MAILDIR}.'/search-cache.db';

    if(-r $cache_file) {
        use Ext::DB;
        my %hash = ();
        my $db = Ext::DB->new(file => "Btree:$cache_file");

        my $info = parse_cache($db->lookup('HEADER'));
        my $end = ($pos+$nfiles)>= $info->{TOTALCOUNT}?
            $info->{TOTALCOUNT}: $pos+$nfiles;

        # update in 2005-08-19, return a flag to indicate whether
        # there are more entires in cache
        my $nomore = ($pos+$nfiles)>= $info->{TOTALCOUNT} ?
            1 : 0;

        foreach(my $i=$pos; $i<$end; $i++) {
            $hash{$i} = parse_cache($db->lookup("REC$i"));
        }
        undef $db;
        return (\%hash, $nomore);
    }else {
        die "Can't read $cache_file, $!\n";
    }
    1;
}

sub by_date {
    $b->{DATETIME} <=> $a->{DATETIME};
}

sub by_date_rev {
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

1;
