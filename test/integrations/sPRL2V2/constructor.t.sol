// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract SPRL2V2_Constructor_Integrations_Test is Integrations_Test {
    function test_SPRL2V2_Constructor() external {
        sprl2v2 = new sPRL2V2(
            users.daoTreasury.addr,
            address(accessManager),
            DEFAULT_PENALTY_PERCENTAGE,
            DEFAULT_TIME_LOCK_DURATION,
            sPRL2V2.BPTConfigParams({
                balancerRouter: IBalancerV3Router(address(balancerV3RouterMock)),
                balancerBPT: IERC20(address(bpt)),
                prl: IERC20(address(prl)),
                weth: IWrappedNative(address(weth)),
                permit2: IPermit2(address(permit2))
            })
        );
        assertEq(sprl2v2.authority(), address(accessManager));
        assertEq(address(sprl2v2.underlying()), address(bpt));
        assertEq(sprl2v2.timeLockDuration(), DEFAULT_TIME_LOCK_DURATION);
        assertEq(sprl2v2.startPenaltyPercentage(), DEFAULT_PENALTY_PERCENTAGE);
        assertEq(sprl2v2.unlockingAmount(), 0);
        assertEq(sprl2v2.feeReceiver(), users.daoTreasury.addr);
        assertEq(sprl2v2.name(), "Stake 20WETH-80PRL Deposit Vault");
        assertEq(sprl2v2.symbol(), "sPRL2V2");
        assertEq(address(sprl2v2.BALANCER_ROUTER()), address(balancerV3RouterMock));
        assertEq(address(sprl2v2.BPT()), address(bpt));
        assertEq(address(sprl2v2.PRL()), address(prl));
        assertEq(address(sprl2v2.WETH()), address(weth));
        assertEq(address(sprl2v2.PERMIT2()), address(permit2));
    }
}
