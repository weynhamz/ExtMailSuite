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
package Ext::MailFilter;

use strict;
use Exporter;
use Fcntl qw(:flock);
use Ext::Storage::Maildir;

use vars qw(@ISA $VERSION);
@ISA = qw(Exporter);
$VERSION = '1.2';

sub new {
    my $class = shift;
    my %opt = @_;

    my $self = {
        file => $opt{file} ? $opt{file} : $ENV{HOME}.'/.mailfilter',
        lock => $opt{lock} ? 1:0
    };

    bless $self, $class;

    $self->parse; # XXX auto
    $self;
}

# XXX new design:
#
# will rename $self->{filter} to $self->{rules}
#
# $rules ----> HASH ref element
#              |---> header,value,folder,from,name,options
#
# $whitelist ---> { on => yes/not, path => $path }
# $blacklist ---> { on => yes/not, path => $path }
# $spam2junk ---> { on => yes/not }
# $mail2sms  ---> { on => yes/not }
# $autoreply ---> { on => yes/not }
# $forward   ---> { on => yes/not, addr => $addr }
#
# Priority: whitelist > blacklist > forward > rules > spam2junk > mail2sms
sub parse {
    my $self = shift;
    my $file = $self->{file};
    my $new = 1;
    my $ref = ();
    my @rules;

    # extension
    my $whitelist = {};
    my $blacklist = {};
    my $spam2junk = 0;
    my $mail2sms = 0;
    my $autoreply = 0;
    my $forward = 0;

    # ignore opening file error, set the $self->{rules} to empty ARRAY
    # ref, or perl will complain, :-)
    open(FD, "< $file") or $self->{rules} = [] and return;
    while(<FD>) {
        chomp;
        my $line = $_;

        # extension parsing
        if (substr($line, 0, 2) eq '#*') {
            my $res = substr($line, 2);
            if ($res eq 'whitelist') {
                $whitelist = { on => 1, path => 'whitelist.cf'};
                $self->{whitelist} = $whitelist;
            } elsif ($res eq 'blacklist') {
                $blacklist = { on => 1, path => 'blacklist.cf'};
                $self->{blacklist} = $blacklist;
            } elsif ($res eq 'spam2junk') {
                $spam2junk = 1;
                $self->{spam2junk} = $spam2junk;
            } elsif ($res eq 'mail2sms') {
               $mail2sms = 1;
               $self->{mail2sms} = $mail2sms;
            } elsif ($res eq 'autoreply') {
                $autoreply = 1;
                $self->{autoreply} = $autoreply;
            } elsif ($res =~ /^forward: (.*)/) {
                # forward: user@domain.tld
                $forward = 1;
                $self->{forward} = $1; # the forward addr
            } elsif ($res eq 'forwardcc') {
                $self->{forwardcc} = 1;
            }
        }

        # format to design V2
        # example:
        #
        # README
        # ---------
        # v2 remove contain and Notcontain facility, maildrop
        # can not support full body search, we enhance the
        # subject/from/to searching
        #
        # ##Name:test rule
        # ##From:hzqbbc@hzqbbc.com
        # ##Folder:!foo@bar.com
        # ##Folder:.Junk
        # ##Delete
        # ##Continue
        # ##Recipient:bbc@aaa.com
        # ##Subject:Hello
        #
        # /^From:(.*)/
        # FROM=`$DECODER $MATCH1`
        # /^To:(.*)/
        # TO=`$DECODER $MATCH1`
        # /^Subject:(.*)/
        # SUBJECT=`$DECODER $MATCH1`
        #
        # if (($FROM =~/.*hzqbbc\@hzqbbc\.com.*/) ||
        #     ($TO =~/.*bbc\@aaa\.com.*/) ||
        #     ($SUBJECT =~/Hello/D))
        # {
        #     cc "foo@bar.com"
        #     EXITCODE=0
        #     exit
        #     to "$HOME/.Junk/."
        # }
        #
        # format to design V1
        # example:
        #
        # ##Name:test rule
        # ##From:hzqbbc@hzqbbc.com
        # ##Folder:!foo@bar.com
        # ##Folder:.Junk
        # ##Delete
        # ##Continue
        # ##Recipient:bbc@aaa.com
        # ##Notcontains:haha
        # ##Contains:xixi
        #
        # if ((/^From: .*hzqbbc\@hzqbbc\.com.*/) ||
        #     (/^To: .*bbc\@aaa\.com.*/) ||
        #     (/xixi/:b) ||
        #     (!/haha/:b))
        # {
        #     cc "foo@bar.com"
        #     EXITCODE=0
        #     exit
        #     to "$HOME/.Junk/."
        # }
        if (!$new) {
            if (substr($line, 0, 2) eq '##') {
                my $res = substr($line, 2, 5);
                if ($res eq 'Recip') {
                    $ref->{recipient} = substr($line, 12);
                } elsif ($res eq 'Folde') {
                    my $val = substr($line, 9);
                    next unless $val;
                    if ($ref->{folder}) {
                        push @{$ref->{folder}}, $val;
                    } else {
                        $ref->{folder} = [$val];
                    }
                } elsif ($res eq 'From:') {
                    $ref->{from} = substr($line, 7);
                } elsif ($res eq 'Subje') {
                    $ref->{subject} = substr($line, 10);
                } else {
                    next if ($line =~ /:/);
                    $ref->{options} .= substr($line, 2).' ';
                }
            } else {
                if($ref->{options}) {
                    $ref->{options} =~ s/\s+$//;
                }
                push @rules, $ref;
                $new = 1;
                $ref = ();
            }
        }

        if ($new && substr($line, 0, 6) eq '##Name') {
            $new = 0;
            $ref->{name} = substr($line, 7);
        }
    }
    close FD;
    $self->{rules} = \@rules; # save the ref
}

