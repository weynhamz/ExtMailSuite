# vim: set ci et ts=4 sw=4:
# CmdTools.pm: An experimental perl module to provide unified API
#              to access extman functions.
#
#      Author: He zhiqiang <hzqbbc@hzqbbc.com>
# Last Update: Tue Nov 20 2007 20:26:03
#     Version: 0.1

package CmdTools;

use Ext; # read config file
use Ext::Mgr;
use Exporter;
use Ext::Utils qw(lock unlock haslock);

@ISA = qw( Ext );

sub ctx {
    shift->{mgr};
}

sub init {
    my $self = shift;

    my $c = \%Ext::Cfg;
    my $backend = $c->{SYS_BACKEND_TYPE};
    my $mgr; # the backend object

    if ($backend eq 'mysql') {
        $mgr = Ext::Mgr->new(
            type => 'mysql',
            host => $c->{SYS_MYSQL_HOST},
            socket => $c->{SYS_MYSQL_SOCKET},
            dbname => $c->{SYS_MYSQL_DB},
            dbuser => $c->{SYS_MYSQL_USER},
            dbpw => $c->{SYS_MYSQL_PASS},
            table => $c->{SYS_MYSQL_TABLE},
            table_attr_username => $c->{SYS_MYSQL_ATTR_USERNAME},
            table_attr_passwd => $c->{SYS_MYSQL_ATTR_PASSWD},
            crypt_type => $c->{SYS_CRYPT_TYPE},
            psize => $c->{SYS_PSIZE} || 10,
        );
    } elsif ($backend eq 'ldap') {
        $mgr = Ext::Mgr->new(
            type => 'ldap',
            host => $c->{SYS_LDAP_HOST},
            base => $c->{SYS_LDAP_BASE},
            rootdn => $c->{SYS_LDAP_RDN},
            rootpw => $c->{SYS_LDAP_PASS},
            ldif_attr_username => $c->{SYS_LDAP_ATTR_USERNAME},
            ldif_attr_passwd => $c->{SYS_LDAP_ATTR_PASSWD},
            crypt_type => $c->{SYS_CRYPT_TYPE},
            psize => $c->{SYS_PSIZE} || 10,
            bind => 1
        );
    } else {
        die "$backend unknow!\n";
    }

    $self->{mgr} = $mgr;
}

sub _lock {
    my $self = shift;
    open (my $fh, "< $0") or die "Error: $!\n";
    if (haslock($fh)) {
        warn "There is another process working, abort\n";
        exit (255);
    } else {
        $self->{fh} = $fh;
        lock ($fh);
    }
}

sub _unlock {
    unlock($_[0]->{fh}) if defined $_[0]->{fh};
}

sub DESTORY {
    $_[0]->unlock if defined $_[0]->{fh};
}

1;
