const hre = require("hardhat");
const { ethers } = hre;

// ---------------- CONFIG ----------------
const UP_ADMIN = "0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C";
const CONTRACT = "0xA0EB23c4e8c08f6d497FD8B80fF9CC9B91452E0A";
const ISSUER_TO_ALLOW = "0xAa18E265Bb38cD507eD018AF9abf0FeF16E685C9";
// ---------------------------------------

async function main() {
  const [signer] = await ethers.getSigners();
  const signerAddress = await signer.getAddress();

  console.log("Signer (EOA):", signerAddress);
  console.log("UP admin    :", UP_ADMIN);
  console.log("Contract    :", CONTRACT);
  console.log("Issuer allow:", ISSUER_TO_ALLOW);

  // ABI minima UP.execute
  const UP_EXEC_ABI = [
    "function execute(uint256 operation, address to, uint256 value, bytes data) payable returns (bytes)"
  ];

  // ABI minima del contratto per encode + verifica
  const CONTRACT_ABI = [
    "function setIssuerAllowed(address issuer, bool allowed)",
    "function isIssuerAllowed(address issuer) view returns (bool)"
  ];

  // Encode calldata per setIssuerAllowed(issuer, true)
  const contractIface = new ethers.Interface(CONTRACT_ABI);
  const calldata = contractIface.encodeFunctionData(
    "setIssuerAllowed",
    [ISSUER_TO_ALLOW, true]
  );

  // OPERATION: CALL = 0
  const OP_CALL = 0;

  // Istanza UP
  const up = new ethers.Contract(UP_ADMIN, UP_EXEC_ABI, signer);

  // Esegui come UP
  const tx = await up.execute(OP_CALL, CONTRACT, 0, calldata);
  console.log("UP.execute tx:", tx.hash);

  await tx.wait();
  console.log("Transaction confirmed");

  // Verifica on-chain
  const contract = new ethers.Contract(CONTRACT, CONTRACT_ABI, signer);
  const allowed = await contract.isIssuerAllowed(ISSUER_TO_ALLOW);

  console.log("isIssuerAllowed =", allowed);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
