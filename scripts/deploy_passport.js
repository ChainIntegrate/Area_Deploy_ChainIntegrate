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

  const contractOwner =
    process.env.CHAIN_INTEGRATE_UP ||
    "0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C";

  console.log("=== DEPLOY PROOF OF FARMING PASSPORT ===");
  console.log("Deploy signer:", deployer.address);
  console.log("Contract owner:", contractOwner);

  const Contract = await hre.ethers.getContractFactory(
    "ProofOfFarmingPassport"
  );

  const contract = await Contract.deploy(contractOwner);

  await contract.waitForDeployment();

  const address = await contract.getAddress();

  console.log("====================================");
  console.log("ProofOfFarmingPassport deployed to:", address);
  console.log("====================================");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});