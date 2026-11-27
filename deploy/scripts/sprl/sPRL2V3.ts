import assert from "assert";
import { deployScript, artifacts } from "@rocketh";

import { checkAddressValid, getTokenAddressFromConfig, getWalletAddressFromConfig, isAddressValid } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "sPRL2V3";

// sPRL2V3 is sPRL2V2 deployed against a Frontier pool (Balancer V3 fork): the constructor still names the
// router and the BPT `balancerRouter` / `balancerBPT`.
export default deployScript(
  async ({ namedAccounts, name, deploy }) => {
    const { deployer } = namedAccounts;
    assert(deployer, "Missing deployer account");
    console.log(`Network: ${name}\nDeployer: ${deployer}\nDeploying: ${contractName}`);

    const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${name}/config.json`).toString());
    const accessManager = config.accessManager;
    if (!isAddressValid(accessManager)) throw new Error("Invalid access manager address");

    const sprl2v3Data = config.sprl2v3;
    if (!sprl2v3Data) throw new Error(`Missing sprl2v3 config for ${name}`);
    const prlToken = getTokenAddressFromConfig("prl", config);
    const wethToken = getTokenAddressFromConfig("weth", config);

    const permit2 = checkAddressValid(sprl2v3Data.permit2, "Permit2");
    const feeReceiver = getWalletAddressFromConfig(sprl2v3Data.feeReceiver, config);
    const frontierRouter = checkAddressValid(sprl2v3Data.frontierRouter, "Frontier Router");
    const frontierBPT = checkAddressValid(sprl2v3Data.frontierBPT, "Frontier BPT");

    const BPTConfigParams = {
      balancerRouter: frontierRouter,
      balancerBPT: frontierBPT,
      prl: prlToken,
      weth: wethToken,
      permit2,
    };

    const contract = await deploy(contractName, {
      account: deployer,
      artifact: artifacts.sPRL2V3,
      args: [
        feeReceiver,
        accessManager,
        BigInt(sprl2v3Data.startPenaltyPercentage),
        BigInt(sprl2v3Data.timeLockDuration),
        BPTConfigParams,
      ],
    });

    console.log(`Deployed ${contractName}, network: ${name}, address: ${contract.address}`);
  },
  {
    tags: [contractName],
  },
);
