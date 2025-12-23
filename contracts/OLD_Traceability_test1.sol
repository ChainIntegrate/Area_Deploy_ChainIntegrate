/// @dev Prototype – not for production use


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { LSP8IdentifiableDigitalAsset } from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import { LSP8Burnable } from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Burnable.sol";

contract Traceability_test1 is LSP8IdentifiableDigitalAsset, LSP8Burnable {
    // -------------------------
    //  Conformity / Traceability
    // -------------------------

    enum CertStatus {
        Valid,      // 0
        Revoked,    // 1
        Superseded  // 2 (opzionale, ma utile)
    }

    struct ConformityCert {
        bytes32 certificateId;   // ID certificato (può essere hash o ID interno)
        bytes32 companyIdHash;   // hash companyId (es. PIVA|salt) oppure 0x0
        bytes32 batchIdHash;     // hash lotto/commessa (batch|salt)
        bytes32 standardHash;    // hash dello standard (es. keccak256("MOCA"))
        uint256 issuedAt;        // timestamp emissione
        uint256 validUntil;      // 0 se non scade
        bytes32 documentHash;    // hash del PDF/XML (keccak256(bytes))
        string  documentURI;     // ipfs://CID o https://... (solo per retrieval)
        CertStatus status;       // Valid/Revoked/Superseded
    }

    mapping(bytes32 => ConformityCert) private _certByTokenId;

    bool public metadataFrozen;      // blocca update LSP4 metadata
    bool public conformityFrozen;    // blocca update conformity data (audit mode)

    event ConformitySet(
        bytes32 indexed tokenId,
        bytes32 indexed certificateId,
        bytes32 documentHash,
        uint256 issuedAt
    );

    event ConformityStatusChanged(bytes32 indexed tokenId, CertStatus status);

    event ConformityFrozen();
    event MetadataFrozen();

    // -------------------------
    //  Access control
    // -------------------------
    modifier onlyAssetOwner() {
        require(msg.sender == owner(), "Not owner");
        _;
    }

    // -------------------------
    //  Constructor
    // -------------------------
    constructor(address newOwner_)
    LSP8IdentifiableDigitalAsset(
  "Traceability_test1",
  "TRC1",
  newOwner_,
  0,
  0
    )
{}


    // -------------------------
    //  Mint (certificato)
    // -------------------------
    function mintCert(bytes32 tokenId, address to, bytes calldata data) external onlyAssetOwner {
        // LSP8 usa tokenId come identifier
        _mint(to, tokenId, true, data);
    }

    // -------------------------
    //  Conformity data (on-chain)
    // -------------------------
    function setConformityData(bytes32 tokenId, ConformityCert calldata c) external onlyAssetOwner {
        require(!conformityFrozen, "Conformity frozen");

        // Sanity check minimi (evitano record “vuoti”)
        require(c.certificateId != bytes32(0), "Missing certificateId");
        require(c.documentHash != bytes32(0), "Missing documentHash");
        require(c.issuedAt != 0, "Missing issuedAt");

        // Imposta status automaticamente a Valid se non è valorizzato (difensivo)
        ConformityCert memory stored = c;
        if (uint8(stored.status) > uint8(CertStatus.Superseded)) {
            stored.status = CertStatus.Valid;
        }

        _certByTokenId[tokenId] = stored;

        emit ConformitySet(tokenId, stored.certificateId, stored.documentHash, stored.issuedAt);
        emit ConformityStatusChanged(tokenId, stored.status);
    }

    function getConformityData(bytes32 tokenId) external view returns (ConformityCert memory) {
        return _certByTokenId[tokenId];
    }

    function revoke(bytes32 tokenId) external onlyAssetOwner {
        require(!conformityFrozen, "Conformity frozen");
        ConformityCert storage c = _certByTokenId[tokenId];
        require(c.certificateId != bytes32(0), "No conformity data");

        c.status = CertStatus.Revoked;
        emit ConformityStatusChanged(tokenId, CertStatus.Revoked);
    }

    function supersede(bytes32 oldTokenId, bytes32 newTokenId) external onlyAssetOwner {
        require(!conformityFrozen, "Conformity frozen");

        ConformityCert storage oldC = _certByTokenId[oldTokenId];
        require(oldC.certificateId != bytes32(0), "Old missing");
        oldC.status = CertStatus.Superseded;
        emit ConformityStatusChanged(oldTokenId, CertStatus.Superseded);

        // Nota: il “collegamento” old->new lo puoi gestire anche con un mapping extra se ti serve.
        // Qui manteniamo minimale.
        ConformityCert storage newC = _certByTokenId[newTokenId];
        require(newC.certificateId != bytes32(0), "New missing");
    }

    function freezeConformity() external onlyAssetOwner {
        conformityFrozen = true;
        emit ConformityFrozen();
    }

    // -------------------------
    //  LSP4 Metadata (link/URI controllato)
    // -------------------------
    function setLSP4Metadata(bytes32 lsp4MetadataKey, bytes calldata lsp4MetadataValue)
        external
        onlyAssetOwner
    {
        require(!metadataFrozen, "Metadata frozen");
        _setData(lsp4MetadataKey, lsp4MetadataValue);
    }

    function freezeMetadata() external onlyAssetOwner {
        metadataFrozen = true;
        emit MetadataFrozen();
    }
}
