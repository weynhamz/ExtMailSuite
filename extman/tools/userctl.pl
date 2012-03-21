#!/bin/sh
exec ${PERL-perl} -Swx $0 ${1+"$@"}

#!/usr/bin/perl -w
# vim: set ci et ts=4 sw=4:
#   userinfo.pl: user managerment
#	     Author: chifeng <chifeng At gmail.com>
#	       Date: 2008-01-02 17:49:00
#   Last update: 2009-12-24 16:37:00
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
use Ext::Utils qw(untaint expire_calc);
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
my $basedir = $c->{SYS_MAILDIR_BASE};
my $dir = $c->{SYS_CONFIG};
my $set_user=$c->{SYS_DEFAULT_UID};
my $set_group=$c->{SYS_DEFAULT_GID};

Getopt::Long::Configure('no_ignore_case');
Getopt::Long::GetOptions(\%opt,
    'mode|m=s',
    'file|f=s',
    'username|u=s',
    'domain|d=s',
    'password|p=s',
    'name|n=s',
    'question|Q=s',
    'answer|A=s',
    'uid|i=i',
    'uidnumber|U=i',
    'gidnumber|G=i',
    'expire|e=s',
    'quota|q=s',
    'ndquota|N=s',
    'active|a=i',
    'services|S=s',
    'mailhost|H=s',
    'setuid|su=s',
    'setgid|sg=s',
    'nomaildir|no=s',
    'delmaildir|D=s',
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
    if($opt{xml}){
        output_xml;
    }
    return if($opt{quiet});
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

# Using: output
# output function will print %exp hash variable

sub output {
    if($opt{xml}){
        output_xml;
    }else{
        output_default;
    }
}

sub usage_xml {
    push @exp, { mode => "add,badd,del,bdel,list,show,mod,help",
        file => "/path/to/filename.csv",
        name => "name",
        question => "what are you doing?",
        answer => "working",
        gid => "gid",
        uid => "uid",
        expire => "2012-12-31",
        quota => 100,
        ndquota => 100,
        active => "1 or 0",
        services => "smtp,smtpd,pop3,imap,webmail,netdisk,pwdchange",
        setgid => "vgroup",
        setuid => "vuser",
        nomaildir => "1 or 0",
        delmaildir => "1 or 0",
        quiet => "1 or 0",
        status => 0,
        prompt => "help info"
    };
    output ;
}

sub usage_default {
    return if($opt{quiet});
    print qq~
usage: ./userctl.pl command [options] ...

Commands:

    add     -- add a user
    badd    -- batch add users
    del     -- delete a user
    bdel    -- batch delete users
    list    -- list all of users in a domain
    show    -- show profile of a user
    mod     -- modify user infomation
    help    -- display this help and exit

Options:

  -u, --username="username\@domain.tld"            A username as email address
  -p, --password="******"                         User password
  -f, --file="/path/to/filename.csv"              A CSV file path, Just for batch add users, one user one line
                                                      username@domain.tld password
  -d, --domain="domain.tld"                       A domain name
  -n, --name="name"                               common name
  -i, --uid="uid"                                 uid
  -Q, --question="what are you doing?"            Question?
  -A, --answer="play games"                       Answer
  -U, --uidnumber="1000"                          User ID number
  -G, --gidnumber="1000"                          Group ID number
  -e, --expire="2012-12-31"                       Expire date
  -q, --quota=100                                 Mail box quota
  -N, --ndquota=100                               Network disk quota
  -a, --active=1                                  Enable or disable (1 or 0)
  -S, --services="smtp,smtpd,pop3,webmail"        Enable services (smtp,smtpd,pop3,imap,webmail,netdisk,pwdchange)
  -su, --setuid="vuser"                           A system user to setuid if you want
  -sg, --setgid="vgroup"                          A system user to setgid if you want
  -H, --mailhost="mailhost"                       Mailhost is useful if you use ISP mode
  -no, --nomaildir=1                              Do you want create users maildir
  -D, --delmaildir=0                              Do you want keep users maildir
  -qq, --quiet                                    quiet mode, no any feedback
  -x, --xml                                       output XML format data

~
}

sub usage {
    if($opt{xml}){
        usage_xml;
    }else{
        usage_default;
    }
}

sub gen_user_hashdir {
    my $self = shift;

    eval { require Ext::HashDir };
    die 'Need Ext::HashDir' if ($@);

    Ext::HashDir->import(qw(hashdir));
    return undef if ($c->{SYS_ISP_MODE} ne 'yes');

    my $user_deep = $c->{SYS_USER_HASHDIR_DEPTH} || '2x1';
    my ($len, $size) = ($user_deep =~ /^(\d+)x(\d+)$/);

    return hashdir($len, $size);
    '';
}

sub adduser {
    my $email = $_[0];
    my $password = $_[1];
    my ($user,$domain) = split(/@/,$email);

    my $dinfo = $mgr->get_domain_info($domain);
    if(!$dinfo){
        push @exp, { prompt => "$domain No exist" , status => 0};
        output ;
    }

    my $uidnumber = defined $opt{uidnumber} ? $opt{uidnumber} : $c->{SYS_DEFAULT_UID};
    my $gidnumber = defined $opt{gidnumber} ? $opt{gidnumber} : $c->{SYS_DEFAULT_GID};

    my $createdate = strftime("%Y-%m-%d %H:%M:%S", localtime);
    my $expiredate = "0000-00-00";

    #my $epochtime = time2epoch($createdate);
    #my $offset_time = expire_calc($dinfo->{default_expire});
    #die "$offset_time";
    #my $expiretime = $epochtime + $offset_time;
    #my $expiredate = strftime("%Y-%m-%d", localtime $expiretime);
    #die "$dinfo->{default_expire}  $offset_time $expiretime $expiredate";

    my $question = defined $opt{question} ? $opt{question} : "";
    my $answer = defined $opt{answer} ? $opt{answer} : "";
    my $name = defined $opt{name} ? $opt{name} : $user;
    my $mailhost = defined $opt{mailhost} ? $opt{mailhost} : "";

    my $quota = defined $opt{quota} ? num2quota($opt{quota}) : $dinfo->{default_quota};
    my $ndquota = defined $opt{ndquota} ? num2quota($opt{ndquota}) : $dinfo->{default_ndquota};

    if($opt{services}){
        my $service = $opt{services};
        my %disable= (
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
            if (exists $disable{$_}){
                $disable{$_}=0;
            }
        }
    }

    my $d_hashdir = $dinfo->{hashdirpath};
    my $u_hashdir = gen_user_hashdir;
    my $path;
    if ($c->{SYS_ISP_MODE} eq 'yes') {
        $path = ($d_hashdir ? "$d_hashdir/" : "").
        "$domain/" .($u_hashdir? "$u_hashdir/" : "").
        $user;
    } else {
        $path = "$domain/$user";
    }

    my $ul = $mgr->get_user_info($email);
    my $ula = $mgr->get_alias_info($email);
    if($ul || $ula){
        push @exp, { prompt => "$email Exist" , status => 0};
        output ;
    }else{
        my $rv = $mgr->add_user(
        mail => "$user\@$domain",
        domain => $domain,
        uid => $opt{uid} || $user,
        cn => $name || "",
        uidnumber => $uidnumber || 1000,
        gidnumber => $gidnumber || 1000,
        create => $createdate,
        expire => $expiredate,
        passwd => $password,
        quota => $quota,
        question => $question || "",
        answer => $answer || "",
        mailhost => $mailhost || "",
        maildir => "$path/Maildir/",
        homedir => $path,
        netdiskquota => $ndquota,
        active => 1,
        disablepwdchange => $disable{pwdchange} || 0,
        disablesmtpd => $disable{smtpd} || $dinfo->{disablesmtpd},
        disablesmtp => $disable{smtp} || $dinfo->{disablesmtp},
        disablewebmail => $disable{webmail} || $dinfo->{disablewebmail},
        disablenetdisk => $disable{netdisk} || $dinfo->{disablenetdisk},
        disablepop3 => $disable{pop3} || $dinfo->{disablepop3},
        disableimap => $disable{imap} || $dinfo->{disableimap}
        );

        if(!$opt{nomaildir}){
            system("$dir/tools/maildirmake.pl $basedir/$path/Maildir/");
        }
        if($rv){
            return 0;
        }else{
            push @exp, { status => 1,
                prompt => "$email OK"
            };
            return 1;
        }
    }
}

sub add {
    if($opt{username}){
	    my $email = $opt{username};
	    my $password = $opt{password};

        if(!($password)) {
            push @exp, { prompt => "Password can not empty!", status => 0 };
            output ;
        }

        if(! (adduser $email,$password)){
            push @exp, { prompt => "Add username faild!" , status => 0 };
        }
    }else{
        push @exp, { prompt => "Please input username for add!", status => 0};
    }
    output ;
}

sub badd {
    if(!$opt{file}){
        push @exp, { prompt => "Please input a text file!" , status => 0};
        output ;
    }
	if( -e $opt{file} ){
        my @info;
        my $rv;
        open(BAF,"< $opt{file}")
            or die "Can't open $opt{file} !\n";
        while(<BAF>){
            chomp;
            @info = split(/ /, untaint($_));
            $rv = adduser $info[0],$info[1];
        }
        close BAF;
    }else{
        push @exp, { prompt => "File no exist!" , status => 0};
    }
    output ;
}

sub deluser {
    my $username = $_[0];
    my $delmaildir = 0;
    if(defined $opt{delmaildir} and ($opt{delmaildir} != 0)){
        $delmaildir = 1;
    }else{
        $delmaildir = 0;
    }
    if(my $rv = $mgr->get_user_info($username)){
        if($mgr->delete_user($username)){
            push @exp, { prompt => "$username Faild", status => 0 };
        }else{
            push @exp, { prompt => "$username Deleted", status => 1 };
            if($delmaildir != 0){
                system("/bin/rm -fr \"$c->{SYS_MAILDIR_BASE}/$rv->{homedir}\"");
            }
        }
    }else{
        push @exp, { prompt => "Username no exist!" , status => 0};
    }
}

sub del {
    if($opt{username}){
	    deluser $opt{username};
    }else{
        push @exp, { prompt => "Please input a email address to delete!", status => 0};
    }
    output ;
}

sub bdel {
    if(!$opt{file}){
        push @exp, { prompt => "Please input a text file!" , status => 0};
        output ;
    }
    if( -e $opt{file} ){
        open(BDF, "< $opt{file}")
            or die "Can't open $opt{file} !\n";
        while(<BDF>){
            chomp $_;
            deluser untaint($_);
        }
        close BDF;
    }else{
        push @exp, { prompt => "File no exist!" , status => 0};
    }
    output ;
}

sub list {
    if(!$opt{domain}){
        push @exp, { prompt => "Please input a domain name!", status => 0};
        output ;
    }
    my $domain = $opt{domain};
    if(!($mgr->get_domain_info($domain))){
        push @exp, { prompt => "domain no exists!" , status => 0};
        output ;
    }
    my $ul = $mgr->get_users_list($domain);
    foreach my $u (@$ul) {
        push @exp, { email => $u->{mail}, status => 1 };
    }
    output ;
}

sub show {
    my $dms = [];
    if(!$opt{username}) {
        push @exp, { prompt => "Please input a username to show!" , status => 0};
        output ;
    }

    if( my $ul = $mgr->get_user_info($opt{username})){
        push @exp, { type => "user",
                    username => $ul->{mail},
                    name => $ul->{cn},
                    password => $ul->{passwd},
                    uidnumber => $ul->{uidnumber},
                    gidnumber => $ul->{gidnumber},
                    quota => $ul->{quota},
                    question => $ul->{question},
                    answer => $ul->{answer},
                    ndquota => $ul->{netdiskquota},
                    active => $ul->{active},
                    status => 1 ,
                    prompt => "$ul->{mail}'s profile" ,
                    maildir => "$basedir\/$ul->{maildir}",
                    homedir => "$basedir\/$ul->{homedir}",
                    mailhost => $ul->{mailhost},
                    createdate => $ul->{create},
                    expire => $ul->{expire},
                    disablepwdchange => $ul->{disablepwdchange},
                    disablesmtpd => $ul->{disablesmtpd},
                    disablesmtp => $ul->{disablesmtp},
                    disablewebmail => $ul->{disablewebmail},
                    disablenetdisk => $ul->{disablenetdisk},
                    disablepop3 => $ul->{disablepop3},
                    disableimap => $ul->{disableimap}
        };
        output_show ;
    }else{
        push @exp, { prompt => "User no exist!", status => 0 };
        output ;
    }
}

sub num2quota {
    # sys_quota_type, valid type: vda|courier
    #SYS_QUOTA_TYPE = courier
    my $quota = $_[0]; # must be number
    $quota = $quota * 1024 * 1024;
    my $type = $c->{SYS_QUOTA_TYPE} || 'vda';
    if ($type eq 'vda') {
	return $quota ? $quota : '0';
    } else {
	return $quota."S";
    }
}

sub quota2num {
    my $self = shift;
    my $quota = $_[0];
    $quota =~ s/S$//i;
    return $quota;
}

sub mod {
    if(!$opt{username}){
        push @exp, { prompt => "Please input a username for modify!", status => 0 };
        output ;
    }
    my $email = $opt{username};
    my ($user,$domain) = split(/\@/,$email);
    my $password = $opt{password};
    my $quota = $opt{quota};
    my $ndquota = $opt{ndquota};
    my $expiredate = $opt{expire};
    my $ul = $mgr->get_user_info($email);

    if(!$ul){
        push @exp, { prompt => "$email not exist!" ,status => 0 };
        output ;
    }
    if(scalar keys %opt <= 1){
        push @exp, { prompt => "Modify what?", status=>0 };
        output ;
    }

    my $active = (defined $opt{active} ? $opt{active} : $ul->{active});
    my $name = (defined $opt{name} ? $opt{name} : $ul->{cn});
    my $question = defined $opt{question} ? $opt{question} : $ul->{question};
    my $answer = defined $opt{answer} ? $opt{answer} : $ul->{answer};

    #smtp,smtpd,pop3,imap,webmail,netdisk,pwdchange
    #PRIORITY: 1:disable, 2:enable
    my %services = (
     	'pwdchange' => $ul->{disablepwdchange},
		'smtpd' => $ul->{disablesmtpd},
		'smtp' => $ul->{disablesmtp},
		'webmail' => $ul->{disablewebmail},
		'netdisk' => $ul->{disablenetdisk},
		'pop3' => $ul->{disablepop3},
		'imap' => $ul->{disableimap}
	);
    #enable services,
    if ($opt{services}) {
        #smtp,smtpd,pop3,imap,webmail,netdisk,pwdchange
        #PRIORITY: 1:disable, 2:enable
        %services = (
            'pwdchange' => 1,
            'smtpd' => 1,
            'smtp' => 1,
            'webmail' => 1,
            'netdisk' => 1,
            'pop3' => 1,
            'imap' => 1
        );
        my @sve = split(/,/,$opt{services});
        foreach(@sve){
            if (exists $services{$_}){
                $services{$_} = 0;
            }
        }
    }

    if($ul){
        my $uidnumber = $ul->{uidnumber};
        my $gidnumber = $ul->{gidnumber};
        my @ttime = split(/ /,$ul->{expire});
        my $time = $ttime[1];
        $expiredate = $expiredate ? $expiredate." ".$time : $ul->{expire};
        $quota = $quota ? num2quota $quota : $ul->{quota};
        $password = $password ? $password : undef;
        my $netdiskquota = $ndquota ? num2quota $ndquota : $ul->{netdiskquota};
        push @exp, { status => 1,
                prompt => "$email Modified!"
        };
        my $href = $exp[0];
        $href->{password} = $password if($password);

        my $rc = $mgr->modify_user(
            user => "$user\@$domain",
            domain => $domain,
            cn => $name,
            uidnumber => $uidnumber,
            gidnumber => $gidnumber,
            expire => $expiredate,
            passwd => $password,
            quota => $quota,
            question => $question,
            answer => $answer,
            netdiskquota => $netdiskquota,
            active => $active,
            disablepwdchange => $services{pwdchange},
            disablesmtpd => $services{smtpd},
            disablesmtp => $services{smtp},
            disablewebmail => $services{webmail},
            disablenetdisk => $services{netdisk},
            disablepop3 => $services{pop3},
            disableimap => $services{imap},
        );
        if($rc){
            $href->{status} = 0;
        }else{
            $href->{status} = 1;
        }
    }
    output ;
}

my $mode = $opt{mode} || $ARGV[0];
if($mode){
    switch ($mode){
	case "add" { add(); }
	case "badd" { badd(); }
	case "del" { del(); }
	case "bdel" { bdel(); }
	case "list" { list(); }
	case "show" { show(); }
	case "mod" { mod(); }
	case "help" { usage(); }
	else { usage(); }
    }
}else{
    usage ();
}
