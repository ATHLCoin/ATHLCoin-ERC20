"use client";

import { useState } from "react";
import { VESTING_WALLET_ABI, VestingPool } from "../vestingPools";
import { AddressInput } from "@scaffold-ui/components";
import { formatEther, parseEther } from "viem";
import { useReadContract, useWaitForTransactionReceipt, useWriteContract } from "wagmi";

type Props = {
  pool: VestingPool;
  connectedAddress: `0x${string}` | undefined;
  isRevoker: boolean;
};

export const VestingPoolCard = ({ pool, connectedAddress, isRevoker }: Props) => {
  const [revokeTarget, setRevokeTarget] = useState<string>("");
  const [addBeneficiaryAddress, setAddBeneficiaryAddress] = useState<string>("");
  const [addBeneficiaryAmount, setAddBeneficiaryAmount] = useState<string>("");
  const [showRevokerPanel, setShowRevokerPanel] = useState(false);

  // ── Read: beneficiary info for connected user ────────────────────────────
  const { data: info, refetch: refetchInfo } = useReadContract({
    address: pool.address,
    abi: VESTING_WALLET_ABI,
    functionName: "beneficiaryInfo",
    args: connectedAddress ? [connectedAddress] : undefined,
    query: { enabled: !!connectedAddress },
  });

  const { data: releasableAmount, refetch: refetchReleasable } = useReadContract({
    address: pool.address,
    abi: VESTING_WALLET_ABI,
    functionName: "releasable",
    args: connectedAddress ? [connectedAddress] : undefined,
    query: { enabled: !!connectedAddress },
  });

  const { data: startTs } = useReadContract({
    address: pool.address,
    abi: VESTING_WALLET_ABI,
    functionName: "start",
  });

  const { data: durationSecs } = useReadContract({
    address: pool.address,
    abi: VESTING_WALLET_ABI,
    functionName: "duration",
  });

  // ── Write: release ────────────────────────────────────────────────────────
  const { writeContract: writeRelease, data: releaseTxHash, isPending: isReleasing } = useWriteContract();
  const { isLoading: isConfirmingRelease, isSuccess: isReleaseSuccess } = useWaitForTransactionReceipt({
    hash: releaseTxHash,
    query: { enabled: !!releaseTxHash },
  });

  // Refetch after a successful release
  if (isReleaseSuccess) {
    refetchInfo();
    refetchReleasable();
  }

  // ── Write: revoke ─────────────────────────────────────────────────────────
  const { writeContract: writeRevoke, data: revokeTxHash, isPending: isRevoking } = useWriteContract();
  const { isLoading: isConfirmingRevoke } = useWaitForTransactionReceipt({
    hash: revokeTxHash,
    query: { enabled: !!revokeTxHash },
  });

  // ── Derived values ────────────────────────────────────────────────────────
  const isBeneficiary = info && info.allocation > 0n;
  const isRevoked = info?.revoked ?? false;
  const allocation = info?.allocation ?? 0n;
  const released = info?.released ?? 0n;
  const claimable = releasableAmount ?? 0n;
  const vestingStartDate = startTs ? new Date(Number(startTs) * 1000).toLocaleDateString() : "—";
  const vestingEndDate =
    startTs && durationSecs && durationSecs > 0n
      ? new Date((Number(startTs) + Number(durationSecs)) * 1000).toLocaleDateString()
      : "—";

  const handleRelease = () => {
    writeRelease({ address: pool.address, abi: VESTING_WALLET_ABI, functionName: "release" });
  };

  const handleRevoke = () => {
    if (!revokeTarget) return;
    writeRevoke({
      address: pool.address,
      abi: VESTING_WALLET_ABI,
      functionName: "revoke",
      args: [revokeTarget as `0x${string}`],
    });
    setRevokeTarget("");
  };

  return (
    <div className="card bg-base-100 shadow-md w-full">
      <div className="card-body p-6">
        {/* ── Header ────────────────────────────────────────── */}
        <div className="flex justify-between items-start flex-wrap gap-2">
          <div>
            <h3 className="card-title text-xl">{pool.label}</h3>
            <p className="text-sm text-base-content/60">{pool.description}</p>
          </div>
          <div className="text-right">
            <div className="badge badge-outline badge-lg font-semibold">{pool.allocationPercent}</div>
            <div className="text-sm font-mono mt-1 text-base-content/70">{pool.allocationLabel}</div>
          </div>
        </div>

        {/* ── Schedule ─────────────────────────────────────── */}
        <div className="flex flex-wrap gap-4 mt-2 text-sm">
          <div>
            <span className="font-semibold">Schedule: </span>
            <span className="text-base-content/70">{pool.scheduleLabel}</span>
          </div>
          {startTs !== undefined && durationSecs !== undefined && durationSecs > 0n && (
            <>
              <div>
                <span className="font-semibold">Vesting starts: </span>
                <span className="text-base-content/70">{vestingStartDate}</span>
              </div>
              <div>
                <span className="font-semibold">Vesting ends: </span>
                <span className="text-base-content/70">{vestingEndDate}</span>
              </div>
            </>
          )}
        </div>

        {/* ── Contract address ─────────────────────────────── */}
        <div className="text-xs text-base-content/40 font-mono break-all mt-1">{pool.address}</div>

        <div className="divider my-2" />

        {/* ── Beneficiary position ─────────────────────────── */}
        {!connectedAddress ? (
          <p className="text-sm text-base-content/50 italic">Connect your wallet to see your position.</p>
        ) : !isBeneficiary ? (
          <p className="text-sm text-base-content/50 italic">You are not a beneficiary of this pool.</p>
        ) : (
          <div className="space-y-3">
            {isRevoked && (
              <div className="alert alert-warning py-2 text-sm">
                <span>⚠️ Your allocation has been revoked. You can still claim your vested-to-date tokens.</span>
              </div>
            )}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div className="stat bg-base-200 rounded-xl p-3">
                <div className="stat-title text-xs">Allocation</div>
                <div className="stat-value text-base font-mono">
                  {parseFloat(formatEther(allocation)).toLocaleString()}
                </div>
                <div className="stat-desc">ATHL</div>
              </div>
              <div className="stat bg-base-200 rounded-xl p-3">
                <div className="stat-title text-xs">Released</div>
                <div className="stat-value text-base font-mono">
                  {parseFloat(formatEther(released)).toLocaleString()}
                </div>
                <div className="stat-desc">ATHL</div>
              </div>
              <div className="stat bg-base-200 rounded-xl p-3">
                <div className="stat-title text-xs">Remaining</div>
                <div className="stat-value text-base font-mono">
                  {parseFloat(formatEther(allocation - released)).toLocaleString()}
                </div>
                <div className="stat-desc">ATHL</div>
              </div>
              <div className="stat bg-base-200 rounded-xl p-3">
                <div className="stat-title text-xs">Claimable Now</div>
                <div className="stat-value text-base font-mono text-success">
                  {parseFloat(formatEther(claimable)).toLocaleString()}
                </div>
                <div className="stat-desc">ATHL</div>
              </div>
            </div>

            <button
              className="btn btn-primary btn-sm"
              disabled={claimable === 0n || isReleasing || isConfirmingRelease}
              onClick={handleRelease}
            >
              {isReleasing || isConfirmingRelease ? <span className="loading loading-spinner loading-xs" /> : null}
              {isConfirmingRelease ? "Confirming…" : isReleasing ? "Claiming…" : "Claim Tokens"}
            </button>
          </div>
        )}

        {/* ── Revoker panel ─────────────────────────────────── */}
        {isRevoker && (
          <div className="mt-2">
            <button className="btn btn-xs btn-ghost text-warning" onClick={() => setShowRevokerPanel(v => !v)}>
              {showRevokerPanel ? "▲ Hide" : "▼ Show"} Revoker Controls
            </button>

            {showRevokerPanel && (
              <div className="mt-3 p-4 rounded-xl border border-warning/30 bg-warning/5 space-y-4">
                <p className="text-xs text-warning font-semibold uppercase tracking-wide">Revoker Controls</p>

                {/* Revoke beneficiary */}
                <div className="space-y-2">
                  <p className="text-sm font-semibold">Revoke a beneficiary</p>
                  <AddressInput value={revokeTarget} onChange={setRevokeTarget} placeholder="Beneficiary address" />
                  <button
                    className="btn btn-warning btn-sm"
                    disabled={!revokeTarget || isRevoking || isConfirmingRevoke}
                    onClick={handleRevoke}
                  >
                    {isRevoking || isConfirmingRevoke ? <span className="loading loading-spinner loading-xs" /> : null}
                    {isConfirmingRevoke ? "Confirming…" : isRevoking ? "Revoking…" : "Revoke"}
                  </button>
                </div>

                {/* Add beneficiary */}
                <div className="space-y-2">
                  <p className="text-sm font-semibold">Add a beneficiary</p>
                  <AddressInput
                    value={addBeneficiaryAddress}
                    onChange={setAddBeneficiaryAddress}
                    placeholder="Beneficiary address"
                  />
                  <input
                    type="number"
                    className="input input-bordered input-sm w-full"
                    placeholder="Amount (ATHL)"
                    value={addBeneficiaryAmount}
                    onChange={e => setAddBeneficiaryAmount(e.target.value)}
                  />
                  <AddBeneficiaryButton
                    poolAddress={pool.address}
                    beneficiary={addBeneficiaryAddress}
                    amount={addBeneficiaryAmount}
                    onSuccess={() => {
                      setAddBeneficiaryAddress("");
                      setAddBeneficiaryAmount("");
                    }}
                  />
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

// ── Sub-component for addBeneficiary (needs its own write hook) ───────────────

const ADD_BENEFICIARY_ABI = [
  {
    type: "function",
    name: "addBeneficiary",
    inputs: [
      { name: "beneficiary", type: "address" },
      { name: "allocation", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
] as const;

function AddBeneficiaryButton({
  poolAddress,
  beneficiary,
  amount,
  onSuccess,
}: {
  poolAddress: `0x${string}`;
  beneficiary: string;
  amount: string;
  onSuccess: () => void;
}) {
  const { writeContract, data: txHash, isPending } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
    query: { enabled: !!txHash },
  });

  if (isSuccess) onSuccess();

  const handleAdd = () => {
    if (!beneficiary || !amount) return;
    writeContract({
      address: poolAddress,
      abi: ADD_BENEFICIARY_ABI,
      functionName: "addBeneficiary",
      args: [beneficiary as `0x${string}`, parseEther(amount)],
    });
  };

  return (
    <button
      className="btn btn-success btn-sm"
      disabled={!beneficiary || !amount || isPending || isConfirming}
      onClick={handleAdd}
    >
      {isPending || isConfirming ? <span className="loading loading-spinner loading-xs" /> : null}
      {isConfirming ? "Confirming…" : isPending ? "Adding…" : "Add Beneficiary"}
    </button>
  );
}
