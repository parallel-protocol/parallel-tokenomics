import assert from "assert";
import { deployScript, artifacts } from "@rocketh";

import { checkAddressValid, getTokenAddressFromConfig, getWalletAddressFromConfig, isAddressValid } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "sPRL2V2";

export default deployScript(
  async ({ namedAccounts, name, deploy }) => {
    const { deployer } = namedAccounts;
    assert(deployer, "Missing deployer account");
    console.log(`Network: ${name}\nDeployer: ${deployer}\nDeploying: ${contractName}`);

    const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${name}/config.json`).toString());
    const accessManager = config.accessManager;
    if (!isAddressValid(accessManager)) throw new Error("Invalid access manager address");

    const sprl2v2Data = config.sprl2v2;
    const prlToken = getTokenAddressFromConfig("prl", config);
    const wethToken = getTokenAddressFromConfig("weth", config);

    const permit2 = checkAddressValid(sprl2v2Data.permit2, "Permit2");
    const feeReceiver = getWalletAddressFromConfig(sprl2v2Data.feeReceiver, config);
    const balancerRouter = checkAddressValid(sprl2v2Data.balancerV3Router, "Balancer V3 Router");
    const balancerBPT = checkAddressValid(sprl2v2Data.balancerBPT, "Balancer BPT");

    const BPTConfigParams = {
      balancerRouter,
      balancerBPT,
      prl: prlToken,
      weth: wethToken,
      permit2,
    };

    const contract = await deploy(contractName, {
      account: deployer,
      artifact: artifacts.sPRL2V2,
      args: [
        feeReceiver,
        accessManager,
        BigInt(sprl2v2Data.startPenaltyPercentage),
        BigInt(sprl2v2Data.timeLockDuration),
        BPTConfigParams,
      ],
    });

    console.log(`Deployed ${contractName}, network: ${name}, address: ${contract.address}`);
  },
  {
    tags: [contractName],
  },
);
