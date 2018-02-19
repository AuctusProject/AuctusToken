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


contract AuctusAlphaPurchaseEscrow is ContractReceiver {
	using SafeMath for uint256;

	address public auctusAlphaToken = 0x0;
	address public owner;
	mapping(address => uint256) internal escrowed;
	
	event Escrow(address indexed from, uint256 value);
	event EscrowResult(address indexed from, address indexed to, uint256 value);
	
	function AuctusAlphaPurchaseEscrow() public {
		owner = msg.sender;
	}
	
	function locked(address from) public constant returns (uint256) {
		return escrowed[from];
	}
	
	function transferOwnership(address newOwner) public {
		require(msg.sender == owner);
        owner = newOwner;
    }
	
	function tokenFallback(address from, uint256 value, bytes) public {
		require(msg.sender == auctusAlphaToken);
		escrowed[from] = escrowed[from].add(value);
		Escrow(from, value);
	}
	
	function escrowResult(address from, address to, uint256 value) public {
		require(msg.sender == owner);
		require(escrowed[from] >= value);
		escrowed[from] = escrowed[from].sub(value);
		assert(AuctusAlphaToken(auctusAlphaToken).transfer(to, value));
		EscrowResult(from, to, value);
	}
}