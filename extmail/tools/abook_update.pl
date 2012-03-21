#!/usr/bin/perl
# vim: set ci et ts=4 sw=4:
#
# abook_update.pl - a stupid script to convert old abook format
#                   (before 1.0.4) to new rich format (1.0.4+)
#
# Author: He zhiqiang <hzqbbc@hzqbbc.com>
#   Date: 20:49:00 2008-03-16
#    VER: 0.1
#
# $Id$

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

use Ext::CSV;
use Ext::Abook; # import @Head
my $csv = Ext::CSV->new;
my $count = 0;
my @ABOOK;
my %map = ('0' => '0', '1' => '1', '10' => '3', '16' => '2');

die "$0 /path/to/abook.cf\n" unless (-r $ARGV[0]);

open(FD, "< $ARGV[0]") or die $!;
while (<FD>) {
	chomp;
	if ($csv->parse($_)) {
		my @field = $csv->fields;
        my @nfield = ();
        if ($count == 0) {
            $ABOOK[$count] = \@Ext::Abook::Head; # new head
        } else {
            for (my $k=0; $k<scalar @Ext::Abook::Head;$k++) {
                if ($k =~ m/^(0|1|10|16)$/) {
                    $nfield[$k] = $field[$map{$k}];
                } else {
                    $nfield[$k] = '';
                }
            }
            $ABOOK[$count] = \@nfield;
        }
        $count ++;
    }else {
        warn $csv->error_input;
    }
}
close FD;

open(FD, "> ".$ARGV[0].".new") or die $!;
foreach(my $k=0; $k< scalar @ABOOK; $k++) {
    my $val = $ABOOK[$k];
    $val = $csv->combine(@$val);
    $val = $csv->string($val);
    print FD $val,"\n";
}
close FD;

unlink $ARGV[0];
rename ($ARGV[0].'.new', $ARGV[0]);

warn "Convertion done! But you must set file permission yourself! Or\n";
warn "you can not modify them correctly! :-)\n";
