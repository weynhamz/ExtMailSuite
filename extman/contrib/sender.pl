#!/usr/bin/perl -w
# created by chifeng<chifeng@gmail.com> 2007.02.10
#
# filename: sender.pl
#  version: 0.1
#
# ./sender.pl userlist template logfile
#
#
use Net::SMTP;
use IO::File;

print "\nUsage: $0 userlist template logfile \n" and exit(255) unless $#ARGV == 2;

my $relayhost="localhost";
my $mailfrom='no-relay@steelport.extmail.org';
my $heloname="localhost";
#------------------------------------------

my $file="$ARGV[0]";
my $filetemp="$ARGV[1]";
my $logfile="$ARGV[2]";
my $fp=IO::File ->new($file);
my $email;

my $timeout=60;
my $count=0;

while(<$fp>) {
    chomp;
    #@aline = split(/,/,$_);
    if( $_ =~ /\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*/ ) {
        $email = $_;
        #my $password = $aline[3];
        #my $sidnumber = $aline[0];
        #my $edmnumber = $aline[1];
        $smtp = Net::SMTP->new($relayhost,Hello => $heloname,Timeout=>$timeout);
        $smtp->mail($mailfrom);
        $smtp->to($email);
        $smtp->data();

        my $fptemp=IO::File->new($filetemp);
        while(<$fptemp>){
            $_ =~ s/EMAILADDRESS/$email/g;
            $_ =~ s/EMAILMAILFROM/$mailfrom/g;
            $smtp->datasend("$_");
        }
        $fptemp->close;

        $smtp->dataend();
        $smtp->quit;
        open(LOGFILE, ">>", $logfile) or die "Can't create logfile: $!" ;
        print LOGFILE $count." ".$email." Success!\n";
    }else{
        open(LOGFILE, ">>", $logfile) or die "Can't create logfile: $!" ;
        print LOGFILE $count." ".$email." Address NO match!\n";
    }
    $count++;
}
$fp->close;
