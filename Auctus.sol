//Draft Auctus SC version 0.2
pragma solidity ^0.4.13;


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

	function min(uint256 x, uint256 y) internal constant returns (uint256) {
		return x <= y ? x : y;
	}

	function max(uint256 x, uint256 y) internal constant returns (uint256) {
		return x > y ? x : y;
	}
}


contract VestedToken {
	using SafeMath for uint256;
	
	struct Token {
		uint256 amount;
		uint64 useOnlyAfter;
	}
	
	mapping(address => Token[]) public balances;
	
	function tokenAttributionCount(address owner) constant returns (uint256) {
		return balances[owner].length;
	}
	
	function balanceAt(address owner, uint64 time) constant returns (uint256) {
		uint256 quantity = 0;
		uint256 attributionCount = tokenAttributionCount(owner);
		for (uint256 i = 0; i < attributionCount; i++) {
			if (balances[owner][i].useOnlyAfter == 0 || time > balances[owner][i].useOnlyAfter) {
				quantity += balances[owner][i].amount;
			}
		}
		return quantity;
	}
	
	function currentTime() returns (uint64) {
		return uint64(now);
	}
	
	function addAmount(address recipient, uint256 quantity, uint64 transferableAfter) internal {
		require(quantity > 0);
		bool attributed = false;
		uint256 attributionCount = tokenAttributionCount(recipient);
		for (uint256 i = 0; i < attributionCount; i++) {
			if (balances[recipient][i].useOnlyAfter == transferableAfter) {
				balances[recipient][i].amount = balances[recipient][i].amount.plus(quantity);
				attributed = true; //TODO: Evaluate use of 'return' instead of 'break' due security reasons
				break;
			}
		}
		if (!attributed) {
			balances[recipient].push(Token(quantity, transferableAfter));
		}
	}

	function removeAmount(address from, uint256 quantity) internal {
		require(quantity > 0);
		uint256 remaining = quantity;
		uint256 attributionCount = tokenAttributionCount(from);
		for(uint256 i = 0; i < attributionCount; i++) {
			if (
				balances[from][i].amount > 0 &&
				(balances[from][i].useOnlyAfter == 0 ||
				currentTime() > balances[from][i].useOnlyAfter) 
				
			) {
				if (balances[from][i].amount >= remaining) {
					balances[from][i].amount = balances[from][i].amount.minus(remaining);
					remaining = 0;
					break;
				} else {
					remaining = remaining.minus(balances[from][i].amount);
					balances[from][i].amount = 0;
				}
			}
		}
		assert(remaining == 0);
	}
}


contract Owner is VestedToken {
	address public ownerAddress;
	
	modifier onlyOwner() {
        require(msg.sender == ownerAddress);
		_;
    }
	
	function Owner() {
		ownerAddress = msg.sender;
	}	
	
	function transferOwnership(address newOwner) onlyOwner {
        ownerAddress = newOwner;
		uint256 attributionCount = tokenAttributionCount(msg.sender);
		for(uint256 i = 0; i < attributionCount; i++) {
			if (balances[msg.sender][i].amount > 0) {
				addAmount(newOwner, balances[msg.sender][i].amount, balances[msg.sender][i].useOnlyAfter);
				balances[msg.sender][i].amount = 0;
			}
		}
    }
}


