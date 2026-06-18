// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";
import { sPRL2Migrator } from "contracts/sPRL/sPRL2Migrator.sol";

contract SPRL2Migrator_Integrations_Test is Integrations_Test {
    sPRL2Migrator migrator;
    uint256 DEPOSIT_AMOUNT = 100e18;

    function setUp() public override {
        super.setUp();
        sigUtils = new SigUtils(prl.DOMAIN_SEPARATOR());

        migrator = new sPRL2Migrator(sprl2, sprl2v2);

        // Alice deposits into sPRL2
        vm.startPrank(users.alice.addr);
        weth.approve(address(sprl2), type(uint256).max);

        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            _signPermitData(users.alice.privateKey, address(sprl2), DEPOSIT_AMOUNT, address(prl));

        sprl2.depositPRLAndWeth(DEPOSIT_AMOUNT, DEPOSIT_AMOUNT, DEPOSIT_AMOUNT, deadline, v, r, s);
        vm.stopPrank();

        // Admin pauses sPRL2 for migration
        vm.prank(users.admin.addr);
        sprl2.pause();
    }

    function test_Migrator_Constructor() external view {
        assertEq(address(migrator.SPRL2()), address(sprl2));
        assertEq(address(migrator.SPRL2V2()), address(sprl2v2));
        assertEq(address(migrator.BPT()), address(bpt));
    }

    function test_Migrator_Migrate() external {
        uint256 amount = sprl2.balanceOf(users.alice.addr);

        vm.startPrank(users.alice.addr);
        IERC20(address(sprl2)).approve(address(migrator), amount);

        vm.expectEmit(address(migrator));
        emit sPRL2Migrator.Migrated(users.alice.addr, amount);
        migrator.migrate(amount);
        vm.stopPrank();

        assertEq(sprl2.balanceOf(users.alice.addr), 0);
        assertEq(sprl2v2.balanceOf(users.alice.addr), amount);
    }

    function test_Migrator_Migrate_Partial() external {
        uint256 totalAmount = sprl2.balanceOf(users.alice.addr);
        uint256 migrateAmount = totalAmount / 2;

        vm.startPrank(users.alice.addr);
        IERC20(address(sprl2)).approve(address(migrator), migrateAmount);
        migrator.migrate(migrateAmount);
        vm.stopPrank();

        assertEq(sprl2.balanceOf(users.alice.addr), totalAmount - migrateAmount);
        assertEq(sprl2v2.balanceOf(users.alice.addr), migrateAmount);
    }

    function test_Migrator_Migrate_MultipleUsers() external {
        // Bob deposits into sPRL2
        vm.startPrank(users.bob.addr);
        weth.approve(address(sprl2), type(uint256).max);

        // sPRL2 is paused, so Bob needs to have deposited before pause
        // Instead, unpause, deposit, then re-pause
        vm.stopPrank();
        vm.prank(users.admin.addr);
        sprl2.unpause();

        vm.startPrank(users.bob.addr);
        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            _signPermitData(users.bob.privateKey, address(sprl2), DEPOSIT_AMOUNT, address(prl));
        sprl2.depositPRLAndWeth(DEPOSIT_AMOUNT, DEPOSIT_AMOUNT, DEPOSIT_AMOUNT, deadline, v, r, s);
        vm.stopPrank();

        vm.prank(users.admin.addr);
        sprl2.pause();

        // Alice migrates
        uint256 aliceAmount = sprl2.balanceOf(users.alice.addr);
        vm.startPrank(users.alice.addr);
        IERC20(address(sprl2)).approve(address(migrator), aliceAmount);
        migrator.migrate(aliceAmount);
        vm.stopPrank();

        // Bob migrates
        uint256 bobAmount = sprl2.balanceOf(users.bob.addr);
        vm.startPrank(users.bob.addr);
        IERC20(address(sprl2)).approve(address(migrator), bobAmount);
        migrator.migrate(bobAmount);
        vm.stopPrank();

        assertEq(sprl2.balanceOf(users.alice.addr), 0);
        assertEq(sprl2v2.balanceOf(users.alice.addr), aliceAmount);
        assertEq(sprl2.balanceOf(users.bob.addr), 0);
        assertEq(sprl2v2.balanceOf(users.bob.addr), bobAmount);
    }

    function test_Migrator_RevertWhen_AmountZero() external {
        vm.prank(users.alice.addr);
        vm.expectRevert(abi.encodeWithSelector(sPRL2Migrator.MigrationAmountZero.selector));
        migrator.migrate(0);
    }

    function test_Migrator_RevertWhen_NotPaused() external {
        vm.prank(users.admin.addr);
        sprl2.unpause();

        uint256 amount = sprl2.balanceOf(users.alice.addr);
        vm.startPrank(users.alice.addr);
        IERC20(address(sprl2)).approve(address(migrator), amount);
        vm.expectRevert(abi.encodeWithSelector(Pausable.ExpectedPause.selector));
        migrator.migrate(amount);
    }

    function test_Migrator_RevertWhen_InsufficientApproval() external {
        vm.startPrank(users.alice.addr);
        vm.expectRevert();
        migrator.migrate(DEPOSIT_AMOUNT);
    }
}
