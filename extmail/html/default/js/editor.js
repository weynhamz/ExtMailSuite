var editbox = editwin = editdoc = null;
var cursor = -1;
var stack = new Array();

function newEditor(mode, initialtext) {

	wysiwyg = parseInt(mode);
	if(!(is_ie || is_moz || (is_opera && opera.version() >= 9))) {
		allowswitcheditor = wysiwyg = 0;
	}
	var bbcodemode = $('bbcodemode');
	var wysiwygmode = $('wysiwygmode');
	bbcodemode.className = wysiwyg ? 'editor_switcher' : 'editor_switcher_highlight';
	wysiwygmode.className = wysiwyg ? 'editor_switcher_highlight' : 'editor_switcher';
	if(!allowswitcheditor) {
		$(editorid + '_switcher').style.display = 'none';
	}

	//$(editorid + '_cmd_table').style.display = wysiwyg ? '' : 'none';
	$('posteditor_controls').style.display = wysiwyg ? '' : 'none';

	if(wysiwyg) {
		if($(editorid + '_iframe')) {
			editbox = $(editorid + '_iframe');
		} else {
			var iframe = document.createElement('iframe');
			editbox = textobj.parentNode.appendChild(iframe);
			editbox.id = editorid + '_iframe';
		}

		editwin = editbox.contentWindow;
		editdoc = editwin.document;

		writeEditorContents(isUndefined(initialtext) ?  textobj.value : initialtext);
	} else {
		editbox = textobj;
		editwin = textobj;
		editdoc = textobj;
		if(!isUndefined(initialtext)) {
			writeEditorContents(initialtext);
		}
		addSnapshot(textobj.value);
	}
	setEditorEvents();
}


function writeEditorContents(text) {
	if(wysiwyg) {
		if(text == '' && is_moz) {
			text = '<br />';
		}
		if(editdoc && editdoc.initialized) {
			editdoc.body.innerHTML = text;
		} else {
			editdoc.designMode = 'on';
			editdoc = editwin.document;
			editdoc.open('text/html', 'replace');
			editdoc.write(text);
			editdoc.close();
			editdoc.body.contentEditable = true;
			editdoc.initialized = true;
		}
	} else {
		textobj.value = text;
	}

	setEditorStyle();

}

function getEditorContents() {
	return wysiwyg ? editdoc.body.innerHTML : editdoc.value;
}

function setEditorStyle() {
	if(wysiwyg) {
		textobj.style.display = 'none';
		editbox.style.display = '';

		if(is_moz || is_opera) {
			for(var ss = 0; ss < document.styleSheets.length; ss++) {
				if(document.styleSheets[ss].cssRules.length <= 0) {
					continue;
				}
				for(var i = 0; i < document.styleSheets[ss].cssRules.length; i++) {
					if(document.styleSheets[ss].cssRules[i].selectorText == '.wysiwyg') {
						var newss = editdoc.createElement('style');
						newss.type = 'text/css';
						newss.innerHTML = document.styleSheets[ss].cssRules[i].cssText + ' p { margin: 0px; }';
						editdoc.documentElement.childNodes[0].appendChild(newss);
						editdoc.body.style.fontSize = document.styleSheets[ss].cssRules[i].style.fontSize;
						editdoc.body.style.fontFamily = document.styleSheets[ss].cssRules[i].style.fontFamily;
					}
				}
			}
			editbox.style.border = '0px';
		} else if(is_ie) {
			//if(document.styleSheets['css']) {
				//editdoc.createStyleSheet().cssText = document.styleSheets['css'].cssText + ' p { margin: 0px; }';
				editdoc.createStyleSheet().cssText = ' p { margin: 0px; }';
				editdoc.body.className = 'wysiwyg';

			//}
			editdoc.body.style.border = '1px';
			editdoc.body.style.fontSize = '12px';
			editdoc.body.style.fontFamily = 'Arial,ËÎÌו';
		}
		editbox.style.width = textobj.style.width;
		editbox.style.height = textobj.style.height;
		editdoc.body.style.background = '';
		editdoc.body.style.backgroundColor = '#FFFFFF';

	} else {
		var iframe = textobj.parentNode.getElementsByTagName('iframe')[0];
		if(iframe) {
			textobj.style.display = '';
			textobj.style.width = iframe.style.width;
			textobj.style.height = iframe.style.height;
			iframe.style.display = 'none';
		}
	}
}

