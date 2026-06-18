import assert from "assert";
import { deployScript, artifacts } from "@rocketh";

import { checkAddressValid, getLzEidReceiver, getTokenAddressFromConfig } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "SideChainFeeCollector";

export default deployScript(
  async ({ namedAccounts, name, deploy }) => {
    const { deployer } = namedAccounts;
    assert(deployer, "Missing deployer account");
    console.log(`Network: ${name}\nDeployer: ${deployer}\nDeploying: ${contractName}`);

    const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${name}/config.json`).toString());
    if (config.isMainChainFeeDistributor) throw new Error("SideChainFeeCollector must be deployed on side chain");

    const accessManager = checkAddressValid(config.accessManager, "access manager");

    const feeDistributorData = config.feeDistributor;
    const lzEidReceiver = getLzEidReceiver(feeDistributorData.mainChain);
    const destinationReceiver = checkAddressValid(feeDistributorData.destinationReceiver, "destination receiver");
    const bridgeableToken = checkAddressValid(feeDistributorData.bridgeableToken, "bridgeable token");

    const feeToken = getTokenAddressFromConfig(feeDistributorData.feeToken, config);

    const contract = await deploy(contractName, {
      account: deployer,
      artifact: artifacts.SideChainFeeCollector,
      args: [accessManager, lzEidReceiver, bridgeableToken, destinationReceiver, feeToken],
    });

    console.log(`Deployed ${contractName}, network: ${name}, address: ${contract.address}`);
  },
  {
    tags: [contractName],
  },
);
