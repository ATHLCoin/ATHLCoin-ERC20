"use client";

import { useState } from "react";
import { AddressInput, BaseInput as InputBase } from "@scaffold-ui/components";
import type { NextPage } from "next";
import { formatEther, parseEther } from "viem";
import { useAccount } from "wagmi";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

const ERC20: NextPage = () => {
  const { address: connectedAddress } = useAccount();

  const [toAddress, setToAddress] = useState<string>("");
  const [amount, setAmount] = useState<string>("");

  const { data: balance } = useScaffoldReadContract({
    contractName: "AthlCoin",
    functionName: "balanceOf",
    args: [connectedAddress],
  });

  const { data: totalSupply } = useScaffoldReadContract({
    contractName: "AthlCoin",
    functionName: "totalSupply",
  });

  const { writeContractAsync: writeAthlCoinAsync } = useScaffoldWriteContract("AthlCoin");

  return (
    <>
      <div className="flex items-center flex-col flex-grow pt-10">
        <div className="px-5 text-center max-w-4xl">
          <h1 className="text-4xl font-bold">ATHL Token</h1>
          <div>
            <p>
              AthlCoin (ATHL) is a fixed-supply ERC-20 token. 10 billion ATHL were minted once at deployment — there is
              no additional minting or burning.
            </p>
            <p>
              The token follows the{" "}
              <a
                target="_blank"
                href="https://eips.ethereum.org/EIPS/eip-20"
                className="underline font-bold text-nowrap"
              >
                EIP-20
              </a>{" "}
              standard and also supports{" "}
              <a
                target="_blank"
                href="https://eips.ethereum.org/EIPS/eip-2612"
                className="underline font-bold text-nowrap"
              >
                EIP-2612 permit
              </a>
              , enabling gasless approvals.
            </p>
            <p>
              The contract is implemented using the{" "}
              <a
                target="_blank"
                href="https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol"
                className="underline font-bold text-nowrap"
              >
                OpenZeppelin ERC-20
              </a>{" "}
              library.
            </p>
          </div>

          <div className="divider my-0" />

          <h2 className="text-3xl font-bold mt-4">Interact with the token</h2>

          <div>
            <p>Below you can see the total token supply and your token balance.</p>
            <p>
              You can transfer tokens to another address by filling in the recipient address and amount, then clicking{" "}
              <strong>Send</strong>.
            </p>
          </div>
        </div>

        <div className="flex flex-col justify-center items-center bg-base-300 w-full mt-8 px-8 pt-6 pb-12">
          <div className="flex justify-center items-center space-x-2 flex-col sm:flex-row">
            <p className="my-2 mr-2 font-bold text-2xl">Total Supply:</p>
            <p className="text-xl">{totalSupply ? formatEther(totalSupply) : 0} tokens</p>
          </div>
          <div className="flex justify-center items-center space-x-2 flex-col sm:flex-row">
            <p className="y-2 mr-2 font-bold text-2xl">Your Balance:</p>
            <p className="text-xl">{balance ? formatEther(balance) : 0} tokens</p>
          </div>

          <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center w-full md:w-2/4 rounded-3xl mt-10">
            <h3 className="text-2xl font-bold">Transfer Tokens</h3>
            <div className="flex flex-col items-center justify-between w-full lg:w-3/5 px-2 mt-4">
              <div className="font-bold mb-2">Send To:</div>
              <div>
                <AddressInput value={toAddress} onChange={setToAddress} placeholder="Address" />
              </div>
            </div>
            <div className="flex flex-col items-center justify-between w-full lg:w-3/5 p-2 mt-4">
              <div className="flex gap-2 mb-2">
                <div className="font-bold">Amount:</div>
                <div>
                  <button
                    disabled={!balance}
                    className="btn btn-secondary text-xs h-6 min-h-6"
                    onClick={() => {
                      if (balance) {
                        setAmount(formatEther(balance));
                      }
                    }}
                  >
                    Max
                  </button>
                </div>
              </div>
              <div>
                <InputBase value={amount} onChange={setAmount} placeholder="0" />
              </div>
            </div>
            <div>
              <button
                className="btn btn-primary text-lg px-12 mt-2"
                disabled={!toAddress || !amount}
                onClick={async () => {
                  try {
                    await writeAthlCoinAsync({ functionName: "transfer", args: [toAddress, parseEther(amount)] });
                    setToAddress("");
                    setAmount("");
                  } catch (e) {
                    console.error("Error while transfering token", e);
                  }
                }}
              >
                Send
              </button>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default ERC20;
