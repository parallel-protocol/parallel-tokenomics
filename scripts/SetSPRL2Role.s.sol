// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./Base.s.sol";

import { sPRL2 } from "contracts/sPRL/sPRL2.sol";
import { TimeLockPenaltyERC20 } from "contracts/sPRL/TimeLockPenaltyERC20.sol";

contract SetSPRL2Role is BaseScript {
    address sprl2 = 0x90337e484B1Cb02132fc150d3Afa262147348545;

    function run() public broadcast {
        bytes4[] memory guardianSelectors = new bytes4[](2);
        guardianSelectors[0] = TimeLockPenaltyERC20.pause.selector;
        guardianSelectors[1] = TimeLockPenaltyERC20.unpause.selector;
        console2.log("guardianSelectors", guardianSelectors);
        // accessManager.setTargetFunctionRole(sprl2, guardianSelectors, Roles.GUARDIAN_ROLE);

        bytes4[] memory governorSelectors = new bytes4[](4);
        governorSelectors[0] = TimeLockPenaltyERC20.updateFeeReceiver.selector;
        governorSelectors[1] = TimeLockPenaltyERC20.updateStartPenaltyPercentage.selector;
        governorSelectors[2] = TimeLockPenaltyERC20.updateTimeLockDuration.selector;
        governorSelectors[3] = sPRL2.updateRewardTokens.selector;
        console2.log("governorSelectors", governorSelectors);
        // accessManager.setTargetFunctionRole(sprl2, governorSelectors, Roles.GOVERNOR_ROLE);
    }
}
