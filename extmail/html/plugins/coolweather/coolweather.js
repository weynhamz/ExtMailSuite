function get_nav_language() {
    var nav_lng;
    if(navigator.userlanguage) nav_lng = navigator.userlanguage;
    if(navigator.browserLanguage) nav_lng = navigator.browserLanguage;
    if(navigator.systemLanguage) nav_lng = navigator.systemLanguage;
    if(navigator.language) nav_lng = navigator.language;
    return new String(nav_lng).toLowerCase();
}

var coolweather_nav_lng;

// lang tag for extmail
if (userlang=='zh_CN')
    coolweather_nav_lng = 'zh-cn';
else if (userlang=='zh_TW')
    coolweather_nav_lng = 'zh-tw';
else if (userlang=='en_US')
    coolweather_nav_lng = 'en';
else
    coolweather_nav_lng = get_nav_language();

var coolweather_nav_language = "en, ca, de, es, fr, it, ja, nl, pt, zh-cn, zh-tw";
if (coolweather_nav_language.indexOf(coolweather_nav_lng) == -1) coolweather_nav_lng = 'en';

var coolweather_lang = [];

coolweather_lang['en'] = [];
coolweather_lang['en']['rpcnotready'] = "Cool Weather RPC is not ready.";
coolweather_lang['en']['currentconditions'] = "Current Conditions";
coolweather_lang['en']['changecity'] = "Change the city";
coolweather_lang['en']['temperature'] = "Temperature: ";
coolweather_lang['en']['hightemperature'] = "High Temperature: ";
coolweather_lang['en']['lowtemperature'] = "Low Temperature: ";
coolweather_lang['en']['realfeel'] = "Realfeel<sup>&reg;</sup>: ";
coolweather_lang['en']['realfeelhigh'] = "Realfeel<sup>&reg;</sup> High: ";
coolweather_lang['en']['realfeellow'] = "Realfeel<sup>&reg;</sup> Low: ";
coolweather_lang['en']['windspeed'] = "Wind Speed: ";
coolweather_lang['en']['windforce'] = "Wind Force: ";
coolweather_lang['en']['scale'] = "scale";
coolweather_lang['en']['winddirection'] = "Wind Direction: ";
coolweather_lang['en']['today'] = "Today: ";
coolweather_lang['en']['tomorrow'] = "Tomorrow: ";
coolweather_lang['en']['daytime'] = "daytime";
coolweather_lang['en']['nighttime'] = "nighttime";
coolweather_lang['en']['loading'] = "Loading...";
coolweather_lang['en']['city'] = "City: (Example: New York)";
coolweather_lang['en']['firstseehint'] = "Maybe you use this browser to see me for the first time, so you need set your city first which you want to see the weather report.";
coolweather_lang['en']['location'] = "Location: ";
coolweather_lang['en']['nocitymatched'] = "There is no city matched your input!";
coolweather_lang['en']['morecitymatched'] = "There are more than one city matched your input, select which you want.";
coolweather_lang['en']['back'] = "back";
coolweather_lang['en']['choosecity'] = 'choose your city';
coolweather_lang['en']['unit'] = 'Unit of Measure: ';
coolweather_lang['en']['unita'] = 'American';
coolweather_lang['en']['unitm'] = 'Metric';
coolweather_lang['en']['N'] = 'N';
coolweather_lang['en']['S'] = 'S';
coolweather_lang['en']['W'] = 'W';
coolweather_lang['en']['E'] = 'E';
coolweather_lang['en']['NE'] = 'NE';
coolweather_lang['en']['SE'] = 'SE';
coolweather_lang['en']['NW'] = 'NW';
coolweather_lang['en']['SW'] = 'SW';
coolweather_lang['en']['ENE'] = 'ENE';
coolweather_lang['en']['ESE'] = 'ESE';
coolweather_lang['en']['WNW'] = 'WNW';
coolweather_lang['en']['WSW'] = 'WSW';
coolweather_lang['en']['NNE'] = 'NNE';
coolweather_lang['en']['NNW'] = 'NNW';
coolweather_lang['en']['SSE'] = 'SSE';
coolweather_lang['en']['SSW'] = 'SSW';

// Catalan translate by Alexandre Perera
coolweather_lang['ca'] = [];
coolweather_lang['ca']['rpcnotready'] = "Cool Weather RPC no est&agrave; preparat.";
coolweather_lang['ca']['currentconditions'] = "Condicions actuals";
coolweather_lang['ca']['changecity'] = "Canvia la ciutat";
coolweather_lang['ca']['temperature'] = "Temperatura: ";
coolweather_lang['ca']['hightemperature'] = "Temperatura M&agrave;x.: ";
coolweather_lang['ca']['lowtemperature'] = "Temperatura M&iacute;n.: ";
coolweather_lang['ca']['realfeel'] = "T. aparent.&reg;: ";
coolweather_lang['ca']['realfeelhigh'] = "T. aparent.&reg; M&agrave;x: ";
coolweather_lang['ca']['realfeellow'] = "T. aparent.&reg; M&iacute;n: ";
coolweather_lang['ca']['windspeed'] = "Velocitat Vent: ";
coolweather_lang['ca']['windforce'] = "For&ccedil;a Vent: ";
coolweather_lang['ca']['scale'] = "escala";
coolweather_lang['ca']['winddirection'] = "Direcci&oacute; vent: ";
coolweather_lang['ca']['today'] = "Avui: ";
coolweather_lang['ca']['tomorrow'] = "Dem&agrave;: ";
coolweather_lang['ca']['daytime'] = "de dia";
coolweather_lang['ca']['nighttime'] = "a la  nit";
coolweather_lang['ca']['loading'] = "Carregant...";
coolweather_lang['ca']['city'] = "Ciutat: (Per Exemple: Altafulla)";
coolweather_lang['ca']['firstseehint'] = "Si em visites per primer cop, cal que indiques la ciutat d'on vols veure el temps.";
coolweather_lang['ca']['location'] = "Ubicaci&oacute;: ";
coolweather_lang['ca']['nocitymatched'] = "Cap ciutat es corresp&oacute;n amb la teva entrada!";
coolweather_lang['ca']['morecitymatched'] = "Hi ha m&eacute;s d'una ciutat que es corresp&oacute;n a la teva entrada, si us plau escull.";
coolweather_lang['ca']['back'] = "Enrerra";
coolweather_lang['ca']['choosecity'] = 'Escull ';
coolweather_lang['ca']['unit'] = 'Unitats: ';
coolweather_lang['ca']['unita'] = 'Americanes';
coolweather_lang['ca']['unitm'] = 'M&egrave;triques';
coolweather_lang['ca']['N'] = 'N';
coolweather_lang['ca']['S'] = 'S';
coolweather_lang['ca']['W'] = 'O';
coolweather_lang['ca']['E'] = 'E';
coolweather_lang['ca']['NE'] = 'NE';
coolweather_lang['ca']['SE'] = 'SE';
coolweather_lang['ca']['NW'] = 'NO';
coolweather_lang['ca']['SW'] = 'SO';
coolweather_lang['ca']['ENE'] = 'ENE';
coolweather_lang['ca']['ESE'] = 'ESE';
coolweather_lang['ca']['WNW'] = 'ONO';
coolweather_lang['ca']['WSW'] = 'OSO';
coolweather_lang['ca']['NNE'] = 'NNE';
coolweather_lang['ca']['NNW'] = 'NNO';
coolweather_lang['ca']['SSE'] = 'SSE';
coolweather_lang['ca']['SSW'] = 'SSO';

