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
package Ext::Passwd;
use strict;
use Exporter;
use MIME::Base64;

use vars qw(@ISA @EXPORT @SCHEMES);
@ISA = qw(Exporter);
@SCHEMES = qw(CRYPT CLEARTEXT PLAIN MD5 MD5CRYPT PLAIN-MD5 LDAP-MD5 SHA SHA1);
@EXPORT = qw(@SCHEMES);

sub new {
    my $this = shift;
    my $self = bless {@_}, ref $this || $this;
    $self->init(@_);
}

sub init {
    my $self = shift;
    my %opt = @_;
    my $default = uc $opt{fallback_scheme};

    die "$default not suuport!" unless grep {m/^$default$/} @SCHEMES;

    $self->{_fallback_scheme} = $default;
    $self;
}

sub get_passwd_scheme {
    my $self = shift;
    my $passwd = shift;

    die "Password null or invalid!" unless $passwd;

    # cleanup first
    delete $self->{_passwd};
    delete $self->{_scheme};

    if (substr($passwd, 0, 3) eq '$1$') {
        $self->{_passwd} = $passwd;
        $self->{_scheme} = 'MD5';
        return 'MD5';
    } elsif (substr($passwd, 0, 1) eq '{') {
        my $pos = index($passwd, '}');
        my $scheme;

        die "Password format invalid!" unless $pos>0;
        $scheme = uc substr($passwd, 1, $pos-1);
        $passwd = substr($passwd, $pos+1); # strip out {xx}

        if (!grep {m/^$scheme$/} @SCHEMES) {
            die "$scheme password not support!";
        }
        if ($scheme eq 'MD5') {
            # to distinguish between md5crypt and ldap-md5
            $scheme = 'LDAP-MD5';
        } elsif ($scheme eq 'CRYPT') {
            # to distinguish between crypt and md5crypt
            if (substr($passwd, 0, 3) eq '$1$') {
                $scheme = 'MD5';
            } else {
                $scheme = 'CRYPT';
            }
        }
        $self->{_passwd} = $passwd;
        $self->{_scheme} = $scheme;
        return $scheme;
    } else {
        # fallback to default password scheme
        $self->{_passwd} = $passwd;
        $self->{_scheme} = $self->{_fallback_scheme};
        return uc $self->{_fallback_scheme};
    }
}

# the top api for encrypt a password, api:
# $self->encrypt($type, $password)
sub encrypt {
    my $self = shift;
    my $type = uc shift;

    if ($type eq 'CRYPT') {
        return encrypt_crypt($_[0]);
    } elsif ($type eq 'CLEARTEXT') {
        return encrypt_clear($_[0]);
    } elsif ($type eq 'PLAIN') {
        return encrypt_clear($_[0]);
    } elsif ($type eq 'MD5') {
        return encrypt_md5($_[0]);
    } elsif ($type eq 'MD5CRYPT') {
        return encrypt_md5($_[0]);
    } elsif ($type eq 'PLAIN-MD5') {
        return encrypt_plain_md5($_[0]);
    } elsif ($type eq 'LDAP-MD5') {
        return encrypt_ldap_md5($_[0]);
    } elsif ($type eq 'SHA') {
        return encrypt_sha($_[0]);
    } elsif($type eq 'SHA1') {
        return encrypt_sha($_[0]);
    }
    die "unsupport password type: $type";
}

# verify ($pass, $raw_pwd_data)
#
# $pass         user input plain password
# $raw_pwd_data encrypted password in database
sub verify {
    my $self = shift;
    my $pass = shift;
    my $raw_pwd_data = shift;
    my $type = $self->get_passwd_scheme($raw_pwd_data);
    my $passwd = $self->{_passwd}; # maby be same as
                                   # $raw_pwd_data

    if ($type eq 'CRYPT') {
        return verify_crypt($pass, $passwd);
    } elsif ($type eq 'CLEARTEXT') {
        return verify_clear($pass, $passwd);
    } elsif ($type eq 'PLAIN') {
        return verify_clear($pass, $passwd);
    } elsif ($type eq 'MD5') {
        return verify_md5($pass, $passwd);
    } elsif ($type eq 'MD5CRYPT') {
        return verify_md5($pass, $passwd);
    } elsif ($type eq 'PLAIN-MD5') {
        return verify_plain_md5($pass, $passwd);
    } elsif ($type eq 'LDAP-MD5') {
        return verify_ldap_md5($pass, $passwd);
    } elsif ($type eq 'SHA') {
        return verify_sha($pass, $passwd);
    } elsif ($type eq 'SHA1') {
        return verify_sha($pass, $passwd);
    }
    die "unsupport password type: $type";
}