function setEditorEvents() {
	if(wysiwyg) {
		if(is_moz || is_opera) {
			editdoc.addEventListener('mouseup', function(e) {setContext(); popupmenu.hide();}, true);
			editdoc.addEventListener('keyup', function(e) {setContext();}, true);
			editwin.addEventListener('focus', function(e) {this.hasfocus = true;}, true);
			editwin.addEventListener('blur', function(e) {this.hasfocus = false;}, true);
			editwin.addEventListener('keydown', function(e) {ctlent(e);}, true);
		} else {
			editdoc.onmouseup = function(e) {setContext(); popupmenu.hide();};
			editdoc.onkeyup = function(e) {setContext();};
			if(editdoc.attachEvent) {
				editdoc.body.attachEvent("onkeydown", ctlent);
			}
		}
	}
	editwin.onfocus = function(e) {this.hasfocus = true;};
	editwin.onblur = function(e) {this.hasfocus = false;};
}

function wrapTags(tagname, useoption, selection) {

	if(tagname=='code') {
		applyFormat('removeformat');
	}

	if(isUndefined(selection)) {
		var selection = getSel();
		if(selection === false) {
			selection = '';
		} else {
			selection += '';
		}
	}

	if(useoption === true) {
		var option = showPrompt(construct_phrase(lang['enter_tag_option'], ('[' + tagname + ']')), '');
		if(option = verifyPrompt(option)) {
			var opentag = '[' + tagname + '=' + option + ']';
		} else {
			return false;
		}
	} else if(useoption !== false) {
		var opentag = '[' + tagname + '=' + useoption + ']';
	} else {
		var opentag = '[' + tagname + ']';
	}

	var closetag = '[/' + tagname + ']';

	if (tagname=='quote')
	{
		opentag = '<blockquote class="extmail_quote" style="PADDING-LEFT: 1ex; MARGIN: 0px 0px 0px 0.8ex; BORDER-LEFT: #ccc 1px solid">';
		closetag = '</blockquote><br>';
	}

	var text = opentag + selection + closetag;

	insertText(text, mb_strlen(opentag), mb_strlen(closetag));

	return false;
}

function applyFormat(cmd, dialog, argument) {

	if(wysiwyg) {
		editdoc.execCommand(cmd, (isUndefined(dialog) ? false : dialog), (isUndefined(argument) ? true : argument));
		return false;
	}
	switch(cmd) {
		case 'bold':
		case 'italic':
		case 'underline':
			wrapTags(cmd.substr(0, 1), false);
			break;
		case 'justifyleft':
		case 'justifycenter':
		case 'justifyright':
			wrapTags('align', cmd.substr(7));
			break;
		case 'indent':
			wrapTags(cmd, false);
			break;
		case 'fontname':
			wrapTags('font', argument);
			break;
		case 'fontsize':
			wrapTags('size', argument);
			break;
		case 'forecolor':
			wrapTags('color', argument);
			break;
		case 'createlink':
			var sel = getSel();
			if(sel) {
				wrapTags('url', argument);
			} else {
				wrapTags('url', argument, argument);
			}
			break;
		case 'insertimage':
			wrapTags('img', false, argument);
			break;
	}
}

