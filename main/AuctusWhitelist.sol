pragma solidity ^0.4.21;


contract AuctusWhitelist {
	address public owner;
	uint256 public timeThatFinishGuaranteedPeriod = 1522245600; //2018-03-28 2 PM UTC
	uint256 public maximumValueAfterGuaranteedPeriod = 15000 ether; //too high value
	uint256 public maximumValueDuringGuaranteedPeriod;

	mapping(address => WhitelistInfo) public whitelist;

	struct WhitelistInfo {
		address _address;
		bool _doubleValue;
		bool _shouldWaitGuaranteedPeriod;
	}

	function AuctusWhitelist(uint256 maximumValue) public {
		owner = msg.sender;
		maximumValueDuringGuaranteedPeriod = maximumValue;
	}

	modifier onlyOwner() {
		require(owner == msg.sender);
		_;
	}

	function transferOwnership(address newOwner) onlyOwner public {
		require(newOwner != address(0));
		owner = newOwner;
	}

	function changeMaximumValueDuringGuaranteedPeriod(uint256 maximumValue) onlyOwner public {
		require(maximumValue > 0);
		maximumValueDuringGuaranteedPeriod = maximumValue;
	}

	function listAddresses(bool doubleValue, bool shouldWait, address[] _addresses) onlyOwner public {
		for (uint256 i = 0; i < _addresses.length; i++) {
			whitelist[_addresses[i]] = WhitelistInfo(_addresses[i], doubleValue, shouldWait);
		}
	}

	function getAllowedAmountToContribute(address addr) view public returns(uint256) {
		if (whitelist[addr]._address != addr) {
			return 0;
		} else if (now <= timeThatFinishGuaranteedPeriod) {
			if (whitelist[addr]._shouldWaitGuaranteedPeriod) {
				return 0;
			} else {
				if (whitelist[addr]._doubleValue) {
					return (maximumValueDuringGuaranteedPeriod * 2);
				} else {
					return maximumValueDuringGuaranteedPeriod;
				}
			}
		} else {
			return maximumValueAfterGuaranteedPeriod;
		}
	}
}