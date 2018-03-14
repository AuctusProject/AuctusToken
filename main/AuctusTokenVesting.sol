pragma solidity ^0.4.21;


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


contract AuctusToken {
	function balanceOf(address who) public constant returns (uint256);
	function transfer(address to, uint256 value) public returns (bool);
}


contract ContractReceiver {
	function tokenFallback(address from, uint256 value, bytes data) public;
}


/**
 * Built based on https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/contracts/token/ERC20/TokenVesting.sol
 */
contract AuctusTokenVesting is ContractReceiver {
	using SafeMath for uint256;

	address public auctusTokenAddress = 0x0;

    address public owner;
	address public beneficiary;
	uint256 public cliff;
	uint256 public start;
	uint256 public duration;

	uint256 public releasedAmount;
	uint256 public tokenAmount;

	event Released(uint256 amount);

	modifier onlyOwner() {
		require(owner == msg.sender);
		_;
	}

	/**
	* @dev Creates a vesting contract that vests its balance of Auctus token to the
	* _beneficiary, gradually in a linear fashion until _start + _duration. By then all
	* of the balance will have vested.
	* @param _beneficiary address of the beneficiary to whom vested tokens are transferred
	* @param _cliff duration in seconds of the cliff in which tokens will begin to vest
	* @param _duration duration in seconds of the period in which the tokens will vest
	*/
	function AuctusTokenVesting(address _beneficiary, uint256 _start, uint256 _cliff, uint256 _duration) public {
		require(_beneficiary != address(0));
		require(_cliff <= _duration);

		owner = msg.sender;
		beneficiary = _beneficiary;
		duration = _duration;
		cliff = _start.add(_cliff);
		start = _start;
	}


	function transferOwnership(address newOwner) onlyOwner public {
		require(newOwner != address(0));
		owner = newOwner;
	}

	/**
	* @notice Transfers vested tokens to beneficiary.
	*/
	function release() public {
		uint256 unreleased = releasableAmount();

		require(unreleased > 0);

		releasedAmount = releasedAmount.add(unreleased);
		tokenAmount = tokenAmount.sub(unreleased);

		AuctusToken(auctusTokenAddress).transfer(beneficiary, unreleased);

		emit Released(unreleased);
	}

	/**
	* @dev Calculates the amount that has already vested but hasn't been released yet.
	*/
	function releasableAmount() public view returns (uint256) {
		return vestedAmount().sub(releasedAmount);
	}

	/**
	* @dev Calculates the amount that has already vested.
	*/
	function vestedAmount() public view returns (uint256) {
		uint256 totalBalance = tokenAmount.add(releasedAmount);
		if (now < cliff) {
			return 0;
		} else if (now >= start.add(duration)) {
			return totalBalance;
		} else {
			return totalBalance.mul(now.sub(start)).div(duration);
		}
	}

	function tokenFallback(address, uint256 value, bytes) public {
		require(msg.sender == auctusTokenAddress);
		tokenAmount = value;
	}
}