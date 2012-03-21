var menuslidetimer = null;

function Popup_Handler() {
	this.open_steps = 2;
	this.open_fade = false;
	this.active = false;
	this.menus = new Array();
	this.activemenu = null;
	this.hidden_selects = new Array();

	this.activate = function(active) {
		this.active = active;
	}

	this.register = function(clickactive, controlkey, noimage) {
		this.menus[controlkey] = new Popup_Menu(clickactive, controlkey, noimage);
		return this.menus[controlkey];
	}

	this.hide = function() {
		if(this.activemenu != null) this.menus[this.activemenu].hide();
	}
}

function Popup_Events() {
	this.controlobj_show = function(e) {
		doane(e);
		clearTimeout(this.slidetimer);
		if(popupmenu.activemenu == null || popupmenu.menus[popupmenu.activemenu].controlkey != this.id)	{popupmenu.menus[this.id].show(this, false, popupmenu.menus[this.id].clickactive);}
	}

	this.controlobj_onclick = function(e) {
		doane(e);
		if(popupmenu.activemenu == null || popupmenu.menus[popupmenu.activemenu].controlkey != this.id)	{popupmenu.menus[this.id].show(this, false, popupmenu.menus[this.id].clickactive);}
		else {popupmenu.menus[this.id].hide();}
	}

	this.controlobj_onmouseover = function(e) {
		doane(e);
		popupmenu.menus[this.id].hover(this);
	}

	this.menuoption_onclick_function = function(e) {
		this.ofunc(e);
		popupmenu.menus[this.controlkey].hide();
	}

	this.menuoption_onclick_link = function(e) {
		popupmenu.menus[this.controlkey].choose(e, this);
	}

	this.menuoption_onmouseover = function(e) {
		this.className = 'popupmenu_highlight';
	}

	this.menuoption_onmouseout = function(e) {
		this.className = 'popupmenu_option';
	}
}

popupmenu = new Popup_Handler();
popupevents = new Popup_Events();

function popupmenu_hide(e) {
	if(e && e.button && e.button != 1 && e.type == 'click')  return true;
	else popupmenu.hide();
}

