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
package Ext::GraphLog;
use strict;

use Ext;
use vars qw(@ISA @EXPORT $rrd_tmp_dir);

@Ext::GraphLog::ISA = qw( Ext );

@EXPORT = qw(graph graph_err graph_queue graph_bytes
             graph_courier graph_webmail);

use RRDs;
use POSIX qw(uname strftime);
use vars qw($XWIDTH $YWIDTH $POINTS_SAMP);

$XWIDTH = 450 ;#540 default
$YWIDTH = 150 ;#150 default
$POINTS_SAMP = 3; # points per sample

my $rrd;
my $rrd_virus;
my $rrd_queue;
my $rrd_bytes;
my $rrd_courier;
my $rrd_webmail;

my %color = (
	sent     => '000099', # rrggbb in hex
	received => '009900',
	rejected => 'AA0000',
	bounced  => '000000',
	virus    => 'DDBB00',
	spam     => '999999',
	active	 => '00ff00',
	deferred => '0000ff',
	incoming => '336699',
	bounce	 => '000000',
    #in       => 'AABBCC',
    #out      => '330099',
    in       => '00FFFF',
    out      => 'D88132',
    pop3     => 'DD0000',
    pop3_ssl => '770000',
    imap     => '00DD00',
    imap_ssl => '007700',
    wmstat0  => '009900', # loginok
    wmstat1  => 'AA0000', # loginfail
    wmstat2  => '999999', # disabled
    wmstat3  => '0000ff', # deactive
);

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;
    my $rrd_store_dir = $Ext::Cfg{SYS_RRD_DATADIR} || '/var/lib';

    $rrd_tmp_dir = $Ext::Cfg{SYS_RRD_TMPDIR} || '/tmp/mailgraph';
    $rrd       = "$rrd_store_dir/mailgraph.rrd";
    $rrd_virus = "$rrd_store_dir/mailgraph_virus.rrd";
    $rrd_queue = "$rrd_store_dir/mailgraph_queue.rrd";
    $rrd_bytes = "$rrd_store_dir/mailgraph_bytes.rrd";
    $rrd_courier = "$rrd_store_dir/mailgraph_courier.rrd";
    $rrd_webmail = "$rrd_store_dir/mailgraph_webmail.rrd";

    $self;
}

sub local_time {
    # RRDTool will throw error if we return %H:%M:%S, must escape :
    my $date = strftime("%Y-%m-%d %H:%M:%S", localtime);
    $date =~ s|:|\\:|g unless $RRDs::VERSION < 1.199908;
    $date;
}

sub graph {
    my $self = shift;
	my $range = shift;
	my $file = shift;
	my $title = shift;
	my $myxpoints = shift;
	my $myypoints = shift;
	my $step = $range*$POINTS_SAMP/$XWIDTH;

	my ($graphret,$xs,$ys) = RRDs::graph($file,
		'--imgformat', 'PNG',
		'--width', $myxpoints,
		'--height', $myypoints,
		'--start', "-$range",
		'--end', "-".int($range*0.01),
		'--vertical-label', 'msgs/min',
		'--title', "$title of Successes",
		'--lazy',
        '--units-exponent', 0, # don't show milli-messages/s
        $RRDs::VERSION < 1.2002 ? () : (
            '--slope-mode'
        ),
		"DEF:sent=$rrd:sent:AVERAGE",
		"DEF:recv=$rrd:recv:AVERAGE",
		"DEF:msent=$rrd:sent:MAX",
		"DEF:mrecv=$rrd:recv:MAX",
		"CDEF:rsent=sent,60,*",
		"CDEF:rrecv=recv,60,*",
		"CDEF:rmsent=msent,60,*",
		"CDEF:rmrecv=mrecv,60,*",
		"CDEF:dsent=sent,UN,0,sent,IF,$step,*",
		"CDEF:ssent=PREV,UN,dsent,PREV,IF,dsent,+",
		"CDEF:drecv=recv,UN,0,recv,IF,$step,*",
		"CDEF:srecv=PREV,UN,drecv,PREV,IF,drecv,+",
		"AREA:rsent#$color{sent}:Sent    ",
		'GPRINT:ssent:MAX:total\: %8.0lf msgs',
		'GPRINT:rsent:AVERAGE:avg\: %.2lf msgs/min',
		'GPRINT:rmsent:MAX:max\: %.0lf msgs/min\l',
		"LINE2:rrecv#$color{received}:Received",
		'GPRINT:srecv:MAX:total\: %8.0lf msgs',
		'GPRINT:rrecv:AVERAGE:avg\: %.2lf msgs/min',
		'GPRINT:rmrecv:MAX:max\: %.0lf msgs/min\l',
		'HRULE:0#000000',
		'COMMENT:\s',
		'COMMENT:graph created on '.local_time().'\r',
	);
	my $ERR=RRDs::error;
	die "ERROR: $ERR\n" if $ERR;
}

