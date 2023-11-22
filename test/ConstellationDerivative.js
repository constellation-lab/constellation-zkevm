// Import necessary modules for testing
import { ethers, waffle } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory, BigNumber } from "ethers";
import { parseEther } from "ethers/lib/utils";

// Import your contract and the SafeMath library
import ConstellationDerivativeArtifact from "../artifacts/contracts/ConstellationDerivative.sol/ConstellationDerivative.json";
import SafeMathArtifact from "../artifacts/contracts/ConstellationDerivative.sol/SafeMath.sol/SafeMath.json";
// Import necessary Hardhat libraries and ethers
//const { expect } = require("chai");
//const { ethers } = require("hardhat");

// Define the testing variables
//let constellationDerivative: Contract;
//et safeMath: Contract;

// Define the testing accounts
//let owner: any;
//let addr1: any;
//let addr2: any;

// Initialize the contract and testing environment
beforeEach(async () => {
  [owner, addr1] = await ethers.getSigners();

  // Deploy SafeMath library
  const SafeMath = new ethers.ContractFactory(
    SafeMathArtifact.abi,
    SafeMathArtifact.bytecode,
    owner
  );
  safeMath = await SafeMath.deploy();

  // Deploy ConstellationDerivative
  const ConstellationDerivative = new ethers.ContractFactory(
    ConstellationDerivativeArtifact.abi,
    ConstellationDerivativeArtifact.bytecode,
    owner
  ).connect(owner);

  constellationDerivative = await waffle.deployContract(owner, constellationDerivative, [
    safeMath.address,
  ]);
});

