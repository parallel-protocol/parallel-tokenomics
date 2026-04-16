// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./Base.s.sol";

import { SideChainFeeCollector } from "contracts/fees/SideChainFeeCollector.sol";
import { FeeCollectorCore } from "contracts/fees/FeeCollectorCore.sol";

contract SetSideChainFeeCollectorRole is BaseScript {
    address sideChainFeeCollector = 0x2A4ABC8dcBE2f68E48dFc0db5784C71dB8d5B89c;

    function run() public broadcast {
        bytes4[] memory guardianSelectors = new bytes4[](3);
        guardianSelectors[0] = FeeCollectorCore.pause.selector;
        guardianSelectors[1] = FeeCollectorCore.unpause.selector;
        guardianSelectors[2] = FeeCollectorCore.emergencyRescue.selector;
        accessManager.setTargetFunctionRole(sideChainFeeCollector, guardianSelectors, Roles.GUARDIAN_ROLE);

        bytes4[] memory governorSelectors = new bytes4[](2);
        governorSelectors[0] = SideChainFeeCollector.updateDestinationReceiver.selector;
        governorSelectors[1] = SideChainFeeCollector.updateBridgeableToken.selector;
        accessManager.setTargetFunctionRole(sideChainFeeCollector, governorSelectors, Roles.GOVERNOR_ROLE);

        bytes4[] memory keeperSelectors = new bytes4[](1);
        keeperSelectors[0] = SideChainFeeCollector.swapLzToken.selector;
        accessManager.setTargetFunctionRole(sideChainFeeCollector, keeperSelectors, Roles.KEEPER_ROLE);
    }
}
