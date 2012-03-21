# vim: set cindent expandtab ts=4 sw=4:
# APF::Color - output strings with color to console or tty
#              backport to perl module for APF Server
#
# Copyright: 1998-2004 (c) He zhiqiang <hzqbbc@hzqbbc.com>
#            1998-2006 (c) He zhiqiang <hzqbbc@hzqbbc.com>
#
# Date: 2004-03-07
# Update: 2006-04-12
package APF::Color;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);

@EXPORT = qw(nc darkc);
@EXPORT_OK = qw(_cio);

sub nc {
    my $str = shift;
    my $type = lc shift;

    return _cio(0, $type) . $str . _cio(0, 'white');
}

sub darkc {
    my $str = shift;
    my $type = lc shift;

    return _cio(1, $type) . $str . _cio(0, 'white');
}

sub _cio {
    my $dark = shift || 0;
    my $type = shift;

    return "\033[$dark;39m" if !$type;

    return "\033[$dark;31m" if $type eq 'red';
    return "\033[$dark;32m" if $type eq 'green';
    return "\033[$dark;33m" if $type eq 'yellow';
    return "\033[$dark;34m" if $type eq 'blue';
    return "\033[$dark;35m" if $type eq 'purple';
    return "\033[$dark;36m" if $type eq 'camblue';
    return "\033[$dark;37m" if $type eq 'white';

    # fallback
    return "\033[$dark;39m";
}

1;
