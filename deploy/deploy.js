// first run prepare.js to import the compiled source code and some other helper variables
// before you do that run prepare.py to compile the latest version of the software in Foundation
// and populate the helper variables

personal.unlockAccount(eth.accounts[3]);
var _maxDelegators = max_Delegate_number ;
var _debatingDays = debating_days ;
var _bitcointalkId = "" ;
var foundationContract = web3.eth.contract(foundation_abi);
var foundation = foundationContract.new(
   _maxDelegators,
   _debatingDays,
   _bitcointalkId,
   {
     from: web3.eth.accounts[0], 
     data: foundation_bin,
     gas: 3000000
   }, function(e, contract){
    console.log(e, contract);
    if (typeof contract.address != 'undefined') {
         console.log('Contract mined! address: ' + contract.address + ' transactionHash: ' + contract.transactionHash);
    }
 })
