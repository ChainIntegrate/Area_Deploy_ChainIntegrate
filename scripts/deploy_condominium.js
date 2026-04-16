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

  const chainIntegrateUP =
    process.env.CHAIN_INTEGRATE_UP ||
    "0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C";

  const requiredProfileInterfaceId = "0x629aa694"; // ERC725Y (Universal Profile)

  const collectionName = "Condominium Registry";
  const collectionSymbol = "CONDOREG";

  console.log("Deploy signer:", deployer.address);
  console.log("Contract owner (UP):", chainIntegrateUP);
  console.log(
    "Required profile interfaceId:",
    requiredProfileInterfaceId
  );

  const Contract = await hre.ethers.getContractFactory(
    "CondominiumRegistryLSP8"
  );

  const contract = await Contract.deploy(
    collectionName,
    collectionSymbol,
    chainIntegrateUP,
    requiredProfileInterfaceId
  );

  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log("CondominiumRegistryLSP8 deployed to:", address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});