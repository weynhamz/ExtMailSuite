#!/bin/sh
#
# Author: He zhiqiang <hzqbbc@hzqbbc.com>
build() {
for i in Passwd DateTime CGI Config Lang Session Utils RFC822 CaptCha GD FCGI;do
	cp -p $1/$i.pm $i.pm
done
}

clean() {
for i in Passwd DateTime CGI Config Lang Session Utils RFC822 CaptCha GD FCGI;do
	rm -f $i.pm
done
}

case "$1" in
	build)
		build $2
		;;
	clean)
		clean
		;;
	*)
		echo "$0 {build|clean} /path/to/extmail/libs/Ext/"
esac

exit 0
