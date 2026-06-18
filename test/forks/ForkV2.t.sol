// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "../Base.t.sol";

/// @notice Common logic needed by all sPRL2V2 fork tests.
abstract contract ForkV2_Test is Base_Test {
    function setUp() public virtual override {
        // Fork Mainnet at a specific block number.
        vm.createSelectFork({ blockNumber: 24_905_586, urlOrAlias: "mainnet" });

        // The base is set up after the fork is selected so that the base test contracts are deployed on the fork.
        Base_Test.setUp();

        _setForkContracts();

        sprl2v2 = _deploySPRL2V2(
            users.daoTreasury.addr,
            address(accessManager),
            DEFAULT_PENALTY_PERCENTAGE,
            DEFAULT_TIME_LOCK_DURATION,
            sPRL2V2.BPTConfigParams({
                balancerRouter: IBalancerV3Router(address(balancerV3RouterMock)),
                balancerBPT: bpt,
                prl: prl,
                weth: weth,
                permit2: permit2
            })
        );
    }

    function _setForkContracts() internal virtual {
        permit2 = Permit2Mock(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        vm.label({ account: address(permit2), newLabel: "Permit2" });

        balancerV3RouterMock = BalancerV3RouterMock(0x5C6fb490BDFD3246EB0bB062c168DeCAF4bD9FDd);
        vm.label({ account: address(balancerV3RouterMock), newLabel: "BalancerV3Router" });

        bpt = ERC20Mock(0x1846C6cBE0D433e152fA358e5fF27968E18bcE7c);
        vm.label({ account: address(bpt), newLabel: "BPT" });
        prl = ERC20Mock(0x6c0aeceeDc55c9d55d8B99216a670D85330941c3);
        vm.label({ account: address(prl), newLabel: "PRL" });
        weth = WrappedNativeMock(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        vm.label({ account: address(weth), newLabel: "WETH" });
    }
}
