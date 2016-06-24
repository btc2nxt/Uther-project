/// Comet 0.0.1
contract VACRetriever {
 	bytes8 drawData = '';
	function getVACDrawDataTransactional(uint _contractorId) public returns (bytes8)	{
		drawData = '-1';
		return drawData;
	}
}


contract Comet is VACRetriever {
    uint maxChooseLen; //the contract contains choose ceiling, default 999
    uint8 maxDrawLen; //the contract contains draw ceiling, default 255
    uint minAmount; //every tip can not overtake the max, default 1^18
	uint8 winnerPercent; //default 20%
	uint8 feePercent; //default 5%
    uint totalAmount;
    uint totalChoose; //how many choose have been placed
	address creator;

	//setting parameters interacting with VAC
	bytes8 contractName;
	bytes32 description;
	bytes32 codeLink; //source code http link,e.g.  github/
	bytes32 pattern; //define the accurate string fomula
	uint8 requestRefereeNumber; //3-Max, minimize is 3 referees;
	uint contractorID; //registerId in VAC
	VACRetriever vac; //VAC smart contract;

    struct Draw {
		bytes32 drawName; //every draw may have different name
		uint beginTime;
		uint endTime;
		uint deadline; //referees must inject data before it
		uint placeTime; //when to place it
		bytes8 drawData;
		uint chooseTotal; //total of choose;
    }

	struct Choose {
		uint8 drawId; //active draw id for placing
		address asker; //who place the transaction
		bytes8 data;
		uint amount; //total of this tip
        bool dual;   //person to person to play 
		uint placeTime; //when to place it
		uint refundAmount; //win or refund;
    }

    Choose[] public chooses;
    Draw[] public draws;

	/*
	Created: create the contract;
	Active: user can interact with the contract;
	Funding: prepar for payment;
	Refund: drawData is wrong, so refund;
	Success: data is Ok and do the payment 
	Failed: data is wrong, all funds will be paid back
	*/
	enum State { Created, Active, Funding, Refund, Success, Failed }
	State state;

    function Comet(
		uint _maxChooseLen, 
		uint _minAmount, 
		uint8 _winnerPercent, 
		uint8 _feePercent
	) {
		maxChooseLen = _maxChooseLen;
		minAmount = _minAmount;
		winnerPercent = _winnerPercent;
		feePercent = _feePercent;
		totalChoose = 0;
		totalAmount = 0;
		creator =msg.sender;

		contractName = 'WhatNext';
		description = 'What will happen next month';
		codeLink = 'github.com/btc2nxt';
		pattern = '123:123|WL';
		requestRefereeNumber = 3;
    }

    // creator set a new draw after the last fininsed
    function newDraw(
		bytes32 _drawName, 
		uint _beginTime, 
		uint _endTime, 
		uint _deadline
	) returns (uint) {
		uint nLen = draws.length;
		//TO DO >=drawLen, will recycle the array
		if (state == State.Created || state == State.Success && nLen < maxDrawLen) {
			draws.push(Draw(_drawName, _beginTime, _endTime, _deadline, now,'', 0 ));
			//ensure push ok
			if (nLen < draws.length)
				state = State.Active;
		}
		return draws.length;
    }

    // user place a choose
    function newChoose(uint8 _drawId, bytes8 _data, bool _dual) returns (uint) {
 		Draw d =draws[_drawId];
		//TODO: locate old choose, and replace it with the new
		if (state == State.Active && chooses.length < maxChooseLen) {
			chooses.push(Choose(_drawId, msg.sender, _data, msg.value, _dual, now,0 ));
			d.chooseTotal = d.chooseTotal + msg.value;
		}
		return chooses.length;
    }

    /// get DrawData from VAC by contracotrId
    function getDrawDataFromVAC() {
		bytes8 drawData = vac.getVACDrawDataTransactional(contractorID);		
 		Draw d =draws[draws.length-1];
		d.drawData = drawData;
		// drawData is Ok
		if (drawData ==0xff00ff00ff00ff00)
			state = State.Refund;
		else
			state = State.Funding;
    }

	//fund or refund;
	function payAskers() returns (State) {
		uint drawId = draws.length;
		if (drawId < 1) throw;
		drawId--;
		Draw d =draws[drawId];		
		if (state == State.Funding) {
			for (uint8 i = 0; i < chooses.length; ++i) {
				if (chooses[i].drawId == drawId  && chooses[i].data == d.drawData) {
					chooses[i].refundAmount = chooses[i].amount*(200-feePercent)/100;
					chooses[i].asker.send(chooses[i].amount*(200-feePercent)/100);
				}
			}
			state = State.Success;
			//pay feePercent*requestRefereeNumber% to VAC
			vac.send(d.chooseTotal*feePercent*requestRefereeNumber/10000);
		} 
		else if (state == State.Refund) {
			for (i = 0; i < chooses.length; ++i) {
				if (chooses[i].drawId == drawId  ) {
					chooses[i].refundAmount = chooses[i].amount;
					chooses[i].asker.send(chooses[i].amount);
				}
			}
			state = State.Failed;
		}
		return state;
	}

	//clear chooses for future use
	function clearChooses(uint _drawId) {
		for (uint8 i = 0; i < chooses.length; ++i) {
			if (chooses[i].drawId == _drawId)
				chooses[i].amount =0;
		}
	}
	
    /********** test only
     Standard kill() function to recover funds 
     **********/
    
    function kill() { 
        if (msg.sender == creator)
            suicide(creator);  // kills this contract and sends remaining funds back to creator
    }	
}