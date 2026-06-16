import assert from "assert";

import { type DeployFunction } from "hardhat-deploy/types";

import { checkAddressValid, getTokenAddressFromConfig, getWalletAddressFromConfig, isAddressValid } from "../../utils";
import { readFileSync } from "fs";
import { ConfigData } from "../../utils/types";

const contractName = "sPRL2V2";

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

  const sprl2v2Data = config.sprl2v2;
  const prlToken = getTokenAddressFromConfig("prl", config);
  const wethToken = getTokenAddressFromConfig("weth", config);

  const permit2 = checkAddressValid(sprl2v2Data.permit2, "Permit2");
  const feeReceiver = getWalletAddressFromConfig(sprl2v2Data.feeReceiver, config);
  const balancerRouter = checkAddressValid(sprl2v2Data.balancerV3Router, "Balancer V3 Router");
  const balancerBPT = checkAddressValid(sprl2v2Data.balancerBPT, "Balancer BPT");

  const BPTConfigParams = {
    balancerRouter: balancerRouter,
    balancerBPT: balancerBPT,
    prl: prlToken,
    weth: wethToken,
    permit2: permit2,
  };
  const contract = await deploy(contractName, {
    from: deployer,
    args: [
      feeReceiver,
      accessManager,
      sprl2v2Data.startPenaltyPercentage,
      sprl2v2Data.timeLockDuration,
      BPTConfigParams,
    ],
    log: true,
    skipIfAlreadyDeployed: false,
  });

  console.log(`Deployed contract: ${contractName}, network: ${hre.network.name}, address: ${contract.address}`);
};

deploy.tags = [contractName];
export default deploy;