sub graph_err {
    my $self = shift;
	my $range = shift;
	my $file = shift;
	my $title = shift;
	my $myxpoints = shift;
	my $myypoints = shift;
	my $step = $range*$POINTS_SAMP/$XWIDTH;

	my ($graphret,$xs,$ys) = RRDs::graph($file,
		'--imgformat', 'PNG',
		'--width', $myxpoints,
		'--height', $myypoints,
		'--start', "-$range",
		'--end', "-".int($range*0.01),
		'--vertical-label', 'msgs/min',
		'--title', "$title of Errors",
		'--lazy',
        '--units-exponent', 0, # don't show milli-messages/s
        $RRDs::VERSION < 1.2002 ? () : (
            '--slope-mode'
        ),
		"DEF:bounced=$rrd:bounced:AVERAGE",
		"DEF:rejected=$rrd:rejected:AVERAGE",
		"DEF:virus=$rrd_virus:virus:AVERAGE",
		"DEF:spam=$rrd_virus:spam:AVERAGE",
		"DEF:mbounced=$rrd:bounced:MAX",
		"DEF:mrejected=$rrd:rejected:MAX",
		"DEF:mvirus=$rrd_virus:virus:MAX",
		"DEF:mspam=$rrd_virus:spam:MAX",
		"CDEF:rbounced=bounced,60,*",
		"CDEF:rrejected=rejected,60,*",
		"CDEF:rvirus=virus,60,*",
		"CDEF:rspam=spam,60,*",

		"CDEF:dbounced=bounced,UN,0,bounced,IF,$step,*",
		"CDEF:sbounced=PREV,UN,dbounced,PREV,IF,dbounced,+",
		"CDEF:drejected=rejected,UN,0,rejected,IF,$step,*",
		"CDEF:srejected=PREV,UN,drejected,PREV,IF,drejected,+",
		"CDEF:dvirus=virus,UN,0,virus,IF,$step,*",
		"CDEF:svirus=PREV,UN,dvirus,PREV,IF,dvirus,+",
		"CDEF:dspam=spam,UN,0,spam,IF,$step,*",
		"CDEF:sspam=PREV,UN,dspam,PREV,IF,dspam,+",

		"CDEF:rmbounced=mbounced,60,*",
		"CDEF:rmrejected=mrejected,60,*",
		"CDEF:rmvirus=mvirus,60,*",
		"CDEF:rmspam=mspam,60,*",
		"AREA:rrejected#$color{rejected}:Rejected",
		'GPRINT:srejected:MAX:total\: %5.0lf msgs',
		'GPRINT:rrejected:AVERAGE:avg\: %.2lf msgs/min',
		'GPRINT:rmrejected:MAX:max\: %.0lf msgs/min\l',
		"STACK:rbounced#$color{bounced}:Bounced ",
		'GPRINT:sbounced:MAX:total\: %5.0lf msgs',
		'GPRINT:rbounced:AVERAGE:avg\: %.2lf msgs/min',
		'GPRINT:rmbounced:MAX:max\: %.0lf msgs/min\l',
		"STACK:rvirus#$color{virus}:Viruses ",
		'GPRINT:svirus:MAX:total\: %5.0lf msgs',
		'GPRINT:rvirus:AVERAGE:avg\: %.2lf msgs/min',
		'GPRINT:rmvirus:MAX:max\: %.0lf msgs/min\l',
		"STACK:rspam#$color{spam}:SPAM    ",
		'GPRINT:sspam:MAX:total\: %5.0lf msgs',
		'GPRINT:rspam:AVERAGE:avg\: %.2lf msgs/min',
		'GPRINT:rmspam:MAX:max\: %.0lf msgs/min\l',
		'HRULE:0#000000',
		'COMMENT:\s',
		'COMMENT:graph created on '.local_time().'\r',
	);
	my $ERR=RRDs::error;
	die "ERROR: $ERR\n" if $ERR;
}

