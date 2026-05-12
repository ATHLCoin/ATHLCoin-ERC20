import { listKeystores } from "./listKeystores.js";
import { spawnSync } from "child_process";
import dotenv from "dotenv";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { toString } from "qrcode";
import { readFileSync } from "fs";
import { parse } from "toml";
import { ethers } from "ethers";

// Load environment variables
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
dotenv.config({ path: join(__dirname, "..", ".env") });

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
if (!ALCHEMY_API_KEY)
  throw new Error(
    "ALCHEMY_API_KEY environment variable is not set. Please add it to packages/foundry/.env file."
  );

async function getBalanceForEachNetwork(address) {
  try {
    // Read the foundry.toml file
    const foundryTomlPath = join(__dirname, "..", "foundry.toml");
    const tomlString = readFileSync(foundryTomlPath, "utf-8");

    // Parse the tomlString to get the JS object representation
    const parsedToml = parse(tomlString);

    // Extract rpc_endpoints from parsedToml
    const rpcEndpoints = parsedToml.rpc_endpoints;

    // Replace placeholders in the rpc_endpoints section
    function replaceENVAlchemyKey(input) {
      return input.replace("${ALCHEMY_API_KEY}", ALCHEMY_API_KEY);
    }

    console.log(await toString(address, { type: "terminal", small: true }));
    console.log(`\n📊 Address: ${address}`);

    for (const networkName in rpcEndpoints) {
      const networkUrl = replaceENVAlchemyKey(rpcEndpoints[networkName]);
      console.log(`\n--${networkName}-- 📡`);

      try {
        const provider = new ethers.providers.JsonRpcProvider(networkUrl);

        // Get balance and format it
        const balance = await provider.getBalance(address);
        const formattedBalance = +ethers.utils.formatUnits(balance);

        console.log("   Balance:", formattedBalance);
        console.log("   Nonce:", await provider.getTransactionCount(address));
      } catch (e) {
        console.log(
          `   ❌ Can't connect to network ${networkName}: ${e.message}`
        );
      }
    }
  } catch (error) {
    console.error("Error reading foundry.toml:", error);
  }
}

async function checkAccountBalance() {
  try {
    // Step 1: List accounts and let user select one
    console.log("📋 Listing available accounts...");
    const selectedKeystore = await listKeystores(
      "Select a keystore to display its balance (enter the number, e.g., 1): "
    );

    if (!selectedKeystore) {
      console.error("❌ No keystore selected");
      process.exit(1);
    }

    // Step 2: Get the address of the selected account
    console.log(`\n🔍 Getting address for keystore: ${selectedKeystore}`);

    let address;
    try {
      const result = spawnSync(
        "cast",
        ["wallet", "address", "--account", selectedKeystore],
        { encoding: "utf8" }
      );

      if (result.error) throw result.error;

      if (result.status !== 0)
        throw new Error(result.stderr || "cast wallet address failed");

      address = result.stdout.trim();
      console.log("\n💰 Checking balances across networks...");
      console.log("\n");
      await getBalanceForEachNetwork(address);
    } catch (error) {
      console.error(`❌ Error getting address: ${error.message}`);
      process.exit(1);
    }
  } catch (error) {
    console.error(`\n❌ Error: ${error.message}`);
    process.exit(1);
  }
}

// Run the function if this script is called directly
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  checkAccountBalance().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

export { checkAccountBalance };
