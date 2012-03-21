function eURL(str) {
        var rv = ' '; // not '' for a NS bug!
        for (i=0; i < str.length; i++) {
                aChar=str.substring(i, i+1);
                switch(aChar) {
                        case '=': rv += "%3D"; break;
                        case '?': rv += "%3F"; break;
                        case '&': rv += "%26"; break;
                        default: rv += aChar;
                }
        }
        return rv.substring(1, rv.length);
}

function fixDate (date) {
    var base = new Date(0);
    var skew = base.getTime();
    if (skew > 0)
        date.setTime(date.getTime() - skew);
}

function genNowTime() {
    var now = new Date();
    fixDate(now);
    now.setTime(now.getTime() + 2 * 24 * 60 * 60 * 1000);
    now = now.toGMTString();
    return now;
}

function setCookie (name, value, expires, path, domain, secure) {
	var curCookie = name + "=" + escape(value) + (expires ? "; expires=" + expires : "") + (path ? "; path=" + path : "") + (domain ? "; domain=" + domain : "") + (secure ? "secure" : "");
	document.cookie = curCookie;
}

function getCookie (name) {
	var prefix = name + '=';
	var c = document.cookie;
	var nullstring = '';
	var cookieStartIndex = c.indexOf(prefix);
	if (cookieStartIndex == -1)
	    return nullstring;
	var cookieEndIndex = c.indexOf(";", cookieStartIndex + prefix.length);
	if (cookieEndIndex == -1)
	    cookieEndIndex = c.length;
	return unescape(c.substring(cookieStartIndex + prefix.length, cookieEndIndex));
}

function deleteCookie (name, path, domain) {
	if (getCookie(name))
	    document.cookie = name + "=" + ((path) ? "; path=" + path : "") + ((domain) ? "; domain=" + domain : "") + "; expires=Thu, 01-Jan-70 00:00:01 GMT";
}

function getFromUrl (name) {
	var url = document.location.href;
	var res = url.match('\\?*&*('+name+')=([^&]+)');
	if (res)
		return res[2];
}

function highlight_Sel(name, selected)
{
	var sel = document.getElementById(name);
	try {
		if (selected == null || selected == '') {
			selected = getFromUrl(name);
			if (selected == null || selected == '') {
				selected = getCookie('_'+name);
			} else {
				setCookie('_'+name, selected, genNowTime(), '/', '', '');
			}
		}
	}
	catch(e) { alert(e); return false }

	if (selected == null || selected == '')
		return false;

	for(var i=0;i<sel.options.length;i++)
	{
		if (sel.options[i].value == selected ||
		    sel.options[i].text == selected)
		{
			sel.options[i].selected = true;
		} else {
			sel.options[i].selected = false;
		}
	}
}
