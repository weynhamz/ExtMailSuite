# vim: set ci et ts=4 sw=4:
# HOW TO run set_uid() set_gid()
#
# step 1 - perl script header
# ---------------------------
# #!/bin/sh
# exec ${PERL-perl} -Swx $0 ${1+"$@"}
# #!/usr/bin/perl
#
# step 2 - call set_gid()
# ---------------------------
#
# step 3 - call set_uid()
# ---------------------------
#
# Caution: call set_gid() first, then set_uid()!

sub numberp { defined $_[0] && $_[0] =~ m/^-?\d+$/o; }

sub group2gid {
    my $g = shift;
    return $g if numberp ($g);
    my $gid = getgrnam ($g);
    return $gid if defined $gid && numberp ($gid);
    die "no such group: $g";
}

sub user2uid {
    my $u = shift;
    return $u if numberp ($u);
    my $uid = getpwnam ($u);
    return $uid if defined $uid && numberp ($uid);
    die "no such user: $u";
}

sub set_gid {
    my $sgid = group2gid (shift);
    my $rgid = $( + 0;
    my $egid = $) + 0;

    if ($^O ne 'aix') {
        $( = $sgid;
        die "cannot set rgid $sgid: $!\n" if ($( == $rgid && $rgid != $sgid);
    }
    $) = $sgid;
    die "cannot set egid $sgid: $!\n" if ($) == $egid && $egid != $sgid);
}

sub set_uid {
    my $suid = user2uid (shift);
    my $ruid = $<;
    my $euid = $>;

    if ($^O ne 'aix') {
        $< = $suid;
        die "cannot set ruid $suid: $!\n" if ($< == $ruid && $ruid != $suid);
    }
    $> = $suid;
    die "cannot set euid $suid: $!\n" if ($> == $euid && $euid != $suid);
}

1;

__END__

=head1 NAME

setid.pl - a small script to do setuid() and setgid() C API

=head1 Usage

#!/bin/sh
exec ${PERL-perl} -Swx $0 ${1+"$@"}

#!/usr/bin/perl -w

require 'setid.pl';

set_gid('vgroup');
set_uid('vuser');

sleep;

=head1 COPYRIGHT

He zhiqiang <hzqbbc@hzqbbc.com>

code merge from Noah Friedman <friedman@splode.com> 's suid-with
