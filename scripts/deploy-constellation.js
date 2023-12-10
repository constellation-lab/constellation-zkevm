const { ethers } = require("hardhat");

async function main() {
  const ConstellationCoreContractFactory = await ethers.getContractFactory("ConstellationCore");
  const ConstellationMarketContractFactory = await ethers.getContractFactory("ConstellationMarket");

  // Specify your private key
  const privateKey = "e2dbf702083acc7c12e944de0654e8b5e092c77bfa8e04324d31cf3f835efa5b";
  const provider = ethers.provider; // You may need to adjust this based on your configuration
  const signer = new ethers.Wallet(privateKey).connect(provider);

  // Deploy the contract
  const factory = new ethers.ContractFactory(
    ConstellationCoreContractFactory.interface,
    ConstellationCoreContractFactory.bytecode,
    signer
  );

  const coreDeploymentTx = await factory.deploy();
  console.log("ConstellationCore contract deployed:", coreDeploymentTx.address);

  
  // Deploy ConstellationMarket contract
  const marketFactory = new ethers.ContractFactory(
    ConstellationMarketContractFactory.interface,
    ConstellationMarketContractFactory.bytecode,
    signer
  );

  const marketDeploymentTx = await marketFactory.deploy(coreDeploymentTx.address); // Pass the address of ConstellationCore to ConstellationMarket constructor
  console.log("ConstellationMarket contract deployed:", marketDeploymentTx.address);

  /*
  console.log("before deploymentTx log");
  console.log(deploymentTx);
  console.log("after deploymentTx log");
*/
  console.log("Constellation contracts deployed")

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});