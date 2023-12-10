    // SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-v0.7/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-v0.7/math/SafeMath.sol";
import "@openzeppelin/contracts-v0.7/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

import "./ChainlinkMock.sol";
import "./Constants.sol";


interface ChainlinkVRF {
    function requestRandomness(bytes32 keyHash, uint256 fee) external returns (bytes32 requestId);
    function getPrice(bytes32 requestId) external returns (uint256);
}

pragma experimental ABIEncoderV2;
contract ConstellationCore is Ownable {
    using SafeMath for uint256;
    using Constants for *;
    //using Constants for address;

    // ConstellationCore

    ConfigResponse public config;
    //mapping(uint256 => Data) public options;
     // Mapping to store option data by ID
    mapping(uint256 => Data) public optionList;

    // Struct to store option data
    struct Data {
        address creator;
        address owner;
        address collateralToken;
        uint256 collateralAmount;
        uint256[] counterOffer;
        Constants.OptionStatus status;
        uint256[] price;
        uint256 expires;
        uint256 units;
    }

    // Struct to store collateral data
    struct Collateral {
        uint256 totalCollateral;
        uint256 totalPremium;
        uint256 units;
    }

    // Struct to store config response
    struct ConfigResponse {
        address creator;
        uint256 totalOptionsNum;
    }

    // Event emitted when a new option is created
    event OptionCreated(
        uint256 id,
        address indexed owner,
        address creator,
        address collateralToken,
        uint256 collateralAmount,
        uint256 counterOffer,
        uint256 expires,
        uint256 maxUnits
    );


   

    // Mapping to store option data by creator and ID
    mapping(address => mapping(uint256 => Data)) public creatorList;

    // Mapping to store option data by owner and ID
    mapping(address => mapping(uint256 => Data)) public ownerList;

    // Mapping to store market data by ID
    mapping(uint256 => Data) public marketList;

    // Mapping to store collateral data by ID
    mapping(uint256 => Collateral) public collateralList;

    // Mapping to store bids by option ID and bidder address
    mapping(uint256 => mapping(address => uint256)) public bids;

    // Mapping to store offers by option ID and offerer address
    mapping(uint256 => mapping(address => uint256)) public offers;

    // Mapping to store price requests by request ID
    mapping(bytes32 => uint256) public priceRequests;

    // Mapping to store user bids by address
    mapping(address => uint256) public userBids;

    // Mapping to store collateral limit by option ID
    mapping(uint256 => uint256) public collateralLimit;

    // Mapping to store user bid count by address
    mapping(address => uint256) public userBidCount;

    // Mapping to store price to bidder address by option and price ID
    mapping(uint256 => mapping(uint256 => address)) public priceToBidder;

    // Mapping to store price to offerer address by option and price ID
    mapping(uint256 => mapping(uint256 => address)) public priceToOfferer;



    //ConfigResponse public config;
    Data public data;

    uint256 public bufferTime;
    uint256 public bidDuration;
    uint256 public offerDuration;
    uint256 public gracePeriod;
    uint256 public minBidDuration;
    uint256 public minBidAmount;
    uint256 public minOfferDuration;
    uint256 public baseExpiration;
    uint256 public expirationIncreaseFactor;
    uint256 public staleBidRemoveThreshold;
    uint256 public maxBidsPerUser;
    uint256 public bidResetFee;
    uint256 public offerResetFee;
    uint256 public latestPrice;
    address public chainlinkOracle;
    uint256 public gasLimit = 200000;
    bool public paused;

     ChainlinkMock public chainlinkMock;

    // ChainlinkMock public chainlinkMock; // Commented out for now as ChainlinkMock is not provided

     modifier onlyOptionOwner(uint256 id) {
        require(optionList[id].owner == msg.sender, "Unauthorized: Only option owner can call this function");
        _;
    }

    modifier onlyValidTime(uint256 expires) {
        require(block.timestamp < expires, "Invalid time: Option expiration time must be in the future");
        _;
    }

    modifier onlyValidAmount(uint256 amount) {
        require(amount > 0, "Invalid amount: Amount must be greater than zero");
        _;
    }

    modifier gasLimitNotExceeded() {
        require(gasleft() > 200000, "Gas limit exceeded");
        _;
    }

        // Add the requested modifiers
    modifier onlyCreator() {
        require(msg.sender == config.creator, "Unauthorized: Only creator can call this function");
        _;
    }

    modifier onlyIfNotExpired(uint256 id) {
        require(optionList[id].expires > block.timestamp, "Option expired");
        _;
    }

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Invalid address: Address cannot be zero");
        _;
    }

    modifier onlyIfNotOnSale(uint256 id) {
        require(optionList[id].status != Constants.OptionStatus.OnSale, "Option already on sale");
        _;
    }

    modifier onlyIfOnSale(uint256 id) {
        require(optionList[id].status == Constants.OptionStatus.OnSale, "Option not on sale");
        _;
    }

    modifier onlyIfPaused() {
        require(paused, "Contract is not paused");
        _;
    }

    modifier onlyIfNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier onlyIfNotZeroAddress(address addr) {
        require(addr != address(0), "Invalid address: Address cannot be zero");
        _;
    }

    modifier onlyIfZeroAddress(address addr) {
        require(addr == address(0), "Invalid address: Address must be zero");
        _;
    }

    modifier onlyValidPrice(uint256[] memory price) {
        require(price.length > 0, "Invalid price: Price must have at least one element");
        _;
    }

    modifier onlyIfCallerIs(address caller, address expected) {
        require(caller == expected, "Unauthorized: Caller is not the expected address");
        _;
    }

    modifier onlyValidUnit(uint256 unit) {
        require(unit > 0, "Invalid unit: Unit must be greater than zero");
        _;
    }

    modifier onlyIfValidToken(address token) {
        require(token != address(0) && IERC20(token).totalSupply() > 0, "Invalid token: Token does not exist");
        _;
    }

    modifier onlyIfValidCollateralAmount(uint256 amount, uint256[] memory counterOffer) {
        require(amount > 0 || (counterOffer.length > 0 && counterOffer[0] > 0), "Invalid amount: Collateral amount must be greater than zero");
        _;
    }

    modifier onlyIfValidId(uint256 id) {
        require(id > 0 && id <= config.totalOptionsNum, "Invalid ID: Option ID does not exist");
        _;
    }

    modifier onlyIfValidBidAmount(uint256 amount) {
        require(amount >= minBidAmount, "Invalid bid amount: Bid amount is below the minimum allowed");
        _;
    }

    modifier onlyIfValidBidDuration(uint256 duration) {
        require(duration >= minBidDuration, "Invalid bid duration: Bid duration is below the minimum allowed");
        _;
    }

    modifier onlyIfValidOfferDuration(uint256 duration) {
        require(duration >= minOfferDuration, "Invalid offer duration: Offer duration is below the minimum allowed");
        _;
    }

    modifier onlyIfValidExpiration(uint256 expires) {
        require(expires > baseExpiration, "Invalid expiration: Expiration must be greater than base expiration");
        _;
    }

    modifier onlyIfValidOracleData(uint256[] memory oracleData) {
        require(oracleData.length > 0, "Invalid oracle data: Oracle data must have at least one element");
        _;
    }

    modifier onlyIfStaleBidRemoveThresholdSet() {
        require(staleBidRemoveThreshold > 0, "Invalid stale bid remove threshold: Threshold must be greater than zero");
        _;
    }

    modifier onlyIfMaxBidsPerUserSet() {
        require(maxBidsPerUser > 0, "Invalid max bids per user: Max bids per user must be greater than zero");
        _;
    }

    modifier onlyIfBidResetFeeSet() {
        require(bidResetFee > 0, "Invalid bid reset fee: Bid reset fee must be greater than zero");
        _;
    }

    modifier onlyIfOfferResetFeeSet() {
        require(offerResetFee > 0, "Invalid offer reset fee: Offer reset fee must be greater than zero");
        _;
    }

    modifier onlyIfChainlinkOracleSet() {
        require(chainlinkOracle != address(0), "Invalid Chainlink Oracle address: Address cannot be zero");
        _;
    }

    modifier onlyIfChainlinkOracleNotSet() {
        require(chainlinkOracle == address(0), "Chainlink Oracle address already set");
        _;
    }

    modifier onlyIfNotChainlinkOracle(address oracle) {
        require(oracle != chainlinkOracle, "Invalid Oracle address: Chainlink Oracle cannot be set as the main Oracle");
        _;
    }

    modifier onlyIfGasLimitSet() {
        require(gasLimit > 0, "Invalid gas limit: Gas limit must be greater than zero");
        _;
    }

    modifier onlyIfInvalidOracleData(uint256[] memory oracleData) {
        require(oracleData.length == 0, "Invalid oracle data: Oracle data must be empty");
        _;
    }

    modifier onlyIfInvalidBidResetFee(uint256 fee) {
        require(fee == 0, "Invalid bid reset fee: Bid reset fee must be zero");
        _;
    }

    modifier onlyIfInvalidOfferResetFee(uint256 fee) {
        require(fee == 0, "Invalid offer reset fee: Offer reset fee must be zero");
        _;
    }

    modifier onlyIfInvalidBidWithdrawAmount(uint256 amount) {
        require(amount == 0, "Invalid bid withdraw amount: Bid withdraw amount must be zero");
        _;
    }

    modifier onlyIfInvalidOfferWithdrawAmount(uint256 amount) {
        require(amount == 0, "Invalid offer withdraw amount: Offer withdraw amount must be zero");
        _;
    }

    modifier onlyIfInvalidPartialBidWithdrawAmount(uint256 amount) {
        require(amount == 0, "Invalid partial bid withdraw amount: Partial bid withdraw amount must be zero");
        _;
    }

    modifier onlyIfInvalidOfferPlaced(uint256 id) {
        require(bids[id][msg.sender] == 0, "Invalid offer placed: Bidder already placed a bid");
        _;
    }

    modifier onlyIfInvalidBidPlaced(uint256 id) {
        require(offers[id][msg.sender] == 0, "Invalid bid placed: Offerer already placed an offer");
        _;
    }

    modifier onlyIfInvalidBidWithdrawn(uint256 id) {
        require(bids[id][msg.sender] > 0, "Invalid bid withdrawn: Bidder did not place a bid");
        _;
    }

    modifier onlyIfInvalidOfferWithdrawn(uint256 id) {
        require(offers[id][msg.sender] > 0, "Invalid offer withdrawn: Offerer did not place an offer");
        _;
    }

    modifier onlyIfInvalidPartialBidWithdrawn(uint256 id) {
        require(bids[id][msg.sender] > 0, "Invalid partial bid withdrawn: Bidder did not place a bid");
        _;
    }

    modifier onlyIfInvalidTimeBufferSet(uint256 duration) {
        require(duration > 0, "Invalid time buffer set: Time buffer must be greater than zero");
        _;
    }

    modifier onlyIfInvalidBidDurationExtended(uint256 additionalDuration) {
        require(additionalDuration > 0, "Invalid bid duration extension: Additional duration must be greater than zero");
        _;
    }

    modifier onlyIfInvalidOfferDurationExtended(uint256 additionalDuration) {
        require(additionalDuration > 0, "Invalid offer duration extension: Additional duration must be greater than zero");
        _;
    }

    modifier onlyIfInvalidBidReset(uint256 id) {
        require(bids[id][msg.sender] == 0, "Invalid bid reset: Bidder already placed a bid");
        _;
    }

    modifier onlyIfNotZero(uint256[] memory array) {
        require(array.length > 0, "Invalid array: Array cannot be empty");
        _;
    }

    modifier onlyValidFraction(uint256 units, uint256 maxUnits) {
        require(units > 0 && units <= maxUnits, "Invalid fraction: Units must be greater than zero and less than or equal to maxUnits");
        _;
    }

    modifier onlyValidCounterOffer(uint256 counterOffer) {
        require(counterOffer > 0, "Invalid counter offer: Counter offer must be greater than zero");
        _;
    }

    modifier onlyIfNotStale(uint256 id) {
        require(block.timestamp < optionList[id].expires, "Stale bid/offer");
        _;
    }

    modifier onlyIfNotActive(uint256 id) {
        require(block.timestamp < optionList[id].expires.add(gracePeriod), "Active bid/offer");
        // Additional logic if needed for the existing onlyIfNotActive implementation
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Contract is not paused");
        _;
    }

    
    function createOption(uint256[] calldata counterOffer, uint256 expires, address collateralToken, uint256 collateralAmount, uint256 maxUnits) external returns (uint256) {
            // Input validation and collateral transfer
            _validateAndTransferCollateral(expires, collateralToken, collateralAmount);

            // Set expires with bufferTime
            expires = expires.add(bufferTime);

            // Create option
            uint256 id = _createOption(counterOffer, expires, collateralToken, collateralAmount, maxUnits);

            // Emit event
            emit Constants.OptionCreated(id, msg.sender, collateralToken, collateralAmount, counterOffer[0], expires, maxUnits);

            return id;
        }

        function _validateAndTransferCollateral(uint256 expires, address collateralToken, uint256 collateralAmount) internal {
            // Input validation
            require(block.timestamp < expires, "Invalid time: Option expiration time must be in the future");
            require(collateralAmount > 0, "Invalid collateral amount: Collateral amount must be greater than zero");

            // Transfer collateral and approve
            _transferCollateral(collateralToken, collateralAmount);
        }

        function _transferCollateral(address collateralToken, uint256 collateralAmount) internal {
            require(IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount), "Transfer failed");
            require(IERC20(collateralToken).approve(address(this), collateralAmount), "Approval failed");
        }

        function _createOption(uint256[] memory counterOffer, uint256 expires, address collateralToken, uint256 collateralAmount, uint256 maxUnits) internal returns (uint256 id) {
            // Create option logic
            id = config.totalOptionsNum;

            Data memory newOption = Data({
                creator: msg.sender,
                owner: msg.sender,
                collateralToken: collateralToken,
                collateralAmount: collateralAmount,
                counterOffer: counterOffer,
                status: Constants.OptionStatus.Created,
                price: new uint256[](0),
                expires: expires,
                units: maxUnits
            });

            optionList[id] = newOption;
            creatorList[msg.sender][id] = newOption;
            ownerList[msg.sender][id] = newOption;

            Collateral memory newCollateral = Collateral({
                totalCollateral: collateralAmount,
                totalPremium: 0,
                units: maxUnits
            });

            collateralList[id] = newCollateral;

            // Set collateral limit based on collateral deposited
            collateralLimit[id] = collateralAmount;

            config.totalOptionsNum++;

            return id;
        }

        function transferOption(uint256 id, address to) external 
            onlyOptionOwner(id) 
            onlyValidTime(optionList[id].expires) 
            onlyValidAddress(to) 
            gasLimitNotExceeded {
            delete ownerList[msg.sender][id];

            optionList[id].owner = to;

            ownerList[to][id] = optionList[id];

            emit Constants.OptionTransfered(id, msg.sender, to);
        }
        
        function addToMarket(uint256 id, uint256[] calldata toAddPrice) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires) onlyIfNotOnSale(id) onlyIfNotExpired(id) onlyIfNotZero(toAddPrice) gasLimitNotExceeded {
            optionList[id].status = Constants.OptionStatus.OnSale;
            optionList[id].price = toAddPrice;

            // Convert calldata to memory array
            uint256[] memory toAddPriceMemory = new uint256[](toAddPrice.length);
            for (uint256 i = 0; i < toAddPrice.length; i++) {
                toAddPriceMemory[i] = toAddPrice[i];
            }

            marketList[id] = optionList[id];

            emit Constants.OptionListed(id, msg.sender, toAddPriceMemory);
        }

        function requestPriceData(uint256 id, string calldata denom, uint256 expirationTime) external onlyOptionOwner(id) {
            require(chainlinkOracle != address(0), "Chainlink oracle address not set");
            bytes32 requestId = ChainlinkVRF(chainlinkOracle).requestRandomness(keccak256(abi.encodePacked(id, denom)), 1 ether);
            priceRequests[requestId] = block.timestamp.add(expirationTime);

            emit Constants.PriceDataRequested(id, denom, expirationTime, requestId);
        }

        /*function addToMarketChainlink(uint256 id, uint256 amount, string memory denom) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires) onlyValidAmount(amount) gasLimitNotExceeded onlyIfNotOnSale(id) {
            optionList[id].status = OptionStatus.OnSale;
            optionList[id].price = new uint256[](1);

            // Request latest price data for the market option
            requestPriceData(id, denom, 1 days);

            marketList[id] = optionList[id];

            emit OptionListed(id, msg.sender, optionList[id].price);
        }*/

        function removeFromMarket(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
            require(optionList[id].status == Constants.OptionStatus.OnSale, "Option not on sale");

            optionList[id].status = Constants.OptionStatus.Created;
            delete marketList[id];

            emit Constants.OptionDelisted(id, msg.sender);
        }

        function burnOption(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
            require(optionList[id].status != Constants.OptionStatus.OnSale, "Cannot burn option while on sale");

            // Transfer collateral back to the owner
            require(IERC20(optionList[id].collateralToken).transfer(optionList[id].owner, optionList[id].collateralAmount), "Failed to transfer ERC20 collateral");

            delete ownerList[msg.sender][id];
            delete creatorList[msg.sender][id];
            delete optionList[id];
            delete collateralList[id];
            delete marketList[id];

            emit Constants.OptionBurned(id, msg.sender);
        }

        function claimOption(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
            require(optionList[id].status != Constants.OptionStatus.OnSale, "Cannot claim option while on sale");

            // Transfer collateral to the owner
            require(IERC20(optionList[id].collateralToken).transfer(optionList[id].owner, optionList[id].collateralAmount), "Failed to transfer ERC20 collateral");

            // Transfer premium to the creator
            require(IERC20(optionList[id].collateralToken).transfer(optionList[id].creator, collateralList[id].totalPremium), "Failed to transfer premium");

            delete ownerList[msg.sender][id];
            delete creatorList[msg.sender][id];
            delete optionList[id];
            delete collateralList[id];
            delete marketList[id];

            emit Constants.OptionClaimed(id, msg.sender);
        }

        function executeOption(uint256 id) external onlyValidTime(optionList[id].expires) onlyIfNotExpired(id) onlyIfNotStale(id) gasLimitNotExceeded {
            require(optionList[id].status == Constants.OptionStatus.OnSale, "Option not on sale");

            // Check if the latest price is available
            require(latestPrice > 0, "Latest price not available");

            uint256 totalPrice = 0;
            uint256 optionPrice = 0;

            // Calculate the total price based on the option price and units
            for (uint256 i = 0; i < optionList[id].price.length; i++) {
                totalPrice = totalPrice.add(optionList[id].price[i]);
            }

            // Calculate the option price using the latest price and units
            for (uint256 i = 0; i < optionList[id].counterOffer.length; i++) {
                optionPrice = optionPrice.add(latestPrice.mul(optionList[id].counterOffer[i]).div(optionList[id].units));
            }

            // Check if the option is profitable
            require(optionPrice >= totalPrice, "Option is not profitable");

            // Transfer the collateral to the owner
            require(IERC20(optionList[id].collateralToken).transfer(optionList[id].owner, optionList[id].collateralAmount), "Failed to transfer ERC20 collateral");

            // Transfer the premium to the creator
            require(IERC20(optionList[id].collateralToken).transfer(optionList[id].creator, collateralList[id].totalPremium), "Failed to transfer premium");

            delete ownerList[msg.sender][id];
            delete creatorList[msg.sender][id];
            delete optionList[id];
            delete collateralList[id];
            delete marketList[id];

            emit Constants.OptionExecuted(id, msg.sender, optionPrice, totalPrice);
        }

        function buyOption(uint256 id) external payable onlyIfNotExpired(id) onlyIfNotStale(id) gasLimitNotExceeded {
            require(optionList[id].status == Constants.OptionStatus.OnSale, "Option not on sale");

            uint256 totalPrice = 0;

            // Calculate the total price based on the option price and units
            for (uint256 i = 0; i < optionList[id].price.length; i++) {
                totalPrice = totalPrice.add(optionList[id].price[i]);
            }

            // Check if the sent value matches the total price
            require(msg.value == totalPrice, "Incorrect payment amount");

            // Transfer the collateral to the owner
            require(IERC20(optionList[id].collateralToken).transfer(optionList[id].owner, optionList[id].collateralAmount), "Failed to transfer ERC20 collateral");

            // Transfer the premium to the creator
            require(IERC20(optionList[id].collateralToken).transfer(optionList[id].creator, collateralList[id].totalPremium), "Failed to transfer premium");

            // Transfer the option to the buyer
            delete ownerList[msg.sender][id];
            ownerList[msg.sender][id] = optionList[id];
            optionList[id].owner = msg.sender;
            optionList[id].status = Constants.OptionStatus.Created;

            // Refund excess payment to the buyer
            if (msg.value > totalPrice) {
                payable(msg.sender).transfer(msg.value.sub(totalPrice));
            }

            emit Constants.OptionBought(id, msg.sender, totalPrice);
        }

        function buyOptionChainlink(uint256 id, uint256 units) external payable onlyValidAmount(msg.value) onlyValidTime(optionList[id].expires) gasLimitNotExceeded onlyIfNotExpired(id) onlyValidFraction(units, collateralList[id].units) {
            require(msg.value == latestPrice.mul(units).div(collateralList[id].units), "Price mismatch");

            uint256 totalPrice = 0;

            // Calculate the total price based on the option price and units
            for (uint256 i = 0; i < optionList[id].price.length; i++) {
                totalPrice = totalPrice.add(optionList[id].price[i]);
            }

            // Check if the sent value matches the total price
            require(msg.value == totalPrice, "Incorrect payment amount");

            // Transfer the collateral to the owner
            require(IERC20(optionList[id].collateralToken).transfer(optionList[id].owner, optionList[id].collateralAmount), "Failed to transfer ERC20 collateral");

            // Transfer the premium to the creator
            require(IERC20(optionList[id].collateralToken).transfer(optionList[id].creator, collateralList[id].totalPremium), "Failed to transfer premium");

            // Transfer the option to the buyer
            delete ownerList[msg.sender][id];
            ownerList[msg.sender][id] = optionList[id];
            optionList[id].owner = msg.sender;
            optionList[id].status = Constants.OptionStatus.Created;

            // Refund excess payment to the buyer
            if (msg.value > totalPrice) {
                payable(msg.sender).transfer(msg.value.sub(totalPrice));
            }

            emit Constants.OptionBought(id, msg.sender, totalPrice);
        }

        function cancelOption(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
            require(optionList[id].status == Constants.OptionStatus.OnSale, "Option not on sale");

            delete ownerList[msg.sender][id];
            optionList[id].status = Constants.OptionStatus.Created;
            delete marketList[id];

            emit Constants.OptionCancelled(id, msg.sender);
        }

        function withdrawCollateral(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
            require(optionList[id].status == Constants.OptionStatus.Created, "Cannot withdraw collateral for an active option");

            // Transfer collateral back to the owner
            require(IERC20(optionList[id].collateralToken).transfer(optionList[id].owner, optionList[id].collateralAmount), "Failed to transfer ERC20 collateral");

            delete ownerList[msg.sender][id];
            delete creatorList[msg.sender][id];
            delete optionList[id];
            delete collateralList[id];

            emit Constants.CollateralWithdrawn(id, msg.sender);
        }

            // Function to update the creator address, restricted to the current creator
        function setCreator(address _newCreator) external onlyCreator() {
            require(_newCreator != address(0), "Invalid creator address");
            data.creator = _newCreator;
        }

    // Function to update the creator address, restricted to the current creator
        function setOwner(address _newOwner) external onlyOwner() {
            require(_newOwner != address(0), "Invalid owner address");
            data.owner = _newOwner;
        }

            receive() external payable {
        // Handle incoming Ether
        // You can implement logic here to handle the incoming Ether.
        // For example, you may want to log the sender and the amount received.
        emit Constants.ReceivedEther(msg.sender, msg.value);

        // Optionally, you can perform additional actions or trigger other functions based on the received Ether.

    }



    // Function with onlyCreator modifier
    function functionWithOnlyCreator() external onlyCreator() {
        // Sample logic restricted to the creator
        // For example, let's emit an event when the function is called
        //emit Constants.FunctionWithOnlyCreatorCalled(msg.sender);
    }

    // Function with onlyCreator modifier
    function functionWithonlyOptionOwner(uint256 id) external onlyOptionOwner(id) {
        // Sample logic restricted to the creator
        // For example, let's emit an event when the function is called
        //emit Constants.FunctionWithOnlyOwnerCalled(msg.sender);
    }

    // Helper function with event emission
    function functionWithEvent(uint256 optionId) external {
        // Add your specific logic here
        // For example, emit an event indicating the function was called
        //emit Constants.FunctionWithEventCalled(msg.sender, optionId);
    }

    // Helper function with zero address check
    function functionWithZeroAddress() external view {
        // Add your specific logic here
        // For example, require that the sender is not the zero address
        require(msg.sender != address(0), "Invalid address");
    }

    // Helper function with zero amount check
    function functionWithZeroAmount() external payable {
        // Add your specific logic here
        // For example, require that the sent value is greater than zero
        require(msg.value > 0, "Invalid amount");
    }

    // Helper function with empty array check
    function functionWithEmptyArray(uint256[] calldata functionData) external pure {
        // Add your specific logic here
        // For example, require that the input array is not empty
        require(functionData.length > 0, "Invalid array");
    }

    // Helper function with overflow check
    function functionWithOverflow() external payable {
        // Add your specific logic here
        // For example, ensure that the value sent doesn't cause an overflow
        uint256 maxValue = type(uint256).max;
        require(msg.value <= maxValue, "Value overflow");
    }

    // Helper function exceeding gas limit
    function functionExceedingGasLimit() external view {
        // Add your specific logic here
        // For example, simulate a gas-consuming operation
        uint256 result = 1;
        for (uint256 i = 1; i <= 100000; i++) {
         // Some computation that consumes gas
            result = result * i;
        }
        // Ensure gas limit is not exceeded
        require(gasleft() > 100000, "Gas limit exceeded");
    }

    function executeOptionWithRandomness(bytes32 requestId) external {
        // Check if the random number has been fulfilled for the given requestId
        require(chainlinkMock.latestRandomNumber() > 0, "Random number not fulfilled yet");

        // Use the random number for your specific logic
        uint256 randomNumber = chainlinkMock.latestRandomNumber();

        // Add your specific logic here based on the random number
        // For example, you can use it to determine the outcome of the option execution

        // Emit an event or perform any other necessary actions
        emit Constants.OptionExecuted(requestId, randomNumber);

        // Reset the Chainlink mock state for the next test or execution
        chainlinkMock.resetState();
    }

    function pause() external onlyCreator() whenNotPaused() {
        paused = true;
        // Additional implementation details if needed
    }

    function unpause() external onlyCreator whenPaused() {
        paused = false;
        // Additional implementation details if needed
    }

    function checkOnlyIfNotStale(uint256 id) external view {
        require(block.timestamp < optionList[id].expires, "Stale bid/offer");
        // Additional logic if needed for the existing onlyIfNotStale implementation
    }

    function checkOnlyIfNotActive(uint256 id) external view {
        require(block.timestamp < optionList[id].expires.add(gracePeriod), "Active bid/offer");
        // Additional logic if needed for the existing onlyIfNotActive implementation
    }

    function getTotalBids(uint256 id) internal view returns (uint256) {
        uint256 totalBids = 0;

        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address bidder = priceToBidder[id][optionList[id].price[i]];
            if (bids[id][bidder] > 0) {
                totalBids++;
            }
        }
        
        return totalBids;
    }

    function getTotalOffers(uint256 id) internal view returns (uint256) {
        uint256 totalOffers = 0;

        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address offerer = priceToOfferer[id][optionList[id].price[i]];
            if (offers[id][offerer] > 0) {
                totalOffers++;
            }
        }

        return totalOffers;
    }

    // Getter functions for ConfigResponse fields
    function getCreator() external view returns (address) {
        return config.creator;
    }

    function getTotalOptionsNum() external view returns (uint256) {
        return config.totalOptionsNum;
    }

    //In this modified acceptOffer function, the offererBalance function is used to check whether 
    //the balance of the offerer (lowestOfferer) is sufficient to cover the offer amount (lowestOffer). 
    //This is similar to the bidderBalance function used in the acceptBid function.

    function offererBalance(uint256 id, address account) internal view returns (uint256) {
        // Helper function to get offerer balance
        if (optionList[id].collateralToken == address(0)) {
            return account.balance;
        } else {
            return IERC20(optionList[id].collateralToken).balanceOf(account);
        }
    }

    // Helper function to get bidder balance
    function bidderBalance(uint256 id, address account) internal view returns (uint256) {
        if (optionList[id].collateralToken == address(0)) {
            return account.balance;
        } else {
            return IERC20(optionList[id].collateralToken).balanceOf(account);
        }
    }

    function analyzeActivity(uint256 id) external onlyIfNotExpired(id) {
        
         // Implement the logic for the new analyzeActivity function
        // This function may involve analyzing bids, offers, or other relevant activities and emitting relevant events

        //The below code is a sample
        //It performs a simple analysis to determine whether the market is considered active based on the presence of bids or offers. 
        //The result is emitted as an event (AnalyzeActivity). 

        // Fetch relevant data and perform analysis
        uint256 totalBids = getTotalBids(id);
        uint256 totalOffers = getTotalOffers(id);

        // Perform analysis based on the data
        bool isMarketActive = totalBids > 0 || totalOffers > 0;

        // Emit an event with the analysis result
        emit Constants.AnalyzeActivity(id, isMarketActive ? 1 : 0);
    }
    
    function setMinBidAmount(uint256 id, uint256 _minBidAmount) external onlyOptionOwner(id) {  
        
        minBidAmount = _minBidAmount;
    }

    // Inside the Core contract
    function getMinBidAmount() external view returns (uint256) {
        // Assuming minBidAmount is a mapping, adjust the data structure accordingly
        return minBidAmount;
    }


    // Helper function to get the highest bid amount
    function getHighestBid(uint256 id) external view returns (uint256) {
        uint256 highestBid = 0;

        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address bidder = priceToBidder[id][optionList[id].price[i]];
            uint256 bidAmount = bids[id][bidder];

            if (bidAmount > highestBid) {
                highestBid = bidAmount;
            }
        }
        return highestBid;
    }

    // Helper function to get the lowest offer amount
    function getLowestOffer(uint256 id) external view returns (uint256) {
        uint256 lowestOffer = type(uint256).max; // Initialize with the maximum possible value

        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address offerer = priceToOfferer[id][optionList[id].price[i]];
            uint256 offerAmount = offers[id][offerer];

            if (offerAmount < lowestOffer) {
                lowestOffer = offerAmount;
            }
        }

        return lowestOffer;
    }

    function setTimeBuffer(uint256 id, uint256 buffer) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires) {    
        
        // Set a time buffer before expiry for executions
        optionList[id].expires = optionList[id].expires.add(buffer);

        emit Constants.TimeBufferSet(id, buffer);
    }

    function resetBids(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id)  {
         
        require(block.timestamp > optionList[id].expires.sub(bidDuration), "Bid duration not expired");

        // Delete expired bids
        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address bidder = priceToBidder[id][optionList[id].price[i]];
            delete bids[id][bidder];
        }
        emit Constants.BidReset(id);
    }

    function resetOffers(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id){  
         
        require(block.timestamp > optionList[id].expires.add(minOfferDuration), "Offer duration not expired");

        // Delete expired offers
        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address offerer = priceToOfferer[id][optionList[id].price[i]];
            delete offers[id][offerer];
        }

        emit Constants.OffersReset(id);
    }

    function setGracePeriod(uint256 id, uint256 period) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){
    
        // Set a grace period before resetting bids/offers
        gracePeriod = period;

        emit Constants.GracePeriodSet(id, period);
    }

    function setMinBidDuration(uint256 id, uint256 duration) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires) {
        
        // Set the minimum bid duration
        minBidDuration = duration;

        emit Constants.MinBidDurationSet(id, duration);
    }

    function setMinOfferDuration(uint256 id, uint256 duration) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires) {
         
        // Set the minimum offer duration
        minOfferDuration = duration;

        emit Constants.MinOfferDurationSet(id, duration);
    }

    function setBaseExpiration(uint256 id, uint256 duration) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){  
         
        // Set the base expiration duration
        baseExpiration = duration;

        emit Constants.BaseExpirationSet(id, duration);
    }

    function setExpirationIncreaseFactor(uint256 id, uint256 factor) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){
          
        // Set the exponential backoff factor for expiration
        expirationIncreaseFactor = factor;

        emit Constants.ExpirationIncreaseFactorSet(id, factor);
    }

    function setStaleBidRemoveThreshold(uint256 id, uint256 threshold) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires)  {
         
        // Set the threshold for removing very old stale bids
        staleBidRemoveThreshold = threshold;

        emit Constants.StaleBidRemoveThresholdSet(id, threshold);
    }

    function setMaxBidsPerUser(uint256 id, uint256 maxBids) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){ 
        
        // Set the maximum number of bids per user
        maxBidsPerUser = maxBids;

        emit Constants.MaxBidsPerUserSet(id, maxBids);
    }

    function setBidResetFee(uint256 id, uint256 fee) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){
         
        // Set the fee for resetting bids
        bidResetFee = fee;

        emit Constants.BidResetFeeSet(id, fee);
    }

    function setOfferResetFee(uint256 id, uint256 fee) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){
         
        // Set the fee for resetting offers
        offerResetFee = fee;

        emit Constants.OfferResetFeeSet(id, fee);
    }

    function getConfig() external view returns (address creator, uint256 totalOptionsNum ) {
       // ConfigResponse memory config = config;
       // ConfigResponse memory config = config;
        return (config.creator, config.totalOptionsNum);
    }

    /*function getOption(uint256 id) external view returns (Data memory) {
        return optionList[id];
    }*/

    function getOption(uint256 id) external view returns (
        address creator,
        address owner,
        address collateralToken,
        uint256 collateralAmount,
        uint256[] memory counterOffer,
        Constants.OptionStatus status,
        uint256[] memory price,
        uint256 expires,
        uint256 units 
        ) {
        Data storage option = optionList[id];

        return (
            option.creator,
            option.owner,
            option.collateralToken,
            option.collateralAmount,
            option.counterOffer,
            option.status,
            option.price,
            option.expires,
            option.units
        );
    }

    function isExpired(uint256 id) external view returns (bool) {
        return optionList[id].expires < block.timestamp; 
    }

    function isOnSale(uint256 id) external view returns (bool) {
        return optionList[id].status == Constants.OptionStatus.OnSale;
    }

    function isStale(uint256 id) external view returns (bool) {
        return block.timestamp >= optionList[id].expires;
    }

    function isPaused() external view returns (bool) {
        return paused;
    }

    function isOptionOwner(uint256 id) external view returns (bool) {
        return optionList[id].owner == msg.sender;
    }

    function getBid(uint256 id, address bidder) external view returns (uint256) {
        return bids[id][bidder];
    }

    function getUserBidCount(address user) external view returns (uint256) {
        return userBidCount[user];
    }

    function getMaxBidCount() external view returns (uint256) {
        return maxBidsPerUser;
    }

    function getCollateralLimit(uint256 id) external view returns (uint256) {
        return collateralLimit[id];
    }

    function setBid(uint256 id, address bidder, uint256 value) external {
        bids[id][bidder] = value;
    }

    function incrementUserBidCount(address bidder) external {
        userBidCount[bidder]++;
    }

     function decrementUserBidCount(address bidder) external {
        userBidCount[bidder]--;
    }

    function getMarketList(uint256 id) external view returns (ConstellationCore.Data memory) {
        return marketList[id];
    }

    function getPriceToBidder(uint256 id, uint256 price) external view returns (address) {
        return priceToBidder[id][price];
    }

    function getOffer(uint256 id, address offeror) external view returns (uint256) {
        return offers[id][offeror];
    }

      function setOffer(uint256 id, address offeror, uint256 value) external {
        offers[id][offeror] = value;
    }

    function getPriceToOfferer(uint256 id, uint256 price) external view returns (address) {
        return priceToOfferer[id][price];
    }

   function setPriceToOfferer(uint256 id, uint256 price, address offerer) external {
        priceToOfferer[id][price] = offerer;
    }

}
    
     