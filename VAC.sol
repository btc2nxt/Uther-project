// Virtual Autonomous Company (VAC) 0.0.2
contract VAC {
    uint8 maxReferees; //maximize referees, default 9
	uint maxContractors; //maximize contractor; default 255
	uint8 professorNumber; //need how many professors to review a contract ,2 
    uint8 maxRequestRefereeNumber; //miximize referees, default 9
    uint8 minRequestRefereeNumber; //default 3
    uint8 contractorDepositPercent; // 100= 100% gurantee for running a contract
    uint8 refereeDepositPercent;
    uint initDeposit; //init deposit to add referee and contractor
    uint8 waitWeeks; //after setting weeks, deposit percent will act, so every member should re-deposit to get the limit
	uint8 totalReferees;
	address creator;
	
	bytes8 emptyDrawData;

	// who gets the information from the real world, and inject to blockchain.
	// or audit contractor's contract.
	struct Referee {
		address addr; 
		uint deposit; //ensure data is right, otherwise will deduct from deposit
		uint commission; //get reward
		uint times; //how many times the referee has injected info to blockchain 
		uint failedTimes; //got wrong data
		uint reputation; //the higher, more register will ask it to help
        bool onLeave;   //has a leave, so no work to it. 
		uint registerTime; //when to register the vocation
		uint withdrawal; //has withdraw from commission
		bool isProfessor; //true: can audit contracts; if dont want to do other things,set onLeave=flase
    }

	//who creats a contract, and register to VAC, so get ensured data ,and pay some % to the refrees;
	struct Contractor {
		address owner;
		uint deposit;
		address contractAddress;
		bytes8 drawData; //byte0=FF, means no data
		bool safed; // data is voted safe,after the deadline
		uint beginTime;
		uint endTime;
		uint deadline; //referees must inject data before it
		uint8 requestRefereeNumber; //3-Max, minimize is 3 referees;
		uint firstCreateTime; //first generate this contract
		uint updateTime; //when update this contract;
		Contractor_State state; //contractor's state: running;waiting-update;updated;
		bytes reviewProfessorIds; //{01 04} {02 08} means id=01 ,con but id=2 pro.
		bytes8[8] refereeDrawDatas; //every referee write its drawData here order by refereeIds. bytes8 array cannot be written
		uint[8] refereeIds; //bytes->swap error; byte[8]->store wrong position		
	}
	
	/*
	created: 
	Reviewing: professors are review source code of the contract
	Binding(2): bind referees to the contract;
	Sleeping: wait start the contract;
	Active(4): user can interact with the contract;
	Pending: user cannot operate the contract, wait referee to inject data to it;
	Success(6): data is Ok
	Failed: data is wrong
	Finished(8): contractor finished its work;
	*/
	enum Contractor_State { Created, Reviewing, Binding, Sleeping, Active, Pending, Success, Failed, Finished }

    Contractor[] public contractors;
	Referee[] public referees;

    function VAC(
		uint8 _maxReferees, 
		uint8 _maxRequestRefereeNumber, 
		uint8 _minRequestRefereeNumber, 
		uint8 _contractorDepositPercent, 
		uint8 _refereeDepositPercent, 
		uint _initDeposit, 
		uint8 _waitWeeks)
    {
		maxReferees = _maxReferees;
		maxContractors = 255;
		professorNumber = 2;
		maxRequestRefereeNumber = _maxRequestRefereeNumber;
		minRequestRefereeNumber = _minRequestRefereeNumber;
		contractorDepositPercent = _contractorDepositPercent;
		refereeDepositPercent = _refereeDepositPercent;
		initDeposit = _initDeposit;
		waitWeeks = _waitWeeks;
		creator =msg.sender;
		emptyDrawData = 0xff00ff00ff00ff00;
    }
	
	//anyone can become a referee, only if send a deposit.
	//in case someone register all referees, so in the future, only creator can add referee or every referee and invite one
	function addReferee(address _addr, uint _deposit, bool _isProfessor) returns (uint8 ) {
		bool found = false;
		if ( totalReferees <= maxReferees && totalReferees >0) {
			for (uint i = 0; i < totalReferees; ++i) {
				if (referees[i].addr == _addr) {
					found =true; 
					break;
				}
            }			
		}
		
		if ( !found && _deposit >= initDeposit) {
			referees.push(Referee(_addr, _deposit, 0,0,0,0, false,now,0, _isProfessor));
			totalReferees++;			
		}
		
		return totalReferees;		
	}

	modifier onlyReferee() {
        bool founded =false;
		for (uint8 i = 0; i < referees.length; ++i) {
			if (msg.sender == referees[i].addr) {
				founded = true;
				break;
			}
        }               
		
		if (!founded) throw;
		_							
    }
    
	modifier onlyProfessor() {
        bool founded =false;
		for (uint8 i = 0; i < referees.length; ++i) {
			if (msg.sender == referees[i].addr && referees[i].isProfessor ) {
				founded = true;
				break;
			}
        }               
		
		if (!founded) throw;
		_							
    }
    
    function getRefereeId(address _addr) internal returns (uint8) {
        uint8 refereeId = maxReferees+1;
        for (uint8 i = 0; i < referees.length; ++i) {
			if (_addr == referees[i].addr) {
			    refereeId = i;
			    return refereeId+1; //referee id starts from 1;
			}
        } 
    }

	
	// any user can create one
    function newContractor(uint _deposit, address _addr, uint8 _requestRefereeNumber) returns (uint) {
		//over the ceiling, or not enough deposit
		if (contractors.length == maxContractors  || _deposit < initDeposit)
            throw;
		bytes8[] memory b1;
		contractors.length++;
        Contractor c = contractors[contractors.length - 1];
		c.owner = msg.sender;
		c.deposit = _deposit;
		c.contractAddress = _addr;
		c.requestRefereeNumber = _requestRefereeNumber;
		c.state = Contractor_State.Created;
		c.reviewProfessorIds.length = 2*2;
		//c.refereeIds = 0x00;
		//c.refereeDrawDatas.length = 0;
		return contractors.length;
    }

    /* 0x01= start review, 0x04= con , 0x08 =pro */        
	function reviewContract(uint _contractorId, byte _position) 
		onlyProfessor returns (uint voteID)
	{
        Contractor c = contractors[_contractorId];
        uint8 professorId;
		if ( (_position ==1 || _position ==4 || _position ==8) && (c.state == Contractor_State.Created || c.state == Contractor_State.Reviewing ) ) {
            professorId = getRefereeId(msg.sender);
            if (professorId > maxReferees ) return;

			// first review
			if ( c.state != Contractor_State.Created ) {
				c.state = Contractor_State.Reviewing;
				c.reviewProfessorIds[0] = byte(professorId);
				c.reviewProfessorIds[1] = byte(_position);
				return;
			}

            uint8 nIndex = professorNumber;
			for (uint8 i = 0; i < professorNumber; ++i) {
				//position =0, no review
				if (c.reviewProfessorIds[i*2+1] == 0 ) {
					nIndex = i;
					break;
				}
				//find its refereeId,may updated it
				if (c.reviewProfessorIds[i*2] == byte(professorId) ) {
					nIndex = i;
					break;
				}
			}
			
			//professor is full
			if (nIndex == professorNumber)
				throw;
			
			c.reviewProfessorIds[nIndex*2] = byte(professorId);
			c.reviewProfessorIds[nIndex*2 +1] = _position;

			//if review pass, change state to binding;
			//if not ,failed; owner must re-update the contract address;
			uint8 nPass =0;
			uint8 nVeto =0;
			if (c.reviewProfessorIds[professorNumber*2 -1] > 0)
			for ( i = 0; i < professorNumber; ++i) {
				//position =0, no review
				if (c.reviewProfessorIds[i*2+1] == 8 )
					nPass++;
				else if (c.reviewProfessorIds[i*2+1] == 4 )
					nVeto++;
			}
			
			if (nPass == professorNumber)
				c.state = Contractor_State.Binding;
			else if ( nVeto == professorNumber)
				c.state = Contractor_State.Failed;
		}
	}

	function BindReferee(uint _contractorId) 
		onlyReferee returns (uint voteID)
	{
        Contractor c = contractors[_contractorId];
        uint8 refereeId;
		if (c.state ==  Contractor_State.Binding)
		{
            refereeId = getRefereeId(msg.sender);
			//now this referee
            if (refereeId > maxReferees ) return; //throw; when in blockchain

			// first binding
			if (c.state == Contractor_State.Binding && c.refereeIds[0] == 0) {
				//c.refereeIds.length = c.requestRefereeNumber ;
				/* dynamic bytes8[] get error with setting value
				*/
				//c.refereeDrawDatas.length = c.requestRefereeNumber ;
				c.refereeIds[0] = uint8(refereeId);
				c.refereeDrawDatas[0] = emptyDrawData;
				return;
			}

			uint8 nIndex = c.requestRefereeNumber;
			for (uint8 i = 0; i < c.requestRefereeNumber; ++i) {
				//position =0, no review
				if (c.refereeIds[i] == 0) {
					nIndex = i;
					break;
				}
				//find its refereeId
				if (c.refereeIds[i] == uint8(refereeId))
					return; //throw;//binded, cannot bind again with same referee
			}
			//find a available postion, link its referee id in;
			if (nIndex != c.requestRefereeNumber) {
				c.refereeIds[nIndex] = uint8(refereeId);
				c.refereeDrawDatas[nIndex] = emptyDrawData;
			}
			//all referees binded, state change to sleeping;
			if (c.refereeIds[c.requestRefereeNumber-1] > 0)
				c.state = Contractor_State.Sleeping;
		}
	}


	function StartContract(uint _contractorId, uint _beginTime, uint _endTime, uint _deadline) {
        Contractor c = contractors[_contractorId];
		//only owner can start contract with begin,endtime;
		if (c.owner != msg.sender)
			throw;
		if (c.state == Contractor_State.Sleeping) {
			c.beginTime = _beginTime;
			c.endTime = _endTime;
			c.deadline = _deadline;
			c.drawData = 0xff;
			c.state = Contractor_State.Active;
		}
	}
	
	/*
	first injection, drawData = _drawData
	if other refreee's data isn't same with the predessor, will change the drawData
	but more are same, will change the drawData;
	e.g. in 2016 USA president votes
	Hillary vs Trump
	228:220(drawData), 7 bytes
	bindings: {01 L 00} (05 W 00} { 89 W 00}
	the third refree will change the drawData
	*/
	function InjectRawData(uint _contractorId, bytes8 _drawData) 
		onlyReferee returns (uint voteID)
	{
        Contractor c = contractors[_contractorId];
        uint8 refereeId;
		if ( c.state ==  Contractor_State.Active && now > c.endTime && now < c.deadline ) {
            refereeId = getRefereeId(msg.sender);
			//now this referee
            if (refereeId > maxReferees ) return; //throw; when in blockchain

			uint8 nIndex = c.requestRefereeNumber;
			//find the referee's  position
			for (uint8 i = 0; i < c.requestRefereeNumber; ++i) {
				//find its refereeId
				if (c.refereeIds[i] == (refereeId) ) {
					nIndex = i;
					break;
				}
			}

			if (nIndex == c.requestRefereeNumber)
				throw; //invalid referee, which not binded to this contract
			
			c.refereeDrawDatas[nIndex] = _drawData;
			//first referee set the drawData
			if (c.drawData[0] == 0xff)
				c.drawData = _drawData;
			else {
				uint8 nDraw = 0;
				uint8 nDraw1 = 0;
				uint8 totalDraw = 0;
				for ( i = 0; i < c.requestRefereeNumber; ++i) {
					if (c.refereeDrawDatas[i] != emptyDrawData)
					totalDraw++;
					//find its refereeId
					if (c.refereeDrawDatas[i] == c.drawData)
						nDraw++;
					else if (c.refereeDrawDatas[i] == _drawData && c.drawData != _drawData) //different drawdata)
						nDraw1++;
				}
				if (nDraw1 > nDraw) 
					c.drawData = _drawData;
				
				//over half referees's drawdata are same;
				if (totalDraw == c.requestRefereeNumber && nDraw >= (totalDraw+1)/2) {
					c.state = Contractor_State.Pending;	
					c.safed =true;
				}
			}
		}
	}

	/*
	owner run this function, so have enough time to handle exception, like data faild.
	over 1/2 referees have same data, the result is safe.
	*/
	function SealDrawData(uint _contractorId) returns(bool)
	{
        Contractor c = contractors[_contractorId];
        uint nDraw =0 ;
		if ( c.state ==  Contractor_State.Pending) {
			for (uint8 i = 0; i < c.requestRefereeNumber; ++i) {
				if (c.refereeDrawDatas[i] == c.drawData )
					nDraw++;
			}

			if ( nDraw >= (c.requestRefereeNumber+1)/2 ) {
				c.safed = true;
				c.state = Contractor_State.Success;
			} 
			else {
				c.safed = false;
				c.state = Contractor_State.Failed;
			}				
		}
		return(c.safed);
	}

	//Transactionally return drawData, overriding VACRetriever
	function getVACDrawDataTransactional(uint _contractorId) public returns (bytes8) {	
        Contractor c = contractors[_contractorId];
		return c.drawData;
	}	
	
	//execute by the contract
	function FinishContract(uint _contractorId) {
        Contractor c = contractors[_contractorId];
		if ( c.state ==  Contractor_State.Success  || c.state ==  Contractor_State.Failed && c.contractAddress== msg.sender)
			c.state = Contractor_State.Finished;
	}

    /********** test use only
     Standard kill() function to recover funds 
     **********/
    function kill() { 
        if (msg.sender == creator)
            suicide(creator);  // kills this contract and sends remaining funds back to creator
    }	
}