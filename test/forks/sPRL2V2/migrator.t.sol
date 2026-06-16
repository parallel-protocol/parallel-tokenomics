// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "test/forks/ForkV2.t.sol";
import { sPRL2 } from "contracts/sPRL/sPRL2.sol";
import { sPRL2Migrator } from "contracts/sPRL/sPRL2Migrator.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAccessManager } from "@openzeppelin/contracts/access/manager/IAccessManager.sol";

contract SPRL2Migrator_Fork_Test is ForkV2_Test {
    sPRL2 sprl2Legacy;
    sPRL2Migrator migrator;

    address admin = 0x25Fc7ffa8f9da3582a36633d04804F0004706F9b;
    address user = address(0xBEEF);

    function setUp() public override {
        super.setUp();

        sprl2Legacy = sPRL2(payable(0xE8A2d848fE656E34A6caA35f375B42979e322135));
        vm.label(address(sprl2Legacy), "sPRL2Legacy");

        migrator = new sPRL2Migrator(sprl2Legacy, sprl2v2);

        // User deposits into sPRL2
        uint256 depositAmount = 1e18;
        vm.startPrank(user);
        deal(address(prl), user, 100e18);
        deal(address(weth), user, 100e18);

        IERC20(address(prl)).approve(address(permit2), type(uint256).max);
        IERC20(address(weth)).approve(address(permit2), type(uint256).max);

        uint48 deadline = uint48(block.timestamp + 15);
        permit2.approve(address(prl), address(balancerV3RouterMock), type(uint160).max, deadline);
        permit2.approve(address(weth), address(balancerV3RouterMock), type(uint160).max, deadline);

        balancerV3RouterMock.addLiquidityProportional(
            address(bpt), _getMaxDepositAmountParams(100e18, 100e18), depositAmount, false, ""
        );

        bpt.approve(address(sprl2Legacy), depositAmount);
        sprl2Legacy.depositBPT(depositAmount);
        vm.stopPrank();

        // Admin pauses sPRL2
        vm.prank(admin);
        sprl2Legacy.pause();
    }

    function test_fork_Migrator_Migrate() external {
        uint256 amount = sprl2Legacy.balanceOf(user);

        vm.startPrank(user);
        IERC20(address(sprl2Legacy)).approve(address(migrator), amount);
        migrator.migrate(amount);
        vm.stopPrank();

        assertEq(sprl2Legacy.balanceOf(user), 0);
        assertEq(sprl2v2.balanceOf(user), amount);
    }

    function test_fork_Migrator_Migrate_Partial() external {
        uint256 totalAmount = sprl2Legacy.balanceOf(user);
        uint256 migrateAmount = totalAmount / 2;

        vm.startPrank(user);
        IERC20(address(sprl2Legacy)).approve(address(migrator), migrateAmount);
        migrator.migrate(migrateAmount);
        vm.stopPrank();

        assertEq(sprl2Legacy.balanceOf(user), totalAmount - migrateAmount);
        assertEq(sprl2v2.balanceOf(user), migrateAmount);
    }

    function _getMaxDepositAmountParams(
        uint256 maxPrlAmount,
        uint256 maxWethAmount
    )
        internal
        view
        returns (uint256[] memory maxAmountsIn)
    {
        maxAmountsIn = new uint256[](2);
        (maxAmountsIn[0], maxAmountsIn[1]) =
            address(weth) > address(prl) ? (maxPrlAmount, maxWethAmount) : (maxWethAmount, maxPrlAmount);
    }
}