sub encrypt_crypt {
    my $pwd = $_[0];
    my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    return crypt($pwd, $salt);
}

sub verify_crypt {
    return (crypt($_[0], $_[1]) eq $_[1] ? 1 : 0);
}

sub encrypt_clear {
    return shift;
}

sub verify_clear {
    return ($_[0] eq $_[1] ? 1 : 0);
}

sub encrypt_md5 {
    eval { require Crypt::PasswdMD5 };
    if ($@) {
        return 'Crypt::PasswdMD5 not found!';
    } else {
        Crypt::PasswdMD5->import(qw(unix_md5_crypt));
        return unix_md5_crypt(shift);
    }
}

sub verify_md5 {
    eval { require Crypt::PasswdMD5 };
    if ($@) {
        die 'Crypt::PasswdMD5 not found!';
    } else {
        # prepend $1$ if the raw passwd data missing it
        if (substr($_[1], 0, 3) ne '$1$') {
            $_[1] = '$1$'.$_[1];
        }
        Crypt::PasswdMD5->import(qw(unix_md5_crypt));
        return (unix_md5_crypt($_[0], $_[1]) eq $_[1] ? 1 : 0);
    }
}

sub encrypt_plain_md5 {
    eval { require Digest::MD5 };
    if ($@) {
        return 'Digest::MD5 could not found!';
    } else {
        Digest::MD5->import(qw(md5_hex));
        return md5_hex(shift);
    }
}

sub verify_plain_md5 {
    eval { require Digest::MD5 };
    if ($@) {
        die 'Digest::MD5 not found!';
    } else {
        Digest::MD5->import(qw(md5_hex));
        return (md5_hex($_[0]) eq $_[1] ? 1 : 0);
    }
}

sub encrypt_ldap_md5 {
    eval { require Digest::MD5 };
    if ($@) {
        return 'Digest::MD5 could not found!';
    } else {
        Digest::MD5->import(qw(md5));
        return '{MD5}'.mybase64_encode(md5(shift));
    }
}

sub verify_ldap_md5 {
    eval { require Digest::MD5 };
    if ($@) {
        die 'Digest::MD5 not found!';
    } else {
        Digest::MD5->import(qw(md5));
        return (mybase64_encode(md5($_[0])) eq $_[1] ? 1 : 0 );
    }
}

sub encrypt_sha {
    eval { require Digest::SHA1 };
    if ($@) {
        return 'Digest::SHA1 could not found!';
    } else {
        Digest::SHA1->import(qw(sha1_base64));
        # bug fix, add redundant '=' to compatible with base64 standard
        return '{SHA}'.sha1_base64(shift).'=';
    }
}

sub verify_sha {
    eval { require Digest::SHA1 };
    if ($@) {
        die 'Digest::SHA1 not found1';
    } else {
        Digest::SHA1->import(qw(sha1_base64));
        return (sha1_base64($_[0]).'=' eq $_[1] ? 1 : 0);
    }
}

sub mybase64_encode {
    my $str = shift;
    $str = encode_base64($str);
    chomp $str;
    return $str;
}

sub DESTORY {
}

1;

__END__

Authentication and password scheme defination. reference from Dovecot-auth
, Courier-authlib and LDAP RFC2307.

Ext::Passwd currently support the following password scheme mapping:

CRYPT     => crypt
MD5       => md5
PLAIN-MD5 => plain_md5
LDAP-MD5  => ldap_md5
SHA       => sha
SHA1      => sha
CLEARTEXT => clear
PLAIN     => clear

The way to identify password scheme:

$1$hhhhhh$xxxxxxxxxxx => md5 crypted, hhh is hash, xxxx is raw data
{xxxx}yyyyyyyyyyyyyyy => xxxx is scheme, yyy is data (base64 encoded)
xxxxxxxxxxxxxxxxxxxxx => no scheme, raw data, need to specify type!
