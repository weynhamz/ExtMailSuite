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
package Ext::Abook;

use Exporter;
use Ext::CSV;
use Fcntl qw(:flock);

use vars qw(@ISA @ABOOK $REF @GROUP @Head @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(@Head);
undef @ABOOK;
undef @GROUP;
$REF = undef;

# API design
# ----------
#
# type: group, abook, all base on CSV format
#
# search method: base on line number (ID) from 1...N
#
# functions for group:
# ====================
# grp_append
# grp_delete
# grp_update
# grp_lookup
# grp_exists
# grp_sort
# grp_dump
#
# functions for abook:
# ====================
# ab_append
# ab_delete
# ab_update
# ab_lookup
# ab_sort
# ab_search
# ab_getgrp
# ab_modgrp
# ab_dump
#
sub new {
    my $class = shift;
    my %opt = @_;

    my $self = {
        file => $opt{file} ? $opt{file} : 'abook.cf',
        gfile => $opt{gfile} ? $opt{gfile} : 'group.cf',
        type => $opt{type} ? $opt{type} : 'all', # type: all|abook|group
        lock => $opt{lock} ? 1:0,
        sort => $opt{sort} ? $opt{sort} : 'by_mailaddr',
        gsort => $opt{gsort} ? $opt{gsort} : 'by_name',
    };

    bless $self, $class;

    $REF = new Ext::CSV unless($REF);
    $self->parse; # XXX auto
    $self;
}

sub parse {
    my $self = shift;
    my $file = $self->{file};
    my $gfile = $self->{gfile};
    my $type = $self->{type};
    my $count = 0;

    if ($type =~ /^(all|abook)/) {
        open(FD, "< $file") or
            warn "$file not exists, abort\n" and return "";
        while (<FD>) {
            chomp;

            if ($REF->parse($_)) {
                my @field = $REF->fields;
                $ABOOK[$count] = \@field;
                $count ++;
            }else {
                warn $REF->error_input;
            }
        }
        close FD;
    }

    if ($type =~ /^(all|group)/) {
        $count = 0;
        open(FD, "< $gfile") or
            warn "$gfile not exists, abort\n" and return "";
        while (<FD>) {
            chomp;
            if ($REF->parse($_)) {
                my @field = $REF->fields;
                $GROUP[$count] = \@field;
                $count++;
            } else {
                warn $REF->error_input;
            }
        }
        close FD;
    }
}

# CSV format 1.0:
#
# 'ID', 'Name', 'Email', 'Company', 'Mobile'
#   0      1       2         3         4

# CSV format 2.0:
#
# ('ID',)
#
#   0
#
# Part 1: Main and IM
#
# ('Name', 'Email', 'NickName', 'IMaol', 'IMicq', 'IMgoogle', 'IMmsn', IMqq', 'IMskype',)
#    1        2         3          4         5          6       7        8       9
#
# Part 2: Personal
#
# ('HomeTel', 'Mobile', 'HomeAddress', 'HomeCity', 'HomeState', 'HomeZip', 'HomeCountry')
#    10          11         12             13           14         15           16
#
# Part 3: Business
#
# ('Company', 'Job', 'WorkMail', 'WorkTel', 'WorkFax', 'WorkAddress', 'WorkCity', 'WorkState', 'WorkZip', 'WorkCountry')
#    17        18        19         20          21           22           23          24           25         26
#
# Part 4: Other
#
# ('OtherMail', 'OtherPhone', 'WebSite', 'BirthDay', 'Notes', 'Picture')
#     27             28           29        30          31       32

@Head = ('Name','Email','NickName','IMaol','IMicq','IMgoogle','IMmsn','IMqq','IMskype',
            'HomeTel','Mobile','HomeAddress','HomeCity','HomeState','HomeZip','HomeCountry',
            'Company','Job', 'WorkMail','WorkTel','WorkFax','WorkAddress','WorkCity','WorkState',
            'WorkZip','WorkCountry','OtherMail','OtherPhone','WebSite','BirthDay','Notes', 'Picture');

my @GHead = ('GrpName', 'GrpMember'); # dynamic array!

# CVS group 1.0:
#
#       'GrpName',          'GrpMember' (0...N)
#   [8bit or A-Z space]     Email address only (0...N)
#

sub by_name {
    $a->[1] cmp $b->[1];
}

sub by_mailaddr {
    $a->[2] cmp $b->[2];
}

sub by_mobile {
    $a->[11] <=> $b->[11];
}

sub by_company {
    $a->[17] cmp $b->[17];
}

#
# Abook related functions
sub ab_dump {
    shift;
    return \@ABOOK;
}

sub ab_sort {
    my $self = shift;
    my @mybuf = @ABOOK; # deep copy

    for (0...scalar @mybuf-1) {
        $mybuf[$_] = [$_, @{$mybuf[$_]}];
    }
    shift @mybuf; # ignore the first line

    # sort it now
    my $method = $self->{sort};

    eval { @mybuf = sort $method @mybuf; };
    if ($@) {
        # default sort method
        @mybuf = sort by_mailaddr @mybuf;
    }
    unshift @mybuf, [0, @Head];
    \@mybuf; # sorted array
}

sub ab_search {
    my $self = shift;
    my $key = $_[0];
    my @id;
    my $ref = $self->ab_sort;

    foreach(my $k=1; $k < scalar @$ref; $k++) {
        # join to a big string
        my $lid = $ref->[$k]->[0]; # line ID
        my $s = join('', splice(@{$ref->[$k]}, 1)); # ignore the first id
        if($s=~/$key/i) {
            push @id, $lid;# return $k only?
        }
    }
    @id;
}

sub ab_lookup {
    my $self = shift;
    return $ABOOK[$_[0]] if($ABOOK[$_[0]]);
    "";
}

sub ab_delete {
    my $self = shift;
    my @id = @_;
    my @tarray;

    my $newid = 0;
    my $called = 0;
    foreach(my $k=0; $k < scalar @ABOOK; $k++) {
        my $del = 0;
        for(@id) {
            if($k eq $_) { $del = 1; last; }
        }
        if ($del) {
            # call modgrp() to delete member before
            # the abook deletion, or line id will be comfused!
            $self->ab_modgrp($k, []);
            $called = 1;
        } else {
            $tarray[$newid] = $ABOOK[$k];
            $newid++;
        }
    }
    $self->grp_save if $called; # if called ab_modgrp must call save
    @ABOOK = @tarray;
    undef @tarray;
}

sub ab_append {
    my $self = shift;
    my $ref = $_[0]; # ARRAY ref
    my $id = scalar @ABOOK;
    $ABOOK[$id] = $ref; # add into it
}

sub ab_update {
    my $self = shift;
    my ($id,$ref) = @_; # ref => ARRAY ref

    # must call ab_modgrp() first, then update abook, or ab_modgrp()
    # can't get the old abook infomation !
    $self->ab_modgrp($id, $ref);
    $ABOOK[$id] = $ref;# if not present, will auto
                       # append it
    $self->grp_save; # must save now!
}

sub ab_getgrp {
    my $self = shift;
    my $id = shift;
    my $buf = '"'.$ABOOK[$id]->[0] .'" <'.$ABOOK[$id]->[1].'>';

    my $k = 0;
    my $Grp = {}; # hash ref
    for my $g (@GROUP) {
        my $grpname = $g->[0]; # name
        foreach (my $i=1;$i<scalar @$g; $i++) {
            if ($g->[$i] eq $buf) {
                $Grp->{$k} = $grpname;
            }
        }
        $k++;
    }
    return $Grp;
}

# a special function to update group member for the member
# which been update by abook function, if we pass null newref
# to ab_modgrp(), then this member will be delete
sub ab_modgrp {
    my $self = shift;
    my ($id, $newref) = @_;
    my $obuf = '"'.$ABOOK[$id]->[0] .'" <'.$ABOOK[$id]->[1].'>';
    my $nbuf = '"'.$newref->[0] .'" <'.$newref->[1].'>';
    my $Grp = $self->ab_getgrp($id);
    my $del = 0;

    return unless $Grp;
    if (!scalar @$newref) {
        $del = 1;
    }
    foreach (my $i = 0; $i< scalar @GROUP; $i++) {
        if ($Grp->{$i}) {
            my $tarray = [$GROUP[$i]->[0]]; # save the name first
            # match yes!
            for (my $k=1; $k< scalar @{$GROUP[$i]}; $k++) {
                if ($GROUP[$i]->[$k] eq $obuf) {
                    next if $del; # ignore if the member need to delete!
                    push @$tarray, $nbuf;
                } else {
                    push @$tarray, $GROUP[$i]->[$k];
                }
            }
            delete $Grp->{$i};# purge
            $GROUP[$i] = $tarray; # array ref;
        }
    }
    undef $Grp;
    return 1;
}

sub ab_save {
    my $self = shift;
    my $file = $self->{file} || 'abook.cf';
    my $addhdr = 0;

    $addhdr = 1 if(!-r $file);
    open(FD, "> $file") or die "Write to $file error: $!\n";
    flock(FD, LOCK_EX);
    if($addhdr) {
        $REF->combine(@Head);
        print FD $REF->string,"\n";
    }
    foreach(my $k=0; $k< scalar @ABOOK; $k++) {
        my $val = $ABOOK[$k];
        $val = $REF->combine(@$val);
        $val = $REF->string($val);
        print FD $val,"\n";
    }
    flock(FD, LOCK_UN);
    close FD;
    1;
}

#
# Group related functions

sub grp_dump {
    shift;
    return \@GROUP;
}

sub grp_sort {
    my $self = shift;
    my @mybuf = @GROUP; # deep copy

    for (0...scalar @mybuf-1) {
        $mybuf[$_] = [$_, @{$mybuf[$_]}];
    }
    shift @mybuf; # ignore the first line

    # sort it now
    my $method = $self->{gsort};

    eval { @mybuf = sort $method @mybuf; };
    if ($@) {
        # default sort method
        @mybuf = sort by_name @mybuf;
    }
    unshift @mybuf, [0, 'GrpName', 'GrpMember'];
    \@mybuf; # sorted array
}

sub grp_append {
    my $self = shift;
    my $ref = $_[0]; # ARRAY ref
    my $id = scalar @GROUP;
    $GROUP[$id] = $ref; # add into it
}

sub grp_delete {
    my $self = shift;
    my @id = @_;
    my @tarray;

    my $newid = 0;
    foreach(my $k=0; $k < scalar @GROUP; $k++) {
        my $del = 0;
        for(@id) {
            if($k eq $_) { $del = 1; last; }
        }
        unless($del) {
            $tarray[$newid] = $GROUP[$k];
            $newid++;
        }
    }
    @GROUP = @tarray;
    undef @tarray;
}

sub grp_update {
    my $self = shift;
    my ($id,$ref) = @_; # ref => ARRAY ref
    $GROUP[$id] = $ref; # if not present, will auto
                        # append it
}

sub grp_lookup {
    my $self = shift;
    my $id = shift;
    return $GROUP[$id];
}

sub grp_exists {
    my $self = shift;
    my $name = shift;

    for (@GROUP) {
        return 1 if ($_->[0] eq $name);
    }
    0;
}

sub grp_save {
    my $self = shift;
    my $file = $self->{gfile} || 'group.cf';
    my $addhdr = 0;

    $addhdr = 1 if(!-r $file);
    open(FD, "> $file") or die "Write to $file error: $!\n";
    flock(FD, LOCK_EX);
    if($addhdr) {
        $REF->combine(@GHead);
        print FD $REF->string,"\n";
    }
    foreach(my $k=0; $k< scalar @GROUP; $k++) {
        my $val = $GROUP[$k];
        $val = $REF->combine(@$val);
        $val = $REF->string($val);
        print FD $val,"\n";
    }
    flock(FD, LOCK_UN);
    close FD;
    1;
}

sub DESTROY {
    undef $REF;
    undef @ABOOK;
    undef @GROUP;
}

1;
