# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```


```shell
/*
README INFO ON COMMENTS, SUGGESTIONS, FUTURE INFO, UNDERSTANDING FUNCTIONALITY OF THE CONSTELLATION DERIVATIVE CONTRACT - ADD THESE FUNCTIONS TO COSM VERSION

GENERAL COMMENTS

Added events for the new functions: newBid, newResetBids, withdrawBid, extendBidDuration, extendOfferDuration, analyzeActivity
Modified acceptOffer to check offerer balance using a new offererBalance function, similar to bidder balance check in acceptBid
Added logic to withdrawBid to only allow withdrawal if bid is not highest, and apply fee if needed
Added withdrawOffer function with logic to only allow withdrawal if offer is not lowest
Added helper functions getHighestBid and getLowestOffer
Added extendBidDuration and extendOfferDuration functions to extend expiration times
Added requestPriceData function to request price data from Chainlink oracle
Added withdrawPartialBid to allow withdrawing a percentage of a bid
Added analyzeActivity function to analyze market activity and emit an event with the result

Other improvements:
Using SafeMath for overflow checks
Added more validation in require statements
Added gas limit checks with new gasLimitNotExceeded modifier
Emitting more events for transparency


POSTIVE
Modular code organization into logical functions and events
Good validation logic, modifiers, and error messages
Allows ERC20 tokens for collateral with approvals and transfers
Separates collateral from premiums paid
Implements bids, offers, partial execution, and fractional trading
Has expiration buffers, bid/offer duration controls, and stale bid logic
Integrates Chainlink price feeds
Well documented events for transparency


Validation of addresses in transferOption and addToMarket.
Separation of collateral from premiums using the collateral mapping and events.
Support for ERC20 tokens as collateral via transfers and approvals.
Fractional units allowed for partial trading of options.
Expanded SafeMath library with mul and div methods.

Some additional positive highlights:
Modularized the option data into logical structs.
Clear validation logic and error messages.
Well structured code and effective use of libraries.
Detailed events for transparency.

Positive changes:
Good use of require error messages for debugging.
Added SafeMath for substraction to prevent underflows.
Allow variable length arrays for counterOffer and price.
Added cancelOption and withdrawCollateral for owner flexibility.
Added pause/unpause methods for emergency control.
Added initial bid/offer and partial execution logic.
Allowed setting time buffers before expiration.
Other enhancements:
Could validate addresses in transferOption and addToMarket.
Separating collateral from premiums paid could still be done.
Allowing ERC20 tokens as collateral would be useful.
An oracle for latest market price data would be great.
Can expand the bid/offer and partial execution logic.
Could add logic to allow fraction of an option to be traded.
Architecture:
Well structured with sensible use of libraries, mappings, and events.
Modularizing repeating logic into inherited base contracts could be a future improvement.

IMPLEMENTED

Add error messages for require statements to make debugging easier.
Use SafeMath for subtraction as well to prevent underflows.
Allow array params like counterOffer and price to be variable length rather than fixed size.
Add a cancelOption function to allow owner to cancel before expiry.
Allow partial execution of an option by owner.
Validate addresses intransferOption and addToMarket.
Separate collateral from premiums paid - have collateral returned in all cases.
Allow ERC20 tokens as collateral instead of only Ether.
Add a pause/unpause ability for emergencies.
Allow owner to withdraw collateral early if not executed.
Have an oracle feed the latest price into the contract for market options.
Allow bids/offers instead of direct fixed prices.
Add time buffers before expiry for executions.
Allow fraction of an option to be traded.
Some higher level thoughts:
Modifiers could be split into reusable ones in a base contract.
Logging and events are good for transparency.
Mapping structures are efficient for storage.
Consider implications of re-entrancy with transfers.


Allowing ERC20 tokens as collateral:
Add an ERC20 token address to the Option struct
In createOption, accept an ERC20 token address and amount as collateral
Transfer tokens from caller to contract for collateral
Require approval first if using transferFrom
Update collateral transfer logic to use ERC20 transfers
Allow caller to specify which collateral token to withdraw

Expand bid/offer and partial execution logic:
For bids, store them in a mapping from bidder => bid amount
Accept the highest bid if above reserve when executing
For offers, store in a similar mapping by owner
When buying, pick the lowest offer below the buy price
For partial execution, allow input of a percentage to execute
Transfer that percentage of the collateral and premium
Store executed percentage on option struct

Allow fraction of an option to be traded:
Add a "units" field to track fractional units of the option
When creating, max units is determined by collateral
Allow less than max units to be specified
Transferring and buying transfers ownership of units
Premiums and executions done proportionally based on units owned

Separating collateral from premiums:
Have a separate collateral mapping that tracks collateral deposited per option
Premiums paid go directly to the beneficiary, not into collateral
Add collateral and premium structs/mappings
CreateOption takes collateral deposit, stores in mapping
Buying takes premium payment, transfers to beneficiary
Collateral is returned separately from any premium transfers
This keeps collateral escrowed with contract until returned

Integrating an oracle:
Define Chainlink interface for requesting latest price data
Set a Chainlink oracle address in the contract
Add a fulfillPrice function that Chainlink node can call
In fulfillPrice, update a latestPrice variable with the reported price
Create a requestPriceData function to initiate requests
Request price for market options in addToMarket
Use the latestPrice for market buy/sell price validation
Add expiry time for price data requests

Simple bid/offer implementations:
Add a bid mapping from bidder => bid amount
In the bid function, store the bid amount from msg.value
Add an acceptBid function to accept the highest bid
Transfer the bid amount to the owner, collateral to bidder
Similarly, store offers in an offer mapping from owner => offer amount
Accept the lowest offer that's above the reserve price
This allows basic auction-style bidding and direct offerings.

Default expiration buffer:
Add a bufferTime variable for the buffer duration
In createOption, set expires = expires + bufferTime
Allow bufferTime to be configured by the owner
Require executions happen before expires - bufferTime
This prevents last minute executions without notice.


Allowing withdrawals:
Add a withdrawBid() function that transfers the bid back to bidder and deletes bid
Require only the bidder can withdraw
Similarly add withdrawOffer() for offers
Could have a time limit, e.g. withdraw up to 1 day before expiry

Timestamp best practices:
 Use block.timestamp instead of now for expiration times
 now can be manipulated by miners, block.timestamp is from the block
 Be careful using block.timestamp for duration checks:
if (block.timestamp - startTime > 1 days) {}
This can fail if mining time is manipulated
Use block.number to check durations:
if (block.number - startBlock > 1 day blocks) {}

Resetting bids/offers:
Set a bidDuration and offerDuration variable
After that duration, mark bids/offers as expired
Add a resetBids() and resetOffers() function to delete expired ones
Could call reset periodically, e.g. every 1 day
To prevent stale bids/offers:
Set reasonable base durations for expiry like 1-2 days
Increase expiration if bid/offer is "active" - interacts with contract
Charge a small fee to discourage stale bids
Limit number of bids/offers per user
Remove very old stale bids first during resets
Have an exponential backoff on expiration time
Delete all bids/offers on finalization rather than expiring

Simple bid/offer acceptance logic:
Add an acceptBid() function that accepts the highest valid bid
Transfers collateral to bidder and bid amount to owner
Similarly acceptOffer() to accept lowest valid offer
Store bids and offers in mappings by address
Loop through bids/offers to find best bid/offer

Allow bid withdrawals:
Add a withdrawBid() function
Check msg.sender has a valid bid
Delete bid, transfer bid amount back
Make sure bid is not "active" e.g. highest
Emit events for transparency
Can limit withdrawals close to expiry
Similar logic for offer withdrawals

Partial Withdrawals
To allow partial withdrawals:
Store bid/offer amounts per user in a mapping
WithdrawBid would take a percent or amount to withdraw
Reduce the stored bid by that amount
Transfer the partial amount out
Check that bid remains above any minimum
Things to consider:
Incremental gas cost of multiple partial withdrawals
User experience - easy to mistakenly do partial
May want to limit to 1 or 2 partial withdrawals
Can have a minimum withdrawal percentage

Auction Dynamics
Bid withdrawals could affect auction dynamics by:
Removing bids affects order book and price discovery
Can leave gaps in the bid ladder
Highest bidder withdrawing may completely reset auction
Discourage bidding if easy to withdraw anytime
To limit effects:
Only allow withdrawal if bid no longer highest
Charge a withdrawal fee that increases closer to expiry
Limit withdrawal frequency, e.g. 1 per day
Disallow withdrawals in last 24 hours
Lower max bids if withdrawals allowed
The key is balancing flexibility with minimizing disruption to the auction.

Validate Bids Against Collateral
Add a collateralLimit mapping to store limits per option
When creating, set collateralLimit based on collateral deposited
In bid(), check that bid + premium <= collateralLimit
Consider factoring in units - bid/premium per unit
Could split collateralLimit into bidLimit and premiumLimit

Check Bid Amounts vs Balances
Before accepting a bid, check bidder balance covers amount
Use an ERC20 balanceOf() check if token collateral
For ETH, check eth.balance or use require() statement
Revert with error if balance too low





YET TO BE IMPLEMENTED
Make Oracle Interface Flexible
Create an abstract OracleInterface contract
Have functions like requestData and fulfillData
ChainlinkOracle contract inherits OracleInterface
OptionContract interacts through OracleInterface
Can easily swap oracle contracts this way
Use interface inheritance rather than concrete address

Base contract for modifiers:
Create a BaseContract that contains common modifiers
Have OptionContract inherit from BaseContract
Move modifiers like onlyOptionOwner, onlyValidTime etc to BaseContract
Override modifiers in OptionContract as needed

For user experience:
Document withdrawal and reset functionality in comments and docs
Emit events for withdrawals, resets and expirations
Notify users when their bids/offers are reset or expired
Allow a grace period before resetting to give warnings
Have a minimum bid/offer duration that can't be instantly reset
Clearly communicate bid and offer expiration rules

Some other ideas:
Allow users to selectively extend bid/offer durations
Analyze activity and optimize reset frequency



Implement the ones from this standard list not yet implemented:
createOption: Used to create a new option.
expireOption: Marks an option as expired.
exerciseOption: Allows an option holder to exercise their option.
cancelOption: Allows the owner to cancel an option before it expires.
settleOption: Settles the option, calculating and transferring profits or losses.
addCollateral: Adds collateral to an existing option.
removeCollateral: Removes collateral from an existing option.
getOptionDetails: Retrieves details of a specific option.
getAccountBalance: Returns the balance of a user's account in the contract.
getMarketData: Retrieves current market data, such as prices or rates.
updateOraclePrice: Updates the contract with the latest oracle price.
changeOptionOwner: Allows the transfer of ownership of an option.
setOptionParameters: Modifies the parameters of an existing option.
getExpirationTime: Returns the expiration time of a specific option.
getCollateralBalance: Retrieves the balance of a specific collateral in the contract.
getTotalValueLocked: Returns the total value locked in the contract.
getOptionsList: Returns a list of all active options.
getCollateralList: Returns a list of supported collateral tokens.
getOptionStatus: Retrieves the current status of a specific option.
emergencyShutdown: Initiates an emergency shutdown procedure.
etHistoricalPrices: Retrieves historical prices or rates for a specific asset.
setOptionFee: Sets or updates the fee structure for creating options.
getFeeDetails: Retrieves details about fees associated with the contract.
calculateOptionPayout: Calculates the potential payout for a given option.
getMarketTrends: Provides insights into current market trends.
setLeverage: Allows users to adjust the leverage for their positions.
getLiquidityPool: Retrieves information about the liquidity pool in the contract.
adjustLiquidity: Enables the adjustment of the liquidity pool.
getRiskMetrics: Calculates and returns risk metrics for the contract.
getCollateralizationRatio: Retrieves the current collateralization ratio.
setLiquidationThreshold: Sets the threshold for triggering liquidation.
triggerLiquidation: Initiates the liquidation process for undercollateralized positions.
getUnderlyingAsset: Returns the underlying asset associated with an option.
setOracle: Updates the oracle used for price feeds.
getExpirationSchedule: Provides a schedule of upcoming option expirations.
setOptionLimits: Defines limits on the size or parameters of new options.
getUserOptions: Returns a list of options associated with a specific user.
getMarketVolatility: Retrieves the current volatility of the market.
setOptionVisibility: Controls the visibility of certain options in the contract.
getContractParameters: Retrieves general parameters and settings for the contract.
adjustOptionExpiry: Allows adjustment of the expiration date for a specific option.
getOpenInterest: Retrieves the open interest for a particular series of options.
setOptionExerciseWindow: Defines a window during which options can be exercised.
getContractVersion: Returns the current version or implementation of the contract.
setFundingRate: Sets the funding rate for perpetual options.
getMarketSentiment: Provides data on market sentiment for a specific asset.
getCollateralReserve: Retrieves information about the collateral reserve in the contract.
setEmergencyShutdown: Initiates an emergency shutdown of the contract.
getLiquidityProviders: Returns a list of addresses providing liquidity to the contract.
setOptionSeriesParameters: Configures parameters specific to an option series.
getTradingVolume: Provides information on the trading volume within the contract.
setContractPause: Temporarily pauses certain contract functions.
getMarketLiquidity: Retrieves data on overall market liquidity.
setOptionAutoExercise: Enables or disables automatic exercise of options upon expiry.
getContractStatus: Returns the current status of the contract (active, paused, shutdown, etc.).
setOptionSeriesVisibility: Controls the visibility of specific option series.
getMarketCap: Retrieves the market capitalization of a particular asset.
setRiskParameters: Configures parameters related to risk management.
getSystemHealth: Provides an overview of the system's health and performance.
setOptionExerciseFee: Sets a fee for exercising options.
setOptionStrikePrice: Allows updating the strike price of a specific option.
getMarketFees: Retrieves information about fees associated with trading on the platform.
setMarketOracle: Sets or updates the oracle responsible for providing price feeds.
getMarketVolatility: Provides data on the volatility of the market.
setOptionSeriesFee: Configures fees specific to an entire series of options.
getMarketHistoricalData: Retrieves historical price and volume data for an asset.
setLiquidityProviderFee: Sets fees for users providing liquidity to the contract.
getMarketOptions: Returns a list of available options for a specific asset.
setCollateralizationRatio: Adjusts the collateralization ratio required for options.
getMarketDividends: Provides information on dividends associated with the market.
setOptionSeriesRestrictions: Configures restrictions on trading for a series of options.
getMarketVesting: Retrieves details about vesting schedules associated with assets.
setMarketParameters: Configures general parameters for the entire market.
getMarketInsurance: Provides information on insurance coverage for the market.
setMarketLeverage: Adjusts the leverage available for trading on the market.
getOptionPremium: Calculates and returns the current premium for a specific option.
setOptionLiquidityRequirement: Sets requirements for liquidity provision for options.
getOptionExerciseWindow: Retrieves the exercise window for a specific option.
setOptionAutoRoll: Enables or disables automatic rolling of options positions.
getOptionUnderlying: Returns the underlying asset of a specific option.
setOptionApproval: Manages the approval status of a specific option series.
getOptionGreeks: Calculates and returns the Greeks (e.g., delta, gamma) for an option.
setOptionPositionLimits: Configures limits on the size of options positions.
getOptionStrikeWindow: Retrieves the acceptable strike price range for an option.
setMarketLiquidation: Configures rules and parameters for market liquidation.


*/
```