sub save {
    my $self = shift;
    my $file = $self->{file};
    my $rr = $self->{rules};
    my @rules = @$rr;
    my $buf1 = '';
    my $buf  = '';
    my $username = $ENV{USERNAME};
    my $maildir = $ENV{HOME};
    my $autoreply = "if ((!/^X-Loop:.*\$FROM/) && !\$BADSENDER)\n";

    my %need_decode = ();

    # advoid coding too long
    $autoreply .="{\n";
    $autoreply .="    cc \"| mailbot -A 'X-Loop: \$FROM' -A 'X-Sender: \$FROM' -A 'From: \$FROM' \\\n";
    $autoreply .= "        -m '\$HOME/Maildir/autoreply.cf' -d '\$HOME/Maildir/autoreply.db' \$SENDMAIL -t -f ''\"\n";
    $autoreply .="}";

    $buf1 .= "#MFMAILDROP=2\n";
    $buf1 .= "#\n";
    $buf1 .= "# DO NOT EDIT THIS FILE.  This is an automatically generated filter.\n";
    $buf1 .= "# Generated by ExtMail $VERSION\n\n";

    $buf1 .= "FROM='$username'\n";
    $buf1 .= "import SENDER\n";
    $buf1 .= "if (\$SENDER eq \"\")\n";
    $buf1 .= "{\n";
    $buf1 .= " SENDER=\$FROM\n";
    $buf1 .= "}\n\n";

    if ($self->{whitelist}) {
        $buf1 .= "#*whitelist\n";
        $buf1 .= "foreach /^(Return-path|From): .*/\n";
        $buf1 .= "{\n";
        $buf1 .= "  if (lookup( getaddr(\$MATCH), \"\$HOME/Maildir/whitelist.cf\" ))\n";
        $buf1 .= "  {\n";
        if ($self->{autoreply}) {
            # must append the autoreply code, or the 'to' operator will
            # terminate the deliver process and ignore autoreply code
            # following the whitelist!
            $buf1 .= "$autoreply\n";
        }
        if ($self->{forward}) {
            # must append the forwarding code, or the 'to' operator will
            # terminate the deliver process and ignore forwarding code
            # behide the whitelist:)
            $buf1 .="if ((!/X-Loop:.*\$FROM/) && !\$BADSENDER)\n";
            $buf1 .="{\n";
            $buf1 .= "    ".($self->{forwardcc}?'cc':'to').
                    " \"| reformail -a 'X-Loop: \$FROM' |\$SENDMAIL -f \" '\"\$SENDER\"' \" $self->{forward}\"\n";
            $buf1 .="}\n";
        }
        $buf1 .= "    to \"\$HOME/Maildir/.\"\n";
        $buf1 .= "  }\n";
        $buf1 .= "}\n\n";
    }

    if ($self->{blacklist}) {
        $buf1 .= "#*blacklist\n";
        $buf1 .= "foreach /^(Return-path|From): .*/\n";
        $buf1 .= "{\n";
        $buf1 .= "  if (lookup( getaddr(\$MATCH), \"\$HOME/Maildir/blacklist.cf\" ))\n";
        $buf1 .= "  {\n";
        $buf1 .= "    EXITCODE=0\n";
        $buf1 .= "    exit\n"; # XXX discard
        $buf1 .= "  }\n";
        $buf1 .= "}\n\n";
    }

    if ($self->{autoreply}) {
        $buf1 .= "#*autoreply\n";
        $buf1 .= "$autoreply\n\n";
    }

    if ($self->{forward}) {
        my $dist = 'to';
        $buf1 .= "#*forward: $self->{forward}\n";
        if ($self->{forwardcc}) {
            $buf1 .= "#*forwardcc\n";
            $dist = 'cc';
        }
        $buf1 .= "if ((!/^X-Loop:.*\$FROM/) && !\$BADSENDER)\n";
        $buf1 .= "{\n";
        $buf1 .= "    $dist \"| reformail -a 'X-Loop: \$FROM' | \$SENDMAIL -f \" '\"\$SENDER\"' \" $self->{forward}\"\n";
        $buf1 .= "}\n";
    }

    for (my $i=0; $i <scalar @rules; $i++) {
        my $rule = $rules[$i];
        my $dist = 'to';
        my $delete = 0;
        my $hasattach = 0;
        my $folder = $rule->{folder};
        my @statements;

        $buf .= "##Name:$rule->{name}\n";
        $buf .= "##From:$rule->{from}\n";
        $buf .= "##Recipient:$rule->{recipient}\n";
        $buf .= "##Subject:$rule->{subject}\n";

        if ($folder) {
            $buf .= "##Folder:$_\n" for (@$folder);
        } else {
            $buf .= "##Folder:\n";
        }

        if ($rule->{options}) {
            for my $o (split(/ /, $rule->{options})) {
                $buf .= "##$o\n";
                if ($o eq 'Continue') {
                    $dist = 'cc';
                } elsif ($o eq 'Delete') {
                    $delete = 1;
                } elsif ($o eq 'Hasattach') {
                    $hasattach = 1;
                }
            }
        }

        $buf .= "\n";
        $buf .= "if (";

        if ($rule->{from}) {
            $need_decode{from} = 1;
            push @statements, "(\$FROM=~/.*".slashes($rule->{from}).".*/)";
        }
        if ($rule->{recipient}) {
            $need_decode{recipient} = 1;
            push @statements, "(\$TO=~/.*".slashes($rule->{recipient}).".*/)";
        }
        if ($rule->{subject}) {
            $need_decode{subject} = 1;
            push @statements, "(\$SUBJECT=~/.*".slashes($rule->{subject}).".*/)";
        }
        if ($hasattach) {
            push @statements, "(/^Content-Type: *multipart\\/mixed/)";
        }

        $buf .= join(" || \\\n", @statements);
        $buf .= ")\n";
        $buf .= "{\n";

        if ($folder) {
            my $hasfolder = '';
            my $hasforward = '';
            my $hasbounce = '';
            my $hasdelete = '';
            my $hasautoreply = '';

            for my $dir (@$folder) {
                # * reject with message
                # ! forward
                # + autoreply
                my $flag = substr($dir,0,1); # generate the flag
                if ($flag eq '!') {
                    $hasforward = "\"| reformail -a 'X-LOOP: \$FROM'| \$SENDMAIL -f \" '\"\$SENDER\"' \" ".substr($dir,1)."\"\n";
                    # $buf .= "  ".$dist." \"| \$SENDMAIL -f \" '\"\$SENDER\"' \" ".substr($dir,1)."\"\n";
                } elsif ($flag eq "*") {
                    # reject code
                    $hasbounce .= "  echo \"".substr($dir, 1)."\"\n";
                    $hasbounce .= "  EXITCODE=77\n";
                    $hasbounce .= "  exit\n";
                } elsif ($flag eq '.') {
                    # $buf .= "  ".$dist." \"\$HOME/Maildir/";
                    $hasfolder .= "\"\$HOME/Maildir/";
                    if ($dir eq '.') {
                        # The Inbox (.) so only prepend the dot(.)
                        $hasfolder .= ".\"\n";
                    } else {
                        $hasfolder .= "$dir/.\"\n";
                    }
                } elsif ($dir eq 'exit' || $delete) {
                    $hasdelete .= "  EXITCODE=0\n";
                    $hasdelete .= "  exit\n";
                }
            }

            # assemble main excution rules in order
            if ($hasfolder) {
                $buf .= "  ".($hasforward || $hasbounce ? 'cc':'to');
                $buf .= " $hasfolder";
            }
            if ($hasforward) {
                $buf .= "  if ((!/^X-Loop:.*\$FROM/) && !\$BADSENDER)\n";
                $buf .= "  {\n";
                $buf .= "    ".($hasbounce ? 'cc':'to');
                $buf .= " $hasforward";
                $buf .= "  }\n";
            }
            if ($hasbounce) {
                $buf .= $hasbounce;
            }
            if ($hasdelete) {
                $buf .= ($hasbounce?'': $hasdelete);
            }
        }

        $buf .= "}\n\n";
    }
    # XXX the end of loop

    if ($self->{spam2junk}) {
        $buf .= "#*spam2junk\n";
        $buf .= "if (/^X-Spam-Flag:.*YES/ || /^X-DSPAM-Result:.*Spam/)\n";
        $buf .= "{\n";
        $buf .= "  to \"\$HOME/Maildir/.Junk/.\"\n";
        $buf .= "}\n\n";
    }

    if ($self->{mail2sms}) {
        $buf .= "#*mail2sms\n";
        $buf .= "cc \"| \$MAIL2SMS \\\"\$FROM\\\"\"\n";
        $buf .= "\n";
    }

    $buf .= "to \"\$HOME/Maildir/.\"\n";

    eval {
        open(FD, "> $file.tmp") or die "Can't write to $file.tmp, $!\n";
        flock(FD, LOCK_EX);
        print FD $buf1;
        print FD "#\n";
        print FD "# EXTERNAL DECODER. Useful for key word filtering\n";
        print FD "#\n";
        if ($need_decode{from}) {
            print FD "/^(From|Sender):(.*)/\n";
            print FD "FROM=`\$DECODER \"\$MATCH2\"`\n";
        }
        if ($need_decode{recipient}) {
            print FD "/^(To|Cc):(.*)/\n";
            print FD "TO=`\$DECODER \"\$MATCH2\"`\n";
        }
        if ($need_decode{subject}) {
            print FD "/^Subject:(.*)/\n";
            print FD "SUBJECT=`\$DECODER \"\$MATCH1\"`\n";
        }
        print FD "\n";
        print FD $buf;
        flock(FD, LOCK_UN);
        close FD;
        rename("$file.tmp", $file) or die "Rename err, $!\n";
    };

    if ($@) {
        return $@;
    } else {
        return 0;
    }
}