sub graph_queue {
    my $self = shift;
	my $range = shift;
	my $file = shift;
	my $title = shift;
	my $myxpoints = shift;
	my $myypoints = shift;
	my $step = $range*$POINTS_SAMP/$XWIDTH;

	my ($graphret,$xs,$ys) = RRDs::graph($file,
		'--imgformat', 'PNG',
		'--width', $myxpoints,
		'--height', $myypoints,
		'--start', "-$range",
		'--end', "-".int($range*0.01),
		'--vertical-label', 'msgs/min',
		'--title', "$title of Queues",
		'--lazy',
        '--units-exponent', 0, # don't show milli-messages/s
        $RRDs::VERSION < 1.2002 ? () : (
            '--slope-mode'
        ),
        "DEF:hold=$rrd_queue:hold:AVERAGE",
        "DEF:maildrop=$rrd_queue:maildrop:AVERAGE",
        "DEF:active=$rrd_queue:active:AVERAGE",
        "DEF:deferred=$rrd_queue:deferred:AVERAGE",
        "DEF:incoming=$rrd_queue:incoming:AVERAGE",
        "DEF:mhold=$rrd_queue:hold:MAX",
        "DEF:mmaildrop=$rrd_queue:maildrop:MAX",
        "DEF:mactive=$rrd_queue:active:MAX",
        "DEF:mdeferred=$rrd_queue:deferred:MAX",
        "DEF:mincoming=$rrd_queue:incoming:MAX",
        "CDEF:rhold=hold,60,*",
        "CDEF:rmaildrop=maildrop,60,*",
        "CDEF:ractive=active,60,*",
        "CDEF:rdeferred=deferred,60,*",
        "CDEF:rincoming=incoming,60,*",

        "CDEF:dhold=hold,UN,0,hold,IF,$step,*",
        "CDEF:shold=PREV,UN,dhold,PREV,IF,dhold,+",
        "CDEF:dmaildrop=hold,UN,0,maildrop,IF,$step,*",
        "CDEF:smaildrop=PREV,UN,dmaildrop,PREV,IF,dmaildrop,+",
        "CDEF:dactive=active,UN,0,active,IF,$step,*",
        "CDEF:sactive=PREV,UN,dactive,PREV,IF,dactive,+",
        "CDEF:ddeferred=deferred,UN,0,deferred,IF,$step,*",
        "CDEF:sdeferred=PREV,UN,ddeferred,PREV,IF,ddeferred,+",
        "CDEF:dincoming=incoming,UN,0,incoming,IF,$step,*",
        "CDEF:sincoming=PREV,UN,dincoming,PREV,IF,dincoming,+",

        "CDEF:rmhold=mhold,60,*",
        "CDEF:rmmaildrop=mmaildrop,60,*",
        "CDEF:rmactive=mactive,60,*",
        "CDEF:rmdeferred=mdeferred,60,*",
        "CDEF:rmincoming=mincoming,60,*",
        "AREA:ractive#$color{active}:Active   ",

        'GPRINT:sactive:MAX:total\: %5.0lf msgs',
        'GPRINT:ractive:AVERAGE:avg\: %.2lf msgs/min',
        'GPRINT:rmactive:MAX:max\: %.0lf msgs/min\l',
        "STACK:rhold#$color{bounce}:Hold     ",
        'GPRINT:shold:MAX:total\: %5.0lf msgs',
        'GPRINT:rhold:AVERAGE:avg\: %.2lf msgs/min',
        'GPRINT:rmhold:MAX:max\: %.0lf msgs/min\l',
        "STACK:rdeferred#$color{deferred}:Deferred ",
        'GPRINT:sdeferred:MAX:total\: %5.0lf msgs',
        'GPRINT:rdeferred:AVERAGE:avg\: %.2lf msgs/min',
        'GPRINT:rmdeferred:MAX:max\: %.0lf msgs/min\l',
        "STACK:rincoming#$color{incoming}:Incoming ",
        'GPRINT:sincoming:MAX:total\: %5.0lf msgs',
        'GPRINT:rincoming:AVERAGE:avg\: %.2lf msgs/min',
        'GPRINT:rmincoming:MAX:max\: %.0lf msgs/min\l',

		'HRULE:0#000000',
		'COMMENT:\s',
		'COMMENT:graph created on '.local_time().'\r',
	);

	my $ERR=RRDs::error;
	die "ERROR: $ERR\n" if $ERR;
}

