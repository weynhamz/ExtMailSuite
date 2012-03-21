#!/bin/sh
FILES=`find . |grep ".pm$"`
SET_FAIL="echo -en \\033[1;31m"
SET_OK="echo -en \\033[1;32m"
SET_HL="echo -en \\033[1;33m"
SET_NM="echo -en \\033[0;39m"

LISTS=`for i in $FILES; do grep "^use " $i;done|awk {'print $2'}|sed -e s/\;//|sort |grep -v "Ext"|grep -v "constant"|grep -v "vars"|grep -v "strict"|grep -v "HTML::KTemplate"|grep -v "^MIME::"| uniq`

echo "Checking modules that ExtMail requires:"
for i in $LISTS; do
	perl -I./libs -e "use $i" 2>/dev/null
	RETV=$?
	if [ $RETV -eq 0 ];then
		$SET_OK
		echo -n "    $i"
		$SET_NM
		echo " found"
	else
		$SET_FAIL
		echo -n "    $i"
		$SET_HL
		echo " not found!"
		$SET_NM
	        echo "	Try http://search.cpan.org/search?query=$i&mode=module"
	fi
done
