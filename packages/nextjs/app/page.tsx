"use client";

import Link from "next/link";
import { Address } from "@scaffold-ui/components";
import type { NextPage } from "next";
import { hardhat } from "viem/chains";
import { useAccount } from "wagmi";
import { BanknotesIcon, BugAntIcon, LockClosedIcon, MagnifyingGlassIcon } from "@heroicons/react/24/outline";
import { useTargetNetwork } from "~~/hooks/scaffold-eth";

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const { targetNetwork } = useTargetNetwork();

  return (
    <>
      <div className="flex items-center flex-col grow pt-10">
        <div className="px-5 text-center">
          <h1 className="text-center">
            <span className="block text-2xl mb-2">Welcome to</span>
            <span className="block text-4xl font-bold">AthlCoin (ATHL)</span>
          </h1>
          <p className="text-lg mt-2 max-w-xl mx-auto">
            A fixed-supply ERC-20 token with multi-beneficiary revocable vesting. 10 billion ATHL minted once — no
            further minting or burning.
          </p>
          <div className="flex justify-center items-center space-x-2 flex-col mt-4">
            <p className="my-2 font-medium">Connected Address:</p>
            <Address
              address={connectedAddress}
              chain={targetNetwork}
              blockExplorerAddressLink={
                targetNetwork.id === hardhat.id ? `/blockexplorer/address/${connectedAddress}` : undefined
              }
            />
          </div>
        </div>

        <div className="grow bg-base-300 w-full mt-16 px-8 py-12">
          <div className="flex justify-center items-center gap-12 flex-col md:flex-row flex-wrap">
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <BanknotesIcon className="h-8 w-8 fill-secondary" />
              <p className="mt-2 font-semibold text-lg">ATHL Token</p>
              <p className="text-sm">
                View your balance and transfer ATHL tokens on the{" "}
                <Link href="/erc20" passHref className="link">
                  ERC-20
                </Link>{" "}
                page.
              </p>
            </div>
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <LockClosedIcon className="h-8 w-8 fill-secondary" />
              <p className="mt-2 font-semibold text-lg">Vesting</p>
              <p className="text-sm">
                Claim vested tokens or manage beneficiaries on the{" "}
                <Link href="/vesting" passHref className="link">
                  Vesting
                </Link>{" "}
                page.
              </p>
            </div>
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <BugAntIcon className="h-8 w-8 fill-secondary" />
              <p className="mt-2 font-semibold text-lg">Debug Contracts</p>
              <p className="text-sm">
                Inspect and call contract functions directly on the{" "}
                <Link href="/debug" passHref className="link">
                  Debug
                </Link>{" "}
                page.
              </p>
            </div>
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <MagnifyingGlassIcon className="h-8 w-8 fill-secondary" />
              <p className="mt-2 font-semibold text-lg">Block Explorer</p>
              <p className="text-sm">
                Browse local transactions on the{" "}
                <Link href="/blockexplorer" passHref className="link">
                  Block Explorer
                </Link>{" "}
                page.
              </p>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default Home;
