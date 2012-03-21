function  initMozTextOverflow(obj)
{

	function re_render()
	{
		doMozTextOverflow(obj);
	}
	setTimeout(re_render,0);

}


function doMozTextOverflow(obj)
{

	function _overflow(e)
	{
		var el = e.currentTarget;
		el.className="_textOverflow";
	}


	function _underflow(e)
	{
		var el = e.currentTarget;
		el.className="_textUnderflow";
	}



	obj.className="_textUnderflow";
	obj.addEventListener("overflow", _overflow, false);
	obj.addEventListener("underflow", _underflow, false);
	obj.ins = document.createElement("ins");
	obj.ins.innerHTML="&hellip;";
	obj.appendChild(obj.ins);



	obj.onmousedown = function(e)
	{
		this.selectStartX = e.clientX - document.getBoxObjectFor(this).x;
	}

	obj.onmouseup = function(e)
	{
		this.selectStartX = null;
	}

	obj.onmousemove = function(e)
	{
		if(this.selectStartX!=null )
		{
			var mx =  e.clientX - this.selectStartX;
			var ex = 	this.offsetWidth -  this.selectStartX;

			if( ( ex - mx) < (this.ins.offsetWidth+3) )
			{
				if(this.className!="_textUnderflow")
				{
					this.className="_textUnderflow";
					this.scrollLeft=0;
					var box =  document.createElement("input");
					box.setAttribute("type","text");
					box.value=1111
					this.appendChild(box);
					box.select();
					this.removeChild(box);
					this.focus();
				}
			}
			else
			{
				if(this.className!="_textOverflow")
				{
					this.className="_textOverflow"
				}

			}
			return false;
		}
	};

}
