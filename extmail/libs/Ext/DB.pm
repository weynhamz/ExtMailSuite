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
package Ext::DB;
use strict;

sub new {
    my $class = shift;
    my %opt = @_;

    my $self = {
        try1null    => $opt{try1null},
        use_flock    => ($opt{no_flock} ? 0 : 1)
        # XXX see INTERNAL_LOCK in include/sys_defs.h
    };
    bless $self, $class;

    return $self->tie(@_) if defined $opt{file}; # file path
    $self;
}

sub tie {
    my ($self, %opt) = @_;

    if ($opt{file} !~ /^(\w+):(.+)$/) {
        $self->{error} = "Cannot parse database name $opt{file}";
        return undef;
    }
    my $dbtype = $1;
    $opt{file} = $2; # this is trick

    $self = "Ext::DB::$dbtype"->new(%opt);
    if(!$self) {
        $self->{error} = "Database format $dbtype not implemented";
        return undef;
    }
    $self;
}

# perfomance tips: under high concurrency application, flocking is
# a must to advoid race condition, but it will hurt the performance,
# the current implemention does use_flock checking every time calling
# flock(), this is much more expensive!
#
# Under PIII450, 50,000 times calling insert(), without flock invokes
# in insert(), which simpliy comment it, use only 4-5 wall seconds.
#
# If we uncomment the flock() calling, time will raise up to 8 seconds!
# So please wait for better implemention :-)
#
# He zhiqiang (Chi-Keung Ho) <hzqbbc@hzqbbc.com>
sub flock {
    my ($self, $flags) = @_;

    return if not $self->{handle};

    if ($self->{use_flock}) {
        flock($self->{handle}, $flags) or die "flock: $!";
    } else {
        return ; # should log: "No locking implemented!\n";
    }
}

sub error {
    my ($self) = @_;
    return $self->{error};
}

package Ext::DB::DB_File;
use vars qw(@ISA);
@ISA = qw(Ext::DB);

use DB_File; # db-1.8.x
use Fcntl ':flock';
use Symbol;

sub new {
    my ($class, %opt) = @_;

    my $self = $class->SUPER::new(%opt);

    return $self->tie(%opt) if scalar keys %opt;
    $self;
}

sub setup_locking {
    my ($self) = @_;

    my $fd = $self->{db}->fd;
    $self->{handle} = gensym;
    open($self->{handle}, "+<&=$fd");
}

sub lookup {
    my ($self, $key) = @_;
    my $value;

    $self->flock(LOCK_SH);
    my $r = $self->{db}->get($key.($self->{try1null} ? "\0" : ''), $value);
    # die $r if $r and $r !~ /^DB_NOTFOUND/; # XXX this is BDB perl pkg does
    # DB_File only return 1 if record not found , so ignore it and return
    # undef, don't call die() and advoid up-level programe crash, :-)
    warn "$key not found\n" if $r;
    $self->flock(LOCK_UN);

    return $r ? undef : $value;
}

# an alias to insert. in DB level, update is a certain kind of
# insert.
sub update {
    shift->insert(@_);
}

sub insert {
    my ($self, $key, $value) = @_;

    $self->flock(LOCK_EX);
    my $r = $self->{db}->put($key.($self->{try1null} ? "\0" : ''), $value);
    die "Insert $key error\n" if $r;
    $self->flock(LOCK_UN);
}

# XXX update bunch of records, useful for a lot of insert operation, it
# will reduce sync calling times.
sub update_s {
    shift->insert_s(@_);
}

sub insert_s {
    my ($self, $ref) = @_;
    my $r = 0;

    $self->flock(LOCK_EX);
    foreach(keys %$ref) {
        $r = $self->{db}->put($_, $ref->{$_});
        die "Insert_s $_ error\n" if $r;
    }
    $self->flock(LOCK_UN);
}

sub delete {
    my ($self, $key) = @_;

    $self->flock(LOCK_EX);
    my $r = $self->{db}->del($key.($self->{try1null} ? "\0" : ''));
    $self->flock(LOCK_UN);
}

package Ext::DB::Hash;
use vars qw(@ISA);
@ISA = qw(Ext::DB::DB_File);
use DB_File;

sub tie {
    my ($self, %opt) = @_;
    if (not defined $opt{flags}) {
        $opt{flags} = O_RDONLY;
    }elsif(lc $opt{flags} eq 'write') {
        $opt{flags} = O_CREAT|O_RDWR;
    }else {
        $opt{flags} = O_RDONLY;
    }

    $self->{db} = tie my %h, "DB_File", $opt{file},
        $opt{flags}, 0666, $DB_HASH;

    if (not defined $self->{db}) {
        $self->{error} = "Cannot open $opt{file}: $!\n";
        return undef;
    }

    $self->{hash} = \%h;
    # no locking provide, see DB_File(3), use BerkeleyDB instead
    # $self->setup_locking;
    $self;
}

package Ext::DB::Btree;
use vars qw(@ISA);
@ISA = qw(Ext::DB::DB_File);
use DB_File;

sub tie {
    my ($self, %opt) = @_;
    if (not defined $opt{flags}) {
        $opt{flags} = O_RDONLY;
    }elsif(lc $opt{flags} eq 'write') {
        $opt{flags} = O_CREAT|O_RDWR;
    }else {
        $opt{flags} = O_RDONLY;
    }

    $self->{db} = tie my %h, "DB_File", $opt{file},
        $opt{flags}, 0666, $DB_BTREE;

    if (not defined $self->{db}) {
        $self->{error} = "Cannot open $opt{file}: $!\n";
        return undef;
    }

    $self->{hash} = \%h;
    # no locking provide, see DB_File(3), use BerkeleyDB instead
    # $self->setup_locking;
    $self;
}

1;
