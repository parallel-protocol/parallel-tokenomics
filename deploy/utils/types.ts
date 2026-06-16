import type { BigNumberish } from "ethers";

export type Address = `0x${string}`;

export type ConfigData = {
  isMainChainFeeDistributor: boolean;
  accessManager: Address;
  wallets: {
    dao: Address;
  };
  tokens: {
    prl: Address;
    par: Address;
    weth: Address;
  };
  rewardMerkleDistributor: {
    token: string;
    expiredRewardsRecipient: string;
  };
  feeDistributor: {
    feeToken: string;
    mainChain: string;
    destinationReceiver: Address;
    bridgeableToken: Address;
  };
  sprl1: {
    underlying: Address;
    feeReceiver: string;
    startPenaltyPercentage: BigNumberish;
    timeLockDuration: number;
  };
  sprl2: {
    permit2: Address;
    feeReceiver: string;
    startPenaltyPercentage: BigNumberish;
    timeLockDuration: number;
    balancerV3Router: Address;
    auraRewardsPool: Address;
    auraBoosterLite: Address;
    auraBPT: Address;
    balancerBPT: Address;
    rewardsTokens: Address[];
  };
  sprl2v2: {
    permit2: Address;
    feeReceiver: string;
    startPenaltyPercentage: BigNumberish;
    timeLockDuration: number;
    balancerV3Router: Address;
    balancerBPT: Address;
  };
};
