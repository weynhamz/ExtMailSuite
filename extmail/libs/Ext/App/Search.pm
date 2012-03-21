# vim: set ci et ts=4 sw=4:
package Ext::App::Search;
use strict;
use Exporter;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter Ext::App);

use Ext::App;
use Ext::Config; # load sys/user config
use Ext::MIME;
use Ext::Utils;
use Ext::MailFilter;
use Ext::RFC822; # import date_fmt
use Ext::Storage::Maildir;
use Ext::DateTime;
use vars qw(%lang_folders %lang_search $lang_charset);
use Ext::Lang;
use Ext::Unicode;

use POSIX qw(strftime);
use Ext::Storage::Search;

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    return unless($self->valid||$self->permit);

    $self->add_methods(search => \&search);
    $self->add_methods(show_search => \&show_search);
    $self->add_methods(messages_mgr => \&messages_mgr);
    $self->{default_mode} = 'search';
    Ext::Storage::Maildir::init($self->get_working_path);

    $self->_initme;
    $self->{tpl}->assign(
        IS_IN_SEARCH=>1,
    );
    $self;
}

sub _initme {
    initlang($_[0]->userconfig->{lang}, __PACKAGE__);
    $_[0]->{tpl}->assign( lang_charset => $lang_charset );
    $_[0]->{tpl}->assign( \%lang_folders );
    $_[0]->{tpl}->assign( \%lang_search );
}

sub show_search {
    my $self = shift;
    my $tpl = $self->{tpl};
    $tpl->assign(SHOW_SEARCH=>1);
    my $utf8 = Ext::Unicode->new;
    my $q = $self->{query};
    my @list = get_dirs_list;

    for(@list) {
        # caution, template currently not support same VAR resuing
        # in the loop, ouch :-(
        my $name = $lang_folders{$_};
        $tpl->assign(
            'LOOP_FOLDERS',
            DISTFOLDER => $_,
            DISTNAME => $name ? $name : $utf8->decode_imap_utf7($_)
        );
    }
}