// German translate by Patrick Blumberg
coolweather_lang['de'] = [];
coolweather_lang['de']['rpcnotready'] = "Cool Weather RPC noch nicht bereit.";
coolweather_lang['de']['currentconditions'] = "Aktuelle Verh&auml;ltnisse";
coolweather_lang['de']['changecity'] = "&Auml;ndere die Stadt";
coolweather_lang['de']['temperature'] = "Temperatur: ";
coolweather_lang['de']['hightemperature'] = "Max Temperatur: ";
coolweather_lang['de']['lowtemperature'] = "Min Temperatur: ";
coolweather_lang['de']['realfeel'] = "Gef&uuml;hlt: ";
coolweather_lang['de']['realfeelhigh'] = "Gef&uuml;hlt Max: ";
coolweather_lang['de']['realfeellow'] = "Gef&uuml;hlt Min: ";
coolweather_lang['de']['windspeed'] = "Windgeschwindigkeit: ";
coolweather_lang['de']['windforce'] = "Windst&auml;rke: ";
coolweather_lang['de']['scale'] = "";
coolweather_lang['de']['winddirection'] = "Windrichtung: ";
coolweather_lang['de']['today'] = "Heute: ";
coolweather_lang['de']['tomorrow'] = "Morgen: ";
coolweather_lang['de']['daytime'] = "tags&uuml;ber";
coolweather_lang['de']['nighttime'] = "nachts";
coolweather_lang['de']['loading'] = "Lade...";
coolweather_lang['de']['city'] = "Stadt: (z.B.: Hamburg)";
coolweather_lang['de']['firstseehint'] = "Wenn du zum ersten Mal mit deinem Browser auf diese Seite kommst, musst Du erst mal eine Stadt ausw&auml;len, bevor dir die Wetterdaten gezeigt werden k&ouml;nnen.";
coolweather_lang['de']['location'] = "Ort: ";
coolweather_lang['de']['nocitymatched'] = "Es gibt keine Stadt, die zu deiner Eingabe passt!";
coolweather_lang['de']['morecitymatched'] = "Es gibt f&uuml;r deine Eingabe mehr als eine Stadt. W&auml;hle hier welche in Frage kommt.";
coolweather_lang['de']['back'] = "zur&uuml;ck";
coolweather_lang['de']['choosecity'] = 'W&#228;hle deine Stadt';
coolweather_lang['de']['unit'] = 'Ma&szlig;einheit: ';
coolweather_lang['de']['unita'] = 'amerikanisch';
coolweather_lang['de']['unitm'] = 'metrisch';
coolweather_lang['de']['N'] = 'N';
coolweather_lang['de']['S'] = 'S';
coolweather_lang['de']['W'] = 'W';
coolweather_lang['de']['E'] = 'O';
coolweather_lang['de']['NE'] = 'NO';
coolweather_lang['de']['SE'] = 'SO';
coolweather_lang['de']['NW'] = 'NW';
coolweather_lang['de']['SW'] = 'SW';
coolweather_lang['de']['ENE'] = 'ONO';
coolweather_lang['de']['ESE'] = 'OSO';
coolweather_lang['de']['WNW'] = 'WNW';
coolweather_lang['de']['WSW'] = 'WSW';
coolweather_lang['de']['NNE'] = 'NNO';
coolweather_lang['de']['NNW'] = 'NNW';
coolweather_lang['de']['SSE'] = 'SSO';
coolweather_lang['de']['SSW'] = 'SSW';

// Spanish translate by Ostman el Sullusta
coolweather_lang['es'] = [];
coolweather_lang['es']['rpcnotready'] = 'Cool Weather RPC no est&aacute; preparado.';
coolweather_lang['es']['currentconditions'] = 'Condiciones actuales';
coolweather_lang['es']['changecity'] = 'Cambia la ciudad';
coolweather_lang['es']['temperature'] = 'Temperatura: ';
coolweather_lang['es']['hightemperature'] = 'Temperatura M&acute;x.: ';
coolweather_lang['es']['lowtemperature'] = 'Temperatura M&iacute;n.: ';
coolweather_lang['es']['realfeel'] = 'T. aparente.&reg;: ';
coolweather_lang['es']['realfeelhigh'] = 'T. aparente.&reg; M&acute;x: ';
coolweather_lang['es']['realfeellow'] = 'T. aparente.&reg; M&iacute;n: ';
coolweather_lang['es']['windspeed'] = 'Velocidad Viento: ';
coolweather_lang['es']['windforce'] = 'Fuerza Viento: ';
coolweather_lang['es']['scale'] = 'escala';
coolweather_lang['es']['winddirection'] = 'Direcci&oacute;n Viento: ';
coolweather_lang['es']['today'] = 'Hoy: ';
coolweather_lang['es']['tomorrow'] = 'Ma&ntilde;ana: ';
coolweather_lang['es']['daytime'] = 'de d&iacute;a';
coolweather_lang['es']['nighttime'] = 'de noche';
coolweather_lang['es']['loading'] = 'Cargando...';
coolweather_lang['es']['city'] = 'Ciudad: (Por Ejemplo: Barcelona)';
coolweather_lang['es']['firstseehint'] = 'Si nos visitas por primer vez, debes indicar la ciudad de la que quieres ver el tiempo.';
coolweather_lang['es']['location'] = 'Ubicaci&oacute;n: ';
coolweather_lang['es']['nocitymatched'] = 'Ninguna ciudad se corresponde con tu entrada!';
coolweather_lang['es']['morecitymatched'] = 'Hay m&acute;s de una ciudad que corresponde a tu, por favor escoge.';
coolweather_lang['es']['back'] = 'Atras';
coolweather_lang['es']['choosecity'] = 'Escoje ';
coolweather_lang['es']['unit'] = 'Unidades: ';
coolweather_lang['es']['unita'] = 'Americanas';
coolweather_lang['es']['unitm'] = 'M&eacute;tricas';
coolweather_lang['es']['N'] = 'N';
coolweather_lang['es']['S'] = 'S';
coolweather_lang['es']['W'] = 'O';
coolweather_lang['es']['E'] = 'E';
coolweather_lang['es']['NE'] = 'NE';
coolweather_lang['es']['SE'] = 'SE';
coolweather_lang['es']['NW'] = 'NO';
coolweather_lang['es']['SW'] = 'SO';
coolweather_lang['es']['ENE'] = 'ENE';
coolweather_lang['es']['ESE'] = 'ESE';
coolweather_lang['es']['WNW'] = 'ONO';
coolweather_lang['es']['WSW'] = 'OSO';
coolweather_lang['es']['NNE'] = 'NNE';
coolweather_lang['es']['NNW'] = 'NNO';
coolweather_lang['es']['SSE'] = 'SSE';
coolweather_lang['es']['SSW'] = 'SSO';