sub slashes {
    $_ = shift;
    s/ /\\ /g;
    s/-/\\-/g;
    s/_/\\_/g;
    s/\+/\\+/g;
    s/:/\\:/g;
    s/'/\\'/g;
    s/>/\\>/g;
    s/\//\\\//g;
    s/\./\\./g;
    s/@/\\@/g;
    s/\[/\\[/g;
    s/]/\\]/g;
    s/</\\</g;
    return $_;
}

sub rules_up {
    my $self = shift;
    my $rules = $self->{rules};
    my $id = $_[0];

    return 1 if ($id <= 0 || $id >scalar @$rules -1);

    my $tmp_ref = ();
    $tmp_ref = $rules->[$id-1];
    $rules->[$id-1] = $rules->[$id];
    $rules->[$id] = $tmp_ref;
    $self->{rules} = $rules;
    0; # success
}

sub rules_down {
    my $self = shift;
    my $rules = $self->{rules};
    my $id = $_[0];

    return 1 if ($id<0 || $id>=scalar @$rules -1);

    my $tmp_ref = ();
    $tmp_ref = $rules->[$id+1];
    $rules->[$id+1] = $rules->[$id];
    $rules->[$id] = $tmp_ref;
    $self->{rules} = $rules;
    0;
}

sub rules_remove {
    my $self = shift;
    my $rules = $self->{rules};
    my $id = $_[0];

    return 1 if($id<0 || $id>scalar @$rules -1);

    my $new_rules = []; # ARRAY ref
    for (my $i=$id; $i< scalar @$rules-1;$i++) {
        $rules->[$i]=$rules->[$i+1];
    }
    pop @$rules;
    $self->{rules} = $rules;
}

