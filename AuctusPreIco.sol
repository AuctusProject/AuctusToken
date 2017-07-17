//Draft Auctus Pre ICO SC version 0.1
pragma solidity ^0.4.11;


library SafeMath {
	function times( uint256 x, uint256 y) internal returns (uint256) {
		uint256 z = x * y;
		assert(x == 0 || (z / x == y));
		return z;
	}

	function divided( uint256 x, uint256 y) internal returns (uint256) {
		assert(y != 0);
		return x / y;
	}

	function minus( uint256 x, uint256 y) internal returns (uint256) {
		assert(y <= x);
		return x - y;
	}

	function plus( uint256 x, uint256 y) internal returns (uint256) {
		uint256 z = x + y;
		assert(z >= x && z >= y);
		return z;
	}
}


contract AuctusPreICO {
	using SafeMath for uint256;
	
	function name() constant returns (string) { return "Auctus Pre Ico"; }
    function symbol() constant returns (string) { return "AGT"; }
    function decimals() constant returns (uint8) { return 18; }
	
	uint256 public tokensPerEther = 100000;
	uint256 public minWeiToInvest = 0.05 ether; 
	uint64 public preIcoStartBlock = 0; //TODO:Define Start ~ 2017-08-15 09:00:00 UTC
	uint64 public preIcoEndBlock = 20000000; //TODO:Define End ~ 2017-08-29 09:00:00 UTC
	uint256 public maxPreIcoCap = 1500 ether;
	uint256 public minPreIcoCap = 600 ether;
	address public owner;
	
	mapping(address => uint256) public balances;
	mapping(address => bool) public migrated;
	mapping(address => uint256) private invested;
	
	uint256 private preIcoWeiRaised = 0;
	uint256 private distributedAmount = 0;
	bool private preIcoHalted = false;
	bool private bountyFinished = false;
	address private migrationToken = 0x0;
	
	event Bounty(address indexed recipient, uint256 amount);
	event PreBuy(address indexed recipient, uint256 amount);
	event TokenMigration(address indexed recipient, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    
	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
	}
	
	modifier preIcoPeriod() {
		require(block.number >= preIcoStartBlock && block.number <= preIcoEndBlock && preIcoWeiRaised < maxPreIcoCap);
		_;
	}
	
	modifier preIcoCompletedSuccessfully() {
		require(preIcoWeiRaised >= minPreIcoCap && (preIcoWeiRaised >= maxPreIcoCap || block.number > preIcoEndBlock));
		_;
	}
	
	modifier preIcoFailed() {
		require(failed());
		_;
	}
	
	modifier preIcoNotFailed() {
		require(!failed());
		_;
	}

	modifier preIcoNotHalted() {
		require(!preIcoHalted);
		_;
	}
	
	modifier bountyIsOpened() {
		require(!bountyFinished);
		_;
	}
	
	modifier migrationIsDefined() {
		require(migrationToken != 0x0);
		_;
	}
	
	modifier validPayload() { //"Fix for the ERC20 short address attack"
		require(msg.data.length >= 68);
		_;
	}
	
	function AuctusPreICO() {
		owner = msg.sender;
	}
	
	function tokensPerEther() constant returns (uint256) {
		return tokensPerEther;
	}
	
	function maximumPreIcoCap() constant returns (uint256) {
		return maxPreIcoCap / 1 ether;
	}
	
	function minimumPreIcoCap() constant returns (uint256) {
		return minPreIcoCap / 1 ether;
	}
	
	function startBlock() constant returns (uint256) {
		return preIcoStartBlock;
	}
	
	function endBlock() constant returns (uint256) {
		return preIcoEndBlock;
	}
	
	function weiRaised() constant returns (uint256) {
		return preIcoWeiRaised;
	}
	
	function tokenDistributed() constant returns (uint256) {
		return distributedAmount;
	}
	
	function minimumWeiToInvest() constant returns (uint256) {
		return minWeiToInvest;
	}
	
	function preIcoIsHalted() constant returns (bool) {
		return preIcoHalted;
	}
	
	function ownerBountyIsFinished() constant returns (bool) {
		return bountyFinished;
	}
	
	function balanceOf(address who) constant returns (uint256) {
		return balances[who];
	}
	
	function wasMigrated(address who) constant returns (bool) {
		return migrated[who];
	}
	
	function()
		payable 
		preIcoPeriod 
		preIcoNotHalted
	{		
		require(msg.value >= minWeiToInvest);
		uint256 tokenAmount = SafeMath.times(msg.value, tokensPerEther);
		balances[msg.sender] = SafeMath.plus(balances[msg.sender], tokenAmount);
		invested[msg.sender] = SafeMath.plus(invested[msg.sender], msg.value);
		distributedAmount = SafeMath.plus(distributedAmount,tokenAmount);
		preIcoWeiRaised = SafeMath.plus(preIcoWeiRaised, msg.value);
		
		PreBuy(msg.sender, tokenAmount);
	}
	
	function transfer(address to, uint256 value) returns (bool success) { //ERC20 Token Conpliance - pre ico token is not transferable
     	require(false);
		balances[to] = balances[to];
		value = value;
		return false;
    }
		
	function revoke()
		validPayload	
		preIcoFailed 
	{
		uint256 amount = invested[msg.sender];
		require(amount > 0);
		invested[msg.sender] = 0;
		balances[msg.sender] = 0;
		require(msg.sender.send(amount));
	}
	//REMOVE
	function migrate() 
		validPayload
		migrationIsDefined
		preIcoCompletedSuccessfully
	{
		require(!migrated[msg.sender]);
		migrated[msg.sender] = true;
		require(migrationToken.delegatecall(bytes4(sha3("processPreIcoMigration()"))));
		TokenMigration(msg.sender, balanceOf(msg.sender));
	}
	
	function bounty(address recipient, uint256 amount) 
		onlyOwner 
		bountyIsOpened
		preIcoNotFailed
	{
		balances[recipient] = balances[recipient].plus(amount);
		distributedAmount = distributedAmount.plus(amount);
		Bounty(recipient, amount);
	}
	
	function transferOwnership(address newOwner) onlyOwner {
		owner = newOwner;
	}
	
	function setPreIcoHalt(bool halted) onlyOwner {
		preIcoHalted = halted;
	}
	//REMOVE
	function setMigrationToken(address mainToken) onlyOwner {
		migrationToken = mainToken;
		bountyFinished = true;
	}
	
	function failed() internal returns (bool) {
		return (preIcoWeiRaised < minPreIcoCap && block.number > preIcoEndBlock);
	}
}