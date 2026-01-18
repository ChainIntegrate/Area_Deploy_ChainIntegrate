const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  // =====================================
  // CONFIG
  // =====================================

  // Universal Profile admin (OWNER del contratto)
  const UP_OWNER = "0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C";

  // Metadata collezione
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

  const Factory = await ethers.getContractFactory(
    "BatteryCarbonCertificateLSP8",
    signer
  );

  const contract = await Factory.deploy(
    NAME,
    SYMBOL,
    UP_OWNER
  );

  await contract.waitForDeployment();

  const contractAddress = await contract.getAddress();

  console.log("--------------------------------------------------");
  console.log("BatteryCarbonCertificateLSP8 deployed");
  console.log("Contract address :", contractAddress);
  console.log("Contract owner   :", UP_OWNER);
  console.log("--------------------------------------------------");

  // =====================================
  // SANITY CHECK
  // =====================================

  try {
    const owner = await contract.owner();
    console.log("owner() on-chain :", owner);
  } catch {
    console.log("owner() check skipped (method not exposed)");
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
