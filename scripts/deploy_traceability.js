const { ethers } = require("hardhat");

async function main() {
  const UP_ADDRESS = process.env.UP_ADDRESS;
  if (!UP_ADDRESS) throw new Error("Missing UP_ADDRESS in .env");

  const Factory = await ethers.getContractFactory("Traceability_test2");
  const c = await Factory.deploy(UP_ADDRESS);

  await c.waitForDeployment();

  const addr = await c.getAddress();
  console.log("Traceability_test2 deployed to:", addr);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
