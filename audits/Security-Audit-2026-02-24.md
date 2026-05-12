# Security Audit Report — AthlCoin / AthlVestingWallet

---

### 🔴 HIGH

#### H-1 · `addBeneficiary` zero-allocation bypass (AthlVestingWallet.sol)

The `AlreadyAdded` guard checks `allocation != 0`, but does not validate that the new `allocation` argument itself is nonzero. This creates two problems:

1. `addBeneficiary(alice, 0)` succeeds silently, writing a zero-allocation record with no useful effect and emitting a `BeneficiaryAdded` event with `allocation = 0`.
2. Because the guard key is `allocation != 0`, a subsequent call `addBeneficiary(alice, realAmount)` also passes — bypassing the "already added" protection entirely.

**Fix:** add a zero-allocation guard in `addBeneficiary`:

```solidity
function addBeneficiary(address beneficiary, uint256 allocation) external {
    if (msg.sender != revoker) revert NotRevoker();
    if (beneficiary == address(0)) revert ZeroAddress();
+   if (allocation == 0) revert ZeroAllocation();   // new error
    if (_beneficiaries[beneficiary].allocation != 0) revert AlreadyAdded(beneficiary);
    ...
}
```

Add a corresponding test: `test_RevertWhen_AddBeneficiary_ZeroAllocation`.

---

#### H-2 · Hardcoded Alchemy API key (`scripts-js/checkAccountBalance.js:11`)

```js
const ALCHEMY_API_KEY =
  process.env.ALCHEMY_API_KEY || "oKxs-03sij-U_N0iOlrSsZFr29-IqbuF";
```

A real API key is committed in source and will appear in git history forever. The key could be rate-limited, abused by third parties who clone the repo, or revoked without notice, breaking the script for all contributors.

**Fix:** Remove the hardcoded fallback, throw an explicit error when the env var is missing, and rotate the exposed key immediately.

```js
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
if (!ALCHEMY_API_KEY) throw new Error("ALCHEMY_API_KEY env var not set");
```

---

### 🟡 MEDIUM

#### M-1 · Zero `duration` creates instant full-vesting (AthlVestingWallet.sol)

The constructor accepts `_duration = 0` without reverting. With duration zero, `vestedAmount` returns `total` for any `timestamp >= start` — all tokens are immediately claimable the moment vesting starts. There is no cliff or linear release.

**Fix:**

```solidity
constructor(..., uint64 _duration) {
    if (_token == address(0) || _revoker == address(0)) revert ZeroAddress();
+   if (_duration == 0) revert ZeroDuration();
    ...
}
```

---

#### M-2 · Private key briefly exposed in process arguments (generateKeystore.js, selectOrCreateKeystore.js)

Both files extract the private key from `cast wallet new` stdout, hold it as a plaintext string, then pass it as a CLI argument to a new `spawn` call:

```js
spawn("cast", ["wallet", "import", keystoreName, "--private-key", privateKey], ...)
```

During the lifespan of that spawn, the private key is visible in process listings (`ps aux`) to any other process on the machine. This is a local development context, but developer machines are still high-value targets.

**Fix:** pipe the key via stdin using `cast wallet import --interactive`, or use a `PRIVATE_KEY` environment variable rather than a CLI argument.

---

#### M-3 · EOA deployer holds revoker role and 6.5 B ATHL treasury (deploy script)

Both vesting wallets use the deployer EOA as `revoker`, and 6.5 B ATHL (65% of total supply) sits in the deployer's address with no lock. A single private key compromise gives an attacker:
- Ability to `revoke` all beneficiaries and drain unvested tokens back to the revoker.
- Immediate access to 6.5 B ATHL.

The DeployAthlCoin.s.sol file documents this as a TODO, but it is worth treating as a blocking pre-mainnet item. **Replace the deployer EOA with a Gnosis Safe multisig** for the revoker role. Consider a timelocked treasury contract for the 6.5 B.

---

#### M-4 · VerifyAll.s.sol constructor-args extraction will fail for contracts with immutables

```solidity
bytes memory constructorArgs = BytesLib.slice(
    deployedBytecode, compiledBytecode.length, ...
);
```

`AthlVestingWallet` has four `immutable` state variables. The Solidity compiler inserts zero-byte placeholders for immutables in the compiled bytecode; the EVM replaces them with actual values at deployment time. The on-chain `transaction.input` therefore differs from the artifact's compiled bytecode beyond just the constructor arguments — the immutables are baked in. This means `compiledBytecode.length` is the wrong offset, causing `BytesLib.slice` to extract garbage constructor args (and likely revert or submit incorrect verification data).

**Fix:** use `forge verify-contract --guess-constructor-args` or provide constructor args explicitly per contract rather than trying to reverse-engineer them from bytecode.

---

### 🔵 LOW

#### L-1 · Pragma version inconsistency across files

| File | Pragma |
|---|---|
| AthlCoin.sol / AthlVestingWallet.sol | `>=0.8.20 <0.9.0` |
| DeployAthlCoin.s.sol | `^0.8.20` |
| Deploy.s.sol / DeployHelpers.s.sol / VerifyAll.s.sol | `^0.8.19` |

Scripts compiled with `^0.8.19` could theoretically use a different patch version than the contracts. Pin all files to the same version (e.g. `0.8.28`) to guarantee identical compiler behaviour.

---