// French translate by j m lledos
coolweather_lang['fr']=[];
coolweather_lang['fr']['rpcnotready']="Le RPC Cool Weather n'est pas pr&#234;t.";
coolweather_lang['fr']['currentconditions']="Conditions actuelles";
coolweather_lang['fr']['changecity']="Changer de ville";
coolweather_lang['fr']['temperature']="Temp&#233;rature: ";
coolweather_lang['fr']['hightemperature']="Temp&#233;rature maxi: ";
coolweather_lang['fr']['lowtemperature']="Temp&#233;rature mini: ";
coolweather_lang['fr']['realfeel']="Realfeel&reg;: ";
coolweather_lang['fr']['realfeelhigh']="Sensation&reg; Maxi: ";
coolweather_lang['fr']['realfeellow']="Sensation&reg; Mini: ";
coolweather_lang['fr']['windspeed']="Vitesse du vent: ";
coolweather_lang['fr']['windforce']="Force du vent: ";
coolweather_lang['fr']['scale']="scale";
coolweather_lang['fr']['winddirection']="Direction du vent: ";
coolweather_lang['fr']['today']="Aujourd'hui: ";
coolweather_lang['fr']['tomorrow']="Demain: ";
coolweather_lang['fr']['daytime']="Journ&#233;e";
coolweather_lang['fr']['nighttime']="Nuit";
coolweather_lang['fr']['loading']="Minute papillon, je vais chercher les informations ...";
coolweather_lang['fr']['city']="Ville: (Exemple: Paris, France)";
coolweather_lang['fr']['firstseehint']="Peut-&#234;tre utilisez-vous ce navigateur pour la premi&#232;re fois, aussi devez-vous d&#233;terminer de quelle ville vous souhaitez conna&#238;tre les pr&#233;visions m&#233;t&#233;orologiques.";
coolweather_lang['fr']['location']="Lieu: ";
coolweather_lang['fr']['nocitymatched']="La ville que vous cherchez ne figure pas dans nos bases de donn&#233;es!";
coolweather_lang['fr']['morecitymatched']="Il y a plus d'une ville portant ce nom, choisissez celle que vous voulez.";
coolweather_lang['fr']['back']="back";
coolweather_lang['fr']['choosecity']='Choisissez la ville';
coolweather_lang['fr']['unit']='Unit&#233; de mesure: ';
coolweather_lang['fr']['unita']='Am&#233;ricaine';
coolweather_lang['fr']['unitm']='M&#233;trique';
coolweather_lang['fr']['N']='N';
coolweather_lang['fr']['S']='S';
coolweather_lang['fr']['W']='W';
coolweather_lang['fr']['E']='E';
coolweather_lang['fr']['NE']='NE';
coolweather_lang['fr']['SE']='SE';
coolweather_lang['fr']['NW']='NW';
coolweather_lang['fr']['SW']='SW';
coolweather_lang['fr']['ENE']='ENE';
coolweather_lang['fr']['ESE']='ESE';
coolweather_lang['fr']['WNW']='WNW';
coolweather_lang['fr']['WSW']='WSW';
coolweather_lang['fr']['NNE']='NNE';
coolweather_lang['fr']['NNW']='NNW';
coolweather_lang['fr']['SSE']='SSE';
coolweather_lang['fr']['SSW']='SSW';

// Italian translate by Franco Di Pangrazio
coolweather_lang['it']=[];
coolweather_lang['it']['rpcnotready']="Il Server di Cool Weather al momento non &egrave; disponibile";
coolweather_lang['it']['currentconditions']="Condizioni attuali";
coolweather_lang['it']['changecity']="Cambia citt&agrave;";
coolweather_lang['it']['temperature']="Temperatura: ";
coolweather_lang['it']['hightemperature']="Massima: ";
coolweather_lang['it']['lowtemperature']="Minima: ";
coolweather_lang['it']['realfeel']="Percepita&reg;: ";
coolweather_lang['it']['realfeelhigh']="Sensation&reg; Maxi: ";
coolweather_lang['it']['realfeellow']="Sensation&reg; Mini: ";
coolweather_lang['it']['windspeed']="Velocit&agrave; vento: ";
coolweather_lang['it']['windforce']="Forza vento: ";
coolweather_lang['it']['scale']="scala";
coolweather_lang['it']['winddirection']="Direzione vento: ";
coolweather_lang['it']['today']="Oggi: ";
coolweather_lang['it']['tomorrow']="Domani: ";
coolweather_lang['it']['daytime']="Giorno";
coolweather_lang['it']['nighttime']="Notte";
coolweather_lang['it']['loading']="Ricerca informazioni ...";
coolweather_lang['it']['city']="Citt&#224;: (Esempio: Roma)";
coolweather_lang['it']['firstseehint']="Probabilmente &egrave; la prima volta che visitate il sito con questo browser; per cui dovete sceglire la citt&agrave; per visualizzarne le informazioni metereologiche.";
coolweather_lang['it']['location']="Localit&agrave;: ";
coolweather_lang['it']['nocitymatched']="La citt&agrave; scelta non &egrave; stata trovata";
coolweather_lang['it']['morecitymatched']="Sono state trovate pi&ugrave; localit&agrave;, scegli quella desiderata.";
coolweather_lang['it']['back']="&laquo; indietro";
coolweather_lang['it']['choosecity']='Scegli';
coolweather_lang['it']['unit']='Unit&agrave; di misura: ';
coolweather_lang['it']['unita']='&#176;F';
coolweather_lang['it']['unitm']='&#176;C';
coolweather_lang['it']['N']='N';
coolweather_lang['it']['S']='S';
coolweather_lang['it']['W']='O';
coolweather_lang['it']['E']='E';
coolweather_lang['it']['NE']='NE';
coolweather_lang['it']['SE']='SE';
coolweather_lang['it']['NW']='NO';
coolweather_lang['it']['SW']='SO';
coolweather_lang['it']['ENE']='ENE';
coolweather_lang['it']['ESE']='ESE';
coolweather_lang['it']['WNW']='ONO';
coolweather_lang['it']['WSW']='OSO';
coolweather_lang['it']['NNE']='NNE';
coolweather_lang['it']['NNW']='NNO';
coolweather_lang['it']['SSE']='SSE';
coolweather_lang['it']['SSW']='SSO';

