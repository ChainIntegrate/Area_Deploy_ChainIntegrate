// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {
    LSP8IdentifiableDigitalAsset
} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";

import {
    LSP8Burnable
} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Burnable.sol";

/**
 * @title ComplianceCertificateLSP8REV2
 * @notice LSP8 certificates for verification/compliance use-cases.
 *
 * REV2 changes:
 * - tokenMetadataFrozen[tokenId] freezes ONLY CertificateData updates (metadata of that token)
 * - status changes remain possible EXCEPT:
 *   - Revoked is terminal: once Revoked, it can never transition to any other status.
 */
contract ComplianceCertificateLSP8REV2 is LSP8IdentifiableDigitalAsset, LSP8Burnable {
    // -------------------------
    //  Status / Outcome
    // -------------------------

    enum CertStatus {
        Valid,      // 0 (emesso/valido)
        Revoked,    // 1 (revocato)  [TERMINAL]
        Superseded  // 2 (superato)
    }

    enum Outcome {
        Unknown,     // 0
        Positive,    // 1
        Negative,    // 2
        Conditional  // 3
    }

    // -------------------------
    //  Certificate data model
    // -------------------------

    struct CertificateData {
        // --- Hash fields (pepper-based, computed off-chain) ---
        bytes32 companyNameHash;
        bytes32 vatHash;
        bytes32 fiscalCodeHash;
        bytes32 certificateNumberHash;
        bytes32 certificateTypeHash;
        bytes32 assetTypeHash;
        bytes32 modelHash;
        bytes32 serialNumberHash;
        bytes32 manufacturingYearHash;
        bytes32 standardHash;
        bytes32 reportReferenceHash;
        bytes32 technicianHash;

        // --- Cleartext fields ---
        uint256 inspectionDate;
        Outcome outcome;
        uint256 validUntil;
        uint256 issuedAt;

        // --- Document anchoring ---
        bytes32 documentHash;
        string documentURI;
        CertStatus status;
    }

    mapping(bytes32 => CertificateData) private _certByTokenId;

    // Mint tracking
    mapping(bytes32 => bool) private _minted;

    // supersede graph
    mapping(bytes32 => bytes32) private _supersededBy; // old => new
    mapping(bytes32 => bytes32) private _supersedes;   // new => old

    // -------------------------
    //  Freeze (REV2)
    // -------------------------

    // Per-token freeze: blocks ONLY certificate metadata updates (CertificateData)
    mapping(bytes32 => bool) public tokenMetadataFrozen;

    // Global freeze for LSP4/ERC725Y contract-level metadata (collection metadata)
    bool public metadataFrozen;

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

    event TokenMetadataFrozen(bytes32 indexed tokenId);

    event MetadataFrozen();

    // -------------------------
    //  Access control
    // -------------------------

    modifier onlyAssetOwner() {
        require(msg.sender == owner(), "Not owner");
        _;
    }

    modifier onlyMinted(bytes32 tokenId) {
        require(_minted[tokenId], "Token not minted");
        _;
    }

    modifier tokenMetadataNotFrozen(bytes32 tokenId) {
        require(!tokenMetadataFrozen[tokenId], "Token metadata frozen");
        _;
    }

    // -------------------------
    //  Constructor
    // -------------------------

    constructor(address newOwner_)
        LSP8IdentifiableDigitalAsset(
            "ComplianceCertificateLSP8REV2",
            "CCERT",
            newOwner_,
            0,
            0
        )
    {}

    // -------------------------
    //  Mint
    // -------------------------

    function mintCert(bytes32 tokenId, address to, bytes calldata data)
        external
        onlyAssetOwner
    {
        require(!_minted[tokenId], "Already minted");

        _mint(to, tokenId, true, data);
        _minted[tokenId] = true;

        _certByTokenId[tokenId].issuedAt = block.timestamp;
        _certByTokenId[tokenId].status = CertStatus.Valid;

        emit CertificateMinted(tokenId, to, block.timestamp);
        emit CertificateStatusChanged(tokenId, CertStatus.Valid);
    }

    // -------------------------
    //  Data set / get
    // -------------------------

    /**
     * @dev Blocked by tokenMetadataFrozen[tokenId].
     * @dev Does NOT allow changing a token that is already Revoked/Superseded back to Valid via data write.
     */
    function setCertificateData(bytes32 tokenId, CertificateData calldata c)
        external
        onlyAssetOwner
        onlyMinted(tokenId)
        tokenMetadataNotFrozen(tokenId)
    {
        require(c.certificateNumberHash != bytes32(0), "Missing certificateNumberHash");
        require(c.inspectionDate != 0, "Missing inspectionDate");
        require(c.validUntil != 0, "Missing validUntil");
        require(c.documentHash != bytes32(0), "Missing documentHash");

        uint256 issuedAt_ = _certByTokenId[tokenId].issuedAt;
        require(issuedAt_ != 0, "Missing issuedAt (mint first)");

        CertificateData memory stored = c;
        stored.issuedAt = issuedAt_;

        // Defensive enum bounds
        if (uint8(stored.outcome) > uint8(Outcome.Conditional)) {
            stored.outcome = Outcome.Unknown;
        }
        if (uint8(stored.status) > uint8(CertStatus.Superseded)) {
            stored.status = CertStatus.Valid;
        }

        // Preserve terminal/non-resettable statuses
        CertStatus currentStatus = _certByTokenId[tokenId].status;

        // If already Revoked => must stay Revoked (terminal)
        if (currentStatus == CertStatus.Revoked) {
            stored.status = CertStatus.Revoked;
        }
        // If already Superseded => must stay Superseded (no silent reset)
        else if (currentStatus == CertStatus.Superseded) {
            stored.status = CertStatus.Superseded;
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

    function isMinted(bytes32 tokenId) external view returns (bool) {
        return _minted[tokenId];
    }

    // -------------------------
    //  Status management
    // -------------------------

    /**
     * @notice Set status to Revoked (terminal).
     * @dev Once Revoked, it can never transition to any other status.
     * @dev Allowed even if token metadata is frozen.
     */
    function revoke(bytes32 tokenId)
        external
        onlyAssetOwner
        onlyMinted(tokenId)
    {
        CertificateData storage c = _certByTokenId[tokenId];
        require(c.issuedAt != 0, "No certificate data");
        require(c.status != CertStatus.Revoked, "Already revoked");

        c.status = CertStatus.Revoked;
        emit CertificateStatusChanged(tokenId, CertStatus.Revoked);
    }

    /**
     * @notice Supersede old certificate with a new one.
     * @dev Revoked is terminal: cannot supersede a revoked token, and cannot use a revoked token as "new".
     * @dev Allowed even if token metadata is frozen.
     */
    function supersede(bytes32 oldTokenId, bytes32 newTokenId)
        external
        onlyAssetOwner
    {
        require(_minted[oldTokenId] && _minted[newTokenId], "Mint both tokens first");

        CertificateData storage oldC = _certByTokenId[oldTokenId];
        CertificateData storage newC = _certByTokenId[newTokenId];

        require(oldC.issuedAt != 0, "Old missing data");
        require(newC.issuedAt != 0, "New missing data");

        // Old constraints
        require(oldC.status != CertStatus.Revoked, "Old is revoked");
        require(oldC.status != CertStatus.Superseded, "Old already superseded");

        // New constraints (extra REV2 safety)
        require(newC.status != CertStatus.Revoked, "New is revoked");

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
    //  Token-level metadata freeze
    // -------------------------

    function freezeTokenMetadata(bytes32 tokenId)
        external
        onlyAssetOwner
        onlyMinted(tokenId)
    {
        require(!tokenMetadataFrozen[tokenId], "Already frozen");
        tokenMetadataFrozen[tokenId] = true;
        emit TokenMetadataFrozen(tokenId);
    }

    // -------------------------
    //  Contract-level metadata (LSP4 / ERC725Y)
    // -------------------------

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
