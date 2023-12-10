    //This contract handles the key option operations for creation, transfer, bidding, offering, buying, selling 
    // SPDX-License-Identifier: MIT
    //pragma solidity ^0.8.9;
    //pragma solidity --no-strings;
    pragma solidity ^0.6.8;

    import "@openzeppelin/contracts-v0.7/access/Ownable.sol";
    import "@openzeppelin/contracts-v0.7/token/ERC20/IERC20.sol";
    import "@openzeppelin/contracts-v0.7/math/SafeMath.sol";
    import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

    import "./ConstellationCore.sol";
    import "./ChainlinkMock.sol";



    interface IConstellationCore {

        
        
        function createOption(
                uint256[] calldata counterOffer, 
                uint256 expires,
                address collateralToken,
                uint256 collateralAmount,
                uint256 maxUnits
            ) external returns (uint256);

            function getOption(uint256 id) external view returns (Constants.Data memory) ;
            /*(
                address creator,
                address owner,
                address collateralToken,
                uint256 collateralAmount,
                uint256[] memory counterOffer,
                Constants.OptionStatus status,
                uint256[] memory price,
                uint256 expires,
                uint256 units
            );*/


                            

            function getConfig() external view returns (address creator, uint256 totalOptionsNum);

            function getExpiry(uint256 id) external view returns (uint256 expires);

            //function getStatus(uint256 id) external view returns (OptionStatus);

            function isListed(uint256 id) external view returns (bool);

            function buyOption(uint256 id) external payable;

            function executeOption(uint256 id) external;
            
            function withdrawCollateral(uint256 id) external;

            function isExpired(uint256 id) external view returns (bool);

            function isOnSale(uint256 id) external view returns (bool);

            function isStale(uint256 id) external view returns (bool);

            function isPaused() external view returns (bool);

            function isOptionOwner(uint256 id) external view returns (bool);

            function getCounterOffer(uint256 id) external view returns (uint256[] memory);

            function getPrice(uint256 id) external view returns (uint256[] memory);

            function getMinBidAmount() external view returns (uint256);

            function getBid(uint256 id, address bidder) external view returns (uint256);

            function setBid(uint256 id, address bidder, uint256 value) external;
            
            function getOffer(uint256 id, address bidder) external view returns (uint256);

            function setOffer(uint256 id, address bidder, uint256 value) external;

            function getUserBidCount(address user) external view returns (uint256);

            function incrementUserBidCount(address bidder) external;

            function getMaxBidCount() external view returns (uint256);

             function getCollateralLimit(uint256 id) external view returns (uint256);

            function getMarketList(uint256 id) external view returns (ConstellationCore.Data memory);

            function getPriceToBidder(uint256 id, uint256 price) external view returns (address);

            function getPriceToOfferer(uint256 id, uint256 price) external view returns (address);

            function setPriceToOfferer(uint256 id, uint256 price, address offerer) external view returns (address);

            function getHighestBid(uint256 id) external view returns (uint256);

            function getLowestOffer(uint256 id) external view returns (uint256);

             function decrementUserBidCount(address user) external;

            //mareket functions
            function addToMarket(uint256 id, uint256[] calldata price) external;

            function removeFromMarket(uint256 id) external; 

            function getMarketListed(uint256 id) external view returns (bool);

            function checkOnlyIfNotActive(uint256 id) external view ;

            // Oracle functions
            //function updatePrice(uint256 id, string calldata denom) external;
            //function fulfillPrice(uint256 price) external;

            // Events
            event OptionCreated(uint256 id, address owner);
            event OptionExecuted(uint256 id, uint256 price);

    }

    pragma experimental ABIEncoderV2; 

    contract ConstellationMarket{
        using SafeMath for uint256;
        using Constants for *;

        IConstellationCore public core; // Interface to interact with ConstellationCore

        constructor(address coreAddress) public {
            core = IConstellationCore(coreAddress);
        }
        

         // Add the requested modifiers
            modifier onlyCreator(address creator) {
                require(msg.sender == creator, "Unauthorized: Only creator can call this function");
                _;
            }

            modifier onlyIfNotExpired(uint256 id) {
                require(!core.isExpired(id), "Expired");
                _; 
            }

            modifier onlyValidAddress(address addr) {
                require(addr != address(0), "Invalid address: Address cannot be zero");
                _;
            }

            modifier onlyIfNotOnSale(uint256 id) {
                require(!core.isOnSale(id), "Option already on sale");
             _;
            }


            modifier onlyIfNotStale(uint256 id) {
                require(!core.isStale(id), "Stale bid/offer");
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

            modifier whenNotPaused() {
                require(IConstellationCore(core).isPaused()==false, "Contract is paused");
                _;
            }

            modifier whenPaused() {
                require(IConstellationCore(core).isPaused()==true, "Contract is not paused");
                _;
            }

            modifier onlyOptionOwner(uint256 id) {
                require(core.isOptionOwner(id), "Unauthorized: Only option owner can call this function");
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

           

            modifier onlyIfNotActive(uint256 id) {
                //require(block.timestamp < Constants.optionList[id].expires.add(gracePeriod), "Active bid/offer");
                // Additional logic if needed for the existing onlyIfNotActive implementation
                _;
            }


 function bid(uint256 id, uint256[] calldata offer) external payable
        onlyValidAddress(core.getOption(id).owner)
        onlyValidTime(core.getExpiry(id))
        onlyIfNotExpired(id)
        onlyValidAmount(offer[0])
        onlyIfNotStale(id)
        onlyValidCounterOffer(offer[1])
        onlyValidFraction(offer[2], core.getOption(id).units)
        gasLimitNotExceeded
    {
    require(core.getOption(id).status == Constants.OptionStatus.Created, "Option not in created state");
    require(core.getBid(id, msg.sender) == 0, "You already have an active bid");
    require(core.getUserBidCount(msg.sender) < core.getMaxBidCount(), "Maximum number of bids reached");

    uint256 maxBidCount = core.getMaxBidCount();
    // Calculate total premium
    uint256 totalPremium = offer[0].add(offer[1]);

    // Check that bid + premium <= collateralLimit
    require(totalPremium <= core.getCollateralLimit(id), "Bid + premium exceeds collateral limit");

    // Transfer collateral and premium to contract
    require(IERC20(core.getOption(id).collateralToken).transferFrom(msg.sender, address(this), totalPremium), "Failed to transfer collateral and premium");

    // Update bid data
    uint256 existingBid = core.getBid(id, msg.sender);
    require(existingBid == 0, "You already have an active bid");

    core.setBid(id, msg.sender, totalPremium);

    // Update user bid count
    require(core.getUserBidCount(msg.sender) < maxBidCount, "Maximum number of bids reached");
    core.incrementUserBidCount(msg.sender);

    // Update market data
   /* ConstellationCore.Data memory marketData = core.getMarketList(id);
    marketData.counterOffer = offer;
   

    // Update priceToBidder mapping
    //address previousBidder = core.getPriceToBidder(id, offer[3]);

    core.getPriceToBidder(id, offer[3]);*/

        // Update market data
    _updateMarketData(id, offer);

    emit Constants.BidPlaced(id, msg.sender, offer);
}

function _updateMarketData(uint256 id, uint256[] memory offer) internal {
    // Update market data
    ConstellationCore.Data memory marketData = core.getMarketList(id);
    marketData.counterOffer = offer;

    // Update priceToBidder mapping
    // address previousBidder = core.getPriceToBidder(id, offer[3]);
    core.getPriceToBidder(id, offer[3]);

    emit Constants.BidPlaced(id, msg.sender, offer);
}

function simpleBid(uint256 id, uint256 amount) external payable onlyValidAmount(amount) onlyValidTime(core.getOption(id).expires) onlyIfNotExpired(id) {
    require(msg.sender != core.getOption(id).owner, "Owner cannot bid on their own option");

    // Retrieve the existing bid value
    uint256 existingBid = core.getBid(id, msg.sender);

    // If there's an existing bid, revert or handle as needed
    require(existingBid == 0, "You already have an active bid");

    // Set the bid value
    core.setBid(id, msg.sender, amount);
}



   function offerAmt(uint256 id, uint256 amount) external
    onlyOptionOwner(id)
    onlyValidAmount(amount)
    onlyValidTime(core.getOption(id).expires)
    onlyIfNotExpired(id)
{
    require(msg.sender != core.getOption(id).owner, "Owner cannot offer on their own option");

    // Retrieve the existing offer value
    uint256 existingOffer = core.getOffer(id, msg.sender);

    // If there's an existing offer, revert or handle as needed
    require(existingOffer == 0, "You already have an active offer");

    // Set the offer value
    core.setOffer(id, msg.sender, amount);
}

    function offer(uint256 id, uint256[] calldata offerPrice) external
        onlyValidTime(core.getOption(id).expires)
        onlyIfNotExpired(id)
        onlyValidAmount(offerPrice[0])
        onlyIfNotStale(id)
        onlyValidCounterOffer(offerPrice[1])
        onlyValidFraction(offerPrice[2], core.getOption(id).units)
        gasLimitNotExceeded
    {
        require(core.getOption(id).status == Constants.OptionStatus.Created, "Option not in created state");

        // Calculate total premium
        uint256 totalPremium = offerPrice[0].add(offerPrice[1]);

        // Transfer collateral and premium to contract
        require(IERC20(core.getOption(id).collateralToken).transferFrom(msg.sender, address(this), totalPremium), "Failed to transfer collateral and premium");

        // Update offer data
        core.setOffer(id, msg.sender, totalPremium);

        // Update priceToOfferer mapping
        // Update priceToOfferer mapping
        core.setPriceToOfferer(id, offerPrice[3], msg.sender);


        emit Constants.OfferPlaced(id, msg.sender, offerPrice);
    }


    function newBid(uint256 id, uint256[] calldata bidOffer, uint256[] calldata oracleData) external
        onlyValidAddress(core.getOption(id).owner)
        onlyValidTime(core.getExpiry(id))
        onlyIfNotExpired(id)
        onlyValidAmount(bidOffer[0])
        onlyIfNotStale(id)
        onlyValidCounterOffer(bidOffer[1])
        onlyValidFraction(bidOffer[2], core.getOption(id).units)
        gasLimitNotExceeded
    {
        require(core.getOption(id).status == Constants.OptionStatus.Created, "Option not in created state");

        // Calculate total premium
        uint256 totalPremium = bidOffer[0].add(bidOffer[1]);

        // Transfer collateral and premium to contract
        _validateAndTransferBidCollateral(id, totalPremium /*bidOffer[3]*/);

        // Update bid data
        _updateBidData(id, totalPremium);

        // Update market data
        _updateMarketData(id, bidOffer, oracleData);

        emit Constants.NewBid(id, msg.sender, bidOffer, oracleData);
    }

function _validateAndTransferBidCollateral(uint256 id, uint256 totalPremium /*uint256 offerPrice*/) internal {
        // Check that bid + premium <= collateralLimit
        require(totalPremium <= core.getCollateralLimit(id), "Bid + premium exceeds collateral limit");

        // Transfer collateral and premium to contract
        require(IERC20(core.getOption(id).collateralToken).transferFrom(msg.sender, address(this), totalPremium), "Failed to transfer collateral and premium");
    }

function _updateBidData(uint256 id, uint256 totalPremium) internal {
        // Update bid data
        uint256 existingBid = core.getBid(id, msg.sender);
        require(existingBid == 0, "You already have an active bid");

        core.setBid(id, msg.sender, totalPremium);

        // Update user bid count
        uint256 maxBidCount = core.getMaxBidCount();
        require(core.getUserBidCount(msg.sender) < maxBidCount, "Maximum number of bids reached");
        core.incrementUserBidCount(msg.sender);
    }

function _updateMarketData(uint256 id, uint256[] memory bidOffer, uint256[] memory oracleData) internal {
        // Update market data
        ConstellationCore.Data memory marketData = core.getMarketList(id);
        marketData.counterOffer = bidOffer;

        // Update priceToBidder mapping
        //address previousBidder = core.getPriceToBidder(id, bidOffer[3]);
        core.getPriceToBidder(id, bidOffer[3]);


        emit Constants.NewBid(id, msg.sender, bidOffer, oracleData);
    }





   


function newResetBids(uint256 id) external
        onlyOptionOwner(id)
        onlyIfNotExpired(id)
    {
        // Delete expired bids
        _deleteExpiredBids(id);

        emit Constants.NewResetBids(id);
    }

function acceptBid(uint256 id) external
        onlyOptionOwner(id)
        onlyIfNotExpired(id)
    {
        require(core.getOption(id).status  == Constants.OptionStatus.OnSale, "Option is not on sale");

        (address highestBidder, uint256 highestBid) = _findHighestBid(id);
        require(highestBid > 0, "No valid bids");

        _transferCollateralAndBidAmount(id, highestBidder, highestBid);

        // Clear bids
        _deleteExpiredBids(id);

        // Update option status
        core.getOption(id).status  = Constants.OptionStatus.Created;
        delete core.getOption(id).price;

        emit Constants.OptionBought(id, msg.sender, core.getOption(id).collateralAmount.add(highestBid));
    }

function acceptOffer(uint256 id) external
        onlyOptionOwner(id)
        onlyIfNotExpired(id)
    {
        require(core.getOption(id).status == Constants.OptionStatus.OnSale, "Option is not on sale");

        (address lowestOfferer, uint256 lowestOffer) = _findLowestOffer(id);
        require(lowestOffer < type(uint256).max, "No valid offers");

        _transferCollateralAndOfferAmount(id, lowestOfferer, lowestOffer);

        // Clear offers
        _deleteExpiredOffers(id);

        // Update option status
        core.getOption(id).status  = Constants.OptionStatus.Created;

        emit Constants.OptionBought(id, msg.sender, core.getOption(id).collateralAmount.add(lowestOffer));
    }

// Internal function to delete expired bids
function _deleteExpiredBids(uint256 id) internal {
    for (uint256 i = 0; i < core.getOption(id).price.length; i++) {
        address bidder = core.getPriceToBidder(id, core.getOption(id).price[i]);
        _resetBidData(id, bidder);
    }
}

// Internal function to find the highest bid
function _findHighestBid(uint256 id) internal view returns (address, uint256) {
    address highestBidder = address(0);
    uint256 highestBid = 0;

    for (uint256 i = 0; i < core.getOption(id).price.length; i++) {
        address bidder = core.getPriceToBidder(id, core.getOption(id).price[i]);
        uint256 bidAmount = core.getBid(id, bidder);

        if (bidAmount > highestBid) {
            highestBid = bidAmount;
            highestBidder = bidder;
        }
    }

    return (highestBidder, highestBid);
}

// Internal function to reset bid data for a bidder
function _resetBidData(uint256 id, address bidder) internal {
    core.setBid(id, bidder, 0);
}


// Internal function to transfer collateral and bid amount
function _transferCollateralAndBidAmount(uint256 id, address bidder, uint256 bidAmount) internal {
    require(core.getBid(id, bidder) >= bidAmount, "Bidder balance too low");

    // Transfer collateral to the bidder and bid amount to the owner
    IERC20(core.getOption(id).collateralToken).transfer(msg.sender, core.getOption(id).collateralAmount);
    IERC20(core.getOption(id).collateralToken).transfer(core.getOption(id).owner, bidAmount);
}

// Internal function to delete expired offers
function _deleteExpiredOffers(uint256 id) internal {
    for (uint256 i = 0; i < core.getOption(id).price.length; i++) {
        address offerer = core.getPriceToOfferer(id, core.getOption(id).price[i]);
        _resetOfferData(id, offerer);
    }
}

// Internal function to reset offer data for an offerer
function _resetOfferData(uint256 id, address offerer) internal {
    core.setOffer(id, offerer, 0);
}

// Internal function to find the lowest offer
function _findLowestOffer(uint256 id) internal view returns (address, uint256) {
    address lowestOfferer = address(0);
    uint256 lowestOffer = type(uint256).max; // Initialize with the maximum possible value

    for (uint256 i = 0; i < core.getOption(id).price.length; i++) {
        address offerer = core.getPriceToOfferer(id, core.getOption(id).price[i]);
        uint256 offerAmount = core.getOffer(id, offerer);

        if (offerAmount < lowestOffer) {
            lowestOffer = offerAmount;
            lowestOfferer = offerer;
        }
    }

    return (lowestOfferer, lowestOffer);
}

// Internal function to transfer collateral and offer amount
function _transferCollateralAndOfferAmount(uint256 id, address offerer, uint256 offerAmount) internal {
    require(core.getOffer(id, offerer) >= offerAmount, "Offerer balance too low");

    // Transfer collateral to the owner and offer amount to the offerer
    IERC20(core.getOption(id).collateralToken).transfer(msg.sender, core.getOption(id).collateralAmount);
    IERC20(core.getOption(id).collateralToken).transfer(offerer, offerAmount);
}





function withdrawBid(uint256 id) external onlyIfNotActive(id) {
    require(core.getBid(id, msg.sender) > 0, "No valid bid to withdraw");
    uint256 bidAmount = core.getBid(id, msg.sender);

    // Check if bid is not the highest
    require(bidAmount < core.getHighestBid(id), "Cannot withdraw highest bid");

    // Your existing logic for withdrawal fee
    // Only allow withdrawal if bid no longer highest, and apply withdrawal fee if necessary
    // Also, consider other withdrawal limitations (frequency, last 24 hours, etc.)

    _resetBidData(id, msg.sender);
    payable(msg.sender).transfer(bidAmount);

    emit Constants.BidWithdrawn(id, msg.sender, bidAmount);
}

function withdrawOffer(uint256 id) external onlyIfNotActive(id) {
    require(core.getOffer(id, msg.sender) > 0, "No valid offer to withdraw");
    uint256 offerAmount = core.getOffer(id, msg.sender);

    // Check if offer is not the lowest
    require(offerAmount < core.getLowestOffer(id), "Cannot withdraw lowest offer");

    _resetOfferData(id, msg.sender);
    IERC20(core.getOption(id).collateralToken).transfer(msg.sender, offerAmount);

    emit Constants.OfferWithdrawn(id, msg.sender, offerAmount);
}

function extendBidDuration(uint256 id, uint256 additionalDuration) external onlyOptionOwner(id) onlyIfNotExpired(id) {
    require(additionalDuration > 0, "Additional duration must be greater than zero");

    core.getOption(id).expires = core.getOption(id).expires.add(additionalDuration);

    emit Constants.BidDurationExtended(id, additionalDuration);
}

function extendOfferDuration(uint256 id, uint256 additionalDuration) external onlyOptionOwner(id) onlyIfNotExpired(id) {
    require(additionalDuration > 0, "Additional duration must be greater than zero");

    // Use SafeMath     to prevent overflow
    uint256 newExpiration = core.getOption(id).expires.add(additionalDuration);
    require(newExpiration > core.getOption(id).expires, "Overflow in expiration calculation");

    core.getOption(id).expires = newExpiration;

    emit Constants.OfferDurationExtended(id, additionalDuration);
}

function withdrawPartialBid(uint256 id, uint256 percent) external onlyIfNotActive(id) {
    require(core.getBid(id, msg.sender) > 0, "No valid bid to withdraw");
    require(percent > 0 && percent <= 100, "Invalid percentage");

    uint256 bidAmount = core.getBid(id, msg.sender);
    uint256 partialAmount = bidAmount.mul(percent).div(100);

    // Ensure the remaining bid amount is above any minimum
    require(bidAmount.sub(partialAmount) >= core.getMinBidAmount(), "Remaining bid below minimum");

    // Update the stored bid amount
    core.decrementUserBidCount(msg.sender);

    // Transfer the partial amount back
    payable(msg.sender).transfer(partialAmount);

    emit Constants.PartialBidWithdrawn(id, msg.sender, partialAmount);
}


function createOption(
    uint256[] calldata counterOffer,
    uint256 expires,
    address collateralToken,
    uint256 collateralAmount,
    uint256 maxUnits
    ) external returns (uint256) {
        // Call the corresponding function in ConstellationCore
        return core.createOption(counterOffer, expires, collateralToken, collateralAmount, maxUnits);
    }

    function getOption(uint256 id)
        external
        view
        returns (Constants.Data memory)
        /*returns (
            address creator,
            address owner,
            address collateralToken,
            uint256 collateralAmount,
            uint256[] memory counterOffer,
            Constants.OptionStatus status,
            uint256[] memory price,
            uint256 expires,
            uint256 units
        )*/
    {
        // Call the corresponding function in ConstellationCore
        return core.getOption(id);
    }

    function getConfig() external view returns (address creator, uint256 totalOptionsNum) {
        // Call the corresponding function in ConstellationCore
        return core.getConfig();
    }

    function getExpiry(uint256 id) external view returns (uint256 expires) {
        // Call the corresponding function in ConstellationCore
        return core.getExpiry(id);
    }

    function isListed(uint256 id) external view returns (bool) {
        // Call the corresponding function in ConstellationCore
        return core.isListed(id);
    }

    function buyOption(uint256 id) external payable {
        // Call the corresponding function in ConstellationCore
        core.buyOption{value: msg.value}(id);
    }

    function executeOption(uint256 id) external {
        // Call the corresponding function in ConstellationCore
        core.executeOption(id);
    }

    function withdrawCollateral(uint256 id) external {
        // Call the corresponding function in ConstellationCore
        core.withdrawCollateral(id);
    }

    function getCounterOffer(uint256 id) external view returns (uint256[] memory) {
        // Call the corresponding function in ConstellationCore
        return core.getCounterOffer(id);
    }

    function getPrice(uint256 id) external view returns (uint256[] memory) {
        // Call the corresponding function in ConstellationCore
        return core.getPrice(id);
    }

    function addToMarket(uint256 id, uint256[] calldata price) external {
        // Call the corresponding function in ConstellationCore
        core.addToMarket(id, price);
    }

    function removeFromMarket(uint256 id) external {
        // Call the corresponding function in ConstellationCore
        core.removeFromMarket(id);
    }

    function getMarketListed(uint256 id) external view returns (bool) {
        // Call the corresponding function in ConstellationCore
        return core.getMarketListed(id);
    }

    function checkOnlyIfNotActive(uint256 id) external view {
        // Call the corresponding function in ConstellationCore
        core.checkOnlyIfNotActive(id);
    }

    }