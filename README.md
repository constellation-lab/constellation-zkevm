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
## Constellation Derivative (Fullstack) Dapp zkEVM Version
- ***Features added to this version***
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



