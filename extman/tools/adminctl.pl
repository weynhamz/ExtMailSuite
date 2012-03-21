#!/bin/sh
exec ${PERL-perl} -Swx $0 ${1+"$@"}

#!/usr/bin/perl -w
#   adminctl.pl: admin user management
#	 Author: chifeng <chifeng At gmail.com>
#	   Date: 2007-11-28 15:39:00
#  Homepage: http://www.extmail.org
#	Version: 20091224
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
use Ext::Utils qw(untaint);
use CmdTools;
use Ext::DateTime qw(time2epoch epoch2time);
use Getopt::Long;
use Switch;
use IO::File;
use Data::Dumper;
require $DIR.'/tools/setid.pl';

my $VERSION = 'CMDTools-20091224';

my $ctx = CmdTools->new( config => $DIR . '/webman.cf', directory => $DIR );
my $c = \%Ext::Cfg;
my $mgr = $ctx->ctx; # backend object
my $basedir = $c->{SYS_MAILDIR_BASE};
my %opt = ();
my @exp; # export parameters
my $set_user=$c->{SYS_DEFAULT_UID};
my $set_group=$c->{SYS_DEFAULT_GID};

Getopt::Long::Configure('no_ignore_case');
Getopt::Long::GetOptions(\%opt,
	'mode|m=s',
	'file|f=s',
	'username|u=s',
	'password|p=s',
	'changepwd|c=i',
	'name|n=s',
	'active|a=i',
	'expire|e=s',
	'question|Q=s',
	'answer|A=s',
	'adddomains|ad=s',
	'deldomains|dd=s',
	'domains|d=s',
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
    push @exp, { mode => "add,badd,del,bdel,list,show,mod,help",
        file => "/path/to/filename.csv",
        username => "user name",
        password => "user password",
        name => "common name",
        question => "what are you doing?",
        answer => "working",
        expire => "2012-12-31",
        active => "1 or 0",
        setgid => "vgroup",
        setuid => "vuser",
        domains => "domain.tld,domain1.tld,...",
        adddomains => "domain.tld,domain1.tld,...",
        deldomains => "domain.tld,domain1.tld,...",
        quiet => "",
        xml => "",
        status => 0,
        prompt => "help info"
    };
    output ;
}

sub usage_default {
    return if($opt{quiet});
    print qq~
usage: ./adminctl.pl command [options] ...

Commands:

    add     -- add a admin
    badd    -- batch add admins
    del     -- delete a admin
    bdel    -- batch delete admins
    list    -- list all of admins
    show    -- show profile of a admin
    mod     -- modify admin infomation
    help    -- display this help and exit

Options:

  -u, --username="admin"                          A admin name
  -p, --password="******"                         Admin password
  -f, --file="/path/to/filename.csv"              A CSV file path, Just for batch add users, one user one line
                                                  eg: username password domain.tld,domain2.tld,...
  -n, --name="name"                               common name
  -Q, --question="what are you doing?"            Question?
  -A, --answer="play games"                       Answer
  -e, --expire="2009-09-17"                       Expire date
  -a, --active=1                                  Enable or disable (1 or 0)
  -su, --setuid="vuser"                           A system user to setuid if you want
  -sg, --setgid="vgroup"                          A system user to setgid if you want
  -d, --domains="domain.tld,domain2.tld,..."      Ignore any domains before value,Just set these domains to this admin
  -ad, --adddomains="domain.tld,domain2.tld,..."  Append these domains to this admin
  -dd, --deldomains="domain.tld,domain2.tld,..."  Delete these domains from current value of this admin
  -qq, --quiet                                    quiet mode, no any feedback
  -x, --xml                                       xml format output

~
}

sub usage {
    if($opt{xml}){
        usage_xml;
    }else{
        usage_default;
    }
}

sub adduser {
    my $username = $_[0];
    my $password = $_[1];
    my $domains = $_[2];

    my $uid = $username;
    if($opt{name}){
        $uid = $opt{name};
    }

    if($mgr->get_manager_info($username)){
        push @exp, { prompt => "$username exist!", status => 0 };
        output ;
    }else{
        my @dms = split(/,/,$domains);
        foreach my $d (@dms){
            if(!($mgr->get_domain_info($d))){
                push @exp, { prompt => "$d domain no exist!", status=>0 };
                output ;
            }
        }
        my $createdate = strftime("%Y-%m-%d %H:%M:%S", localtime);
        my $expiredate = '0000-00-00'; # default to unlimited/auto

        $domains =~ s#,# #g;
        my $rc = $mgr->add_manager(
            manager => $username,
            cn => $uid,
            expire => $expiredate,
            create => strftime("%Y-%m-%d %H:%M:%S", localtime),
            active => $opt{active} ? $opt{active} : 0,
            domain => $domains,
            question => $opt{question} ? $opt{question} : '',
            answer => $opt{answer} ? $opt{answer} : '',
            disablepwdchange => $opt{changepwd} ? $opt{changepwd} : 0,
            type => 'postmaster',
            passwd => $password,
        );
        if($rc){
            return 0;
        }else{
            return 1;
        }
    }
}

sub add {
    if(!($opt{username} && $opt{password})){
        push @exp, { prompt => "Please input username,password at least!", status=>0 };
        output ;
    }else{
        my $username = $opt{username};
        my $password = $opt{password};
        my $domains = $opt{domains} || "";
        my $rv = adduser $username,$password,$domains;
        if ($rv == 1){
            push @exp, { prompt => "$username OK",
                status => 1
            };
            output ;
        }else{
            push @exp, { prompt => "$username add faild!", status => 0 };
            output ;
        }
    }
}

