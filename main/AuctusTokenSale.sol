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


contract ContractReceiver {
	function tokenFallback(address from, uint256 value, bytes data) public;
}


contract AuctusToken {
	function transfer(address to, uint256 value) public returns (bool);
	function transfer(address to, uint256 value, bytes data) public returns (bool);
	function burn(uint256 value) public returns (bool);
	function setTokenSaleFinished() public;
}


contract AuctusWhitelist {
	function getAllowedAmountToContribute(address addr) view public returns(uint256);
}


contract AuctusTokenSale is ContractReceiver {
	using SafeMath for uint256;

	address public auctusTokenAddress = 0x0;
	address public auctusWhiteListAddress = 0x0;

	uint256 public startTime = 1522159200; //2018-03-27 2 PM UTC
	uint256 public endTime = 1522504800; //2018-03-31 2 PM UTC

	uint256 public basicPricePerEth = 2000;

	address public owner;
	uint256 public softCap;
	uint256 public remainingTokens;
	uint256 public weiRaised;
	mapping(address => uint256) public invested;

	bool public saleWasSet;
	bool public tokenSaleHalted;

	event Buy(address indexed buyer, uint256 tokenAmount);
	event Revoke(address indexed buyer, uint256 investedAmount);

	function AuctusTokenSale(uint256 minimumCap) public {
		owner = msg.sender;
		softCap = minimumCap;
		saleWasSet = false;
		tokenSaleHalted = false;
	}

	modifier onlyOwner() {
		require(owner == msg.sender);
		_;
	}

	modifier openSale() {
		require(saleWasSet && !tokenSaleHalted && now >= startTime && now <= endTime && remainingTokens > 0);
		_;
	}

	modifier saleCompletedSuccessfully() {
		require(weiRaised >= softCap && (now > endTime || remainingTokens == 0));
		_;
	}

	modifier saleFailed() {
		require(weiRaised < softCap && now > endTime);
		_;
	}

	function transferOwnership(address newOwner) onlyOwner public {
		require(newOwner != address(0));
		owner = newOwner;
	}

	function setTokenSaleHalt(bool halted) onlyOwner public {
		tokenSaleHalted = halted;
	}

	function setSoftCap(uint256 minimumCap) onlyOwner public {
		require(now < startTime);
		softCap = minimumCap;
	}

	function tokenFallback(address, uint256 value, bytes) public {
		require(msg.sender == auctusTokenAddress);
		require(!saleWasSet);
		setTokenSaleDistribution(value);
	}

	function()
		payable
		openSale
		public
	{
		uint256 weiToInvest;
		uint256 weiRemaining;
		(weiToInvest, weiRemaining) = getValueToInvest();

		require(weiToInvest > 0);

		uint256 tokensToReceive = weiToInvest.mul(basicPricePerEth);
		remainingTokens = remainingTokens.sub(tokensToReceive);
		weiRaised = weiRaised.add(weiToInvest);
		invested[msg.sender] = invested[msg.sender].add(weiToInvest);

		if (weiRemaining > 0) {
			msg.sender.transfer(weiRemaining);
		}
		assert(AuctusToken(auctusTokenAddress).transfer(msg.sender, tokensToReceive));

		emit Buy(msg.sender, tokensToReceive);
	}

	function revoke() saleFailed public {
		uint256 investedValue = invested[msg.sender];
		require(investedValue > 0);

		invested[msg.sender] = 0;
		msg.sender.transfer(investedValue);

		emit Revoke(msg.sender, investedValue);
	}

	function finish() 
		onlyOwner
		saleCompletedSuccessfully 
		public 
	{
		//40% of the ethers are unvested
		uint256 freeEthers = address(this).balance * 40 / 100;
		uint256 vestedEthers = address(this).balance - freeEthers;

		address(0x0).transfer(freeEthers); //Auctus multi signed wallet
		assert(address(0x0).call.value(vestedEthers)(bytes4(keccak256("deposit()")))); //AuctusEtherVesting SC

		AuctusToken token = AuctusToken(auctusTokenAddress);
		token.setTokenSaleFinished();
		if (remainingTokens > 0) {
			token.burn(remainingTokens);
			remainingTokens = 0;
		}
	}

	function getValueToInvest() view private returns (uint256, uint256) {
		uint256 allowedValue = AuctusWhitelist(auctusWhiteListAddress).getAllowedAmountToContribute(msg.sender);

		uint256 weiToInvest;
		if (allowedValue == 0) {
			weiToInvest = 0;
		} else if (allowedValue >= invested[msg.sender].add(msg.value)) {
			weiToInvest = getAllowedAmount(msg.value);
		} else {
			weiToInvest = getAllowedAmount(allowedValue.sub(invested[msg.sender]));
		}
		return (weiToInvest, msg.value.sub(weiToInvest));
	}

	function getAllowedAmount(uint256 value) view private returns (uint256) {
		uint256 maximumValue = remainingTokens / basicPricePerEth;
		if (value > maximumValue) {
			return maximumValue;
		} else {
			return value;
		}
	}

	function setTokenSaleDistribution(uint256 totalAmount) private {
		//Auctus core team 20%
		uint256 auctusCoreTeam = totalAmount * 20 / 100;
		//Bounty 2%
		uint256 bounty = totalAmount * 2 / 100;
		//Reserve for Future 18%
		uint256 reserveForFuture = totalAmount * 18 / 100;
		//Partnerships and Advisory free amount 1.8%
		uint256 partnershipsAdvisoryFree = totalAmount * 18 / 1000;
		//Partnerships and Advisory vested amount 7.2%
		uint256 partnershipsAdvisoryVested = totalAmount * 72 / 1000;

		uint256 privateSales = 0;
		uint256 preSale = 2397307557007329968290000;

		transferTokens(auctusCoreTeam, bounty, reserveForFuture, preSale, partnershipsAdvisoryVested, partnershipsAdvisoryFree, privateSales);
		
		remainingTokens = totalAmount - auctusCoreTeam - bounty - reserveForFuture - preSale - partnershipsAdvisoryVested - partnershipsAdvisoryFree - privateSales;
		saleWasSet = true;
	}
	
	function transferTokens(
		uint256 auctusCoreTeam,
		uint256 bounty,
		uint256 reserveForFuture,
		uint256 preSale,
		uint256 partnershipsAdvisoryVested,
		uint256 partnershipsAdvisoryFree,
		uint256 privateSales
	) private {
		AuctusToken token = AuctusToken(auctusTokenAddress);
		bytes memory empty;
		assert(token.transfer(0x0, auctusCoreTeam, empty)); //AuctusTokenVesting SC
		assert(token.transfer(0x0, bounty, empty)); //AuctusBountyDistribution SC
		assert(token.transfer(0x0, reserveForFuture, empty)); //AuctusTokenVesting SC
		assert(token.transfer(0x0, preSale, empty)); //AuctusPreSaleDistribution SC
		assert(token.transfer(0x0, partnershipsAdvisoryVested, empty)); //AuctusTokenVesting SC
		assert(token.transfer(0x0, partnershipsAdvisoryFree));
		assert(token.transfer(0x0, privateSales));
	}
}