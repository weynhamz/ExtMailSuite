var sPop = null;
var postSubmited = false;

var userAgent = navigator.userAgent.toLowerCase();
var is_opera = (userAgent.indexOf('opera') != -1);
var is_saf = ((userAgent.indexOf('applewebkit') != -1) || (navigator.vendor == 'Apple Computer, Inc.'));
var is_webtv = (userAgent.indexOf('webtv') != -1);
var is_ie = ((userAgent.indexOf('msie') != -1) && (!is_opera) && (!is_saf) && (!is_webtv));
var is_ie4 = ((is_ie) && (userAgent.indexOf('msie 4.') != -1));
var is_moz = ((navigator.product == 'Gecko') && (!is_saf));
var is_kon = (userAgent.indexOf('konqueror') != -1);
var is_ns = ((userAgent.indexOf('compatible') == -1) && (userAgent.indexOf('mozilla') != -1) && (!is_opera) && (!is_webtv) && (!is_saf));
var is_ns4 = ((is_ns) && (parseInt(navigator.appVersion) == 4));
var is_mac = (userAgent.indexOf('mac') != -1);

function ctlent(event) {
	if(postSubmited == false && (event.ctrlKey && event.keyCode == 13) || (event.altKey && event.keyCode == 83) && $('postsubmit')) {
		//if(in_array($('postsubmit').name, ['topicsubmit', 'replysubmit', 'editsubmit']) && !validate($('postform'))) {
		//	return;
		//}
		DoSend();
	}
}

function storeCaret(textEl){
	if(textEl.createTextRange){
		textEl.caretPos = document.selection.createRange().duplicate();
	}
}

function checkall(form, prefix, checkall) {
	var checkall = checkall ? checkall : 'chkall';
	for(var i = 0; i < form.elements.length; i++) {
		var e = form.elements[i];
		if(e.name != checkall && (!prefix || (prefix && e.name.match(prefix)))) {
			e.checked = form.elements[checkall].checked;
		}
	}
}

function arraypop(a) {
	if(typeof a != 'object' || !a.length) {
		return null;
	} else {
		var response = a[a.length - 1];
		a.length--;
		return response;
	}
}

function arraypush(a, value) {
	a[a.length] = value;
	return a.length;
}


function findtags(parentobj, tag) {
	if(typeof parentobj.getElementsByTagName != 'undefined') {return parentobj.getElementsByTagName(tag);}
	else if(parentobj.all && parentobj.all.tags) {return parentobj.all.tags(tag);}
	else {return null;}
}

function copycode(obj) {
	var rng = document.body.createTextRange();
	rng.moveToElementText(obj);
	rng.scrollIntoView();
	rng.select();
	rng.execCommand("Copy");
	rng.collapse(false);
}


function toggle_collapse(objname, unfolded) {
	if(typeof unfolded == 'undefined') {
		var unfolded = 1;
	}
	var obj = $(objname);
	var oldstatus = obj.style.display;
	var collapsed = getcookie('discuz_collapse');
	var cookie_start = collapsed ? collapsed.indexOf(objname) : -1;
	var cookie_end = cookie_start + objname.length + 1;

	obj.style.display = oldstatus == 'none' ? '' : 'none';
	collapsed = cookie_start != -1 && ((unfolded && oldstatus == 'none') || (!unfolded && oldstatus == '')) ?
			collapsed.substring(0, cookie_start) + collapsed.substring(cookie_end, collapsed.length) : (
			cookie_start == -1 && ((unfolded && oldstatus == '') || (!unfolded && oldstatus == 'none')) ?
			collapsed + objname + ' ' : collapsed);

	expires = new Date();
	expires.setTime(expires.getTime() + (collapsed ? 86400 * 30 : -(86400 * 30 * 1000)));
	document.cookie = 'discuz_collapse=' + escape(collapsed) + '; expires=' + expires.toGMTString() + '; path=/';

	var img = $(objname + '_img');
	var img_regexp = new RegExp((oldstatus == 'none' ? '_yes' : '_no') + '\\.gif$');
	var img_re = oldstatus == 'none' ? '_no.gif' : '_yes.gif'
	if(img) {
		img.src = img.src.replace(img_regexp, img_re);
	}
}

function imgzoom(o) {
	if(event.ctrlKey) {
		var zoom = parseInt(o.style.zoom, 10) || 100;
		zoom -= event.wheelDelta / 12;
		if(zoom > 0) {
			o.style.zoom = zoom + '%';
		}
		return false;
	} else {
		return true;
	}
}

function getcookie(name) {
	var cookie_start = document.cookie.indexOf(name);
	var cookie_end = document.cookie.indexOf(";", cookie_start);
	return cookie_start == -1 ? '' : unescape(document.cookie.substring(cookie_start + name.length + 1, (cookie_end > cookie_start ? cookie_end : document.cookie.length)));
}

function AddText(txt) {
	obj = $('postform').message;
	selection = document.selection;
	checkFocus();
	if(typeof(obj.selectionStart) != 'undefined') {
		var opn = obj.selectionStart + 0;
		obj.value = obj.value.substr(0, obj.selectionStart) + txt + obj.value.substr(obj.selectionEnd);
	} else if(selection && selection.createRange) {
		var sel = selection.createRange();
		sel.text = txt;
		sel.moveStart('character', -mb_strlen(txt));
	} else {
		obj.value += txt;
	}
}