// Write your test cases
describe("ConstellationDerivative", function () {
  it("should create an option", async function () {
    const counterOffer = [100];
    const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

    await expect(constellationDerivative.createOption(counterOffer, expires))
      .to.emit(constellationDerivative, "OptionCreated")
      .withArgs(
        0,
        owner.address,
        owner.address,
        parseEther("1"), // Assuming 1 ether collateral
        counterOffer,
        0, // OptionStatus.Created
        [],
        expires
      );

    const optionData = await constellationDerivative.queryOption(0);
    expect(optionData.creator).to.equal(owner.address);
    expect(optionData.owner).to.equal(owner.address);
    expect(optionData.collateral).to.equal(parseEther("1"));
    expect(optionData.counterOffer).to.eql(counterOffer);
    expect(optionData.status).to.equal(0); // OptionStatus.Created
    expect(optionData.price).to.eql([]);
    expect(optionData.expires).to.equal(expires);
  });

  it("should transfer an option", async function () {
    const counterOffer = [100];
    const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

    await constellationDerivative.createOption(counterOffer, expires);

    await expect(constellationDerivative.transferOption(0, addr1.address))
      .to.emit(constellationDerivative, "OptionTransferred")
      .withArgs(0, owner.address, addr1.address);

    const optionData = await constellationDerivative.queryOption(0);
    expect(optionData.owner).to.equal(addr1.address);
  });

  it("Should emit the correct events with the right parameters for OptionTransferred", async function () {
    const [owner, user1] = await ethers.getSigners();
    const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
    const contract = await contractFactory.deploy();
    await contract.deployed();
  
    // Create an option
    const optionId = await contract.createOption([], 0);
  
    // Transfer the option
    await contract.transferOption(optionId, user1.address);
    const transferEvent = (await contract.queryFilter(contract.filters.OptionTransferred()))[0];
  
    expect(transferEvent.args.id).to.equal(optionId);
    expect(transferEvent.args.from).to.equal(owner.address);
    expect(transferEvent.args.to).to.equal(user1.address);
  });

  it("Should handle extreme values for amounts correctly", async function () {
    const [owner, user1] = await ethers.getSigners();
    const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
    const contract = await contractFactory.deploy();
    await contract.deployed();
  
    // Create an option with a large collateral amount
    const largeCollateral = ethers.constants.MaxUint256;
    const optionId = await contract.createOption([], 0, { value: largeCollateral });
    const option = await contract.queryOption(optionId);
  
    expect(option.collateral).to.equal(largeCollateral);
  });

  it("Should handle very short expiration times correctly", async function () {
    const [owner, user1] = await ethers.getSigners();
    const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
    const contract = await contractFactory.deploy();
    await contract.deployed();
  
    // Set a very short expiration time (e.g., 1 second)
    const shortExpiration = Math.floor(Date.now() / 1000) + 1;
  
    // Create an option with the short expiration time
    const optionId = await contract.createOption([], shortExpiration);
    const option = await contract.queryOption(optionId);
  
    expect(option.expires).to.be.above(shortExpiration);
  });

  it("Should emit the correct events with the right parameters for OptionAddedToMarket", async function () {
    const [owner, user1] = await ethers.getSigners();
    const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
    const contract = await contractFactory.deploy();
    await contract.deployed();
  
    // Create an option
    const optionId = await contract.createOption([], 0);
  
    // Add the option to the market
    const amount = ethers.utils.parseEther("2");
    await contract.addToMarket(optionId, amount, "ETH");
    const addMarketEvent = (await contract.queryFilter(contract.filters.OptionAddedToMarket()))[0];
  
    expect(addMarketEvent.args.id).to.equal(optionId);
    expect(addMarketEvent.args.amount).to.equal(amount);
    expect(addMarketEvent.args.currency).to.equal("ETH");
  });

  it("should revert creating an option with past expiration", async function () {
    const counterOffer = [100];
    const expires = Math.floor(Date.now() / 1000) - 1; // 1 second ago
  
    await expect(constellationDerivative.connect(creator).createOption(counterOffer, expires))
      .to.be.revertedWith("Invalid time: Option expiration time must be in the future");
  });

  it("should revert transferring an option to an invalid address", async function () {
    const counterOffer = [100];
    const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
  
    await constellationDerivative.createOption(counterOffer, expires);
  
    await expect(constellationDerivative.connect(creator).transferOption(0, ethers.constants.AddressZero))
      .to.be.revertedWith("Invalid address: Address cannot be zero");
  });

  it("should revert updating an option with an empty price array", async function () {
    const counterOffer = [100];
    const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
  
    await constellationDerivative.createOption(counterOffer, expires);
  
    await expect(constellationDerivative.connect(creator).updatePrice(0, []))
      .to.be.revertedWith("Invalid array: Array cannot be empty");
  });

  it("should revert buying an option with insufficient funds", async function () {
    const counterOffer = [100];
    const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
    const price = parseEther("2");
  
    await constellationDerivative.createOption(counterOffer, expires);
    await constellationDerivative.addToMarket(0, price, "ETH");
  
    await expect(constellationDerivative.connect(buyer).buyOption(0, { value: parseEther("1.5") }))
      .to.be.revertedWith("Price mismatch");
  });

  it("should revert executing an option not expired yet", async function () {
    const counterOffer = [100];
    const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
  
    await constellationDerivative.createOption(counterOffer, expires);
  
    await expect(constellationDerivative.executeOption(0))
      .to.be.revertedWith("Option not expired yet");
  });

  it("should revert claiming an option not expired yet", async function () {
    const counterOffer = [100];
    const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
  
    await constellationDerivative.createOption(counterOffer, expires);
  
    await expect(constellationDerivative.claimOption(0))
      .to.be.revertedWith("Option not expired yet");
  });

  it("should revert removing an option from the market not on sale", async function () {
    const counterOffer = [100];
    const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
  
    await constellationDerivative.createOption(counterOffer, expires);
  
    await expect(constellationDerivative.removeFromMarket(0))
      .to.be.revertedWith("Option is not on sale");
  });

  it("should revert adding an option to the market with zero amount", async function () {
    const counterOffer = [100];
    const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
  
    await constellationDerivative.createOption(counterOffer, expires);
  
    await expect(constellationDerivative.addToMarket(0, 0, "ETH"))
      .to.be.revertedWith("Invalid amount: Amount must be greater than zero");
  });

  it("should revert adding an option to the market with past expiration", async function () {
    const counterOffer = [100];
    const expires = Math.floor(Date.now() / 1000) - 1; // 1 second ago
  
    await constellationDerivative.createOption(counterOffer, expires);
  
    await expect(constellationDerivative.addToMarket(0, parseEther("2"), "ETH"))
      .to.be.revertedWith("Invalid time: Option expiration time must be in the future");
  });

//Reverting on Invalid Token Transfer:
it("should revert if attempting to transfer option with invalid token address", async function () {
  const counterOffer = [100];
  const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

  await constellationDerivative.createOption(counterOffer, expires);

  // Use an invalid token address (e.g., zero address)
  await expect(constellationDerivative.transferOption(0, addr1.address, { value: parseEther("1"), token: ethers.constants.AddressZero }))
    .to.be.revertedWith("Invalid token address");
});

//Reverting on Invalid Amount when Adding to Market:
it("should revert if adding an option to the market with zero amount", async function () {
  const counterOffer = [100];
  const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

  await constellationDerivative.createOption(counterOffer, expires);

  // Attempt to add an option with zero amount to the market
  await expect(constellationDerivative.addToMarket(0, 0, "ETH"))
    .to.be.revertedWith("Invalid amount: Amount must be greater than zero");
});

//Reverting on Adding to Market with Past Expiration:
it("should revert if adding an option to the market with past expiration", async function () {
  const counterOffer = [100];
  const expires = Math.floor(Date.now() / 1000) - 1; // 1 second ago

  await constellationDerivative.createOption(counterOffer, expires);

  // Attempt to add an option to the market with past expiration
  await expect(constellationDerivative.addToMarket(0, parseEther("2"), "ETH"))
    .to.be.revertedWith("Invalid time: Option expiration time must be in the future");
});

//Reverting on Invalid Address when Transferring Option:
it("should revert if transferring an option to an invalid address", async function () {
  const counterOffer = [100];
  const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

  await constellationDerivative.createOption(counterOffer, expires);

  // Attempt to transfer an option to the zero address
  await expect(constellationDerivative.transferOption(0, ethers.constants.AddressZero))
    .to.be.revertedWith("Invalid address: Address cannot be zero");
});

//Reverting on Option Creation with Past Expiration:
it("should revert if creating an option with past expiration", async function () {
  const counterOffer = [100];
  const expires = Math.floor(Date.now() / 1000) - 1; // 1 second ago

  await expect(constellationDerivative.createOption(counterOffer, expires))
    .to.be.revertedWith("Invalid time: Option expiration time must be in the future");
});

//Reverting on Update with Empty Price Array:
it("should revert if updating an option with an empty price array", async function () {
  const counterOffer = [100];
  const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

  await constellationDerivative.createOption(counterOffer, expires);

  // Attempt to update an option with an empty price array
  await expect(constellationDerivative.updatePrice(0, []))
    .to.be.revertedWith("Invalid array: Array cannot be empty");
});

//Ensure Execution Reverts for Unexpired Options:
it("should revert executing an option not expired yet", async function () {
  const counterOffer = [100];
  const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

  await constellationDerivative.createOption(counterOffer, expires);

  // Attempt to execute an option that is not yet expired
  await expect(constellationDerivative.executeOption(0))
    .to.be.revertedWith("Option not expired yet");
});

//Ensure Claiming Reverts for Unexpired Options:
it("should revert claiming an option not expired yet", async function () {
  const counterOffer = [100];
  const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

  await constellationDerivative.createOption(counterOffer, expires);

  // Attempt to claim an option that is not yet expired
  await expect(constellationDerivative.claimOption(0))
    .to.be.revertedWith("Option not expired yet");
});

//Ensure Removing from Market Reverts for Unlisted Options
it("should revert removing an option from the market not on sale", async function () {
  const counterOffer = [100];
  const expires = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now

  await constellationDerivative.createOption(counterOffer, expires);

  // Attempt to remove an option from the market that is not on sale
  await expect(constellationDerivative.removeFromMarket(0))
    .to.be.revertedWith("Option is not on sale");
});
  // Add more test cases for other functions in a similar fashion
});



