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
- ***Features added to this version***
A. Add bidding and offering functionality:
-   Allow users to place bids and offers for options
-   Maintain mapping of bids and offers by user
-   Allow accepting best bid/offer to sell option
B. Integrate with Chainlink oracle for real-time pricing:
-    Request latest price for a marketpair
-    Fulfill latest price to use in executions
C. Improve option lifecycle management:
-   Allow early withdrawal of collateral
-   Enable extending expiration time
-   Add pausing functionality
D. Enhance access controls:
-   Make critical functions onlyOwner
-   Add an onlyCreator modifier
-   Allow transferring creator role
E. Add time buffers before expiry:
-   To prevent last minute sniping
-   Configurable buffer duration
F. Implement partial withdrawals:
-   Allow users to withdraw a % of their bid
G. Analyze market activity:
-   Add functions to analyze bids/offers
-   Determine if market is active
H. Emit more events for transparency:
-   All state changes should emit events
I. Additional test cases:
-   Focus on security and edge cases
-   Use mocks for external dependencies
J. Gas optimization:
-   Add modifiers to limit gas usage
-   Use paginated returns for mappings

***Features Tracking Information:***
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