contract AuctusIco is Owner {
	struct BuyInfo {
		uint256 currentWeiInvested; // Wei invested in current limitation block amount
		uint256 startBlockToCurrentLimitation; 
		uint256 weiInvested;
	}
	
	struct Bonus {
		uint64 period; // Max period after start timestamp
		uint256 bonus; // in percentage
	}
	
	bool public fundingHalted = false;
	
	uint256 public startBlock = 0;
	uint64 public maxPeriod = 86400 * 15; //15 days after start block timestamp
	
	uint256 public minCap = 20000 ether;
	uint256 public targetCap = 80000 ether;
	
	uint64 public extraTimeAfterTargetReached = 86400; //24h after ether target reached
	
	uint256 public maxGasPrice = 50000000000; // 50 gwei
	uint256 public blockAmount = 150; // Block amount to refresh limitations 
	uint256 public maxEthPerBlockAmount = 40 ether;
	
	uint256 public basicPricePerEth = 2500;
	
	Bonus[] public bonusDistribution;
	mapping(address => BuyInfo) public buyInfo;
	
	uint64 public startTimestamp; 
	uint64 public targetReachedTimestamp;
	uint256 public weiRaised;
	uint256 public amountShared;
	
	event Buy(address indexed recipient, uint256 amount);
	event Revoke(address indexed recipient, uint256 amount);
	
	modifier icoPeriod() {
		require(blockNumber() >= startBlock && 
				(startTimestamp == 0 || currentTime() <= (startTimestamp + maxPeriod)) &&
				(weiRaised < targetCap || currentTime() <= (targetReachedTimestamp + extraTimeAfterTargetReached)));
		_;
	}
	
	modifier icoCompletedSuccessfully() {
		require(weiRaised >= minCap && startTimestamp > 0 && (currentTime() > (startTimestamp + maxPeriod) ||
				(weiRaised >= targetCap && currentTime() > (targetReachedTimestamp + extraTimeAfterTargetReached))));
		_;
	}
	
	modifier icoFailed() {
		require(weiRaised < minCap && startTimestamp > 0 && currentTime() > (startTimestamp + maxPeriod));
		_;
	}
	
	modifier isFundingNotHalted() {
		require(!fundingHalted);
		_;
	}
	
	function AuctusIco() {
		bonusDistribution.push(Bonus(86400, 16)); // first day, 16%
		bonusDistribution.push(Bonus(86400 * 3, 12)); // until third day, 12%
		bonusDistribution.push(Bonus(86400 * 6, 8)); // until sixth day, 8%
		bonusDistribution.push(Bonus(86400 * 9, 4)); // until ninth day, 4%
		bonusDistribution.push(Bonus(86400 * 12, 2)); // until twelfth day, 2%
	}
	
	function() 
		payable 
		icoPeriod 
		isFundingNotHalted 
	{
		require(msg.value > 0 && tx.gasprice <= maxGasPrice);
		
		var (weiToInvest, weiRemaining) = getWeiValues();
		assert(weiToInvest > 0);
		
		uint256 amount = getTokenAmount(weiToInvest);
		addAmount(msg.sender, amount, 0);
		amountShared = amountShared.plus(amount);
		weiRaised = weiRaised.plus(weiToInvest);
		
		if (startTimestamp == 0) {
			startTimestamp = currentTime();
		}
		if (weiRaised >= targetCap && targetReachedTimestamp == 0) {
			targetReachedTimestamp = currentTime();
		}
		
		require(weiRemaining == 0 || msg.sender.send(weiRemaining)); // TODO: Evaluate if is there a best way
		Buy(msg.sender, amount);
	}
	
	function revoke() icoFailed {
		uint256 weiAmount = buyInfo[msg.sender].weiInvested;
		assert(weiAmount > 0);
		buyInfo[msg.sender].weiInvested = 0;
		require(msg.sender.send(weiAmount));
		Revoke(msg.sender, weiAmount);
	}
	
	function blockNumber() returns (uint256) {
		return block.number;
	}
	
	function setFundingHalt(bool halted) onlyOwner {
		fundingHalted = halted;
	}
	
	function getWeiValues() internal returns (uint256, uint256) {
		if (blockNumber() > (buyInfo[msg.sender].startBlockToCurrentLimitation + blockAmount)) {
			buyInfo[msg.sender].startBlockToCurrentLimitation = blockNumber();
			buyInfo[msg.sender].currentWeiInvested = 0;
		}
		uint256 weiToInvest;
		uint256 weiRemaining;
		uint256 newWeiInvested = buyInfo[msg.sender].currentWeiInvested.plus(msg.value);
		if (newWeiInvested <= maxEthPerBlockAmount) {
			weiToInvest = msg.value;
			buyInfo[msg.sender].currentWeiInvested = newWeiInvested;
			weiRemaining = 0;
		} else {
			weiToInvest = maxEthPerBlockAmount.minus(buyInfo[msg.sender].currentWeiInvested);
			buyInfo[msg.sender].currentWeiInvested = maxEthPerBlockAmount;
			weiRemaining = msg.value.minus(weiToInvest);
		}
		buyInfo[msg.sender].weiInvested = buyInfo[msg.sender].weiInvested.plus(weiToInvest);
		return (weiToInvest, weiRemaining);
	}
	
	function getTokenAmount(uint256 weiAmount) internal returns (uint256) {
		uint256 bonusApplied = 0;
		for(uint256 i = 0; i < bonusDistribution.length; i++) {
			if (currentTime() <= (bonusDistribution[i].period + startTimestamp)) {
				bonusApplied = bonusApplied.max(bonusDistribution[i].bonus);
			}
		}
		uint256 price = basicPricePerEth * (100 + bonusApplied) / 100;
		return weiAmount.times(price) / (1 ether);
	}
}