// Japanese translation come from http://f40.aaa.livedoor.jp/~benjamin/?p=209
coolweather_lang['ja'] = [];
coolweather_lang['ja']['rpcnotready'] = "Cool Weather RPC is not ready.";
coolweather_lang['ja']['currentconditions'] = "&#29694;&#22312;&#12398;&#29366;&#27841;";
coolweather_lang['ja']['changecity'] = "&#37117;&#24066;&#12398;&#22793;&#26356;";
coolweather_lang['ja']['temperature'] = "&#27671;&#28201;: ";
coolweather_lang['ja']['hightemperature'] = "&#26368;&#39640;&#27671;&#28201;: ";
coolweather_lang['ja']['lowtemperature'] = "&#26368;&#20302;&#27671;&#28201;: ";
coolweather_lang['ja']['realfeel'] = "&#20307;&#24863;&#28201;&#24230;<sup>&reg;</sup>: ";
coolweather_lang['ja']['realfeelhigh'] = "&#20307;&#24863;&#28201;&#24230;<sup>&reg;</sup> &#26368;&#39640;: ";
coolweather_lang['ja']['realfeellow'] = "&#20307;&#24863;&#28201;&#24230;<sup>&reg;</sup> &#26368;&#20302;: ";
coolweather_lang['ja']['windspeed'] = "&#39080;&#36895;: ";
coolweather_lang['ja']['windforce'] = "&#39080;&#12398;&#24375;&#12373;: ";
coolweather_lang['ja']['scale'] = "&#12473;&#12465;&#12540;&#12523;";
coolweather_lang['ja']['winddirection'] = "&#39080;&#21521;: ";
coolweather_lang['ja']['today'] = "&#26412;&#26085;";
coolweather_lang['ja']['tomorrow'] = "&#26126;&#26085;";
coolweather_lang['ja']['daytime'] = "&#26172;";
coolweather_lang['ja']['nighttime'] = "&#22812;";
coolweather_lang['ja']['loading'] = "Loading...";
coolweather_lang['ja']['city'] = "&#37117;&#24066;: (&#20363;: Chiba)";
coolweather_lang['ja']['firstseehint'] = "&#21021;&#12417;&#12390;&#12398;&#26041;&#12399;&#37117;&#24066;&#12434;&#35373;&#23450;&#12375;&#12390;&#12367;&#12384;&#12373;&#12356;&#12290;";
coolweather_lang['ja']['location'] = "Location: ";
coolweather_lang['ja']['nocitymatched'] = "&#37117;&#24066;&#21517;&#12364;&#19968;&#33268;&#12375;&#12414;&#12379;&#12435;&#65281;";
coolweather_lang['ja']['morecitymatched'] = "&#35079;&#25968;&#12398;&#37117;&#24066;&#12364;&#35211;&#12388;&#12363;&#12426;&#12414;&#12375;&#12383;&#12398;&#12391;&#12289;&#12381;&#12398;&#20013;&#12363;&#12425;&#36984;&#25246;&#12375;&#12390;&#12367;&#12384;&#12373;&#12356;&#12290;";
coolweather_lang['ja']['back'] = "&#25147;&#12427;";
coolweather_lang['ja']['choosecity'] = 'choose your city';
coolweather_lang['ja']['N'] = '&#21271;';
coolweather_lang['ja']['S'] = '&#21335;';
coolweather_lang['ja']['W'] = '&#35199;';
coolweather_lang['ja']['E'] = '&#26481;';
coolweather_lang['ja']['NE'] = '&#21271;&#26481;';
coolweather_lang['ja']['SE'] = '&#21335;&#26481;';
coolweather_lang['ja']['NW'] = '&#21271;&#35199;';
coolweather_lang['ja']['SW'] = '&#21335;&#35199;';
coolweather_lang['ja']['ENE'] = '&#26481;&#21271;&#26481;';
coolweather_lang['ja']['ESE'] = '&#26481;&#21335;&#26481;';
coolweather_lang['ja']['WNW'] = '&#35199;&#21271;&#35199;';
coolweather_lang['ja']['WSW'] = '&#35199;&#21335;&#35199;';
coolweather_lang['ja']['NNE'] = '&#21271;&#21271;&#26481;';
coolweather_lang['ja']['NNW'] = '&#21271;&#21271;&#35199;';
coolweather_lang['ja']['SSE'] = '&#21335;&#21335;&#26481;';
coolweather_lang['ja']['SSW'] = '&#21335;&#21335;&#35199;';

// dutch translate by Jordy
coolweather_lang['nl'] = [];
coolweather_lang['nl']['rpcnotready'] = "Error! Het weer kon niet worden weergegeven";
coolweather_lang['nl']['currentconditions'] = "Actueel weer";
coolweather_lang['nl']['changecity'] = "Verander de plaats";
coolweather_lang['nl']['temperature'] = "Temperatuur: ";
coolweather_lang['nl']['hightemperature'] = "Max Temp: ";
coolweather_lang['nl']['lowtemperature'] = "Min Temp: ";
coolweather_lang['nl']['realfeel'] = "Gevoelstemp&reg;: ";
coolweather_lang['nl']['realfeelhigh'] = "Gevoelstemp&reg; Max: ";
coolweather_lang['nl']['realfeellow'] = "Gevoelstemp&reg; Min: ";
coolweather_lang['nl']['windspeed'] = "Wind snelheid: ";
coolweather_lang['nl']['windforce'] = "Wind kracht: ";
coolweather_lang['nl']['scale'] = "Bf";
coolweather_lang['nl']['winddirection'] = "Wind Richting: ";
coolweather_lang['nl']['today'] = "Vandaag: ";
coolweather_lang['nl']['tomorrow'] = "Morgen: ";
coolweather_lang['nl']['daytime'] = "Dag";
coolweather_lang['nl']['nighttime'] = "Nacht";
coolweather_lang['nl']['loading'] = "Laden...";
coolweather_lang['nl']['city'] = "Plaatsnaam: (bv: Den Haag)";
coolweather_lang['nl']['firstseehint'] = "Eerste keer hier? Vul hier je stad in voor een lokaal weerbericht.";
coolweather_lang['nl']['location'] = "Plaatsnaam: ";
coolweather_lang['nl']['nocitymatched'] = "Plaats onbekend!!";
coolweather_lang['nl']['morecitymatched'] = "Meerdere plaatsen gevonden, selecteer de plaats die je wilt.";
coolweather_lang['nl']['back'] = "terug";
coolweather_lang['nl']['choosecity'] = 'Kies je plaats';
coolweather_lang['nl']['unit'] = 'Meeteenheid: ';
coolweather_lang['nl']['unita'] = 'Ouderwets';
coolweather_lang['nl']['unitm'] = 'Normaal';
coolweather_lang['nl']['N'] = 'N';
coolweather_lang['nl']['S'] = 'Z';
coolweather_lang['nl']['W'] = 'W';
coolweather_lang['nl']['E'] = 'O';
coolweather_lang['nl']['NE'] = 'NO';
coolweather_lang['nl']['SE'] = 'ZO';
coolweather_lang['nl']['NW'] = 'NW';
coolweather_lang['nl']['SW'] = 'ZW';
coolweather_lang['nl']['ENE'] = 'ONO';
coolweather_lang['nl']['ESE'] = 'OZO';
coolweather_lang['nl']['WNW'] = 'WNW';
coolweather_lang['nl']['WSW'] = 'WZW';
coolweather_lang['nl']['NNE'] = 'NNO';
coolweather_lang['nl']['NNW'] = 'NNW';
coolweather_lang['nl']['SSE'] = 'ZZO';
coolweather_lang['nl']['SSW'] = 'ZZW';