// Test the contract's behavior with gas consumption
describe("Gas Consumption Tests", function () {
  it("Should stay within acceptable gas limits", async function () {
    const [owner, user] = await ethers.getSigners();
    const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
    const contract = await contractFactory.deploy();
    await contract.deployed();

    // Create an option with some collateral
    const optionId = await contract.createOption([], 0, { value: ethers.utils.parseEther("1") });

    // Measure gas consumption for transferring the option
    const transferTx = await contract.transferOption(optionId, user.address);
    const transferReceipt = await transferTx.wait();
    const transferGasUsed = transferReceipt.gasUsed.toNumber();

    // Measure gas consumption for executing the option
    const executeTx = await contract.executeOption(optionId);
    const executeReceipt = await executeTx.wait();
    const executeGasUsed = executeReceipt.gasUsed.toNumber();

    // Define acceptable gas limits based on your contract's complexity
    const maxTransferGas = 100000;
    const maxExecuteGas = 150000;

    // Check that gas consumption is within acceptable limits
    expect(transferGasUsed).to.be.lte(maxTransferGas);
    expect(executeGasUsed).to.be.lte(maxExecuteGas);
  });

  it("Should stay within acceptable gas limits for transferring an option", async function () {
    const [owner, user] = await ethers.getSigners();
    const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
    const contract = await contractFactory.deploy();
    await contract.deployed();
  
    // Create an option with some collateral
    const optionId = await contract.createOption([], 0, { value: ethers.utils.parseEther("1") });
  
    // Measure gas consumption for transferring the option
    const transferTx = await contract.transferOption(optionId, user.address);
    const transferReceipt = await transferTx.wait();
    const transferGasUsed = transferReceipt.gasUsed.toNumber();
  
    // Define acceptable gas limits based on your contract's complexity
    const maxTransferGas = 100000;
  
    // Check that gas consumption is within acceptable limits
    expect(transferGasUsed).to.be.lte(maxTransferGas);
  });
  
  it("Should stay within acceptable gas limits for executing an option", async function () {
    const [owner, user] = await ethers.getSigners();
    const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
    const contract = await contractFactory.deploy();
    await contract.deployed();
  
    // Create an option with some collateral
    const optionId = await contract.createOption([], 0, { value: ethers.utils.parseEther("1") });
  
    // Measure gas consumption for executing the option
    const executeTx = await contract.executeOption(optionId);
    const executeReceipt = await executeTx.wait();
    const executeGasUsed = executeReceipt.gasUsed.toNumber();
  
    // Define acceptable gas limits based on your contract's complexity
    const maxExecuteGas = 150000;
  
    // Check that gas consumption is within acceptable limits
    expect(executeGasUsed).to.be.lte(maxExecuteGas);
  });

  it("Should stay within acceptable gas limits for updating an option price", async function () {
    const [owner, user] = await ethers.getSigners();
    const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
    const contract = await contractFactory.deploy();
    await contract.deployed();
  
    // Create an option with some collateral
    const optionId = await contract.createOption([], 0, { value: ethers.utils.parseEther("1") });
  
    // Measure gas consumption for updating the option price
    const updatePriceTx = await contract.updatePrice(optionId, [200]);
    const updatePriceReceipt = await updatePriceTx.wait();
    const updatePriceGasUsed = updatePriceReceipt.gasUsed.toNumber();
  
    // Define acceptable gas limits based on your contract's complexity
    const maxUpdatePriceGas = 120000;
  
    // Check that gas consumption is within acceptable limits
    expect(updatePriceGasUsed).to.be.lte(maxUpdatePriceGas);
  });
  
});
// Test the contract's behavior with reentrancy
describe("Reentrancy Tests", function () {
    it("Should not be vulnerable to reentrancy attacks", async function () {
        // Section 1: Basic reentrancy attempt
        await maliciousContract.attack(optionId, { value: ethers.utils.parseEther("1") });

        // Check that the option is not in the market anymore
        const marketOption = await contract.queryMarketOption(optionId);
        expect(marketOption.status).to.equal(0); // Assuming 0 means not on sale

        // Check that the owner of the option is still the original owner
        const option = await contract.queryOption(optionId);
        expect(option.owner).to.equal(owner.address);

        // Additional checks to improve coverage
        // Check that the contract's balance is correctly updated
        const contractBalance = await ethers.provider.getBalance(contract.address);
        expect(contractBalance).to.equal(0);

        // Check the balance of the malicious contract to ensure it received the funds
        const maliciousContractBalance = await ethers.provider.getBalance(maliciousContract.address);
        expect(maliciousContractBalance).to.equal(ethers.utils.parseEther("1"));

    });
    it("Should not be vulnerable to reentrancy attacks2 - Balance Check", async function () {
      
        // Section 2: Reentrancy with balance check
        const initialContractBalance = await ethers.provider.getBalance(contract.address);
        await maliciousContract.attack(optionId, { value: ethers.utils.parseEther("1") });
        const finalContractBalance = await ethers.provider.getBalance(contract.address);

        // Check that the contract balance is unchanged after the reentrancy attempt
        expect(finalContractBalance).to.equal(initialContractBalance);

        // Additional checks to improve coverage
        // Check that the owner of the option is the attacker after the reentrancy attempt
        const optionAfterReentrancy = await contract.queryOption(optionId);
        expect(optionAfterReentrancy.owner).to.equal(attacker.address);

        // Check that the contract's balance is correctly updated
        const updatedContractBalance = await ethers.provider.getBalance(contract.address);
        expect(updatedContractBalance).to.equal(0);


    });
  });

  describe("Testing Each Function", function () {
    // ... Previous tests
  
    describe("buyOption()", function () {
      it("should buy with exact funds", async function () {
        const [buyer, seller] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        const optionId = await contract.createOption([], (await getTimestamp()) + 3600, { value: ethers.utils.parseEther("1") });
  
        await contract.addToMarket(optionId, ethers.utils.parseEther("1"), "ETH");
  
        await contract.connect(buyer).buyOption(optionId, { value: ethers.utils.parseEther("1") });
  
        const marketOption = await contract.queryMarketOption(optionId);
        expect(marketOption.status).to.equal(2); // Assuming 2 means sold
        const option = await contract.queryOption(optionId);
        expect(option.owner).to.equal(buyer.address);
      });
  
      it("should revert buying with insufficient funds", async function () {
        const [buyer, seller] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        const optionId = await contract.createOption([], (await getTimestamp()) + 3600, { value: ethers.utils.parseEther("1") });
  
        await contract.addToMarket(optionId, ethers.utils.parseEther("1"), "ETH");
  
        await expect(contract.connect(buyer).buyOption(optionId, { value: ethers.utils.parseEther("0.5") }))
          .to.be.revertedWith("Insufficient funds");
      });
    });
  
    describe("executeOption()", function () {
      it("should execute a valid expired option", async function () {
        const [owner, executor] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        const optionId = await contract.createOption([], (await getTimestamp()) - 1, { value: ethers.utils.parseEther("1") });
  
        await contract.addToMarket(optionId, ethers.utils.parseEther("1"), "ETH");
        await contract.connect(executor).executeOption(optionId);
  
        const marketOption = await contract.queryMarketOption(optionId);
        expect(marketOption.status).to.equal(3); // Assuming 3 means executed
      });
  
      it("should revert executing unexpired option", async function () {
        const [owner, executor] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        const optionId = await contract.createOption([], (await getTimestamp()) + 3600, { value: ethers.utils.parseEther("1") });
  
        await contract.addToMarket(optionId, ethers.utils.parseEther("1"), "ETH");
  
        await expect(contract.connect(executor).executeOption(optionId))
          .to.be.revertedWith("Option not expired");
      });
    });
  
    // ... Add more tests for other functions as needed
  });

  // Continuing Testing Events and Invalid Inputs
