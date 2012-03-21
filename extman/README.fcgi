FastCGI support for ExtMan

Introduction
============

FastCGI is a high performance web application standard by OpenMarket,
currently extman added experimental FastCGI support, i tested with
Apache 2.0.x and lighttpd 1.4.x, and it should be ok under Apache 1.x
or lighttpd 1.3.x/1.5.x, report bugs to me if something wrong.

Before you begin to setup, please make sure FCGI perl module is ready
, you can get FCGI from http://search.cpan.org if it's not installed

Version
=======

This document release with 0.2.3 (extman), and most configs are the
very similar to extmail, so *we only conver the difference parts* .

Sat 3 Nov 2007 He zhiqiang <hzqbbc@hzqbbc.com>

Index
======

There are several configs to enable FCGI support for extman under
different web server, currently i only tested lighttpd and Apache.
Since 0.24-pre4 (20060601) extmail support remote FCGI server setup,
this mode has the best flexibility and security, can seperate fcgi
app from web server, even setup on different host.

The following is the list of possible config methods for ExtMan:

1.lighttpd + suid-with + dispatch.fcgi
2.lighttpd + suidperl + dispatch.fcgi
3.lighttpd + remote setup + dispatch.fcgi
4.Apache + Non-apache uid/gid + dispatch.fcgi
5.Apache + suidperl + dispatch.fcgi
6.Apache + remote setup + dispatch.fcgi
7.Nginx + remote setup + dispatch.fcgi


lighttpd + suid-with + dispatch.fcgi
====================================

lighttpd: run as root (default setup)
dispatch.fcgi: called by suid-with to suid to vmail user, eg: vuser

the suid-with programe is written by Noah Friedman <friedman@splode.com>
and modified by He zhiqiang <hzqbbc@hzqbbc.com>

setup:

1) config lighttpd.conf

uncomment the line of mod_fastcgi, like:

server.modules = (
        .............
        "mod_fastcgi",
        .............
)

alias.url = (
        "/extmail/cgi/" => "/var/www/extsuite/extmail/cgi/",
        "/extmail/" => "/var/www/extsuite/extmail/html/",
	"/extman/cgi/" => "/var/www/extsuite/extman/cgi/",
	"/extman/" => "/var/www/extsuite/extman/html/",
)

fastcgi.server = (
	".cgi" =>
           ( "localhost" =>
             (
                "socket"   => "/tmp/dispatch.fcgi",
                "bin-path" => "/var/www/extsuite/extmail/dispatch_lig.sh",
                "min-procs" => 1,
                "max-procs" => 4,
                "max-load-per-proc" => 100,
                "idle-timeout" => 20
              )
            )
         )

2) dispatch_lig.sh

You can get the latest version in the extmail top directory

#!/bin/sh
# dispatch_lig.sh - a small script to startup dispatch.fcgi for lighttpd
#
# Author: He zhiqiang <hzqbbc@hzqbbc.com>
BASE=/var/www/extsuite/extmail
$BASE/tools/suid-with -u vuser -g vgroup /usr/bin/perl $BASE/dispatch.fcgi

3) permission

name              permission
------------------------------
tools/suid-with   root:root 0755
dispatch.fcgi     root:root 0755
dispatch_lig.sh   root:root 0755

4) restart lighttpd

ps ax to see whether dispatch.fcgi is running, eg:

31301 ?        S      0:00 /bin/sh /var/www/extsuite/extmail/dispatch_lig.sh
31302 ?        S      0:00 /usr/bin/perl /var/www/extsuite/extmail/dispatch.fcgi
31303 ?        S      0:00 /bin/sh /var/www/extsuite/extmail/dispatch_lig.sh
31304 ?        S      0:00 /usr/bin/perl /var/www/extsuite/extmail/dispatch.fcgi

lighttpd + suidperl + dispatch.fcgi
===================================

lighttpd: run as root or noon root.
dispatch.fcgi: use suidperl to suid to vmail user, eg: vuser

setup:

1) config lighttpd.conf

alias.url = (
        "/extmail/cgi/" => "/var/www/extsuite/extmail/cgi/",
        "/extmail/" => "/var/www/extsuite/extmail/html/",
	"/extman/cgi/" => "/var/www/extsuite/extman/cgi/",
	"/extman/" => "/var/www/extsuite/extman/html/",
)

fastcgi.server = (
        ".cgi" =>
           ( "localhost" =>
             (
                "socket"   => "/tmp/dispatch.fcgi",
                "bin-path" => "/var/www/extsuite/extmail/dispatch.fcgi",
                "min-procs" => 1,
                "max-procs" => 4,
                "max-load-per-proc" => 100,
                "idle-timeout" => 20
              )
            )
         )

change dispatch_lig.sh to dispatch.fcgi, and be careful of the path!

2) dispatch.fcgi

Install suidperl package, it is a small binary, most modern Linux OS
distribution will come with perl-suidperl package.

edit dispatch.fcgi, replace the first three line from:

#!/bin/sh
# vim: set cindent expandtab ts=4 sw=4:
exec ${PERL-perl} -Swx $0 ${1+"$@"}