// Portuguese translate by Orlando
coolweather_lang['pt'] = [];
coolweather_lang['pt']['rpcnotready'] = "Cool Weather RPC is not ready.";
coolweather_lang['pt']['currentconditions'] = "Condi&#231;&#245;es Actuais";
coolweather_lang['pt']['changecity'] = "Mudar Cidade";
coolweather_lang['pt']['temperature'] = "Temperatura: ";
coolweather_lang['pt']['hightemperature'] = "Max. Temperatura: ";
coolweather_lang['pt']['lowtemperature'] = "Min. Temperatura: ";
coolweather_lang['pt']['realfeel'] = "Sens.Termica<sup>&reg;</sup>: ";
coolweather_lang['pt']['realfeelhigh'] = "Sens.Termica<sup>&reg;</sup> High: ";
coolweather_lang['pt']['realfeellow'] = "Sens.Termica<sup>&reg;</sup> Low: ";
coolweather_lang['pt']['windspeed'] = "Vento/Wind Speed: ";
coolweather_lang['pt']['windforce'] = "Vento/Wind Force: ";
coolweather_lang['pt']['scale'] = "scale";
coolweather_lang['pt']['winddirection'] = "Direc&#231;&#227;o Vento: ";
coolweather_lang['pt']['today'] = "Hoje: ";
coolweather_lang['pt']['tomorrow'] = "Amanh&#227;: ";
coolweather_lang['pt']['daytime'] = "dia";
coolweather_lang['pt']['nighttime'] = "noite";
coolweather_lang['pt']['loading'] = "Loading...";
coolweather_lang['pt']['city'] = "Cidade: (Exemplo: Oporto)";
coolweather_lang['pt']['firstseehint'] = "Se utiliza o browser pela primeira vez, introduza um nome de uma cidade (Maybe you use this browser to see me for the first time, so you need set your city first which you want to see the weather report.)";
coolweather_lang['pt']['location'] = "S&#237;tio: ";
coolweather_lang['pt']['nocitymatched'] = "There is no city matched your input!";
coolweather_lang['pt']['morecitymatched'] = "There are more than one city matched your input, select which you want.";
coolweather_lang['pt']['back'] = "back";
coolweather_lang['pt']['choosecity'] = 'escolha cidade';
coolweather_lang['pt']['unit'] = 'Sistema de medidas: ';
coolweather_lang['pt']['unita'] = 'Americano';
coolweather_lang['pt']['unitm'] = 'M&#233;trico';
coolweather_lang['pt']['N'] = 'N';
coolweather_lang['pt']['S'] = 'S';
coolweather_lang['pt']['W'] = 'W';
coolweather_lang['pt']['E'] = 'E';
coolweather_lang['pt']['NE'] = 'NE';
coolweather_lang['pt']['SE'] = 'SE';
coolweather_lang['pt']['NW'] = 'NW';
coolweather_lang['pt']['SW'] = 'SW';
coolweather_lang['pt']['ENE'] = 'ENE';
coolweather_lang['pt']['ESE'] = 'ESE';
coolweather_lang['pt']['WNW'] = 'WNW';
coolweather_lang['pt']['WSW'] = 'WSW';
coolweather_lang['pt']['NNE'] = 'NNE';
coolweather_lang['pt']['NNW'] = 'NNW';
coolweather_lang['pt']['SSE'] = 'SSE';
coolweather_lang['pt']['SSW'] = 'SSW';

// Simplified Chinese translate by Ma Bingyao
coolweather_lang['zh-cn'] = [];
coolweather_lang['zh-cn']['rpcnotready'] = "Cool Weather &#36828;&#31243;&#36807;&#31243;&#35843;&#29992;&#23578;&#26410;&#23601;&#32490;&#12290;";
coolweather_lang['zh-cn']['currentconditions'] = "&#24403;&#21069;&#22825;&#27668;&#24773;&#20917;";
coolweather_lang['zh-cn']['changecity'] = "&#26356;&#25913;&#22478;&#24066;";
coolweather_lang['zh-cn']['temperature'] = "&#23454;&#38469;&#28201;&#24230;&#65306;";
coolweather_lang['zh-cn']['hightemperature'] = "&#26368;&#39640;&#23454;&#38469;&#28201;&#24230;&#65306;";
coolweather_lang['zh-cn']['lowtemperature'] = "&#26368;&#20302;&#23454;&#38469;&#28201;&#24230;&#65306;";
coolweather_lang['zh-cn']['realfeel'] = "&#24863;&#35273;&#28201;&#24230;&#65306;";
coolweather_lang['zh-cn']['realfeelhigh'] = "&#26368;&#39640;&#24863;&#35273;&#28201;&#24230;&#65306;";
coolweather_lang['zh-cn']['realfeellow'] = "&#26368;&#20302;&#24863;&#35273;&#28201;&#24230;&#65306;";
coolweather_lang['zh-cn']['windspeed'] = "&#39118;&#36895;&#65306;";
coolweather_lang['zh-cn']['windforce'] = "&#39118;&#21147;&#65306;";
coolweather_lang['zh-cn']['scale'] = "&#32423;";
coolweather_lang['zh-cn']['winddirection'] = "&#39118;&#21521;&#65306;";
coolweather_lang['zh-cn']['today'] = "&#20170;&#22825;&#65306;";
coolweather_lang['zh-cn']['tomorrow'] = "&#26126;&#22825;&#65306;";
coolweather_lang['zh-cn']['daytime'] = "&#30333;&#22825;";
coolweather_lang['zh-cn']['nighttime'] = "&#22812;&#38388;";
coolweather_lang['zh-cn']['loading'] = "&#36733;&#20837;&#20013;&#8230;&#8230;";
coolweather_lang['zh-cn']['city'] = "&#22478;&#24066;&#65306;&#65288;&#20363;&#22914;&#65306;Shanghai&#65289;";
coolweather_lang['zh-cn']['firstseehint'] = "&#24744;&#21487;&#33021;&#26159;&#31532;&#19968;&#27425;&#20351;&#29992;&#35813;&#27983;&#35272;&#22120;&#30475;&#21040;&#25105;&#65292;&#22240;&#27492;&#24744;&#38656;&#35201;&#39318;&#20808;&#35774;&#32622;&#19968;&#19979;&#20320;&#24076;&#26395;&#30475;&#21040;&#22825;&#27668;&#39044;&#25253;&#30340;&#22478;&#24066;&#12290;";
coolweather_lang['zh-cn']['location'] = "&#20855;&#20307;&#20301;&#32622;&#65306;";
coolweather_lang['zh-cn']['nocitymatched'] = "&#27809;&#26377;&#22478;&#24066;&#21305;&#37197;&#20320;&#30340;&#36755;&#20837;&#65281;";
coolweather_lang['zh-cn']['morecitymatched'] = "&#36825;&#37324;&#26377;&#19981;&#27490;&#19968;&#20010;&#22478;&#24066;&#21305;&#37197;&#24744;&#30340;&#36755;&#20837;&#65292;&#35831;&#36873;&#25321;&#24744;&#24819;&#35201;&#30340;&#37027;&#20010;&#12290;";
coolweather_lang['zh-cn']['back'] = "&#21518;&#36864;";
coolweather_lang['zh-cn']['choosecity'] = 'choose your city';
coolweather_lang['zh-cn']['unit'] = '&#21333;&#20301;&#65306;';
coolweather_lang['zh-cn']['unita'] = '&#32654;&#21046;';
coolweather_lang['zh-cn']['unitm'] = '&#20844;&#21046;';
coolweather_lang['zh-cn']['N'] = '&#21271;';
coolweather_lang['zh-cn']['S'] = '&#21335;';
coolweather_lang['zh-cn']['W'] = '&#35199;';
coolweather_lang['zh-cn']['E'] = '&#19996;';
coolweather_lang['zh-cn']['NE'] = '&#19996;&#21271;';
coolweather_lang['zh-cn']['SE'] = '&#19996;&#21335;';
coolweather_lang['zh-cn']['NW'] = '&#35199;&#21271;';
coolweather_lang['zh-cn']['SW'] = '&#35199;&#21335;';
coolweather_lang['zh-cn']['ENE'] = '&#19996;&#21271;&#20559;&#19996;';
coolweather_lang['zh-cn']['ESE'] = '&#19996;&#21335;&#20559;&#19996;';
coolweather_lang['zh-cn']['WNW'] = '&#35199;&#21271;&#20559;&#35199;';
coolweather_lang['zh-cn']['WSW'] = '&#35199;&#21335;&#20559;&#35199;';
coolweather_lang['zh-cn']['NNW'] = '&#35199;&#21271;&#20559;&#21271;';
coolweather_lang['zh-cn']['NNE'] = '&#19996;&#21271;&#20559;&#21271;';
coolweather_lang['zh-cn']['SSW'] = '&#35199;&#21335;&#20559;&#21335;';
coolweather_lang['zh-cn']['SSE'] = '&#19996;&#21335;&#20559;&#21335;';