sub badd {
    if($opt{file}){
        if( -e $opt{file} ){
            my @info;
            my @rv;
            open(BAF, "< $opt{file}")
                or die "Can't open $opt{file} !\n";
            while(<BAF>){
                chomp;
                @info = split(/ /, untaint($_));
                my $rv = adduser $info[0],$info[1],$info[2];
                if($rv == 1){
                    push @exp, { prompt => "$info[0] OK", status => 1 };
                }else{
                    push @exp, { prompt => "$info[0] Faild", status => 0 };
                }
            }
            close BAF;
            output ;
        }else{
            push @exp, { prompt => "$opt{file} file no exist!", status=>0 };
            output ;
        }
    }else{
        push @exp, { prompt => "Please input a text file", status=>0 };
        output ;
    }
}

sub deluser {
    my $username = $_[0];
    if($mgr->get_manager_info($username)){
        if(!($mgr->delete_manager($username))){
            push @exp, { prompt => "$username Deleted", status => 1 };
        }else{
            push @exp, { prompt => "$username Faild", status => 0 };
        }
    }else{
        push @exp, { prompt => "$username no exist!", status=>0 };
        output ;
    }
}

sub del {
    if($opt{username}){
        deluser $opt{username};
    }else{
        push @exp, { prompt => "Please input a username to delete!", status=>0 };
    }
    output ;
}

sub bdel {
    if($opt{file}){
        if( -e $opt{file} ){
            open(BDF, "< $opt{file}")
                or die "Can't open $opt{file} !\n";
            while(<BDF>){
                chomp $_;
                deluser $_;
            }
            close BDF;
            output ;
        }else{
            push @exp, { prompt => "$opt{file} file no exist!", status=>0 };
            output ;
        }
    }else{
        push @exp, { prompt => "Please input a text file!", status=>0 };
        output ;
    }
}


sub list {
    my $all = $mgr->get_managers_list || [];
    for(my $i=0; $i<scalar @$all; $i++) {
        my $e = $all->[$i];
        push @exp, { username => $e->{manager}};
    }
    output ;
}

sub show {
    my $dms = [];
    if($opt{username}){
        if(my $minfo = $mgr->get_manager_info($opt{username})){
            if($minfo->{type} eq 'admin'){
                push @$dms,'ALL Domains';
            }else{
                $dms = $minfo->{domain};
            }
            my $d;
            foreach my $rv (@$dms){
                $d = $d."$rv ";
            }
            push @exp, { type => $minfo->{type},
                username => $minfo->{manager},
                name => $minfo->{cn},
                active => $minfo->{active},
                disablepwdchange => $minfo->{disablepwdchange},
                question => $minfo->{question},
                answer => $minfo->{answer},
                createdate => $minfo->{create},
                expiredate => $minfo->{expire},
                domains => $d,
                status => 1,
                prompt => "$minfo->{manager}'s profile",
            };
            output_show ;
        }else{
            push @exp, { prompt => "$opt{username} no exist!", status=>0 };
            output ;
        }
    }else{
        push @exp, { prompt => "Please input a admin name to show!", status=>0 };
        output ;
    }
}

sub mod {
    if(!($opt{username})){
        push @exp, { prompt => "Please input a username!", status=>0 };
        output ;
    }
    my $manager = $opt{username};
    my $rv = $mgr->get_manager_info($manager);
    if(!$rv) {
        push @exp, { prompt => "$manager no exist!", status=>0 };
        output ;
    }
    if(scalar keys %opt <= 1){
        push @exp, { prompt => "Modify what?", status=>0 };
        output ;
    }
    my $name = $opt{name} ? $opt{name} : $rv->{cn};
    my $changepwd = defined $opt{changepwd} ? $opt{changepwd} : $rv->{disablepwdchange};
    my $active = defined $opt{active} ? $opt{active} : $rv->{active};
    my @ttime = split(/ /,$rv->{expire});
    my $time = $ttime[1];
    my $expire = defined $opt{expire} ? $opt{expire}." ".$time : $rv->{expire};
    my $question = defined $opt{question} ? $opt{question} : $rv->{question};
    my $answer = defined $opt{answer} ? $opt{answer} : $rv->{answer};
    my $password = defined $opt{password} ? $opt{password} : undef;
    my $alldomains = $rv->{domain};
    if($opt{adddomains}){
        my @idomains = split(/,/,$opt{adddomains});
        foreach my $idm (@idomains){
            if(!$mgr->get_domain_info($idm)){
                push @exp, { prompt => "$idm domain no exist!", status=>0 };
                output ;
            }
        }
        push @$alldomains,@idomains;
    }
    if($opt{deldomains}){
        my @rdomains = split(/,/,$opt{deldomains});
        my $i = 0;
        foreach my $domain (@rdomains){
            for (;$i < scalar @$alldomains ; $i++){
                last if (@$alldomains[$i] eq $domain);
            }
            splice(@$alldomains,$i,1);
            $i=0;
        }
    }
    if($opt{domains}){
        my @setdomains = split(/,/,$opt{domains});
        foreach my $setdm (@setdomains){
            if(!$mgr->get_domain_info($setdm)){
                push @exp, { prompt => "$setdm domain no exist!", status=>0 };
                output ;
            }
        }
        @$alldomains = @setdomains ;
    }
    my %hash = ();
    my @alldomains2;
    foreach my $member (@$alldomains){
        $hash{$member} = 1;
    }
    foreach (keys %hash){
        push (@alldomains2,$_);
    }
    my $adomains = join(" ",@alldomains2);
    push @exp, { prompt => "$manager Modified!",
        status => 1,
    };
    push @exp, { password => $password, } if($password);
    $mgr->modify_manager(
        manager => $manager,
        cn => $name,
        expire => $expire,
        active => $active,
        domain => $adomains,
        question => $question,
        answer => $answer,
        disablepwdchange => $changepwd,
        passwd => $password,
    );
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