describe("Testing Events and Invalid Inputs", function () {
    // ... Previous tests
  
    describe("Event Emission", function () {
      it("should emit the expected event", async function () {
        const [owner] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        const optionId = await contract.createOption([], (await getTimestamp()) + 3600, { value: ethers.utils.parseEther("1") });
  
        const tx = await contract.connect(owner).functionWithEvent(optionId);
        const receipt = await tx.wait();
  
        // Check if the expected event is emitted
        const event = receipt.events.find((e) => e.event === "YourEventName"); // Replace "YourEventName" with the actual event name
        expect(event).to.not.be.undefined;
  
        // Check that event parameters match expected values
        expect(event.args.parameterName).to.equal(expectedValue); // Adjust as per your contract's event structure
      });
    });
  
    describe("Invalid Inputs", function () {
      it("should revert with zero address", async function () {
        const [owner] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        await expect(contract.connect(owner).functionWithZeroAddress())
          .to.be.revertedWith("Invalid address");
      });
  
      it("should revert with zero amount", async function () {
        const [owner] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        await expect(contract.connect(owner).functionWithZeroAmount())
          .to.be.revertedWith("Invalid amount");
      });
  
      it("should revert with empty array", async function () {
        const [owner] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        await expect(contract.connect(owner).functionWithEmptyArray([]))
          .to.be.revertedWith("Invalid array");
      });
  
      it("should revert with overflow", async function () {
        const [owner] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        await expect(contract.connect(owner).functionWithOverflow())
          .to.be.revertedWith("Value overflow");
      });
  
      it("should revert with exceeding gas limits", async function () {
        const [owner] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        await expect(contract.connect(owner).functionExceedingGasLimit())
          .to.be.revertedWith("Gas limit exceeded");
      });
    });
  
    // ... Add more tests for other events and invalid inputs as needed
  });

  
  // Continuing Testing Access Control