// Traditional Chinese translate by He zhiqiang
coolweather_lang['zh-tw'] = [];
coolweather_lang['zh-tw']['rpcnotready'] = "Cool Weather &#36960;&#31243;&#31243;&#24207;&#21628;&#21483;&#23578;&#26410;&#23601;&#32210;&#12290;";
coolweather_lang['zh-tw']['currentconditions'] = "&#30070;&#21069;&#22825;&#27683;&#24773;&#27841;";
coolweather_lang['zh-tw']['changecity'] = "&#26356;&#25913;&#22478;&#24066;";
coolweather_lang['zh-tw']['temperature'] = "&#23526;&#38555;&#28331;&#24230;&#65306;";
coolweather_lang['zh-tw']['hightemperature'] = "&#26368;&#39640;&#23526;&#38555;&#28331;&#24230;&#65306;";
coolweather_lang['zh-tw']['lowtemperature'] = "&#26368;&#20302;&#23526;&#38555;&#28331;&#24230;&#65306;";
coolweather_lang['zh-tw']['realfeel'] = "&#24863;&#35258;&#28331;&#24230;&#65306;";
coolweather_lang['zh-tw']['realfeelhigh'] = "&#26368;&#39640;&#24863;&#35258;&#28331;&#24230;&#65306;";
coolweather_lang['zh-tw']['realfeellow'] = "&#26368;&#20302;&#24863;&#35258;&#28331;&#24230;&#65306;";
coolweather_lang['zh-tw']['windspeed'] = "&#39080;&#36895;&#65306;";
coolweather_lang['zh-tw']['windforce'] = "&#39080;&#21147;&#65306;";
coolweather_lang['zh-tw']['scale'] = "&#32026;";
coolweather_lang['zh-tw']['winddirection'] = "&#39080;&#21521;&#65306;";
coolweather_lang['zh-tw']['today'] = "&#20170;&#22825;&#65306;";
coolweather_lang['zh-tw']['tomorrow'] = "&#26126;&#22825;&#65306;";
coolweather_lang['zh-tw']['daytime'] = "&#30333;&#22825;";
coolweather_lang['zh-tw']['nighttime'] = "&#22812;&#38291;";
coolweather_lang['zh-tw']['loading'] = "&#36617;&#20837;&#20013;&#8230;&#8230;";
coolweather_lang['zh-tw']['city'] = "&#22478;&#24066;&#65306;&#65288;&#20363;&#22914;&#65306;Shanghai&#65289;";
coolweather_lang['zh-tw']['firstseehint'] = "&#24744;&#21487;&#33021;&#26159;&#31532;&#19968;&#27425;&#20351;&#29992;&#35442;&#27969;&#35261;&#22120;&#30475;&#21040;&#25105;&#65292;&#22240;&#27492;&#24744;&#38656;&#35201;&#39318;&#20808;&#35373;&#32622;&#19968;&#19979;&#20320;&#24076;&#26395;&#30475;&#21040;&#22825;&#27683;&#38928;&#22577;&#30340;&#22478;&#24066;&#12290;";
coolweather_lang['zh-tw']['location'] = "&#20855;&#39636;&#20301;&#32622;&#65306;";
coolweather_lang['zh-tw']['nocitymatched'] = "&#27794;&#26377;&#22478;&#24066;&#21305;&#37197;&#20320;&#30340;&#36664;&#20837;&#65281;";
coolweather_lang['zh-tw']['morecitymatched'] = "&#36889;&#35023;&#26377;&#19981;&#27490;&#19968;&#20491;&#22478;&#24066;&#21305;&#37197;&#24744;&#30340;&#36664;&#20837;&#65292;&#35531;&#36984;&#25799;&#24744;&#24819;&#35201;&#30340;&#37027;&#20491;&#12290;";
coolweather_lang['zh-tw']['back'] = "&#24460;&#36864;";
coolweather_lang['zh-tw']['choosecity'] = 'choose your city';
coolweather_lang['zh-tw']['unit'] = '&#21934;&#20301;&#65306;';
coolweather_lang['zh-tw']['unita'] = '&#32654;&#21046;';
coolweather_lang['zh-tw']['unitm'] = '&#20844;&#21046;';
coolweather_lang['zh-tw']['N'] = '&#21271;';
coolweather_lang['zh-tw']['S'] = '&#21335;';
coolweather_lang['zh-tw']['W'] = '&#35199;';
coolweather_lang['zh-tw']['E'] = '&#26481;';
coolweather_lang['zh-tw']['NE'] = '&#26481;&#21271;';
coolweather_lang['zh-tw']['SE'] = '&#26481;&#21335;';
coolweather_lang['zh-tw']['NW'] = '&#35199;&#21271;';
coolweather_lang['zh-tw']['SW'] = '&#35199;&#21335;';
coolweather_lang['zh-tw']['ENE'] = '&#26481;&#21271;&#20559;&#26481;';
coolweather_lang['zh-tw']['ESE'] = '&#26481;&#21335;&#20559;&#26481;';
coolweather_lang['zh-tw']['WNW'] = '&#35199;&#21271;&#20559;&#35199;';
coolweather_lang['zh-tw']['WSW'] = '&#35199;&#21335;&#20559;&#35199;';
coolweather_lang['zh-tw']['NNW'] = '&#35199;&#21271;&#20559;&#21271;';
coolweather_lang['zh-tw']['NNE'] = '&#26481;&#21271;&#20559;&#21271;';
coolweather_lang['zh-tw']['SSW'] = '&#35199;&#21335;&#20559;&#21335;';
coolweather_lang['zh-tw']['SSE'] = '&#26481;&#21335;&#20559;&#21335;';

