#!/bin/sh
exec ${PERL-perl} -Swx $0 ${1+"$@"}

#!/usr/bin/perl -w
# vim: set ci et ts=4 sw=4:
#  domainctl.pl: domain name management
#	     Author: chifeng <chifeng At gmail.com>
#	       Date: 2007-11-28 15:39:00
#   Last Update: 2009-12-24 16:37:00
#      Homepage: http://www.extmail.org
#	    Version: 20091224
#
#
use vars qw($DIR);

BEGIN {
    my $path = $0;
    if ($path =~ s/tools\/[0-9a-zA-Z\-\_]+\.pl$//) {
	if ($path !~ /^\//) {
	    $DIR = "./$path";
	} else {
            $DIR = $path;
        }
    } else {
        $DIR = '../';
    }
    unshift @INC, $DIR .'libs';
};

# use strict; # developing env
no warnings; # production environment
use POSIX qw(strftime);
use Ext::Mgr;
use CmdTools;
use Ext::DateTime qw(time2epoch epoch2time);
use Getopt::Long;
use Switch;
use IO::File;
use Data::Dumper;
require $DIR.'/tools/setid.pl';

my $VERSION = 'CMDTools-20091224';

my %opt = (); # parameters
my @exp; # export parameters
my $ctx = CmdTools->new( config => $DIR . '/webman.cf', directory => $DIR );
my $c = \%Ext::Cfg;
my $mgr = $ctx->ctx; # backend object
my $set_user=$c->{SYS_DEFAULT_UID};
my $set_group=$c->{SYS_DEFAULT_GID};

Getopt::Long::Configure('no_ignore_case');
Getopt::Long::GetOptions(\%opt,
    'mode|m=s',
    'domain|d=s',
    'description|s=s',
    'maxuser|mu=i',
    'maxalias|ma=i',
    'maxquota|mq=i',
    'maxndquota|mn=i',
    'expire|e=s',
    'active|a=i',
    'signup|S=i',
    'transport|t=s',
    'userquota|uq=i',
    'userndquota|un=i',
    'userlifetime|ul=s',
    'userservices|us=s',
    'setgid|sg=s',
    'setuid|su=s',
    'quiet|qq',
    'xml|x',
) or exit 1;

if($opt{setgid} && $opt{setuid}){
    $set_user = $opt{setuid};
    $set_group = $opt{setgid};
}
set_gid($set_user);
set_uid($set_group);

sub output_default {
    return if($opt{quiet});
    my $type = $_[0];
    if($exp[0]->{status} eq 0){
        print $exp[0]->{prompt};
        print "\n";
    }else{
        for $href (@exp){
            foreach my $i ( keys %$href ){
                next if($i eq "status");
                printf ("%s", $href->{$i}),;
            }
            print "\n";
        }
    }
    exit;
}

sub output_xml {
    return if($opt{quiet});
    my $type = $_[0];
    print "<?xml version=\"1.0\" encoding=\"UTF-8\"?> \n";
    print "<ExtmailAPI>\n";
    my $j = 0;
    for $href (@exp){
        print " <item key=\"$j\">\n";
        foreach my $i ( keys %$href ){
            print "  <$i>";
            print "$href->{$i}";
            print "</$i>";
            print "\n";
        }
        print " </item>\n";
        $j++;
    }
    print "</ExtmailAPI>\n";
    exit;
}

sub output_show {
    return if($opt{quiet});
    if($opt{xml}){
        output_xml;
    }
    my $type = $_[0];
    if($exp[0]->{status} eq 0){
        print $exp[0]->{prompt};
        print "\n";
    }else{
        print $exp[0]->{prompt};
        print "\n--------------------------------------------------------------\n";
        for $href (@exp){
            foreach my $i ( keys %$href ){
                next if($i eq "status");
                next if($i eq "prompt");
                printf ("%s = ", $i);
                printf ("%s", $href->{$i});
                print "\n";
            }
            print "\n";
        }
    }
    exit;
}

sub output {
    if($opt{xml}){
        output_xml;
    }else{
        output_default;
    }
}

