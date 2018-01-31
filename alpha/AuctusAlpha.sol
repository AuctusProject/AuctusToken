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
		bool enabled;
		string distribution;
	}
	
	struct Purchase {
		uint256 identifier;
		uint256 price;
		uint64 period;
		uint256 datetime;
		bool matched;
		int256 performedValue;
	}
	
	address public admin;
	bool public toValidateEscrow;

	address public auctusAlphaToken = 0x0;
	address public auctusAlphaEscrow = 0x0;
	
	mapping(uint256 => Portfolio) internal portfolio;
	mapping(address => Purchase[]) internal purchase;
	mapping(address => uint256) internal escrowed;
	
	event CreatePortfolio(uint256 indexed portfolio, address indexed owner, uint256 projection, uint256 price, uint64 period, string distribution);
	event UpdatePortfolio(uint256 indexed portfolio, uint256 price, uint64 period, bool enabled);
	event UpdateDistribution(uint256 indexed portfolio, string distribution);
	event MakePurchase(address indexed buyer, uint256 indexed portfolio, uint256 price, uint64 period, uint256 datetime);
	event MatchPurchase(address indexed buyer, uint256 indexed portfolio, int256 performedValue, uint256 buyerCashback, uint256 portfolioOwnerPayment);
	event ValidateEscrow(bool indexed validate);
	
	modifier onlyAdmin() {
        require(msg.sender == admin);
		_;
    }
	
	function AuctusAlpha() public {
		admin = msg.sender;
		toValidateEscrow = true;
	}
	
	function getPortfolio(uint256 identifier) public constant returns (address, uint256, uint256, uint64, bool, string) {
		return (portfolio[identifier].owner, 
				portfolio[identifier].projection, 
				portfolio[identifier].price, 
				portfolio[identifier].period, 
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
	
	function getPurchaseByIndex(address buyer, uint256 index) public constant returns (uint256, uint256, uint64, uint256, bool, int256) {
		uint256 count = purchaseCount(buyer);
		if (index < count) {
			return (purchase[buyer][index].identifier, 
					purchase[buyer][index].price, 
					purchase[buyer][index].period, 
					purchase[buyer][index].datetime,
					purchase[buyer][index].matched,
					purchase[buyer][index].performedValue);
		} else {
			return (0, 0, 0, 0, false, 0);
		}
	}
	
	function purchaseCount(address buyer) public constant returns (uint256) {
		return purchase[buyer].length;
	}
	
	function locked(address from) public constant returns (uint256) {
		return escrowed[from];
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
	
	function createPortfolio(
		address manager, 
		uint256 identifier, 
		uint256 projection, 
		uint256 price, 
		uint64 period, 
		string hashDistribution
	) 
		onlyAdmin 
		public 
	{
		internalCreatePortfolio(manager, identifier, projection, price, period, hashDistribution);
	}
	
	function updatePortfolio(
		uint256 identifier, 
		uint256 price, 
		uint64 period, 
		bool enabled
	) public {
		require(portfolio[identifier].owner != address(0));
		require(portfolio[identifier].owner == msg.sender || msg.sender == admin);
		
		updatePortfolio(identifier, price, period, enabled);
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
		string hashDistribution
	) public {
		internalCreatePortfolio(msg.sender, identifier, projection, price, period, hashDistribution);
	}
	
	function purchasePortfolio(uint256 identifier) public {
		require(portfolio[identifier].owner != address(0));
		require(portfolio[identifier].owner != msg.sender);
		require(portfolio[identifier].enabled);
		validateEscrow(msg.sender);
		
		var (found, index) = getLastPurchaseIndex(msg.sender, identifier);
		require(!found || purchase[msg.sender][index].matched);
		
		uint256 price = portfolio[identifier].price;
		uint64 period = portfolio[identifier].period;
		uint256 datetime = now;
		purchase[msg.sender].push(Purchase(identifier, price, period, datetime, false, 0));
		
		assert(AuctusAlphaToken(auctusAlphaToken).transfer(this, price));
		
		MakePurchase(msg.sender, identifier, price, period, datetime);
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
		require(found && !purchase[buyer][index].matched);
		require(now >= (purchase[buyer][index].datetime + uint256(purchase[buyer][index].period * 86400)));
		
		uint256 buyerCashback = getBuyerCashback(purchase[buyer][index].price, purchase[buyer][index].period, portfolio[identifier].projection, performedValue);
		uint256 portfolioOwnerPayment = purchase[buyer][index].price.sub(buyerCashback);
		escrowed[buyer] = escrowed[buyer].sub(purchase[buyer][index].price);
		purchase[buyer][index].matched = true;
		purchase[buyer][index].performedValue = performedValue;
		 
		if (portfolioOwnerPayment > 0) {
			assert(AuctusAlphaToken(auctusAlphaToken).transfer(portfolio[identifier].owner, portfolioOwnerPayment));
		}
		if (buyerCashback > 0) {
			assert(AuctusAlphaToken(auctusAlphaToken).transfer(buyer, buyerCashback));
		}
		MatchPurchase(buyer, identifier, performedValue, buyerCashback, portfolioOwnerPayment);
	}
	
	function internalCreatePortfolio(
		address manager, 
		uint256 identifier, 
		uint256 projection, 
		uint256 price, 
		uint64 period, 
		string hashDistribution
	) private {
		require(portfolio[identifier].owner == address(0));
		require(projection > 0 && price > 0 && period > 0 && bytes(hashDistribution).length > 0);
		validateEscrow(manager);
		
		portfolio[identifier] = Portfolio(manager, projection, price, period, true, hashDistribution);
		CreatePortfolio(identifier, manager, projection, price, period, hashDistribution);
	}
	
	function internalUpdatePortfolio(
		uint256 identifier, 
		uint256 price, 
		uint64 period, 
		bool enabled
	) private {
		require(price > 0 && period > 0);
		validateEscrow(portfolio[identifier].owner);
		
		portfolio[identifier].price = price;
		portfolio[identifier].period = period;
		portfolio[identifier].enabled = enabled;
		UpdatePortfolio(identifier, price, period, enabled);
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
	
	function getBuyerCashback(uint256 price, uint64 period, uint256 dailyProjection, int256 performedValue) private pure returns (uint256) {
		if (performedValue <= 0) {
			return price;
		} else {
			uint256 expectedValue = 1;
			for (uint64 i = 0; i < period; i++) {
				expectedValue = expectedValue + ((expectedValue * dailyProjection) / 100); 
			}
			expectedValue = (expectedValue - 1) * 100;
			if (expectedValue <= uint256(performedValue)) {
				return 0;
			} else if (expectedValue <= (uint256(performedValue * 105) / 100)) {
				return price * 10 / 100;
			} else if (expectedValue <= (uint256(performedValue * 120) / 100)) {
				return price * 30 / 100;
			} else if (expectedValue <= (uint256(performedValue * 135) / 100)) {
				return price * 50 / 100;
			} else if (expectedValue <= (uint256(performedValue * 150) / 100)) {
				return price * 70 / 100;
			} else  {
				return price;
			}
		}
	}
}