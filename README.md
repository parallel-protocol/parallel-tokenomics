# Parallel Tokenomics

## Summary

The Parallel Tokenomics system consists of smart contracts that enable:

- Forwarding fees to the main fee distributor on the destination chain (SideChainFeeDistributor)
- Distributing protocol-generated fees to registered fee receivers (MainFeeDistributor)
- Staking PRL tokens to earn rewards through:
  - Single staking (sPRL1): Direct PRL staking with time-lock and rewards
  - Balancer Pool staking (sPRL2): 80PRL/20WETH pool tokens staked into Aura.finance
- Distributing rewards to sPRL1/sPRL2 users via off-chain calculations and merkle proofs (RewardMerkleDistributor)

### Key Features

- Time-lock staking mechanism with configurable early withdrawal penalties
- Dual staking options with different risk-reward profiles
- Cross-chain fee collection and distribution
- Merkle-based reward distribution system
- Integration with Balancer and Aura.finance protocols

### Requirements

- PRL tokens for staking (sPRL2 requires Balancer V3 and Aura.finance)
- ETH/WETH for sPRL2 liquidity provision
- Expected supported networks:
  - sPRL(s) tokens: Mainnet (as BalancerV3 and Aura.finance are required)
  - RewardMerkleDistributor: Mainnet
  - MainFeeDistributor: Mainnet
  - SideChainFeeDistributor: Polygon, Fantom

## Architecture

![High Level Architecture](./docs/assets/high-level-architecture.png)

## Documentation Links

Additional documentation can be found in the `/docs` directory:

- [Audit Details](docs/AuditDetails.md)
- [Deployments Contracts](docs/Deployment.md)
- [Technical Specifications](docs/TechnicalSpecs.md)

## Security

### Foundry

Foundry is used for testing and scripting. To
[Install foundry follow the instructions.](https://book.getfoundry.sh/getting-started/installation)

### Install js dependencies

```bash
bun i
```

### Setup `.env` file

```bash
MNEMONIC="YOUR_MNEMONIC"
PRIVATE_KEY="PRIVATE_KEY"
ALCHEMY_API_KEY="ALCHEMY_API_KEY"
MAINNET_ETHERSCAN_API_KEY="MAINNET_ETHERSCAN_API_KEY"
POLYGON_ETHERSCAN_API_KEY="POLYGON_ETHERSCAN_API_KEY"
```

### Compile contracts

```bash
bun run compile
```

### Run tests

```bash
bun run test
```

You will find other useful commands in the [package.json](./package.json) file.

## Contributing

If you're interested in contributing, please see our [contributions guidelines](./CONTRIBUTING.md).

## Questions & Feedback

For any question or feedback you can use [discord](https://discord.com/invite/mimodao). Don't hesitate to reach out on
[Twitter](https://twitter.com/mimo_labs)🐦 as well.

## Licensing

The primary license for this repository is the MIT license. See [`LICENSE`](./LICENSE). Minus the following exceptions:

- tests files are under UNLICENSED license
- mocks contracts are under UNLICENSED license

Each of these files states their license type.
