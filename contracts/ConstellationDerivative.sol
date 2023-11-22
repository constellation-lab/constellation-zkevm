//This contract handles the key option operations for creation, transfer, bidding, offering, buying, selling 
// SPDX-License-Identifier: MIT
//pragma solidity ^0.8.9;
pragma solidity ^0.6.8;
pragma solidity --no-strings;



import "@openzeppelin/contracts-v0.7/access/Ownable.sol";
import "@openzeppelin/contracts-v0.7/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-v0.7/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

import "./ConstellationDerivativeState.sol";
import "./ChainlinkMock.sol";


interface ChainlinkVRF {
    function requestRandomness(bytes32 keyHash, uint256 fee) external returns (bytes32 requestId);
    function getPrice(bytes32 requestId) external returns (uint256);
}

contract ConstellationDerivative is ConstellationDerivativeState{
    //using ConstellationDerivativeState for *;
    using SafeMath for uint256;
    
    /*
    ConstellationDerivativeUtils private state;
    ConstellationDerivativeModifiers private modifiers;
    ConstellationDerivativeUtils private utils;
   
    // Constructor to initialize the ChainlinkMock contract
    constructor() public {
        utils = new ConstellationDerivativeState();
        modifiers = new ConstellationDerivativeModifiers();
        utils = new ConstellationDerivativeUtils(); 

    }*/

    function createOption(uint256[] calldata counterOffer, uint256 expires, address collateralToken, uint256 collateralAmount, uint256 maxUnits) external returns (uint256) {
        // Input validation and collateral transfer
        _validateAndTransferCollateral(expires, collateralToken, collateralAmount);

        // Set expires with bufferTime
        expires = expires.add(bufferTime);

        // Create option
        uint256 id = _createOption(counterOffer, expires, collateralToken, collateralAmount, maxUnits);

        // Emit event
        emit OptionCreated(id, msg.sender, msg.sender, collateralToken, collateralAmount, counterOffer[0], expires, maxUnits);

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
            status: OptionStatus.Created,
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



    function transferOption(uint256 id, address to) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires) onlyValidAddress(to) gasLimitNotExceeded {
        delete ownerList[msg.sender][id];

        optionList[id].owner = to;

        ownerList[to][id] = optionList[id];

        emit OptionTransferred(id, msg.sender, to);
    }
    
    function addToMarket(uint256 id, uint256[] calldata toAddPrice) external onlyOptionOwner(id) onlyValidTime(optionList[id].expires) onlyIfNotOnSale(id) onlyIfNotExpired(id) onlyIfNotZero(toAddPrice) gasLimitNotExceeded {
        optionList[id].status = OptionStatus.OnSale;
        optionList[id].price = toAddPrice;

        // Convert calldata to memory array
        uint256[] memory toAddPriceMemory = new uint256[](toAddPrice.length);
        for (uint256 i = 0; i < toAddPrice.length; i++) {
            toAddPriceMemory[i] = toAddPrice[i];
        }

        marketList[id] = optionList[id];

        emit OptionListed(id, msg.sender, toAddPriceMemory);
    }

    function requestPriceData(uint256 id, string calldata denom, uint256 expirationTime) external onlyOptionOwner(id) {
        require(chainlinkOracle != address(0), "Chainlink oracle address not set");
        bytes32 requestId = ChainlinkVRF(chainlinkOracle).requestRandomness(keccak256(abi.encodePacked(id, denom)), 1 ether);
        priceRequests[requestId] = block.timestamp.add(expirationTime);

        emit PriceDataRequested(id, denom, expirationTime, requestId);
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
        require(optionList[id].status == OptionStatus.OnSale, "Option not on sale");

        optionList[id].status = OptionStatus.Created;
        delete marketList[id];

        emit OptionDelisted(id, msg.sender);
    }

    function burnOption(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
        require(optionList[id].status != OptionStatus.OnSale, "Cannot burn option while on sale");

        // Transfer collateral back to the owner
        require(IERC20(optionList[id].collateralToken).transfer(optionList[id].owner, optionList[id].collateralAmount), "Failed to transfer ERC20 collateral");

        delete ownerList[msg.sender][id];
        delete creatorList[msg.sender][id];
        delete optionList[id];
        delete collateralList[id];
        delete marketList[id];

        emit OptionBurned(id, msg.sender);
    }

    function claimOption(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
        require(optionList[id].status != OptionStatus.OnSale, "Cannot claim option while on sale");

        // Transfer collateral to the owner
        require(IERC20(optionList[id].collateralToken).transfer(optionList[id].owner, optionList[id].collateralAmount), "Failed to transfer ERC20 collateral");

        // Transfer premium to the creator
        require(IERC20(optionList[id].collateralToken).transfer(optionList[id].creator, collateralList[id].totalPremium), "Failed to transfer premium");

        delete ownerList[msg.sender][id];
        delete creatorList[msg.sender][id];
        delete optionList[id];
        delete collateralList[id];
        delete marketList[id];

        emit OptionClaimed(id, msg.sender);
    }

    function executeOption(uint256 id) external onlyValidTime(optionList[id].expires) onlyIfNotExpired(id) onlyIfNotStale(id) gasLimitNotExceeded {
        require(optionList[id].status == OptionStatus.OnSale, "Option not on sale");

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

        emit OptionExecuted(id, msg.sender, optionPrice, totalPrice);
    }

    function buyOption(uint256 id) external payable onlyIfNotExpired(id) onlyIfNotStale(id) gasLimitNotExceeded {
        require(optionList[id].status == OptionStatus.OnSale, "Option not on sale");

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
        optionList[id].status = OptionStatus.Created;

        // Refund excess payment to the buyer
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value.sub(totalPrice));
        }

        emit OptionBought(id, msg.sender, totalPrice);
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
        optionList[id].status = OptionStatus.Created;

        // Refund excess payment to the buyer
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value.sub(totalPrice));
        }

        emit OptionBought(id, msg.sender, totalPrice);
    }


    function updatePrice(uint256 id) external onlyOptionOwner(id) {
        // Use Chainlink VRF to get the latest price
        bytes32 requestId = ChainlinkVRF(chainlinkOracle).requestRandomness(bytes32(0), 1);
        latestPrice = ChainlinkVRF(chainlinkOracle).getPrice(requestId);
    }

    function fulfillPrice(bytes32 requestId, uint256 price) external {
        require(msg.sender == chainlinkOracle, "Unauthorized: Only Chainlink oracle can fulfill price");
        latestPrice = price;
        delete priceRequests[requestId];
    }

    function cancelOption(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
        require(optionList[id].status == OptionStatus.OnSale, "Option not on sale");

        delete ownerList[msg.sender][id];
        optionList[id].status = OptionStatus.Created;
        delete marketList[id];

        emit OptionCancelled(id, msg.sender);
    }

    function withdrawCollateral(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
        require(optionList[id].status == OptionStatus.Created, "Cannot withdraw collateral for an active option");

        // Transfer collateral back to the owner
        require(IERC20(optionList[id].collateralToken).transfer(optionList[id].owner, optionList[id].collateralAmount), "Failed to transfer ERC20 collateral");

        delete ownerList[msg.sender][id];
        delete creatorList[msg.sender][id];
        delete optionList[id];
        delete collateralList[id];

        emit CollateralWithdrawn(id, msg.sender);
    }

    

    function bid(uint256 id, uint256[] calldata offer) external payable onlyValidAddress(optionList[id].owner) onlyValidTime(optionList[id].expires) onlyIfNotExpired(id) onlyValidAmount(offer[0]) onlyIfNotStale(id) onlyValidCounterOffer(offer[1]) onlyValidFraction(offer[2], collateralList[id].units) gasLimitNotExceeded {
        require(optionList[id].status == OptionStatus.Created, "Option not in created state");
        require(bids[id][msg.sender] == 0, "You already have an active bid");
        require(userBidCount[msg.sender] < maxBidsPerUser, "Maximum number of bids reached");

        // Calculate total premium
        uint256 totalPremium = offer[0].add(offer[1]);

        // Check that bid + premium <= collateralLimit
        require(totalPremium <= collateralLimit[id], "Bid + premium exceeds collateral limit");

        // Transfer collateral and premium to contract
        require(IERC20(optionList[id].collateralToken).transferFrom(msg.sender, address(this), totalPremium), "Failed to transfer collateral and premium");

        // Update bid data
        bids[id][msg.sender] = totalPremium;

        // Update user bid count
        userBidCount[msg.sender]++;

        // Update market data
        marketList[id].counterOffer = offer;

        // Update priceToBidder mapping
        priceToBidder[id][offer[3]] = msg.sender;

        emit BidPlaced(id, msg.sender, offer);
    }

    function simpleBid(uint256 id, uint256 amount) external payable onlyValidAmount(amount) onlyValidTime(optionList[id].expires) onlyIfNotExpired(id) {
        require(msg.sender != optionList[id].owner, "Owner cannot bid on their own option");
        bids[id][msg.sender] = amount;
    }
    function offerAmt(uint256 id, uint256 amount) external onlyOptionOwner(id) onlyValidAmount(amount) onlyValidTime(optionList[id].expires) onlyIfNotExpired(id) {
        require(msg.sender != optionList[id].owner, "Owner cannot offer on their own option");
        offers[id][msg.sender] = amount;
    }

    function offer(uint256 id, uint256[] calldata offerPrice) external onlyValidTime(optionList[id].expires) onlyIfNotExpired(id) onlyValidAmount(offerPrice[0]) onlyIfNotStale(id) onlyValidCounterOffer(offerPrice[1]) onlyValidFraction(offerPrice[2], collateralList[id].units) gasLimitNotExceeded {
        require(optionList[id].status == OptionStatus.Created, "Option not in created state");

        // Calculate total premium
        uint256 totalPremium = offerPrice[0].add(offerPrice[1]);

        // Transfer collateral and premium to contract
        require(IERC20(optionList[id].collateralToken).transferFrom(msg.sender, address(this), totalPremium), "Failed to transfer collateral and premium");

        // Update offer data
        offers[id][msg.sender] = totalPremium;

        // Update priceToOfferer mapping
        priceToOfferer[id][offerPrice[3]] = msg.sender;

        emit OfferPlaced(id, msg.sender, offerPrice);
    }

    

    // ... (new bid function)
