import assert from "assert";

import { type DeployFunction } from "hardhat-deploy/types";

import { checkAddressValid, getTokenAddressFromConfig, getWalletAddressFromConfig, isAddressValid } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "sPRL2";

const deploy: DeployFunction = async (hre) => {
  const { getNamedAccounts, deployments } = hre;

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  assert(deployer, "Missing deployer account");

  console.log(`Network: ${hre.network.name}`);
  console.log(`Deployer: ${deployer}`);

  const config: ConfigData = JSON.parse(readFileSync(`./deploy/config/${hre.network.name}/config.json`).toString());
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
    balancerRouter: balancerRouter,
    auraBoosterLite: auraBoosterLite,
    auraRewardsPool: auraRewardsPool,
    balancerBPT: balancerBPT,
    prl: prlToken,
    weth: wethToken,
    rewardTokens: rewardsTokens,
    permit2: permit2,
  };
  const contract = await deploy(contractName, {
    from: deployer,
    args: [
      auraBPT,
      feeReceiver,
      accessManager,
      sprl2Data.startPenaltyPercentage,
      sprl2Data.timeLockDuration,
      BPTConfigParams,
    ],
    log: true,
    skipIfAlreadyDeployed: false,
  });

  console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${contract.address}`);
};

deploy.tags = [contractName];
export default deploy;
