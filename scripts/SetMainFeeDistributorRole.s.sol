// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./Base.s.sol";

import { MainFeeDistributor } from "contracts/fees/MainFeeDistributor.sol";
import { FeeCollectorCore } from "contracts/fees/FeeCollectorCore.sol";

contract SetMainFeeDistributorRole is BaseScript {
    address mainFeeDistributor = 0x90337e484B1Cb02132fc150d3Afa262147348545;

    function run() public broadcast {
        bytes4[] memory guardianSelectors = new bytes4[](3);
        guardianSelectors[0] = FeeCollectorCore.pause.selector;
        guardianSelectors[1] = FeeCollectorCore.unpause.selector;
        guardianSelectors[2] = FeeCollectorCore.emergencyRescue.selector;
        accessManager.setTargetFunctionRole(mainFeeDistributor, guardianSelectors, Roles.GUARDIAN_ROLE);

        bytes4[] memory governorSelectors = new bytes4[](2);
        governorSelectors[0] = MainFeeDistributor.updateBridgeableToken.selector;
        governorSelectors[1] = MainFeeDistributor.updateFeeReceivers.selector;
        accessManager.setTargetFunctionRole(mainFeeDistributor, governorSelectors, Roles.GOVERNOR_ROLE);
    }
}