function newBid(uint256 id, uint256[] calldata bidOffer, uint256[] calldata oracleData) external
    onlyValidAddress(optionList[id].owner)
    onlyValidTime(optionList[id].expires)
    onlyIfNotExpired(id)
    onlyValidAmount(bidOffer[0])
    onlyIfNotStale(id)
    onlyValidCounterOffer(bidOffer[1])
    onlyValidFraction(bidOffer[2], collateralList[id].units)
    gasLimitNotExceeded
{
    require(optionList[id].status == OptionStatus.Created, "Option not in created state");

    // Calculate total premium
    uint256 totalPremium = bidOffer[0].add(bidOffer[1]);

    // Transfer collateral and premium to contract
    _validateAndTransferBidCollateral( id, totalPremium, bidOffer[3]);

    // Update bid data
    _updateBidData(id, totalPremium);

    // Update market data
    _updateMarketData(id, bidOffer);

    emit NewBid(id, msg.sender, bidOffer, oracleData);
}

function _validateAndTransferBidCollateral(uint256 id, uint256 totalPremium, uint256 collateralAmount) internal {
    // Input validation
    require(totalPremium > 0, "Invalid bid premium: Bid premium must be greater than zero");

    // Transfer collateral and approve
    _transferBidCollateral(id, collateralAmount);
}

