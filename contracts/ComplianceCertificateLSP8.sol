// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {
    LSP8IdentifiableDigitalAsset
} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";

import {
    LSP8Burnable
} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Burnable.sol";

/**
 * @title ComplianceCertificateLSP8
 * @notice LSP8 certificates for verification/compliance use-cases.
 *
 * Data policy:
 * - "Hashato" = bytes32 already computed off-chain using keccak256(pepper || normalized_field)
 * - On-chain cleartext = inspectionDate, outcome, validUntil, issuedAt (mint timestamp)
 * - documentHash anchors the authenticity of the PDF/JSON you have in hand.
 */
contract ComplianceCertificateLSP8 is LSP8IdentifiableDigitalAsset, LSP8Burnable {
    // -------------------------
    //  Status / Outcome
    // -------------------------

    enum CertStatus {
        Valid,      // 0
        Revoked,    // 1
        Superseded  // 2
    }

    enum Outcome {
        Unknown,     // 0
        Positive,    // 1
        Negative,    // 2
        Conditional  // 3 (es. positivo con prescrizioni)
    }

    // -------------------------
    //  Certificate data model
    // -------------------------
    struct CertificateData {
        // --- Hash fields (pepper-based, computed off-chain) ---
        bytes32 companyNameHash;          // Nome Azienda
        bytes32 vatHash;                  // Partita IVA
        bytes32 fiscalCodeHash;           // Codice Fiscale
        bytes32 certificateNumberHash;    // Nr certificato
        bytes32 certificateTypeHash;      // Tipologia certificato
        bytes32 assetTypeHash;            // Tipologia bene certificato
        bytes32 modelHash;                // Modello
        bytes32 serialNumberHash;         // Matricola
        bytes32 manufacturingYearHash;    // Anno di costruzione
        bytes32 standardHash;             // Normativa di riferimento
        bytes32 reportReferenceHash;      // Riferimento verbale verifica
        bytes32 technicianHash;           // Responsabile Tecnico

        // --- Cleartext fields ---
        uint256 inspectionDate;           // Data esecuzione verifica (timestamp)
        Outcome outcome;                  // Esito verifica
        uint256 validUntil;               // Data scadenza (timestamp)
        uint256 issuedAt;                 // Timestamp emissione (block.timestamp at mint)

        // --- Document anchoring (recommended) ---
        bytes32 documentHash;             // Hash del PDF/JSON (keccak256 o sha256 -> bytes32)
        string documentURI;               // Opzionale (ipfs://..., https://...)
        CertStatus status;                // Stato certificato
    }

    mapping(bytes32 => CertificateData) private _certByTokenId;

    // Mint tracking (to avoid relying on tokenOwnerOf revert behaviour)
    mapping(bytes32 => bool) private _minted;

    // supersede graph
    mapping(bytes32 => bytes32) private _supersededBy; // old => new
    mapping(bytes32 => bytes32) private _supersedes;   // new => old

    bool public metadataFrozen;
    bool public conformityFrozen;

    // -------------------------
    //  Events
    // -------------------------

    event CertificateMinted(bytes32 indexed tokenId, address indexed to, uint256 issuedAt);

    event CertificateDataSet(
        bytes32 indexed tokenId,
        bytes32 indexed certificateNumberHash,
        bytes32 documentHash,
        uint256 inspectionDate,
        Outcome outcome,
        uint256 validUntil
    );

    event CertificateStatusChanged(bytes32 indexed tokenId, CertStatus status);

    event CertificateSuperseded(bytes32 indexed oldTokenId, bytes32 indexed newTokenId);

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
            "ComplianceCertificateLSP8",
            "VCERT",
            newOwner_,
            0,
            0
        )
    {}

    // -------------------------
    //  Mint
    // -------------------------

    /**
     * @notice Mint a new certificate token. issuedAt is set to block.timestamp.
     * @dev You can set the data later with setCertificateData().
     */
    function mintCert(bytes32 tokenId, address to, bytes calldata data)
        external
        onlyAssetOwner
    {
        require(!_minted[tokenId], "Already minted");

        _mint(to, tokenId, true, data);
        _minted[tokenId] = true;

        // Store issuedAt immediately (cleartext)
        _certByTokenId[tokenId].issuedAt = block.timestamp;
        _certByTokenId[tokenId].status = CertStatus.Valid;

        emit CertificateMinted(tokenId, to, block.timestamp);
        emit CertificateStatusChanged(tokenId, CertStatus.Valid);
    }

    // -------------------------
    //  Data set / get
    // -------------------------

    /**
     * @notice Set full certificate data (hash fields already computed off-chain with pepper).
     * @dev issuedAt is NOT taken from input; it is always the mint timestamp.
     */
    function setCertificateData(bytes32 tokenId, CertificateData calldata c)
        external
        onlyAssetOwner
    {
        require(!conformityFrozen, "Conformity frozen");
        require(_minted[tokenId], "Token not minted");

        // Minimal sanity checks (adapt if you want stricter)
        require(c.certificateNumberHash != bytes32(0), "Missing certificateNumberHash");
        require(c.inspectionDate != 0, "Missing inspectionDate");
        require(c.validUntil != 0, "Missing validUntil");
        require(c.documentHash != bytes32(0), "Missing documentHash");

        // Keep immutable issuedAt from mint
        uint256 issuedAt_ = _certByTokenId[tokenId].issuedAt;
        require(issuedAt_ != 0, "Missing issuedAt (mint first)");

        CertificateData memory stored = c;

        // Enforce issuedAt + default status rules
        stored.issuedAt = issuedAt_;

        // Validate enums bounds defensively
        if (uint8(stored.outcome) > uint8(Outcome.Conditional)) {
            stored.outcome = Outcome.Unknown;
        }
        if (uint8(stored.status) > uint8(CertStatus.Superseded)) {
            stored.status = CertStatus.Valid;
        }

        // If already revoked/superseded, do not silently reset it
        CertStatus currentStatus = _certByTokenId[tokenId].status;
        if (currentStatus == CertStatus.Revoked || currentStatus == CertStatus.Superseded) {
            stored.status = currentStatus;
        }

        _certByTokenId[tokenId] = stored;

        emit CertificateDataSet(
            tokenId,
            stored.certificateNumberHash,
            stored.documentHash,
            stored.inspectionDate,
            stored.outcome,
            stored.validUntil
        );
        emit CertificateStatusChanged(tokenId, _certByTokenId[tokenId].status);
    }

    function getCertificateData(bytes32 tokenId)
        external
        view
        returns (CertificateData memory)
    {
        return _certByTokenId[tokenId];
    }

    function issuedAt(bytes32 tokenId) external view returns (uint256) {
        return _certByTokenId[tokenId].issuedAt;
    }

    // -------------------------
    //  Status management
    // -------------------------

    function revoke(bytes32 tokenId)
        external
        onlyAssetOwner
    {
        require(!conformityFrozen, "Conformity frozen");
        require(_minted[tokenId], "Token not minted");

        CertificateData storage c = _certByTokenId[tokenId];
        require(c.issuedAt != 0, "No certificate data");
        require(c.status != CertStatus.Superseded, "Already superseded");

        c.status = CertStatus.Revoked;
        emit CertificateStatusChanged(tokenId, CertStatus.Revoked);
    }

    function supersede(bytes32 oldTokenId, bytes32 newTokenId)
        external
        onlyAssetOwner
    {
        require(!conformityFrozen, "Conformity frozen");
        require(_minted[oldTokenId] && _minted[newTokenId], "Mint both tokens first");

        CertificateData storage oldC = _certByTokenId[oldTokenId];
        CertificateData storage newC = _certByTokenId[newTokenId];

        require(oldC.issuedAt != 0, "Old missing data");
        require(newC.issuedAt != 0, "New missing data");

        require(oldC.status != CertStatus.Revoked, "Old is revoked");
        require(oldC.status != CertStatus.Superseded, "Old already superseded");

        oldC.status = CertStatus.Superseded;

        _supersededBy[oldTokenId] = newTokenId;
        _supersedes[newTokenId] = oldTokenId;

        emit CertificateStatusChanged(oldTokenId, CertStatus.Superseded);
        emit CertificateSuperseded(oldTokenId, newTokenId);
    }

    // -------------------------
    //  Supersede getters
    // -------------------------

    function supersededBy(bytes32 tokenId) external view returns (bytes32) {
        return _supersededBy[tokenId];
    }

    function supersedes(bytes32 tokenId) external view returns (bytes32) {
        return _supersedes[tokenId];
    }

    // -------------------------
    //  Freeze
    // -------------------------

    function freezeConformity() external onlyAssetOwner {
        conformityFrozen = true;
        emit ConformityFrozen();
    }

    // LSP4 / ERC725Y metadata setter (owner-managed)
    function setLSP4Metadata(bytes32 key, bytes calldata value)
        external
        onlyAssetOwner
    {
        require(!metadataFrozen, "Metadata frozen");
        _setData(key, value);
    }

    function freezeMetadata() external onlyAssetOwner {
        metadataFrozen = true;
        emit MetadataFrozen();
    }
}