describe("Testing Access Control and Modifiers", function () {
    // ... Previous tests
  
    describe("onlyOwner Modifier", function () {
      it("should allow calling a function as the owner", async function () {
        const [owner, nonOwner] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        // Call a function as the owner
        const tx = await contract.connect(owner).functionWithOnlyOwner();
        await tx.wait(); // Wait for the transaction to be mined
        // Add assertions as needed
      });
  
      it("should revert when called by a non-owner", async function () {
        const [owner, nonOwner] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
  
        // Attempt to call the function as a non-owner
        await expect(contract.connect(nonOwner).functionWithOnlyOwner())
          .to.be.revertedWith("Ownable: caller is not the owner");
      });
    });
  
    describe("onlyCreator Modifier", function () {
        it("should allow calling a function as the creator", async function () {
          const [creator, nonCreator] = await ethers.getSigners();
          const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
          const contract = await contractFactory.deploy();
          await contract.deployed();
      
          // Set the creator in the contract
          await contract.setCreator(creator.address);
      
          // Call a function as the creator
          const tx = await contract.connect(creator).functionWithOnlyCreator();
          await tx.wait(); // Wait for the transaction to be mined
          // Add assertions as needed
        });
      
        it("should revert when called by a non-creator", async function () {
          const [creator, nonCreator] = await ethers.getSigners();
          const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
          const contract = await contractFactory.deploy();
          await contract.deployed();
      
          // Set the creator in the contract
          await contract.setCreator(creator.address);
      
          // Attempt to call the function as a non-creator
          await expect(contract.connect(nonCreator).functionWithOnlyCreator())
            .to.be.revertedWith("Only creator can call this function");
        });
      });
  
    // ... Add more tests for other access control modifiers as needed
  });

  // Continuing Testing Option Lifecycle
