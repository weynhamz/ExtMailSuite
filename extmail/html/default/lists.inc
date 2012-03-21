var frm = document.preferences
var destList	= frm.destList;
var srcList		= frm.srcList;
var bttnRemove	= frm.Remove;
var bttnAdd		= frm.Add;
var aCh="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
var dCh="0123456789";
var asCh=aCh + dCh + ".-_+@";
var maxLength = 150;

if (destList.options.length > 2*maxLength)
frm.Add.disabled = 1;
function bttnRemove_refreshState()
{
if (destList && destList.selectedIndex >= 0)
{
frm.Remove.disabled = false;
frm.Remove.className = "A";
}
else
{
frm.Remove.disabled = true;
frm.Remove.className = "B";
}
}
function addToTheList(allowDomain)
{
var currentLength = destList.length;
var theStr = srcList.value.toLowerCase();
var count = 0;
var domainStr = ValidateDomain( theStr );
var emailStr  = ValidateLooseEmail( theStr );
var domainCount=0, emailCount=0;
var userEmail = "<%USER%>";
if ( domainStr == "" && emailStr == "")
{
alert("<%input_err2%>");
srcList.select();
srcList.focus();
return false;
}
if ( emailStr == userEmail)
{
alert("<%input_warn1%>");
srcList.select();
srcList.focus();
return false;
}
else if (domainStr != "" && allowDomain==false)
{
alert("<%input_warn2%>");
srcList.select();
srcList.focus();
return false;
}
else
{
theStr = (emailStr != "" ? emailStr : domainStr);
srcList.value = theStr;
}
for ( count=0; count<=currentLength && destList.options[count] != null; count++)
{
var localStr = destList.options[count].text.toLowerCase();
if ( ValidateDomain(localStr) != "" )	domainCount++;
if ( ValidateLooseEmail(localStr) != "" )	emailCount++;
if ( domainCount >= maxLength || emailCount >= maxLength )
{
if ( (ValidateDomain(theStr) != "" && domainCount >= maxLength) || (ValidateLooseEmail(theStr) != "" && emailCount >= maxLength) )
{
if (domainCount >= maxLength && emailCount >= maxLength)
bttnAdd.disabled = 1;
alert("<%input_warn3%>");
srcList.value="";
srcList.focus();
return false;
}
}
if (theStr == localStr)
{
alert(theStr + "<%already_exist%>");
srcList.select();
srcList.focus();
return false;	    
}
}
destList.options[currentLength] = new Option(theStr);
srcList.value = "";
srcList.focus();
bttnRemove_refreshState();
return true;
}
function removeFromTheList()
{
while (destList.selectedIndex>=0)
{
destList.options[destList.selectedIndex] = null;
}
if (destList.options.length < 2*maxLength)
bttnAdd.disabled = 0;
bttnRemove.disabled = 1;
srcList.focus();
bttnRemove_refreshState();
}
function removeDeleteLRU()
{
destList.options[0] = null;
}
function disableToggle(tf)
{
for (x = 5; x <= frm.length - 4; x++)
{
frm.elements[x].disabled=tf;
}
}
function buildwhitelists()
{
var white = frm.whitelists;
var len = destList.options.length;
for(var i = 0; i < len; i++)
{
white.value += destList.options[i].text + " ";
}
}
function buildblacklists()
{
var black = frm.blacklists;
var len = destList.options.length;
for(var i = 0; i< len; i++)
{
black.value += destList.options[i].text + " ";
}
}
function buildAllLists(buildType)
{
if (buildType == 'white') {
buildwhitelists();
return true;
}
if (buildType == 'black') {
buildblacklists();
return true;
}
}

function ValidateEmail(S)
{
var R=false;
if (typeof(S) != "undefined")
{
if
(/^([a-zA-Z0-9_\-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$/.test(S))
R=S;
}
return R;
}

function ValidateLooseEmail(S){
var resultS=S.replace(/ /gi, "");
var atIndex  =resultS.indexOf("@");
var dotIndex =resultS.lastIndexOf(".");
if( resultS == "" || !isASCII(resultS) || dotIndex == -1)
return "";
if ( resultS.lastIndexOf("@") != atIndex || resultS.charAt(atIndex+1) == ".")
return "";
if ( atIndex <= 0 || dotIndex < atIndex ||  dotIndex >= resultS.length-1)
return "";
return resultS;
}

function ValidateDomain(S){
var resultS=S.replace(/ /gi, "");
var atIndex  =resultS.indexOf("@");
var dotIndex =resultS.lastIndexOf(".");
if( resultS=="" || !isASCII(resultS) || dotIndex == -1)
return "";
if ( atIndex > 0 || resultS.charAt(atIndex+1) == "." || dotIndex >=resultS.length-1 )
return "";
return resultS.replace(/@/i, "");
}

function isASCII(S){
for (var i=0; i < S.length; i++)
{
if (asCh.indexOf(S.charAt(i)) == -1)
return false;
}
return true;
}

function noEnterKey()
{
if (event.keyCode==13)
return false;
}
if (srcList != null)
srcList.focus();
