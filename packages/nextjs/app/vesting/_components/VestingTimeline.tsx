"use client";

import { Bar, BarChart, Cell, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";

/** Months from deployment date for each pool's cliff and vesting duration */
const DEPLOY_DATE = new Date("2026-05-12");

type PoolTimeline = {
  name: string;
  cliffMonths: number;
  vestingMonths: number;
  color: string;
};

const POOLS: PoolTimeline[] = [
  { name: "Team", cliffMonths: 12, vestingMonths: 36, color: "#3b82f6" },
  { name: "Advisors", cliffMonths: 6, vestingMonths: 18, color: "#10b981" },
  { name: "Ecosystem", cliffMonths: 0, vestingMonths: 0, color: "#6366f1" },
  { name: "Platform", cliffMonths: 0, vestingMonths: 0, color: "#8b5cf6" },
  { name: "Public Sale", cliffMonths: 0, vestingMonths: 0, color: "#06b6d4" },
  { name: "Marketing", cliffMonths: 0, vestingMonths: 0, color: "#f59e0b" },
  { name: "Private Sale", cliffMonths: 0, vestingMonths: 0, color: "#ef4444" },
  { name: "Seed", cliffMonths: 0, vestingMonths: 0, color: "#f97316" },
];

// For immediately-claimable pools show a tiny 0.5-month bar so they're visible
const chartData = POOLS.map(p => ({
  name: p.name,
  cliff: p.cliffMonths,
  vesting: p.vestingMonths > 0 ? p.vestingMonths : 0.5,
  hasVesting: p.vestingMonths > 0,
  color: p.color,
}));

const monthsToLabel = (months: number) => {
  if (months === 0) return "Now";
  if (months < 12) return `${months}mo`;
  const yrs = months / 12;
  return Number.isInteger(yrs) ? `${yrs}yr` : `${yrs}yr`;
};

const CustomTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null;
  const cliff = payload.find((p: any) => p.dataKey === "cliff")?.value ?? 0;
  const vesting = payload.find((p: any) => p.dataKey === "vesting")?.value ?? 0;
  const hasVesting = payload[0]?.payload?.hasVesting;
  return (
    <div className="bg-base-100 border border-base-300 rounded-lg px-3 py-2 text-sm shadow-lg">
      <p className="font-bold mb-1">{label}</p>
      {cliff > 0 && <p className="text-warning">Cliff: {cliff} months</p>}
      {hasVesting ? (
        <p className="text-info">Linear vesting: {vesting} months</p>
      ) : (
        <p className="text-success">Immediately claimable</p>
      )}
      {cliff > 0 && hasVesting && (
        <p className="text-base-content/60 text-xs mt-1">Total locked: {cliff + vesting} months</p>
      )}
    </div>
  );
};

export const VestingTimeline = () => (
  <div className="w-full">
    <h2 className="text-2xl font-bold mb-4">Vesting Timeline</h2>
    <div className="card bg-base-100 border border-base-300 p-4">
      <p className="text-sm text-base-content/60 mb-4">
        Months from deployment ({DEPLOY_DATE.toLocaleDateString("en-AU", { month: "short", year: "numeric" })})
      </p>
      <ResponsiveContainer width="100%" height={300}>
        <BarChart data={chartData} layout="vertical" margin={{ top: 0, right: 30, left: 10, bottom: 0 }}>
          <XAxis
            type="number"
            domain={[0, 50]}
            tickFormatter={monthsToLabel}
            tick={{ fontSize: 11 }}
            tickLine={false}
          />
          <YAxis type="category" dataKey="name" width={90} tick={{ fontSize: 12 }} tickLine={false} />
          <Tooltip content={<CustomTooltip />} />
          <Legend
            content={() => (
              <div className="flex gap-4 justify-center flex-wrap mt-2 text-xs">
                {[
                  { label: "Cliff (locked)", color: "#f59e0b" },
                  { label: "Linear vesting", color: "#3b82f6" },
                  { label: "Immediately claimable", color: "#10b981" },
                ].map(item => (
                  <span key={item.label} className="flex items-center gap-1">
                    <span className="inline-block w-3 h-3 rounded-sm" style={{ background: item.color }} />
                    {item.label}
                  </span>
                ))}
              </div>
            )}
          />
          {/* Cliff bar */}
          <Bar dataKey="cliff" stackId="a" name="Cliff">
            {chartData.map(entry => (
              <Cell key={entry.name} fill={entry.cliff > 0 ? "#f59e0b" : "transparent"} />
            ))}
          </Bar>
          {/* Vesting bar */}
          <Bar dataKey="vesting" stackId="a" name="Vesting" radius={[0, 4, 4, 0]}>
            {chartData.map(entry => (
              <Cell
                key={entry.name}
                fill={entry.hasVesting ? entry.color : "#10b981"}
                fillOpacity={entry.hasVesting ? 1 : 0.7}
              />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  </div>
);
