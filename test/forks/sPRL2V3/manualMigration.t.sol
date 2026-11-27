// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { Test } from "@forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { sPRL2V2 } from "contracts/sPRL/sPRL2V2.sol";
import { sPRL2V3 } from "contracts/sPRL/sPRL2V3.sol";
import { TimeLockPenaltyERC20 } from "contracts/sPRL/TimeLockPenaltyERC20.sol";
import { IBalancerV3Router } from "contracts/interfaces/IBalancerV3Router.sol";
import { IPermit2 } from "contracts/interfaces/IPermit2.sol";
import { IBalancerV3Pool, IBalancerV3SwapRouter } from "contracts/interfaces/IBalancerV3Vault.sol";
import { AlignFrontierAndSunset } from "scripts/AlignFrontierAndSunset.s.sol";

interface IFrontierVaultErrors {
    error AmountInAboveMax(IERC20 tokenIn, uint256 amountIn, uint256 maxAmountIn);
    error SwapLimit(uint256 amount, uint256 limit);
}

/// @notice Manual migration of the live Balancer-backed sPRL2V2 positions to the Frontier-backed sPRL2V3, on a fork.
/// The DAO Safe runs the batch built by AlignFrontierAndSunset (align the Frontier price, penalty to 0, pause), then
/// each user exits sPRL2V2 with requestWithdraw and withdrawPRLAndWeth in a row, and deposits the PRL and WETH into
/// sPRL2V3 with depositPRLAndWeth.
abstract contract ManualMigration_Fork_Test is Test {
    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant FRONTIER_ROUTER = 0xB3C45499aa0ad2fF5d586E7d473C75d5781c557B;
    /// @dev BPT slippage the frontend takes off its quote. The max amounts in stay the full withdrawn amounts.
    uint256 constant SLIPPAGE_BPS = 50;
    /// @dev Slippage on the alignment swap of the DAO batch (the script default).
    uint256 constant BATCH_SLIPPAGE_BPS = 100;

    sPRL2V2 from;
    sPRL2V3 to;
    IERC20 prl;
    IERC20 weth;
    address dao;
    address[] holders;
    uint256 initialPenalty;
    AlignFrontierAndSunset script;
    AlignFrontierAndSunset.Config batchConfig;
    /// @dev State right before the DAO batch runs.
    uint256 beforeBatch;

    function _fork() internal virtual;
    function _config()
        internal
        view
        virtual
        returns (address source, address frontierPool, address accessManager, address daoWallet);
    function _holders() internal view virtual returns (address[] memory);

    function setUp() public {
        _fork();
        (address source, address frontierPool, address accessManager, address daoWallet) = _config();
        from = sPRL2V2(payable(source));
        dao = daoWallet;
        holders = _holders();
        prl = from.PRL();
        weth = IERC20(address(from.WETH()));
        initialPenalty = from.startPenaltyPercentage();

        to = new sPRL2V3(
            dao,
            accessManager,
            initialPenalty,
            from.timeLockDuration(),
            sPRL2V3.BPTConfigParams({
                balancerRouter: IBalancerV3Router(FRONTIER_ROUTER),
                balancerBPT: IERC20(frontierPool),
                prl: prl,
                weth: from.WETH(),
                permit2: IPermit2(PERMIT2)
            })
        );
        /// @dev The live Frontier pools are not at the Balancer price yet (25% off on mainnet at this block). The Base
        /// Safe holds no PRL at this block, so fund both Safes for the alignment swap.
        script = new AlignFrontierAndSunset();
        batchConfig = AlignFrontierAndSunset.Config({ source: from, frontierPool: frontierPool, dao: dao });
        deal(address(prl), dao, prl.balanceOf(dao) + 1_000_000e18);
        deal(address(weth), dao, weth.balanceOf(dao) + 1000e18);
        beforeBatch = vm.snapshotState();

        this.executeBatch(script.build(batchConfig, BATCH_SLIPPAGE_BPS, block.timestamp + 1 days));
        assertLe(script.priceDeviation(batchConfig), script.TARGET_DEVIATION());
        assertTrue(from.paused());
        assertEq(from.startPenaltyPercentage(), 0);
    }

    /// @dev Runs the batch from the DAO Safe. External so that a revert undoes the whole batch, as the Safe MultiSend
    /// does.
    function executeBatch(AlignFrontierAndSunset.Transaction[] memory _txs) external {
        for (uint256 i; i < _txs.length; ++i) {
            vm.prank(dao);
            (bool success, bytes memory result) = _txs[i].to.call(_txs[i].data);
            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }
        }
    }

    /// @dev The batch is atomic: if the Frontier price moves before the Safe executes it, the alignment swap misses
    /// its minAmountOut and the sunset does not happen either.
    function test_fork_ManualMigration_RevertWhen_FrontierPriceMovedBeforeBatch() external {
        vm.revertToState(beforeBatch);
        AlignFrontierAndSunset.Transaction[] memory txs =
            script.build(batchConfig, BATCH_SLIPPAGE_BPS, block.timestamp + 1 days);

        /// @dev Someone sells 1% of the Frontier PRL balance first: the alignment swap now returns about 5% less WETH.
        (uint256 toPrl,) = _poolBalances(address(to.BPT()));
        _swap(makeAddr("front runner"), prl, weth, toPrl / 100);

        vm.expectPartialRevert(IFrontierVaultErrors.SwapLimit.selector);
        this.executeBatch(txs);
        assertFalse(from.paused());
        assertEq(from.startPenaltyPercentage(), initialPenalty);
    }

    function test_fork_ManualMigration_AllHolders() external {
        uint256 feeReceiverBpt = from.BPT().balanceOf(from.feeReceiver());
        uint256 totalShares;
        for (uint256 i; i < holders.length; ++i) {
            address user = holders[i];
            uint256 amount = from.balanceOf(user);
            if (amount == 0) continue;
            uint256 price = _sourcePrice();

            (uint256 prlOut, uint256 wethOut) = _exit(user, amount);
            assertGt(prlOut, 0);
            assertGt(wethOut, 0);
            assertEq(from.balanceOf(user), 0);

            (uint256 shares, uint256 prlRefund, uint256 wethRefund) = _enter(user, prlOut, wethOut);
            assertEq(to.balanceOf(user), shares);
            totalShares += shares;

            /// @dev Valued at the Balancer price, the user keeps what they had: the proportional join only loses the
            /// BPT slippage, which comes back as refunds, and the price gap left after alignment.
            uint256 valueBefore = Math.mulDiv(prlOut, price, 1e18) + wethOut;
            uint256 valueAfter = _destinationValue(shares, price) + Math.mulDiv(prlRefund, price, 1e18) + wethRefund;
            assertApproxEqRel(valueAfter, valueBefore, 0.0001e18);
        }
        assertEq(from.BPT().balanceOf(from.feeReceiver()), feeReceiverBpt, "no penalty taken");
        assertEq(to.totalSupply(), totalShares);
        assertEq(to.BPT().balanceOf(address(to)), totalShares);
    }

    /// @dev Once the sunset is done, the same script builds an alignment-only batch to realign the pool mid-migration.
    function test_fork_ManualMigration_RealignAfterSunset() external {
        (uint256 toPrl,) = _poolBalances(address(to.BPT()));
        _swap(makeAddr("seller"), prl, weth, toPrl * 2 / 100);
        assertGt(script.priceDeviation(batchConfig), script.MAX_DEVIATION());

        AlignFrontierAndSunset.Transaction[] memory txs =
            script.build(batchConfig, BATCH_SLIPPAGE_BPS, block.timestamp + 1 days);
        assertEq(txs.length, 3, "approve, Permit2 approve, swap");
        this.executeBatch(txs);
        assertLe(script.priceDeviation(batchConfig), script.TARGET_DEVIATION());
    }

    function test_fork_ManualMigration_PendingRequestWithoutFee() external {
        address user = holders[0];
        uint256 amount = from.balanceOf(user);
        address feeReceiver = from.feeReceiver();

        /// @dev A request made before the sunset, one day into its timelock.
        vm.prank(dao);
        from.updateStartPenaltyPercentage(initialPenalty);
        uint256 id = from.userVsNextID(user);
        vm.prank(user);
        from.requestWithdraw(amount);
        skip(1 days);
        vm.prank(dao);
        from.updateStartPenaltyPercentage(0);

        uint256 feeReceiverBpt = from.BPT().balanceOf(feeReceiver);
        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        vm.prank(user);
        from.withdrawBPT(ids, 0);

        assertEq(from.BPT().balanceOf(user), amount);
        assertEq(from.BPT().balanceOf(feeReceiver), feeReceiverBpt);
    }

    function test_fork_ManualMigration_RevertWhen_PenaltyNotCancelled() external {
        vm.prank(dao);
        from.updateStartPenaltyPercentage(initialPenalty);

        address user = holders[0];
        uint256[] memory ids = new uint256[](1);
        ids[0] = from.userVsNextID(user);
        vm.startPrank(user);
        from.requestWithdraw(from.balanceOf(user));
        vm.expectRevert(TimeLockPenaltyERC20.MaxPenaltyPercentageExceeded.selector);
        from.withdrawPRLAndWeth(ids, 0, 0, 0);
        vm.stopPrank();
    }

    function test_fork_ManualMigration_RevertWhen_DepositIntoSource() external {
        /// @dev whenNotPaused runs before any transfer, so the caller needs no BPT.
        vm.prank(holders[0]);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        from.depositBPT(1e18);
    }

    /// @dev The frontend quotes exactBptAmount from the Frontier balances and caps the inputs at what the user just
    /// withdrew. If the Frontier price moves past the BPT slippage before the deposit lands, the deposit reverts.
    function test_fork_ManualMigration_RevertWhen_FrontierPriceMovedAfterQuote() external {
        address user = holders[0];
        (uint256 prlOut, uint256 wethOut) = _exit(user, from.balanceOf(user));
        uint256 bptOut = _quoteJoin(prlOut, wethOut);

        /// @dev Sell 1% of the WETH balance of the Frontier pool: minting bptOut now needs about 1% more WETH.
        (, uint256 toWeth) = _poolBalances(address(to.BPT()));
        _swap(makeAddr("attacker"), weth, prl, toWeth / 100);

        vm.startPrank(user);
        prl.approve(address(to), prlOut);
        weth.approve(address(to), wethOut);
        vm.expectPartialRevert(IFrontierVaultErrors.AmountInAboveMax.selector);
        to.depositPRLAndWeth(prlOut, wethOut, bptOut, block.timestamp, 0, bytes32(0), bytes32(0));
        vm.stopPrank();
    }

    //-------------------------------------------
    // Helpers
    //-------------------------------------------

    /// @dev Exit sPRL2V2 in one block: request, then withdraw with a max penalty of 0.
    function _exit(address _user, uint256 _amount) internal returns (uint256 prlOut, uint256 wethOut) {
        uint256[] memory ids = new uint256[](1);
        ids[0] = from.userVsNextID(_user);
        uint256 prlBefore = prl.balanceOf(_user);
        uint256 wethBefore = weth.balanceOf(_user);
        vm.startPrank(_user);
        from.requestWithdraw(_amount);
        (prlOut, wethOut) = from.withdrawPRLAndWeth(ids, 0, 0, 0);
        vm.stopPrank();
        assertEq(prl.balanceOf(_user) - prlBefore, prlOut);
        assertEq(weth.balanceOf(_user) - wethBefore, wethOut);
    }

    /// @dev Deposit the withdrawn PRL and WETH into sPRL2V3, quoted as the frontend would.
    function _enter(
        address _user,
        uint256 _prlIn,
        uint256 _wethIn
    )
        internal
        returns (uint256 shares, uint256 prlRefund, uint256 wethRefund)
    {
        uint256 bptOut = _quoteJoin(_prlIn, _wethIn);
        uint256 prlBefore = prl.balanceOf(_user);
        uint256 wethBefore = weth.balanceOf(_user);
        vm.startPrank(_user);
        prl.approve(address(to), _prlIn);
        weth.approve(address(to), _wethIn);
        (, shares) = to.depositPRLAndWeth(_prlIn, _wethIn, bptOut, block.timestamp, 0, bytes32(0), bytes32(0));
        vm.stopPrank();
        assertEq(shares, bptOut);
        prlRefund = prl.balanceOf(_user) - (prlBefore - _prlIn);
        wethRefund = weth.balanceOf(_user) - (wethBefore - _wethIn);
    }

    /// @dev BPT a proportional join of these amounts mints, minus the slippage. Balancer V3 rounds the amounts in up,
    /// so flooring each ratio keeps both inputs under their max.
    function _quoteJoin(uint256 _prlIn, uint256 _wethIn) internal view returns (uint256) {
        (uint256 toPrl, uint256 toWeth) = _poolBalances(address(to.BPT()));
        uint256 supply = to.BPT().totalSupply();
        uint256 bptOut = Math.min(Math.mulDiv(_prlIn, supply, toPrl), Math.mulDiv(_wethIn, supply, toWeth));
        return bptOut * (10_000 - SLIPPAGE_BPS) / 10_000;
    }

    function _destinationValue(uint256 _shares, uint256 _price) internal view returns (uint256) {
        (uint256 toPrl, uint256 toWeth) = _poolBalances(address(to.BPT()));
        return Math.mulDiv(Math.mulDiv(toPrl, _price, 1e18) + toWeth, _shares, to.BPT().totalSupply());
    }

    function _poolBalances(address _pool) internal view returns (uint256 prlBalance, uint256 wethBalance) {
        (IERC20[] memory tokens,, uint256[] memory balances,) =
            IBalancerV3Pool(_pool).getVault().getPoolTokenInfo(_pool);
        (prlBalance, wethBalance) = tokens[0] == prl ? (balances[0], balances[1]) : (balances[1], balances[0]);
    }

    /// @dev Spot PRL price of the Balancer pool in WETH (1e18 precision): an 80/20 pool prices PRL at 4 * weth / prl.
    function _sourcePrice() internal view returns (uint256) {
        (uint256 fromPrl, uint256 fromWeth) = _poolBalances(address(from.BPT()));
        return Math.mulDiv(fromWeth, 4e18, fromPrl);
    }

    function _swap(address _who, IERC20 _tokenIn, IERC20 _tokenOut, uint256 _amountIn) internal returns (uint256) {
        deal(address(_tokenIn), _who, _amountIn);
        vm.startPrank(_who);
        _tokenIn.approve(PERMIT2, type(uint256).max);
        IPermit2(PERMIT2).approve(address(_tokenIn), FRONTIER_ROUTER, type(uint160).max, type(uint48).max);
        uint256 amountOut = IBalancerV3SwapRouter(FRONTIER_ROUTER)
            .swapSingleTokenExactIn(address(to.BPT()), _tokenIn, _tokenOut, _amountIn, 0, block.timestamp, false, "");
        vm.stopPrank();
        return amountOut;
    }
}