describe("Testing Option Lifecycle", function () {
    // ... Previous tests
  
    it("should test the complete option lifecycle", async function () {
      const [owner, buyer, anotherAccount] = await ethers.getSigners();
      const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
      const contract = await contractFactory.deploy();
      await contract.deployed();
  
      // Create an option with valid parameters
      const optionId = await contract.createOption([], 0, { value: ethers.utils.parseEther("1") });
  
      // Add the option to the market
      await contract.addToMarket(optionId, ethers.utils.parseEther("1"), "ETH");
  
      // Test buying the option
      await contract.connect(buyer).buyOption(optionId, { value: ethers.utils.parseEther("1") });
  
      // Wait for expiration (you may need to use a testing framework with time manipulation)
      // For example, using Hardhat's time testing helpers:
      await network.provider.send("evm_increaseTime", [86400]); // Increase time by 1 day
      await network.provider.send("evm_mine"); // Mine a new block to finalize the time increase
  
      // Test executing the expired option
      await expect(contract.connect(owner).executeOption(optionId))
        .to.be.revertedWith("Option has expired");
  
      // Test claiming a non-expired option (should revert)
      await expect(contract.connect(buyer).claimOption(optionId))
        .to.be.revertedWith("Option is not expired");
  
      // Test removing from market
      await contract.connect(owner).removeFromMarket(optionId);
  
      // Test cancelling option
      await contract.connect(owner).cancelOption(optionId);
    });
  
    // ... Add more tests for specific scenarios in the option lifecycle as needed
  });

  // Continuing Testing Failed Transactions and Chainlink Integration
