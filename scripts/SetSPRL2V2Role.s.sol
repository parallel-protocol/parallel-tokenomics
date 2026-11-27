// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./Base.s.sol";

import { TimeLockPenaltyERC20 } from "contracts/sPRL/TimeLockPenaltyERC20.sol";

contract SetSPRL2V2Role is BaseScript {
    address sprl2v2 = 0xa13BFA24b189271Ac00b148BE565D609AC847A4B;

    function run() public broadcast {
        bytes4[] memory guardianSelectors = new bytes4[](2);
        guardianSelectors[0] = TimeLockPenaltyERC20.pause.selector;
        guardianSelectors[1] = TimeLockPenaltyERC20.unpause.selector;
        accessManager.setTargetFunctionRole(sprl2v2, guardianSelectors, Roles.GUARDIAN_ROLE);

        bytes4[] memory governorSelectors = new bytes4[](4);
        governorSelectors[0] = TimeLockPenaltyERC20.updateFeeReceiver.selector;
        governorSelectors[1] = TimeLockPenaltyERC20.updateStartPenaltyPercentage.selector;
        governorSelectors[2] = TimeLockPenaltyERC20.updateTimeLockDuration.selector;
        governorSelectors[3] = TimeLockPenaltyERC20.recoverERC20.selector;
        accessManager.setTargetFunctionRole(sprl2v2, governorSelectors, Roles.GOVERNOR_ROLE);
    }
}