function customTags(tagname, params) {
	applyFormat('removeformat');

	if(custombbcodes[tagname].indexOf(']') == -1) {
		custombbcodes[tagname] = '[' + tagname + '][/' + tagname + ']';
	}

	if(params == 1) {
		var selection = getSel();
		if(selection === false) {
			selection = '';
		} else {
			selection += '';
		}

		var opentag = '[' + tagname + ']';
		var closetag = '[/' + tagname + ']';
		var text = opentag + selection + closetag;
		selection == '' ? insertText(custombbcodes[tagname], mb_strlen('[' + tagname + ']'), mb_strlen('[/' + tagname + ']')) : insertText(text, mb_strlen(opentag), mb_strlen(closetag));
	} else {
		insertText(custombbcodes[tagname], custombbcodes[tagname].indexOf(']') + 1, mb_strlen('[/' + tagname + ']'));
	}

	return false;
}

function discuzcode(cmd, arg) {
	if(cmd != 'redo') {
		addSnapshot(getEditorContents());
	}

	checkFocus();

	if(in_array(cmd, ['quote', 'code'])) {
		var ret = wrapTags(cmd, false);
	} else if(cmd.substr(0, 6) == 'custom') {
		var ret = customTags(cmd.substr(8), cmd.substr(6, 1));
	} else if(!wysiwyg && cmd == 'removeformat') {
		var simplestrip = new Array('b', 'i', 'u');
		var complexstrip = new Array('font', 'color', 'size');

		var str = getSel();
		if(str === false) {
			return;
		}
		for(var tag in simplestrip) {
			str = stripSimple(simplestrip[tag], str);
		}
		for(var tag in complexstrip) {
			str = stripComplex(complexstrip[tag], str);
		}
		insertText(str);
	} else if(!wysiwyg && cmd == 'undo') {
		addSnapshot(getEditorContents());
		moveCursor(-1);
		if((str = getSnapshot()) !== false) {
			editdoc.value = str;
		}
	} else if(!wysiwyg && cmd == 'redo') {
		moveCursor(1);
		if((str = getSnapshot()) !== false) {
			editdoc.value = str;
		}
	} else if(!wysiwyg && in_array(cmd, ['insertorderedlist', 'insertunorderedlist'])) {
		var listtype = cmd == 'insertorderedlist' ? '1' : '';
		var opentag = '[list' + (listtype ? ('=' + listtype) : '') + ']\n';
		var closetag = '[/list]';

		if(txt = getSel()) {
			var regex = new RegExp('([\r\n]+|^[\r\n]*)(?!\\[\\*\\]|\\[\\/?list)(?=[^\r\n])', 'gi');
			txt = opentag + trim(txt).replace(regex, '$1[*]') + '\n' + closetag;
			insertText(txt, mb_strlen(txt), 0);
		} else {
			insertText(opentag + closetag, opentag.length, closetag.length);

			while(listvalue = prompt(lang['enter_list_item'], '')) {
				if(is_opera && opera.version() > 8) {
					listvalue = '\n' + '[*]' + listvalue;
					insertText(listvalue, mb_strlen(listvalue) + 1, 0);
				} else {
					listvalue = '[*]' + listvalue + '\n';
					insertText(listvalue, mb_strlen(listvalue), 0);
				}
			}
		}
	} else if(!wysiwyg && cmd == 'outdent') {
		var sel = getSel();
		sel = stripSimple('indent', sel, 1);
		insertText(sel);
	} else if(cmd == 'createlink') {
		if(wysiwyg) {
			if(is_moz || is_opera) {
				var url = showPrompt(lang['enter_link_url'], 'http://');
				if((url = verifyPrompt(url)) !== false) {
					if(getSel()) {
						applyFormat('unlink');
						applyFormat('createlink', is_ie, (isUndefined(url) ? true : url));
					} else {
						insertText('<a href="' + url + '">' + url + '</a>');
					}
				}
			} else {
				applyFormat('createlink', is_ie, (isUndefined(url) ? true : url));
			}
		} else {
			promptLink('url', lang['enter_link_url'], 'http://');
		}
	} else if(!wysiwyg && cmd == 'unlink') {
		var sel = getSel();
		sel = stripSimple('url', sel);
		sel = stripComplex('url', sel);
		insertText(sel);
	} else if(cmd == 'email') {
		if(wysiwyg) {
			var email = showPrompt(lang['enter_email_link'], '');
			email = verifyPrompt(email);

			if(email === false) {
				applyFormat('unlink');
			} else {
				var selection = getSel();
				insertText('<a href="mailto:' + email + '">' + (selection ? selection : email) + '</a>', (selection ? true : false));
			}
		} else {
			promptLink('email', lang['enter_email_link'], '');
		}
	} else if(cmd == 'insertimage') {
		var img = showPrompt(lang['enter_image_url'], 'http://');
		if(img = verifyPrompt(img)) {
			return applyFormat('insertimage', false, img);
		} else {
			return false;
		}
	} else if(cmd == 'table') {
		if(wysiwyg) {
			if(isUndefined(rows)) {
				var rows = showPrompt(lang['enter_table_rows'], '2');
			}
			if(rows != 'null' && isUndefined(columns)) {
				var columns = showPrompt(lang['enter_table_columns'], '2');
			}
			if(!isUndefined(columns) && columns != 'null') {
				rows = /^[-\+]?\d+$/.test(rows) && rows > 0 && rows <= 30 ? rows : 2;
				columns = /^[-\+]?\d+$/.test(columns) && columns > 0 && columns <= 30 ? columns : 2;
				var html = '<table cellspacing="1" cellpadding="4" width="50%" align="center" style="background: ' + BORDERCOLOR + '">';
				for (var row = 0; row < rows; row++) {
					html += '<tr bgcolor="' + ALTBG2 + '">\n';
					for (col = 0; col < columns; col++) {
						html += '<td>&nbsp;</td>\n';
					}
					html+= '</tr>\n';
				}
				html += '</table>\n';
				insertText(html);
			}
		}
		return false;
	} else {
		var ret = applyFormat(cmd, false, (isUndefined(arg) ? true : arg));
	}

	if(cmd != 'undo') {
		addSnapshot(getEditorContents());
	}
	if(wysiwyg) {
		setContext(cmd);
		if(cmd == 'forecolor') {
			$(editorid + '_color_bar').style.backgroundColor = arg;
		}
	}
	checkFocus();
	return ret;
}

