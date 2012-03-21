function md5(data){var add32=function(x,y){var lsw=(x&0xFFFF)+(y&0xFFFF);var msw=(x>>16)+(y>>16)+(lsw>>16);return(msw<<16)|(lsw&0xFFFF);};var bitrol=function(n,c){return(n<<c)|(n>>>(32-c));};var cmn=function(q,a,b,x,s,t){return add32(bitrol(add32(add32(a,q),add32(x,t)),s),b);};var ff=function(a,b,c,d,x,s,t){return cmn((b&c)|((~b)&d),a,b,x,s,t);};var gg=function(a,b,c,d,x,s,t){return cmn((b&d)|(c&(~d)),a,b,x,s,t);};var hh=function(a,b,c,d,x,s,t){return cmn(b^c^d,a,b,x,s,t);};var ii=function(a,b,c,d,x,s,t){return cmn(c^(b|(~d)),a,b,x,s,t);};var pack=function(b){var l=b.length<<2;var s=new Array(l);for(var i=0;i<l;i++){s[i]=String.fromCharCode((b[i>>2]>>>((i%4)<<3))&255);}
return s.join("");};var unpack=function(s){var l=s.length;var b=new Array();for(var i=0;i<l;i++){b[i>>2]|=(s.charCodeAt(i)&0xff)<<((i%4)<<3);}
return b;};var x=unpack(data);var len=data.length<<3;x[len>>5]|=0x80<<((len)%32);x[(((len+64)>>>9)<<4)+14]=len;var a=1732584193;var b=-271733879;var c=-1732584194;var d=271733878;for(var i=0;i<x.length;i+=16){var olda=a;var oldb=b;var oldc=c;var oldd=d;a=ff(a,b,c,d,x[i+0],7,-680876936);d=ff(d,a,b,c,x[i+1],12,-389564586);c=ff(c,d,a,b,x[i+2],17,606105819);b=ff(b,c,d,a,x[i+3],22,-1044525330);a=ff(a,b,c,d,x[i+4],7,-176418897);d=ff(d,a,b,c,x[i+5],12,1200080426);c=ff(c,d,a,b,x[i+6],17,-1473231341);b=ff(b,c,d,a,x[i+7],22,-45705983);a=ff(a,b,c,d,x[i+8],7,1770035416);d=ff(d,a,b,c,x[i+9],12,-1958414417);c=ff(c,d,a,b,x[i+10],17,-42063);b=ff(b,c,d,a,x[i+11],22,-1990404162);a=ff(a,b,c,d,x[i+12],7,1804603682);d=ff(d,a,b,c,x[i+13],12,-40341101);c=ff(c,d,a,b,x[i+14],17,-1502002290);b=ff(b,c,d,a,x[i+15],22,1236535329);a=gg(a,b,c,d,x[i+1],5,-165796510);d=gg(d,a,b,c,x[i+6],9,-1069501632);c=gg(c,d,a,b,x[i+11],14,643717713);b=gg(b,c,d,a,x[i+0],20,-373897302);a=gg(a,b,c,d,x[i+5],5,-701558691);d=gg(d,a,b,c,x[i+10],9,38016083);c=gg(c,d,a,b,x[i+15],14,-660478335);b=gg(b,c,d,a,x[i+4],20,-405537848);a=gg(a,b,c,d,x[i+9],5,568446438);d=gg(d,a,b,c,x[i+14],9,-1019803690);c=gg(c,d,a,b,x[i+3],14,-187363961);b=gg(b,c,d,a,x[i+8],20,1163531501);a=gg(a,b,c,d,x[i+13],5,-1444681467);d=gg(d,a,b,c,x[i+2],9,-51403784);c=gg(c,d,a,b,x[i+7],14,1735328473);b=gg(b,c,d,a,x[i+12],20,-1926607734);a=hh(a,b,c,d,x[i+5],4,-378558);d=hh(d,a,b,c,x[i+8],11,-2022574463);c=hh(c,d,a,b,x[i+11],16,1839030562);b=hh(b,c,d,a,x[i+14],23,-35309556);a=hh(a,b,c,d,x[i+1],4,-1530992060);d=hh(d,a,b,c,x[i+4],11,1272893353);c=hh(c,d,a,b,x[i+7],16,-155497632);b=hh(b,c,d,a,x[i+10],23,-1094730640);a=hh(a,b,c,d,x[i+13],4,681279174);d=hh(d,a,b,c,x[i+0],11,-358537222);c=hh(c,d,a,b,x[i+3],16,-722521979);b=hh(b,c,d,a,x[i+6],23,76029189);a=hh(a,b,c,d,x[i+9],4,-640364487);d=hh(d,a,b,c,x[i+12],11,-421815835);c=hh(c,d,a,b,x[i+15],16,530742520);b=hh(b,c,d,a,x[i+2],23,-995338651);a=ii(a,b,c,d,x[i+0],6,-198630844);d=ii(d,a,b,c,x[i+7],10,1126891415);c=ii(c,d,a,b,x[i+14],15,-1416354905);b=ii(b,c,d,a,x[i+5],21,-57434055);a=ii(a,b,c,d,x[i+12],6,1700485571);d=ii(d,a,b,c,x[i+3],10,-1894986606);c=ii(c,d,a,b,x[i+10],15,-1051523);b=ii(b,c,d,a,x[i+1],21,-2054922799);a=ii(a,b,c,d,x[i+8],6,1873313359);d=ii(d,a,b,c,x[i+15],10,-30611744);c=ii(c,d,a,b,x[i+6],15,-1560198380);b=ii(b,c,d,a,x[i+13],21,1309151649);a=ii(a,b,c,d,x[i+4],6,-145523070);d=ii(d,a,b,c,x[i+11],10,-1120210379);c=ii(c,d,a,b,x[i+2],15,718787259);b=ii(b,c,d,a,x[i+9],21,-343485551);a=add32(a,olda);b=add32(b,oldb);c=add32(c,oldc);d=add32(d,oldd);}
return pack([a,b,c,d]);}
function utf16to8(str){var out,i,j,len,c,c2;out=[];len=str.length;for(i=0,j=0;i<len;i++,j++){c=str.charCodeAt(i);if(c<=0x7f){out[j]=str.charAt(i);}
else if(c<=0x7ff){out[j]=String.fromCharCode(0xc0|(c>>>6),0x80|(c&0x3f));}
else if(c<0xd800||c>0xdfff){out[j]=String.fromCharCode(0xe0|(c>>>12),0x80|((c>>>6)&0x3f),0x80|(c&0x3f));}
else{if(++i<len){c2=str.charCodeAt(i);if(c<=0xdbff&&0xdc00<=c2&&c2<=0xdfff){c=((c&0x03ff)<<10|(c2&0x03ff))+0x010000;if(0x010000<=c&&c<=0x10ffff){out[j]=String.fromCharCode(0xf0|((c>>>18)&0x3f),0x80|((c>>>12)&0x3f),0x80|((c>>>6)&0x3f),0x80|(c&0x3f));}
else{out[j]='?';}}
else{i--;out[j]='?';}}
else{i--;out[j]='?';}}}
return out.join('');}
function utf8to16(str){var out,i,j,len,c,c2,c3,c4,s;out=[];len=str.length;i=j=0;while(i<len){c=str.charCodeAt(i++);switch(c>>4){case 0:case 1:case 2:case 3:case 4:case 5:case 6:case 7:out[j++]=str.charAt(i-1);break;case 12:case 13:c2=str.charCodeAt(i++);out[j++]=String.fromCharCode(((c&0x1f)<<6)|(c2&0x3f));break;case 14:c2=str.charCodeAt(i++);c3=str.charCodeAt(i++);out[j++]=String.fromCharCode(((c&0x0f)<<12)|((c2&0x3f)<<6)|(c3&0x3f));break;case 15:switch(c&0xf){case 0:case 1:case 2:case 3:case 4:case 5:case 6:case 7:c2=str.charCodeAt(i++);c3=str.charCodeAt(i++);c4=str.charCodeAt(i++);s=((c&0x07)<<18)|((c2&0x3f)<<12)|((c3&0x3f)<<6)|(c4&0x3f)-0x10000;if(0<=s&&s<=0xfffff){out[j]=String.fromCharCode(((s>>>10)&0x03ff)|0xd800,(s&0x03ff)|0xdc00);}
else{out[j]='?';}
break;case 8:case 9:case 10:case 11:i+=4;out[j]='?';break;case 12:case 13:i+=5;out[j]='?';break;}}
j++;}
return out.join('');}
var base64EncodeChars=["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","0","1","2","3","4","5","6","7","8","9","+","/"];var base64DecodeChars=[-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,62,-1,-1,-1,63,52,53,54,55,56,57,58,59,60,61,-1,-1,-1,-1,-1,-1,-1,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,-1,-1,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,-1,-1,-1,-1,-1];function base64encode(str){var out,i,j,len;var c1,c2,c3;len=str.length;i=j=0;out=[];while(i<len){c1=str.charCodeAt(i++)&0xff;if(i==len)
{out[j++]=base64EncodeChars[c1>>2];out[j++]=base64EncodeChars[(c1&0x3)<<4];out[j++]="==";break;}
c2=str.charCodeAt(i++)&0xff;if(i==len)
{out[j++]=base64EncodeChars[c1>>2];out[j++]=base64EncodeChars[((c1&0x03)<<4)|((c2&0xf0)>>4)];out[j++]=base64EncodeChars[(c2&0x0f)<<2];out[j++]="=";break;}
c3=str.charCodeAt(i++)&0xff;out[j++]=base64EncodeChars[c1>>2];out[j++]=base64EncodeChars[((c1&0x03)<<4)|((c2&0xf0)>>4)];out[j++]=base64EncodeChars[((c2&0x0f)<<2)|((c3&0xc0)>>6)];out[j++]=base64EncodeChars[c3&0x3f];}
return out.join('');}
function base64decode(str){var c1,c2,c3,c4;var i,j,len,out;len=str.length;i=j=0;out=[];while(i<len){do{c1=base64DecodeChars[str.charCodeAt(i++)&0xff];}while(i<len&&c1==-1);if(c1==-1)break;do{c2=base64DecodeChars[str.charCodeAt(i++)&0xff];}while(i<len&&c2==-1);if(c2==-1)break;out[j++]=String.fromCharCode((c1<<2)|((c2&0x30)>>4));do{c3=str.charCodeAt(i++)&0xff;if(c3==61)return out.join('');c3=base64DecodeChars[c3];}while(i<len&&c3==-1);if(c3==-1)break;out[j++]=String.fromCharCode(((c2&0x0f)<<4)|((c3&0x3c)>>2));do{c4=str.charCodeAt(i++)&0xff;if(c4==61)return out.join('');c4=base64DecodeChars[c4];}while(i<len&&c4==-1);if(c4==-1)break;out[j++]=String.fromCharCode(((c3&0x03)<<6)|c4);}
return out.join('');}
function serialize(o){var p=0,sb=[],ht=[],hv=1;var classname=function(o){if(typeof(o)=="undefined"||typeof(o.constructor)=="undefined")return'';var c=o.constructor.toString();c=utf16to8(c.substr(0,c.indexOf('(')).replace(/(^\s*function\s*)|(\s*$)/ig,''));return((c=='')?'Object':c);};var is_int=function(n){var s=n.toString(),l=s.length;if(l>11)return false;for(var i=(s.charAt(0)=='-')?1:0;i<l;i++){switch(s.charAt(i)){case'0':case'1':case'2':case'3':case'4':case'5':case'6':case'7':case'8':case'9':break;default:return false;}}
return!(n<-2147483648||n>2147483647);};var in_ht=function(o){for(k in ht)if(ht[k]===o)return k;return false;};var ser_null=function(){sb[p++]='N;';};var ser_boolean=function(b){sb[p++]=(b?'b:1;':'b:0;');};var ser_integer=function(i){sb[p++]='i:'+i+';';};var ser_double=function(d){if(isNaN(d))d='NAN';else if(d==Number.POSITIVE_INFINITY)d='INF';else if(d==Number.NEGATIVE_INFINITY)d='-INF';sb[p++]='d:'+d+';';};var ser_string=function(s){var utf8=utf16to8(s);sb[p++]='s:'+utf8.length+':"';sb[p++]=utf8;sb[p++]='";';};var ser_array=function(a){sb[p++]='a:';var lp=p;sb[p++]=0;sb[p++]=':{';for(var k in a){if(typeof(a[k])!='function'){is_int(k)?ser_integer(k):ser_string(k);__serialize(a[k]);sb[lp]++;}}
sb[p++]='}';};var ser_object=function(o){var cn=classname(o);if(cn=='')ser_null();else if(typeof(o.serialize)!='function'){sb[p++]='O:'+cn.length+':"';sb[p++]=cn;sb[p++]='":';var lp=p;sb[p++]=0;sb[p++]=':{';if(typeof(o.__sleep)=='function'){var a=o.__sleep();for(var kk in a){ser_string(a[kk]);__serialize(o[a[kk]]);sb[lp]++;}}
else{for(var k in o){if(typeof(o[k])!='function'){ser_string(k);__serialize(o[k]);sb[lp]++;}}}
sb[p++]='}';}
else{var cs=o.serialize();sb[p++]='C:'+cn.length+':"';sb[p++]=cn;sb[p++]='":'+cs.length+':{';sb[p++]=cs;sb[p++]="}";}};var ser_pointref=function(R){sb[p++]="R:"+R+";";};var ser_ref=function(r){sb[p++]="r:"+r+";";};var __serialize=function(o){if(o==null||o.constructor==Function){hv++;ser_null();}
else switch(o.constructor){case Boolean:{hv++;ser_boolean(o);break;}
case Number:{hv++;is_int(o)?ser_integer(o):ser_double(o);break;}
case String:{hv++;ser_string(o);break;}/*@cc_on@*//*@if(@_jscript)
case VBArray:{o=o.toArray();}@end@*/case Array:{var r=in_ht(o);if(r){ser_pointref(r);}
else{ht[hv++]=o;ser_array(o);}
break;}
default:{var r=in_ht(o);if(r){hv++;ser_ref(r);}
else{ht[hv++]=o;ser_object(o);}
break;}}};__serialize(o);return sb.join('');}
function unserialize(ss){var p=0,ht=[],hv=1;r=null;var unser_null=function(){p++;return null;};var unser_boolean=function(){p++;var b=(ss.charAt(p++)=='1');p++;return b;};var unser_integer=function(){p++;var i=parseInt(ss.substring(p,p=ss.indexOf(';',p)));p++;return i;};var unser_double=function(){p++;var d=ss.substring(p,p=ss.indexOf(';',p));switch(d){case'NAN':d=NaN;break;case'INF':d=Number.POSITIVE_INFINITY;break;case'-INF':d=Number.NEGATIVE_INFINITY;break;default:d=parseFloat(d);}
p++;return d;};var unser_string=function(){p++;var l=parseInt(ss.substring(p,p=ss.indexOf(':',p)));p+=2;var s=utf8to16(ss.substring(p,p+=l));p+=2;return s;};var unser_array=function(){p++;var n=parseInt(ss.substring(p,p=ss.indexOf(':',p)));p+=2;var a=[];ht[hv++]=a;for(var i=0;i<n;i++){var k;switch(ss.charAt(p++)){case'i':k=unser_integer();break;case's':k=unser_string();break;case'U':k=unser_unicode_string();break;default:return false;}
a[k]=__unserialize();}
p++;return a;};var unser_object=function(){p++;var l=parseInt(ss.substring(p,p=ss.indexOf(':',p)));p+=2;var cn=utf8to16(ss.substring(p,p+=l));p+=2;var n=parseInt(ss.substring(p,p=ss.indexOf(':',p)));p+=2;if(eval(['typeof(',cn,') == "undefined"'].join(''))){eval(['function ',cn,'(){}'].join(''));}
var o=eval(['new ',cn,'()'].join(''));ht[hv++]=o;for(var i=0;i<n;i++){var k;switch(ss.charAt(p++)){case's':k=unser_string();break;case'U':k=unser_unicode_string();break;default:return false;}
if(k.charAt(0)=='\0'){k=k.substring(k.indexOf('\0',1)+1,k.length);}
o[k]=__unserialize();}
p++;if(typeof(o.__wakeup)=='function')o.__wakeup();return o;};var unser_custom_object=function(){p++;var l=parseInt(ss.substring(p,p=ss.indexOf(':',p)));p+=2;var cn=utf8to16(ss.substring(p,p+=l));p+=2;var n=parseInt(ss.substring(p,p=ss.indexOf(':',p)));p+=2;if(eval(['typeof(',cn,') == "undefined"'].join(''))){eval(['function ',cn,'(){}'].join(''));}
var o=eval(['new ',cn,'()'].join(''));ht[hv++]=o;if(typeof(o.unserialize)!='function')p+=n;else o.unserialize(ss.substring(p,p+=n));p++;return o;};var unser_unicode_string=function(){p++;var l=parseInt(ss.substring(p,p=ss.indexOf(':',p)));p+=2;var sb=[];for(var i=0;i<l;i++){if((sb[i]=ss.charAt(p++))=='\\'){sb[i]=String.fromCharCode(parseInt(ss.substring(p,p+=4),16));}}
p+=2;return sb.join('');};var unser_ref=function(){p++;var r=parseInt(ss.substring(p,p=ss.indexOf(';',p)));p++;return ht[r];};var __unserialize=function(){switch(ss.charAt(p++)){case'N':return ht[hv++]=unser_null();case'b':return ht[hv++]=unser_boolean();case'i':return ht[hv++]=unser_integer();case'd':return ht[hv++]=unser_double();case's':return ht[hv++]=unser_string();case'U':return ht[hv++]=unser_unicode_string();case'r':return ht[hv++]=unser_ref();case'a':return unser_array();case'O':return unser_object();case'C':return unser_custom_object();case'R':return unser_ref();default:return false;}};return __unserialize();}
function mul(a,b){var n=a.length,m=b.length,nm=n+m,i,j,c=Array(nm);for(i=0;i<nm;i++)c[i]=0;for(i=0;i<n;i++){for(j=0;j<m;j++){c[i+j]+=a[i]*b[j];c[i+j+1]+=(c[i+j]>>16)&0xffff;c[i+j]&=0xffff;}}
return c;}
function div(a,b,is_mod){var n=a.length,m=b.length,i,j,d,tmp,qq,rr,c=Array();d=Math.floor(0x10000/(b[m-1]+1));a=mul(a,[d]);b=mul(b,[d]);for(j=n-m;j>=0;j--){tmp=a[j+m]*0x10000+a[j+m-1];rr=tmp%b[m-1];qq=Math.round((tmp-rr)/b[m-1]);if(qq==0x10000||(m>1&&qq*b[m-2]>0x10000*rr+a[j+m-2])){qq--;rr+=b[m-1];if(rr<0x10000&&qq*b[m-2]>0x10000*rr+a[j+m-2])qq--;}
for(i=0;i<m;i++){tmp=i+j;a[tmp]-=b[i]*qq;a[tmp+1]+=Math.floor(a[tmp]/0x10000);a[tmp]&=0xffff;}
c[j]=qq;if(a[tmp+1]<0){c[j]--;for(i=0;i<m;i++){tmp=i+j;a[tmp]+=b[i];if(a[tmp]>0xffff){a[tmp+1]++;a[tmp]&=0xffff;}}}}
if(!is_mod)return c;b=Array();for(i=0;i<m;i++)b[i]=a[i];return div(b,[d]);}
function pow_mod(a,b,c){var n=b.length,p=[1],i,j,tmp;for(i=0;i<n-1;i++){tmp=b[i];for(j=0;j<0x10;j++){if(tmp&1)p=div(mul(p,a),c,1);tmp>>=1;a=div(mul(a,a),c,1);}}
tmp=b[i];while(tmp){if(tmp&1)p=div(mul(p,a),c,1);tmp>>=1;a=div(mul(a,a),c,1);}
return p;}
function zerofill(str,num){var n=num-str.toString().length,i,s='';for(i=0;i<n;i++)s+='0';return s+str;}
function dec2num(str){var n=str.length,a=[0],i,j,m;n+=4-(n%4);str=zerofill(str,n);n>>=2;for(i=0;i<n;i++){a=mul(a,[10000]);a[0]+=parseInt(str.substring(4*i,4*(i+1)),10);m=a.length;j=a[m]=0;while(j<m&&a[j]>0xffff){a[j++]&=0xffff;a[j]++;}
while(a.length>1&&!a[a.length-1])a.length--;}
return a;}
function num2dec(a){var n=2*a.length,b=Array(),i;for(i=0;i<n;i++){b[i]=zerofill(div(a,[10000],1)[0],4);a=div(a,[10000]);}
while(b.length>1&&!parseInt(b[b.length-1],10))b.length--;n=b.length-1;b[n]=parseInt(b[n],10);b=b.reverse().join('');return b;}
function str2num(str){var len=str.length;if(len&1){str="\0"+str;len++;}
len>>=1;var result=Array();for(var i=0;i<len;i++){result[len-i-1]=str.charCodeAt(i<<1)<<8|str.charCodeAt((i<<1)+1);}
return result;}
function num2str(num){var n=num.length;var s=Array();for(var i=0;i<n;i++){s[n-i-1]=String.fromCharCode(num[i]>>8&0xff,num[i]&0xff);}
return s.join('');}
function rand(n,s){var lowBitMasks=new Array(0x0000,0x0001,0x0003,0x0007,0x000f,0x001f,0x003f,0x007f,0x00ff,0x01ff,0x03ff,0x07ff,0x0fff,0x1fff,0x3fff,0x7fff);var r=n%16;var q=n>>4;var result=Array();for(var i=0;i<q;i++){result[i]=Math.floor(Math.random()*0xffff);}
if(r!=0){result[q]=Math.floor(Math.random()*lowBitMasks[r]);if(s){result[q]|=1<<(r-1);}}
else if(s){result[q-1]|=0x8000;}
return result;}
function long2str(v,w){var vl=v.length;var n=(vl-1)<<2;if(w){var m=v[vl-1];if((m<n-3)||(m>n))return null;n=m;}
for(var i=0;i<vl;i++){v[i]=String.fromCharCode(v[i]&0xff,v[i]>>>8&0xff,v[i]>>>16&0xff,v[i]>>>24&0xff);}
if(w){return v.join('').substring(0,n);}
else{return v.join('');}}
function str2long(s,w){var len=s.length;var v=[];for(var i=0;i<len;i+=4){v[i>>2]=s.charCodeAt(i)|s.charCodeAt(i+1)<<8|s.charCodeAt(i+2)<<16|s.charCodeAt(i+3)<<24;}
if(w){v[v.length]=len;}
return v;}
function xxtea_encrypt(str,key){if(str==""){return"";}
var v=str2long(str,true);var k=str2long(key,false);if(k.length<4){k.length=4;}
var n=v.length-1;var z=v[n],y=v[0],delta=0x9E3779B9;var mx,e,p,q=Math.floor(6+52/(n+1)),sum=0;while(0<q--){sum=sum+delta&0xffffffff;e=sum>>>2&3;for(p=0;p<n;p++){y=v[p+1];mx=(z>>>5^y<<2)+(y>>>3^z<<4)^(sum^y)+(k[p&3^e]^z);z=v[p]=v[p]+mx&0xffffffff;}
y=v[0];mx=(z>>>5^y<<2)+(y>>>3^z<<4)^(sum^y)+(k[p&3^e]^z);z=v[n]=v[n]+mx&0xffffffff;}
return long2str(v,false);}
function xxtea_decrypt(str,key){if(str==""){return"";}
var v=str2long(str,false);var k=str2long(key,false);if(k.length<4){k.length=4;}
var n=v.length-1;var z=v[n-1],y=v[0],delta=0x9E3779B9;var mx,e,p,q=Math.floor(6+52/(n+1)),sum=q*delta&0xffffffff;while(sum!=0){e=sum>>>2&3;for(p=n;p>0;p--){z=v[p-1];mx=(z>>>5^y<<2)+(y>>>3^z<<4)^(sum^y)+(k[p&3^e]^z);y=v[p]=v[p]-mx&0xffffffff;}
z=v[n];mx=(z>>>5^y<<2)+(y>>>3^z<<4)^(sum^y)+(k[p&3^e]^z);y=v[0]=v[0]-mx&0xffffffff;sum=sum-delta&0xffffffff;}
return long2str(v,true);}/*@cc_on@*//*@if(@_jscript_version<5.5)
Array.prototype.push=function(){var curlen=this.length;for(var i=0;i<arguments.length;i++){this[curlen+i]=arguments[i];}
return this.length;}
Array.prototype.shift=function(){var returnValue=this[0];for(var i=1;i<this.length;i++){this[i-1]=this[i];}
this.length--;return returnValue;}@end@*/function PHPRPC_Error(errno,errstr){this.Number=errno;this.Message=errstr;}
PHPRPC_Error.prototype.toString=function(){return this.Number+":"+this.Message;}
function PHPRPC_Client(serverURL){this.ready=false;this.__id=PHPRPC_Client.__clientList.length;PHPRPC_Client.__clientList[this.__id]=this;this.__name='PHPRPC_Client.__clientList['+this.__id+']';if(typeof(serverURL)!="undefined")
{this.useService(serverURL);}}
PHPRPC_Client.create=function(serverURL){return new PHPRPC_Client(serverURL);}
PHPRPC_Client.prototype.dispose=function(){PHPRPC_Client.__clientList[this.__id]=null;}
PHPRPC_Client.prototype.useService=function(serverURL,username,password){this.__username=null;this.__password=null;if(typeof(serverURL)=="undefined"){return new PHPRPC_Error(1,"You should set serverURL first!");}
this.__url=serverURL;if(typeof(username)!="undefined"&&typeof(password)!="undefined"){this.__username=username;this.__password=password;}
this.__initService();this.__useService();return true;}
PHPRPC_Client.prototype.setKeyLength=function(keyLength){if(this.__encrypt!=null){return false;}
else{this.__keyLength=keyLength;return true;}}
PHPRPC_Client.prototype.getKeyLength=function(){return this.__keyLength;}
PHPRPC_Client.prototype.setEncryptMode=function(encryptMode){if(encryptMode>=0&&encryptMode<=3){this.__encryptMode=parseInt(encryptMode);return true;}
else{this.__encryptMode=0;return false;}}
PHPRPC_Client.prototype.invoke=function(){var args=this.__argsToArray(arguments);var func=args.shift();this.__invoke(func,args);}
PHPRPC_Client.__clientList=[];PHPRPC_Client.__createXMLHttp=function(){if(window.XMLHttpRequest){var objXMLHttp=new XMLHttpRequest();if(objXMLHttp.readyState==null){objXMLHttp.readyState=0;objXMLHttp.addEventListener("load",function(){objXMLHttp.readyState=4;if(typeof(objXMLHttp.onreadystatechange)=="function"){objXMLHttp.onreadystatechange();}},false);}
return objXMLHttp;}
else{var MSXML=['MSXML2.XMLHTTP.5.0','MSXML2.XMLHTTP.4.0','MSXML2.XMLHTTP.3.0','MSXML2.XMLHTTP','Microsoft.XMLHTTP'];var n=MSXML.length;for(var i=0;i<n;i++){try{return new ActiveXObject(MSXML[i]);}
catch(e){}}
return null;}}
PHPRPC_Client.__createID=function(){return(new Date()).getTime().toString(36)
+Math.floor(Math.random()*100000000).toString(36);}
PHPRPC_Client.prototype.__initService=function(){this.ready=false;this.__encrypt=null;this.__keyLength=128;this.__encryptMode=0;this.__keySwitching=false;this.__taskQueue=[];this.__dataObject=[];var protocol=null;var host=null;if(this.__url.substr(0,7)=="http://"){protocol="http:";host=this.__url.substring(7,this.__url.indexOf('/',7));}
else if(this.__url.substr(0,8)=="https://"){protocol="https:";host=this.__url.substring(8,this.__url.indexOf('/',8));}
if(((protocol==null&&host==null)||(protocol==location.protocol&&host==location.host)||location.protocol=="file:")&&PHPRPC_Client.__createXMLHttp()!=null){this.__ajax=true;}
else{this.__ajax=false;}
this.__url=this.__url.replace(/[\&\?]+$/g,"");this.__url+=(this.__url.indexOf('?',0)==-1)?'?':'&';}
PHPRPC_Client.prototype.__useService=function(){if(this.__ajax){var xmlhttp=PHPRPC_Client.__createXMLHttp();var __rpc=this;xmlhttp.onreadystatechange=function(){if(xmlhttp.readyState==4&&xmlhttp.status==200){if(xmlhttp.responseText){var id=PHPRPC_Client.__createID();__rpc.__createDataObject(xmlhttp.responseText,id);__rpc.__createFunctions(unserialize(__rpc.__dataObject[id].phprpc_functions));__rpc.__deleteDataObject(id);}
__rpc=null;xmlhttp=null;}}
try{xmlhttp.open("GET",this.__url+'phprpc_encode=false',true);if(this.__username!==null){xmlhttp.setRequestHeader('Authorization','Basic '+base64_encode(this.__username+":"+this.__password));}
xmlhttp.send(null);}
catch(e){xmlhttp=null;this.__ajax=false;this.__useService();}}
else{var id=PHPRPC_Client.__createID();var callback=base64encode(utf16to8(this.__name+".__getFunctions('"+id+"');"));var request='phprpc_encode=false&phprpc_callback='+callback;this.__appendScript(id,request);}}
PHPRPC_Client.prototype.__appendScript=function(id,request,args,ref,encrypt,callback){var script=document.createElement("script");script.id="script_"+id;script.src=this.__url+request.replace(/\+/g,'%2B');script.defer=true;script.type="text/javascript";script.args=args;script.ref=ref;script.encrypt=encrypt;script.callback=callback;var head=document.getElementsByTagName("head").item(0);head.appendChild(script);}
PHPRPC_Client.prototype.__removeScript=function(id){var script=document.getElementById("script_"+id);var head=document.getElementsByTagName("head").item(0);head.removeChild(script);}
PHPRPC_Client.prototype.__argsToArray=function(args){var n=args.length;var argArray=new Array(n);for(i=0;i<n;i++){argArray[i]=args[i];}
return argArray;}
PHPRPC_Client.prototype.__createDataObject=function(str,id){var params=str.split(";\r\n");var result={};var n=0;for(var i=0;i<params.length;i++){var p=params[i].indexOf("=");if(p>=0){var l=params[i].substr(0,p);var r=params[i].substr(p+1);result[l]=eval(r);}}
this.__dataObject[id]=result;}
PHPRPC_Client.prototype.__deleteDataObject=function(id){delete this.__dataObject[id];}
PHPRPC_Client.prototype.__invoke=function(func,args){var __rpc=this;var task=function(){__rpc.__call(func,args);__rpc=null;};this.__taskQueue.push(task);this.__switchKey();}
PHPRPC_Client.prototype.__createFunctions=function(func){for(var i=0;i<func.length;i++){PHPRPC_Client.__clientList[this.__id][func[i]]=new Function("this.__invoke('"+func[i]+"', this.__argsToArray(arguments));");}
this.ready=true;if(typeof(this.onready)=="function"){this.onready();}}
PHPRPC_Client.prototype.__getFunctions=function(id){this.__createFunctions(unserialize(phprpc_functions));this.__removeScript(id);}
PHPRPC_Client.prototype.__switchKey=function(){if(this.__keySwitching)return;if(this.__encrypt===null&&this.__encryptMode>0){this.__keySwitching=true;if(this.__ajax){var xmlhttp=PHPRPC_Client.__createXMLHttp();var __rpc=this;xmlhttp.onreadystatechange=function(){if(xmlhttp.readyState==4&&xmlhttp.status==200){if(xmlhttp.responseText){var id=PHPRPC_Client.__createID();__rpc.__createDataObject(xmlhttp.responseText,id);__rpc.__switchKey2(id);__rpc.__deleteDataObject(id);}
__rpc=null;xmlhttp=null;}}
xmlhttp.open("GET",this.__url+'phprpc_encrypt=true&phprpc_encode=false&phprpc_keylen='+this.__keyLength,true);if(this.__username!==null){xmlhttp.setRequestHeader('Authorization','Basic '+base64_encode(this.__username+":"+this.__password));}
xmlhttp.send(null);}
else{var id=PHPRPC_Client.__createID();var callback=base64encode(utf16to8(this.__name+".__switchKey2('"+id+"');"));var request='phprpc_encrypt=true&phprpc_encode=false&phprpc_keylen='+this.__keyLength+'&phprpc_callback='+callback;this.__appendScript(id,request);}}
else{this.__keySwitched();}}
PHPRPC_Client.prototype.__switchKey2=function(id){if(this.__ajax){if(typeof(this.__dataObject[id].phprpc_encrypt)=="undefined"){this.__encrypt=null;this.__encorytMode=0;this.__keySwitching=false;this.__keySwitched();}
else{if(typeof(this.__dataObject[id].phprpc_keylen)!="undefined"){this.__keyLength=parseInt(this.__dataObject[id].phprpc_keylen);}
else{this.__keyLength=128;}
this.__encrypt=unserialize(this.__dataObject[id].phprpc_encrypt);var encrypt=this.__getKey().replace(/\+/g,'%2B');var __rpc=this;var xmlhttp=PHPRPC_Client.__createXMLHttp();xmlhttp.onreadystatechange=function(){if(xmlhttp.readyState==4&&xmlhttp.status==200){__rpc.__keySwitching=false;__rpc.__keySwitched();__rpc=null;xmlhttp=null;}}
xmlhttp.open("GET",this.__url+'phprpc_encode=false&phprpc_encrypt='+encrypt,true);if(this.__username!==null){xmlhttp.setRequestHeader('Authorization','Basic '+base64_encode(this.__username+":"+this.__password));}
xmlhttp.send(null);}}
else{this.__removeScript(id);if(typeof(phprpc_encrypt)=="undefined"){this.__encrypt=null;this.__encorytMode=0;this.__keySwitching=false;this.__keySwitched();}
else{this.__encrypt=unserialize(phprpc_encrypt);if((typeof(phprpc_keylen)!="undefined")&&(phprpc_keylen!==null)){this.__keyLength=parseInt(phprpc_keylen);phprpc_keylen=null;}
else{this.__keyLength=128;}
var callback=base64encode(utf16to8(this.__name+".__removeScript('"+id+"');"));var request='phprpc_encrypt='+this.__getKey()
+'&phprpc_encode=false&phprpc_callback='+callback;this.__appendScript(id,request);this.__keySwitching=false;this.__keySwitched();}}}
PHPRPC_Client.prototype.__getKey=function(){this.__encrypt['p']=dec2num(this.__encrypt['p']);this.__encrypt['g']=dec2num(this.__encrypt['g']);this.__encrypt['y']=dec2num(this.__encrypt['y']);this.__encrypt['x']=rand(this.__keyLength-1,1);var key=pow_mod(this.__encrypt['y'],this.__encrypt['x'],this.__encrypt['p']);if(this.__keyLength==128){key=num2str(key);var n=16-key.length;var k=[];for(var i=0;i<n;i++){k[i]='\0';}
k[n]=key;this.__encrypt['k']=k.join('');}
else{this.__encrypt['k']=md5(num2dec(key));}
return num2dec(pow_mod(this.__encrypt['g'],this.__encrypt['x'],this.__encrypt['p']));}
PHPRPC_Client.prototype.__keySwitched=function(){while(this.__taskQueue.length>0){var task=this.__taskQueue.shift();if(typeof(task)=="function"){task();}}}
PHPRPC_Client.prototype.__call=function(func,args){var id=PHPRPC_Client.__createID();var ref=false;var encrypt=this.__encryptMode;var callback=PHPRPC_Client.__clientList[this.__id][func+"_callback"];if(typeof(callback)!="function"){callback=null;}
if(typeof(args[args.length-1])=="boolean"&&typeof(args[args.length-2])=="function"){ref=args[args.length-1];callback=args[args.length-2];args.length-=2;}
if(typeof(args[args.length-1])=="function"){callback=args[args.length-1];args.length--;}
var __args=serialize(args);if((this.__encrypt!==null)&&(encrypt>0)){__args=xxtea_encrypt(__args,this.__encrypt['k']);}
__args=base64encode(__args);var request='phprpc_func='+func
+'&phprpc_args='+__args
+'&phprpc_encode=false'
+'&phprpc_encrypt='+encrypt;if(!ref){request+='&phprpc_ref=false';}
if(this.__ajax){var xmlhttp=PHPRPC_Client.__createXMLHttp();var __rpc=this;xmlhttp.onreadystatechange=function(){if(xmlhttp.readyState==4&&xmlhttp.status==200){if(xmlhttp.responseText){__rpc.__createDataObject(xmlhttp.responseText,id);__rpc.__getResult(id,args,ref,encrypt,callback);__rpc.__deleteDataObject(id);}
__rpc=null;xmlhttp=null;}}
xmlhttp.open("POST",this.__url,true);xmlhttp.setRequestHeader('Content-Type','application/x-www-form-urlencoded; charset=UTF-8');if(this.__username!==null){xmlhttp.setRequestHeader('Authorization','Basic '+base64_encode(this.__username+":"+this.__password));}
xmlhttp.send(request.replace(/\+/g,'%2B'));}
else{request+='&phprpc_callback='+base64encode(utf16to8(this.__name+".__callback('"+id+"');"));this.__appendScript(id,request,args,ref,encrypt,callback);}}
PHPRPC_Client.prototype.__getResult=function(id,args,ref,encrypt,callback){if(typeof(callback)=="function"){var errno=this.__dataObject[id].phprpc_errno;var errstr=this.__dataObject[id].phprpc_errstr;var output=this.__dataObject[id].phprpc_output;var result=new PHPRPC_Error(errno,errstr);var warning=result;if((errno!=1)&&(errno!=16)&&(errno!=64)&&(errno!=256)){result=this.__dataObject[id].phprpc_result;if(ref){args=this.__dataObject[id].phprpc_args;}
if((this.__encrypt!==null)&&(encrypt>0)){if(encrypt>2){output=xxtea_decript(output,this.__encrypt['k']);if(output===null){output=this.__dataObject[id].phprpc_output;}}
if(encrypt>1){result=xxtea_decrypt(result,this.__encrypt['k']);}
if(ref){args=xxtea_decrypt(args,this.__encrypt['k']);}}
result=unserialize(result);if(ref){args=unserialize(args);}}
callback(result,args,output,warning);}}
PHPRPC_Client.prototype.__callback=function(id){this.__dataObject[id]={};this.__dataObject[id].phprpc_errno=phprpc_errno;this.__dataObject[id].phprpc_errstr=phprpc_errstr;this.__dataObject[id].phprpc_output=phprpc_output;if(typeof(phprpc_result)!="undefined"){this.__dataObject[id].phprpc_result=phprpc_result;}
if(typeof(phprpc_args)!="undefined"){this.__dataObject[id].phprpc_args=phprpc_args;}
var script=document.getElementById("script_"+id);this.__getResult(id,script.args,script.ref,script.encrypt,script.callback);this.__deleteDataObject(id);this.__removeScript(id);}
