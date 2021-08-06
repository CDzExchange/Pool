import "@nomiclabs/hardhat-waffle"
import '@nomiclabs/hardhat-ethers'
import "@nomiclabs/hardhat-etherscan"
import "@tenderly/hardhat-tenderly"
import "@nomiclabs/hardhat-solhint"
import '@typechain/hardhat'
import "hardhat-abi-exporter"
import "hardhat-deploy"
import "hardhat-deploy-ethers"

import { HardhatUserConfig } from "hardhat/types"

const accounts = {
  mnemonic: process.env.MNEMONIC || "test test test test test test test test test test test junk"
}

const config: HardhatUserConfig = {
  abiExporter: {
    path: "./abi",
    clear: false,
    flat: true,
    // only: [],
    // except: []
  },
  namedAccounts:{
      deployer:{
        default: 0
      },
      dev: {
        default: 1
      }
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    hardhat: {
      mining: {
        auto: true,
        interval: 0
      }
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      accounts,
      chainId: 97,
      gasPrice: 20000000000
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      accounts,
      chainId: 56,
      gasPrice: 20000000000
    }
  },
  solidity: {
    version: "0.8.0",
    settings: {
      optimizer: {
        enabled: true
      }
    }
  },
  etherscan:{
    apiKey: "US8RSTTS73UJ3KVTA4HD83JN77SVFI3KBD"
  },
  typechain: {
    outDir: "types",
    target: "ethers-v5",
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: ['externalArtifacts/*.json'], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
  },
  paths: {
    artifacts: "artifacts",
    cache: "cache",
    //deploy: "deploy",
    //deployments: "deployments",
    //imports: "imports",
    sources: "contracts",
    tests: "test",
  },
};

export default config
