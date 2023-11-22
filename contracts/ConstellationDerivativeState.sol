//Contains the globally accessed state that is needed across different contract 
// SPDX-License-Identifier: MIT
//pragma solidity ^0.8.9;
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-v0.7/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-v0.7/math/SafeMath.sol";
import "@openzeppelin/contracts-v0.7/access/Ownable.sol";

import "./ChainlinkMock.sol";

contract ConstellationDerivativeState is Ownable {
    using SafeMath for uint256;

    /*constructor() public{
        data.creator = msg.sender;
        paused = false;
    }*/
    enum OptionStatus { Created, OnSale, Expired }

    struct Data {
        address creator;
        address owner;
        address collateralToken;
        uint256 collateralAmount;
        uint256[] counterOffer;
        OptionStatus status;
        uint256[] price;
        uint256 expires;
        uint256 units;
    }

    struct Collateral {
        uint256 totalCollateral;
        uint256 totalPremium;
        uint256 units;
    }

    struct ConfigResponse {
        address creator;
        uint256 totalOptionsNum;
    }

    mapping(uint256 => Data) public optionList;
    mapping(address => mapping(uint256 => Data)) public creatorList;
    mapping(address => mapping(uint256 => Data)) public ownerList;
    mapping(uint256 => Data) public marketList;
    mapping(uint256 => Collateral) public collateralList;
    mapping(uint256 => mapping(address => uint256)) public bids; // Bid mapping from bidder => bid amount
    mapping(uint256 => mapping(address => uint256)) public offers; // Offer mapping from owner => offer amount
    mapping(bytes32 => uint256) public priceRequests; // Mapping requestId to expiration timestamp
    // Mapping to store bid amounts per user
    mapping(address => uint256) public userBids;
    // Mapping to store collateral limits per option
    mapping(uint256 => uint256) public collateralLimit;
    mapping(address => uint256) public userBidCount;
    // Separate mapping for bids based on price
    mapping(uint256 => mapping(uint256 => address)) public priceToBidder;
    // Separate mapping for offers based on price
    mapping(uint256 => mapping(uint256 => address)) public priceToOfferer;


    ConfigResponse public config;
    Data public data;

    uint256 public bufferTime; // Buffer duration
    uint256 public bidDuration; // Bid duration
    uint256 public offerDuration; // Offer duration
    uint256 public gracePeriod; // Grace period before resetting bids/offers
    uint256 public minBidDuration; // Minimum bid duration
    uint256 public minBidAmount;    // ßMinimum bid amount
    uint256 public minOfferDuration; // Minimum offer duration
    uint256 public baseExpiration; // Base expiration duration
    uint256 public expirationIncreaseFactor; // Exponential backoff factor
    uint256 public staleBidRemoveThreshold; // Threshold for removing very old stale bids
    uint256 public maxBidsPerUser; // Maximum number of bids per user
    uint256 public bidResetFee; // Fee for resetting bids
    uint256 public offerResetFee; // Fee for resetting offers
    uint256 public latestPrice;
    address public chainlinkOracle;
    uint256 public gasLimit = 200000; // Adjust the gas limit as needed
    bool public paused;

    ChainlinkMock public chainlinkMock;

     // Events
    event BidWithdrawn(uint256 indexed id, address bidder, uint256 amount);
    event OfferWithdrawn(uint256 indexed id, address offerer, uint256 amount);
    event BidDurationExtended(uint256 indexed id, uint256 additionalDuration);
    event OfferDurationExtended(uint256 indexed id, uint256 additionalDuration);
    event BidReset(uint256 indexed id);
    event OfferReset(uint256 indexed id);
    event OptionExpired(uint256 indexed id);
    event PriceDataRequested(uint256 indexed id, string denom, uint256 expirationTime, bytes32 requestId);    
    event TimeBufferSet(uint256 indexed id, uint256 buffer);
    event BidsReset(uint256 indexed id);
    event OffersReset(uint256 indexed id);
    event GracePeriodSet(uint256 indexed id, uint256 period);
    event MinBidDurationSet(uint256 indexed id, uint256 duration);
    event MinOfferDurationSet(uint256 indexed id, uint256 duration);
    event BaseExpirationSet(uint256 indexed id, uint256 duration);
    event ExpirationIncreaseFactorSet(uint256 indexed id, uint256 factor);
    event StaleBidRemoveThresholdSet(uint256 indexed id, uint256 threshold);
    event MaxBidsPerUserSet(uint256 indexed id, uint256 maxBids);
    event BidResetFeeSet(uint256 indexed id, uint256 fee);
    event OfferResetFeeSet(uint256 indexed id, uint256 fee);
    event ReceivedEther(address bidder, uint256 value);
    // Event for the new resetBids function
    event NewResetBids(uint256 indexed id);
    // Event for the new withdrawBid function
    event WithdrawBid(uint256 indexed id, address indexed bidder, uint256 refundedAmount);
    // Event for the new analyzeActivity function
    event AnalyzeActivity(uint256 indexed id, uint256 result);
    // Event for the new extendBidDuration function
    event ExtendBidDuration(uint256 indexed id, uint256 newExpiration);
    // Event for the new extendOfferDuration function
    event ExtendOfferDuration(uint256 indexed id, uint256 newExpiration);
    // Event to log when the functionWithOnlyCreator is called
    event FunctionWithOnlyCreatorCalled(address indexed caller);
    // Event to log when the functionWithOnlyCreator is called
    event FunctionWithOnlyOwnerCalled(address indexed caller);
     // Event to log when the functionWithEvent is called
    event FunctionWithEventCalled(address indexed sender, uint256 indexed id);
    event OptionCreated(uint256 id, address indexed owner, address creator, address collateralToken, uint256 collateralAmount, 
        uint256 counterOffer,
        uint256 expires,
        uint256 maxUnits);
    event OptionTransferred(uint256 id, address indexed from, address indexed to);
    event OptionListed(uint256 id, address indexed lister, uint256[] price);
    event OptionDelisted(uint256 id, address indexed delister);
    event OptionBurned(uint256 id, address indexed burner);
    event OptionClaimed(uint256 id, address indexed claimer);
    event OptionExecuted(uint256 id, address indexed executor, uint256 optionPrice, uint256 totalPrice);
    event OptionBought(uint256 id, address indexed buyer, uint256 totalPrice);
    event OptionCancelled(uint256 id, address indexed canceller);
    event CollateralWithdrawn(uint256 id, address indexed withdrawer);
    event BidPlaced(uint256 id, address indexed bidder, uint256[] offer);
    event OfferPlaced(uint256 id, address indexed offerer, uint256[] offer);
    event NewBid(uint256 id, address indexed bidder, uint256[] offer, uint256[] oracleData);
    event PartialBidWithdrawn(uint256 id, address indexed withdrawer, uint256 partialAmount);
    event OptionExecuted(bytes32 indexed requestId, uint256 randomNumber);


    modifier onlyCreator() {
        require(msg.sender == config.creator, "Unauthorized: Only creator can call this function");
        _;
    }

    /*modifier onlyOwner() override {  //Test and double check data owner working here
        require(msg.sender == data.owner, "Unauthorized: Only creator can call this function");
        _;
    }*/

    modifier onlyOptionOwner (uint256 id) {
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

    modifier onlyIfNotExpired(uint256 id) {
        require(optionList[id].expires > block.timestamp, "Option expired");
        _;
    }

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Invalid address: Address cannot be zero");
        _;
    }

    modifier onlyIfNotOnSale(uint256 id) {
        require(optionList[id].status != OptionStatus.OnSale, "Option is on sale");
        _;
    }

    modifier onlyValidCounterOffer(uint256 counter) {
        require(counter > 0, "Invalid counter offer: Counter offer must be greater than zero");
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

    modifier onlyIfNotStale(uint256 id) {
        require(block.timestamp < optionList[id].expires, "Stale bid/offer");
        _;
    }

    modifier onlyIfNotActive(uint256 id) {
        require(block.timestamp < optionList[id].expires.add(gracePeriod), "Active bid/offer");
        _;
    }

    modifier onlyIfNotStaleOrActive(uint256 id) {
        require(block.timestamp < optionList[id].expires.add(gracePeriod), "Stale bid/offer");
        _;
    }

    modifier onlyIfNotStaleOrActiveOrOnSale(uint256 id) {
        require(block.timestamp < optionList[id].expires.add(gracePeriod), "Stale bid/offer");
        require(optionList[id].status != OptionStatus.OnSale, "Option is on sale");
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


    function instantiate() external onlyCreator() {
        // Initialization logic
    }

     receive() external payable {
        // Handle incoming Ether
        // You can implement logic here to handle the incoming Ether.
        // For example, you may want to log the sender and the amount received.
        emit ReceivedEther(msg.sender, msg.value);

        // Optionally, you can perform additional actions or trigger other functions based on the received Ether.

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

    // Function with onlyCreator modifier
    function functionWithOnlyCreator() external onlyCreator() {
        // Sample logic restricted to the creator
        // For example, let's emit an event when the function is called
        emit FunctionWithOnlyCreatorCalled(msg.sender);
    }

    // Function with onlyCreator modifier
    function functionWithonlyOptionOwner(uint256 id) external onlyOptionOwner(id) {
        // Sample logic restricted to the creator
        // For example, let's emit an event when the function is called
        emit FunctionWithOnlyOwnerCalled(msg.sender);
    }

        // Helper function with event emission
    function functionWithEvent(uint256 optionId) external {
        // Add your specific logic here
        // For example, emit an event indicating the function was called
        emit FunctionWithEventCalled(msg.sender, optionId);
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
        emit OptionExecuted(requestId, randomNumber);

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

        // Helper function to get offerer balance
    
    function offererBalance(uint256 id, address account) internal view returns (uint256) {
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
        emit AnalyzeActivity(id, isMarketActive ? 1 : 0);
    }
    
    function setMinBidAmount(uint256 id, uint256 _minBidAmount) external onlyOptionOwner(id) {  
        
        minBidAmount = _minBidAmount;
    }

        // Helper function to get the highest bid amount
    function getHighestBid(uint256 id) internal view returns (uint256) {
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
    function getLowestOffer(uint256 id) internal view returns (uint256) {
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

        emit TimeBufferSet(id, buffer);
    }


    function resetBids(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id)  {
         
        require(block.timestamp > optionList[id].expires.sub(bidDuration), "Bid duration not expired");

        // Delete expired bids
        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address bidder = priceToBidder[id][optionList[id].price[i]];
            delete bids[id][bidder];
        }
        emit BidReset(id);
    }

    function resetOffers(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id){  
         
        require(block.timestamp > optionList[id].expires.add(minOfferDuration), "Offer duration not expired");

        // Delete expired offers
        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address offerer = priceToOfferer[id][optionList[id].price[i]];
            delete offers[id][offerer];
        }

        emit OffersReset(id);
    }

    function setGracePeriod(uint256 id, uint256 period) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){
    
        // Set a grace period before resetting bids/offers
        gracePeriod = period;

        emit GracePeriodSet(id, period);
    }

    function setMinBidDuration(uint256 id, uint256 duration) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires) {
        
        // Set the minimum bid duration
        minBidDuration = duration;

        emit MinBidDurationSet(id, duration);
    }

    function setMinOfferDuration(uint256 id, uint256 duration) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires) {
         
        // Set the minimum offer duration
        minOfferDuration = duration;

        emit MinOfferDurationSet(id, duration);
    }

    function setBaseExpiration(uint256 id, uint256 duration) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){  
         
        // Set the base expiration duration
        baseExpiration = duration;

        emit BaseExpirationSet(id, duration);
    }

    function setExpirationIncreaseFactor(uint256 id, uint256 factor) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){
          
        // Set the exponential backoff factor for expiration
        expirationIncreaseFactor = factor;

        emit ExpirationIncreaseFactorSet(id, factor);
    }

    function setStaleBidRemoveThreshold(uint256 id, uint256 threshold) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires)  {
         
        // Set the threshold for removing very old stale bids
        staleBidRemoveThreshold = threshold;

        emit StaleBidRemoveThresholdSet(id, threshold);
    }

    function setMaxBidsPerUser(uint256 id, uint256 maxBids) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){ 
        
        // Set the maximum number of bids per user
        maxBidsPerUser = maxBids;

        emit MaxBidsPerUserSet(id, maxBids);
    }

    function setBidResetFee(uint256 id, uint256 fee) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){
         
        // Set the fee for resetting bids
        bidResetFee = fee;

        emit BidResetFeeSet(id, fee);
    }

    function setOfferResetFee(uint256 id, uint256 fee) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires){
         
        // Set the fee for resetting offers
        offerResetFee = fee;

        emit OfferResetFeeSet(id, fee);
    }

    /*In this modified acceptOffer function, the offererBalance function is used to check whether 
    the balance of the offerer (lowestOfferer) is sufficient to cover the offer amount (lowestOffer). 
    This is similar to the bidderBalance function used in the acceptBid function.*/

}