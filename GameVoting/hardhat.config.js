require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    // hardhat: {
    //   chainId: 31337
    // },
    sepolia: {
      url: `https://sepolia.drpc.org`,
      accounts: [process.env.PRIVATE_KEY]
    },
    // mainnet: {
    //   url: `https://eth.llamarpc.com`,
    //   accounts: [process.env.PRIVATE_KEY]
    // },
    // base: {
    //   url: `https://mainnet.base.org`,
    //   accounts: [process.env.PRIVATE_KEY]
    // }
  }
}; 