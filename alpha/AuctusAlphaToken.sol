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

contract ERC20 {
	uint256 public totalSupply;
	uint8 public decimals;
	
	function balanceOf(address who) public constant returns (uint256);
	function allowance(address owner, address spender) public constant returns (uint256);
	function transfer(address to, uint256 value) public returns (bool);
	function approve(address spender, uint256 value) public returns (bool);
	function transferFrom(address from, address to, uint256 value) public returns (bool);

	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract ERC223 {
  uint256 public totalSupply;
  uint8 public decimals;
  string public name;
  string public symbol;
  
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function transfer(address to, uint256 value, bytes data) public returns (bool);
  function transfer(address to, uint256 value, bytes data, string custom_fallback) public returns (bool);
  
  event Transfer(address indexed from, address indexed to, uint256 value, bytes indexed data);
}


contract ContractReceiver {
  function tokenFallback(address from, uint256 value, bytes data) public;
}


contract BasicToken is ERC20, ERC223 {
	using SafeMath for uint256;

	mapping(address => uint256) balances;
	mapping(address => mapping(address => uint256)) internal allowed;
	
	function balanceOf(address who) public constant returns (uint256) {
		return balances[who];
	}
  
	function allowance(address owner, address spender) public constant returns (uint256) {
		return allowed[owner][spender];
	}
  
	function approve(address spender, uint256 value) public returns (bool) {
		allowed[msg.sender][spender] = value;
		Approval(msg.sender, spender, value);
		return true;
	}
	
	function transferFrom(address from, address to, uint256 value) public returns (bool) {
		require(value <= allowed[from][msg.sender]);
		internalTransfer(from, to, value);
		allowed[from][msg.sender] = allowed[from][msg.sender].sub(value);
		Transfer(from, to, value);
		return true;
	}

	function increaseApproval(address spender, uint256 value) public returns (bool) {
		allowed[msg.sender][spender] = allowed[msg.sender][spender].add(value);
		Approval(msg.sender, spender, allowed[msg.sender][spender]);
		return true;
	}

	function decreaseApproval(address spender, uint256 value) public returns (bool) {
		uint256 currentValue = allowed[msg.sender][spender];
		if (value > currentValue) {
			allowed[msg.sender][spender] = 0;
		} else {
			allowed[msg.sender][spender] = currentValue.sub(value);
		}
		Approval(msg.sender, spender, allowed[msg.sender][spender]);
		return true;
	}
	
	function transfer(address to, uint256 value) public returns (bool) {
		internalTransfer(msg.sender, to, value);
		if (isContract(to)) {
			bytes memory empty;
			callTokenFallback(to, value, empty);
		}
		Transfer(msg.sender, to, value);
		return true;
	}
	
	function transfer(address to, uint256 value, bytes data) public returns (bool) {
		internalTransfer(msg.sender, to, value);
		if (isContract(to)) {
			callTokenFallback(to, value, data);
		}
		Transfer(msg.sender, to, value, data);
		return true;
	}

	function transfer(address to, uint256 value, bytes data, string custom_fallback) public returns (bool) {
		internalTransfer(msg.sender, to, value);
		if (isContract(to)) {
			assert(to.call.value(0)(bytes4(keccak256(custom_fallback)), msg.sender, value, data));
		} 
		Transfer(msg.sender, to, value, data);
		return true;
	}
	
	function isContract(address _address) private constant returns (bool) {
		uint256 length;
		assembly {
			length := extcodesize(_address)
		}
		return (length > 0);
    }
	
	function internalTransfer(address from, address to, uint256 value) private {
		require(value <= balances[from]);
		balances[from] = balances[from].sub(value);
		balances[to] = balances[to].add(value);
    }
	
	function callTokenFallback(address to, uint256 value, bytes data) private {
		ContractReceiver receiver = ContractReceiver(to);
		receiver.tokenFallback(msg.sender, value, data);
    }
}


contract AuctusAlphaToken is BasicToken {
	uint256 public totalSupply;
	uint8 public decimals = 18;
	string public name = "Auctus Testnet Token";
	string public symbol = "AUCT";
	
	address public owner;
	
	event Burn(address indexed from, uint256 value);
	event Mint(address indexed to, uint256 value);
	
	modifier onlyOwner() {
        require(msg.sender == owner);
		_;
    }
	
	function AuctusAlphaToken() public {
		owner = msg.sender;
		totalSupply = 0;
	}
	
	function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }
	
	function mint(address to, uint256 value) onlyOwner public  {
		balances[to] = balances[to].add(value);
		totalSupply = totalSupply.add(value);
		Mint(to, value);
	}
	
	function burn(uint256 value) public returns (bool) {
		internalBurn(msg.sender, value);
        Burn(msg.sender, value);
		return true;
    }

    function burnFrom(address from, uint256 value) public returns (bool) {
		require(value <= allowed[from][msg.sender]);
		internalBurn(from, value);
		allowed[from][msg.sender] = allowed[from][msg.sender].sub(value);
		Burn(from, value);
		return true;
    }
	
	function internalBurn(address from, uint256 value) private {
		require(value <= balances[from]);
		balances[from] = balances[from].sub(value);
		totalSupply = totalSupply.sub(value);
	}
}