# Copilot Instructions

## Project Overview

**AthlCoin (ATHL)** — a Scaffold-ETH 2 (Foundry flavor) monorepo implementing a fixed-supply ERC-20 token with multi-beneficiary revocable vesting. Two packages:

- `packages/foundry` — Solidity contracts, deploy scripts, tests (Forge/Anvil)
- `packages/nextjs` — React frontend (Next.js App Router, RainbowKit, Wagmi, Viem, DaisyUI)

## Core Contracts

### `AthlCoin` (`contracts/AthlCoin.sol`)
Fixed-supply ERC-20 (ERC-2612 permit). 10B ATHL minted once to `recipient` at construction — no further minting or burning. Token distribution is handled via vesting wallets or direct transfer by the deployer.

### `AthlVestingWallet` (`contracts/AthlVestingWallet.sol`)
Multi-beneficiary, revocable linear vesting pool. One instance per allocation group. Key pattern:
- `revoker` funds the contract via token transfer, then calls `addBeneficiary(address, allocation)`
- Beneficiaries call `release()` (parameterless — unlike OZ VestingWallet) to claim
- `revoke(beneficiary)` preserves vested-to-date; returns unvested tokens to `revoker`
- Cliff is implemented by setting `start = deployTime + cliffPeriod`

### Token Allocation (from `script/DeployAthlCoin.s.sol`)
| Recipient | Amount | Schedule |
|---|---|---|
| Team vesting | 2B ATHL | 1-year cliff + 3-year linear |
| Investor vesting | 1.5B ATHL | 6-month cliff + 18-month linear |
| Deployer (treasury) | 6.5B ATHL | No lock |

> **Production TODOs in `DeployAthlCoin.s.sol`:** Replace `deployer` with a treasury multisig as `revoker`, and replace the placeholder `addBeneficiary(deployer, ...)` calls with real beneficiary addresses.

## Dev Workflow

```bash
yarn chain      # Start local Anvil node (chain ID 31337)
yarn deploy     # Compile + deploy + auto-generate deployedContracts.ts
yarn start      # Start Next.js at http://localhost:3000
```

Run each in a separate terminal. Always run `yarn deploy` after any Solidity change — it regenerates `packages/nextjs/contracts/deployedContracts.ts`. **Never edit `deployedContracts.ts` manually.**

## Adding a New Contract

1. Create `packages/foundry/contracts/MyContract.sol`
2. Create `packages/foundry/script/DeployMyContract.s.sol` — must inherit `ScaffoldETHDeploy` and use the `ScaffoldEthDeployerRunner` modifier on `run()` (handles broadcast, ABI export, and sets `deployer`):

```solidity
import "./DeployHelpers.s.sol";
contract DeployMyContract is ScaffoldETHDeploy {
    function run() external ScaffoldEthDeployerRunner {
        new MyContract(deployer);
    }
}
```

3. Register in `packages/foundry/script/Deploy.s.sol`
4. Deploy: `yarn deploy` or `yarn deploy --file DeployMyContract.s.sol`

> **Note:** When two instances of the same contract type are deployed (e.g. team + investor `AthlVestingWallet`), only the last one is exported under that name in `deployedContracts.ts`. To surface both on the frontend, register the first address in `packages/nextjs/contracts/externalContracts.ts` under a distinct key.

## Frontend Contract Interaction

`contractName` must exactly match the key in `deployedContracts.ts`:

```tsx
const { data: balance } = useScaffoldReadContract({
  contractName: "AthlCoin",
  functionName: "balanceOf",
  args: [connectedAddress],
});

const { writeContractAsync } = useScaffoldWriteContract("AthlCoin");
```

Available hooks: `useScaffoldReadContract`, `useScaffoldWriteContract`, `useScaffoldEventHistory`, `useScaffoldWatchContractEvent`, `useScaffoldContract`, `useDeployedContractInfo`, `useTransactor`.

See `packages/nextjs/app/erc20/page.tsx` as a reference implementation (note: still uses the `SE2Token` name — update to `AthlCoin` when building new pages).

## UI Components & Styling

```tsx
import { Address, AddressInput, Balance, EtherInput } from "@scaffold-ui/components";
```

Use **DaisyUI** classes (`btn btn-primary`, `card bg-base-100`). Use the `~~` alias for all intra-nextjs imports:

```tsx
import { useTargetNetwork } from "~~/hooks/scaffold-eth";
```

## Solidity Conventions

- OpenZeppelin remapping: `@openzeppelin/contracts/` → `lib/openzeppelin-contracts/contracts` (`remappings.txt`)
- Pragma: `>=0.8.20 <0.9.0` for contracts, `^0.8.19` for deploy scripts
- Deploy scripts: `PascalCase.s.sol`

## Testing (Forge)

Tests in `packages/foundry/test/*.t.sol`, inherit `forge-std/Test.sol`. Prefixes: `test_`, `test_RevertWhen_`, `testFuzz_`. Mirror contract constants in tests rather than importing them.

```bash
yarn foundry:test                        # run all tests
forge test --match-test test_X -vvv      # specific test with traces
```

Key cheatcodes: `vm.prank`, `vm.deal`, `vm.warp`, `vm.expectRevert`, `vm.expectEmit`.

## Network Configuration

- Default: `chains.foundry` (chain ID 31337) — `packages/nextjs/scaffold.config.ts`
- Live network: add RPC to `packages/foundry/foundry.toml` → `[rpc_endpoints]`, then `yarn deploy --network <name>`; add to `targetNetworks` in `scaffold.config.ts`

## Code Review

Use the **`grumpy-carlos-code-reviewer`** specialized agent for code reviews before finalizing changes.

## Key File Reference

| File | Purpose |
|---|---|
| `packages/foundry/contracts/AthlCoin.sol` | Fixed-supply ERC-20 (ATHL) with ERC-2612 permit |
| `packages/foundry/contracts/AthlVestingWallet.sol` | Multi-beneficiary revocable vesting pool |
| `packages/foundry/script/DeployAthlCoin.s.sol` | Full deployment: token + team/investor vesting wallets |
| `packages/foundry/script/Deploy.s.sol` | Entry point orchestrating all deployments |
| `packages/foundry/script/DeployHelpers.s.sol` | `ScaffoldETHDeploy` base + `ScaffoldEthDeployerRunner` modifier |
| `packages/nextjs/contracts/deployedContracts.ts` | Auto-generated ABIs — do not edit |
| `packages/nextjs/contracts/externalContracts.ts` | Manually registered contracts (use for second vesting wallet) |
| `packages/nextjs/scaffold.config.ts` | Target networks, API keys, polling interval |
| `packages/nextjs/app/erc20/page.tsx` | Reference read/write hook patterns |