#### L-2 · `EIGHTEEN_MONTHS` and `SIX_MONTHS` constants are slightly imprecise

```solidity
uint64 constant SIX_MONTHS     = 182 days;   // ≈ 182.6 days
uint64 constant EIGHTEEN_MONTHS = 547 days;  // ≈ 547.9 days
```

Using 182/547 days makes the periods ~14–21 hours shorter than a calendar half-year/18-months. For a token with billions of dollars of potential value, consider whether investors or the team will dispute the early unlock. A cleaner approximation: `SIX_MONTHS = 183 days`, `EIGHTEEN_MONTHS = 548 days`, or express them as `365 days / 2` and `3 * (365 days / 2)`.

---

#### L-3 · `deployments` array in `ScaffoldETHDeploy` is dead code

The `Deployment[] public deployments` array in DeployHelpers.s.sol is never written to by any deploy script. `exportDeployments()` iterates over it but the loop body is never reached (`len == 0`). The result is that the written JSON only contains `networkName`. The frontend relies on the broadcast files parsed by generateTsAbis.js instead — the array serves no purpose.

**Fix:** either remove the dead array and the JSON-writing loop, or actually populate it in the deploy scripts.

---

#### L-4 · generateTsAbis.js uses `prettier.format()` without `await` (Prettier v3 compatibility)

```js
writeFileSync(
  `${NEXTJS_TARGET_DIR}deployedContracts.ts`,
  format(fileTemplate(...), { parser: "typescript" })  // format() returns a Promise in v3
);
```

Prettier v3 made `format` async. Without `await`, `writeFileSync` receives a `Promise` object and writes `[object Promise]` to `deployedContracts.ts`, silently breaking the frontend type system. Check the installed Prettier version and add `await` (making `main` async). 

---

### ℹ️ INFORMATIONAL

#### I-1 · No beneficiary address migration path

If a beneficiary loses access to their private key, their allocation is permanently locked. Consider adding a `changeBeneficiary(address old, address new)` function gated to the `revoker`, which would allow the treasury to redirect tokens to a recovery address.

---

#### I-2 · No total-allocation accounting in vesting wallet

The contract doesn't track the sum of all `allocation` values versus its actual token balance. If the revoker mistakenly over-allocates (total allocations > funded balance), the first beneficiaries to call `release()` succeed; later ones receive an ERC-20 insufficient balance revert. Consider adding a `totalAllocated` counter that is checked against `token.balanceOf(address(this))` in `addBeneficiary`.

---

#### I-3 · `execSync` in checkAccountBalance.js uses unsanitized keystore name

```js
const addressCommand = `cast wallet address --account ${selectedKeystore}`;
execSync(addressCommand)
```

The keystore name comes from `readdirSync(~/.foundry/keystores)`. A filename with shell metacharacters (`;`, `$()`, backticks) in that directory would constitute command injection. Very low risk in practice (local dev tool, attacker needs filesystem access), but use `spawnSync` with an args array instead of `execSync` with a templated string.

---

#### I-4 · CEI pattern and reentrancy — ✅ correctly implemented

`release()` updates `_beneficiaries[beneficiary].released` before calling `safeTransfer`. `revoke()` updates `info.revoked` and `info.vestedAtRevoke` before transferring unvested tokens. No reentrancy exposure.

---

#### I-5 · `AthlCoin` constructor does not guard against `address(0)` recipient

OZ's `_mint` will revert on `address(0)`, so this is not exploitable, but an explicit `require(recipient != address(0))` at the top of the constructor makes the failure mode clearer and the NatSpec honest.

---

### Summary Table

| Status | ID | Severity | File | Title |
|---|---|---|---|---|
|✅| H-1 | 🔴 | AthlVestingWallet.sol | Zero-allocation bypasses `AlreadyAdded` guard |
|✅| H-2 | 🔴 | checkAccountBalance.js | Hardcoded Alchemy API key in source |
|✅| M-1 | 🟡 | AthlVestingWallet.sol | `duration = 0` gives immediate full vesting |
|✅| M-2 | 🟡 | generateKeystore.js, selectOrCreateKeystore.js | Private key exposed in process args |
|⏳| M-3 | 🟡 | DeployAthlCoin.s.sol | EOA deployer controls revoker role & treasury |
|✅| M-4 | 🟡 | VerifyAll.s.sol | Immutable bytecode breaks constructor arg extraction |
|✅| L-1 | 🔵 | All scripts | Pragma version inconsistency |
|✅| L-2 | 🔵 | DeployAthlCoin.s.sol | `SIX_MONTHS`/`EIGHTEEN_MONTHS` imprecise |
|🛑| L-3 | 🔵 | DeployHelpers.s.sol | `deployments` array never populated (dead code) |
|✅| L-4 | 🔵 | generateTsAbis.js | `format()` missing `await` breaks Prettier v3 |
|✅| I-1 | ℹ️ | AthlVestingWallet.sol | No beneficiary address migration |
|✅| I-2 | ℹ️ | AthlVestingWallet.sol | No total-allocation accounting |
|✅| I-3 | ℹ️ | checkAccountBalance.js | `execSync` with unsanitized keystore name |
|✅| I-4 | ℹ️ | AthlVestingWallet.sol | CEI pattern correctly followed ✅ |
|✅| I-5 | ℹ️ | AthlCoin.sol | No explicit `address(0)` guard for `recipient` |
