// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract TimeLockPenaltyERC20_RecoverERC20_Integrations_Test is Integrations_Test {
    uint256 internal constant REWARD_AMOUNT = 1e18;

    function setUp() public override {
        super.setUp();
        // Simulate reward tokens being sent to the contract on its behalf (e.g. MERKL claim).
        rewardToken.mint(address(timeLockPenaltyERC20), REWARD_AMOUNT);
    }

    function test_TimeLockPenaltyERC20_RecoverERC20() external {
        vm.startPrank(users.admin.addr);
        vm.expectEmit(address(timeLockPenaltyERC20));
        emit TimeLockPenaltyERC20.TokensRecovered(address(rewardToken), REWARD_AMOUNT);
        timeLockPenaltyERC20.recoverERC20(IERC20(address(rewardToken)));

        assertEq(rewardToken.balanceOf(address(timeLockPenaltyERC20)), 0);
        assertEq(rewardToken.balanceOf(timeLockPenaltyERC20.feeReceiver()), REWARD_AMOUNT);
    }

    function test_TimeLockPenaltyERC20_RecoverERC20_RevertWhen_TokenIsUnderlying() external {
        // The mock's underlying is PRL (see Integrations setUp).
        vm.startPrank(users.admin.addr);
        vm.expectRevert(TimeLockPenaltyERC20.CannotRecoverUnderlying.selector);
        timeLockPenaltyERC20.recoverERC20(IERC20(address(prl)));
    }

    function test_TimeLockPenaltyERC20_RecoverERC20_RevertWhen_CallerNotAuthorized() external {
        vm.startPrank(users.hacker.addr);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker.addr));
        timeLockPenaltyERC20.recoverERC20(IERC20(address(rewardToken)));
    }
}