contract AuctusPreIco {
    function balanceOf(address owner) constant returns (uint256);
	function tokenDistributed() constant returns (uint256);
}


contract DistributionManagement is AuctusIco {
	struct VestedDistribution {
		uint64 period; 
		uint256 percentage; 
	}
	
	bool public endOfDistribution = false;
	
	address public teamAddress = 0xdead; 
	address public preIcoContract = 0xdead; 
	uint256 public preIcoBonus = 75; // in percentage
	
	uint256 public ownerPercentage = 20; // for bounties and partnerships
	uint256 public teamPercentage = 30;
	
	uint256 public total;
	VestedDistribution[] public teamDistribution;
	mapping(address => bool) public preIcoClaimed;
	
	event PreIcoClaim(address indexed recipient, uint256 amount);
	
	modifier distributionIsFinished() {
		require(endOfDistribution);
		_;
	}
	
	function DistributionManagement() {
		teamDistribution.push(VestedDistribution(86400 * 180, 16)); // 6 months, 25%
		teamDistribution.push(VestedDistribution(86400 * 360, 16)); // 12 months, more 25%
		teamDistribution.push(VestedDistribution(86400 * 540, 16)); // 18 months, more 25%
		teamDistribution.push(VestedDistribution(86400 * 720, 16)); // 24 months, more 25%
	}
	
	function finishDistribution()
		onlyOwner
		icoCompletedSuccessfully
	{
		require(!endOfDistribution);
		AuctusPreIco preIco = AuctusPreIco(preIcoContract);
		uint256 amountSold = preIco.tokenDistributed() + amountShared;
		uint256 teamAmount = amountSold * 50 / 100 * teamPercentage / 100;
		uint256 ownerAmount = amountSold * 50 / 100 * ownerPercentage / 100;
		total = amountSold + teamAmount + ownerAmount;
		
		addAmount(ownerAddress, ownerAmount, 0);
		for(uint256 i = 0; i < teamDistribution.length; i++) {
			addAmount(teamAddress, 
					  teamAmount * teamDistribution[i].percentage / 100, 
					  teamDistribution[i].period + currentTime());
		}
		endOfDistribution = true;
	}
	
	function claimTokens() distributionIsFinished {
		require(!preIcoClaimed[msg.sender]);
		AuctusPreIco preIco = AuctusPreIco(preIcoContract);
		uint256 amount = preIco.balanceOf(msg.sender);
		assert(amount > 0); 
		preIcoClaimed[msg.sender] = true;
		uint256 newAmount = amount * (100 + preIcoBonus) / 100;
		addAmount(msg.sender, newAmount, 0);
		PreIcoClaim(msg.sender, newAmount);
	}
}


contract DrainManagement is DistributionManagement {
	struct DrainInfo {
		uint256 percentage;
		uint64 useOnlyAfter;
	}
	
	address public firstDrainAddress = 0xdead;
	address public secondDrainAddress = 0xdead;
	address public thirdDrainAddress = 0xdead;
	address public fourthDrainAddress = 0xdead;
	
	uint256 public drainImmediatePercentage = 20;
	uint256 public drainPercentagePerMonth = 5;
	
	DrainInfo[] public drainables;
	mapping(address => uint256) public alreadyDrained;
	
	event Drain(address indexed destination, uint256 amount);
	
	function DrainManagement() {
		drainables.push(DrainInfo(drainImmediatePercentage, 0)); 
		
		uint64 month = (86400 * 30);
		uint64 vestedPeriod = currentTime() + month;
		uint256 drainQt = (100 - drainImmediatePercentage) / drainPercentagePerMonth;
		for(uint256 i = 1; i <= drainQt; i++) {
			drainables.push(DrainInfo(drainPercentagePerMonth, vestedPeriod)); 
			vestedPeriod = vestedPeriod + month;
		}
	}
	
	function totalAlreadyDrained(address who) constant returns (uint256) {
		return alreadyDrained[who];
	}
	
	function processFirstAddressDrain() 
		onlyOwner 
		distributionIsFinished 
	{
		processDrain(firstDrainAddress);
	}
	
	function processSecondAddressDrain()
		onlyOwner 
		distributionIsFinished 
	{
		processDrain(secondDrainAddress);
	}
	
	function processThirdAddressDrain()
		onlyOwner 
		distributionIsFinished 
	{
		processDrain(thirdDrainAddress);
	}
	
	function processFourthAddressDrain() 
		onlyOwner 
		distributionIsFinished 
	{
		processDrain(fourthDrainAddress);
	}
	
	function processDrain(address destination) internal {
		uint256 percentageReleased = 0;
		for (uint256 i = 0; i < drainables.length; i++) {
			if (drainables[i].useOnlyAfter == 0 || currentTime() > drainables[i].useOnlyAfter) {
				percentageReleased += drainables[i].percentage;
			}
		}
		assert(percentageReleased > 0);
		uint256 weiReleasedPerDrainAddress = weiRaised * percentageReleased / 100 / 4;
		if (weiReleasedPerDrainAddress > this.balance) { // for security
			weiReleasedPerDrainAddress = this.balance;
		}
		require(alreadyDrained[destination] < weiReleasedPerDrainAddress);
		uint256 weiToBeDrained = weiReleasedPerDrainAddress - alreadyDrained[destination];
		alreadyDrained[destination] = alreadyDrained[destination] + weiToBeDrained;
		require(destination.send(weiToBeDrained));
		Drain(destination, weiToBeDrained);
	}
}


