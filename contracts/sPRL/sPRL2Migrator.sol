// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { sPRL2 } from "./sPRL2.sol";
import { sPRL2V2 } from "./sPRL2V2.sol";

/// @title sPRL2Migrator
/// @author Cooper Labs
/// @custom:contact security@cooperlabs.xyz
/// @notice Migrates sPRL2 positions to sPRL2V2 in a single transaction.
/// @dev Requires sPRL2 to be paused so that emergencyWithdraw is available.
contract sPRL2Migrator {
    using SafeERC20 for IERC20;

    sPRL2 public immutable SPRL2;
    sPRL2V2 public immutable SPRL2V2;
    IERC20 public immutable BPT;

    error MigrationAmountZero();

    event Migrated(address indexed user, uint256 amount);

    constructor(sPRL2 _sprl2, sPRL2V2 _sprl2v2) {
        SPRL2 = _sprl2;
        SPRL2V2 = _sprl2v2;
        BPT = _sprl2v2.BPT();

        BPT.approve(address(_sprl2v2), type(uint256).max);
    }

    /// @notice Migrate sPRL2 tokens to sPRL2V2.
    /// @dev User must approve this contract to spend their sPRL2 tokens.
    /// @dev sPRL2 must be paused for emergencyWithdraw to work.
    /// @param _amount The amount of sPRL2 to migrate.
    function migrate(uint256 _amount) external {
        if (_amount == 0) revert MigrationAmountZero();

        // Transfer sPRL2 from user
        IERC20(address(SPRL2)).safeTransferFrom(msg.sender, address(this), _amount);

        // Emergency withdraw BPT from sPRL2 (requires paused)
        SPRL2.emergencyWithdraw(_amount);

        // Deposit BPT into sPRL2V2 (mints sPRL2V2 to this contract)
        SPRL2V2.depositBPT(_amount);

        // Transfer sPRL2V2 to user
        IERC20(address(SPRL2V2)).safeTransfer(msg.sender, _amount);

        emit Migrated(msg.sender, _amount);
    }
}
