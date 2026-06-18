import assert from "assert";
import { deployScript, artifacts } from "@rocketh";

import { checkAddressValid, getTokenAddressFromConfig } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "MainFeeDistributor";

export default deployScript(
  async ({ namedAccounts, name, deploy }) => {
    const { deployer } = namedAccounts;
    assert(deployer, "Missing deployer account");
    console.log(`Network: ${name}\nDeployer: ${deployer}\nDeploying: ${contractName}`);

    const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${name}/config.json`).toString());
    if (!config.isMainChainFeeDistributor) throw new Error("MainFeeDistributor must be deployed on main chain");

    const accessManager = checkAddressValid(config.accessManager, "access manager");

    const feeDistributorData = config.feeDistributor;
    const bridgeableToken = checkAddressValid(feeDistributorData.bridgeableToken, "bridgeable token");

    const feeToken = getTokenAddressFromConfig(feeDistributorData.feeToken, config);

    const contract = await deploy(contractName, {
      account: deployer,
      artifact: artifacts.MainFeeDistributor,
      args: [accessManager, bridgeableToken, feeToken],
    });

    console.log(`Deployed ${contractName}, network: ${name}, address: ${contract.address}`);
  },
  {
    tags: [contractName],
  },
);