sub graph_bytes {
    my $self = shift;
    my $range = shift;
    my $file = shift;
    my $title = shift;
    my $myxpoints = shift;
    my $myypoints = shift;
    my $step = $range*$POINTS_SAMP/$XWIDTH;

    my ($graphret,$xs,$ys) = RRDs::graph($file,
        '--imgformat', 'PNG',
        '--width', $myxpoints,
        '--height', $myypoints,
        '--start', "-$range",
        '--end', "-".int($range*0.01),
        '--vertical-label', 'bytes/min',
        '--title', "$title of Traffic",
        '--lazy',
        $RRDs::VERSION < 1.2002 ? () : (
            '--slope-mode'
        ),
        "DEF:bytesin=$rrd_bytes:bytesin:AVERAGE",
        "DEF:bytesout=$rrd_bytes:bytesout:AVERAGE",
        "DEF:mbytesin=$rrd_bytes:bytesin:MAX",
        "DEF:mbytesout=$rrd_bytes:bytesout:MAX",
        "CDEF:nbytesin=bytesin,60,*",
        "CDEF:nbytesout=bytesout,60,*",
        "CDEF:rbytesin=bytesin,60,*,1024,/",
        "CDEF:rbytesout=bytesout,60,*,1024,/",

        "CDEF:rmbytesin=mbytesin,60,*,1024,/",
        "CDEF:rmbytesout=mbytesout,60,*,1024,/",
        "CDEF:dbytesin=bytesin,UN,0,bytesin,IF,$step,*,1024,/",
        "CDEF:sbytesin=PREV,UN,dbytesin,PREV,IF,dbytesin,+",
        "CDEF:dbytesout=bytesout,UN,0,bytesout,IF,$step,*,1024,/",
        "CDEF:sbytesout=PREV,UN,dbytesout,PREV,IF,dbytesout,+",

        "AREA:nbytesin#$color{in}:IN ",
        'GPRINT:sbytesin:MAX:total\: %8.1lfK',
        'GPRINT:rbytesin:AVERAGE:avg\: %.1lfK/min',
        'GPRINT:rmbytesin:MAX:max\: %.1lfK/min',
        'GPRINT:rbytesin:LAST:cur\: %.1lfK/min\l',

        "LINE2:nbytesout#$color{out}:OUT",
        'GPRINT:sbytesout:MAX:total\: %8.1lfK',
        'GPRINT:rbytesout:AVERAGE:avg\: %.1lfK/min',
        'GPRINT:rmbytesout:MAX:max\: %.1lfK/min',
        'GPRINT:rbytesout:LAST:cur\: %.1lfK/min\l',

        'HRULE:0#000000',
        'COMMENT:\s',
        'COMMENT:graph created on '.local_time().'\r',
    );

    my $ERR=RRDs::error;
    die "ERROR: $ERR\n" if $ERR;
}

