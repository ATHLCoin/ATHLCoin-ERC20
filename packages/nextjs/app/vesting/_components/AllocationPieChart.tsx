"use client";

import { VESTING_POOLS } from "../vestingPools";
import { Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";

const COLORS = [
  "#6366f1", // ecosystem   – indigo
  "#8b5cf6", // platform    – violet
  "#3b82f6", // team        – blue
  "#06b6d4", // public sale – cyan
  "#10b981", // advisors    – emerald
  "#f59e0b", // marketing   – amber
  "#ef4444", // private sale– red
  "#f97316", // seed        – orange
];

const data = VESTING_POOLS.map((pool, i) => ({
  name: pool.label,
  value: parseFloat(pool.allocationPercent),
  color: COLORS[i % COLORS.length],
}));

const renderCustomLabel = ({ cx, cy, midAngle, innerRadius, outerRadius, percent }: any) => {
  if (percent < 0.05) return null;
  const RADIAN = Math.PI / 180;
  const radius = innerRadius + (outerRadius - innerRadius) * 0.55;
  const x = cx + radius * Math.cos(-midAngle * RADIAN);
  const y = cy + radius * Math.sin(-midAngle * RADIAN);
  return (
    <text x={x} y={y} fill="white" textAnchor="middle" dominantBaseline="central" fontSize={12} fontWeight={600}>
      {`${(percent * 100).toFixed(1)}%`}
    </text>
  );
};

export const AllocationPieChart = () => (
  <div className="w-full">
    <h2 className="text-2xl font-bold mb-4">Token Allocation</h2>
    <div className="card bg-base-100 border border-base-300 p-4">
      <ResponsiveContainer width="100%" height={320}>
        <PieChart>
          <Pie
            data={data}
            cx="50%"
            cy="50%"
            outerRadius={120}
            dataKey="value"
            labelLine={false}
            label={renderCustomLabel}
          >
            {data.map(entry => (
              <Cell key={entry.name} fill={entry.color} />
            ))}
          </Pie>
          <Tooltip
            formatter={value => [`${value}%`, "Share"]}
            contentStyle={{ borderRadius: "8px", fontSize: "13px" }}
          />
          <Legend
            formatter={(value: string) => <span style={{ fontSize: 13 }}>{value}</span>}
            iconType="circle"
            iconSize={10}
          />
        </PieChart>
      </ResponsiveContainer>
    </div>
  </div>
);
