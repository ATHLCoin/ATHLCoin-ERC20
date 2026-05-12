"use client";

import { VestingPoolCard } from "./_components/VestingPoolCard";
import { VESTING_POOLS, VESTING_WALLET_ABI } from "./vestingPools";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { useReadContract } from "wagmi";

const VestingPage: NextPage = () => {
  const { address: connectedAddress } = useAccount();

  // Check if connected user is the revoker — use the first pool (all pools share the same revoker)
  const { data: revokerAddress } = useReadContract({
    address: VESTING_POOLS[0].address,
    abi: VESTING_WALLET_ABI,
    functionName: "revoker",
    query: { enabled: !!connectedAddress },
  });

  const isRevoker =
    !!connectedAddress && !!revokerAddress && connectedAddress.toLowerCase() === revokerAddress.toLowerCase();

  return (
    <div className="flex flex-col items-center grow pt-10 pb-16 px-4 md:px-8">
      {/* ── Header ────────────────────────────────────────────────────────── */}
      <div className="text-center max-w-2xl">
        <h1 className="text-4xl font-bold">Token Vesting</h1>
        <p className="mt-3 text-base text-base-content/70">
          ATHL tokens are distributed across allocation groups via revocable linear vesting wallets. Each pool has its
          own schedule — beneficiaries call <strong>Claim Tokens</strong> to withdraw their vested amount at any time.
        </p>
        {isRevoker && (
          <div className="alert alert-info mt-4 text-sm">
            <span>
              🔑 You are the <strong>revoker</strong> for all pools. Expand the revoker controls on any card to add
              beneficiaries or revoke unvested allocations.
            </span>
          </div>
        )}
      </div>

      {/* ── Allocation summary ────────────────────────────────────────────── */}
      <div className="w-full max-w-5xl mt-10">
        <h2 className="text-2xl font-bold mb-4">Allocation Summary</h2>
        <div className="overflow-x-auto rounded-xl border border-base-300">
          <table className="table table-zebra w-full text-sm">
            <thead>
              <tr>
                <th>Pool</th>
                <th>Allocation</th>
                <th className="hidden sm:table-cell">Share</th>
                <th className="hidden md:table-cell">Schedule</th>
              </tr>
            </thead>
            <tbody>
              {VESTING_POOLS.map(pool => (
                <tr key={pool.key}>
                  <td className="font-semibold">{pool.label}</td>
                  <td className="font-mono">{pool.allocationLabel}</td>
                  <td className="hidden sm:table-cell">
                    <div className="badge badge-outline badge-sm">{pool.allocationPercent}</div>
                  </td>
                  <td className="hidden md:table-cell text-base-content/60">{pool.scheduleLabel}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* ── Pool cards ────────────────────────────────────────────────────── */}
      <div className="w-full max-w-5xl mt-10 space-y-4">
        <h2 className="text-2xl font-bold">Vesting Pools</h2>
        {VESTING_POOLS.map(pool => (
          <VestingPoolCard
            key={pool.key}
            pool={pool}
            connectedAddress={connectedAddress as `0x${string}` | undefined}
            isRevoker={isRevoker}
          />
        ))}
      </div>
    </div>
  );
};

export default VestingPage;
