//Draft Auctus Pre ICO SC version 0.2
pragma solidity ^0.4.13;


library SafeMath {
	function times(uint256 x, uint256 y) internal returns (uint256) {
		uint256 z = x * y;
		assert(x == 0 || (z / x == y));
		return z;
	}
	
	function plus(uint256 x, uint256 y) internal returns (uint256) {
		uint256 z = x + y;
		assert(z >= x && z >= y);
		return z;
	}
}


contract AuctusPreICO {
	using SafeMath for uint256;
	
	string public name = "Auctus Pre Ico"; 
    string public symbol = "AGT";
    uint8 public decimals = 18;
	
	uint256 public tokensPerEther = 2500;
	uint64 public preIcoStartBlock = 10; //TODO:Define Start ~ 2017-08-15 09:00:00 UTC
	uint64 public preIcoEndBlock = 100; //TODO:Define End ~ 2017-08-29 09:00:00 UTC
	uint256 public maxPreIcoCap = 30 ether;
	uint256 public minPreIcoCap = 10 ether;
	address public owner;
	
	mapping(address => uint256) public balances;
	mapping(address => uint256) public invested; 
	
	uint256 private preIcoWeiRaised = 0;
	uint256 private distributedAmount = 0;
	
	bool private preIcoHalted = false;
	
	event PreBuy(address indexed recipient, uint256 amount);
	event Transfer(address indexed _from, address indexed _to, uint256 _value);
    
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
		require(preIcoWeiRaised < minPreIcoCap && block.number > preIcoEndBlock);
		_;
	}
	
	modifier preIcoNotHalted() {
		require(!preIcoHalted);
		_;
	}
	
	function AuctusPreICO() {
		owner = msg.sender;
	}

	function weiRaised() constant returns (uint256) {
		return preIcoWeiRaised;
	}
	
	function tokenDistributed() constant returns (uint256) {
		return distributedAmount;
	}
	
	function preIcoIsHalted() constant returns (bool) {
		return preIcoHalted;
	}
	
	function balanceOf(address who) constant returns (uint256) {
		return balances[who];
	}
	
	function()
		payable 
		preIcoPeriod 
		preIcoNotHalted
	{		
		require(msg.value > 0); 
		
		uint256 tokenAmount = msg.value.times(tokensPerEther);
		balances[msg.sender] = balances[msg.sender].plus(tokenAmount);
		invested[msg.sender] = invested[msg.sender].plus(msg.value);
		distributedAmount = distributedAmount.plus(tokenAmount);
		preIcoWeiRaised = preIcoWeiRaised.plus(msg.value);
		
		PreBuy(msg.sender, tokenAmount);
	}
	
	function transfer(address to, uint256 value) returns (bool success) { //ERC20 Token Compliance - pre ico token is not transferable
     	require(false);
		balances[to] = balances[to];
		value = value;
		return false;
    }
		
	function revoke() preIcoFailed {
		uint256 amount = invested[msg.sender];
		require(amount > 0);
		invested[msg.sender] = 0;
		balances[msg.sender] = 0;
		require(msg.sender.send(amount));
	}
	
	function drain() 
		onlyOwner 
		preIcoCompletedSuccessfully
	{
		require(msg.sender.send(this.balance));
	}
	
	function setPreIcoHalt(bool halted) onlyOwner {
		preIcoHalted = halted;
	}
}