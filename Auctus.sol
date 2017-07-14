//Draft Auctus SC version 0.1
pragma solidity ^0.4.11;


library SafeMath {
	function times(uint256 x, uint256 y) internal returns (uint256) {
		uint256 z = x * y;
		assert(x == 0 || (z / x == y));
		return z;
	}

	function divided(uint256 x, uint256 y) internal returns (uint256) {
		assert(y != 0);
		return x / y;
	}

	function minus(uint256 x, uint256 y) internal returns (uint256) {
		assert(y <= x);
		return x - y;
	}

	function plus(uint256 x, uint256 y) internal returns (uint256) {
		uint256 z = x + y;
		assert(z >= x && z >= y);
		return z;
	}

	function min64(uint256 x, uint256 y) internal constant returns (uint256) {
		return x <= y ? x : y;
	}

	function max64(uint256 x, uint256 y) internal constant returns (uint256) {
		return x > y ? x : y;
	}

	function min256(uint256 x, uint256 y) internal constant returns (uint256) {
		return x <= y ? x : y;
	}

	function max256(uint256 x, uint256 y) internal constant returns (uint256) {
		return x > y ? x : y;
	}
}


contract TokenContainer {
	using SafeMath for uint256;
	
	struct Token {
		uint256 amount;
		uint64 useOnlyAfterUnixDate;
		uint256 weiInvested;
		bool preIco;
	}
	
	uint256 public MAX_ATTRIBUTIONS_PER_ADDRESS = 20;
	mapping(address => Token[]) public attributions;
	
	function tokenAttributionCount(address owner) constant returns (uint256) {
		return attributions[owner].length;
	}
	
	function balanceOf(address owner) constant returns (uint256) {
		uint256 quantity = 0;
		uint256 attributionCount = tokenAttributionCount(owner);
		if (attributionCount > 0) {
			for(uint256 i = 0; i < attributionCount; i++) {
				quantity += attributions[owner][i].amount;
			}
		}
		return quantity;
	}
	
	function balanceAt(address owner, uint64 time) constant returns (uint256) {
		uint256 quantity = 0;
		uint256 attributionCount = tokenAttributionCount(owner);
		if (attributionCount > 0) {
			for(uint256 i = 0; i < attributionCount; i++) {
				if (attributions[owner][i].useOnlyAfterUnixDate == 0 || time >= attributions[owner][i].useOnlyAfterUnixDate) quantity += attributions[owner][i].amount;
			}
		}
		return quantity;
	}
	
	function getCurrentTime() returns (uint64) {
		return uint64(now);
	}
	
	function addToken(
		address recipient,
		uint256 quantity, 
		uint64 transferableUnixDate, 
		uint256 investimentInWei, 
		bool isPreIco
	) internal {
		require(tokenAttributionCount(recipient) < MAX_ATTRIBUTIONS_PER_ADDRESS);
		
		attributions[recipient].push(
			Token(
				quantity, 
				transferableUnixDate,
				investimentInWei,
				isPreIco
			)
		);
	}

	function removeAmount(address from, uint256 quantity) internal {
		uint256 attributionCount = tokenAttributionCount(from);
		require(attributionCount > 0);
		
		uint64 currentTime = getCurrentTime();
		uint256 remaining = quantity;
		for(uint256 i = 0; i < attributionCount; i++) {
			if (
				attributions[from][i].amount > 0 &&
				(attributions[from][i].useOnlyAfterUnixDate == 0 ||
				currentTime >= attributions[from][i].useOnlyAfterUnixDate) 
				
			) {
				if (attributions[from][i].amount >= remaining) {
					attributions[from][i].amount = SafeMath.minus(attributions[from][i].amount, remaining);
					remaining = 0;
					break;
				}
				else {
					remaining = SafeMath.minus(remaining, attributions[from][i].amount);
					attributions[from][i].amount = 0;
				}
			}
		}
		assert(remaining == 0);
	}
	
	function addAmount(
		address to, 
		uint256 quantity,
		uint64 transferableUnixDate
	) internal {
		uint256 attributionCount = tokenAttributionCount(to);
		if (transferableUnixDate == 0 && attributionCount > 0) {
			for(uint256 i = 0; i < attributionCount; i++) {
				if (attributions[to][i].useOnlyAfterUnixDate == 0) {
					attributions[to][i].amount = SafeMath.plus(attributions[to][i].amount, quantity);
					return;
				}
			}
		} 
		addToken(to, quantity, 0, transferableUnixDate, false);
	}
	
	function revokeWeiInvested(address owner, bool isPreIco) internal returns (uint256) {
		uint256 quantity = 0;
		uint256 attributionCount = tokenAttributionCount(owner);
		if (attributionCount > 0) {
			for(uint256 i = 0; i < attributionCount; i++) {
				if (attributions[owner][i].preIco == isPreIco) {
					quantity += attributions[owner][i].weiInvested;
					//Set all data to zero from token revoked
					attributions[owner][i].amount = 0;
					attributions[owner][i].weiInvested = 0;
				}
			}
		}
		assert(quantity > 0);
		return quantity;
	}
}


