import assert from "assert";
import { deployScript, artifacts } from "@rocketh";

import { checkAddressValid, getTokenAddressFromConfig, getWalletAddressFromConfig, isAddressValid } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "sPRL2";

export default deployScript(
  async ({ namedAccounts, name, deploy }) => {
    const { deployer } = namedAccounts;
    assert(deployer, "Missing deployer account");
    console.log(`Network: ${name}\nDeployer: ${deployer}\nDeploying: ${contractName}`);

    const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${name}/config.json`).toString());
    const accessManager = config.accessManager;
    if (!isAddressValid(accessManager)) throw new Error("Invalid access manager address");

    const sprl2Data = config.sprl2;
    const prlToken = getTokenAddressFromConfig("prl", config);
    const wethToken = getTokenAddressFromConfig("weth", config);

    const permit2 = checkAddressValid(sprl2Data.permit2, "Permit2");
    const feeReceiver = getWalletAddressFromConfig(sprl2Data.feeReceiver, config);
    const balancerRouter = checkAddressValid(sprl2Data.balancerV3Router, "Balancer V3 Router");
    const balancerBPT = checkAddressValid(sprl2Data.balancerBPT, "Balancer BPT");
    const auraBoosterLite = checkAddressValid(sprl2Data.auraBoosterLite, "Aura Booster Lite");
    const auraRewardsPool = checkAddressValid(sprl2Data.auraRewardsPool, "Aura Rewards Pool");
    const auraBPT = checkAddressValid(sprl2Data.auraBPT, "Aura BPT");
    const rewardsTokens = sprl2Data.rewardsTokens.map((token) => checkAddressValid(token, "Reward Token"));

    const BPTConfigParams = {
      balancerRouter,
      auraBoosterLite,
      auraRewardsPool,
      balancerBPT,
      prl: prlToken,
      weth: wethToken,
      rewardTokens: rewardsTokens,
      permit2,
    };

    const contract = await deploy(contractName, {
      account: deployer,
      artifact: artifacts.sPRL2,
      args: [
        auraBPT,
        feeReceiver,
        accessManager,
        BigInt(sprl2Data.startPenaltyPercentage),
        BigInt(sprl2Data.timeLockDuration),
        BPTConfigParams,
      ],
    });

    console.log(`Deployed ${contractName}, network: ${name}, address: ${contract.address}`);
  },
  {
    tags: [contractName],
  },
);
