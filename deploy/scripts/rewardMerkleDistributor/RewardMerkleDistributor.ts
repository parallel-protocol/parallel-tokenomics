import assert from "assert";
import { deployScript, artifacts } from "@rocketh";

import { checkAddressValid, getTokenAddressFromConfig, getWalletAddressFromConfig } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "RewardMerkleDistributor";

export default deployScript(
  async ({ namedAccounts, name, deploy }) => {
    const { deployer } = namedAccounts;
    assert(deployer, "Missing deployer account");
    console.log(`Network: ${name}\nDeployer: ${deployer}\nDeploying: ${contractName}`);

    const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${name}/config.json`).toString());

    const accessManager = checkAddressValid(config.accessManager, "access manager");

    const rewardMerkleDistributorData = config.rewardMerkleDistributor;

    const token = getTokenAddressFromConfig(rewardMerkleDistributorData.token, config);

    const expiredRewardsRecipient = getWalletAddressFromConfig(
      rewardMerkleDistributorData.expiredRewardsRecipient,
      config,
    );

    const contract = await deploy(contractName, {
      account: deployer,
      artifact: artifacts.RewardMerkleDistributor,
      args: [accessManager, token, expiredRewardsRecipient],
    });

    console.log(`Deployed ${contractName}, network: ${name}, address: ${contract.address}`);
  },
  {
    tags: [contractName],
  },
);