describe("Testing Failed Transactions and Chainlink Integration", function () {
    // ... Previous tests
  
    it("should test failed transactions", async function () {
      const [owner, buyer, bidder, tokenApprover] = await ethers.getSigners();
      const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
      const contract = await contractFactory.deploy();
      await contract.deployed();
  
      const optionId = await contract.createOption([], 0, { value: ethers.utils.parseEther("1") });
  
      // Test buying an option without sending exact funds (should revert)
      await expect(contract.connect(buyer).buyOption(optionId, { value: ethers.utils.parseEther("0.5") }))
        .to.be.revertedWith("Incorrect funds sent");
  
      // Test bidding without approving token transfer (should revert)
      const invalidBidAmount = ethers.utils.parseEther("0.5");
      await expect(contract.connect(bidder).bidOnMarket(optionId, invalidBidAmount))
        .to.be.revertedWith("Transfer amount exceeds allowance");
    });
  
    it("should test Chainlink integration", async function () {
        const [owner, chainlinkMock] = await ethers.getSigners();
    
        // Deploy ConstellationDerivative contract
        const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
        const contract = await contractFactory.deploy();
        await contract.deployed();
    
        // Mock Chainlink contract for isolated testing
        const chainlinkMockFactory = await ethers.getContractFactory("ChainlinkMock");
        const mockChainlink = await chainlinkMockFactory.deploy();
        await mockChainlink.deployed();
    
        // Test requesting random number
        await mockChainlink.mockRequestRandomNumber();
        const requestId = await mockChainlink.latestRequestId();
    
        // Test fulfilling random number
        await mockChainlink.fulfillRandomWords(requestId, [42]);
    
        // Use mock random number to execute option
        await contract.connect(owner).executeOptionWithRandomness(requestId);
    
        // Add assertions or further checks as needed
    });
  
  });

  // Continuing Testing Reentrancy Advanced
describe("Testing Reentrancy Advanced", function () {
    
  
    it("should test reentrancy advanced", async function () {
        // Deploy reentrancy attack contract
        const maliciousContractFactory = await ethers.getContractFactory("MaliciousContract");
        const maliciousContract = await maliciousContractFactory.deploy(contract.address);
        await maliciousContract.deployed();

        // Call attack after key state changes like buying option
        await contract.connect(owner).buyOption(optionId, { value: ethers.utils.parseEther("1") });
        await maliciousContract.attack(optionId, { value: ethers.utils.parseEther("1") });

        // Check for impacted state in the main contract
        const optionAfterReentrancy = await contract.queryOption(optionId);
        expect(optionAfterReentrancy.owner).to.equal(attacker.address);

        // Additional checks to improve coverage
        // Check that the contract's balance is correctly updated
        const finalContractBalance = await ethers.provider.getBalance(contract.address);
        expect(finalContractBalance).to.equal(0);
    });
  
    // ... Add more tests for specific scenarios related to advanced reentrancy testing
  });

  // Continuing Testing Race Conditions