contract ERC20 {
    function totalSupply() constant returns (uint256);
    function balanceOf(address owner) constant returns (uint256);
    function transfer(address to, uint256 value) returns (bool);
    function transferFrom(address from, address to, uint256 value) returns (bool);
    function approve(address spender, uint256 value) returns (bool);
    function allowance(address owner, address spender) constant returns (uint256);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract Auctus is DrainManagement, ERC20 {
	string public name = "Auctus";
	string public symbol = "AUC";
	uint256 public decimals = 18;
	string public standard = "ERC20";
	
	mapping(address => mapping(address => uint256)) public allowed;
	
	event Burn(address indexed source, uint256 amount);
	event Bounty(address indexed recipient, uint256 amount, uint64 transferableAfter);

	modifier validPayload(uint256 size) { //"Fix for the ERC20 short address attack"
		require(msg.data.length >= (size + 4));
		_;
	}
	
	function totalSupply() constant returns (uint256) {
		return total;
	}
	
	function balanceOf(address owner) constant returns (uint256) {
		return balanceAt(owner, currentTime()); //TODO: Evaluate problems due block.number
	}
	
	function burn(uint256 amount) distributionIsFinished {
		burnToken(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) distributionIsFinished {
		allowed[from][msg.sender] = allowed[from][msg.sender].minus(amount);
		burnToken(from, amount);
    }

	function allowance(address owner, address spender) constant returns (uint256) {
		return allowed[owner][spender];
	}
	
	function transfer(address to, uint256 value) 
		validPayload(2 * 32) 
		distributionIsFinished
		returns (bool) 
	{
		internalTransfer(msg.sender, to, value, 0);
		Transfer(msg.sender, to, value);
		return true;
	}
	
	function transferFrom(address from, address to, uint256 value) 
		validPayload(3 * 32) 
		distributionIsFinished
		returns (bool) 
	{
		allowed[from][msg.sender] = allowed[from][msg.sender].minus(value);
		internalTransfer(from, to, value, 0);
		Transfer(from, to, value);
		return true;
	}
	
	function approve(address spender, uint256 value) validPayload(2 * 32) returns (bool) {
		require(value == 0 || allowed[msg.sender][spender] != 0); // TODO: Evaluate remove this restriction "mitigate the race condition" https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
		allowed[msg.sender][spender] = value;
		Approval(msg.sender, spender, value);
		return true;
	}
	
	function bounty(address to, uint256 value, uint64 transferableAfter) 
		onlyOwner
		distributionIsFinished
	{
		internalTransfer(msg.sender, to, value, transferableAfter);
		Bounty(to, value, transferableAfter);
	}
	
	function internalTransfer(
		address from, 
		address to, 
		uint256 value, 
		uint64 transferableAfter
	) internal {
		removeAmount(from, value);
		addAmount(to, value, transferableAfter);
	}

	function burnToken(address source, uint256 tokenAmount) internal {
		removeAmount(source, tokenAmount);
        total = total.minus(tokenAmount);  
        Burn(source, tokenAmount);
	}
}