sub search {
    my $self = shift;
    my $tpl = $self->{tpl};
    my $q = $self->{query};
    my $utf8 = Ext::Unicode->new;
    $tpl->assign(SEARCH_MESSAGES_LIST=>1);

    my $sid = fixpath($q->cgi('sid'));
    my $keyword = lc $q->cgi('keyword');
    my $sender = $keyword;
    my $receiver = $keyword;
    my $curpage = $q->cgi('page');
    my $new_search = $q->cgi('new_search');
    my $sort_order = $self->userconfig->{sort}||'Dt';

    if ($self->userconfig->{delmode} eq 'purge') {
        $tpl->assign( HINT_PURGE => 1);
    } else {
        $tpl->assign( HINT_PURGE => 0);
    }

    HANDLE:
    {
        unless ($new_search){
            last HANDLE; # has search ,just paging
        }

        # here for first search,create new db
        my @list = get_dirs_list;

        # here create cachedb for each folder
        foreach(@list){
            my $dir = _name2mdir($_);
            set_msgs_cache($_, $sort_order);
        }

        # here begin real search
        my @cache;
        my ($pos,$seen,$new)=(0,0,0);
        my %cont;
        $cont{is_advance}=$q->cgi('is_advance') if ($q->cgi('is_advance'));
        $cont{sel_folder}=$q->cgi('sel_folder') if ($q->cgi('sel_folder'));
        $cont{daterange}=$q->cgi('daterange') if ($q->cgi('daterange'));
        $cont{chk_attach}=$q->cgi('attach') if ($q->cgi('attach'));
        $cont{chk_subj}=$q->cgi('insubject') if ($q->cgi('insubject'));
        $cont{chk_header}=$q->cgi('inheader') if ($q->cgi('inheader'));

        foreach(@list){
            next  if ($cont{is_advance} && $cont{sel_folder} && $cont{sel_folder} ne $_);
            my $dir = _name2mdir($_);
            my $cache_file = "$dir/extmail-curcache.db";
            next unless (-r  $cache_file);
            search_folder($self,$cache_file,$keyword,$sender,$receiver,\@cache,$_,\%cont);
        }
        # here create db for search result
        mk_search_db(\@cache,$sort_order,$keyword,$sender,$receiver,\%cont);

        # return to search list page, advoid form post problem
        $self->redirect("?__mode=search&sid=$sid&screen=search.html");
        return;
    }

    if($q->cgi('resort')) {
        $sort_order = name2sort($q->cgi('resort'));
        rebuild_search_db($sort_order);
    }

    my $order = Ext::Utils::sort2name($sort_order);
    $tpl->assign(SORT_ORDER => $lang_folders{$order});

    # here show search result list
    my($flag_rev) = ($order =~/_rev/?1:0);
    $order =~s/_rev//; # this only indicate sort type, not asc/desc
    $tpl->assign(
        'flag_'.$order.'_rev' => $flag_rev,
        'flag_'.$order => 1,
        CURPAGE => $q->cgi('page'),
    );

    my $list = undef;
    my ($nonext, $noprev, $nofirst, $nolast);
    ($list, $nonext) = $self->paging($self,$q->cgi('page'));
    my $timezone = $self->userconfig->{timezone};

    $tpl->assign(HAVEMSGLIST => 1) if (keys %$list);

    foreach my $pos (sort {$a<=>$b} keys %$list) {
        my $from = $list->{$pos}->{FROM};
        my $date = $list->{$pos}->{DATE};
        my $folder = $list->{$pos}->{FOLDER};
        my $folder_name=$lang_folders{$folder} ? $lang_folders{$folder} : $utf8->decode_imap_utf7($folder);
        my $subject = $list->{$pos}->{SUBJECT};
        my $file = $list->{$pos}->{FILENAME};
        my ($size) = $list->{$pos}->{SIZES};
        my ($priority)=$list->{$pos}->{PRIORITY}||'';
        my $flag_att = ($file =~ /:.*(A).*/) ? 1:0;
        my $flag_new = ($file =~ /:.*(S).*/) ? 0:1;
        my $flag_is_reply=($file =~ /:.*(R).*/) ? 1:0;
        my $flag_is_forward=($file =~ /:.*(P).*/) ? 1:0;
        my $s_date=dateserial2str(datefield2dateserial($date), $timezone, 'auto','stime', 12);

        my $sjchar;
        TRY: {
            my $subject = $list->{$pos}->{SUBJECT};
            $subject =~ s/\s+//; # remove space
            my $c = charset_detect($subject);
            if ($c =~ /^(windows-1252|iso-8859-)/ && length $subject < 6) {
                $sjchar = charset_detect($from);
            } else {
                $sjchar = $c;
            }
        }

        $from = iconv($from, $sjchar, 'utf-8') if charset_detect($from) ne 'utf-8';
        $subject = iconv($subject, $sjchar, 'utf-8') if charset_detect($subject) ne 'utf-8';
        $subject = $folder_name . ' - '. $subject;

        $tpl->assign(
            'LOOP_SUBLIST', # Must be quote, or die under strict
            POS => $list->{$pos}->{FDPOS},#here record pos in some folder db
            SER_POS=>$pos,
            FOLDER => str2url($folder),
            FILE => str2url($file),
            SUBJECT => ($subject=~/\S+/ ? $subject : $lang_folders{notitle} || 'No Title'),
            FROM => html_escape(rfc822_addr_parse(decode_words_utf8($from))->{name}),
            DATE => date_fmt('%s, %s %s:%s', $date), # XXX FIXME
            SHORTDATE => $s_date,
            SIZE => $size,
            FATT => $flag_att,
            FNEW => $flag_new,
            HIGH_PRIORITY=>($priority && $priority<3)?1:0,
            LOW_PRIORITY=>($priority && $priority>3)?1:0,
            FLAG_IS_REPLY=>$flag_is_reply,
            FLAG_IS_FORWARD=>$flag_is_forward,
            FOLDER_DRAFTS => ($folder eq 'Drafts')?1:0,
        );
    }

    my $inf = get_search_db_hdr();
    my $usercfg = $self->userconfig();
    my $total_pages = myceil(($inf->{TOTALCOUNT})/$usercfg->{page_size});

    $tpl->assign(
        TOTALCOUNT=>$inf->{TOTALCOUNT},
        KEYWORD=>$inf->{SUBJECT},
    );

    for(my $i = 1; $i <= $total_pages; $i++) {
        $tpl->assign(
            'LOOP_PAGES',
            PAGE_VALUE => $i-1,
            PAGE_TEXT => "$i / $total_pages",
            IS_SELECTED => ($i-1)==$q->cgi('page')?1:0
        );
    }

    my $prev = ($q->cgi("page") ? $q->cgi("page") -1 : 0);
    my $next = ($q->cgi("page") ? $q->cgi("page") +1 : 1);
    my $first = 0;
    my $last = $total_pages-1;
    if($q->cgi('page') eq $prev) {
        $noprev = 1;
    }
    if(!$q->cgi('page')) {
        $noprev = 1;
    }

    $nofirst = $q->cgi('page') <= 0?1:0;
    $nolast = ($q->cgi('page') >= ($total_pages-1)) || ($total_pages<=1)?1:0;

    $tpl->assign(
        PREV => $prev,
        NEXT => $next,
        FIRST => $first,
        LAST => $last,
        HAVE_PREV => $noprev?0:1,
        HAVE_NEXT => $nonext?0:1,
        HAVE_FIRST => $nofirst?0:1,
        HAVE_LAST => $nolast?0:1,
        NEED_PAGING => $total_pages <=1?0:1,
    );

    my @list = get_dirs_list;
    for(@list) {
        # caution, template currently not support same VAR resuing
        # in the loop, ouch :-(
        next if($_ eq 'Drafts');
        next if($_ eq 'Archive');

        my $name = $lang_folders{$_};
        $tpl->assign(
            'LOOP_FOLDERS',
            DISTFOLDER => $_,
            DISTNAME => $name?$name:$utf8->decode_imap_utf7($_)
        );
    }
}