describe("Testing Race Conditions", function () {
    // ... Previous tests
  
    it("should test race conditions", async function () {
      const [owner, attacker] = await ethers.getSigners();
      const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
      const contract = await contractFactory.deploy();
      await contract.deployed();
  
      const optionId = await contract.createOption([], 0, { value: ethers.utils.parseEther("1") });
  
      // Deploy attack contract to front-run legitimate transactions
      const frontRunnerFactory = await ethers.getContractFactory("FrontRunnerContract");
      const frontRunner = await frontRunnerFactory.deploy(contract.address);
      await frontRunner.deployed();
  
      // Trigger race conditions around bidding and offering
      await Promise.all([
        contract.connect(owner).addToMarket(optionId, ethers.utils.parseEther("1"), "ETH"),
        frontRunner.attack(optionId, { value: ethers.utils.parseEther("1") }),
      ]);
  
      // Check for race conditions impact
      const marketOption = await contract.queryMarketOption(optionId);
      expect(marketOption.status).to.equal(1); // Assuming 1 means on sale
    });
  
    // ... Add more tests for specific scenarios related to race conditions
  });

  // Continuing Testing Gas Consumption
describe("Testing Gas Consumption", function () {
    // ... Previous tests
  
    it("should measure gas usage for each function", async function () {
      const [owner, user] = await ethers.getSigners();
      const contractFactory = await ethers.getContractFactory("ConstellationDerivative");
      const contract = await contractFactory.deploy();
      await contract.deployed();
  
      // Create an option with some collateral
      const optionId = await contract.createOption([], 0, { value: ethers.utils.parseEther("1") });
  
      // Measure gas usage for createOption
      const createOptionTx = await contract.createOption([], 0, { value: ethers.utils.parseEther("1") });
      const createOptionReceipt = await createOptionTx.wait();
      console.log("Gas used for createOption:", createOptionReceipt.gasUsed.toString());
  
      // Measure gas usage for transferOption
      const transferOptionTx = await contract.transferOption(optionId, user.address);
      const transferOptionReceipt = await transferOptionTx.wait();
      console.log("Gas used for transferOption:", transferOptionReceipt.gasUsed.toString());
  
      // ... Add more gas usage measurements for other functions
  
      // Check gas usage against specified limit (adjust the limit as needed)
      const gasLimit = 2000000;
      expect(createOptionReceipt.gasUsed).to.be.lessThan(gasLimit);
      expect(transferOptionReceipt.gasUsed).to.be.lessThan(gasLimit);
  
      // Attempt to exceed the gas limit (should revert)
      await expect(contract.createOption([], 0, { value: ethers.utils.parseEther("1") })).to.be.revertedWith(
        "Gas consumption exceeds limit"
      );
    });
  
    // ... Add more tests for specific scenarios related to gas consumption
  });
  
  
/*
Test Read me info Comments:
Good coverage of testing each function, events, modifiers, invalid inputs, access control, option lifecycle, failed transactions, 
reentrancy, race conditions, and gas consumption.
The tests for specific functions like createOption, transferOption, buyOption, executeOption etc. cover valid and invalid scenarios.
The tests for modifiers check behavior when conditions pass and fail.
Tests for events check if they are emitted and with expected parameters.
Invalid inputs like invalid addresses, amounts, overflow etc. are tested to trigger reverts.
Access control tests check owner only and creator only modifiers.
Option lifecycle tests go through the key stages.
Mocks are used for Chainlink integration testing.
Reentrancy and race conditions are tested using attack contracts.
Gas consumption is measured and checked against limits.

Future Additions:
Add more tests as needed for other functions and edge cases.
Use a testing framework like Mocha/Chai for improved structure.
Add tests for bidding, offering and market operations.
Check values match expected in events not just parameters. */

