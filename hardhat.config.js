require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  //solidity: "0.8.9",
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 500, // Adjust the number of runs as needed
      },
    },
  },
  
  plugins: [
    "truffle-plugin-verify" 
  ],
  
  paths: {
    artifacts: "./src",
  },
  networks: {
    zkEVM: {
      url: `https://rpc.public.zkevm-test.net`,
      //accounts: [process.env.ACCOUNT_PRIVATE_KEY],
      accounts: [`e2dbf702083acc7c12e944de0654e8b5e092c77bfa8e04324d31cf3f835efa5b`,],
    },  
  },
};
