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


contract AuctusAlphaEscrow {
  function isValidEscrow(address who) public constant returns (bool);
}


contract AuctusAlpha is ContractReceiver {
	using SafeMath for uint256;
	
	struct Portfolio {
		address owner;
		uint256 projection;
		uint256 price;
		uint64 period;
		uint64 cliff;
		bool enabled;
		string distribution;
	}
	
	struct Purchase {
		uint256 identifier;
		uint256 price;
		uint64 period;
		uint64 cliff;
		uint64 matchPriceIndex;
		uint256 datetime;
		bool finished;
		uint64 paymentPeriod;
		mapping(uint64 => int256) performedValue;
	}
	
	struct MatchPrice {
		uint256 variation;
		uint256 pricePercentage;
	}
	
	address public admin;
	bool public toValidateEscrow;
	uint64 public currentMatchPriceIndex;

	address public auctusAlphaToken = 0x0;
	address public auctusAlphaEscrow = 0x0;
	uint256 public basePercentageNumber = 100000000;
	
	mapping(uint256 => Portfolio) internal portfolio;
	mapping(address => Purchase[]) internal purchase;
	mapping(address => uint256) internal escrowed;
	mapping(uint64 => MatchPrice[]) internal matchPrice;
	
	event CreatePortfolio(uint256 indexed portfolio, address indexed owner, uint256 projection, uint256 price, uint64 period, uint64 cliff, string distribution);
	event UpdatePortfolio(uint256 indexed portfolio, uint256 price, uint64 period, uint64 cliff, bool enabled);
	event UpdateDistribution(uint256 indexed portfolio, string distribution);
	event MakePurchase(address indexed buyer, uint256 indexed portfolio, uint256 price, uint64 period, uint64 cliff, uint64 matchPriceIndex, uint256 datetime);
	event MatchPurchase(address indexed buyer, uint256 indexed portfolio, uint64 paymentPeriod, uint256 expectedValue, int256 performedValue, uint256 buyerCashback, uint256 portfolioOwnerPayment);
	event ValidateEscrow(bool indexed validate);
	
	modifier onlyAdmin() {
        require(msg.sender == admin);
		_;
    }
	
	function AuctusAlpha() public {
		admin = msg.sender;
		toValidateEscrow = true;
		currentMatchPriceIndex = 0;
		matchPrice[0].push(MatchPrice({ variation: (95 * basePercentageNumber / 100), pricePercentage: (10 * basePercentageNumber / 100) }));
		matchPrice[0].push(MatchPrice({ variation: (90 * basePercentageNumber / 100), pricePercentage: (20 * basePercentageNumber / 100) }));
		matchPrice[0].push(MatchPrice({ variation: (85 * basePercentageNumber / 100), pricePercentage: (30 * basePercentageNumber / 100) }));
		matchPrice[0].push(MatchPrice({ variation: (80 * basePercentageNumber / 100), pricePercentage: (40 * basePercentageNumber / 100) }));
		matchPrice[0].push(MatchPrice({ variation: (75 * basePercentageNumber / 100), pricePercentage: (50 * basePercentageNumber / 100) }));
		matchPrice[0].push(MatchPrice({ variation: (70 * basePercentageNumber / 100), pricePercentage: (60 * basePercentageNumber / 100) }));
	}
	
	function purchaseCount(address buyer) public constant returns (uint256) {
		return purchase[buyer].length;
	}
	
	function matchPriceCount(uint64 index) public constant returns (uint256) {
		return matchPrice[index].length;
	}
	
	function matchPriceValue(uint64 index, uint256 position) public constant returns (uint256, uint256) {
		return (matchPrice[index][position].variation, matchPrice[index][position].pricePercentage);
	}
	
	function locked(address from) public constant returns (uint256) {
		return escrowed[from];
	}
	
	function getPortfolio(uint256 identifier) public constant returns (address, uint256, uint256, uint64, uint64, bool, string) {
		return (portfolio[identifier].owner, 
				portfolio[identifier].projection, 
				portfolio[identifier].price, 
				portfolio[identifier].period, 
				portfolio[identifier].cliff,
				portfolio[identifier].enabled, 
				portfolio[identifier].distribution);
	}
	
	function getLastPurchaseIndex(address buyer, uint256 identifier) public constant returns (bool, uint256) {
		uint256 count = purchaseCount(buyer);
		uint256 index;
		bool found = false;
		for (index = count - 1; index >= 0; index--) {
			if (purchase[buyer][index].identifier == identifier) {
			    found = true;
				break;
			}
		}
		return (found, index);
	}
	
	function getPurchaseByIndex(address buyer, uint256 index) public constant returns (uint256, uint256, uint64, uint64, uint64, uint256, bool, uint64) {
		uint256 count = purchaseCount(buyer);
		if (index < count) {
		    Purchase storage selectedPurchase = purchase[buyer][index];
			return (selectedPurchase.identifier, 
					selectedPurchase.price, 
					selectedPurchase.period, 
					selectedPurchase.cliff, 
					selectedPurchase.matchPriceIndex, 
					selectedPurchase.datetime,
					selectedPurchase.finished,
					selectedPurchase.paymentPeriod);
		} else {
			return (0, 0, 0, 0, 0, 0, false, 0);
		}
	}
	
	function getPurchasePerformedValue(address buyer, uint256 index, uint64 paymentPeriod) public constant returns (int256) {
		return purchase[buyer][index].performedValue[paymentPeriod];
	}
	
	function tokenFallback(address from, uint256 value, bytes) public {
		require(msg.sender == auctusAlphaToken);
		escrowed[from] = escrowed[from].add(value);
	}
	
	function changeAdmin(address newAdmin) onlyAdmin public {
        admin = newAdmin;
    }
	
	function changeValidateEscrow(bool validate) onlyAdmin public {
        toValidateEscrow = validate;
		ValidateEscrow(validate);
    }
	
	function forcedRedeem(address to, uint256 value) onlyAdmin public {
        require(value <= locked(to));
		assert(AuctusAlphaToken(auctusAlphaToken).transfer(to, value));
    }
	
	function updateMatchPrice(uint256[2][] newMatchPrice) onlyAdmin public {
        currentMatchPriceIndex = currentMatchPriceIndex + 1;
        for (uint256 index = 0; index < newMatchPrice.length; index++) {
            matchPrice[currentMatchPriceIndex].push(MatchPrice({ variation: newMatchPrice[index][0], pricePercentage: newMatchPrice[index][1] }));
        }
    }
	
	function createPortfolio(
		address manager, 
		uint256 identifier, 
		uint256 projection, 
		uint256 price, 
		uint64 period, 
		uint64 cliff, 
		string hashDistribution
	) 
		onlyAdmin 
		public 
	{
		internalCreatePortfolio(manager, identifier, projection, price, period, cliff, hashDistribution);
	}
	
	function updatePortfolio(
		uint256 identifier, 
		uint256 price, 
		uint64 period, 
		uint64 cliff,
		bool enabled
	) public {
		require(portfolio[identifier].owner != address(0));
		require(portfolio[identifier].owner == msg.sender || msg.sender == admin);
		
		updatePortfolio(identifier, price, period, cliff, enabled);
	}
	
	function updateDistribution(uint256 identifier, string hashDistribution) public {
		require(portfolio[identifier].owner != address(0));
		require(portfolio[identifier].owner == msg.sender || msg.sender == admin);
		
		internalUpdateDistribution(identifier, hashDistribution);
	}
	
	function createPortfolio(
		uint256 identifier, 
		uint256 projection, 
		uint256 price, 
		uint64 period, 
		uint64 cliff,
		string hashDistribution
	) public {
		internalCreatePortfolio(msg.sender, identifier, projection, price, period, cliff, hashDistribution);
	}

	function purchasePortfolio(uint256 identifier) public {
		require(portfolio[identifier].owner != address(0));
		require(portfolio[identifier].owner != msg.sender);
		require(portfolio[identifier].enabled);
		validateEscrow(msg.sender);
		
		var (found, index) = getLastPurchaseIndex(msg.sender, identifier);
		require(!found || purchase[msg.sender][index].finished);
		
		uint256 price = portfolio[identifier].price;
		uint64 period = portfolio[identifier].period;
		uint64 cliff = portfolio[identifier].cliff;
		uint64 matchPriceIndex = currentMatchPriceIndex;
		uint256 datetime = now;
		purchase[msg.sender].push(Purchase({
			identifier: identifier, 
			price: price, 
			period: period, 
			cliff: cliff, 
			matchPriceIndex: matchPriceIndex, 
			datetime: datetime, 
			finished: false,
			paymentPeriod: 0}));
		
		assert(AuctusAlphaToken(auctusAlphaToken).transfer(this, price));
		
		MakePurchase(msg.sender, identifier, price, period, cliff, matchPriceIndex, datetime);
	}
	
	function matchPurchase(
		address buyer, 
		uint256 identifier, 
		int256 performedValue
	) 
		onlyAdmin 
		public 
	{
		require(portfolio[identifier].owner != address(0));
		
		var (found, index) = getLastPurchaseIndex(buyer, identifier);
		require(found && !purchase[buyer][index].finished);
		
		Purchase storage purchaseToMatch = purchase[buyer][index];
		
		var (dateReference, finished) = getReferenceDateForPayment(purchaseToMatch.period, 
																	purchaseToMatch.cliff, 
																	purchaseToMatch.datetime, 
																	purchaseToMatch.paymentPeriod);	
		require(now >= dateReference);
		
		uint256 expectedValue = getExpectedValue(purchaseToMatch.cliff, portfolio[identifier].projection);
		uint256 priceReference = getReferencePriceForPayment(purchaseToMatch.price, 
															 purchaseToMatch.period, 
															 purchaseToMatch.cliff, 
															 purchaseToMatch.paymentPeriod);
		uint256 buyerCashback = getBuyerCashback(priceReference, expectedValue, performedValue, purchaseToMatch.matchPriceIndex);
												
		uint256 portfolioOwnerPayment = priceReference - buyerCashback;
		escrowed[buyer] = escrowed[buyer].sub(priceReference);
		purchase[buyer][index].finished = finished;
		purchase[buyer][index].paymentPeriod = purchaseToMatch.paymentPeriod + 1;
		purchase[buyer][index].performedValue[purchaseToMatch.paymentPeriod + 1] = performedValue;
		 
		if (portfolioOwnerPayment > 0) {
			assert(AuctusAlphaToken(auctusAlphaToken).transfer(portfolio[identifier].owner, portfolioOwnerPayment));
		}
		if (buyerCashback > 0) {
			assert(AuctusAlphaToken(auctusAlphaToken).transfer(buyer, buyerCashback));
		}
		MatchPurchase(buyer, identifier, purchaseToMatch.paymentPeriod + 1, expectedValue, performedValue, buyerCashback, portfolioOwnerPayment);
	}
	
	function internalCreatePortfolio(
		address manager, 
		uint256 identifier, 
		uint256 projection, 
		uint256 price, 
		uint64 period, 
		uint64 cliff, 
		string hashDistribution
	) private {
		require(portfolio[identifier].owner == address(0));
		require(projection > 0 && price > 0 && period > 0 && cliff > 0 && cliff <= period && bytes(hashDistribution).length > 0);
		validateEscrow(manager);
		
		portfolio[identifier] = Portfolio({
			owner: manager, 
			projection: projection, 
			price: price, 
			period: period, 
			cliff: cliff, 
			enabled: true, 
			distribution: hashDistribution});
			
		CreatePortfolio(identifier, manager, projection, price, period, cliff, hashDistribution);
	}
	
	function internalUpdatePortfolio(
		uint256 identifier, 
		uint256 price, 
		uint64 period, 
		uint64 cliff, 
		bool enabled
	) private {
		require(price > 0 && period > 0 && cliff > 0 && cliff <= period);
		validateEscrow(portfolio[identifier].owner);
		
		portfolio[identifier].price = price;
		portfolio[identifier].period = period;
		portfolio[identifier].cliff = cliff;
		portfolio[identifier].enabled = enabled;
		UpdatePortfolio(identifier, price, period, cliff, enabled);
	}
	
	function internalUpdateDistribution(uint256 identifier, string hashDistribution) private {
		require(bytes(hashDistribution).length > 0);
		validateEscrow(portfolio[identifier].owner);
		
		portfolio[identifier].distribution = hashDistribution;
		UpdateDistribution(identifier, hashDistribution);
	}
	
	function validateEscrow(address responsible) view private {
		require(!toValidateEscrow || AuctusAlphaEscrow(auctusAlphaEscrow).isValidEscrow(responsible));
	}
	
	function getReferenceDateForPayment( 
		uint64 period, 
		uint64 cliff, 
		uint256 purchaseDate,
		uint64 paymentPeriod
	) 
		private 
		pure 
		returns (uint256, bool) 
	{
		uint256 endTime = (purchaseDate + uint256(period * 86400));
		if (cliff == period) {
			return (endTime, true);
		} else {
			uint256 nextDate = (purchaseDate + uint256(cliff * 86400 * (paymentPeriod + 1)));
			if (nextDate >= endTime) {
				return (endTime, true);
			} else {
				return (nextDate, false);
			}
		}
	}
	
	function getReferencePriceForPayment(
		uint256 price, 
		uint64 period, 
		uint64 cliff, 
		uint64 paymentPeriod
	) 
		private 
		pure 
		returns (uint256) 
	{
		if (cliff == period) {
			return price;
		} else {
			uint256 cliffPrice = price * uint256(cliff) / uint256(period);
			if (price < (cliffPrice * uint256(paymentPeriod + 1))) {
				return (price - (cliffPrice * uint256(paymentPeriod)));
			} else {
				return cliffPrice;
			}
		}
	}
	
	function getExpectedValue(uint64 period, uint256 dailyProjection) private constant returns (uint256) {
		uint256 expectedValue = 1;
		for (uint64 i = 0; i < period; i++) {
			expectedValue = ((expectedValue * basePercentageNumber) + (expectedValue * dailyProjection)) / basePercentageNumber; 
		}
		return (expectedValue - 1) * basePercentageNumber;	
	}
	
	function getBuyerCashback(
		uint256 price, 
		uint256 expectedValue, 
		int256 performedValue,
		uint64 matchPriceIndex
	) 
		private 
		constant 
		returns (uint256) 
	{
		if (performedValue <= 0) {
			return price;
		} else if (expectedValue <= uint256(performedValue)) {
			return 0;
		} else {
			uint256 count = matchPriceCount(matchPriceIndex);
			uint256 percentage = 0;
			for (uint256 index = 0; index < count; index++) {
				if ((matchPrice[matchPriceIndex][index].pricePercentage > percentage) &&
					((expectedValue * matchPrice[matchPriceIndex][index].variation / basePercentageNumber) <= uint256(performedValue))) {
					percentage = matchPrice[matchPriceIndex][index].pricePercentage;
				}
			}
			if (percentage == 0) {
				return price;
			} else {
				return (price * percentage / basePercentageNumber);
			}
		}
	}
}