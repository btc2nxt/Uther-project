/// tip users 0.1.1
contract Tip
{
    uint8 maxTipsLen; //the contract contains tips ceiling, default 32
    uint8 maxTipQuantity; //every tip can not overtake the max, default 32
    uint totalAmount;
    uint totalTip; //has create new tips

    struct OneTip
    {
		address tipper; //who create this tip
		uint amount; //total of this tip
		uint8 quantity; //how manys tips will donate 
        bool randomTip;   //random it 
		uint startDate; //when to start the tip
		uint8 snappedQuantity; //has snapped quantity
		uint snappedAmount; //has snapped amount
    }

	//record who get a tip, so he/she can not snap anther tip unless the tip has finished;
	struct TipRecord
	{
		uint8 tipID;
		address snapper;
		uint amount;
		uint snapDate;
	}

    OneTip[] public tips;
	TipRecord[] public tipRecords;

    // if snap a tip, stores the snapper's address.
    mapping(address => bool) public snappers;

    function Tip(uint8 _maxTipLen, uint8 _maxTipQuantity )
    {
		maxTipsLen = _maxTipLen;
		maxTipQuantity = _maxTipQuantity;
		totalTip = 0;
		totalAmount = 0;
    }

    // create a new tip for users to snap, afterHours=0 ,start now
    function newTip(uint _amount, uint8 _quantity, bool _randomTip, uint _afterHours) returns (uint)
    {
        //over the ceiling, less then 1 tip
		if (tips.length == maxTipsLen  || _quantity < 1)
            throw;
		tips.push(OneTip({tipper: msg.sender, amount: _amount, quantity: _quantity, randomTip: _randomTip , startDate: now + _afterHours * 1 hours, snappedQuantity: 0, snappedAmount:0 }));
		return tips.length;
    }

    /// snap a tip
    function snapTip(uint8 tipId)
    {
        //tips is empty, throw a error, in test using return
		if (tips.length == 0)
			return; //deploy = throw
		// check snap or not, or tips is has tip left
		bool snapped = isSnapped(msg.sender,tipId);
        if (snapped || tips[tipId].quantity == tips[tipId].snappedQuantity)
            return; //deploy =throw
        //calculate the amount of this tip
		OneTip t = tips[tipId];
		uint nAmount = (t.amount-t.snappedAmount) / (t.quantity - t.snappedQuantity);
		
		//random : 1/3--5/3
		if (t.randomTip)
		{
			nAmount = nAmount*((block.number - 1) % 5 +1)/3;
		}
		if (t.quantity - t.snappedQuantity ==1)
			nAmount = t.amount - t.snappedAmount;

		t.snappedAmount = t.snappedAmount + nAmount;
		t.snappedQuantity++;
		msg.sender.send(nAmount);

		//store the tip to tipRecords
		if (t.snappedQuantity < t.quantity)
		{
			uint8 recordId = spareTipRecord(tipId);
			tipRecords[recordId].tipID =tipId;
			tipRecords[recordId].snapper =msg.sender;
			tipRecords[recordId].amount =nAmount;
			tipRecords[recordId].snapDate = now;
		} else  // = ,clear records, and save to the total
		{
			totalAmount = totalAmount + t.amount;
			totalTip++;
			clearTipRecords(tipId);
		}
    }

	function spareTipRecord(uint8 tipId) returns (uint8)
	{
		if (tipRecords.length ==0)
		{
			tipRecords.length++;
			return(0);
		}

		for (uint8 i = 0; i < tipRecords.length; ++i)
		{
			if (tipRecords[i].amount ==0)
				return i;
		}

		//not found any spare row
		tipRecords.length++;
		return uint8(tipRecords.length-1);
	}

	function clearTipRecords(uint tipId)
	{
		for (uint8 i = 0; i < tipRecords.length; ++i)
		{
			if (tipRecords[i].tipID == tipId)
				tipRecords[i].amount =0;
		}
	}
	
	function isSnapped(address _addr, uint8 _tipId) returns(bool)
	{
		for (uint8 i = 0; i < tipRecords.length; ++i)
		{
			if (tipRecords[i].tipID == _tipId && tipRecords[i].snapper == _addr)
				return true;
		}
		return false;
	}	
	
	//1. find a active tip
	//2. if not, find a futuret tip in minutes
	//retrun tipId, minutes
	function findTip() returns(uint8,uint)
	{
		uint8 tipId = 255;
		uint futureMinute = now;
		bool snapped ;
		address _addr =msg.sender;
		for (uint8 i = 0; i < tips.length; ++i)
		{
			if (tips[i].startDate >= now) //future tip
			{
				if (futureMinute > tips[i].startDate /60000)
				{
					tipId = i;
					futureMinute = tips[i].startDate /60000;
				}
			} else if (tips[i].quantity > tips[i].snappedQuantity ) //active tip
			{
				snapped = false;
				//check snapped or not
				for (uint8 j =0; j < tipRecords.length; ++j)
				{
					if (tipRecords[j].snapper == _addr && tipRecords[j].tipID== i)
					{
						snapped = true;	
						break;
					}
				}
				if (!snapped) //found an active tip without snapping it
				{
					tipId = i;
					futureMinute = 0;
					break;
				}
			}
		}
		return(tipId, futureMinute);
	}
}