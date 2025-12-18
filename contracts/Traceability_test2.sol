// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { LSP8IdentifiableDigitalAsset } from
  "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";
import { LSP8Burnable } from
  "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/extensions/LSP8Burnable.sol";

contract Traceability_test2 is LSP8IdentifiableDigitalAsset, LSP8Burnable {

    // -------------------------
    //  Conformity / Traceability
    // -------------------------

    enum CertStatus {
        Valid,      // 0
        Revoked,    // 1
        Superseded  // 2
    }

    struct ConformityCert {
        bytes32 certificateId;
        bytes32 companyIdHash;
        bytes32 batchIdHash;
        bytes32 standardHash;
        uint256 issuedAt;
        uint256 validUntil;
        bytes32 documentHash;
        string  documentURI;
        CertStatus status;
    }

    mapping(bytes32 => ConformityCert) private _certByTokenId;

    // 🔗 supersede graph
    mapping(bytes32 => bytes32) private _supersededBy; // old => new
    mapping(bytes32 => bytes32) private _supersedes;   // new => old

    bool public metadataFrozen;
    bool public conformityFrozen;

    // -------------------------
    //  Events
    // -------------------------

    event ConformitySet(
        bytes32 indexed tokenId,
        bytes32 indexed certificateId,
        bytes32 documentHash,
        uint256 issuedAt
    );

    event ConformityStatusChanged(bytes32 indexed tokenId, CertStatus status);

    event CertificateSuperseded(
        bytes32 indexed oldTokenId,
        bytes32 indexed newTokenId
    );

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
            "Traceability_test2",
            "TRC2",
            newOwner_,
            0,
            0
        )
    {}

    // -------------------------
    //  Mint
    // -------------------------

    function mintCert(
        bytes32 tokenId,
        address to,
        bytes calldata data
    )
        external
        onlyAssetOwner
    {
        _mint(to, tokenId, true, data);
    }

    // -------------------------
    //  Conformity data
    // -------------------------

    function setConformityData(
        bytes32 tokenId,
        ConformityCert calldata c
    )
        external
        onlyAssetOwner
    {
        require(!conformityFrozen, "Conformity frozen");
        require(c.certificateId != bytes32(0), "Missing certificateId");
        require(c.documentHash != bytes32(0), "Missing documentHash");
        require(c.issuedAt != 0, "Missing issuedAt");

        ConformityCert memory stored = c;
        if (uint8(stored.status) > uint8(CertStatus.Superseded)) {
            stored.status = CertStatus.Valid;
        }

        _certByTokenId[tokenId] = stored;

        emit ConformitySet(
            tokenId,
            stored.certificateId,
            stored.documentHash,
            stored.issuedAt
        );
        emit ConformityStatusChanged(tokenId, stored.status);
    }

    function getConformityData(bytes32 tokenId)
        external
        view
        returns (ConformityCert memory)
    {
        return _certByTokenId[tokenId];
    }

    // -------------------------
    //  Status management
    // -------------------------

    function revoke(bytes32 tokenId)
        external
        onlyAssetOwner
    {
        require(!conformityFrozen, "Conformity frozen");

        ConformityCert storage c = _certByTokenId[tokenId];
        require(c.certificateId != bytes32(0), "No conformity data");

        c.status = CertStatus.Revoked;
        emit ConformityStatusChanged(tokenId, CertStatus.Revoked);
    }

    function supersede(bytes32 oldTokenId, bytes32 newTokenId)
        external
        onlyAssetOwner
    {
        require(!conformityFrozen, "Conformity frozen");

        ConformityCert storage oldC = _certByTokenId[oldTokenId];
        require(oldC.certificateId != bytes32(0), "Old missing");

        ConformityCert storage newC = _certByTokenId[newTokenId];
        require(newC.certificateId != bytes32(0), "New missing");

        oldC.status = CertStatus.Superseded;

        _supersededBy[oldTokenId] = newTokenId;
        _supersedes[newTokenId] = oldTokenId;

        emit ConformityStatusChanged(oldTokenId, CertStatus.Superseded);
        emit CertificateSuperseded(oldTokenId, newTokenId);
    }

    // -------------------------
    //  Supersede getters
    // -------------------------

    function supersededBy(bytes32 tokenId)
        external
        view
        returns (bytes32)
    {
        return _supersededBy[tokenId];
    }

    function supersedes(bytes32 tokenId)
        external
        view
        returns (bytes32)
    {
        return _supersedes[tokenId];
    }

    // -------------------------
    //  Freeze
    // -------------------------

    function freezeConformity()
        external
        onlyAssetOwner
    {
        conformityFrozen = true;
        emit ConformityFrozen();
    }

    function setLSP4Metadata(
        bytes32 key,
        bytes calldata value
    )
        external
        onlyAssetOwner
    {
        require(!metadataFrozen, "Metadata frozen");
        _setData(key, value);
    }

    function freezeMetadata()
        external
        onlyAssetOwner
    {
        metadataFrozen = true;
        emit MetadataFrozen();
    }
}
