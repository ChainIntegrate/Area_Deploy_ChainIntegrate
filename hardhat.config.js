require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: { enabled: true, runs: 50 }
    }
  },
  networks: {
    luksoTestnet: {
      url: "https://rpc.testnet.lukso.network",
      chainId: 4201,
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
    },
  },

  // ✅ Necessario per la verifica su Blockscout (custom chain)
  etherscan: {
    apiKey: {
      // Blockscout non richiede davvero una chiave, ma Hardhat vuole una stringa non vuota
      luksoTestnet: "abc",
    },
    customChains: [
      {
        network: "luksoTestnet",
        chainId: 4201,
        urls: {
          apiURL: "https://explorer.execution.testnet.lukso.network/api",
          browserURL: "https://explorer.execution.testnet.lukso.network",
        },
      },
    ],
  },

  // opzionale: se vuoi disabilitare Sourcify
  // sourcify: { enabled: false },
};