sub usage_xml {
    push @exp, { mode => "add,del,list,show,mod,help",
        domain => "domain name",
        description => "domain description",
        maxuser => "max user",
        maxalias => "max alias",
        maxquota => "max quota",
        maxndquota => "max netdisk quota",
        expire => "2012-12-31",
        active => "1 or 0",
        signup => "1 or 0",
        transport => "transport",
        userquota => "per user default quota",
        userndquota => "per user default netdisk quota",
        userlifetime => "per user default life time",
        userservices => "per user default services",
        setgid => "vgroup",
        setuid => "vuser",
        quiet => "quiet mode",
        xml => "xml output",
        status => 0,
        prompt => "help info",
    };
    output ;
}

sub usage_default {
    return if($opt{quiet});
    print qq~
usage: ./domainctl.pl command [options] ...

Commands:

    add     -- add a domain
    del     -- delete a domain
    list    -- list all domains
    show    -- show profile of a domain
    mod     -- modify domain infomation
    help    -- display this help and exit

Options:

  -d, --domain="domain.tld"                       A domain name
  -s, --description="A test domain"               Domain description
  -mu, --maxuser=500                              A max users number
  -ma, --maxalias=500                             A max aliases number
  -mq, --maxquota=500                             A max quota
  -md, --maxndquota=500                           A max netdisk quota
  -e, --expire="2012-12-31"                       Expire date
  -a, --active=1                                  Enable or disable (1 or 0)
  -S, --signup=1                                  Open signup? Enable or disable (1 or 0)
  -t, --transport="mx1.extmail.org"               Open signup? Enable or disable (1 or 0)
  -uq, --userquota=100
  -un, --userndquota=100
  -ul, --userlifetime="1y"
  -us, --userservices="smtp,smtpd,pop3,webmail"   Enable services (smtp,smtpd,pop3,imap,webmail,netdisk,pwdchange)
  -su, --setuid="vuser"                           A system user to setuid if you want
  -sg, --setgid="vgroup"                          A system user to setgid if you want
  -qq, --quiet                                    quiet mode, no any feedback

~
}

sub usage {
    if($opt{xml}){
        usage_xml;
    }else{
        usage_default;
    }
}

sub gen_domain_hashdir {
    my $self = shift;

    eval { require Ext::HashDir };
    die 'Need Ext::HashDir' if ($@);

    Ext::HashDir->import(qw(hashdir));

    return undef if ($c->{SYS_ISP_MODE} ne 'yes');

    my $domain_deep = $c->{SYS_DOMAIN_HASHDIR_DEPTH} || '2x1';
    my ($len, $size) = ($domain_deep =~ /^(\d+)x(\d+)$/);
    return hashdir($len, $size);
    '';
}