sub rules_append {
    my $self = shift;
    my $rules = $self->{rules};
    my $ref = $_[0];

    push @$rules, $ref;
}

sub save_list {
    my $self = shift;
    my $type = $_[0];
    my $list = $_[1]; # must ARRAY ref

    die "Malformed input data!\n" unless (ref $list eq 'ARRAY');

    if ($type eq 'blacklist') {
        open (FD, "> blacklist.cf.tmp") or die "Can't write to $type.cf.tmp\n";
        flock (FD, LOCK_EX);
        for (@$list) {
            print FD lc $_, "\n";
        }
        flock (FD, LOCK_UN);
        close FD;
        rename ('blacklist.cf.tmp', 'blacklist.cf') or return $!;
    } elsif ($type eq 'whitelist') {
        open (FD, "> whitelist.cf.tmp") or die "Can't write to $type.cf.tmp\n";
        flock (FD, LOCK_EX);
        for (@$list) {
            print FD lc $_, "\n";
        }
        flock (FD, LOCK_UN);
        close FD;
        rename ('whitelist.cf.tmp', 'whitelist.cf') or return $!;
    } else {
        return "$type not support yet!\n";
    }
    return 0;
}

sub read_list {
    my $self = shift;
    my $type = $_[0];

    unless ($type =~ /^(black|white)list$/) {
        die "$type not support yet!\n";
    }

    open (FD, "< $type.cf") or return []; # ignore error
    my @arr;
    while(<FD>) {
        chomp;
        s/^\s*//g;
        s/\s*$//g;
        push @arr, lc $_;
    }
    close FD;
    return \@arr;
}

