var etnews_lang = [];

etnews_lang['en_US'] = [];
etnews_lang['en_US']['loading'] = "Loading...";
etnews_lang['en_US']['nonews'] = "No News Available";

etnews_lang['zh_CN'] = [];
etnews_lang['zh_CN']['loading'] = "&#36733;&#20837;&#20013;&#8230;&#8230;";
etnews_lang['zh_CN']['nonews'] = "&#26242;&#26080;&#21487;&#29992;&#26032;&#38395;";

etnews_lang['zh_TW'] = [];
etnews_lang['zh_TW']['loading'] = "&#36617;&#20837;&#20013;&#8230;&#8230;";
etnews_lang['zh_TW']['nonews'] = "&#26283;&#28961;&#21487;&#29992;&#26032;&#32862;";

function get_etnews() {
    var etnews_container = document.getElementById('etnews_container');
    etnews_container.innerHTML = ['<div id="etnews_hint">', etnews_lang[userlang]['loading'], '</div>'].join('');
    if (etnews_rpc != null) {
        window.setTimeout(["etnews_rpc.get_etnews('", userlang, "', get_etnews_callback);"].join(''), 100);
    }
    else {
        window.setTimeout(["get_etnews('", userlang, "');"].join(''), 100);
    }
}

function get_etnews_callback(result) {
    if (result instanceof PHPRPC_Error) {
        var etnews_hint = document.getElementById('etnews_hint');
        etnews_hint.innerHTML = '<span style="color: red">' + result.errstr + '</span>';
    }
    else {
        var etnews_container = document.getElementById('etnews_container');
        etnews_container.innerHTML = result;
        set_cookie('rpc_etnews', result, 3*3600*1000);
    }
}

function etnews_init() {
    var etnews_container = document.getElementById('etnews_container');
    var news = get_cookie('rpc_etnews');

    if (!rpc_plg_enable('etnews')) {
	etnews_container.innerHTML = ['<div id="etnews_hint">', etnews_lang[userlang]['nonews'], '</div>'].join('');
	return;
    } else {
	var div = document.getElementById('etnews_div');
	div.style.display = "block";
    }

    if (news == null) {
        get_etnews();
    }
    else {
        etnews_container.innerHTML = news;
    }
}
