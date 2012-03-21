#!/bin/sh
exec ${PERL-perl} -Swx $0 ${1+"$@"}

#!/usr/bin/perl -w
#   userinfo.pl: alias management
#	 Author: chifeng <chifeng At gmail.com>
#	   Date: 2008-01-06 15:39:00
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
use CmdTools;
use Ext::DateTime qw(time2epoch epoch2time);
use Getopt::Long;
use Switch;
use IO::File;
require $DIR.'/tools/setid.pl';

my $VERSION = 'CMDTools-20091224';

my $ctx = CmdTools->new( config => $DIR . '/webman.cf', directory => $DIR );
my $c = \%Ext::Cfg;
my $mgr = $ctx->ctx; # backend object
my $basedir = $c->{SYS_MAILDIR_BASE};
my %opt = ();
my $set_user=$c->{SYS_DEFAULT_UID};
my $set_group=$c->{SYS_DEFAULT_GID};

Getopt::Long::Configure('no_ignore_case');
Getopt::Long::GetOptions(\%opt,
    'mode|m=s',
    'alias|u=s',
    'domain|d=s',
    'goto|g=s',
    'active|a=i',
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
        alias => "alias name",
        domain => "domain name",
        goto => "email address",
        active => "1 or 0",
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
usage: ./aliasctl.pl command [options] ...

Commands:

    add     -- add a alias
    del     -- delete a alias
    list    -- list all of users in a domain
    show    -- show profile of a alias
    mod     -- modify alias infomation
    help    -- display this help and exit

Options:

  -u, --alias="aliasname\@domain.tld"       A alias name
  -g, --goto="username\@domain.tld"         A email address
  -d, --domain="domain.tld"                Which domain?
  -a, --active=1                           Enable or disable (1 or 0)
  -su, --setuid="vuser"                    A system user to setuid if you want
  -sg, --setgid="vgroup"                   A system user to setgid if you want
  -qq, --quiet                             quiet mode, no any feedback
  -x, --xml                                xml format output

~
}

sub usage {
    if($opt{xml}){
        usage_xml;
    }else{
        usage_default;
    }
}

sub addalias {
    my $aliasname = $_[0];
    my ($alias,$domain) = split(/@/,$aliasname);
    my $goto = $_[1];
    my $createdate = strftime("%Y-%m-%d %H:%M:%S", localtime);

    my $rc = $mgr->add_alias(
        alias => "$alias\@$domain",
        domain => $domain,
        goto => $goto,
        active => defined $opt{active} ? $opt{active} : 1,
        create => $createdate,
    );
    if($rc){
        return 0;
    }else{
        return 1;
    }
}

sub add {
    if($opt{alias}){
        my $aliasname = $opt{alias};
        my $goto = $opt{goto};
        if(!($opt{goto})){
            push @exp, { prompt => "The goto can not empty!", status=>0 };
            output ;
        }
        if(my $rv = $mgr->get_alias_info($aliasname)){
            push @exp, { prompt => "$aliasname Exist", status=>0 };
            output ;
        }
        if(addalias $aliasname,$goto){
            push @exp, { prompt => "$aliasname OK",
                status => 1,
            };
            output ;
	    }else{
            push @exp, { prompt => "$aliasname Faild", status=>0 };
            output ;
	    }
    }else{
        push @exp, { prompt => "Please input a alias name!", status=>0 };
        output ;
    }
}

sub delalias {
    my $aliasname = $_[0];
    if($mgr->get_alias_info($aliasname)){
        if($mgr->delete_alias($aliasname)){
            push @exp, { prompt => "$aliasname Faild", status=>0 };
            output ;
        }else{
            push @exp, { prompt => "$aliasname Deleted", status=>0 };
            output ;
        }
    }else{
        push @exp, { prompt => "$aliasname no exist", status=>0 };
        output ;
    }
}

sub del {
    if($opt{alias}){
        delalias $opt{alias};
    }else{
        push @exp, { prompt => "Please input a alias address!", status=>0 };
        output ;
    }
}

sub list {
    if($opt{domain}){
        my $domain = $opt{domain};
        if(!($mgr->get_domain_info($domain))){
            push @exp, { prompt => "$domain no exists", status=>0 };
	        output ;
        }
        my $ul = $mgr->get_aliases_list($domain);
        foreach my $u (@$ul) {
            my $r = $u->{goto};
            my $goto = ref $r ? join(',', @$r) : $r;
            push @exp, { alias => $u->{alias},
                #goto => $goto,
                status => 1
            };
        }
        output ;
    }else{
        push @exp, { prompt => "Please input a domain name!", status=>0 };
        output ;
    }
}

sub show {
    my $dms = [];
    if($opt{alias}){
        if(my $ul = $mgr->get_alias_info($opt{alias})){
            my $r = $ul->{goto};
            my $goto = ref $r ? join(',', @$r) : $r;
            push @exp, { type => "alias",
                email => $ul->{alias},
                goto => $goto,
                domain => $ul->{domain},
                active => $ul->{active},
                prompt => "$ul->{alias}'s profile",
                status => 1,
            };
            output_show ;
        }else{
            push @exp, { prompt => "$opt{alias} no exist", status=>0 };
            output ;
        }
    }else{
        push @exp, { prompt => "Please input a aliasname!", status=>0 };
        output ;
    }
}

sub mod {
    if(!($opt{alias})){
        push @exp, { prompt => "Please input a alias name!", status=>0 };
        output ;
    }
    my $alias = $opt{alias};
    my $ul = $mgr->get_alias_info($alias);
    if(!$ul){
        push @exp, { prompt => "$alias not exists" };
        output ;
    }
    if(scalar keys %opt <= 1){
        push @exp, { prompt => "Modify what?", status=>0 };
        output ;
    }

    my $active = defined $opt{active} ? $opt{active} : $ul->{active};
    if($ul){
        print $ul->{goto};
        my $ogoto = ref $ul->{goto} ? @{$ul->{goto}} : $ul->{goto};
        my $goto = $opt{goto} ? $opt{goto} : $ogoto;
        push @exp, { prompt => "$alias Modified",
            status => 1,
        };
        $mgr->modify_alias(
            alias => $alias,
            goto => $goto,
            active => $active,
        );
        output ;
    }
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