sub search_folder {
    my ($self,$cache_file,$keyword,$sender,$receiver,$cache,$fd,$cont)=@_;
    my $q = $self->{query};

    return unless (-r $cache_file);

    use Ext::DB;
    my $db = Ext::DB->new(file => "Btree:$cache_file");
    my $info = parse_cache($db->lookup('HEADER'));
    my $lastdate;

    if ($cont->{daterange} && $cont->{daterange} ne "-1"){
        $lastdate= strftime("%Y%m%d%H%M%S", localtime(time - $cont->{daterange}*3600*24));
    }

    foreach(my $i=0; $i<($info->{COUNT}+$info->{NEWCOUNT}); $i++) {
        my $rec_info = parse_cache($db->lookup("REC$i"));
        next if ($lastdate && $rec_info->{DATETIME} le $lastdate);

        if (my $qq = $cont->{chk_attach}) {
            my $file = $rec_info->{FILENAME};
            my $has_attach = ($file =~ /:.*(A).*/) ? 1 : 0;
            if ($qq eq 'attach') {
                # need has attach
                next unless $has_attach;
            } else {
                # attach eq ~attach ?
                next if $has_attach;
            }
        }

        for (qw(FROM SUBJECT)) {
            next unless $rec_info->{$_};
            next unless $rec_info->{$_} =~ /=\?[^?]*\?[QB]\?[^?]*\?=/;
            $rec_info->{$_} =~ s/(\?=)\s+(=\?)/$1$2/g;
        }

        my $subject = decode_words_utf8($rec_info->{SUBJECT});
        unless (my $ch = get_charset($rec_info->{SUBJECT})) {
            $subject =iconv($subject, $ch, 'utf-8');
        }
        my @a=split(/,|;/,$rec_info->{FROM});
        my @result=map { decode_words_utf8($_) } @a;
        my $from=join (';',@result);

        $rec_info->{SUBJECT}=$subject;
        $rec_info->{FROM}=$from;
        $rec_info->{FDPOS}=$i;

        my $match = 0;
        if ($cont->{chk_subj}) {
            $match = 1 if index(lc $rec_info->{SUBJECT}, $keyword)>=0;
        }
        if (!$match && $cont->{chk_header}) {
            $match = 1 if index(lc $rec_info->{FROM}, $sender)>=0;
        }

        if ($match) {
            $rec_info->{FOLDER}=$fd;
            push @$cache,$rec_info;
        }
    }
}