function setContext(cmd) {
	var contextcontrols = new Array('bold', 'italic', 'underline', 'justifyleft', 'justifycenter', 'justifyright', 'insertorderedlist', 'insertunorderedlist');
	for(var i in contextcontrols) {
		var obj = $(editorid + '_cmd_' + contextcontrols[i]);
		if(obj != null) {
			try {
				var state = editdoc.queryCommandState(contextcontrols[i]);
			} catch(e) {
				var state = false;
			}
			if(isUndefined(obj.state)) {
				obj.state = false;
			}
			if(obj.state != state) {
				obj.state = state;
				buttonContext(obj, (obj.id.substr(obj.id.indexOf('_cmd_') + 5) == cmd ? 'mouseover' : 'mouseout'));
			}
		}
	}

	var fs = editdoc.queryCommandValue('fontname');
	if(fs == '' && !is_ie && window.getComputedStyle) {
		fs = editdoc.body.style.fontFamily;
	} else if(fs == null) {
		fs = '';
	}
	if(fs != $(editorid + '_font_out').fontstate) {
		thingy = fs.indexOf(',') > 0 ? fs.substr(0, fs.indexOf(',')) : fs;
		$(editorid + '_font_out').innerHTML = thingy;
		$(editorid + '_font_out').fontstate = fs;
	}

	var ss = editdoc.queryCommandValue('fontsize');
	if(ss == null || ss == '') {
		ss = formatFontsize(editdoc.body.style.fontSize);
	}
	if(ss != $(editorid + '_size_out').sizestate) {
		if($(editorid + '_size_out').sizestate == null) {
			$(editorid + '_size_out').sizestate = '';
		}
		$(editorid + '_size_out').innerHTML = ss;
		$(editorid + '_size_out').sizestate = ss;
	}

	var cs = editdoc.queryCommandValue('forecolor');
	$(editorid + '_color_bar').style.backgroundColor = rgbToColor(cs);
}

