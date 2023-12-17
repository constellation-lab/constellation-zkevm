// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*import "@openzeppelin/contracts-v0.7/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";*/

import "@openzeppelin/contracts/utils/math/Math.sol";
import "./ChainlinkMock.sol";
import "./ConstellationCore.sol";

library Constants {
    using Math for uint256;

    // Enum to represent option status
    enum OptionStatus {
        Created,
        OnSale,
        Expired
    }

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

    // Event emitted when Ether is received
    event ReceivedEther(address bidder, uint256 value);

    // Event emitted when chainlinkMock is set
    event ChainlinkMockSet(address indexed mock);

    // Events from ConstellationMarket
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
    event NewResetBids(uint256 indexed id);
    event WithdrawBid(uint256 indexed id, address indexed bidder, uint256 refundedAmount);
    event AnalyzeActivity(uint256 indexed id, uint256 result);
    event ExtendBidDuration(uint256 indexed id, uint256 newExpiration);
    event ExtendOfferDuration(uint256 indexed id, uint256 newExpiration);
    event CollateralWithdrawn(uint256 id, address indexed withdrawer);
    event BidPlaced(uint256 id, address indexed bidder, uint256[] offer);
    event OfferPlaced(uint256 id, address indexed offerer, uint256[] offer);
    event NewBid(uint256 id, address indexed bidder, uint256[] offer, uint256[] oracleData);
    //event NewBid(uint256 id, address indexed bidder, uint256[] offer);
    event PartialBidWithdrawn(uint256 id, address indexed withdrawer, uint256 partialAmount);
    event OptionExecuted(bytes32 indexed requestId, uint256 randomNumber);
    event OptionTransfered(uint256 id, address sender, address to);
    event OptionListed(uint256 id, address sender, uint256[] toAddPriceMemory);
    event OptionDelisted(uint256 id, address sender);
    event OptionBurned(uint256 id, address sender);
    event OptionClaimed(uint256 id, address indexed claimer);
    event OptionExecuted(uint256 id, address indexed executor, uint256 optionPrice, uint256 totalPrice);
    event OptionBought(uint256 id, address indexed buyer, uint256 totalPrice);
    event OptionCancelled(uint256 id, address indexed canceller);
    event OptionCreated(uint256 id, address sender, address collateralToken, 
        uint256 collateralAmount, uint256 counterOffer, uint256 expires, uint256 maxUnits);


    // Function to initialize the library (can be used as a constructor)
    function initialize() public {
        // constructor logic if needed
    }



}
