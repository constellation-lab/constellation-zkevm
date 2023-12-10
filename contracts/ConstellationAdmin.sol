 //Contains the globally accessed state that is needed across different contract 
// SPDX-License-Identifier: MIT
//pragma solidity ^0.8.9;
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-v0.7/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-v0.7/math/SafeMath.sol";
import "@openzeppelin/contracts-v0.7/access/Ownable.sol";

import "./ChainlinkMock.sol";
import "./ConstellationCore.sol"; // Import the core contract interface


 interface IConstellationCore {
        function unpause() external;
        function pause() external;   
        function getCreator() external view returns (address);
        function setCreator(address newCreator) external;
 }


contract ConstellationAdmin is Ownable {
    using SafeMath for uint256;

    IConstellationCore public core; // Reference to ConstellationCore

    constructor(address coreAddress) public {
        core = IConstellationCore(coreAddress);
    }

    // Function to set the creator address
    function setCreator(address newCreator) external onlyOwner {
        require(msg.sender == core.getCreator(), "Unauthorized: Only creator can call this function");
        core.setCreator(newCreator);
    }

    // Function to pause the contract
    function pause() external onlyOwner {
        require(msg.sender == core.getCreator(), "Unauthorized: Only creator can call this function");
        core.pause();
    }

    // Function to unpause the contract
    function unpause() external onlyOwner {
        require(msg.sender == core.getCreator(), "Unauthorized: Only creator can call this function");
        core.unpause();
    }

    // Function to add an oracle address
   /* function addOracle(address oracleAddress) external onlyOwner {
        require(msg.sender == core.getCreator(), "Unauthorized: Only creator can call this function");
        core.addOracle(oracleAddress);
    }*/
}
