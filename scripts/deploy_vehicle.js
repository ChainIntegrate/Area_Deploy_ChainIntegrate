const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const chainIntegrateUP = "0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C";

  console.log("Deploy signer:", deployer.address);
  console.log("Contract owner (UP):", chainIntegrateUP);

  const Contract = await hre.ethers.getContractFactory("VehiclePassportRegistry");
  const contract = await Contract.deploy(chainIntegrateUP);

  await contract.waitForDeployment();

  console.log("VehiclePassportRegistry deployed to:", await contract.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});