# 🪙 AthlCoin (ATHL)

AthlCoin is the project's primary ERC-20 token for the Athlete ecosystem. It is implemented using OpenZeppelin contracts on top of a [Scaffold-ETH 2](https://scaffoldeth.io) (Foundry) monorepo.

⚙️ Built using NextJS, RainbowKit, Foundry, Wagmi, Viem, and Typescript.

## Token properties

| Property | Value |
|---|---|
| Name | AthlCoin |
| Symbol | ATHL |
| Total supply | 10,000,000,000 ATHL (fixed — no minting or burning) |
| Decimals | 18 |
| Standard | ERC-20 + ERC-2612 (gasless permit) |

## Token distribution

| Recipient | Amount | Vesting schedule |
|---|---|---|
| Team | 2,000,000,000 ATHL (20%) | 1-year cliff, then linear over 3 years |
| Investors | 1,500,000,000 ATHL (15%) | 6-month cliff, then linear over 18 months |
| Treasury / Ecosystem | 6,500,000,000 ATHL (65%) | Held by deployer — no lock |

Vesting is managed by `AthlVestingWallet` — a custom multi-beneficiary, revocable vesting contract. Each group (Team, Investors) gets one pool contract. The treasury revoker can:

- Register multiple beneficiaries with individual allocations via `addBeneficiary(address, uint256)`
- Revoke a beneficiary's unvested tokens back to the treasury via `revoke(address)`

Beneficiaries claim their vested tokens independently by calling `release()` on their group's wallet.

## Key files

| File | Purpose |
|---|---|
| `packages/foundry/contracts/AthlCoin.sol` | ERC-20 token — fixed 10B supply |
| `packages/foundry/contracts/AthlVestingWallet.sol` | Multi-beneficiary, revocable vesting contract |
| `packages/foundry/script/DeployAthlCoin.s.sol` | Deploys token + two vesting wallets |
| `packages/foundry/test/AthlCoin.t.sol` | Token tests |
| `packages/foundry/test/AthlVestingWallet.t.sol` | Vesting contract tests |

## Deploy

```bash
yarn deploy                                   # deploy all contracts
yarn deploy --file DeployAthlCoin.s.sol    # deploy AthlCoin + vesting wallets only
```

> **Before deploying to a live network**, call `addBeneficiary(address, amount)` on each vesting wallet for every team member / investor. Allocations must sum to the group's pool amount. Update the `revoker` address to a treasury multisig in `DeployAthlCoin.s.sol`.

## Requirements

Before you begin, you need to install the following tools:

- [Node (>= v20.18.3)](https://nodejs.org/en/download/)
- Yarn ([v1](https://classic.yarnpkg.com/en/docs/install/) or [v2+](https://yarnpkg.com/getting-started/install))
- [Git](https://git-scm.com/downloads)

## Quickstart

1. Install dependencies if it was skipped in CLI:

```bash
cd athl-coin
yarn install
```

2. Run a local network in the first terminal:

```bash
yarn chain
```

3. On a second terminal, deploy the contracts:

```bash
yarn deploy
```

4. On a third terminal, start your NextJS app:

```bash
yarn start
```

Visit your app on: `http://localhost:3000`. You can interact with your smart contracts using the `Debug Contracts` page. You can tweak the app config in `packages/nextjs/scaffold.config.ts`.

## Testing

```bash
yarn foundry:test                                          # run all tests
forge test --match-path test/AthlVestingWallet.t.sol -v   # vesting tests only
forge test --match-path test/AthlCoin.t.sol -v         # token tests only
forge test -vvv                                            # show traces on failure
```