import "dotenv/config";

import HardhatViem from "@nomicfoundation/hardhat-viem";
import HardhatDeploy from "hardhat-deploy";

import { HardhatUserConfig } from "hardhat/types/config";

import { getRpcURL } from "./utils/getRpcURL";

const PRIVATE_KEY = process.env.PRIVATE_KEY;
if (!PRIVATE_KEY) throw new Error("PRIVATE_KEY is not set");
const accounts = [PRIVATE_KEY];

const config: HardhatUserConfig = {
  plugins: [HardhatViem, HardhatDeploy],
  // Foundry tests live in `test/`; keep Hardhat from compiling them by pointing its
  // Solidity sources at `contracts/` and its test dir at an unused path.
  paths: {
    sources: "contracts",
    tests: "hardhat-test",
  },
  solidity: {
    compilers: [
      {
        version: "0.8.25",
        settings: {
          evmVersion: "cancun",
          optimizer: {
            enabled: true,
            runs: 10_000,
          },
        },
      },
    ],
  },
  networks: {
    mainnet: {
      type: "http",
      url: getRpcURL("mainnet"),
      accounts,
    },
    sepolia: {
      type: "http",
      url: getRpcURL("sepolia"),
      accounts,
    },
    arbiSepolia: {
      type: "http",
      url: getRpcURL("arbiSepolia"),
      accounts,
    },
    polygon: {
      type: "http",
      url: getRpcURL("polygon"),
      accounts,
    },
    base: {
      type: "http",
      url: getRpcURL("base"),
      accounts,
    },
    sonic: {
      type: "http",
      url: getRpcURL("sonic"),
      accounts,
    },
  },
};

export default config;
