// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./Base.s.sol";

import { RewardMerkleDistributor } from "contracts/rewardMerkleDistributor/RewardMerkleDistributor.sol";

contract SetRewardMerkleDistributorRole is BaseScript {
    address rewardMerkleDistributor = 0x7b54f3D993d3bcA077946034Ea710F9c07420C72;

    function run() public broadcast {
        bytes4[] memory guardianSelectors = new bytes4[](3);
        guardianSelectors[0] = RewardMerkleDistributor.pause.selector;
        guardianSelectors[1] = RewardMerkleDistributor.unpause.selector;
        guardianSelectors[2] = RewardMerkleDistributor.emergencyRescue.selector;
        accessManager.setTargetFunctionRole(rewardMerkleDistributor, guardianSelectors, Roles.GUARDIAN_ROLE);

        bytes4[] memory governorSelectors = new bytes4[](1);
        governorSelectors[0] = RewardMerkleDistributor.updateExpiredRewardsRecipient.selector;
        accessManager.setTargetFunctionRole(rewardMerkleDistributor, governorSelectors, Roles.GOVERNOR_ROLE);

        bytes4[] memory keeperSelectors = new bytes4[](1);
        keeperSelectors[0] = RewardMerkleDistributor.updateMerkleDrop.selector;
        accessManager.setTargetFunctionRole(rewardMerkleDistributor, keeperSelectors, Roles.KEEPER_ROLE);
    }
}
