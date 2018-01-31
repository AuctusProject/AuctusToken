pragma solidity ^0.4.19;


library SafeMath {
	function add(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a + b;
		assert(a <= c);
		return c;
	}
	
	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
		assert(a >= b);
		return a - b;
	}

	function mul(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a * b;
		assert(a == 0 || c / a == b);
		return c;
	}

	function div(uint256 a, uint256 b) internal pure returns (uint256) {
		return a / b;
	}
}


contract ContractReceiver {
  function tokenFallback(address from, uint256 value, bytes data) public;
}


contract AuctusAlphaToken {
  function transfer(address to, uint256 value) public returns (bool);
}


contract AuctusAlphaEscrow is ContractReceiver {
	using SafeMath for uint256;

	address public auctusAlphaToken = 0x0;
	address public owner;
	uint256 public minimumEscrow;
	mapping(address => uint256) internal escrowed;
	
	event Escrow(address indexed from, uint256 value);
	event Redeem(address indexed from, uint256 value);
	
	function AuctusAlphaEscrow() public {
		owner = msg.sender;
		minimumEscrow = 10 ether;
	}
	
	function locked(address from) public constant returns (uint256) {
		return escrowed[from];
	}
	
	function isValidEscrow(address who) public constant returns (bool) {
		return (locked(who) >= minimumEscrow);
	}
	
	function transferOwnership(address newOwner) public {
		require(msg.sender == owner);
        owner = newOwner;
    }
	
	function changeMinimumEscrow(uint256 value) public {
		require(msg.sender == owner);
        minimumEscrow = value;
    }
	
	function tokenFallback(address from, uint256 value, bytes) public {
		require(msg.sender == auctusAlphaToken);
		escrowed[from] = escrowed[from].add(value);
		Escrow(from, value);
	}
	
	function redeem(uint256 value) public {
		require(value > 0);
		require(escrowed[msg.sender] >= value);
		escrowed[msg.sender] = escrowed[msg.sender].sub(value);
		assert(AuctusAlphaToken(auctusAlphaToken).transfer(msg.sender, value));
		Redeem(msg.sender, value);
	}
	
	function redeemAll() public {
		redeem(escrowed[msg.sender]);
	}
}