function buttonContext(obj, state) {
	if(state == 'mouseover') {
		var mode = obj.state ? 'down' : 'hover';
		if(obj.mode != mode) {
			obj.mode = mode;
			obj.className = 'editor_button' + mode;
		}
	} else {
		var mode = obj.state ? 'selected' : 'normal';
		if(obj.mode != mode) {
			obj.mode = mode;
			obj.className = mode == 'selected' ? 'editor_buttonselected' : 'editor_button' + 'normal';
		}
	}
	if(is_ie && event) {
		event.cancelBubble = true;
	}
}

function menuContext(obj, state) {
	obj.style.cursor = is_ie ? 'hand' : 'pointer';
	var mode = state == 'mouseover' ? 'hover' : 'normal';
	obj.className = 'editor_button' + mode;
	var tds = findtags(obj, 'td');
	for(var i = 0; i < tds.length; i++) {
		if(tds[i].id == editorid + '_menu') {
			tds[i].className = 'editor_menu' + mode;
		} else if(tds[i].id == editorid + '_colormenu') {
			tds[i].className = 'editor_colormenu' + mode;
		}
	}
}

function colorContext(obj, state) {
	obj.style.cursor = is_ie ? 'hand' : 'pointer';
	var mode = state == 'mouseover' ? 'hover' : 'normal';
	obj.className = 'editor_color' + mode;
}

function getSel() {
	if(wysiwyg) {
		if(is_moz || is_opera) {
			selection = editwin.getSelection();
			checkFocus();
			range = selection ? selection.getRangeAt(0) : editdoc.createRange();
			return readNodes(range.cloneContents(), false);
		} else {
			var range = editdoc.selection.createRange();
			if(range.htmlText && range.text) {
				return range.htmlText;
			} else {
				var htmltext = '';
				for(var i = 0; i < range.length; i++) {
					htmltext += range.item(i).outerHTML;
				}
				return htmltext;
			}
		}
	} else {
		if(!isUndefined(editdoc.selectionStart)) {
			return editdoc.value.substr(editdoc.selectionStart, editdoc.selectionEnd - editdoc.selectionStart);
		} else if(document.selection && document.selection.createRange) {
			return document.selection.createRange().text;
		} else if(window.getSelection) {
			return window.getSelection() + '';
		} else {
			return false;
		}
	}
}

function insertText(text, movestart, moveend) {
	if(wysiwyg) {
		if(is_moz || is_opera) {
			var fragment = editdoc.createDocumentFragment();
			var holder = editdoc.createElement('span');
			holder.innerHTML = text;

			while(holder.firstChild) {
				fragment.appendChild(holder.firstChild);
			}
			insertNodeAtSelection(fragment);
		} else {
			checkFocus();
			if(!isUndefined(editdoc.selection) && editdoc.selection.type != 'Text' && editdoc.selection.type != 'None') {
				movestart = false;
				editdoc.selection.clear();
			}

			var sel = editdoc.selection.createRange();

			sel.pasteHTML(text);

			if(text.indexOf('\n') == -1) {
				if(!isUndefined(movestart)) {
					sel.moveStart('character', -mb_strlen(text) +movestart);
					sel.moveEnd('character', -moveend);
				} else if(movestart != false) {
					sel.moveStart('character', -mb_strlen(text));
				}
			}
		}
	} else {

		checkFocus();
		if(!isUndefined(editdoc.selectionStart)) {

			var opn = editdoc.selectionStart + 0;

			editdoc.value = editdoc.value.substr(0, editdoc.selectionStart) + text + editdoc.value.substr(editdoc.selectionEnd);

			if(!isUndefined(movestart)) {
				editdoc.selectionStart = opn + movestart;
				editdoc.selectionEnd = opn + mb_strlen(text) - moveend;
			} else if(movestart !== false) {
				editdoc.selectionStart = opn;
				editdoc.selectionEnd = opn + mb_strlen(text);
			}
		} else if(document.selection && document.selection.createRange) {

			var sel = document.selection.createRange();
			sel.text = text.replace(/\r?\n/g, '\r\n');

			if(!isUndefined(movestart)) {
				sel.moveStart('character', -mb_strlen(text) +movestart);
				sel.moveEnd('character', -moveend);
			} else if(movestart !== false) {
				sel.moveStart('character', -mb_strlen(text));
			}
			sel.select();
		} else {
			editdoc.value += text;
		}
	}
}

