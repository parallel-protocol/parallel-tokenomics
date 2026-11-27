import assert from "assert";
import { deployScript, artifacts } from "@rocketh";

import { checkAddressValid } from "../../utils";
import { readFileSync } from "fs";
import { Address } from "../../utils/types";

const contractName = "sPRL2Migrator";

// Reads the addresses from the deployment records so the migrator is wired to the canonical
// sPRL2 (legacy) and sPRL2V2 deployments. Format-agnostic: both hardhat-deploy v1 and rocketh v2
// records expose a top-level `address`.
const readDeployedAddress = (network: string, deployment: string): Address => {
  const record = JSON.parse(readFileSync(`./deployments/${network}/${deployment}.json`).toString());
  return checkAddressValid(record.address as Address, `${deployment} deployment`);
};

export default deployScript(
  async ({ namedAccounts, name, deploy }) => {
    const { deployer } = namedAccounts;
    assert(deployer, "Missing deployer account");
    console.log(`Network: ${name}\nDeployer: ${deployer}\nDeploying: ${contractName}`);

    const sprl2 = readDeployedAddress(name, "sPRL2");
    const sprl2v2 = readDeployedAddress(name, "sPRL2V2");

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
