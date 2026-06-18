import assert from "assert";
import { deployScript, artifacts } from "@rocketh";

import { getTokenAddressFromConfig, getWalletAddressFromConfig, isAddressValid } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "sPRL1";

export default deployScript(
  async ({ namedAccounts, name, deploy }) => {
    const { deployer } = namedAccounts;
    assert(deployer, "Missing deployer account");
    console.log(`Network: ${name}\nDeployer: ${deployer}\nDeploying: ${contractName}`);

    const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${name}/config.json`).toString());
    const accessManager = config.accessManager;
    if (!isAddressValid(accessManager)) throw new Error("Invalid access manager address");

    const sprl1Data = config.sprl1;
    const underlying = getTokenAddressFromConfig(sprl1Data.underlying, config);
    const feeReceiver = getWalletAddressFromConfig(sprl1Data.feeReceiver, config);

    const contract = await deploy(contractName, {
      account: deployer,
      artifact: artifacts.sPRL1,
      args: [
        underlying,
        feeReceiver,
        accessManager,
        BigInt(sprl1Data.startPenaltyPercentage),
        BigInt(sprl1Data.timeLockDuration),
      ],
    });

    console.log(`Deployed ${contractName}, network: ${name}, address: ${contract.address}`);
  },
  {
    tags: [contractName],
  },
);
