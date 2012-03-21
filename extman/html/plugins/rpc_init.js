// global control defination here
// rpc_url_list  - list of rpc servers

rpc_url_list = [
    "http://rpc-srv01.extmail.net/phprpc/rpc.php",
    "http://rpc-srv02.extmail.net/phprpc/rpc.php",
    "http://rpc-srv03.extmail.net/phprpc/rpc.php",
];

rpc = null;
chkupdate_rpc = null;

function rpc_ready() {
    if (rpc == null) {
        rpc = this;
        chkupdate_rpc = rpc;
    }
    else {
        this.dispose();
    }
}

function rpc_chklng() {
    var lng = get_cookie('rpc_lang');
    if (lng == null) {
        // rpc_lang is not set
        set_cookie('rpc_lang', userlang, 24*3600*1000);
    } else if (lng != userlang) {
        // rpc_lang is different with current lang
        delete_cookie('rpc_chkupdate');
        set_cookie('rpc_lang', userlang, 24*3600*1000);
    }
}

rpc_list = [];
for (i = 0; i < rpc_url_list.length; i++) {
    rpc_list[i] = new PHPRPC_Client();
    rpc_list[i].onready = rpc_ready;
    rpc_list[i].useService(rpc_url_list[i]);
}

function get_cookie(name) {
    function get_cookie_val(offset) {
        var endstr = document.cookie.indexOf(";", offset);
        if (endstr == -1) endstr = document.cookie.length;
        return unescape(document.cookie.substring(offset, endstr));
    }
    var arg = name + "=";
    var alen = arg.length;
    var clen = document.cookie.length;
    var i = 0;
    while (i < clen) {
        var j = i + alen;
        if (document.cookie.substring(i, j) == arg) return get_cookie_val(j);
        i = document.cookie.indexOf(" ", i) + 1;
        if (i == 0) break;
    }
    return null;
}

function set_cookie(name, value, expires) {
    var exp = new Date();
    if (expires) {
        exp.setTime(exp.getTime() + expires);
    }
    else {
        exp.setTime(exp.getTime() + 315360000000);
    }
    document.cookie = [name, "=", escape(value), "; expires=", exp.toGMTString(), ";"].join('');
}

function delete_cookie(name) {
    var exp = new Date();
    exp.setTime(exp.getTime() - 60000);
    document.cookie = [name, "=; expires=", exp.toGMTString(), ";"].join('');
}