function _transferBidCollateral(uint256 id,uint256 collateralAmount) internal {
    require(IERC20(optionList[id].collateralToken).transferFrom(msg.sender, address(this), collateralAmount), "Failed to transfer bid collateral");
    require(IERC20(optionList[id].collateralToken).approve(address(this), collateralAmount), "Failed to approve bid collateral");
}

function _updateBidData(uint256 id, uint256 totalPremium) internal {
    // Update bid data logic
    bids[id][msg.sender] = totalPremium;
}

function _updateMarketData(uint256 id, uint256[] memory bidOffer) internal {
    // Update market data logic
    marketList[id].counterOffer = bidOffer;
}


    // ... (new resetBids function)
    function newResetBids(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
        // Implement the logic for the new resetBids function
        // This function may involve deleting or resetting bid data and emitting relevant events

        // Delete expired bids
        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address bidder = priceToBidder[id][optionList[id].price[i]];
            delete bids[id][bidder];
        }

        emit NewResetBids(id);
    }

    function acceptBid(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
        require(optionList[id].status == OptionStatus.OnSale, "Option is not on sale");

        address highestBidder = address(0);
        uint256 highestBid = 0;

        // Find the highest bid
        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address bidder = priceToBidder[id][optionList[id].price[i]];
            uint256 bidAmount = bids[id][bidder];

            if (bidAmount > highestBid) {
                highestBid = bidAmount;
                highestBidder = bidder;
            }
        }

        require(highestBid > 0, "No valid bids");

        // Check bidder balance covers bid amount
        require(bidderBalance(id, highestBidder) >= highestBid, "Bidder balance too low");

        // Transfer collateral to the bidder and bid amount to the owner
        IERC20(optionList[id].collateralToken).transfer(msg.sender, optionList[id].collateralAmount);
        IERC20(optionList[id].collateralToken).transfer(optionList[id].owner, highestBid);

        // Clear bids
        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address bidder = priceToBidder[id][optionList[id].price[i]];
            delete bids[id][bidder];
        }

        // Update option status
        optionList[id].status = OptionStatus.Created;
        delete optionList[id].price;

        emit OptionBought(id, msg.sender, optionList[id].collateralAmount.add(highestBid));

    }

    function acceptOffer(uint256 id) external onlyOptionOwner(id) onlyIfNotExpired(id) {
        require(optionList[id].status == OptionStatus.OnSale, "Option is not on sale");

        address lowestOfferer = address(0);
        uint256 lowestOffer = type(uint256).max; // Initialize with the maximum possible value

        // Find the lowest offer
        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address offerer = priceToOfferer[id][optionList[id].price[i]];
            uint256 offerAmount = offers[id][offerer];

            if (offerAmount < lowestOffer) {
                lowestOffer = offerAmount;
                lowestOfferer = offerer;
            }
        }

        require(lowestOffer < type(uint256).max, "No valid offers");

        // Check offerer balance covers offer amount
        require(offererBalance(id, lowestOfferer) >= lowestOffer, "Offerer balance too low");

        // Transfer collateral to the owner and offer amount to the offerer
        IERC20(optionList[id].collateralToken).transfer(msg.sender, optionList[id].collateralAmount);
        IERC20(optionList[id].collateralToken).transfer(lowestOfferer, lowestOffer);

        // Clear offers
        for (uint256 i = 0; i < optionList[id].price.length; i++) {
            address offerer = priceToOfferer[id][optionList[id].price[i]];
            delete offers[id][offerer];
        }

        // Update option status
        optionList[id].status = OptionStatus.Created;

        emit OptionBought(id, msg.sender, optionList[id].collateralAmount.add(lowestOffer));

    }

    function withdrawBid(uint256 id) external onlyIfNotActive(id) {
        require(bids[id][msg.sender] > 0, "No valid bid to withdraw");
        uint256 bidAmount = bids[id][msg.sender];

        // Check if bid is not the highest
        require(bidAmount < getHighestBid(id), "Cannot withdraw highest bid");

        // Your existing logic for withdrawal fee
        // Only allow withdrawal if bid no longer highest, and apply withdrawal fee if necessary
        // Also, consider other withdrawal limitations (frequency, last 24 hours, etc.)

        delete bids[id][msg.sender];
        payable(msg.sender).transfer(bidAmount);

         emit BidWithdrawn(id, msg.sender, bids[id][msg.sender]);
         //emit BidWithdrawn(id, msg.sender, bidAmount);
    }

    function withdrawOffer(uint256 id) external onlyIfNotActive(id){
        // Implement the logic for withdrawing offers
        // Check if the offer is not the lowest, similar to the bid withdrawal logic
        // Transfer the offer amount back to the user and clear the offer
        // Remember to emit relevant events
        require(offers[id][msg.sender] > 0, "No valid offer to withdraw");
        uint256 offerAmount = offers[id][msg.sender];

         // Check if bid is not the highest
        require(offerAmount < getLowestOffer(id), "Cannot withdraw lowest offer");

        delete offers[id][msg.sender];
        IERC20(optionList[id].collateralToken).transfer(msg.sender, offerAmount);

        emit OfferWithdrawn(id, msg.sender, offers[id][msg.sender]);
        //emit OfferWithdrawn(id, msg.sender, offerAmount);
    }

    function extendBidDuration(uint256 id, uint256 additionalDuration) external onlyOptionOwner(id) onlyIfNotExpired(id) {
        require(additionalDuration > 0, "Additional duration must be greater than zero");

        optionList[id].expires = optionList[id].expires.add(additionalDuration);

        emit BidDurationExtended(id, additionalDuration);
    }

    function extendOfferDuration(uint256 id, uint256 additionalDuration) external onlyOptionOwner(id) onlyIfNotExpired(id) {
        require(additionalDuration > 0, "Additional duration must be greater than zero");

        // Use SafeMath to prevent overflow
        uint256 newExpiration = optionList[id].expires.add(additionalDuration);
        require(newExpiration > optionList[id].expires, "Overflow in expiration calculation");

        optionList[id].expires = newExpiration;

        emit OfferDurationExtended(id, additionalDuration);
    }

    function withdrawPartialBid(uint256 id, uint256 percent) external onlyIfNotActive(id) {
        require(bids[id][msg.sender] > 0, "No valid bid to withdraw");
        require(percent > 0 && percent <= 100, "Invalid percentage");

        uint256 bidAmount = bids[id][msg.sender];
        uint256 partialAmount = bidAmount.mul(percent).div(100);

        // Ensure the remaining bid amount is above any minimum
        require(bidAmount.sub(partialAmount) >= minBidAmount, "Remaining bid below minimum");

        // Update the stored bid amount
        userBids[msg.sender] = userBids[msg.sender].sub(partialAmount);

        // Transfer the partial amount back
        payable(msg.sender).transfer(partialAmount);

        emit PartialBidWithdrawn(id, msg.sender, partialAmount);
    }

}