sub messages_mgr {
    my $self = shift;
    my $q = $self->{query};
    my $sid = fixpath($q->cgi('sid'));
    my $dir = fixpath($q->cgi('folder'));
    my $page = $q->cgi('page');
    my %hash = ();
    my @serpos;

    my $a = $q->cgi_full_names;
    grep {
        if(/^(.+)-MOVE-(.+)-SER-POS-(.+)$/) {
            my $fd = url2str($1);
            $hash{$fd} = () unless ($hash{$fd});
            my ($mpos, $spos) = ($2, $3);
            my $msgid = url2str($q->cgi($_));

            $hash{$fd}->{$mpos} = $msgid;
            push @serpos, $spos;
        }
    } @$a;

    if($q->cgi('deletemsg')) {
        my $need_rb_target=0;
        foreach my $dir(sort keys %hash){
            next unless $hash{$dir};
            next unless scalar keys %{$hash{$dir}};

            if ($self->userconfig->{delmode} eq 'purge') {
                set_bmsgs_delete($dir, %{$hash{$dir}});
            } else {
                # mode == delete then move to trash
                if ($dir eq 'Trash') {
                    set_bmsgs_delete($dir, %{$hash{$dir}});
                } else {
                    set_bmsgs_move($dir, 'Trash', %{$hash{$dir}});
                }
            }

            $need_rb_target=1;
            my $file_num = scalar keys %{$hash{$dir}} || 0;
        }

        unless ($need_rb_target) {
            $self->{tpl}->{noprint} = 1;
            $self->redirect("?__mode=search&sid=$sid&page=$page&screen=search.html");
            return;
        }
        del_search_bmsgs_db(@serpos);
    }

    if($q->cgi('movemsg')) {
        my $distfolder=fixpath($q->cgi('distfolder'));
        my $need_rb_target=0;
        foreach my $dir(sort keys %hash){
            next unless $hash{$dir};
            next unless scalar keys %{$hash{$dir}};
            next unless $dir ne $distfolder;

            set_bmsgs_move($dir, $distfolder, %{$hash{$dir}});
            $need_rb_target=1;
        }

        if ($need_rb_target){
            # has any movement
            rebuild_msgs_cache($distfolder, get_search_db_sort($distfolder));
        }else{
            $self->{tpl}->{noprint} = 1;
            $self->redirect("?__mode=search&sid=$sid&page=$page&screen=search.html");
            return;
        }
        update_search_db_inmove($distfolder, @serpos);
    }

    if($q->cgi('setmsg')) {
        my $op = $q->cgi('msgflag');
        update_search_db($op, @serpos);
    }

    $self->{tpl}->{noprint} = 1;
    $self->redirect("?__mode=search&sid=$sid&page=$page&screen=search.html");
}

sub paging {
    my $self = shift;
    my $usercfg = $self->userconfig();
    my $user_page_size = $usercfg->{page_size};
    my($obj, $page) = @_;

    if (!$page) { $page = 0; }
    my ($c,$nomore) = get_search_msgs_db(
        $user_page_size,
        $user_page_size*$page
    );
    ($c, $nomore);
}

sub pre_run { 1 }

sub post_run {
    my $template = $_[0]->{query}->cgi('screen') || 'search.html';
    # dirty hack, to fallback original working path, ouch :-(
    reset_working_path();
    $_[0]->{tpl}->process($template);
    $_[0]->{tpl}->print;
}

sub DESTORY {}

1;