sub read_autoreply {
    my $self = shift;
    my $buf = '';
    my $crlf = $/;

    open (FD, "< autoreply.cf") or return $buf; # ignore error
    local $/ = "\n\n";
    <FD>; # strip the header
    local $/ = undef;
    $buf = <FD>;
    close FD;

    return $buf;
}

sub remove_member {
    my $self = shift;
    my $list = shift; # ARRAY ref
    my $addr = lc shift;

    return unless $list;

    my @nlist;
    for (@$list) {
        next if $_ eq $addr;
        push @nlist, $_;
    }

    \@nlist;
}

sub save_autoreply {
    my $self = shift;
    my $buf = $_[0];

    open (FD, "> autoreply.cf") or return "Error: $!\n";
    flock (FD, LOCK_EX);
    print FD $buf;
    flock (FD, LOCK_UN);
    close FD;
    return 0;
}

# XXX this func is useful
sub dir_inrule {
    my $self = shift;
    my $dir = $_[0];
    my $rules = $self->{rules};

    return 0 unless(valid_dirname($dir));
    $dir = _name2mdir($dir);

    foreach my $ref (@$rules) {
        if ($ref->{folder}) {
            for (@{$ref->{folder}}) {
                return $ref->{name} || '1'
                    if ($_ eq $dir);
            }
        }
    }
    0;
}

1;
