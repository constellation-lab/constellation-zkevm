// ChainlinkMock.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.6.8;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract ChainlinkMock is VRFConsumerBase {
    bytes32 internal keyHash;
    uint256 internal fee;

    uint256 private _randomNumber;
    uint256 private _requestCounter;

    address private vrfCoordinator;


    event RandomNumberRequested(bytes32 indexed requestId);
    event RandomNumberFulfilled(bytes32 indexed requestId, uint256 randomness);

    constructor(address _vrfCoordinator, bytes32 _keyHash, uint256 _fee, address _link)
        VRFConsumerBase(_vrfCoordinator, _link) public
    {
        keyHash = _keyHash;
        fee = _fee;
        vrfCoordinator = _vrfCoordinator;  // Add this line to initialize vrfCoordinator
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        require(msg.sender == vrfCoordinator, "Only VRF Coordinator can fulfill");
        require(requestId == bytes32(_requestCounter), "Invalid requestId");

        _randomNumber = randomness;
        emit RandomNumberFulfilled(requestId, randomness);
    }

    function mockRequestRandomNumber() external {
        _requestCounter++;
        requestRandomness(keyHash, fee);
        emit RandomNumberRequested(bytes32(_requestCounter));
    }

    function latestRandomNumber() external view returns (uint256) {
        return _randomNumber;
    }

    function latestRequestId() external view returns (bytes32) {
        return bytes32(_requestCounter);
    }

    function resetState() external {
        // Reset state variables to their initial values
        keyHash = 0x0;
        fee = 0;
        _randomNumber = 0;
        _requestCounter = 0;

        // Additional state variables specific to your Chainlink mock, if any
    }
}
