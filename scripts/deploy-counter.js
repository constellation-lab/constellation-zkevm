const { ethers } = require("hardhat");

async function main() {
  const CounterContractFactory = await ethers.getContractFactory("Counter");

  // Specify your private key
  const privateKey = "e2dbf702083acc7c12e944de0654e8b5e092c77bfa8e04324d31cf3f835efa5b";
  const provider = ethers.provider; // You may need to adjust this based on your configuration
  const signer = new ethers.Wallet(privateKey).connect(provider);

  // Deploy the contract
  const factory = new ethers.ContractFactory(
    CounterContractFactory.interface,
    CounterContractFactory.bytecode,
    signer
  );

  const deploymentTx = await factory.deploy();
  console.log("before line 19");
  console.log(deploymentTx);
  console.log("after line 19");
/*
  //await deploymentTx 
  //const address = await deploymentTx
  //await address
  //console.log(address.address)
  const tx = deploymentTx.deployTransaction
  console.log(tx)
  console.log("after line 26");

  // Wait for the contract to be mined and get the deployed instance
  //const counterContract = await deploymentTx.waitForDeployment();
  //await deploymentTx.wait();

  
  // Wait for a certain number of blocks to be mined
  // Wait for a certain number of blocks to be mined
  const blocksToWait = 3;
  //const contractAddress = deploymentTx.deployTransaction.to;

  // Construct a transaction object with the contract deployment address as the "to" and empty "data"
   //const tx = { to: deploymentTx.address, data: "0x" };
   console.log("on line 40")
   console.log(deploymentTx.address) 
  // Loop the number of times to wait
  for (let i = 0; i < blocksToWait; i++) {
    // Send a transaction to mine a new block
    //await provider.sendTransaction(tx);
    await signer.sendTransaction(tx)

    // Wait a tiny bit between transactions to ensure they are mined separately
    await new Promise((resolve) => setTimeout(resolve, 10000));
  }


 
  

  // Verify that the contract is deployed by checking its code
  while (true) {
    if (await provider.getCode(deploymentTx.address)) {
      break;
    }
    await new Promise((resolve) => setTimeout(resolve, 1000)); // Wait for 1 second before checking again
  }
  
  
  
  const counterContract = await factory.attach(deploymentTx.address);
*/

  //console.log(`Counter contract deployed to ${counterContract.address}`);
  console.log("Counter contract deployed")
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});






