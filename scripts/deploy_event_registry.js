const hre = require("hardhat");
require("dotenv").config();

async function main() {
  const signers = await hre.ethers.getSigners();

  if (!signers.length) {
    throw new Error(
      "No deployer signer available. Check DEPLOYER_PRIVATE_KEY in .env"
    );
  }

  const deployer = signers[0];

  const passportAddress = process.env.PROOF_OF_FARMING_PASSPORT_ADDRESS;

  if (!passportAddress) {
    throw new Error(
      "Missing PROOF_OF_FARMING_PASSPORT_ADDRESS in .env"
    );
  }

  console.log("=== DEPLOY PROOF OF FARMING EVENT REGISTRY ===");
  console.log("Deploy signer:", deployer.address);
  console.log("Linked FarmPassport:", passportAddress);

  const Contract = await hre.ethers.getContractFactory(
    "ProofOfFarmingEventRegistry"
  );

  const contract = await Contract.deploy(passportAddress);

  await contract.waitForDeployment();

  const address = await contract.getAddress();

  console.log("====================================");
  console.log("ProofOfFarmingEventRegistry deployed to:", address);
  console.log("Linked FarmPassport:", passportAddress);
  console.log("====================================");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});