//Draft Auctus Pre ICO SC version 0.2
pragma solidity ^0.4.11;

contract PreIcoToken {
    function balanceOf(address owner) constant returns (uint256);
}

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

contract AuctusICOPOC {
	using SafeMath for uint256;
	
	string public name = "Auctus Token"; 
    string public symbol = "AUC";
    uint8 public decimals = 18;
	
	uint256 public bonusPerAGT = 40; //40%

	address public preICOContract;
	
	mapping(address => uint256) public balances;
	
	mapping(address => bool) public preICOClaimed;
	
	uint256 public totalPreIcoTokenClaimed = 0;
	
	event Transfer(address indexed _from, address indexed _to, uint256 _value);
    	
	function AuctusICOPOC(address preICO) {
		preICOContract = preICO;
	}
	
	function balanceOf(address who) constant returns (uint256) {
		return balances[who];
	}
		
	function transfer(address to, uint256 value) returns (bool success) { //ERC20 Token Compliance
     	require(false);
		balances[to] = balances[to];
		value = value;
		return false;
    }
		
	function claimTokensFromPreICO()
	{
		require(!preICOClaimed[msg.sender]);		
		
		PreIcoToken token = PreIcoToken(preICOContract);
		uint256 amount = token.balanceOf(address(msg.sender));
		assert(amount > 0);                     
		uint256 bonus = (amount * bonusPerAGT ) / (100);
		uint256 amountToReceive = amount.plus(bonus);
		
		balances[msg.sender] = balances[msg.sender].plus(amountToReceive);
		totalPreIcoTokenClaimed = totalPreIcoTokenClaimed.plus(amountToReceive);
		preICOClaimed[msg.sender] = true;
	}	
}