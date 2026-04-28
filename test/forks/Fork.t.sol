// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "../Base.t.sol";

/// @notice Common logic needed by all fork tests.
abstract contract Fork_Test is Base_Test {
    address bal;
    address aura;

    function setUp() public virtual override {
        vm.createSelectFork({ blockNumber: 24_905_586, urlOrAlias: "mainnet" });

        // The base is set up after the fork is selected so that the base test contracts are deployed on the fork.
        Base_Test.setUp();

        _setForkContracts();

        address[] memory rewardTokens = new address[](2);
        rewardTokens[0] = address(bal);
        rewardTokens[1] = address(aura);

        sprl2 = _deploySPRL2(
            address(auraBpt),
            users.daoTreasury.addr,
            address(accessManager),
            DEFAULT_PENALTY_PERCENTAGE,
            DEFAULT_TIME_LOCK_DURATION,
            sPRL2.BPTConfigParams({
                balancerRouter: balancerV3RouterMock,
                auraBoosterLite: auraBoosterLiteMock,
                auraRewardsPool: auraRewardPoolMock,
                balancerBPT: bpt,
                prl: prl,
                weth: weth,
                rewardTokens: rewardTokens,
                permit2: permit2
            })
        );
    }

    function _setForkContracts() internal virtual {
        permit2 = Permit2Mock(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        vm.label({ account: address(permit2), newLabel: "Permit2" });

        auraBpt = ERC20Mock(0xC4a27dC753FF0513455D9A326d183220C078be8D);
        vm.label({ account: address(auraBpt), newLabel: "AuraBPT" });
        balancerV3RouterMock = BalancerV3RouterMock(0x5C6fb490BDFD3246EB0bB062c168DeCAF4bD9FDd);
        vm.label({ account: address(balancerV3RouterMock), newLabel: "BalancerV3Router" });
        auraBoosterLiteMock = AuraBoosterLiteMock(0xA57b8d98dAE62B26Ec3bcC4a365338157060B234);
        vm.label({ account: address(auraBoosterLiteMock), newLabel: "AuraBoosterLite" });
        auraRewardPoolMock = AuraRewardPoolMock(0x486Be73794Ec19f3e9cF57f06f03fDCf7F0A9da4);
        vm.label({ account: address(auraRewardPoolMock), newLabel: "AuraRewardPool" });

        bal = 0xba100000625a3754423978a60c9317c58a424e3D;
        vm.label({ account: address(bal), newLabel: "BAL" });
        aura = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF;
        vm.label({ account: address(aura), newLabel: "Aura" });
        bpt = ERC20Mock(0x1846C6cBE0D433e152fA358e5fF27968E18bcE7c);
        vm.label({ account: address(bpt), newLabel: "BPT" });
        prl = ERC20Mock(0x6c0aeceeDc55c9d55d8B99216a670D85330941c3);
        vm.label({ account: address(prl), newLabel: "PRL" });
        weth = WrappedNativeMock(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        vm.label({ account: address(weth), newLabel: "WETH" });
    }
}
