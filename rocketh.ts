// ------------------------------------------------------------------------------------------------
// Typed Config
// ------------------------------------------------------------------------------------------------
import type { UserConfig } from "rocketh/types";

export const config = {
  accounts: {
    deployer: {
      default: 0,
    },
  },
  data: {},
} as const satisfies UserConfig;

// ------------------------------------------------------------------------------------------------
// Extensions available to the deploy scripts through the environment object.
// ------------------------------------------------------------------------------------------------
import * as deployExtension from "@rocketh/deploy"; // provides a deploy function
import * as readExecuteExtension from "@rocketh/read-execute"; // provides read/execute functions
import * as deployProxyExtension from "@rocketh/proxy"; // provides deployViaProxy for proxy based contracts
import * as viemExtension from "@rocketh/viem"; // provides viem handles to clients and contracts
const extensions = {
  ...deployExtension,
  ...readExecuteExtension,
  ...deployProxyExtension,
  ...viemExtension,
};

// ------------------------------------------------------------------------------------------------
// Re-export the generated artifacts so they are available from the @rocketh alias.
import * as artifacts from "./generated/artifacts";
export { artifacts };

// ------------------------------------------------------------------------------------------------
// Create the deployScript helper bound to our extensions and typed config.
import { setupDeployScripts } from "rocketh";
const { deployScript } = setupDeployScripts<typeof extensions, typeof config.accounts, typeof config.data>(extensions);
export { deployScript };