function isUndefined(variable) {
	return typeof variable == 'undefined' ? true : false;
}


function showPrompt(dialogtxt, defaultval) {
	return trim(prompt(dialogtxt, defaultval) + '');
}

function verifyPrompt(str) {
	if(in_array(str, ['http://', 'null', 'undefined', 'false', '']) || str == null || str == false) {
		return false;
	} else {
		return str;
	}
}

function promptLink(tagname, phrase, iprompt) {
	var value = showPrompt(phrase, iprompt);
	if((value = verifyPrompt(value)) !== false) {
		if(getSel()) {
			applyFormat('unlink');
			wrapTags(tagname, value);
		} else {
			wrapTags(tagname, value, value);
		}
	}
	return true;
}

function trim(str) {
	return (str.replace(/(\s+)$/g, '')).replace(/^\s+/g, '');
}

function stripSimple(tag, str, iterations) {
	var opentag = '[' + tag + ']';
	var closetag = '[/' + tag + ']';

	if(isUndefined(iterations)) {
		iterations = -1;
	}
	while((startindex = stripos(str, opentag)) !== false && iterations != 0) {
		iterations --;
		if((stopindex = stripos(str, closetag)) !== false) {
			var text = str.substr(startindex + opentag.length, stopindex - startindex - opentag.length);
			str = str.substr(0, startindex) + text + str.substr(stopindex + closetag.length);
		} else {
			break;
		}
	}
	return str;
}

function stripComplex(tag, str, iterations) {
	var opentag = '[' + tag + '=';
	var closetag = '[/' + tag + ']';

	if(isUndefined(iterations)) {
		iterations = -1;
	}
	while((startindex = stripos(str, opentag)) !== false && iterations != 0) {
		iterations --;
		if((stopindex = stripos(str, closetag)) !== false) {
			var openend = stripos(str, ']', startindex);
			if(openend !== false && openend > startindex && openend < stopindex) {
				var text = str.substr(openend + 1, stopindex - openend - 1);
				str = str.substr(0, startindex) + text + str.substr(stopindex + closetag.length);
			} else {
				break;
			}
		} else {
			break;
		}
	}
	return str;
}

function stripos(haystack, needle, offset) {
	if(isUndefined(offset)) {
		offset = 0;
	}
	var index = haystack.toLowerCase().indexOf(needle.toLowerCase(), offset);

	return (index == -1 ? false : index);
}

