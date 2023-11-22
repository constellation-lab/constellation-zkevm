const { ethers } = require("hardhat");

async function main() {
  const ConstellationDerivativeContractFactory = await ethers.getContractFactory("ConstellationDerivative");

  // Specify your private key
  const privateKey = "e2dbf702083acc7c12e944de0654e8b5e092c77bfa8e04324d31cf3f835efa5b";
  const provider = ethers.provider; // You may need to adjust this based on your configuration
  const signer = new ethers.Wallet(privateKey).connect(provider);

  // Deploy the contract
  const factory = new ethers.ContractFactory(
    ConstellationDerivativeContractFactory.interface,
    ConstellationDerivativeContractFactory.bytecode,
    signer
  );

  const deploymentTx = await factory.deploy();
  console.log("before deploymentTx log");
  console.log(deploymentTx);
  console.log("after deploymentTx log");

  console.log("ConstellationDerivative contract deployed")
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});