contract TokenBasic is TokenContainer {
	address public ownerAddress;
	mapping(address => mapping(address => uint256)) public allowed;
	
	event Transfer(address indexed from, address indexed to, uint256 value);
	event Approval(address indexed owner, address indexed spender, uint256 value);
	
	modifier onlyOwner() {
        require(msg.sender == ownerAddress);
		_;
    }
	
	modifier validPayload() { //"Fix for the ERC20 short address attack"
		require(msg.data.length >= 68);
		_;
	}
	
	function tokenOwnerAddress() constant returns (address) {
		return ownerAddress;
	}
	
	function allowance(address owner, address spender) constant returns (uint256) {
		return allowed[owner][spender];
	}
	
	function transfer(address to, uint256 value) validPayload {
		internalTransfer(msg.sender, to, value, 0);
	}
	
	function transferFrom(address from, address to, uint256 value) validPayload {
		allowed[from][msg.sender] = SafeMath.minus(allowed[from][msg.sender], value);
		internalTransfer(from, to, value, 0);
	}
	
	function approve(address spender, uint256 value) {
		require(value == 0 || allowed[msg.sender][spender] != 0); // "mitigate the race condition" https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
		allowed[msg.sender][spender] = value;
		Approval(msg.sender, spender, value);
	}
	
	function transferOwnership(address newOwner) onlyOwner {
        ownerAddress = newOwner;
    }
	
	function internalTransfer(
		address from,
		address to, 
		uint256 value,
		uint64 transferableUnixDate
	) internal {
		removeAmount(from, value);
		addAmount(to, value, transferableUnixDate);
		Transfer(from, to, value);
	}
}


