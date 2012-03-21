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
package Ext::App::Abook;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::App Ext::App::GlobalAbook);
use Ext::App;
use Ext::Abook;
use Ext::Utils qw(myceil reset_working_path);
use Ext::MIME; # import html_fmt()
use Encode::PPUniDetector;
use Ext::Unicode::Iconv qw(iconv);

use vars qw(%lang_abook $lang_charset);
use Ext::Lang;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(abook_show => \&abook_show);
    $self->add_methods(abook_edit => \&abook_edit);
    $self->add_methods(abook_export => \&abook_export);
    $self->add_methods(abook_search => \&abook_search);
    $self->add_methods(group_edit => \&group_edit);
    $self->add_methods(group_delete => \&group_edit);

    $self->{default_mode} = 'abook_show';
    Ext::Storage::Maildir::init($self->get_working_path);

    $self->_initme;
    my $obj = Ext::Abook->new(file => 'abook.cf', gfile => 'group.cf');
    $self->{obj} = $obj;

    $self;
}

sub _initme {
    initlang($_[0]->userconfig->{lang}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_abook );
}

sub abook_export {
    my $self = shift;
    print "Content-Disposition: attachment; filename=\"abook.csv\"\r\n";
    print "Content-Type: text/plain; name=\"abook.csv\"\r\n\r\n";
    open(FD, "< abook.cf"); # ignore error;
    local $/ = undef;
    my $buf = <FD>;
    close FD;

    # convert abook from utf8 to local encoding if it's convertable
    my $rv = Encode::PPUniDetector::trylocal2($buf, intl2euc($self->userconfig->{lang}));
    if ($rv && uc $rv ne 'UTF-8') {
        $buf = iconv($buf, 'utf-8', $rv);
    }

    print $buf;
    $self->{tpl}->{noprint} = 1;
}

sub group_show {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $obj = $self->{obj};
    my $group = $obj->grp_sort;

    if (scalar @$group >1) {
        $tpl->assign(HAVE_GROUP => 1);
        foreach(my $i=1; $i< scalar @$group; $i++) {
            my $e = $group->[$i];
            $tpl->assign(
                'LOOP_GROUP',
                ID => $e->[0], # ID
                NAME => $e->[1], # name;
                MEMBER_COUNT => scalar @$e-2, # 2 = id + groupname
            );
        }
    } else {
        $tpl->assign(HAVE_GROUP => 0);
    }
}

sub abook_show {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $mode = $_[0];
    my $page = $q->cgi('page') || 0;
    my $show_all = $q->cgi('show_all') ? 1:0;
    my $size = $self->userconfig->{page_size} || 10;
    my $obj = $self->{obj};
    my $abook = $obj->ab_sort;
    my $maxpages = myceil((scalar @$abook -1)/$size); # total number

    $page = ($page >=0 ? ($page > $maxpages -1 ? $maxpages -1 : $page) : 0);

    $tpl->assign(
        # the nums of abook should >1, for the first member is
        # header fields
        HAVE_ABOOK => (scalar @$abook>1?1:0),
        SID => $self->{sid},
        CUR_PAGE => $page,
    );

    my $_end = ($page+1)*$size + 1;
    my $start = $show_all? 1 : $page*$size + 1;
    my $end = $show_all ? scalar @$abook : (scalar @$abook >=$_end ? $_end : scalar @$abook);

    foreach(my $k=$start; $k< $end; $k++) {
        my $e = $abook->[$k];
        $tpl->assign(
            'LOOP_ABOOK',
            ID => $e->[0],          # line ID
            NAME => $e->[1],        # 1
            MAILADDR => $e->[2],    # 2
            COMPANY => $e->[17],    # 17
            MOBILE => $e->[11]      # 11
        );
    }

    if ($show_all) {
        require Ext::App::GlobalAbook;
        my $obj = Ext::App::GlobalAbook->new;
        my $gbook = $obj->_init_obj->dump;

        for(my $k=0; $k < scalar @$gbook; $k++) {
            my $e = $gbook->[$k];
            $tpl->assign(
                'LOOP_GBOOK',
                ID => $k,
                NAME => $e->[0],
                MAILADDR => $e->[1],
                COMPANY => $e->[2],
                MOBILE => $e->[3],
            );
        }
        # if show all mode is active, not need to
        # show group and other paging info, just return
        return;
    }

    $self->group_show;

    $tpl->assign(
        HAVE_PREV => ($page >0? 1:0),
        HAVE_NEXT => ($page< $maxpages-1?1:0),
        PREV => ($page>0?$page-1:0),
        NEXT => ($page<$maxpages-1?$page+1:$maxpages),
    );

    unless($mode) {
        $tpl->assign(
            AB_NAME => $q->cgi('name'),
            AB_EMAIL => $q->cgi('mail'),
            AB_COMPANY => $q->cgi('company'),
            AB_MOBILE => $q->cgi('mobile')
        );
    }

    # return url support
    if($q->cgi('url')) {
        $tpl->assign( RETURN_URL => $q->cgi('url') );
    }
}