function Popup_Menu(clickactive, controlkey, noimage) {
	this.controlkey = controlkey;
	this.clickactive = clickactive;
	this.menuname = this.controlkey.split('.')[0] + '_menu';
	if($(this.menuname)) {this.init_menu(clickactive);}
	this.slide_open = (is_opera ? false : true);
	this.open_steps = popupmenu.open_steps;

	this.init_control = function(noimage) {
		this.controlobj = $(this.controlkey);
		this.controlobj.state = false;
		if(this.controlobj.firstChild && (this.controlobj.firstChild.tagName == 'TEXTAREA' || this.controlobj.firstChild.tagName == 'INPUT')) {
		} else {
			if(!this.clickactive && !noimage && !(is_mac && is_ie)) {
				var img = document.createElement('img');
				img.src = 'images/common/jsmenu.gif';
				img.border = 0;
				img.title = '';
				img.alt = '';
				this.controlobj.appendChild(img);
			}
			this.controlobj.unselectable = true;
			if(!noimage) {
				this.controlobj.style.cursor = is_ie ? 'hand' : 'pointer';
			}
			if(clickactive) {
				this.controlobj.onclick = popupevents.controlobj_onclick;
				this.controlobj.onmouseover = popupevents.controlobj_onmouseover;
			} else {
				this.controlobj.onmouseover = popupevents.controlobj_show;
			}
		}
	}

	this.init_control( noimage);

	this.init_menu = function() {
		this.menuobj = $(this.menuname);
		if(this.menuobj && !this.menuobj.initialized) {
			this.menuobj.initialized = true;
			this.menuobj.onclick = ebygum;
			this.menuobj.style.position = 'absolute';
			if(!this.clickactive) {
				this.menuobj.onmouseover = function() {
					clearTimeout(menuslidetimer);
				}
				this.menuobj.onmouseout = function() {
					menuslidetimer = setTimeout("menuhide()",500);
				}
			}
			this.menuobj.style.zIndex = 50;
			if(is_ie && !is_mac) {
				this.menuobj.style.filter += "progid:DXImageTransform.Microsoft.shadow(direction=135,color=#CCCCCC,strength=2)";
			}
			this.init_menu_contents();
		}
	}

	this.init_menu_contents = function() {
		var tds = findtags(this.menuobj, 'td');
		for(var i = 0; i < tds.length; i++) {
			if(tds[i].className == 'popupmenu_option' || tds[i].className == 'editor_colornormal') {
				if(is_ie && !is_mac) {
					tds[i].style.filter += "progid:DXImageTransform.Microsoft.Alpha(opacity=100,finishOpacity=100,style=0)";
				}
				tds[i].style.opacity = 1.00;
				if(tds[i].title && tds[i].title == 'nohighlight') {
					tds[i].title = '';
				} else {
					tds[i].controlkey = this.controlkey;
					if(tds[i].className != 'editor_colornormal') {
						tds[i].onmouseover = popupevents.menuoption_onmouseover;
						tds[i].onmouseout = popupevents.menuoption_onmouseout;
					}
					if(typeof tds[i].onclick == 'function') {
						tds[i].ofunc = tds[i].onclick;
						tds[i].onclick = popupevents.menuoption_onclick_function;
					} else {
						tds[i].onclick = popupevents.menuoption_onclick_link;
					}
					if(!is_saf && !is_kon)	{
						try {
							links = findtags(tds[i], 'a');
							for(var j = 0; j < links.length; j++) {
								if(typeof links[j].onclick  == 'undefined') links[j].onclick = ebygum;
							}
						}
						catch(e) {}
					}
				}
			}
		}
	}

	this.show = function(obj, instant) {
		if(!popupmenu.active){return false;}
		else if(!this.menuobj)	{this.init_menu();}
		if(!this.menuobj) {return false;}
		if(popupmenu.activemenu != null) {popupmenu.menus[popupmenu.activemenu].hide();}
		popupmenu.activemenu = this.controlkey;
		this.menuobj.style.display = '';
		if(popupmenu.slide_open) {this.menuobj.style.clip = 'rect(auto, auto, auto, auto)';}
		this.pos = this.fetch_offset(obj);
		this.leftpx = this.pos['left'];
		this.toppx = this.pos['top'] + obj.offsetHeight;
		if((this.leftpx + this.menuobj.offsetWidth) >= document.body.clientWidth && (this.leftpx + obj.offsetWidth - this.menuobj.offsetWidth) > 0) {
			this.leftpx = this.leftpx + obj.offsetWidth - this.menuobj.offsetWidth;
			this.direction = 'right';
		} else {this.direction = 'left';}
		this.menuobj.style.left = this.leftpx + 'px';
		this.menuobj.style.top  = this.toppx + 'px';
		if(!instant && this.slide_open) {
			this.intervalX = Math.ceil(this.menuobj.offsetWidth / this.open_steps);
			this.intervalY = Math.ceil(this.menuobj.offsetHeight / this.open_steps);
			this.slide((this.direction == 'left' ? 0 : this.menuobj.offsetWidth), 0, 0);
		} else if(this.menuobj.style.clip && popupmenu.slide_open) {
			this.menuobj.style.clip = 'rect(auto, auto, auto, auto)';
		}
		this.handle_overlaps(true);
		if(this.menuobj.scrollHeight > 400) {
			this.menuobj.style.height = '400px';
			if(is_ie || is_opera) {
				this.menuobj.style.width = this.menuobj.scrollWidth + 18;
			}
			if(is_opera) {
				this.menuobj.style.overflow = 'scroll';
			} else {
				this.menuobj.style.overflowY = 'scroll';
			}
		}
	}

	this.hide = function(e) {
		if(e && e.button && e.button != 1) {return true;}
		this.stop_slide();
		this.menuobj.style.display = 'none';
		this.handle_overlaps(false);
		popupmenu.activemenu = null;
	}

	this.slidehide = function() {
		popupmenu.menus[popupmenu.activemenu].hide()
	}

	this.hover = function(obj, clickactive) {
		if(popupmenu.activemenu != null) {
			if(popupmenu.menus[popupmenu.activemenu].controlkey != this.id) {this.show(obj, true, clickactive);}
		}
	}

	this.choose = function(e, obj) {
		var links = findtags(obj, 'a');
		if(links[0]) {
			if(is_ie) {
				links[0].click();
				window.event.cancelBubble = true;
			} else {
				if(e.shiftKey) {
					window.open(links[0].href);
					e.stopPropagation();
					e.preventDefault();
				} else {
					window.location = links[0].href;
					e.stopPropagation();
					e.preventDefault();
				}
			}
			this.hide();
		}
	}

	this.slide = function(clipX, clipY, opacity) {
		if(this.direction == 'left' && (clipX < this.menuobj.offsetWidth || clipY < this.menuobj.offsetHeight)) {
			if(popupmenu.open_fade && is_ie) {
				opacity += 10;
				this.menuobj.filters.item('DXImageTransform.Microsoft.alpha').opacity = opacity;
			}
			clipX += this.intervalX;
			clipY += this.intervalY;
			this.menuobj.style.clip = "rect(auto, " + clipX + "px, " + clipY + "px, auto)";
			this.slidetimer = setTimeout("popupmenu.menus[popupmenu.activemenu].slide(" + clipX + ", " + clipY + ", " + opacity + ");", 0);
		} else if(this.direction == 'right' && (clipX > 0 || clipY < this.menuobj.offsetHeight)) {
			if(popupmenu.open_fade && is_ie) {
				opacity += 10;
				menuobj.filters.item('DXImageTransform.Microsoft.alpha').opacity = opacity;
			}
			clipX -= this.intervalX;
			clipY += this.intervalY;
			this.menuobj.style.clip = "rect(auto, " + this.menuobj.offsetWidth + "px, " + clipY + "px, " + clipX + "px)";
			this.slidetimer = setTimeout("popupmenu.menus[popupmenu.activemenu].slide(" + clipX + ", " + clipY + ", " + opacity + ");", 0);
		} else {this.stop_slide();}
	}

	this.stop_slide = function() {
		clearTimeout(this.slidetimer);
		this.menuobj.style.clip = 'rect(auto, auto, auto, auto)';
		if(popupmenu.open_fade && is_ie) {this.menuobj.filters.item('DXImageTransform.Microsoft.alpha').opacity = 100;}
	}

	this.fetch_offset = function(obj) {
		var left_offset = obj.offsetLeft;
		var top_offset = obj.offsetTop;
		while ((obj = obj.offsetParent) != null) {
			left_offset += obj.offsetLeft;
			top_offset += obj.offsetTop;
		}
		return { 'left' : left_offset, 'top' : top_offset };
	}

	this.overlaps = function(obj, m) {
		var s = new Array();
		var pos = this.fetch_offset(obj);
		s['L'] = pos['left'];
		s['T'] = pos['top'];
		s['R'] = s['L'] + obj.offsetWidth;
		s['B'] = s['T'] + obj.offsetHeight;
		if(s['L'] > m['R'] || s['R'] < m['L'] || s['T'] > m['B'] || s['B'] < m['T']) {return false;}
		return true;
	}

	this.handle_overlaps = function(dohide) {
		if(is_ie) {
			var selects = findtags(document, 'select');
			if(dohide) {
				var menuarea = new Array(); menuarea = {
					'L' : this.leftpx,
					'R' : this.leftpx + this.menuobj.offsetWidth,
					'T' : this.toppx,
					'B' : this.toppx + this.menuobj.offsetHeight
				};
				for(var i = 0; i < selects.length; i++) {
					if(this.overlaps(selects[i], menuarea)) {
						var hide = true;
						var s = selects[i];
						while (s = s.parentNode) {
							if(s.className == 'popupmenu_popup') {
								hide = false;
								break;
							}
						}
						if(hide) {
							selects[i].style.visibility = 'hidden';
							arraypush(popupmenu.hidden_selects, i);
						}
					}
				}
			} else {
				while (true) {
					var i = arraypop(popupmenu.hidden_selects);
					if(typeof i == 'undefined' || i == null) break;
					else selects[i].style.visibility = 'visible';
				}
			}
		}
	}
}