contract Crowdsale is TokenBasic {
	bool public fundingHalted = false;
	uint256 public totalSupply = 10000000000;
	uint256 public tokenPriceToOneEther = 100000;
	uint256 public minWeiToInvest = 50000000000000000; // 0.05 ether
	uint256 public preIcoBonus = 50; //in percentage
	uint64 public preIcoStartTime = 1502787600; // 2017-08-15 09:00:00 UTC
	uint64 public preIcoEndTime = 1503997200; // 2017-08-29 09:00:00 UTC
	uint256 public maxPreIcoCap = 1000 ether;
	uint256 public minPreIcoCap = 500 ether;
	uint256 public maxIcoCap = 50000 ether;
	uint256 public minIcoCap = 13000 ether;
	uint256 public maxIcoGasPrice = 50000000000; // 50 gwei
	uint256 public maxIcoPurchaseValuePerTime = 100 ether; 
	uint256 public maxDaysForFinishIcoAfterContractCreation = 110;
	
	uint256 public icoStartBlock; 
	uint256 public icoEndBlock; 
	uint256 public maxBlockToFinishIco;
	uint256 public preIcoWeiRaised;
	uint256 public icoWeiRaised;
	uint256 public amountShared;
	
	event Bounty(address indexed recipient, uint256 amount);
	event PreBuy(address indexed recipient, uint256 amount);
	event Buy(address indexed recipient, uint256 amount);
	
	modifier preIcoPeriod() {
		require(isPreIcoPeriod());
		_;
	}
	
	modifier preIcoCompletedSuccessfully() {
		require(preIcoWeiRaised >= minPreIcoCap && (preIcoWeiRaised >= maxPreIcoCap || getCurrentTime() > preIcoEndTime));
		_;
	}

	modifier icoPeriod() {
		require(isIcoPeriod());
		_;
	}
	
	modifier icoCompletedSuccessfully() {
		require(icoWeiRaised >= minIcoCap && (icoWeiRaised >= maxIcoCap || block.number > icoEndBlock));
		_;
	}
	
	modifier isFundingNotHalted() {
		require(!fundingHalted);
		_;
	}
	
	function tokenTotalSupply() constant returns (uint256) {
		return totalSupply;
	}

	function tokenPrice() constant returns (uint256) {
		return tokenPriceToOneEther;
	}
	
	function tokenPreIcoBonus() constant returns (uint256) {
		return preIcoBonus;
	}
	
	function tokenPreIcoStartTime() constant returns (uint256) {
		return preIcoStartTime;
	}
	
	function tokenPreIcoEndTime() constant returns (uint256) {
		return preIcoEndTime;
	}
	
	function tokenMaximumPreIcoCap() constant returns (uint256) {
		return maxPreIcoCap;
	}
	
	function tokenMinimumPreIcoCap() constant returns (uint256) {
		return minPreIcoCap;
	}
	
	function tokenIcoStartBlock() constant returns (uint256) {
		return icoStartBlock;
	}
	
	function tokenIcoEndBlock() constant returns (uint256) {
		return icoEndBlock;
	}
	
	function tokenMaximumIcoCap() constant returns (uint256) {
		return maxIcoCap;
	}
	
	function tokenMinimumIcoCap() constant returns (uint256) {
		return minIcoCap;
	}
	
	function tokenMaxBlockNumberToFinishIco() constant returns (uint256) {
		return maxBlockToFinishIco;
	}
	
	function tokenPreIcoWeiRaised() constant returns (uint256) {
		return preIcoWeiRaised;
	}
	
	function tokenIcoWeiRaised() constant returns (uint256) {
		return icoWeiRaised;
	}
	
	function tokenShared() constant returns (uint256) {
		return amountShared;
	}
	
	function fundingIsHalted() constant returns (bool) {
		return fundingHalted;
	}
	
	function preSale() 
		payable 
		preIcoPeriod 
		isFundingNotHalted 
	{
		uint256 amount = processPurchase((tokenPriceToOneEther * (100 + preIcoBonus)) / 100, true);
		preIcoWeiRaised += msg.value;
		PreBuy(msg.sender, amount);
	}
	
	function revoke() {
		bool isPreIcoFailed = preIcoFailed();
		bool isIcoFailed = icoFailed();
		require(isPreIcoFailed || isIcoFailed);
		uint256 weiAmount = revokeWeiInvested(msg.sender, isPreIcoFailed);
		assert(msg.sender.send(weiAmount));
	}
	
	function bounty(address recipient, uint256 amount, uint64 transferableUnixDate) onlyOwner {
		require(isSafeShare(amount));
		require(tokenAttributionCount(recipient) < (MAX_ATTRIBUTIONS_PER_ADDRESS - 1)); //Make sure that there is one slot available
		internalTransfer(msg.sender, recipient, amount, transferableUnixDate);
		amountShared += amount;
		Bounty(recipient, amount);
	}
	
	function setFundingHalt(bool halted) onlyOwner {
		fundingHalted = halted;
	}
	
	function setIcoPeriodParameters(uint256 newIcoStartBlock, uint256 newIcoEndBlock) 	
		onlyOwner
		preIcoCompletedSuccessfully	
	{
		require(block.number < newIcoStartBlock && newIcoEndBlock < maxBlockToFinishIco && newIcoEndBlock > newIcoStartBlock); 
		icoStartBlock = newIcoStartBlock; 
		icoEndBlock = newIcoEndBlock; 
	}
	
	function sale() internal {
		require(tx.gasprice <= maxIcoGasPrice && msg.value <= maxIcoPurchaseValuePerTime);
		uint256 amount = processPurchase(tokenPriceToOneEther, false);
		icoWeiRaised += msg.value;
		Buy(msg.sender, amount);
	}
	
	function setCrowdsaleParameters() internal {
		uint256 blocksPerDay = (60*60*24) / 18; // 18 is block average time in seconds
		icoStartBlock = block.number + (45 * blocksPerDay); 
		icoEndBlock = block.number + (75 * blocksPerDay); 
		maxBlockToFinishIco = block.number + (maxDaysForFinishIcoAfterContractCreation * blocksPerDay); 
		assert(maxBlockToFinishIco >= icoEndBlock);
	}
	
	function isPreIcoPeriod() internal returns (bool) {
		return (getCurrentTime() >= preIcoStartTime && getCurrentTime() <= preIcoEndTime && preIcoWeiRaised < maxPreIcoCap);
	}
	
	function isIcoPeriod() internal returns (bool) {
		return (block.number >= icoStartBlock && block.number <= icoEndBlock && icoWeiRaised < maxIcoCap);
	}
	
	function preIcoFailed() internal returns (bool) {
		return (preIcoWeiRaised < minPreIcoCap && getCurrentTime() > preIcoEndTime);
	}
	
	function icoFailed() internal returns (bool) {
		return (icoWeiRaised < minIcoCap && block.number > icoEndBlock);
	}
	
	function isSafeShare(uint256 amount) internal returns (bool) {
		return amount <= SafeMath.minus(totalSupply, amountShared);
	}

	function processPurchase(uint256 price, bool isPreIco) internal returns (uint256 tokenAmount) {
		require(msg.value >= minWeiToInvest);
		tokenAmount = SafeMath.times(msg.value, price) / (1 ether);
		require(isSafeShare(tokenAmount));
		removeAmount(ownerAddress, tokenAmount);
		addToken(msg.sender, tokenAmount, 0, msg.value, isPreIco);
		amountShared += tokenAmount;
	}
}


