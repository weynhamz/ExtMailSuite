#!/bin/sh
#
# backup.sh - a small script written by fengyong <www.yiyou.org>
# forum: http://www.extmail.org/forum/thread-7268-1-1.html

backupdir="/home/data/backup/"

if [ ! -d $backupdir ];then
	mkdir $backupdir
fi

# mkdir today backup

today=`date +%Y-%m-%d_%H_%M_%S`
fpath=$backupdir$today
echo $fpath
if [ ! -d $fpath ];then
	mkdir $fpath
fi

# delete old file

find $backupdir -type f -mtime +7 -print -exec /bin/rm -f {} \;

FL=`cat /usr/local/backup/file_list`

for i in $FL ;do
	cp -Rp $i $fpath
done

#backup mail dir

find /home/data/domains -type d >$fpath/maildirlist

# backup mysql all
/usr/local/bin/mysqldump --all-databases -uroot -pyourpasswd >$fpath/mysql_all.sql

# backup my self
cp -Rp $0 $fpath
cp -Rp /usr/local/backup/file_list $fpath

cd $backupdir
tar czf $today.tar.gz $today
rm -rf $today
cd -

# ftp ...

ftp -n<<!
open 192.168.1.3 21
user backup backup
binary
lcd $backupdir
prompt off
mdelete *
mput *
bye
!
