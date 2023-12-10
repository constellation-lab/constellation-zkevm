# Constellation - zkEVM

This project demonstrates a Hardhat use case for zero knowledge proofs EVM Constellation Derivative Contract. It also comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat compile --force
npx hardhat run scripts/deploy.js

npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```
## Constellation Derivative (Fullstack) Dapp zkEVM Version
- **Features added to this version**
- ***A. Add bidding and offering functionality:***
-   Allow users to place bids and offers for options
-   Maintain mapping of bids and offers by user
-   Allow accepting best bid/offer to sell option
- ***B. Integrate with Chainlink oracle for real-time pricing:***
-    Request latest price for a marketpair
-    Fulfill latest price to use in executions
- ***C. Improve option lifecycle management:***
-   Allow early withdrawal of collateral
-   Enable extending expiration time
-   Add pausing functionality
- ***D. Enhance access controls:***
-   Make critical functions onlyOwner
-   Add an onlyCreator modifier
-   Allow transferring creator role
- ***E. Add time buffers before expiry:***
-   To prevent last minute sniping
-   Configurable buffer duration
- ***F. Implement partial withdrawals:***
-   Allow users to withdraw a % of their bid
- ***G. Analyze market activity:***
-   Add functions to analyze bids/offers
-   Determine if market is active
- ***H. Emit more events for transparency:***
-   All state changes should emit events
- ***I. Additional test cases:***
-   Focus on security and edge cases
-   Use mocks for external dependencies
- ***J. Gas optimization:***
-   Add modifiers to limit gas usage
-   Use paginated returns for mappings

***Features Implemented - Additional Information:***
- Added partial execution of an option by owner.
- Added an oracle for the latest price into the contract for market options.
- Allow fraction of an option to be traded.
- Considered and tested re-entrancy.
- Allow ERC20 tokens as collateral instead of only Ether.
- Add a pause/unpause ability for emergencies.
- Allow bids/offers instead of direct fixed prices.
- Add time buffers before expiry for executions.
- Added a cancelOption function to allow owner to cancel before expiry.
- Allow owner to withdraw collateral early if not executed.
- Validate addresses intransferOption and addToMarket.
- Separate collateral from premiums paid - have collateral returned in all cases.
- Added error messages for require statements to make debugging easier.
- Use SafeMath for subtraction as well to prevent underflows.
- Allow array params like counterOffer and price to be variable length rather than fixed size.
- Split Modifiers into reusable ones in a base contract.
- Added Logging and events are good for transparency.
- Added Mapping structures are efficient for storage.


Docs Info:

createOption
Creates a new option. It takes in parameters like collateral and counter offer, does validation, transfers collateral, generates an ID, saves option data to storage, and emits events. Key steps are validating expiration time, transferring collateral, saving data to multiple maps, incrementing option count.
transferOption
Transfers ownership of an option. It first loads the option data, validates sender is the owner and option is not expired. It then updates the owner, saves updated data, emits events. Critical checks are done on sender and expiration before storage is updated.
addToMarket
Puts an option up for sale. It loads the option, validates sender is owner and option is not expired. It sets status to OnSale, saves updated data with price to storage, emits events. Key validation on expiration and owner before allowing market listing.
removeFromMarket
Delists an option from market. Loads option data, checks sender is owner. Sets status back to Created, removes from market listing, saves option data, emits event. Critical step is verifying owner before allowing delisting.
buyOption
Purchase an option. Fetches market listing, verifies sent payment equals listed price, transfers collateral and premiums, updates storage ownership, emits events. Key validation on payment matching list price before transfer and ownership update.
executeOption
Exercise an option. Loads option data, checks sender is owner, option is not expired or stale. Calculates total price and option price. Validates option is profitable. Transfers collateral and premiums. Burns option data in storage, emits events. Critical validations on profitability and transfers done before burning.
claimOption
Claim expired option collateral. Loads option data, checks current time past expiration. Sends collateral to creator, premiums to owner. Burns option data, emits events. Key check on expiration before allowing claim and data removal.
bid
Place bid on option. Validates inputs, calculates total bid value. Transfers bid amount to contract. Updates bid mapping, market data, price mapping. Emits events. Critical to first validate and transfer assets before updating bid state.
offer
Make offer for option. Calculations total offer value, transfers offer amount, updates mappings with offer data and price info. Emits events. Same pattern of validating and transferring before storage updates.
acceptBid
Accept highest bid on option. Finds highest valid bidder and amount using mappings. Checks bidder has enough balance. Transfers collateral and bid amount. Clears bid data, updates option status. Emits events. Leverages mapped data then properly resets state.
acceptOffer
Accept best offer on option. Finds lowest valid offer using price mapping. Checks balance covers offer. Transfers amounts, clears offer data, updates status, emits events. Same pattern of using existing mapped data before state changes.
cancelOption
Cancel market listing without sale. Validates status and sender. Sets back to Created status, removes from market listing. Emits event. Critical to verify status allowing cancel before data removed.
withdrawBid
Withdraw placed bid. Checks for valid bid. Ensures not highest bid. Removes bid data, sends amount back. Emits events. Checks bid amount and status before removal to protect auctions.
burnOption
Burn an option token. Loads option data, checks sender is owner and not expired. Sends back collateral to owner. Burns all option storage data. Emits event. Critical to validate ownership and status before allowing burn.
extendBidDuration
Extend bid duration. Validates additional duration param passed in. Uses SafeMath to prevent overflow. Updates expire time in option storage. Emits event. Care taken to safely update expiration slot.
withdrawPartialBid
Withdraw part of a placed bid. Checks for user's active bid. Validates percentage param. Calculates partial amount from total bid. Ensures bid remains over minimum. Updates bid amount, sends coins back. Emits event. Careful split of bid before state update.
withdrawCollateral
Withdraw collateral. Loads option data. Checks ownership and option has not expired. Validates non-active status. Transfers collateral to owner. Burns storage. Emits event. Critical checks on expiration and status before coin transfer.
setOptionParameters
Set custom parameters. Loads option data. Validates sender is creator. Updates parameters mapping in storage. Emits event. Checks creator permission before state update.
getOptionHistory
Get historical option data. Tries to load option by ID. Emits custom history event. Placeholder returns option's history array. This would compose historical data from various sources into array returned.
provideLiquidity
Provide liquidity to option pool. Loads option data, checks current time before expiration. Placeholder logic to mint LP tokens as liquidity. Transfers tokens to user, emits event. Validates active status before business logic.
withdrawLiquidity
Withdraw liquidity from option pool. Loads option, checks not expired. Placeholder logic to burn LP tokens and return assets. Transfers tokens back, emits event. Checks status then executes liquidity removal.
voteOnGovernance
Vote on governance proposal. Loads proposed option data, checks not expired. Placeholder logic to send vote message to external governance module. Constructs proposal vote message, emits custom event. Relies on governance module after status check.
useOptionAsCollateral
Use option as collateral. Loads option data, checks current time before expiration. Placeholder logic to send collateral usage notification to external module. Constructs message, emits event. Status check before downstream notification.
wrapForYieldFarming
Wrap option token for yield farming program. Loads option, checks expiration time. Placeholder logic to wrap and notify yield farming module. Sends message, emits event on status validation.
integrateDataFeed
Integrate market data feed. Loads option data, checks expiration time. Placeholder logic to integrate data feed in downstream module. Sends integration message, emits event on status check.
executePause
Pause contract. Loads config state data. Validates sender is admin. Updates paused flag to true in config storage. Emits custom paused event. Simple admin-only state update.
executeUnpause
Unpause contract. Loads config, checks admin sender. Sets paused to false in storage. Emits unpaused event. Another basic permissioned state update.
addOracle
Add price oracle module. Loads config state. Validates admin sender. Updates oracle address slot in storage. Emits custom event for oracle addition. Basic admin-privileged storage update.
updatePriceOracle
Update option price from oracle. Tries to load market option. Check current time before expiry. Validates configured oracle. Fetches latest price from oracle module. Updates option price in storage. Emits price updated event. Logic flow respects expiration and external price data.
notifyOptionExpiry
Expiration notification. Loads option data. Checks current block time is within window before expiry. Placeholder notification logic. Constructs response, emits event on timing validation. Key check to only notify when close to expiration.
setExerciseConditions
Set option exercise conditions. Loads option data, validates sender is creator. Updates exercise conditions array in storage. Emits event for conditions update. Checks permission before storage update.
calculateRiskMetrics
Calculate option risk metrics. Tries to load option by ID, placeholders sample risk calculations. Constructs risk metrics mapping, emits event with data. This would eventually compose meaningful risk analytics.
createAmmPool
Creates AMM pool for option. Loads option data, checks current time before expiry. Placeholder logic to create pool in separate AMM module. Sends pool creation message, emits event. Expiry check before downstream action.
tradeOnAmm
Trade option via AMM pool. Placeholder validation logic on trade amounts. Placeholder logic to execute trade in AMM module. Sends trade message with data, emits event. Simple flow before compositing full logic.
referUser
Refer new user. Defines referral reward. Transfers reward to referring user. Emits custom event with referral data. Simple reward payout on referral with tracking attributes.
setDiscountCriteria
Set user discount criteria. Validates and loads user discount state. Inserts criteria rules into user's storage based on sender. Saves updated discounts, emits event. Simple per-user criteria update.
///////////

Planned: 
renewOption
Renews an expired option. Placeholder logic to validate new expiration time. Transfers collateral delta from owner. Resets expiration in storage. Emits custom renewal event. Basic expired option revival flow.
fractionalizeOption
Fractionalize option into shares. Validates fraction units parameter. Placeholder logic to mint erc20 shares, backed by option collateral. Updates total shares state. Emits event for shares minted. Core fractionalization workflow.
redeemOptionShares
Redeems option shares for underlying collateral. Checks sender share balance sufficient for redemption Units. Placeholder to burn shares and unlock collateral. Transfers coins, updates state, emits event. Critical share burn before asset transfers.
liquidateUndercollateralizedOption
Liquidates an undercollateralized option. Placeholder logic to check current collateralization ratio. Transfers out remaining coins. Burns all storage data. Emits liquidation event. Important state cleanup logic.
cancelExpiredBids
Cancels expired bids on option. Loops through bid mappings by bid price. Checks if bid expiration has passed. Deletes bid data, emits events. Cleans up stale bids poisoning auctions.
sweepCommissionFees
Sweeps commission fees to admin. Defines storage for tracking volume and fees. Placeholder logic to calculate owed fees based on trade volumes. Transfers fee coins to admin. Resets volume stats. Basic fee sweeping.
batchTransferOptions
Batch transfers multiple options. Loops through array of transfer data structs. Calls transferOption for each struct. Checks for any failed transfers in batch. Emits batch event with transfer results. Useful bulk operation tool.
batchBurnOptions
Batch burns multiple options. Loops through passed in array of option IDs. Calls burnOption on each ID. Checks for any failures burning options. Emits event with array of burned ID results. Convenient bulk option burn mechanism.
splitMergedOptions
Splits any incorrectly merged option tokens back to original IDs. Loops through passed in array of merged token IDs. Calls internal split function to separate tokens. Transfers split tokens to owner addresses. Emits event with split results. Useful to recover from improper token merges.
recoverLostCoins
Allows admin to withdraw any tokens erroneously sent to contract. Checks caller is authorized owner. Allows withdrawal of specified token type and amount. Transfers recovered coins to owner. Emits event on recovery. Important admin power to avoid lost funds.
upgradeContract
Helper to support seamless upgrading of contract logic. Validates caller is authorized owner. Placeholder logic to perform low-level delegation and storage manipulation allowing logic contract upgrade while preserving state. Emits event signaling upgrade. Key ability for long-term maintainability.
registerApprovedTransferAgents
Whitelists addresses that can transfer options on behalf of users. Checks for owner caller. Adds provided address to stored transfer agents registry. Emits event with registered agent address. Allows flexibility for user-approved delegation.
setMaxOraclePriceAge
Ensures oracle prices fall within configured maximum age. Validates caller is authorized owner. Sets passed in duration as the max allowed oracle price age. Reverts if age exceeded. This guarantees fresh price data.
addStablecoinDenoms
Manages list of accepted stablecoin collateral types. Checks for owner caller. Adds passed in token denom to stored registry of accepted stablecoins. Useful to control collateral risk exposure.
setCollateralBuffer
Configures % buffer between collateral value and dues. Validates caller is owner. Sets passed in basis point buffer percentage. Ensures dues do not exceed buffered collateral value. Manages collateral risk.
slashStaleBids
Applies fee for bids not adjusted close enough to expiration. Fetches bid mapping for option. Checks if bid expiration too close to option expiration. Applies configured slashing percentage. Disincentives stale bids. Could integrate with oracles.




