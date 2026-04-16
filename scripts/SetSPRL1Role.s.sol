// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./Base.s.sol";

import { TimeLockPenaltyERC20 } from "contracts/sPRL/TimeLockPenaltyERC20.sol";

contract SetSPRL1Role is BaseScript {
    address sprl1 = 0x7Df74BBB6F82eC1BCB1562a30ef5Bf5c326e2811;

    function run() public broadcast {
        bytes4[] memory guardianSelectors = new bytes4[](2);
        guardianSelectors[0] = TimeLockPenaltyERC20.pause.selector;
        guardianSelectors[1] = TimeLockPenaltyERC20.unpause.selector;
        accessManager.setTargetFunctionRole(sprl1, guardianSelectors, Roles.GUARDIAN_ROLE);

        bytes4[] memory governorSelectors = new bytes4[](3);
        governorSelectors[0] = TimeLockPenaltyERC20.updateFeeReceiver.selector;
        governorSelectors[1] = TimeLockPenaltyERC20.updateStartPenaltyPercentage.selector;
        governorSelectors[2] = TimeLockPenaltyERC20.updateTimeLockDuration.selector;
        accessManager.setTargetFunctionRole(sprl1, governorSelectors, Roles.GOVERNOR_ROLE);
    }
}