sub graph_courier {
    my $self = shift;
    my $range = shift;
    my $file = shift;
    my $title = shift;
    my $myxpoints = shift;
    my $myypoints = shift;
    my $step = $range*$POINTS_SAMP/$XWIDTH;

    my ($graphret,$xs,$ys) = RRDs::graph($file,
        '--imgformat', 'PNG',
        '--width', $myxpoints,
        '--height', $myypoints,
        '--start', "-$range",
        '--end', "-".int($range*0.01),
        '--vertical-label', 'logins/min',
        '--title', "$title of IMAP/POP Login",
        '--lazy',
        $RRDs::VERSION < 1.2002 ? () : (
            '--slope-mode'
        ),
        "DEF:pop3d_login=$rrd_courier:pop3d_login:AVERAGE",
        "DEF:mpop3d_login=$rrd_courier:pop3d_login:MAX",
        "DEF:pop3d_ssl_login=$rrd_courier:pop3d_ssl_login:AVERAGE",
        "DEF:mpop3d_ssl_login=$rrd_courier:pop3d_ssl_login:MAX",

        "CDEF:rpop3d_login=pop3d_login,60,*",
        "CDEF:vpop3d_login=pop3d_login,UN,0,pop3d_login,IF,$range,*",
        "CDEF:rmpop3d_login=mpop3d_login,60,*",

        "CDEF:rpop3d_ssl_login=pop3d_ssl_login,60,*",
        "CDEF:vpop3d_ssl_login=pop3d_ssl_login,UN,0,pop3d_ssl_login,IF,$range,*",
        "CDEF:rmpop3d_ssl_login=mpop3d_ssl_login,60,*",

        "DEF:imapd_login=$rrd_courier:imapd_login:AVERAGE",
        "DEF:mimapd_login=$rrd_courier:imapd_login:MAX",
        "DEF:imapd_ssl_login=$rrd_courier:imapd_ssl_login:AVERAGE",
        "DEF:mimapd_ssl_login=$rrd_courier:imapd_ssl_login:MAX",

        "CDEF:rimapd_login=imapd_login,60,*",
        "CDEF:vimapd_login=imapd_login,UN,0,imapd_login,IF,$range,*",
        "CDEF:rmimapd_login=mimapd_login,60,*",

        "CDEF:rimapd_ssl_login=imapd_ssl_login,60,*",
        "CDEF:rmimapd_ssl_login=mimapd_ssl_login,60,*",
        "CDEF:vimapd_ssl_login=imapd_ssl_login,UN,0,imapd_ssl_login,IF,$range,*",

        "LINE1:rpop3d_login#$color{pop3}:pop3    ",
        'GPRINT:vpop3d_login:AVERAGE:total\: %.0lf logins',
        'GPRINT:rpop3d_login:AVERAGE:avg\: %.2lf logins',
        'GPRINT:rmpop3d_login:MAX:max\: %.0lf logins/min\l',
        'HRULE:0#000000',

        "AREA:rpop3d_ssl_login#$color{pop3_ssl}:pop3/ssl:STACK",
        'GPRINT:vpop3d_ssl_login:AVERAGE:total\: %.0lf logins',
        'GPRINT:rpop3d_ssl_login:AVERAGE:avg\: %.2lf logins',
        'GPRINT:rmpop3d_ssl_login:MAX:max\: %.0lf logins/min\l',
        'HRULE:0#000000',

        "LINE2:rimapd_login#$color{imap}:imap    ",
        'GPRINT:vimapd_login:AVERAGE:total\: %.0lf logins',
        'GPRINT:rimapd_login:AVERAGE:avg\: %.2lf logins',
        'GPRINT:rmimapd_login:MAX:max\: %.0lf logins/min\l',
        'HRULE:0#000000',

        "AREA:rimapd_ssl_login#$color{imap_ssl}:imap/ssl:STACK",
        'GPRINT:vimapd_ssl_login:AVERAGE:total\: %.0lf logins',
        'GPRINT:rimapd_ssl_login:AVERAGE:avg\: %.2lf logins',
        'GPRINT:rmimapd_ssl_login:MAX:max\: %.0lf logins/min\l',

        'COMMENT:\s',
        'COMMENT:graph created on '.local_time().'\r',
    );

    my $ERR=RRDs::error;
    die "ERROR: $ERR\n" if $ERR;
}