coolweather_unit = [];
coolweather_unit[0] = [];
coolweather_unit[0]['temp'] = '&deg;F';
coolweather_unit[0]['speed'] = ' mph';
coolweather_unit[1] = [];
coolweather_unit[1]['temp'] = '&deg;C';
coolweather_unit[1]['speed'] = ' m/s';

function coolweather_get_windforce(windspeed) {
    var scales = [0.2, 1.5, 3.3, 5.4, 7.9, 10.7, 13.8, 17.1, 20.7, 24.4, 28.4, 32.6];
    for (var i = 0; i < scales.length; i++) {
        if (windspeed <= scales[i]) {
            return i;
        }
    }
    return 12;
}

var coolweather_report = null;

function coolweather_get_location(city) {
    if (coolweather_rpc != null) {
        coolweather_rpc.get_location(city, get_location_callback);
    }
    else {
        alert(coolweather_lang[coolweather_nav_lng]['rpcnotready']);
    }
}

function coolweather_get_weather(locid, metric) {
    var coolweather_container = document.getElementById('coolweather_container');
    coolweather_container.innerHTML = ['<div id="coolweather_hint">', coolweather_lang[coolweather_nav_lng]['loading'], '</div>'].join('');
    if (coolweather_rpc != null) {
        window.setTimeout(["coolweather_rpc.get_weather('", locid, "', ", metric, ", get_weather_callback);"].join(''), 100);
    }
    else {
        window.setTimeout(["coolweather_get_weather('", locid, "', ", metric, ");"].join(''), 100);
    }
}

function coolweather_input_city() {
    delete_cookie('coolweather_locid');
    coolweather_init();
}

function coolweather_set_weather(number, day_or_night) {
    var weather = unserialize(coolweather_report);
    var locid = weather['locid'];
    var metric = weather['metric'];
    var coolweather_hint = document.getElementById('coolweather_hint');
    var unit = [coolweather_lang[coolweather_nav_lng]['unit'],
        '<a href="javascript:void(0)" onclick="coolweather_get_weather(',
        "'", locid, "', ", '0);" style="display: inline; padding: 0; margin: 0">',
        coolweather_lang[coolweather_nav_lng]['unita'], '</a> ',
        '<a href="javascript:void(0)" onclick="coolweather_get_weather(',
        "'", locid, "', ", '1);" style="display: inline; padding: 0; margin: 0">',
        coolweather_lang[coolweather_nav_lng]['unitm'], '</a>'].join('');
    if (number == 0) {
        if (metric == 1) {
            var windforce = [coolweather_lang[coolweather_nav_lng]['windforce'],
                coolweather_get_windforce(weather['windspeed']), ' ',
                coolweather_lang[coolweather_nav_lng]['scale'], '<br />'].join('');
        }
        else {
            var windforce = '';
        }
        coolweather_hint.innerHTML = ['<div style="margin-bottom: 0.5em; display: block;"><strong>',
            coolweather_lang[coolweather_nav_lng]['currentconditions'],
            '</strong><br /><br /><img src="', coolweather_iconspath,
            weather['weathericon'], '.gif" alt="', weather['weathertext'],
            '" align="left" valign="absmiddle" width="64" height="40" style="margin-right: 0.5em" />',
            '<a href="javascript:void(0)" onclick="coolweather_input_city();" title="',
            coolweather_lang[coolweather_nav_lng]['changecity'],
            '" style="display: inline; padding: 0; margin: 0">', weather['city'], '</a><br />',
            weather['state'], '</div><br />', weather['weathertext'], '<br />',
            coolweather_lang[coolweather_nav_lng]['temperature'],
            weather['temperature'], coolweather_unit[metric]['temp'], '<br />',
            coolweather_lang[coolweather_nav_lng]['realfeel'],
            weather['realfeel'], coolweather_unit[metric]['temp'], '<br />',
            coolweather_lang[coolweather_nav_lng]['windspeed'],
            weather['windspeed'], coolweather_unit[metric]['speed'], '<br />',
            windforce,
            coolweather_lang[coolweather_nav_lng]['winddirection'],
            coolweather_lang[coolweather_nav_lng][weather['winddirection']], '<br />',
            coolweather_lang[coolweather_nav_lng]['today'],
            '<a href="javascript:void(0)" onclick="coolweather_set_weather(1, 0);" ',
            'style="display: inline; padding: 0; margin: 0">',
            coolweather_lang[coolweather_nav_lng]['daytime'],
            '</a> <a href="javascript:void(0)" onclick="coolweather_set_weather(1, 1);" ',
            'style="display: inline; padding: 0; margin: 0">',
            coolweather_lang[coolweather_nav_lng]['nighttime'], '</a><br />',
            coolweather_lang[coolweather_nav_lng]['tomorrow'],
            '<a href="javascript:void(0)" onclick="coolweather_set_weather(2, 0);" ',
            'style="display: inline; padding: 0; margin: 0">',
            coolweather_lang[coolweather_nav_lng]['daytime'],
            '</a> <a href="javascript:void(0)" onclick="coolweather_set_weather(2, 1);" ',
            'style="display: inline; padding: 0; margin: 0">',
            coolweather_lang[coolweather_nav_lng]['nighttime'], '</a><br />', unit].join('');
    }
    else {
        if (metric == 1) {
            var windforce = [coolweather_lang[coolweather_nav_lng]['windforce'],
            coolweather_get_windforce(weather[number][day_or_night]['windspeed']), ' ',
            coolweather_lang[coolweather_nav_lng]['scale'], '<br />'].join('');
        }
        else {
            var windforce = '';
        }
        coolweather_hint.innerHTML = ['<div style="margin-bottom: 0.5em; display: block;"><strong>',
            ((number == 1) ? coolweather_lang[coolweather_nav_lng]['today'] : coolweather_lang[coolweather_nav_lng]['tomorrow']),
            ((day_or_night == 0) ? coolweather_lang[coolweather_nav_lng]['daytime'] : coolweather_lang[coolweather_nav_lng]['nighttime']),
            '</strong><br /><br />',
            '<img src="', coolweather_iconspath,
            weather[number][day_or_night]['weathericon'], '.gif" alt="',
            weather[number][day_or_night]['weathertext'],
            '" align="left" valign="absmiddle" width="64" height="40" style="margin-right: 0.5em" />',
            '<a href="javascript:void(0)" onclick="coolweather_input_city();" title="',
            coolweather_lang[coolweather_nav_lng]['changecity'],
            '" style="display: inline; padding: 0; margin: 0">',
            weather['city'], '</a><br />', weather['state'],
            '</div><br />', weather[number][day_or_night]['weathertext'], '<br />',
            coolweather_lang[coolweather_nav_lng]['hightemperature'],
            weather[number][day_or_night]['hightemperature'], coolweather_unit[metric]['temp'], '<br />',
            coolweather_lang[coolweather_nav_lng]['lowtemperature'],
            weather[number][day_or_night]['lowtemperature'], coolweather_unit[metric]['temp'], '<br />',
            coolweather_lang[coolweather_nav_lng]['realfeelhigh'],
            weather[number][day_or_night]['realfeelhigh'], coolweather_unit[metric]['temp'], '<br />',
            coolweather_lang[coolweather_nav_lng]['realfeellow'],
            weather[number][day_or_night]['realfeellow'], coolweather_unit[metric]['temp'], '<br />',
            coolweather_lang[coolweather_nav_lng]['windspeed'],
            weather[number][day_or_night]['windspeed'], coolweather_unit[metric]['speed'], '<br />',
            windforce,
            coolweather_lang[coolweather_nav_lng]['winddirection'],
            coolweather_lang[coolweather_nav_lng][weather[number][day_or_night]['winddirection']], '<br />',
            '<a href="javascript:void(0)" onclick="coolweather_set_weather(0);" ',
            'style="display: inline; padding: 0; margin: 0">',
            coolweather_lang[coolweather_nav_lng]['currentconditions'], '</a><br />',
            coolweather_lang[coolweather_nav_lng]['today'],
            '<a href="javascript:void(0)" onclick="coolweather_set_weather(1, 0);" ',
            'style="display: inline; padding: 0; margin: 0">',
            coolweather_lang[coolweather_nav_lng]['daytime'],
            '</a> <a href="javascript:void(0)" onclick="coolweather_set_weather(1, 1);" ',
            'style="display: inline; padding: 0; margin: 0">',
            coolweather_lang[coolweather_nav_lng]['nighttime'], '</a><br />',
            coolweather_lang[coolweather_nav_lng]['tomorrow'],
            '<a href="javascript:void(0)" onclick="coolweather_set_weather(2, 0);" ',
            'style="display: inline; padding: 0; margin: 0">',
            coolweather_lang[coolweather_nav_lng]['daytime'],
            '</a> <a href="javascript:void(0)" onclick="coolweather_set_weather(2, 1);" ',
            'style="display: inline; padding: 0; margin: 0">',
            coolweather_lang[coolweather_nav_lng]['nighttime'], '</a><br />', unit].join('');
    }
}

