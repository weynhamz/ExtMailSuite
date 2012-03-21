<script language="javascript">
function GrpAdd() {
	var url ='abook.cgi?__mode=group_edit&sid=<%SID%>&edit=&screen=group_edit.html';
	document.location.href = url;
}

function GrpEdit(id) {
	var url ='abook.cgi?__mode=group_edit&sid=<%SID%>&edit=&editid=';
	url += id;
	url += '&screen=group_edit.html';
	document.location.href = url;
}

function GrpDelete(id) {
	if(confirm("<%confirm%>")) {
		var url = 'abook.cgi?__mode=group_edit&sid=<%SID%>&delete=true&delid='+id;
		url += '&screen=group_edit.html';
		document.location.href = url;
	}
}
</script>

<div class="panelout" style="margin: 0 5 5 5; width: 220px">
  <div class="paneltit" style="padding-top: 5px;text-align:right">
    <span style="float:left;left:0px">&nbsp;<%group%></span>
    <span><a href="javascript:GrpAdd();">&gt;&gt;<%add%></a>&nbsp;</span>
  </div>
  <div class="panelin">
  <!-- IF HAVE_GROUP -->
  <table cellspacing=0 cellpadding=0>
  <!-- BEGIN LOOP_GROUP -->
  <tr><td width=100%><a href="javascript:GrpEdit('<%ID%>');" title="<%view%> <%NAME%>"><%NAME%></a> (<%MEMBER_COUNT%>)</td>
  <td style="white-space: nowrap">
  <a href="javascript:GrpEdit('<%ID%>');" title="<%edit%>"><img src="/extmail/default/images/edit.gif"></a>
  <a href="javascript:GrpDelete('<%ID%>');" title="<%delete%>"><img src="/extmail/default/images/delete.gif"></a>
  </td>
  </tr>
  <!-- END LOOP_GROUP -->
  </table>
  <!-- ELSE HAVE_GROUP -->
  <%nogroup%>
  <!-- END HAVE_GROUP -->
  </div>
</div>
