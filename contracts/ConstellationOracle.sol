// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "./ConstellationCore.sol"; // Import the core contract interface
import "@openzeppelin/contracts-v0.7/access/Ownable.sol";
import "@openzeppelin/contracts-v0.7/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-v0.7/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract ConstellationOracle is Ownable, VRFConsumerBase {
    using SafeMath for uint256;

    uint256 public latestPrice;
    address public chainlinkOracle;

    bytes32 public keyHash;
    uint256 public fee;

    ConstellationCore public core; // Reference to ConstellationCore

    constructor(address coreAddress, address linkToken, address vrfCoordinator, bytes32 _keyHash, uint256 _fee)
        VRFConsumerBase(vrfCoordinator, linkToken)
        public
    {
        //core = ConstellationCore(coreAddress);
        core = ConstellationCore(payable(coreAddress));
        chainlinkOracle = address(this); // Set the oracle address as the contract itself
        keyHash = _keyHash; // Set the key hash for Chainlink VRF
        fee = _fee; // Set the fee for Chainlink VRF
    }

    // Function to update the price by the oracle
    function updatePrice(/*uint256 optionId, string calldata denom, uint256 expirationTime,*/ bytes32 requestId) external {
        //require(core.isOracle(msg.sender), "Unauthorized: Only registered oracles can update price");
        // Use Chainlink VRF to get the latest price
        requestId = requestRandomness(keyHash, fee);
    }

    // Function to fulfill the price by the oracle
    function fulfillPrice(/*uint256 optionId,*/ uint256 randomNumber) external onlyOwner {
        require(msg.sender == chainlinkOracle, "Unauthorized: Only Chainlink oracle can fulfill price");
        latestPrice = randomNumber;
        //core.fulfillPrice(optionId, randomNumber);
    }

    // Function to fulfill the price by the oracle
    function fulfillRandomness(bytes32 requestId, uint256 randomNumber) internal override {
        // Your implementation here, e.g., update latestPrice and call core.fulfillPrice
    }

    // Function to execute the option
    function executeOption(bytes32 requestId) external {
        //require(core.isOracle(msg.sender), "Unauthorized: Only registered oracles can execute option");
        core.executeOptionWithRandomness(requestId);
    }

    // Function to add an option to the market using Chainlink (calling from ConstellationCore)
    function addToMarketChainlink(/*uint256 optionId, string calldata denom, uint256 expirationTime*/) external view{
        require(msg.sender == owner(), "Unauthorized: Only owner can add options using Chainlink");
        //core.addToMarketChainlink(optionId, denom, expirationTime);
    }

    // Function to buy an option using Chainlink (calling from ConstellationCore)
    function buyOptionChainlink(/*uint256 optionId*/) external view {
        require(msg.sender == owner(), "Unauthorized: Only owner can buy options using Chainlink");
        //core.buyOptionChainlink(optionId);
    }

    // ... (other oracle functions)

    // Owner function to get the contract owner



}