/// @dev PRL is the first token of both pools.
contract ManualMigration_Mainnet_Fork_Test is ManualMigration_Fork_Test {
    function _fork() internal override {
        vm.createSelectFork({ blockNumber: 26_499_213, urlOrAlias: "mainnet" });
    }

    function _config() internal pure override returns (address, address, address, address) {
        return (
            0xa13BFA24b189271Ac00b148BE565D609AC847A4B,
            0xbF596e932c2476165264b211eF8D6f4574a9a1A6,
            0x94Ea8800444017695345156319e96bdB1E355F7a,
            0x25Fc7ffa8f9da3582a36633d04804F0004706F9b
        );
    }

    function _holders() internal pure override returns (address[] memory h) {
        h = new address[](5);
        h[0] = 0x857F56db9E7f4a6d203998d9266327fcB6F08cF2;
        h[1] = 0x05f9658C0Be31c975CCa99Ab77418Bd53812418E;
        h[2] = 0xBabB038737A7Ae0DcA02075E79ed5B7704C29827;
        h[3] = 0xB9Bb02813C802fFf656361fC10F3255706bc4C17;
        h[4] = 0xD758e17c0d96a6C753995D86e891E07286858130;
    }
}

/// @dev WETH is the first token of both pools.
contract ManualMigration_Base_Fork_Test is ManualMigration_Fork_Test {
    function _fork() internal override {
        vm.createSelectFork({ blockNumber: 62_519_277, urlOrAlias: "base" });
    }

    function _config() internal pure override returns (address, address, address, address) {
        return (
            0xB22f5eDbc62adCC093307025B8fdf75a0aa00e24,
            0x4D81A370dDFc086274f7F73738dBf0CAfAa6ee4c,
            0x0e4e7Ca9D7b1e6293D0713EFEfB4BCA010DeBF46,
            0xC5201FFE258a95Af986E7cD1fcaD54f3f63f2C95
        );
    }

    function _holders() internal pure override returns (address[] memory h) {
        h = new address[](3);
        h[0] = 0x2F14549FBa71b8C86e2F226589c0D917bd967D73;
        h[1] = 0x87aCAc58a3d3966be2B8238BD000576C8b3CAE0C;
        h[2] = 0xd04Fcfa304546CA8F24fe9610D7240eDc3409Ce3;
    }
}
