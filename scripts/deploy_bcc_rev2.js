const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  // =====================================
  // CONFIG
  // =====================================
  const UP_OWNER = "0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C";

  const NAME = "Battery Carbon Certificate";
  const SYMBOL = "BCC";

  // =====================================
  // SIGNER
  // =====================================
  const [signer] = await ethers.getSigners();
  const signerAddress = await signer.getAddress();
  console.log("Deploy signer (EOA):", signerAddress);

  // =====================================
  // DEPLOY
  // =====================================
  // ⬇️ nome giusto del contratto compilato
  const Factory = await ethers.getContractFactory(
    "BatteryCarbonCertificateLSP8_Rev2",
    signer
  );

  const contract = await Factory.deploy(NAME, SYMBOL, UP_OWNER);
  await contract.waitForDeployment();

  const contractAddress = await contract.getAddress();

  console.log("--------------------------------------------------");
  console.log("BatteryCarbonCertificateLSP8_Rev2 deployed");
  console.log("Contract address :", contractAddress);
  console.log("Contract owner   :", UP_OWNER);
  console.log("--------------------------------------------------");

  // =====================================
  // OPTIONAL sanity checks
  // =====================================
  // owner() in LSP8 di solito esiste (Ownable)
  try {
    const owner = await contract.owner();
    console.log("owner() on-chain :", owner);
  } catch (e) {
    console.log("owner() check skipped:", e?.message || e);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});