function doane(eventobj) {
	if(!eventobj || is_ie)	{
		window.event.returnValue = false;
		window.event.cancelBubble = true;
		return window.event;
	} else {
		eventobj.stopPropagation();
		eventobj.preventDefault();
		return eventobj;
	}
}

function ebygum(eventobj) {
	if(!eventobj || is_ie) {
		window.event.cancelBubble = true;
		return window.event;
	} else {
		if(eventobj.target.type == 'submit')  eventobj.target.form.submit();
		eventobj.stopPropagation();
		return eventobj;
	}
}

function menuregister(clickactive, controlid, noimage, datefield) {
	if(typeof popupmenu == 'object') {
		popupmenu.register(clickactive, controlid, noimage);
	}
}

function menuhide() {
	if(popupmenu.activemenu != null) {
		popupmenu.menus[popupmenu.activemenu].slidehide();
	}
}

if(typeof popupmenu == 'object') {
	if(window.attachEvent && !is_saf) {
		document.attachEvent('onclick', popupmenu_hide);
		window.attachEvent('onresize', popupmenu_hide);
	} else if(document.addEventListener && !is_saf) {
		document.addEventListener('click', popupmenu_hide, false);
		window.addEventListener('resize', popupmenu_hide, false);
	} else {
		window.onclick = popupmenu_hide;
		window.onresize = popupmenu_hide;
	}
	popupmenu.activate(true);
}
