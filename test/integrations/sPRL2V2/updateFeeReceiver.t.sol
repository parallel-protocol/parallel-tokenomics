// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract SPRL2V2_UpdateFeeReceiver_Integrations_Test is Integrations_Test {
    address internal newPaymentReceiver = makeAddr("newPaymentReceiver");

    function test_sPRL2V2_UpdateFeeReceiver() external {
        vm.startPrank(users.admin.addr);
        vm.expectEmit(address(sprl2v2));
        emit TimeLockPenaltyERC20.FeeReceiverUpdated(newPaymentReceiver);
        sprl2v2.updateFeeReceiver(newPaymentReceiver);
    }

    function test_SPRL2V2_UpdateFeeReceiver_RevertWhen_CallerNotAuthorized() external {
        vm.startPrank(users.hacker.addr);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker.addr));
        sprl2v2.updateFeeReceiver(newPaymentReceiver);
    }

    function test_SPRL2V2_UpdateFeeReceiver_RevertWhen_ZeroAddress() external {
        vm.startPrank(users.admin.addr);
        vm.expectRevert(TimeLockPenaltyERC20.FeeReceiverZeroAddress.selector);
        sprl2v2.updateFeeReceiver(address(0));
    }
}
