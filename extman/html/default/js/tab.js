function SelectTab(total, tab){
	for(i=1; i <=total; i++){
		if (i==tab) {
			document.getElementById("tab"+i).className="tab-selected b2";
			document.getElementById("tbContent"+i).style.display="block";
		}else{
			document.getElementById("tab"+i).className="tab b1";
			document.getElementById("tbContent"+i).style.display="none";
     		}
    	}
}