function insertAtCaret (textEl,	text){
	if(textEl.createTextRange && textEl.caretPos){
		var caretPos = textEl.caretPos;
		caretPos.text += caretPos.text.charAt(caretPos.text.length - 2)	== ' ' ? text +	' '	: text;
	} else if(textEl) {
		textEl.value +=	text;
	} else {
		textEl.value = text;
	}
}

function checkFocus() {
	var obj = typeof wysiwyg == 'undefined' || !wysiwyg ? $('postform').message : editwin;
	if(!obj.hasfocus) {
		obj.focus();
	}
}

function closesmiliewindow(e) {
	if(typeof smiliewindow != 'undefined' && !smiliewindow.closed) {
		smiliewindow.close();
	}
}

function opensmiliewindow(width, height, editorid) {
	smiliewindow = window.open('post.php?action=smilies' + (editorid ? '&editorid=' + editorid : ''), 'Popup', 'width=' + width + ',height=' + height + ',resizable=yes,scrollbars=yes');
	window.onunload = closesmiliewindow;
}

function mb_strlen(str) {
	return (is_ie && str.indexOf('\n') != -1) ? str.replace(/\r?\n/g, '_').length : str.length;
}

function insertSmiley(smilieid) {
	checkFocus();
	var src = $('smilie_' + smilieid).src;
	var code = $('smilie_' + smilieid).pop ? $('smilie_' + smilieid).pop : $('smilie_' + smilieid).alt;
	if(typeof wysiwyg != 'undefined' && wysiwyg && allowsmilies && (!$('smileyoff') || $('smileyoff').checked == false)) {
		if(is_moz) {
			applyFormat('InsertImage', false, src);
			var smilies = findtags(editdoc.body, 'img');
			for(var i = 0; i < smilies.length; i++) {
				if(smilies[i].src == src && smilies[i].getAttribute('smilieid') < 1) {
					smilies[i].setAttribute('smilieid', smilieid);
					smilies[i].setAttribute('border', "0");
				}
			}
		} else {
			insertText('<img src="' + src + '" border="0" smilieid="' + smilieid + '" alt="" /> ', false);
		}
	} else {
		code += ' ';
		AddText(code);
	}
}

function announcement() {
	$('announcement').innerHTML = '<marquee style="filter:progid:DXImageTransform.Microsoft.Alpha(startX=0, startY=0, finishX=10, finishY=100,style=1,opacity=0,finishOpacity=100); margin: 0px 8px" direction="left" scrollamount="2" scrolldelay="1" onMouseOver="this.stop();" onMouseOut="this.start();">' +
		$('announcement').innerHTML + '</marquee>';
	$('announcement').style.display = 'block';
}

function $(id) {
	return document.getElementById(id);
}

function in_array(needle, haystack) {
	if(typeof needle == 'string') {
		for(var i in haystack) {
			if(haystack[i] == needle) {
					return true;
			}
		}
	}
	return false;
}

document.write("<style type='text/css'id='defaultPopStyle'>");
document.write(".cPopText { font-family: Tahoma, Verdana; background-color: #FFFFCC; border: 1px #000000 solid; font-size: 12px; padding-right: 4px; padding-left: 4px; line-height: 18px; padding-top: 2px; padding-bottom: 2px; visibility: hidden; filter: Alpha(Opacity=80)}");

document.write("</style>");
document.write("<div id='popLayer' style='position:absolute;z-index:1000' class='cPopText'></div>");

function showPopupText(event) {
	if(event.srcElement) o = event.srcElement; else o = event.target;
	if(!o) {
		return;
	}
	MouseX = event.clientX;
	MouseY = event.clientY;
	if(o.alt != null && o.alt != '') {
		o.pop = o.alt;
		o.alt = '';
	}
	if(o.title != null && o.title != '') {
		o.pop = o.title;
		o.title = '';
	}
	if(o.pop != sPop) {
		sPop = o.pop;
		if(sPop == null || sPop == '') {
			$('popLayer').style.visibility = "hidden";
		} else {
			popStyle = o.dyclass != null ? o.dyclass : 'cPopText';
			$('popLayer').style.visibility = "visible";
			showIt();
		}
	}
}

function showIt() {
	$('popLayer').className = popStyle;
	$('popLayer').innerHTML = sPop.replace(/<(.*)>/g,"&lt;$1&gt;").replace(/\n/g,"<br>");
	var popWidth = $('popLayer').clientWidth;
	var popHeight = $('popLayer').clientHeight;
	var popLeftAdjust = MouseX + 12 + popWidth > document.body.clientWidth ? -popWidth - 24 : 0;
	var popTopAdjust = MouseY + 12 + popHeight > document.body.clientHeight ? -popHeight - 24 : 0;
	$('popLayer').style.left = (MouseX + 12 + document.body.scrollLeft + popLeftAdjust) + 'px';
	$('popLayer').style.top = (MouseY + 12 + document.body.scrollTop + popTopAdjust) + 'px';
}

if(!document.onmouseover) {
	document.onmouseover = function(e) {
		var event = e ? e : window.event;
		showPopupText(event);
	};
}
