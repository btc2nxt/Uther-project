contract Foundation {

	uint8 public maxDelegators;
	uint8 public totalDelegators;
    address public founder;
	uint public debatingDays;
    uint public numBudgets;
    Budget[] public budgets;
	Delegator[] public delegators;

   struct Delegator {
    address addr;
    uint amount;
    bytes32 bitcointalkId;
  }

	struct Budget {
        address recipient;
        uint amount;
        bytes32 data;
        string description;
        uint creationDate;
		uint confirmDate;
		uint executeDays;
        uint8 createdBy;		//delegator id;
		State  state;
        bytes votes; // byte0: vote of delegator 0
        //mapping (address => uint8) voted;
    }
	
    /* 
	Created : member create a budget
	Active: a member pro or con the bugdet within debatingDays( default =10 days)
	Vetoed: over half of members against the budget, so budget was vetoed
	Passed: over half pro the budget, passed th budget
	Pending: after the recipient of the budget confirm the budget
	Success: after the recipient has finished the job, over half of members agree a payment
	Failed: recipient didnt finished the work in setting time 
*/
	enum State { Created, Active, Vetoed, Passed, Pending, Success, Failed }

    event BudgetAdded(uint budgetID, address recipient, uint amount, bytes32 data, string description);
    event BudgetVoted(uint budgetID, address voter, byte position);
    event BudgetTallied(uint budgetID, uint8 reult, State state);
    event BudgetConfirmed(uint budgetID, address recipient, State state);
    event BudgetTicked(uint budgetID, address delegator, byte position);
    event BudgetPaid(uint budgetID, uint8 tickDelegatorNum, uint amount);

    struct Vote {
        uint8 position;
        address voter;
    }

    function Foundation(uint8 _maxDelegators, uint _debatingDays, bytes32 _bitcointalkId) {
        founder = msg.sender;  
        maxDelegators = _maxDelegators;// || 5;
        debatingDays = _debatingDays * 1 days;// || 10 days;
		numBudgets = 0;
		totalDelegators =0;
		addDelegator(msg.sender, _bitcointalkId);
    }

	/* in the beginning, Creator adds the delegator 
		in the future, user will select delegators
	*/
	function addDelegator(address _addr, bytes32 _bitcointalkId) returns (uint8 )
	{
		if ( msg.sender == founder && totalDelegators <= maxDelegators && totalDelegators >0) {
			bool found = false;
			for (uint i = 0; i < totalDelegators; ++i) {
				if (delegators[i].addr == _addr) {
					found =true; 
					break;
				}
            }			
			if (!found) {
				delegators.push(Delegator(_addr,_addr.balance,_bitcointalkId));
				totalDelegators++;
			}
		}
		
		if ( _addr == founder && totalDelegators ==0) {
				delegators.push(Delegator(_addr,_addr.balance,_bitcointalkId));
				totalDelegators++;			
		}
		
		return totalDelegators;		
	}

	function getDelegator(uint8 _delegatorId) returns (address)
	{
		address addr =msg.sender;
		if ( _delegatorId < totalDelegators) {
			addr = delegators[_delegatorId].addr;
		}
		return addr;
	}

    modifier onlyDelegator()
    {
        bool founded =false;
		for (uint8 i = 0; i < delegators.length; ++i) {
			if (msg.sender == delegators[i].addr) {
				founded = true;
				break;
			}
        }               
		
		if (!founded) throw;
		_							
    }

    function getDelegatorId(address _addr) internal returns (uint8)
    {
        uint8 delegatorId = maxDelegators;
        for (uint8 i = 0; i < delegators.length; ++i) {
			if (_addr == delegators[i].addr) {
			    delegatorId = i;
			    return delegatorId;
			}
        } 
    }

	function newBudget(address _recipient, uint _amount, bytes32 _data, string _description, uint _executeDays) 
		onlyDelegator returns (uint ) 
    {   
            uint budgetID = budgets.length;
            //bytes memory v ;
            //v[0] =0x0;
			budgets.push(Budget({recipient: _recipient, amount: _amount, data: _data, description: _description, creationDate: now, state: State.Created, executeDays: _executeDays * 1 days,confirmDate: 0, createdBy: 0, votes: '' }));
			//budgets.push(Budget({recipient: _recipient, amount: _amount, data: _data, description: _description, creationDate: now, state: State.Created, executeDays: _executeDays,confirmDate: 0, createdBy: 0, votes: v }));			
            numBudgets = budgetID+1;
            BudgetAdded(budgetID, _recipient, _amount, _data, _description);		
            return budgetID;
    }

    /* 0x01= con , 0x02 =pro */        
	function voteBudget(uint _budgetID, byte _position) 
		onlyDelegator returns (uint voteID)
	{
        Budget b = budgets[_budgetID];
        uint8 delegatorId;
		if ( (_position ==1 || _position ==2) && (b.state == State.Active || b.state == State.Created ) ) {
            delegatorId = getDelegatorId(msg.sender);
            if (delegatorId >= maxDelegators ) return;

			/* have first vote, budget active*/
			if ( b.state != State.Active ) {
				b.state = State.Active;
				b.votes.length = 32;
				b.votes[delegatorId] = b.votes[delegatorId] & 0x0;
			}
            b.votes[delegatorId] = _position;
            BudgetVoted(_budgetID, msg.sender,  _position);
		}
	}
	

    function passBudget(uint _budgetID) returns (uint8 proDelegatorNum, State state) 
	{
        Budget b = budgets[_budgetID];
        /* Check if debating period is over */
        if (now > (b.creationDate + debatingDays) && b.state == State.Active ){   
	        proDelegatorNum = 0;
			/* tally the votes */
            for (uint i = 0; i <  b.votes.length; ++i) {
                if (b.votes[i] == 2) ++proDelegatorNum; 
            }
            /* execute result */
            if (proDelegatorNum >= (totalDelegators+1)/2 ) {
                b.state = State.Passed;
            } else  {
                b.state = State.Vetoed;
            }
            BudgetTallied(_budgetID, proDelegatorNum, b.state);
        }
    }

    function confirmBudget(uint _budgetID) returns (State result) 
	{
        Budget b = budgets[_budgetID];
        if ( msg.sender == b.recipient && b.state == State.Passed ){   
            b.state = State.Pending;
			b.confirmDate = now;
            BudgetConfirmed(_budgetID, b.recipient, b.state);
            result = b.state;
        }
		//result = b.state
    }

    /* 1= pro, 2 = con, 
	5= tick, delegators who voted the budget can tick it  ,then payment will happen
	*/        
	function tickBudget(uint _budgetID, byte _position) 
		onlyDelegator returns (byte)
	{
        Budget b = budgets[_budgetID];
        uint8 delegatorId;        
		if ( b.state ==  State.Pending && _position == 5 ) {
            delegatorId = getDelegatorId(msg.sender);            
            if (delegatorId >= maxDelegators ) return byte(delegatorId);
            if (b.votes[delegatorId] >=5) return b.votes[delegatorId] ;            
            b.votes[delegatorId] = b.votes[delegatorId] | _position;
			/* have a vote, budget active*/
            BudgetTicked(_budgetID, msg.sender, _position);
		}
	}

    function budgetPayment(uint _budgetID) returns (uint8 winDelegatorNum, State result)
	{
        Budget b = budgets[_budgetID];
		uint8 tickDelegatorNum = 0;
		uint8 vetoDelegatorNum = 0;				
		winDelegatorNum =0;

        /* Check if executeDays is not overtime */
		if ( b.state == State.Pending) {
			if ( now <= b.confirmDate + b.executeDays ){   
				/* how many delegator agreed the payment */
		        for (uint i = 0; i <  b.votes.length; ++i) {
				    if ( b.votes[i] >= 5) 
						++tickDelegatorNum; 
					else if ( b.votes[i] >= 1) 
					 	++vetoDelegatorNum; 
	            }
		        /* total of agreed is bigger than 1/2 delegators, will pay to recipient */
				if (tickDelegatorNum >= (totalDelegators+1)/2 ) {
				    b.state = State.Success;
					winDelegatorNum = tickDelegatorNum;
					b.recipient.send(b.amount);
		        	BudgetPaid(_budgetID, tickDelegatorNum, b.amount);					
	            }
				if (vetoDelegatorNum >= (totalDelegators+1)/2 ) {
				    b.state = State.Failed;
					winDelegatorNum = vetoDelegatorNum;
	            }
				
			} else
				b.state = State.Failed;			
		}
		result = b.state;
    }
}