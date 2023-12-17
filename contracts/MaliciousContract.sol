// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ConstellationCore.sol";

contract MaliciousContract {
    ConstellationCore public target;
    mapping(address => uint256) public balances;

    constructor(ConstellationCore _target)  {
        target = _target;
    }

    receive() external payable {
        // Perform reentrancy attack by calling the target contract's fallback function
        (bool success, ) = address(target).call{value: msg.value}("");
        require(success, "Reentrancy attack failed");

        // Additional logic for the attack, if needed
        // For example, continue the attack by calling other functions in the target contract
       // target.requestPriceData();
    }

    function attack(/*uint256 optionId*/) external payable {
        // Trigger the reentrancy attack in the receive function
        //address(this).call{value: msg.value}("");

        (bool success, ) = address(this).call{value: msg.value}("");
        require(success, "Reentrancy attack failed");


        // Additional logic for the attack, if needed
        // For example, continue the attack by calling other functions in the malicious contract
        someFunction();
    }

    function withdrawFunds() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No funds to withdraw");

        // Transfer funds to the caller using payable(msg.sender).transfer(amount);
        payable(msg.sender).transfer(amount);

        // Update the balance
        balances[msg.sender] = 0;
    }

    function someFunction() internal {
        // Trigger a withdrawal in the target contract
        //target.withdrawCollateral();
    }
}
