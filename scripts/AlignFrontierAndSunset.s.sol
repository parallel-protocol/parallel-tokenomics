// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Script, console2 } from "@forge-std/Script.sol";
import { StdCheats } from "@forge-std/StdCheats.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { sPRL2V2 } from "contracts/sPRL/sPRL2V2.sol";
import { TimeLockPenaltyERC20 } from "contracts/sPRL/TimeLockPenaltyERC20.sol";
import { IPermit2 } from "contracts/interfaces/IPermit2.sol";
import { IBalancerV3Pool, IBalancerV3SwapRouter } from "contracts/interfaces/IBalancerV3Vault.sol";

/// @notice Writes the DAO Safe batch that opens the sPRL2V2 to sPRL2V3 migration, in one atomic transaction:
/// 1. align the Frontier PRL price with the Balancer one: approve Permit2, approve the Frontier router on Permit2,
///    swap (skipped when the gap is already under TARGET_DEVIATION);
/// 2. updateStartPenaltyPercentage(0) on sPRL2V2, so every withdrawal request can be withdrawn at once without fee;
/// 3. pause() on sPRL2V2, to block new deposits.
/// Steps 2 and 3 are left out once done, so the same script realigns the pool during the migration.
/// The swap carries a minAmountOut: if the Frontier price moved by more than the slippage before the Safe executes,
/// the swap reverts and the sunset with it. Build a new batch then. Before writing the file, the script runs the
/// whole batch from the DAO Safe on the fork and checks the price gap, the penalty and the pause.
/// Usage: forge script scripts/AlignFrontierAndSunset.s.sol --rpc-url <mainnet|base>
/// Optional env: SLIPPAGE_BPS (default 100), VALIDITY in seconds (default 3 days).
/// Output: batches/sprl2v2-align-and-sunset.<network>.safe.json, to load in the Safe Transaction Builder.
contract AlignFrontierAndSunset is Script, StdCheats {
    struct Config {
        sPRL2V2 source;
        address frontierPool;
        address dao;
    }

    struct Transaction {
        address to;
        bytes data;
    }

    struct Swap {
        IERC20 tokenIn;
        IERC20 tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
    }

    address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant FRONTIER_ROUTER = 0xB3C45499aa0ad2fF5d586E7d473C75d5781c557B;
    /// @dev Gap the alignment aims for (1e18 = 100%).
    uint256 public constant TARGET_DEVIATION = 0.001e18;
    /// @dev Gap above which the migration must not open: each pool charges a 1% swap fee, so arbitrage keeps the two
    /// prices within about 2% of each other.
    uint256 public constant MAX_DEVIATION = 0.02e18;
    /// @dev Balancer V3 weighted pools cap a swap at 30% of the balance of the token in.
    uint256 constant MAX_IN_RATIO = 0.29e18;

    function run() external {
        (Config memory c, string memory network) = config(block.chainid);
        uint256 slippageBps = vm.envOr("SLIPPAGE_BPS", uint256(100));
        uint256 deadline = block.timestamp + vm.envOr("VALIDITY", uint256(3 days));
        Transaction[] memory txs = build(c, slippageBps, deadline);
        _write(network, c.dao, txs);
    }

    function config(uint256 _chainId) public pure returns (Config memory, string memory) {
        if (_chainId == 1) {
            return (
                Config({
                    source: sPRL2V2(payable(0xa13BFA24b189271Ac00b148BE565D609AC847A4B)),
                    frontierPool: 0xbF596e932c2476165264b211eF8D6f4574a9a1A6,
                    dao: 0x25Fc7ffa8f9da3582a36633d04804F0004706F9b
                }),
                "mainnet"
            );
        }
        if (_chainId == 8453) {
            return (
                Config({
                    source: sPRL2V2(payable(0xB22f5eDbc62adCC093307025B8fdf75a0aa00e24)),
                    frontierPool: 0x4D81A370dDFc086274f7F73738dBf0CAfAa6ee4c,
                    dao: 0xC5201FFE258a95Af986E7cD1fcaD54f3f63f2C95
                }),
                "base"
            );
        }
        revert("AlignFrontierAndSunset: unsupported chain");
    }

    /// @notice Builds the batch, then checks it by running it from the DAO Safe on the fork (state reverted after).
    function build(
        Config memory _c,
        uint256 _slippageBps,
        uint256 _deadline
    )
        public
        returns (Transaction[] memory txs)
    {
        uint256 deviation = priceDeviation(_c);
        console2.log("Frontier vs Balancer PRL price gap before (1e18 = 100%):", deviation);

        txs = new Transaction[](5);
        uint256 n;
        Swap memory swap;
        if (deviation > TARGET_DEVIATION) {
            swap = _quoteSwap(_c, _slippageBps);
            (txs[0], txs[1], txs[2]) = _swapTxs(_c, swap, _deadline);
            n = 3;
        }
        /// @dev Skip the sunset calls already done, so the script can also realign the pool during the migration.
        if (_c.source.startPenaltyPercentage() != 0) {
            txs[n++] = Transaction(
                address(_c.source), abi.encodeCall(TimeLockPenaltyERC20.updateStartPenaltyPercentage, (0))
            );
        }
        if (!_c.source.paused()) {
            txs[n++] = Transaction(address(_c.source), abi.encodeCall(TimeLockPenaltyERC20.pause, ()));
        }
        assembly {
            mstore(txs, n)
        }

        _check(_c, txs, swap);
    }

    /// @notice Gap between the Frontier and Balancer PRL prices (1e18 = 100%).
    function priceDeviation(Config memory _c) public view returns (uint256) {
        uint256 ratio = _frontierPriceRatio(_c);
        return ratio > 1e18 ? ratio - 1e18 : 1e18 - ratio;
    }

    //-------------------------------------------
    // Internal
    //-------------------------------------------

    /// @dev Swap that brings the Frontier PRL price back to the Balancer one. A Frontier price above Balancer means
    /// PRL has to be sold into Frontier, and WETH otherwise.
    function _quoteSwap(Config memory _c, uint256 _slippageBps) internal returns (Swap memory swap) {
        IERC20 prl = _c.source.PRL();
        IERC20 weth = IERC20(address(_c.source.WETH()));
        bool sellPrl = _frontierPriceRatio(_c) > 1e18;
        (swap.tokenIn, swap.tokenOut) = sellPrl ? (prl, weth) : (weth, prl);
        uint256 amountOut;
        (swap.amountIn, amountOut) = _quoteAlignment(_c, swap.tokenIn, swap.tokenOut, sellPrl);
        swap.minAmountOut = amountOut * (10_000 - _slippageBps) / 10_000;

        console2.log(sellPrl ? "Sell PRL into Frontier:" : "Sell WETH into Frontier:", swap.amountIn);
        console2.log("Min amount out:", swap.minAmountOut);
        uint256 balance = swap.tokenIn.balanceOf(_c.dao);
        if (balance < swap.amountIn) {
            console2.log("WARNING: fund the DAO Safe before executing, it only holds:", balance);
        }
    }

    /// @dev Approve Permit2, approve the Frontier router on Permit2 until the deadline, swap.
    function _swapTxs(
        Config memory _c,
        Swap memory _swap,
        uint256 _deadline
    )
        internal
        pure
        returns (Transaction memory approve, Transaction memory allow, Transaction memory swap)
    {
        approve = Transaction(address(_swap.tokenIn), abi.encodeCall(IERC20.approve, (PERMIT2, _swap.amountIn)));
        allow = Transaction(
            PERMIT2,
            abi.encodeCall(
                IPermit2.approve,
                (
                    address(_swap.tokenIn),
                    FRONTIER_ROUTER,
                    SafeCast.toUint160(_swap.amountIn),
                    SafeCast.toUint48(_deadline)
                )
            )
        );
        swap = Transaction(
            FRONTIER_ROUTER,
            abi.encodeCall(
                IBalancerV3SwapRouter.swapSingleTokenExactIn,
                (
                    _c.frontierPool,
                    _swap.tokenIn,
                    _swap.tokenOut,
                    _swap.amountIn,
                    _swap.minAmountOut,
                    _deadline,
                    false,
                    ""
                )
            )
        );
    }

    /// @dev Bisect the amount whose swap brings the Frontier price back to the Balancer one, simulating each swap.
    function _quoteAlignment(
        Config memory _c,
        IERC20 _tokenIn,
        IERC20 _tokenOut,
        bool _sellPrl
    )
        internal
        returns (uint256 amountIn, uint256 amountOut)
    {
        (uint256 toPrl, uint256 toWeth) = _poolBalances(_c.frontierPool, _c.source.PRL());
        uint256 lo;
        uint256 hi = Math.mulDiv(_sellPrl ? toPrl : toWeth, MAX_IN_RATIO, 1e18);
        (uint256 ratio,) = _simulateSwap(_c, _tokenIn, _tokenOut, hi);
        require(_sellPrl ? ratio <= 1e18 : ratio >= 1e18, "AlignFrontierAndSunset: one swap cannot align the pool");
        while (hi - lo > hi / 100_000) {
            uint256 mid = (lo + hi) / 2;
            (ratio,) = _simulateSwap(_c, _tokenIn, _tokenOut, mid);
            if (_sellPrl ? ratio > 1e18 : ratio < 1e18) lo = mid;
            else hi = mid;
        }
        amountIn = hi;
        (, amountOut) = _simulateSwap(_c, _tokenIn, _tokenOut, amountIn);
    }

    function _simulateSwap(
        Config memory _c,
        IERC20 _tokenIn,
        IERC20 _tokenOut,
        uint256 _amountIn
    )
        internal
        returns (uint256 ratio, uint256 amountOut)
    {
        uint256 snapshot = vm.snapshotState();
        address trader = makeAddr("alignment simulation");
        deal(address(_tokenIn), trader, _amountIn);
        vm.startPrank(trader);
        _tokenIn.approve(PERMIT2, _amountIn);
        IPermit2(PERMIT2).approve(address(_tokenIn), FRONTIER_ROUTER, SafeCast.toUint160(_amountIn), type(uint48).max);
        amountOut = IBalancerV3SwapRouter(FRONTIER_ROUTER)
            .swapSingleTokenExactIn(_c.frontierPool, _tokenIn, _tokenOut, _amountIn, 0, block.timestamp, false, "");
        vm.stopPrank();
        ratio = _frontierPriceRatio(_c);
        vm.revertToState(snapshot);
    }

    /// @dev Run the batch from the DAO Safe, funding it in the simulation if needed, and check the result.
    function _check(Config memory _c, Transaction[] memory _txs, Swap memory _swap) internal {
        uint256 snapshot = vm.snapshotState();
        if (_swap.amountIn > 0 && _swap.tokenIn.balanceOf(_c.dao) < _swap.amountIn) {
            deal(address(_swap.tokenIn), _c.dao, _swap.amountIn);
        }
        for (uint256 i; i < _txs.length; ++i) {
            vm.prank(_c.dao);
            (bool success, bytes memory result) = _txs[i].to.call(_txs[i].data);
            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }
        }
        uint256 deviation = priceDeviation(_c);
        console2.log("Frontier vs Balancer PRL price gap after (1e18 = 100%):", deviation);
        require(deviation <= MAX_DEVIATION, "AlignFrontierAndSunset: price gap still too high");
        require(_c.source.paused(), "AlignFrontierAndSunset: sPRL2V2 not paused");
        require(_c.source.startPenaltyPercentage() == 0, "AlignFrontierAndSunset: penalty not cancelled");
        vm.revertToState(snapshot);
    }

    /// @dev Frontier PRL price relative to the Balancer one (1e18 = equal). Both pools are 80/20, so the balance
    /// ratios compare directly.
    function _frontierPriceRatio(Config memory _c) internal view returns (uint256) {
        IERC20 prl = _c.source.PRL();
        (uint256 fromPrl, uint256 fromWeth) = _poolBalances(address(_c.source.BPT()), prl);
        (uint256 toPrl, uint256 toWeth) = _poolBalances(_c.frontierPool, prl);
        return Math.mulDiv(toWeth * fromPrl, 1e18, fromWeth * toPrl);
    }

    function _poolBalances(address _pool, IERC20 _prl)
        internal
        view
        returns (uint256 prlBalance, uint256 wethBalance)
    {
        (IERC20[] memory tokens,, uint256[] memory balances,) =
            IBalancerV3Pool(_pool).getVault().getPoolTokenInfo(_pool);
        (prlBalance, wethBalance) = tokens[0] == _prl ? (balances[0], balances[1]) : (balances[1], balances[0]);
    }

    function _write(string memory _network, address _dao, Transaction[] memory _txs) internal {
        string memory transactions;
        for (uint256 i; i < _txs.length; ++i) {
            transactions = string.concat(
                transactions,
                i == 0 ? "" : ",",
                '{"to":"',
                vm.toString(_txs[i].to),
                '","value":"0","data":"',
                vm.toString(_txs[i].data),
                '","contractMethod":null,"contractInputsValues":null}'
            );
        }
        string memory json = string.concat(
            '{"version":"1.0","chainId":"',
            vm.toString(block.chainid),
            '","createdAt":',
            vm.toString(vm.unixTime()),
            ',"meta":{"name":"sPRL2V2 align Frontier and sunset (',
            _network,
            ')","description":"Aligns the Frontier PRL price with Balancer, then sets the sPRL2V2 penalty to 0 and ',
            "pauses it. Atomic: the swap minAmountOut reverts the whole batch if the Frontier price moved. Built at ",
            "block ",
            vm.toString(block.number),
            '.","txBuilderVersion":"1.18.0","createdFromSafeAddress":"',
            vm.toString(_dao),
            '","createdFromOwnerAddress":"","checksum":""},"transactions":[',
            transactions,
            "]}"
        );
        vm.createDir("batches", true);
        string memory path = string.concat("batches/sprl2v2-align-and-sunset.", _network, ".safe.json");
        vm.writeFile(path, json);
        console2.log("Safe batch written to", path);
    }
}