function switchEditor(mode) {

	mode = parseInt(mode);
	if(mode == wysiwyg || !allowswitcheditor)  {

		return;
	}

	// confirm to switch to textmode (mode ==0)
	if (mode == 0 && !confirm(lang['cfm_fmtext'])) {
		return;
        }

	if(!mode) {
		var controlbar = $(editorid + '_controls');
		var controls = new Array();
		var buttons = findtags(controlbar, 'div');
		var buttonslength = buttons.length;
		for(var i = 0; i < buttonslength; i++) {
			if(buttons[i].id) {
				controls[controls.length] = buttons[i].id;
			}
		}
		var controlslength = controls.length;
		for(var i = 0; i < controlslength; i++) {
			var control = $(controls[i]);

			if(control.id.indexOf(editorid + '_cmd_') != -1) {
				control.className = 'editor_buttonnormal';
				control.state = false;
				control.mode = 'normal';
			} else if(control.id.indexOf(editorid + '_popup_') != -1) {
				control.state = false;
			}
		}
	}
	cursor = -1;
	stack = new Array();
	$(editorid + '_font_out').innerHTML = lang['fontname'];
	$(editorid + '_size_out').innerHTML = lang['fontsize'];
	$(editorid + '_font_out').fontstate = null;
	$(editorid + '_size_out').sizestate = null;
	$(editorid + '_color_bar').style.backgroundColor = '#000000';
	var parsedtext = getEditorContents();
	//parsedtext = mode ? bbcode2html(parsedtext) : html2bbcode(parsedtext);
	parsedtext = mode ? escapeHTML(parsedtext) : unescapeHTML(parsedtext);

	wysiwyg = mode;
	$(editorid + '_mode').value = mode;

	newEditor(mode, parsedtext);
	checkFocus();
}

function formatFontsize(csssize) {
	switch(csssize) {
		case '7.5pt':
		case '10px': return 1;
		case '10pt': return 2;
		case '12pt': return 3;
		case '14pt': return 4;
		case '18pt': return 5;
		case '24pt': return 6;
		case '36pt': return 7;
		default:     return lang['fontsize'];
	}
}

function rgbToColor(forecolor) {
	if(!is_moz && !is_opera) {
		return rgbhexToColor((forecolor & 0xFF).toString(16), ((forecolor >> 8) & 0xFF).toString(16), ((forecolor >> 16) & 0xFF).toString(16));
	}
	if(forecolor == '' || forecolor == null) {
		forecolor = window.getComputedStyle(editdoc.body, null).getPropertyValue('color');
	}
	if(forecolor.toLowerCase().indexOf('rgb') == 0) {
		var matches = forecolor.match(/^rgb\s*\(([0-9]+),\s*([0-9]+),\s*([0-9]+)\)$/);
		if(matches) {
			return rgbhexToColor((matches[1] & 0xFF).toString(16), (matches[2] & 0xFF).toString(16), (matches[3] & 0xFF).toString(16));
		} else {
			return rgbToColor(null);
		}
	} else {
		return forecolor;
	}
}

function rgbhexToColor(r, g, b) {
	var coloroptions = {'#000000' : 'Black', '#a0522d' : 'Sienna', '#556b2f' : 'DarkOliveGreen', '#006400' : 'DarkGreen', '#483d8b' : 'DarkSlateBlue', '#000080' : 'Navy', '#4b0082' : 'Indigo', '#2f4f4f' : 'DarkSlateGray', '#8b0000' : 'DarkRed', '#ff8c00' : 'DarkOrange', '#808000' : 'Olive', '#008000' : 'Green', '#008080' : 'Teal', '#0000ff' : 'Blue', '#708090' : 'SlateGray', '#696969' : 'DimGray', '#ff0000' : 'Red', '#f4a460' : 'SandyBrown', '#9acd32' : 'YellowGreen', '#2e8b57' : 'SeaGreen', '#48d1cc' : 'MediumTurquoise', '#4169e1' : 'RoyalBlue', '#800080' : 'Purple', '#808080' : 'Gray', '#ff00ff' : 'Magenta', '#ffa500' : 'Orange', '#ffff00' : 'Yellow', '#00ff00' : 'Lime', '#00ffff' : 'Cyan', '#00bfff' : 'DeepSkyBlue', '#9932cc' : 'DarkOrchid', '#c0c0c0' : 'Silver', '#ffc0cb' : 'Pink', '#f5deb3' : 'Wheat', '#fffacd' : 'LemonChiffon', '#98fb98' : 'PaleGreen', '#afeeee' : 'PaleTurquoise', '#add8e6' : 'LightBlue', '#dda0dd' : 'Plum', '#ffffff' : 'White'};
	return coloroptions['#' + (str_pad(r, 2, 0) + str_pad(g, 2, 0) + str_pad(b, 2, 0))];
}