contract DrainManagement {
	struct Drain {
		uint256 percentage;
		uint64 useOnlyAfterUnixDate;
		bool used;
	}
	
	Drain[] public drainables;
	
	function percentageAlreadyDrained() constant returns (uint256) {
		uint256 percentageOfTotal = 0;
		for(uint256 i = 0; i < drainables.length; i++) {
			if (drainables[i].used) percentageOfTotal += drainables[i].percentage;
		}
		return percentageOfTotal;
	}
	
	function processDrain() internal returns (uint256) {
		uint256 percentageOfTotal = 0;
		uint64 currentTime = uint64(now);
		for(uint256 i = 0; i < drainables.length; i++) {
			if (
				!drainables[i].used &&
				(drainables[i].useOnlyAfterUnixDate == 0 || 
				currentTime >= drainables[i].useOnlyAfterUnixDate) 
			) {
				drainables[i].used = true;
				percentageOfTotal += drainables[i].percentage;
			}
		}
		return percentageOfTotal;
	}
	
	function addDrain(uint256 percentageOfTotal, uint64 drainableUnixDate) internal {
		drainables.push(
			Drain(
				percentageOfTotal, 
				drainableUnixDate,
				false
			)
		);
	}
}

contract AuctusProject is Crowdsale, DrainManagement {
	string public name = "Auctus Project";
	string public symbol = "AUC";
	uint256 public decimals = 18;
	
	uint64 public teamWaitingDaysToTransferOwnToken = 360;
	uint256 public teamTokenPercentage = 25;
	
	uint256 public drainImmediatePercentage = 25;
	
	uint64 public daysForFirstStepDrain = 150;//5 months
	uint256 public drainFirstStepPercentage = 15;
	
	uint64 public daysForSecondStepDrain = 300;//10 months
	uint256 public drainSecondStepPercentage = 15;
	
	uint64 public daysForThirdStepDrain = 450;//15 months
	uint256 public drainThirdPercentage = 15;
	
	uint64 public daysForFourthStepDrain = 600;//20 months
	uint256 public drainFourthStepPercentage = 15;
	
	uint64 public daysForLastStepDrain = 750;//25 months
	uint256 public drainLastStepPercentage = 15;
	
	event Burn(address indexed source, uint256 amount);

	function tokenName() constant returns (string) {
		return name;
	}
	
	function tokenSymbol() constant returns (string) {
		return symbol;
	}
	
	function tokenDecimals() constant returns (uint256) {
		return decimals;
	}
	
	function weiDrained() constant returns (uint256) {
		return percentageAlreadyDrained() * icoWeiRaised / 100;
	}
	
	function AuctusProject() {
		ownerAddress = msg.sender;
		setCrowdsaleParameters();
		
		uint64 daySeconds = uint64(60*60*24);
		uint256 teamAmount = teamTokenPercentage * totalSupply / 100;
		uint64 teamTokenTransferableUnixTime = getCurrentTime() + uint64(daySeconds * teamWaitingDaysToTransferOwnToken); 
		addToken(msg.sender, (totalSupply - teamAmount), 0, 0, false); //Remaining tokens
		addToken(msg.sender, teamAmount, teamTokenTransferableUnixTime, 0, false); //Team tokens
		
		addDrain(drainImmediatePercentage, 0);
		addDrain(drainFirstStepPercentage, uint64(daySeconds * daysForFirstStepDrain));
		addDrain(drainSecondStepPercentage, uint64(daySeconds * daysForSecondStepDrain));
		addDrain(drainThirdPercentage, uint64(daySeconds * daysForThirdStepDrain));
		addDrain(drainFourthStepPercentage, uint64(daySeconds * daysForFourthStepDrain));
		addDrain(drainLastStepPercentage, uint64(daySeconds * daysForLastStepDrain));
	}
	
	function() 
		payable 
		preIcoCompletedSuccessfully
		icoPeriod 
		isFundingNotHalted 
	{
		super.sale();
	}
	
	function burn(uint256 amount) icoCompletedSuccessfully {
		burnToken(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) icoCompletedSuccessfully {
		allowed[from][msg.sender] = SafeMath.minus(allowed[from][msg.sender], amount);
		burnToken(from, amount);
    }
	
	function transfer(address to, uint256 value) icoCompletedSuccessfully {
		super.transfer(to, value);
	}
	
	function transferFrom(address from, address to, uint256 value) icoCompletedSuccessfully {
		super.transferFrom(from, to, value);
	}
	
	function drainPreIco()
		onlyOwner
		preIcoCompletedSuccessfully
	{
		require(block.number < icoStartBlock); //Only drainable before ICO start
		assert(ownerAddress.send(this.balance));
	}
	
	function drain() 
		onlyOwner 
		icoCompletedSuccessfully 
	{
		uint256 percentage = processDrain();
		if (percentage > 0) {
			uint256 quantity = icoWeiRaised * percentage / 100;
			if (quantity > this.balance) quantity = this.balance; //For safe
			assert(ownerAddress.send(quantity));
		}
	}
	
	function burnToken(address source, uint256 tokenAmount) internal {
		removeAmount(source, tokenAmount);
		addAmount(0xdead, tokenAmount, 0);
        totalSupply = SafeMath.minus(totalSupply, tokenAmount);  
        Burn(source, tokenAmount);
	}
}