to:

#!/usr/bin/suidperl
# vim: set cindent expandtab ts=4 sw=4:

then chmod u+s to dispatch.fcgi
and chown vmail:vmail dispatch.fcgi

3) permission

name               permission
-------------------------------
dispatch.fcgi      vmail:vmail 4755

4) restart lighttpd

kill all runing dispatch.fcgi and the lighttpd process, then restart
lighttpd, it will invoke dispatch.fcgi automatically

lighttpd + remote setup + dispatch.fcgi
=======================================

lighttpd: normal setup (no matter what uid/gid lighttpd is running with)
dispatch.fcgi: self startup and listen to a specific port over TCP

Since 0.24-pre4 (20060601) dispatch.fcgi support self startup and process
management, can act as a remote fastcgi server. This new improvement will
greatly enhance performance and security, it seperate fastcgi application
and web server with tcp or unix socket, both can install on one machine
or on different machine. Furthermore there is no more need to take care
web server running uid/gid, dispatch.fcgi will setuid to the proper user
and take care of security, it's a good time to throw all the complexity
by SuEXEC to you :-)

setup:

1) config lighttpd.conf

uncomment the line of mod_fastcgi, like:

server.modules = (
        .............
        "mod_fastcgi",
        .............
)

fastcgi.server = ( "/extmail/cgi/" =>
                        (( "host" => "127.0.0.1",
                           "port" => 8888,
                           "check-local" => "disable",
                         )),
		   "/extman/cgi/" =>
                        (( "host" => "127.0.0.1",
                           "port" => 8888,
                           "check-local" => "disable",
                        ))
                )

alias.url = (
        "/extmail/" => "/var/www/extsuite/extmail/html/",
	"/extman/" => "/var/www/extsuite/extman/html/",
)

2) permission

name             permission
---------------------------
dispatch.fcgi    root:root 755

3) prepare works

su to root:

# touch /var/run/dispatch.fcgi.pid
# chown -R vuser:vgroup /var/run/dispatch.fcgi.pid

The above command will create a file own by vuer:vgroup, it will be
used by dispatch.fcgi (set uid/gid to vuser and vgroup)

4) startup remote fastcgi server

caution: you must su to *root* to do the following steps!

call dispatch.fcgi with full path to get usage:

/var/www/extsuite/extmail/dispatch.fcgi --help

It show:

usage: /path/to/dispatch.fcgi [*option*]

  -h, --help       show this usage
  --port=PORT      FCGI server bind port, eg:8888
  --child=NUMB     number of children to prefork
  --request=NUMB   number of requests a child to handle
  --timeout=NUMB   seconds to wait for request timeout
  --server         run as FCGI server, default off
  -u, --uid        set real and effective user ID
  -g, --gid        set real and effective group ID
  --pid=file       the pid file of parent process

After you know the usage, run the following command:

/var/www/extsuite/extmail/dispatch.fcgi --port=8888 --child=4 --server \
	--uid=vuser --gid=vgroup --pid=/var/run/dispatch.fcgi.pid \
	--request=50 --timeout=120

dispatch.fcgi will fork into background and listen to port 8888

ps aux to see whether dispatch.fcgi is running properly, eg:

vuser  6069  1.5  0.6  8092 3476 pts/1    S+   10:58   0:00 dispatch.fcgi (master)
vuser  6070  0.0  0.6  8092 3492 pts/1    S+   10:58   0:00 dispatch.fcgi (idle)
vuser  6071  0.0  0.6  8092 3492 pts/1    S+   10:58   0:00 dispatch.fcgi (idle)
vuser  6072  0.0  0.6  8092 3492 pts/1    S+   10:58   0:00 dispatch.fcgi (idle)
vuser  6073  0.0  0.6  8092 3492 pts/1    S+   10:58   0:00 dispatch.fcgi (idle)

Another simple way to run dispatch.fcgi is to call dispatch-init, this
shell script will do anything for you, it provide "start", "restart"
and "stop" command to maintain dispatch.fcgi easily.

5) restart lighttpd

restart lighttpd to take effect, try to access extmail and see is it work
correctly.

Apache + Non-apache uid/gid + dispatch.fcgi
===========================================

Changing apache User/Group to the vmail user, and enable mod_fastcgi,
it's the most secure install & setup mode but every processes and files
run as the vmail user, may cause some trouble

1) add mod_fastcgi support

get mod_fastcgi 2.4.2 from http://www.fastcgi.com, unpack it:

#tar xfz mod_fastcgi-2.4.2.tar.gz
#cd mod_fastcgi-2.4.2
#cp Makefile.AP2 Makefile
#make top_dir=/etc/httpd
#make top_dir=/etc/httpd install

the mod_fastcgi.so will be copied to /usr/lib/httpd/modules/

2) config httpd.conf

Change User & Group to the vmail user:

User vuser
Vgroup vgroup

add the following lines to it:

LoadModule fastcgi_module modules/mod_fastcgi.so