sub graph_webmail {
    my $self = shift;
    my $range = shift;
    my $file = shift;
    my $title = shift;
    my $myxpoints = shift;
    my $myypoints = shift;
    my $step = $range*$POINTS_SAMP/$XWIDTH;

    my ($graphret,$xs,$ys) = RRDs::graph($file,
        '--imgformat', 'PNG',
        '--width', $myxpoints,
        '--height', $myypoints,
        '--start', "-$range",
        '--end', "-".int($range*0.01),
        '--vertical-label', 'logins/min',
        '--title', "$title of WebMail Login",
        '--lazy',
        '--units-exponent', 0, # don't show milli-messages/s
        $RRDs::VERSION < 1.2002 ? () : (
            '--slope-mode'
        ),
        "DEF:wmstat0=$rrd_webmail:wmstat0:AVERAGE",
        "DEF:mwmstat0=$rrd_webmail:wmstat0:MAX",
        "DEF:wmstat1=$rrd_webmail:wmstat1:AVERAGE",
        "DEF:mwmstat1=$rrd_webmail:wmstat1:MAX",

        "CDEF:rwmstat0=wmstat0,60,*",
        "CDEF:vwmstat0=wmstat0,UN,0,wmstat0,IF,$range,*",
        "CDEF:rmwmstat0=mwmstat0,60,*",

        "CDEF:rwmstat1=wmstat1,60,*",
        "CDEF:vwmstat1=wmstat1,UN,0,wmstat1,IF,$range,*",
        "CDEF:rmwmstat1=mwmstat1,60,*",

        "DEF:wmstat2=$rrd_webmail:wmstat2:AVERAGE",
        "DEF:mwmstat2=$rrd_webmail:wmstat2:MAX",
        "DEF:wmstat3=$rrd_webmail:wmstat3:AVERAGE",
        "DEF:mwmstat3=$rrd_webmail:wmstat3:MAX",

        "CDEF:rwmstat2=wmstat2,60,*",
        "CDEF:vwmstat2=wmstat2,UN,0,wmstat2,IF,$range,*",
        "CDEF:rmwmstat2=mwmstat2,60,*",

        "CDEF:rwmstat3=wmstat3,60,*",
        "CDEF:rmwmstat3=mwmstat3,60,*",
        "CDEF:vwmstat3=wmstat3,UN,0,wmstat3,IF,$range,*",

        "LINE1:rwmstat0#$color{wmstat0}:loginok  ",
        'GPRINT:vwmstat0:AVERAGE:total\: %.0lf logins',
        'GPRINT:rwmstat0:AVERAGE:avg\: %.2lf logins/min',
        'GPRINT:rmwmstat0:MAX:max\: %.0lf logins/min\l',
        'HRULE:0#000000',

        "AREA:rwmstat1#$color{wmstat1}:loginfail:STACK",
        'GPRINT:vwmstat1:AVERAGE:total\: %.0lf logins',
        'GPRINT:rwmstat1:AVERAGE:avg\: %.2lf logins/min',
        'GPRINT:rmwmstat1:MAX:max\: %.0lf logins/min\l',
        'HRULE:0#000000',

        "LINE2:rwmstat2#$color{wmstat2}:disabled ",
        'GPRINT:vwmstat2:AVERAGE:total\: %.0lf logins',
        'GPRINT:rwmstat2:AVERAGE:avg\: %.2lf logins/min',
        'GPRINT:rmwmstat2:MAX:max\: %.0lf logins/min\l',
        'HRULE:0#000000',

        "AREA:rwmstat3#$color{wmstat3}:deactive :STACK",
        'GPRINT:vwmstat3:AVERAGE:total\: %.0lf logins',
        'GPRINT:rwmstat3:AVERAGE:avg\: %.2lf logins/min',
        'GPRINT:rmwmstat3:MAX:max\: %.0lf logins/min\l',

        'COMMENT:\s',
        'COMMENT:graph created on '.local_time().'\r',
    );

    my $ERR=RRDs::error;
    die "ERROR: $ERR\n" if $ERR;
}

1;