function str_pad(text, length, padstring) {
	text += '';
	padstring += '';

	if(text.length < length) {
		padtext = padstring;

		while(padtext.length < (length - text.length)) {
			padtext += padstring;
		}

		text = padtext.substr(0, (length - text.length)) + text;
	}

	return text;
}

function insertNodeAtSelection(text) {
	checkFocus();

	var sel = editwin.getSelection();
	var range = sel ? sel.getRangeAt(0) : editdoc.createRange();
	sel.removeAllRanges();
	range.deleteContents();

	var node = range.startContainer;
	var pos = range.startOffset;

	switch(node.nodeType) {
		case Node.ELEMENT_NODE:
			if(text.nodeType == Node.DOCUMENT_FRAGMENT_NODE) {
				selNode = text.firstChild;
			} else {
				selNode = text;
			}
			node.insertBefore(text, node.childNodes[pos]);
			add_range(selNode);
			break;

		case Node.TEXT_NODE:
			if(text.nodeType == Node.TEXT_NODE) {
				var text_length = pos + text.length;
				node.insertData(pos, text.data);
				range = editdoc.createRange();
				range.setEnd(node, text_length);
				range.setStart(node, text_length);
				sel.addRange(range);
			} else {
				node = node.splitText(pos);
				var selNode;
				if(text.nodeType == Node.DOCUMENT_FRAGMENT_NODE) {
					selNode = text.firstChild;
				} else {
					selNode = text;
				}
				node.parentNode.insertBefore(text, node);
				add_range(selNode);
			}
			break;
	}
}

function add_range(node) {
	checkFocus();
	var sel = editwin.getSelection();
	var range = editdoc.createRange();
	range.selectNodeContents(node);
	sel.removeAllRanges();
	sel.addRange(range);
}

function readNodes(root, toptag) {
	var html = "";
	var moz_check = /_moz/i;

	switch(root.nodeType) {
		case Node.ELEMENT_NODE:
		case Node.DOCUMENT_FRAGMENT_NODE:
			var closed;
			if(toptag) {
				closed = !root.hasChildNodes();
				html = '<' + root.tagName.toLowerCase();
				var attr = root.attributes;
				for(var i = 0; i < attr.length; ++i) {
					var a = attr.item(i);
					if(!a.specified || a.name.match(moz_check) || a.value.match(moz_check)) {
						continue;
					}
					html += " " + a.name.toLowerCase() + '="' + a.value + '"';
				}
				html += closed ? " />" : ">";
			}
			for(var i = root.firstChild; i; i = i.nextSibling) {
				html += readNodes(i, true);
			}
			if(toptag && !closed) {
				html += "</" + root.tagName.toLowerCase() + ">";
			}
			break;

		case Node.TEXT_NODE:
			html = htmlspecialchars(root.data);
			break;
	}
	return html;
}

function moveCursor(increment) {
	var test = cursor + increment;
	if(test >= 0 && stack[test] != null && !isUndefined(stack[test])) {
		cursor += increment;
	}
}

function addSnapshot(str) {
	if(stack[cursor] == str) {
		return;
	} else {
		cursor++;
		stack[cursor] = str;

		if(!isUndefined(stack[cursor + 1])) {
			stack[cursor + 1] = null;
		}
	}
}

function getSnapshot() {
	if(!isUndefined(stack[cursor]) && stack[cursor] != null) {
		return stack[cursor];
	} else {
		return false;
	}
}
