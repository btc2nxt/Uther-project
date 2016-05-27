var _bitcointalkId = "" ;
var foundationContract = web3.eth.contract($foundation_abi);
console.log("Creating Foundation Contract");

var foundation = foundationContract.new(
   $max_delegate_number,
   $debating_days,
   _bitcointalkId,
    {
	    from: web3.eth.accounts[0],
	    data: '$foundation_bin',
	    gas: 3000000
    }, function (e, contract) {
	    if (e) {
            console.log(e + " at foundation Contract creation!");
	    } else if (typeof contract.address != 'undefined') {
            addToTest('foundation_address', contract.address);
        }
    }
);
checkWork();
console.log("mining contract, please wait");
miner.start(1);
setTimeout(function() {
    miner.stop();
    testResults();
}, 3000);