sub add {
    if( !$opt{domain} ){
        push @exp, { prompt => "Please input a domain name to add!", status=>0 };
        output ;
    }
    my $domainname = $opt{domain};
    my $description = $opt{domain};
    if( defined $opt{description} ){
	    $description = $opt{description};
    }

    my $hashdirpath = gen_domain_hashdir() || "";

    my $maxuser = $c->{SYS_DEFAULT_MAXUSERS};
    if(defined $opt{maxuser}){
	    $maxuser = $opt{maxuser};
    }
    my $maxalias = $c->{SYS_DEFAULT_MAXALIAS};
    if(defined $opt{maxalias}){
	    $maxalias = $opt{maxalias};
    }
    #maxquota,maxndquota,default_quota,default_ndquota
    my $maxquota = defined $opt{maxquota} ? $opt{maxquota} : $c->{SYS_DEFAULT_MAXQUOTA};
    $maxquota = $maxquota * 1024 * 1024;
    $maxquota = $maxquota."S";

    my $maxndquota = defined $opt{maxndquota} ? $opt{maxndquota} : $c->{SYS_DEFAULT_MAXNDQUOTA};
    $maxndquota = $maxndquota * 1024 * 1024;
    $maxndquota = $maxndquota."S";
    my $transport = "NULL";
    if(defined $opt{transport}){
	$transport = $opt{transport};
    }
    my $can_signup = 0;
    if(defined $opt{signup}){
	$can_signup = $opt{signup};
    }
    my $default_quota = defined $opt{accountquota} ? $opt{accountquota} : $c->{SYS_USER_DEFAULT_QUOTA};
    $default_quota = $default_quota * 1024 * 1024;
    $default_quota = $default_quota."S";

    my $default_ndquota = defined $opt{accountndquota} ? $opt{accountndquota} : $c->{SYS_USER_DEFAULT_NDQUOTA};
    $default_ndquota = $default_ndquota * 1024 * 1024;
    $default_ndquota = $default_ndquota."S";

    my $default_expire = defined $opt{accountlifetime} ? $opt{accountlifetime} : $c->{SYS_USER_DEFAULT_EXPIRE};

    my $createdate = strftime("%Y-%m-%d %H:%M:%S", localtime);
    my $expiredate = '0000-00-00'; # set to unlimited/auto
    my $service = defined $opt{accountservices} ? $opt{accountservices} : $c->{SYS_DEFAULT_SERVICES};

    my %services= (
	    pwdchange=>0,
	    smtpd=>1,
	    smtp=>1,
	    webmail=>1,
	    netdisk=>1,
	    imap=>1,
	    pop3=>1
	);
    my @sv = split(/,/,$service);
    foreach (@sv) {
	    if (exists $services{$_}){
	        $services{$_}=0;
	    }
    }
    my $active = defined $opt{active} ? $opt{active} : 0;

    if($mgr->get_domain_info($domainname)){
        push @exp, { prompt => "domain no exist!", status=>0 };
        output ;
    }else{
        push @exp, { prompt => "$domainname OK",
            status => 1
        };
        my $rc = $mgr->add_domain(
            domain => $domainname,
            description => $description,
            hashdirpath => $hashdirpath,
            maxusers => $maxuser,
            maxalias => $maxalias,
            maxquota => $maxquota,
            maxndquota => $maxndquota,
            transport => $transport,
    	    can_signup => $can_signup,
            default_quota => $default_quota,
            default_ndquota => $default_ndquota,
            default_expire => $default_expire,
            disablesmtpd => $services{smtpd},
            disablesmtp => $services{smtp},
            disablewebmail => $services{webmail},
            disablenetdisk => $services{netdisk},
            disablepop3 => $services{pop3},
            disableimap => $services{imap},
            expire => $expiredate,
            create => $createdate,
            active => $active,
        );
        output ;
    }
}

sub del {
    if($opt{domain}){
        if($mgr->get_domain_info($opt{domain})){
            if(!($mgr->delete_domain($opt{domain}))){
                push @exp, { prompt => "$opt{domain} Deleted", status => 1};
                output ;
            }else{
                push @exp, { prompt => "$opt{domain} Faild", status => 0};
                output ;
            }
        }else{
            push @exp, { prompt => "Domain no exist!", status=>0};
            output ;
        }
    }else{
        push @exp, { prompt => "Please input a domainname to delete!", status=>0 };
        output ;
    }
}

sub list {
    my $all = $mgr->get_domains_list || [];
    for(my $i=0; $i<scalar @$all; $i++) {
        my $e = $all->[$i];
        push @exp, {domain => $e->{domain},
            status => 1
        };
    }
    output ;
}

sub show {
    if(!$opt{domain}){
        push @exp, { prompt => "Please input a domain name!", status=>0 };
        output ;
    }

    if(my $minfo = $mgr->get_domain_info($opt{domain})){
        push @exp, { domain => $minfo->{domain},
            description => $minfo->{description},
            createdate => $minfo->{create},
            expiredate => $minfo->{expire},
            hashdirpath => $minfo->{hashdirpath},
            maxalias => $minfo->{maxalias},
            maxusers => $minfo->{maxusers},
            maxquota => $minfo->{maxquota},
            maxndquota => $minfo->{maxndquota},
            transport => $minfo->{transport},
            signup => $minfo->{can_signup},
            defaultquota => $minfo->{default_quota},
            defaultndquota => $minfo->{default_ndquota},
            defaultexpire => $minfo->{default_expire},
            disablesmtpd => $minfo->{disablesmtpd},
            disablesmtp => $minfo->{disablesmtp},
            disablewebmail => $minfo->{disablewebmail},
            disablenetdisk => $minfo->{disablenetdisk},
            disableimap => $minfo->{disableimap},
            disablepop3 => $minfo->{disablepop3},
            active => $minfo->{active},
            status => 1,
            prompt => "$minfo->{domain}'s profile"
        };
        output_show ;
    }else{
        push @exp, { prompt => "Domain no exists!" };
        output ;
    }
}

