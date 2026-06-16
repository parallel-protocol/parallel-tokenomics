// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import "test/Integrations.t.sol";

contract SPRL2V2_CancelWithdrawalRequests_Integrations_Test is Integrations_Test {
    function setUp() public override {
        super.setUp();
        vm.startPrank(users.alice.addr);

        deal(address(bpt), address(users.alice.addr), INITIAL_BALANCE);
        bpt.approve(address(sprl2v2), type(uint256).max);
        sprl2v2.depositBPT(INITIAL_BALANCE);
    }

    modifier requestOneWithdraw() {
        sprl2v2.requestWithdraw(INITIAL_BALANCE);
        _;
    }

    function test_SPRL2V2_CancelWithdrawalRequests_SingleRequest() external requestOneWithdraw {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        vm.expectEmit(address(sprl2v2));
        emit TimeLockPenaltyERC20.WithdrawalRequestCancelled(ids[0], users.alice.addr, INITIAL_BALANCE);
        sprl2v2.cancelWithdrawalRequests(ids);
        assertEq(sprl2v2.balanceOf(users.alice.addr), INITIAL_BALANCE);
        assertEq(sprl2v2.unlockingAmount(), 0);

        (uint256 requestAmount, uint64 requestTime, uint64 releaseTime, TimeLockPenaltyERC20.WITHDRAW_STATUS status) =
            sprl2v2.userVsWithdrawals(users.alice.addr, ids[0]);

        assertEq(requestAmount, INITIAL_BALANCE);
        assertEq(requestTime, block.timestamp);
        assertEq(releaseTime, block.timestamp + sprl2v2.timeLockDuration());
        assertEq(status, TimeLockPenaltyERC20.WITHDRAW_STATUS.CANCELLED);

        uint256[] memory requestIds = sprl2v2.findUnlockingIDs(users.alice.addr, 0, false, 1);
        assertEq(requestIds.length, 0);
    }

    modifier requestMultiWithdraw() {
        sprl2v2.requestWithdraw(1);
        sprl2v2.requestWithdraw(2);
        sprl2v2.requestWithdraw(3);
        sprl2v2.requestWithdraw(4);
        sprl2v2.requestWithdraw(5);
        _;
    }

    function test_SPRL2V2_CancelWithdrawalRequests_MultipleRequests() external requestMultiWithdraw {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 0;
        ids[1] = 2;
        ids[2] = 4;
        sprl2v2.cancelWithdrawalRequests(ids);

        assertEq(sprl2v2.balanceOf(users.alice.addr), INITIAL_BALANCE - 6);
        assertEq(sprl2v2.unlockingAmount(), 6);

        uint256[] memory requestIds = sprl2v2.findUnlockingIDs(users.alice.addr, 0, false, 10);
        assertEq(requestIds.length, 2);
        assertEq(requestIds[0], 1);
        assertEq(requestIds[1], 3);
    }

    function test_SPRL2V2_CancelWithdrawalRequests_RevertWhen_WrongRequestStatus() external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        vm.expectRevert(abi.encodeWithSelector(TimeLockPenaltyERC20.CannotCancelWithdrawalRequest.selector, ids[0]));
        sprl2v2.cancelWithdrawalRequests(ids);
    }
}
