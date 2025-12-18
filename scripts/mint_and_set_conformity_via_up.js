const { ethers } = require("hardhat");
const fs = require("fs");

// UP (LSP0 / ERC725Account) ABI minimale
const UP_ABI = [
  "function owner() view returns (address)",
  "function execute(uint256 operationType, address to, uint256 value, bytes data) public payable returns (bytes)"
];

// KeyManager (LSP6) ABI minimale
const KEYMANAGER_ABI = [
  "function execute(bytes payload) public payable returns (bytes)"
];

const OP_CALL = 0;

function keccakFile(filepath) {
  const bytes = fs.readFileSync(filepath);
  return ethers.keccak256(bytes);
}

async function kmExecute(controller, up, payload) {
  const keyManagerAddress = await up.owner(); // owner dell’UP = KeyManager
  const km = new ethers.Contract(keyManagerAddress, KEYMANAGER_ABI, controller);

  const tx = await km.execute(payload);
  await tx.wait();
  return tx.hash;
}

async function main() {
  const [controller] = await ethers.getSigners();

  const UP_ADDRESS = process.env.UP_ADDRESS;
  const ASSET_ADDRESS = process.env.ASSET_ADDRESS;

  if (!UP_ADDRESS) throw new Error("Missing UP_ADDRESS in .env");
  if (!ASSET_ADDRESS) throw new Error("Missing ASSET_ADDRESS in .env");

  const up = new ethers.Contract(UP_ADDRESS, UP_ABI, controller);
  const asset = await ethers.getContractAt("Traceability_test1", ASSET_ADDRESS);

  // 1) tokenId bytes32 (esempio: hash di un ID leggibile)
  const humanId = "CERT-2025-0001";
  const tokenId = ethers.keccak256(ethers.toUtf8Bytes(humanId));

  // 2) destinatario (qui: UP)
  const to = UP_ADDRESS;

  // 3) hash documento (assicurati che esista davvero questo file)
  const docPath = "metadata/conformita_demo.pdf";
  const documentHash = keccakFile(docPath);

  // 4) campi hashati
  const companyIdHash = ethers.keccak256(ethers.toUtf8Bytes("PIVA01234567890|saltXYZ"));
  const batchIdHash   = ethers.keccak256(ethers.toUtf8Bytes("LOT-2025-00018|saltABC"));
  const standardHash  = ethers.keccak256(ethers.toUtf8Bytes("MOCA"));
  const now = Math.floor(Date.now() / 1000);

  // URI del documento (placeholder ok per ora)
  const documentURI = "ipfs://CID_PLACEHOLDER";

  // ---- MINT ----
  const mintCallData = asset.interface.encodeFunctionData("mintCert", [tokenId, to, "0x"]);

  // payload = chiamata a UP.execute(OP_CALL, ASSET, 0, mintCallData)
  const upExecuteMintPayload = up.interface.encodeFunctionData("execute", [
    OP_CALL,
    ASSET_ADDRESS,
    0,
    mintCallData
  ]);

  console.log("Mint tokenId:", tokenId);
  const mintTxHash = await kmExecute(controller, up, upExecuteMintPayload);
  console.log("Mint OK:", mintTxHash);

  // ---- setConformityData ----
  const conformity = {
    certificateId: ethers.keccak256(ethers.toUtf8Bytes(humanId)),
    companyIdHash,
    batchIdHash,
    standardHash,
    issuedAt: now,
    validUntil: 0,
    documentHash,
    documentURI,
    status: 0
  };

  const setCallData = asset.interface.encodeFunctionData("setConformityData", [tokenId, conformity]);

  const upExecuteSetPayload = up.interface.encodeFunctionData("execute", [
    OP_CALL,
    ASSET_ADDRESS,
    0,
    setCallData
  ]);

  const setTxHash = await kmExecute(controller, up, upExecuteSetPayload);
  console.log("Conformity set OK:", setTxHash);

  // opzionale: freeze
  // const freezeCallData = asset.interface.encodeFunctionData("freezeConformity", []);
  // const upExecuteFreezePayload = up.interface.encodeFunctionData("execute", [OP_CALL, ASSET_ADDRESS, 0, freezeCallData]);
  // const freezeTxHash = await kmExecute(controller, up, upExecuteFreezePayload);
  // console.log("Conformity frozen:", freezeTxHash);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
