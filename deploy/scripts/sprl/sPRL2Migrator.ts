import assert from "assert";
import { deployScript, artifacts } from "@rocketh";

import { checkAddressValid } from "../../utils";

const contractName = "sPRL2Migrator";

// Wires the migrator to the canonical sPRL2 (legacy) and sPRL2V2 deployments, read through rocketh `get`, which
// throws if a deployment is missing. There is deliberately no `dependencies` entry: the legacy sPRL2 record was
// written by hardhat-deploy v1 and has no `argsData`, so rocketh would see it as changed and redeploy sPRL2 if its
// script ran again. Deploy sPRL2 and sPRL2V2 first.
export default deployScript(
  async ({ namedAccounts, name, deploy, get }) => {
    const { deployer } = namedAccounts;
    assert(deployer, "Missing deployer account");
    console.log(`Network: ${name}\nDeployer: ${deployer}\nDeploying: ${contractName}`);

    const sprl2 = checkAddressValid(get("sPRL2").address, "sPRL2 deployment");
    const sprl2v2 = checkAddressValid(get("sPRL2V2").address, "sPRL2V2 deployment");

    console.log(`Using sPRL2 (legacy): ${sprl2}`);
    console.log(`Using sPRL2V2:        ${sprl2v2}`);

    const contract = await deploy(contractName, {
      account: deployer,
      artifact: artifacts.sPRL2Migrator,
      args: [sprl2, sprl2v2],
    });

    console.log(`Deployed ${contractName}, network: ${name}, address: ${contract.address}`);
  },
  {
    tags: [contractName],
  },
);
