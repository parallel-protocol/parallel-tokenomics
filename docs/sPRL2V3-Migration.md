# sPRL2V2 to sPRL2V3 migration runbook

Balancer has been sunset, so sPRL2V2 holders move to sPRL2V3, the same vault on a FrontierFi 80PRL/20WETH pool. There is
no migration contract: each holder exits sPRL2V2 and deposits into sPRL2V3 through the frontend. Mainnet and Base only.

## 1. Deploy sPRL2V3

```sh
npx hardhat deploy --network <mainnet|base> --tags sPRL2V3
```

Check that `deployments/<network>/sPRL2V3.json` matches the target of `sprl2v3-roles.<network>.safe.json` (addresses
predicted from the deployer nonce), then sign that batch from the DAO Safe.

## 2. Build the align and sunset batch

The Frontier pools must trade at the Balancer price before holders move, otherwise arbitrageurs take the gap from them
once they have joined. The DAO Safe does it in one atomic batch:

1. approve Permit2, approve the Frontier router on Permit2, swap into the Frontier pool to align its PRL price with
   Balancer;
2. `updateStartPenaltyPercentage(0)` on sPRL2V2: every withdrawal request, pending or new, can be withdrawn at once
   without fee (the timelock itself cannot go below 1 day, but it only acts through the penalty);
3. `pause()` on sPRL2V2: blocks new deposits, withdrawals keep working.

```sh
forge script scripts/AlignFrontierAndSunset.s.sol --rpc-url <mainnet|base>
```

The script finds the swap amount by simulation, runs the whole batch from the DAO Safe on a fork, checks that the price
gap ends under 2%, that sPRL2V2 is paused and that the penalty is 0, and writes
`batches/sprl2v2-align-and-sunset.<network>.safe.json`. Optional env: `SLIPPAGE_BPS` (default 100) and `VALIDITY` in
seconds (default 3 days).

Read the logs before signing:

- the price gap before and after (1e18 = 100%);
- the amount sold and the token;
- any `WARNING: fund the DAO Safe`: the Safe needs that token before executing. The Base Safe holds no PRL today.

## 3. Sign and execute

Load the file in the Safe Transaction Builder and execute it soon after building it. If the Frontier price moves by more
than the slippage first, the swap reverts with `SwapLimit` and the whole batch with it, sunset included. Build a new
batch then.

## 4. Open the migration in the frontend

For each holder:

1. `sPRL2V2.requestWithdraw(amount)`;
2. `sPRL2V2.withdrawPRLAndWeth(ids, minPrl, minWeth, 0)`, right after;
3. approve PRL and WETH, then `sPRL2V3.depositPRLAndWeth(maxPrl, maxWeth, exactBpt, deadline, 0, 0x0, 0x0)`. Leftovers
   are refunded.

The price protection lives in the frontend:

- before step 3, compare the Frontier PRL price with the Balancer one (both pools are 80/20, so `fromWeth * toPrl`
  against `toWeth * fromPrl` compares them directly) and block above 2%;
- quote `exactBpt = min(prl * supply / toPrl, weth * supply / toWeth)` minus the slippage and pass the withdrawn amounts
  as `maxPrl` and `maxWeth`: the vault reverts with `AmountInAboveMax` if the price moved past the slippage;
- prefer a private RPC on mainnet for the deposit.

## 5. During the migration

If the Frontier price drifts more than 2% from Balancer, run the script again. Once the sunset is done it leaves out the
penalty and pause calls and builds an alignment swap only.

Between steps 2 and 3, holders have PRL and WETH in their wallet: some may not restake.