<IfModule mod_fastcgi.c>
FastCgiIpcDir /var/lib/fcgi
</IfModule>

Then create fastcgi ipc dirs:

#mkdir /var/lib/fcgi
#mkdir /var/lib/fcgi/dynamic
#chmod 777 /var/lib/fcgi
#chmod 777 /var/lib/fcgi/dynamic

3) config httpd.conf for extmail/extman

ScriptAlias /extmail/cgi/ /var/www/extsuite/extmail/dispatch.fcgi/
Alias /extmail /var/www/extsuite/extmail/html
ScriptAlias /extman/cgi/ /var/www/extsuite/extmail/dispatch.fcgi/
Alias /extman /var/www/extsuite/extman/html

<Location "/extmail/cgi">
  SetHandler fastcgi-script
</Location>

<Location "/extman/cgi">
  SetHandler fastcgi-script
</Location>

4) permission

name              permission
----------------------------
dispatch.fcgi     root:root 0755

4) restart apache

access http://hostname/extmail/ to see if extmail can redirect to
index.cgi.

Apache + suidperl + dispatch.fcgi
=================================

This setup is almost the same as "Apache + Non-apache uid/gid" setup,
except that use suidperl instead of perl to call dispatch.fcgi, then
dispatch.fcgi can suid to vmail user and make things more happy.

setup:

1) add mod_fastcgi support

Same as above, skip it

2) config httpd.conf

Almost the same as above, just ignore changing User & Grup part.

3) dispatch.fcgi

Install suidperl package, it is a small binary, most modern Linux OS
distribution will come with perl-suidperl package.

edit dispatch.fcgi, replace the first three line from:

#!/bin/sh
# vim: set cindent expandtab ts=4 sw=4:
exec ${PERL-perl} -Swx $0 ${1+"$@"}

to:

#!/usr/bin/suidperl
# vim: set cindent expandtab ts=4 sw=4:

then chmod u+s to dispatch.fcgi

4) permission

name               permission
-------------------------------
dispatch.fcgi      vmail:vmail 4755

5) restart

You should see the dispatch.fcgi running with vmail user, eg: vuser

Apache + remote mode + dispatch.fcgi
====================================

1) add mod_fastcgi support

Same as above, skip it

2) config httpd.conf

Add the following lines to httpd.conf:

LoadModule fastcgi_module modules/mod_fastcgi.so

<Ifmodule mod_fastcgi.c>
FastCgiExternalServer /usr/bin/dispatch.fcgi -host 127.0.0.1:8888 -idle-timeout 240
</Ifmodule>

3) config httpd.conf for extmail

Alias /extmail/cgi/ /usr/bin/dispatch.fcgi/
Alias /extmail /var/www/extsuite/extmail/html
Alias /extman/cgi/ /usr/bin/dispatch.fcgi/
Alias /extman /var/www/extsuite/extman/html

<Location "/extmail/cgi">
  SetHandler fastcgi-script
</Location>

<Location "/extman/cgi">
  SetHandler fastcgi-script
</Location>

4) prepare works

Refer to the same section of "lighttpd + remote mode + dispatch.fcgi"

5) startup fastcgi remote server

Refer to the same section of "lighttpd + remote mode + dispatch.fcgi"

6) restart apache

Restart apache to take effect, try to access extmail to see whether
it works correctly.

Nginx + remote mode + dispatch.fcgi
====================================

Since webmail 1.0.4+ extman 0.2.4+ we now support nginx

1)  compile nginx with fcgi support

2) config nginx.conf

Add the following lines in the server section:

        location ^~ /extmail/cgi/ {
                fastcgi_pass          127.0.0.1:8888;
                include conf/fcgi.conf;
        }
        location ^~ /extmail/ {
             alias  /var/www/extsuite/extmail/html/;
        }
        location ^~ /extman/cgi/ {
                fastcgi_pass          127.0.0.1:8888;
                include conf/fcgi.conf;
        }
        location ^~ /extman/ {
                alias /var/www/extsuite/extman/html/;
        }

3) create conf/fcgi.conf

# fcgi.conf
fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
fastcgi_param  SERVER_SOFTWARE    nginx;

fastcgi_param  QUERY_STRING       $query_string;
fastcgi_param  REQUEST_METHOD     $request_method;
fastcgi_param  CONTENT_TYPE       $content_type;
fastcgi_param  CONTENT_LENGTH     $content_length;

fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
fastcgi_param  REQUEST_URI        $request_uri;
fastcgi_param  DOCUMENT_ROOT      $document_root;
fastcgi_param  SERVER_PROTOCOL    $server_protocol;

fastcgi_param  REMOTE_ADDR        $remote_addr;
fastcgi_param  REMOTE_PORT        $remote_port;
fastcgi_param  SERVER_ADDR        $server_addr;
fastcgi_param  SERVER_PORT        $server_port;
fastcgi_param  SERVER_NAME        $server_name;

5) startup fastcgi remote server

Refer to the same section of "lighttpd + remote mode + dispatch.fcgi"

6) restart nginx

Restart nginx to take effect, try to access extmail to see whether
it works correctly.
