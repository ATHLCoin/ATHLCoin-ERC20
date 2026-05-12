/**
 * Vesting pool metadata and contract addresses.
 *
 * Addresses are populated from the latest local Anvil deployment.
 * After running `yarn deploy`, update any addresses that changed.
 * The `AthlVestingWallet` entry in deployedContracts.ts always reflects
 * the first wallet (Team) — all others are listed here for reference.
 */

export type VestingPool = {
  key: string;
  label: string;
  address: `0x${string}`;
  allocationLabel: string;
  allocationPercent: string;
  scheduleLabel: string;
  description: string;
};

export const VESTING_POOLS: VestingPool[] = [
  {
    key: "team",
    label: "Team",
    address: "0xa15bb66138824a1c7167f5e85b957d04dd34e468",
    allocationLabel: "1,600,000,000 ATHL",
    allocationPercent: "16%",
    scheduleLabel: "1-year cliff · 3-year linear",
    description: "Team allocation. No tokens claimable before 1 year; then linear release over 3 years.",
  },
  {
    key: "advisors",
    label: "Advisors",
    address: "0xe1aa25618fa0c7a1cfdab5d6b456af611873b629",
    allocationLabel: "600,000,000 ATHL",
    allocationPercent: "6%",
    scheduleLabel: "6-month cliff · 18-month linear",
    description: "Advisor allocation. No tokens claimable before 6 months; then linear release over 18 months.",
  },
  {
    key: "platform",
    label: "Platform",
    address: "0xed1db453c3156ff3155a97ad217b3087d5dc5f6e",
    allocationLabel: "1,950,000,000 ATHL",
    allocationPercent: "19.5%",
    scheduleLabel: "Immediately claimable",
    description: "Platform development allocation. Fully claimable from deployment.",
  },
  {
    key: "marketing",
    label: "Marketing",
    address: "0x12975173b87f7595ee45dffb2ab812ece596bf84",
    allocationLabel: "500,000,000 ATHL",
    allocationPercent: "5%",
    scheduleLabel: "Immediately claimable",
    description: "Marketing allocation. Fully claimable from deployment.",
  },
  {
    key: "seed",
    label: "Seed",
    address: "0x196dbcbb54b8ec4958c959d8949ebfe87ac2aaaf",
    allocationLabel: "400,000,000 ATHL",
    allocationPercent: "4%",
    scheduleLabel: "Immediately claimable",
    description: "Seed round allocation. Fully claimable from deployment.",
  },
  {
    key: "privateSale",
    label: "Private Sale",
    address: "0x05b4cb126885fb10464fdd12666feb25e2563b76",
    allocationLabel: "500,000,000 ATHL",
    allocationPercent: "5%",
    scheduleLabel: "Immediately claimable",
    description: "Private sale allocation. Fully claimable from deployment.",
  },
  {
    key: "publicSale",
    label: "Public Sale",
    address: "0xd04ff4a75edd737a73e92b2f2274cb887d96e110",
    allocationLabel: "800,000,000 ATHL",
    allocationPercent: "8%",
    scheduleLabel: "Immediately claimable",
    description: "Public sale allocation. Fully claimable from deployment.",
  },
  {
    key: "ecosystem",
    label: "Ecosystem",
    address: "0x29a79095352a718b3d7fe84e1f14e9f34a35598e",
    allocationLabel: "3,650,000,000 ATHL",
    allocationPercent: "36.5%",
    scheduleLabel: "Immediately claimable",
    description: "Ecosystem & community allocation. Fully claimable from deployment.",
  },
];

/**
 * Minimal ABI for AthlVestingWallet — only the functions used on the vesting page.
 */
export const VESTING_WALLET_ABI = [
  {
    type: "function",
    name: "beneficiaryInfo",
    inputs: [{ name: "beneficiary", type: "address" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "allocation", type: "uint256" },
          { name: "released", type: "uint256" },
          { name: "vestedAtRevoke", type: "uint256" },
          { name: "revoked", type: "bool" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "releasable",
    inputs: [{ name: "beneficiary", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "release",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "revoke",
    inputs: [{ name: "beneficiary", type: "address" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "revoker",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "start",
    inputs: [],
    outputs: [{ name: "", type: "uint64" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "duration",
    inputs: [],
    outputs: [{ name: "", type: "uint64" }],
    stateMutability: "view",
  },
] as const;