sub abook_edit {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $obj = $self->{obj};

    # big hack for address book manipulation
    # XXX FIXME
    # since 1.0.5 extmail use rich style address book design, for simple
    # coding we use tricks to get all fileds value :-)
    my $a = $q->cgi_full_names;
    my @ids = grep { s/^ab_// } @$a;

    # build head and cgi info :-)
    my $ref = [];
    for my $m (@Ext::Abook::Head) {
        push @$ref, $q->cgi('ab_'. lc $m);
    }

    if($q->cgi('newabook')) {
        $obj->ab_append($ref);
        $obj->ab_save;
        if($q->cgi('url')) {
            $tpl->{noprint} = 1;
            $self->{redirect} = $q->cgi('url');
        }
    }elsif($q->cgi('editsave')) {
        my $curid = $q->cgi('CURID');
        if($curid ne "" && $curid>0) {
            $obj->ab_update($q->cgi('CURID'), $ref);
            $obj->ab_save;
        }
    }elsif($q->cgi('delete')) {
        my $a = $q->cgi_full_names;
        my @ids = grep { s/^REMOVE-// } @$a; # get ids
        $obj->ab_delete(@ids);
        $obj->ab_save;
    }elsif($q->cgi('edit')) {
        my $a = $q->cgi_full_names;
        my ($id) = grep { s/^REMOVE-// } @$a; # get id
        my $s = '';
        if ($id >0 ) {
            $s = $obj->ab_lookup($id);
        } else {
            # do nothing
            $self->abook_show;
            return;
        }

        $tpl->assign(
            MODE_EDIT => 1,
            CURID => $id,
        );

        my $i = 0;
        my %hash;
        for my $m (@Ext::Abook::Head) {
            $hash{'AB_'.uc $m} = html_fmt($s->[$i]);
            $i++;
        }
        $tpl->assign(\%hash);
    }
    $self->abook_show('edit');
}

sub abook_search {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $obj = $self->{obj};

    my $key = $q->cgi('keyword');
    my @ids = $obj->ab_search($key);

    if(scalar @ids) {
        $tpl->assign( HAVE_ABOOK => 1, KEYWORD => $key );
    }else {
        $tpl->assign( SEARCH_NULL => 1 );
        $self->group_show;
        return 0;
    }

    my $size = $self->userconfig->{page_size};
    my $page = $q->cgi('page') || 0;
    my $maxpages = myceil(scalar @ids/$size);

    $page = ($page >=0 ? ($page > $maxpages -1 ? $maxpages -1 : $page) : 0);

    my $_end = ($page+1)*$size;
    my $start = $page*$size;
    my $end = scalar @ids >=$_end ? $_end : scalar @ids;

    $tpl->assign(
        CUR_PAGE => $page,
        HAVE_PREV => ($page >0? 1:0),
        HAVE_NEXT => ($page< $maxpages-1?1:0),
        PREV => ($page>0?$page-1:0),
        NEXT => ($page<$maxpages-1?$page+1:$maxpages),
    );

    for (my $id=$start;$id<$end;$id++) {
        my $e = $obj->ab_lookup($ids[$id]);
        $tpl->assign(
            'LOOP_ABOOK',
            ID => $ids[$id],            # lineID
            NAME => $e->[0],            # 1-1
            MAILADDR => $e->[1],        # 2-1
            COMPANY => $e->[16],        # 17-1
            MOBILE => $e->[10]          # 11-1
        );
    }
    $self->group_show;
}

sub group_edit {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};
    my $obj = $self->{obj};

    my $gname = $q->cgi('grpname');
    my $grpmember = [];
    for my $m (split(/\|/, $q->cgi('grpmember'))) {
        $m =~ s/^\s+//;
        $m =~ s/\s+$//;
        push @$grpmember, $m;
    }

    my $abook = $obj->ab_sort;
    for (my $i=1; $i<scalar @$abook; $i++) {
        my $m = $abook->[$i];
        my $buf = html_fmt('"'.$m->[1] .'" <'.$m->[2] .'>');
        $tpl->assign(
            'LOOP_ABOOK',
            MAIL => $buf,
        );
    }

    if ($q->cgi('newgroup')) {
        $obj->grp_append([$gname, @$grpmember]);
        $obj->grp_save;
        $tpl->assign( OKMSG => 'Add ok!');
        $self->group_show;
    } elsif ($q->cgi('delete')) {
        my $id = $q->cgi('delid');
        if ($id ne "" && $id>0) {
            $obj->grp_delete($id);
            $obj->grp_save;
            $tpl->assign( OKMSG => 'Delete ok!');
        } else {
            $tpl->assign( ERRMSG => 'Delete fail!');
        }
        $self->group_show;
    } elsif ($q->cgi('editsave')) {
        my $curid = $q->cgi('CURID');
        if($curid ne "" && $curid>0) {
            $obj->grp_update($q->cgi('CURID'), [$gname, @$grpmember]);
            $obj->grp_save;
            $tpl->assign( OKMSG => 'Save ok!');
        } else {
            $tpl->assign( ERRMSG => 'Bad id!');
        }
        $self->group_show;
    } elsif (defined $q->cgi('edit')) {
        my $id = $q->cgi('editid');
        my $s;
        if ($id >0) {
            $s = $obj->grp_lookup($id);
            $tpl->assign(CURID => $id);
        } else {
            # new add?
            $self->group_show;
            return;
        }
        $tpl->assign(
            MODE_EDIT => 1,
            CURID => $id,
            EDIT_NAME => html_fmt($s->[0]),
        );
        foreach (my $i=1; $i< scalar @$s; $i++) {
            $tpl->assign(
                'LOOP_MEMBER',
                MEMBER => html_fmt($s->[$i]),
            );
        }
        $self->group_show;
    }
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'abook.html';
    reset_working_path();
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
