// scripts/deploySupplierQualityLSP8.js
const hre = require("hardhat");

async function main() {
  const { ethers, network } = hre;

  // === Parametri token (puoi anche passarli via env) ===
  const TOKEN_NAME = process.env.TOKEN_NAME || "Supplier Quality";
  const TOKEN_SYMBOL = process.env.TOKEN_SYMBOL || "SQ";

  // === Indirizzi (fissi come da tua indicazione) ===
  const CHAININTEGRATE_OWNER = "0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C";
  const QUALITY_OFFICE = "0xAa18E265Bb38cD507eD018AF9abf0FeF16E685C9";

  if (!ethers.isAddress(CHAININTEGRATE_OWNER)) throw new Error("Owner address non valido");
  if (!ethers.isAddress(QUALITY_OFFICE)) throw new Error("QualityOffice address non valido");

  const [deployer] = await ethers.getSigners();

  console.log("======================================");
  console.log("Network:", network.name, "| chainId:", network.config.chainId);
  console.log("Deployer:", deployer.address);
  console.log("Token:", `${TOKEN_NAME} (${TOKEN_SYMBOL})`);
  console.log("Owner:", CHAININTEGRATE_OWNER);
  console.log("QualityOffice:", QUALITY_OFFICE);
  console.log("======================================");

  // Deploy
  const Factory = await ethers.getContractFactory("SupplierQualityLSP8");
  const contract = await Factory.deploy(
    TOKEN_NAME,
    TOKEN_SYMBOL,
    CHAININTEGRATE_OWNER,
    QUALITY_OFFICE
  );

  // ethers v6
  await contract.waitForDeployment();
  const addr = await contract.getAddress();

  console.log("✅ Deployed SupplierQualityLSP8 at:", addr);

  // Post-check: leggo owner e qualityOffice dal contratto
  const onChainOwner = await contract.owner();
  const onChainQO = await contract.qualityOffice();

  console.log("owner()         =", onChainOwner);
  console.log("qualityOffice() =", onChainQO);

  // Piccolo sanity check
  if (onChainOwner.toLowerCase() !== CHAININTEGRATE_OWNER.toLowerCase()) {
    console.warn("⚠️ owner on-chain diverso da quello atteso!");
  }
  if (onChainQO.toLowerCase() !== QUALITY_OFFICE.toLowerCase()) {
    console.warn("⚠️ qualityOffice on-chain diverso da quello atteso!");
  }

  console.log("Done.");
}

main().catch((err) => {
  console.error("❌ Deploy failed:", err);
  process.exitCode = 1;
});


main().catch((error) => {
  console.error("❌ Deploy failed:", error);
  process.exitCode = 1;
});