function get_weather_callback(result, args) {
    if (result instanceof PHPRPC_Error) {
        var coolweather_hint = document.getElementById('coolweather_hint');
        coolweather_hint.innerHTML = ['<img src="', coolweather_iconspath, 'swa.gif" alt="error" align="left" width="64" height="40" /><span style="color: red">', result.errstr, '</span>'].join('');
    }
    else {
        result['locid'] = args[0];
        result['metric'] = args[1];
        var weather = serialize(result);
        set_cookie('coolweather_metric', args[1]);
        set_cookie('coolweather_weather', weather, 900000);
        coolweather_report = weather;
        coolweather_set_weather(0);
    }
}

function get_location_callback(result) {
    var metric = get_cookie('coolweather_metric');
    if (metric == null) metric = 1;
    var coolweather_hint = document.getElementById('coolweather_hint');
    var coolweather_input = document.getElementById('coolweather_input');
    if (result instanceof PHPRPC_Error) {
        coolweather_hint.innerHTML = ['<span style="color: red">', result.errstr, '</span>'].join('');
        coolweather_input.disabled = false;
    }
    else if (result.length == 0) {
        coolweather_hint.innerHTML = coolweather_lang[coolweather_nav_lng]['nocitymatched'];
        coolweather_input.disabled = false;
        coolweather_input.focus();
    }
    else if (result.length == 1) {
        set_cookie('coolweather_locid', result[0]['location']);
        coolweather_get_weather(result[0]['location'], metric);
    }
    else {
        coolweather_hint.innerHTML = [coolweather_lang[coolweather_nav_lng]['morecitymatched'],
            '<br /><div align="right"><a href="javascript:void(0)" onclick="coolweather_input_city()" style="display: inline; padding: 0; margin: 0">',
            coolweather_lang[coolweather_nav_lng]['back'], '</a></div>'].join('');
        var coolweather_input_container = document.getElementById('coolweather_input_container');
        coolweather_input_container.innerHTML = ['<label for="coolweather_input">', coolweather_lang[coolweather_nav_lng]['location'], '</label><br />'].join('');
        coolweather_input = document.createElement('select');
        var opt = document.createElement('option');
        opt.text = coolweather_lang[coolweather_nav_lng]['choosecity'];
        opt.value = '';
        opt.defaultSelected = true;
        if (coolweather_input.options.add) {
            coolweather_input.options.add(opt);
        }
        else {
            coolweather_input.appendChild(opt);
        }
        for (var i = 0; i < result.length; i++) {
            var opt = document.createElement('option');
            opt.text = [result[i]['city'], result[i]['state']].join(', ');
            opt.value = result[i]['location'];
            if (coolweather_input.options.add) {
                coolweather_input.options.add(opt);
            }
            else {
                coolweather_input.appendChild(opt);
            }
        }
        coolweather_input.id = "coolweather_input";
        coolweather_input.onchange = function () {
            var locid = this.value;
            set_cookie('coolweather_locid', locid);
            coolweather_get_weather(locid, metric);
        }
        coolweather_input_container.appendChild(coolweather_input);
        coolweather_input.focus();
    }
}

function on_coolweather_city_input(event) {
    if (window.event) event = window.event;
    if (event.keyCode == 13) {
        var city = this.value;
        var coolweather_hint = document.getElementById('coolweather_hint');
        coolweather_hint.innerHTML = coolweather_lang[coolweather_nav_lng]['loading'];
        var coolweather_input = document.getElementById('coolweather_input');
        coolweather_input.disabled = true;
        coolweather_get_location(city);
    }
}

function coolweather_init() {
    var coolweather_container = document.getElementById('coolweather_container');
    var locid = get_cookie('coolweather_locid');

    if (!rpc_plg_enable('coolweather')) {
	return;
    } else {
	var div = document.getElementById('coolweather_div');
        div.style.display = "block";
    }

    if (locid == null) {
        coolweather_container.innerHTML = ['<div id="coolweather_input_container">',
            '<label for="coolweather_input">',
            coolweather_lang[coolweather_nav_lng]['city'],
            '</label><br /><input type="text" id="coolweather_input" /></div><div id="coolweather_hint">',
            coolweather_lang[coolweather_nav_lng]['firstseehint'], '</div>'].join('');
        var coolweather_input = document.getElementById('coolweather_input');
        coolweather_input.onkeypress = on_coolweather_city_input;
        coolweather_input.focus();
    }
    else {
        coolweather_container.innerHTML = ['<div id="coolweather_hint">', coolweather_lang[coolweather_nav_lng]['loading'], '</div>'].join('');
        var metric = get_cookie('coolweather_metric');
        if (metric == null) metric = 1;
        if (get_cookie('coolweather_weather') == null) {
            coolweather_get_weather(locid, metric);
        }
        else {
            coolweather_report = get_cookie('coolweather_weather');
            coolweather_set_weather(0);
        }
    }
}
