<%total_page%><b><%TOTAL_PAGES%></b>&nbsp;
<button onclick="javascript:JumpTo();"><%jumpto%></button>
<input name=jumpto id=jumpto value="1" style="width: 30px"><%page%>

<script language="javascript">
	var total_pages = '<%TOTAL_PAGES%>';
        var url = document.location.href;
        var keyword = url.match(/keyword=([^&]+)/i);
        var ftype =   url.match(/ftype=([^&]+)/i);
        var page =    url.match(/page=(\d+)/i);
        url = url.replace(/&keyword=[^&]*/i, "").replace(/&ftype=[^&]*/i, "").replace(/&page=\d*/i, "");

        if (keyword)
                url += '&keyword=' + keyword[1];
        if (ftype)
                url += '&ftype=' + ftype[1];
function JumpTo() {
	var to = document.getElementById('jumpto').value;

	if (to>=1 && to<=total_pages) {
		to --;
		url += '&page='+to;
		document.location.href = url;
	} else {
		alert('<%err_jumpto%>');
	}
}
</script>
