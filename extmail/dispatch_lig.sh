#!/bin/sh
# dispatch_lig.sh - a small script to startup dispatch.fcgi for lighttpd
#
# Author: He zhiqiang <hzqbbc@hzqbbc.com>

BASE=/var/www/extsuite/extmail
$BASE/tools/suid-with -u vuser -g vgroup /usr/bin/perl $BASE/dispatch.fcgi
