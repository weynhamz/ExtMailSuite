package Parse::Syslog;
use Carp;
use Symbol;
use Time::Local;
use strict;
use vars qw($VERSION);
my %months_map = (
    'Jan' => 0, 'Feb' => 1, 'Mar' => 2,
    'Apr' => 3, 'May' => 4, 'Jun' => 5,
    'Jul' => 6, 'Aug' => 7, 'Sep' => 8,
    'Oct' => 9, 'Nov' =>10, 'Dec' =>11,
    'jan' => 0, 'feb' => 1, 'mar' => 2,
    'apr' => 3, 'may' => 4, 'jun' => 5,
    'jul' => 6, 'aug' => 7, 'sep' => 8,
    'oct' => 9, 'nov' =>10, 'dec' =>11,
);
# year-increment algorithm: if in january, if december is seen, decrement year
my $enable_year_decrement = 1;
# fast timelocal, cache minute's timestamp
# don't cache more than minute because of daylight saving time switch
my @str2time_last_minute;
my $str2time_last_minute_timestamp;
# 0: sec, 1: min, 2: h, 3: day, 4: month, 5: year
sub str2time($$$$$$$)
{
    my $GMT = pop @_;
    if(defined $str2time_last_minute[4] and
        $str2time_last_minute[0] == $_[1] and
        $str2time_last_minute[1] == $_[2] and
        $str2time_last_minute[2] == $_[3] and
        $str2time_last_minute[3] == $_[4] and
        $str2time_last_minute[4] == $_[5])
    {
        return $str2time_last_minute_timestamp + $_[0];
    }
    my $time;
    if($GMT) {
        $time = timegm(@_);
    }
    else {
        $time = timelocal(@_);
    }
    @str2time_last_minute = @_[1..5];
    $str2time_last_minute_timestamp = $time-$_[0];
    return $time;
}
sub _use_locale($)
{
    use POSIX qw(locale_h strftime);
    my $old_locale = setlocale(LC_TIME);
    for my $locale (@_) {
        croak "new(): wrong 'locale' value: '$locale'" unless setlocale(LC_TIME, $locale);
        for my $month (0..11) {
            $months_map{strftime("%b", 0, 0, 0, 1, $month, 96)} = $month;
        }
    }
    setlocale(LC_TIME, $old_locale);
}
sub new($$;%)
{
    my ($class, $file, %data) = @_;
    croak "new() requires one argument: file" unless defined $file;
    %data = () unless %data;
    if(not defined $data{year}) {
        $data{year} = (localtime(time))[5]+1900;
    }
    $data{_repeat}=0;
    if(ref $file eq 'File::Tail') {
        $data{filetail} = 1;
        $data{file} = $file;
    }
    else {
        $data{file}=gensym;
        open($data{file}, "<$file") or croak "can't open $file: $!";
    }
    if(defined $data{locale}) {
        if(ref $data{locale} eq 'ARRAY') {
            _use_locale @{$data{locale}};
        }
        elsif(ref $data{locale} eq '') {
            _use_locale $data{locale};
        }
        else {
            croak "'locale' parameter must be scalar or array of scalars";
        }
    }
    return bless \%data, $class;
}
sub _next_line($)
{
    my $self = shift;
    my $f = $self->{file};
    if(defined $self->{filetail}) {
        return $f->read;
    }
    else {
        return <$f>;
    }
}
sub next($)
{
    my ($self) = @_;
    while($self->{_repeat}>0) {
        $self->{_repeat}--;
        return $self->{_repeat_data};
    }
    line: while(my $str = $self->_next_line()) {
        # date, time and host
        $str =~ /^
            (\S{3})\s+(\d+)   # date  -- 1, 2
            \s
            (\d+):(\d+):(\d+) # time  -- 3, 4, 5
            \s
            ([-\w\.]+)        # host  -- 6
            \s+
            (.*)              # text  -- 7
            $/x or do
        {
            carp "line not in syslog format: $str";
            next line;
        };
        my $mon = $months_map{$1};
        defined $mon or croak "unknown month $1\n";
        # year change
        if($mon==0) {
            $self->{year}++ if defined $self->{_last_mon} and $self->{_last_mon} == 11;
            $enable_year_decrement = 1;
        }
        elsif($mon == 11) {
            if($enable_year_decrement) {
                $self->{year}-- if defined $self->{_last_mon} and $self->{_last_mon} != 11;
            }
        }
        else {
            $enable_year_decrement = 0;
        }
        $self->{_last_mon} = $mon;
        # convert to unix time
        my $time = str2time($5,$4,$3,$2,$mon,$self->{year}-1900,$self->{GMT});
        my ($host, $text) = ($6, $7);
        # last message repeated ... times
        if($text =~ /^(?:last message repeated|above message repeats) (\d+) time/) {
            next line if defined $self->{repeat} and not $self->{repeat};
            next line if not defined $self->{_last_data}{$host};
            $1 > 0 or do {
                carp "last message repeated 0 or less times??";
                next line;
            };
            $self->{_repeat}=$1-1;
            $self->{_repeat_data}=$self->{_last_data}{$host};
            return $self->{_last_data}{$host};
        }
        # marks
        next if $text eq '-- MARK --';
        # some systems send over the network their
        # hostname prefixed to the text. strip that.
        $text =~ s/^$host\s+//;
        # discard ':' in HP-UX 'su' entries like this:
        # Apr 24 19:09:40 remedy : su : + tty?? root-oracle
        $text =~ s/^:\s+//;
        $text =~ /^
            ([^:]+?)        # program   -- 1
            (?:\[(\d+)\])?  # PID       -- 2
            :\s+
            (?:\[ID\ (\d+)\ ([a-z0-9]+)\.([a-z]+)\]\ )?   # Solaris 8 "message id" -- 3, 4, 5
            (.*)            # text      -- 6
            $/x or do
        {
            carp "line not in syslog format: $str";
            next line;
        };
        if($self->{arrayref}) {
            $self->{_last_data}{$host} = [
                $time,  # 0: timestamp
                $host,  # 1: host
                $1,     # 2: program
                $2,     # 3: pid
                $6,     # 4: text
                ];
        }
        else {
            $self->{_last_data}{$host} = {
                timestamp => $time,
                host      => $host,
                program   => $1,
                pid       => $2,
                msgid     => $3,
                facility  => $4,
                level     => $5,
                text      => $6,
            };
        }
        return $self->{_last_data}{$host};
    }
    return undef;
}

1;
