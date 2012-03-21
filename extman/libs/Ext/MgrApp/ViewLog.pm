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
package Ext::MgrApp::ViewLog;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::MgrApp);
use Ext::MgrApp;
use vars qw($lang_charset %lang_viewlog @graphs);
use Ext::Lang;
use POSIX qw(uname);
use Ext::GraphLog;

my $host = (POSIX::uname())[1];
my $xpoints = $Ext::GraphLog::XWIDTH;
my $ypoints = $Ext::GraphLog::YWIDTH;
my $tmp_dir;
my $xpoints_s = 450;
my $ypoints_s = 80;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(view_all => \&view_all);
    $self->{default_mode} = 'view_all';

    if ($self->{sysconfig}->{SYS_RRD_QUEUE_ON} eq 'yes') {
        $self->{tpl}->assign(QUEUE_ON => 1);
    }

    $self->{_gl} = new Ext::GraphLog;

    # after new a Ext::GraphLog object, rrd_tmp_dir will be initialized
    $tmp_dir = $Ext::GraphLog::rrd_tmp_dir;

    $self->_initme;
    $self->_initarray;
    $self;
}

sub _initme {
    initlang($_[0]->{sysconfig}->{'SYS_LANG'}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_viewlog );
}

# must called after _initme, or %lang_viewlog can't be initialize
sub _initarray {
    my $self = shift;
    @graphs = (
    { title => $lang_viewlog{day_graph},   seconds => 3600*24,     graph_title => $lang_viewlog{gday}  },
    { title => $lang_viewlog{week_graph},  seconds => 3600*24*7,   graph_title => $lang_viewlog{gweek} },
    { title => $lang_viewlog{month_graph}, seconds => 3600*24*31,  graph_title => $lang_viewlog{gmonth}},
    { title => $lang_viewlog{year_graph},  seconds => 3600*24*365, graph_title => $lang_viewlog{gyear}},
    );
}

sub view {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $sid = $q->cgi('sid');

    if ( $q->cgi('view') eq "success" ) {
        $tpl->assign(TITLE => "$lang_viewlog{statistic_success}: $host" );
    } elsif ( $q->cgi('view') eq "errors" ) {
        $tpl->assign(TITLE => "$lang_viewlog{statistic_errors}: $host");
    } elsif ( $q->cgi('view') eq "bytes" ) {
        $tpl->assign(TITLE => "$lang_viewlog{statistic_bytes}: $host");
    } elsif ( $q->cgi('view') eq "queue" ) {
        $tpl->assign(TITLE => "$lang_viewlog{statistic_queue}: $host");
    } elsif ( $q->cgi('view') eq 'courier') {
        $tpl->assign(TITLE => "$lang_viewlog{statistic_courier}: $host");
    } elsif ( $q->cgi('view') eq 'webmail') {
        $tpl->assign(TITLE => "$lang_viewlog{statistic_webmail}: $host");
    } else {
        $tpl->assign(TITLE => "$lang_viewlog{statistic}: $host");
    }

    if (!$q->cgi('mode')) {
        $tpl->assign(VIEW_ALL => 1);
    } else {
        for my $n (0..$#graphs) {
            my $type = '';
            my $view = $q->cgi('view');
            if ($view eq 'success') {
                $type = '';
            } elsif ($view eq 'errors') {
                $type = 'err';
            } elsif ($view eq 'queue') {
                $type = 'queue';
            } elsif ($view eq 'bytes') {
                $type = 'bytes';
            } elsif ($view eq 'courier') {
                $type = 'courier';
            } elsif ($view eq 'webmail') {
                $type = 'webmail';
            }

            $tpl->assign(
                'LOOP_GRAPH_DETAIL',
                GRAPH_TITLE => "$graphs[$n]->{title}",
                GRAPH_TYPE => $type,
                GRAPH_NUM => $n,
            );
        }
        $tpl->assign(VIEW_ALL => 0);
    }
}

sub send_image {
    my $self = shift;
    my $file = shift;

    if (!-r $file) {
        $self->error("ERROR: can't find $file");
        return;
    }

    print "Content-Type: image/png\n";
    print "Content-Length: ".((stat($file))[7])."\n";
    print "\n";
    open (FD, "< $file") or die "Error open $file, $!\n";
    my $data;
    print $data while read(FD, $data, 1024);
    close FD;
}

sub view_all {
    my $self = shift;
    my $q = $self->{query};
    my $tpl = $self->{tpl};

    if( $q->cgi('mode') =~ m/^(thumb|normal)$/ && $q->cgi('filename')) {
        $self->draw;
        # disable tpl header, or it will cause image display corruption
        $tpl->{noprint} = 1;
    } else {
        $self->view;
    }
}

sub draw {
    my $self = shift;
    my $q = $self->{query};

    my $filename = $q->cgi('filename');
    my $mode = $q->cgi('mode');
    my $dirTomk;

    if ($mode eq "thumb") {
        $dirTomk = $tmp_dir . "/thumb";
    } elsif ( $q->cgi('mode') eq "normal" ) {
        $dirTomk = $tmp_dir . "/normal";
    }

    mkdir $tmp_dir, 0777 unless -d $tmp_dir;
    mkdir $dirTomk, 0777 unless -d $dirTomk;

    my $file = "$dirTomk/$filename";
    my $xpoints_t;
    my $ypoints_t;

    if ($mode eq "thumb") {
        $xpoints_t = $xpoints_s;
        $ypoints_t = $ypoints_s;
    } elsif ($mode eq "normal") {
        $xpoints_t = $xpoints;
        $ypoints_t = $ypoints;
    }

    if( $filename =~ /mailgraph_(\d+)\.png$/ ) {
        $self->{_gl}->graph($graphs[$1]{seconds}, $file, $graphs[$1]{graph_title}, $xpoints_t, $ypoints_t);
    } elsif( $filename =~ /mailgraph_(\d+)_err\.png$/ ) {
        $self->{_gl}->graph_err($graphs[$1]{seconds}, $file, $graphs[$1]{graph_title}, $xpoints_t, $ypoints_t);
    } elsif( $filename =~ /mailgraph_(\d+)_queue\.png$/) {
        $self->{_gl}->graph_queue($graphs[$1]{seconds}, $file, $graphs[$1]{graph_title}, $xpoints_t, $ypoints_t);
    } elsif( $filename =~ /mailgraph_(\d+)_bytes\.png$/) {
        $self->{_gl}->graph_bytes($graphs[$1]{seconds}, $file, $graphs[$1]{graph_title}, $xpoints_t, $ypoints_t);
    } elsif( $filename =~ /mailgraph_(\d+)_courier\.png$/) {
        $self->{_gl}->graph_courier($graphs[$1]{seconds}, $file, $graphs[$1]{graph_title}, $xpoints_t, $ypoints_t);
    } elsif( $filename =~ /mailgraph_(\d+)_webmail\.png$/) {
        $self->{_gl}->graph_webmail($graphs[$1]{seconds}, $file, $graphs[$1]{graph_title}, $xpoints_t, $ypoints_t);
    } else {
        $self->error($lang_viewlog{unknowimg} . "&nbsp;" . $file);
        return;
    }

    $self->send_image($file);
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'viewlog_all.html';
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

1;
