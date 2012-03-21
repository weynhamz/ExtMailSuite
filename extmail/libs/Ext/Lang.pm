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
package Ext::Lang;
use strict;

use Ext;
use Exporter;
use Ext::Utils qw(untaint);

use vars qw(@ISA @EXPORT $LANG);
@ISA = qw(Exporter);
@EXPORT = qw(initlang langlist guess_intl intl2euc curlang charset_detect);

use vars qw(%http2intl %intl2euc);
%http2intl = (
    'en' => 'en_US',
    'ja' => 'ja',
    'ko' => 'ko',
    'zh' => 'zh_CN',
    'zh-sg' => 'zh_CN',
    'zh-tw' => 'zh_TW',
    'zh-hk' => 'zh_TW',
);

%intl2euc = (
    'en_US' => 'iso-8859-1',
    'ja' => 'euc-jp',
    'ko' => 'euc-kr',
    'zh' => 'GB2312',
    'zh_CN' => 'GB2312',
    'zh_TW' => 'BIG5',
);

# initlang($locale)
sub initlang {
    my ($lang,$pkg) = @_;
    $pkg = $pkg|| 'main'; # default to main::
    if (!$lang) { $lang = guess_intl() }

    $LANG = $lang; # ouch :-(

    if (-r (my $file = $Ext::Cfg{SYS_LANGDIR}."/$lang")) {
        eval {
            loadlang($pkg, $file);
        };
        warn "Error on load $lang, $@" if($@);
    } else {
        # load default en_US locale
        loadlang($pkg, $Ext::Cfg{SYS_LANGDIR}."/en_US");
    }
}

sub loadlang {
    my ($newpkg, $lang, @symlist)=@_;

    require $lang;
    # lang pack type for certain application
    my $LangPackName = $Ext::Cfg{SYS_APP_TYPE};

    if($lang=~m{/}) {
        $lang =~s#.*/([^\/]+)$#$1#; # strip path info
    }

    my $langpkg = ($LangPackName || 'Ext::Lang') .'::'.$lang;

    no strict 'refs';
    @symlist=keys %{$langpkg.'::'} if ($#symlist<0);
    foreach my $sym (@symlist) {
        # alias symbo of sub routine into current package
        *{$newpkg.'::'.$sym}=*{$langpkg.'::'.$sym};
    }
}

sub guess_intl {
    my @lang;
    foreach ( split(/[,;\s]+/, lc($ENV{'HTTP_ACCEPT_LANGUAGE'})) ) {
        push(@lang, $_) if (/^[a-z\-_]+$/);
        push(@lang, $1) if (/^([a-z]+)\-[a-z]+$/ ); # eg: zh-tw -> zh
    }
    foreach my $lang (@lang) {
        return $http2intl{$lang} if (defined($http2intl{$lang}));
    }
    return('en_US');
}

sub intl2euc {
    my $lang = shift;
    return unless $lang;

    if ($intl2euc{$lang}) {
        return $intl2euc{$lang};
    }
}

sub langlist {
    my $regexp = '^\s*\$lang_description\s*=\s*(\'|")([^\'"]+)(\'|")\s*';
    my $lang_dir = $Ext::Cfg{SYS_LANGDIR};
    my @pref_lang;

    opendir(DIR, $lang_dir) or die "Can't opendir $lang_dir, $!\n";
    my @locales = grep { !/^\./ } readdir DIR;
    close DIR;

    for my $f (@locales) {
        open(FD, "< $lang_dir/$f"); # ignore error;
        while(<FD>) {
            push @pref_lang, {lang=>$f, desc=>$2}
            and last if(/$regexp/);
        }
        close FD;
    }
    \@pref_lang;
}

# getlang - user land function, not available here, go to App level
sub curlang {
    return $LANG || 'en_US';
}

# XXX FIXME the core charset detect function - experimantal
sub charset_detect {
    my ($buf, $len) = @_;
    my $char;

    $buf = substr($buf, 0, $len) if ($len);

    # stage 1, load module
    eval {
        # this module seems to be more acuccury than Encode::Detect
        require Encode::PPDetector;
        $char = Encode::PPDetector::detect($buf);
    };

    eval {
        # this module is an XS perl module, faster
        require Encode::Detect::Detector;
        $char = Encode::Detect::Detector::detect($buf);
    } if ($@);

    # stage 2, return default unless detect success
    return 'iso-8859-1' unless ($char);

    # lower case it
    $char = lc $char;

    # stage 3, fix charset name
    if ($char =~ /^shift[-\_]*jis$/) {
        $char = 'shift-jis';
    } elsif ($char eq 'gb18030') {
        $char = 'cp936';
    } elsif ($char =~ /^utf-*8$/) {
        $char = 'utf-8';
    }
    return $char;
}

1;