sub mod {
    if(!$opt{domain}){
        push @exp, { prompt => "Please input a domain name to modify!", status=>0 };
        output ;
    }
    my $domainname = $opt{domain};
    my $ul = $mgr->get_domain_info($domainname);
    if(!($ul)){
        push @exp, { prompt => "domain no exist!", status=>0 };
        output ;
    }
    if(scalar keys %opt <= 1){
        push @exp, { prompt => "Modify what?", status=>0 };
        output ;
    }
    my $description = defined $opt{description} ? $opt{description} : $ul->{description};
    my $maxuser = defined $opt{maxuser} ? $opt{maxuser} : $ul->{maxusers};
    my $maxalias = defined $opt{maxalias} ? $opt{maxalias} : $ul->{maxalias};
    my $maxquota = $ul->{maxquota};
    if(defined $opt{maxquota}){
        $maxquota = $opt{maxquota}*1024*1024;
        $maxquota = $maxquota."S";
    }
    my $maxndquota = $ul->{maxndquota};
    if(defined $opt{maxndquota}){
        $maxndquota = $opt{maxndquota}*1024*1024;
        $maxndquota = $maxndquota."S";
    }
    my $transport = $opt{transport} ? $opt{transport} : $ul->{transport};
    my $can_signup = defined $opt{signup} ? $opt{signup} : $ul->{can_signup};
    my $default_quota = defined $opt{accountquota} ? $opt{accountquota} : $ul->{default_quota};
    my $default_ndquota = defined $opt{accountndquota} ? $opt{accountndquota} : $ul->{default_ndquota};
    my $default_expire = defined $opt{accountlifetime} ? $opt{accountlifetime} : $ul->{default_expire};
    my $expiredate = $opt{expire} ? $opt{expire} : $ul->{expire};
    my %services = (
        'pwdchange' => 1,
        'smtpd' => 1,
        'smtp' => 1,
        'webmail' => 1,
        'netdisk' => 1,
        'pop3' => 1,
        'imap' => 1,
    );
    #enable services,
    if ($opt{accountservices}) {
        my @sve = split(/,/,$opt{accountservices});
        foreach(@sve){
            if (exists $services{$_}){
                $services{$_} = 0;
            }
        }
    }
    my $active = defined $opt{active} ? $opt{active} : $ul->{active};
    push @exp, { prompt => "$domainname Modified",
        status => 1
    };
    my $rc = $mgr->modify_domain(
        domain => $domainname,
        description => $description,
        maxusers => $maxuser,
        maxalias => $maxalias,
        maxquota => $maxquota,
        maxndquota => $maxndquota,
        transport => $transport,
        can_signup => $can_signup,
        default_quota => $default_quota,
        default_ndquota => $default_ndquota,
        default_expire => $default_expire,
        disablesmtpd => $services{smtpd},
        disablesmtp => $services{smtp},
        disablewebmail => $services{webmail},
        disablenetdisk => $services{netdisk},
        disablepop3 => $services{pop3},
        disableimap => $services{imap},
        expire => $expiredate,
        active => $active,
    );
    output ;
}

my $mode = $opt{mode} || $ARGV[0];
if($mode){
    switch ($mode){
        case "add" { add(); }
        case "del" { del(); }
        case "list" { list(); }
        case "show" { show(); }
        case "mod" { mod(); }
        case "help" { usage(); }
        else { usage(); }
    }
}else{
    usage ();
}

