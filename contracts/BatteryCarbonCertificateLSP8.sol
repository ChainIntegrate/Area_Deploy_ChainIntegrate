// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// LUKSO LSP8
import {
  LSP8IdentifiableDigitalAsset
} from "@lukso/lsp8-contracts/contracts/LSP8IdentifiableDigitalAsset.sol";

// LUKSO constants
import { _LSP4_TOKEN_TYPE_NFT } from "@lukso/lsp4-contracts/contracts/LSP4Constants.sol";
import { _LSP8_TOKENID_FORMAT_HASH } from "@lukso/lsp8-contracts/contracts/LSP8Constants.sol";

// OpenZeppelin ECDSA
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * Battery Carbon Footprint Certificate (LSP8)
 *
 * - tokenId = keccak256(lotCode)
 * - lotCode salvato on-chain (es: "PACK-75-0425")
 * - mint consentito solo a issuer in allowlist
 * - owner del contratto = Universal Profile admin
 */
contract BatteryCarbonCertificateLSP8 is LSP8IdentifiableDigitalAsset {
  using ECDSA for bytes32;

  // --------------------------------------------------
  // Enums
  // --------------------------------------------------

  enum Role {
    ISSUER,
    CAM,
    CELLS,
    LOGISTICS
  }

  enum Status {
    Collecting,
    Frozen,
    Revoked
  }

  // --------------------------------------------------
  // Structs
  // --------------------------------------------------

  struct Contribution {
    address contributor;
    string uri;
    bytes32 digest;
    bytes signature;
    uint64 submittedAt;
    bool exists;
    bool frozen;
    uint64 frozenAt;
  }

  struct Certificate {
    address issuer;
    string lotCode;
    string productType;
    string scope;
    string period;
    Status status;
    uint64 createdAt;
    bool metadataFrozen;
  }

  // --------------------------------------------------
  // Storage
  // --------------------------------------------------

  mapping(bytes32 => Certificate) private _cert;
  mapping(bytes32 => string) private _tokenURI;

  mapping(bytes32 => mapping(Role => address)) public actorByRole;
  mapping(bytes32 => mapping(Role => Contribution)) public contributionByRole;

  mapping(bytes32 => string) public aggregateURI;
  mapping(bytes32 => bytes32) public aggregateDigest;

  // Allowlist issuer
  mapping(address => bool) public isIssuerAllowed;

  // --------------------------------------------------
  // Events
  // --------------------------------------------------

  event IssuerAllowanceUpdated(address indexed issuer, bool allowed);

  event CertificateMinted(
    bytes32 indexed tokenId,
    address indexed issuer,
    string lotCode,
    string tokenURI
  );

  event CertificateStatusChanged(bytes32 indexed tokenId, Status status);

  event ActorAuthorized(bytes32 indexed tokenId, Role indexed role, address indexed actor);

  event ContributionSubmitted(
    bytes32 indexed tokenId,
    Role indexed role,
    address indexed actor,
    bytes32 digest,
    string uri
  );

  event ContributionFrozen(bytes32 indexed tokenId, Role indexed role, address indexed actor);

  event AggregatePublished(bytes32 indexed tokenId, bytes32 digest, string uri);

  event TokenURIMetadataUpdated(bytes32 indexed tokenId, string newURI);
  event TokenURIMetadataFrozen(bytes32 indexed tokenId);

  // --------------------------------------------------
  // Errors
  // --------------------------------------------------

  error NotAuthorized();
  error NotIssuer();
  error IssuerNotAllowed();
  error InvalidStatus();
  error InvalidRole();
  error InvalidSignature();
  error AlreadyExists();
  error MetadataFrozen();
  error ContributionIsFrozen();
  error NothingToFreeze();
  error EmptyValue();

  // --------------------------------------------------
  // Constructor
  // --------------------------------------------------

  /**
   * @param owner_ Universal Profile admin (immutabile)
   */
  constructor(
    string memory name_,
    string memory symbol_,
    address owner_
  )
    LSP8IdentifiableDigitalAsset(
      name_,
      symbol_,
      owner_,
      _LSP4_TOKEN_TYPE_NFT,
      _LSP8_TOKENID_FORMAT_HASH
    )
  {
    require(owner_ != address(0), "owner_ = 0");
  }

  // --------------------------------------------------
  // Allowlist admin (via UP.execute)
  // --------------------------------------------------

  function setIssuerAllowed(address issuer, bool allowed) external onlyOwner {
    if (issuer == address(0)) revert EmptyValue();
    isIssuerAllowed[issuer] = allowed;
    emit IssuerAllowanceUpdated(issuer, allowed);
  }

  function setIssuersAllowed(address[] calldata issuers, bool allowed) external onlyOwner {
    for (uint256 i = 0; i < issuers.length; i++) {
      address issuer = issuers[i];
      if (issuer == address(0)) revert EmptyValue();
      isIssuerAllowed[issuer] = allowed;
      emit IssuerAllowanceUpdated(issuer, allowed);
    }
  }

  // --------------------------------------------------
  // Helpers
  // --------------------------------------------------

  function computeTokenIdFromLot(string calldata lotCode) public pure returns (bytes32) {
    return keccak256(abi.encodePacked(lotCode));
  }

  // --------------------------------------------------
  // Views
  // --------------------------------------------------

  function tokenURI(bytes32 tokenId) external view returns (string memory) {
    return _tokenURI[tokenId];
  }

  function getCertificate(bytes32 tokenId) external view returns (Certificate memory) {
    return _cert[tokenId];
  }

  function getContribution(bytes32 tokenId, Role role)
    external
    view
    returns (Contribution memory)
  {
    return contributionByRole[tokenId][role];
  }

  // --------------------------------------------------
  // Mint (solo issuer allowlisted)
  // --------------------------------------------------

  function mintCertificateByLot(
    string calldata lotCode,
    string calldata certTokenURI_,
    string calldata productType_,
    string calldata scope_,
    string calldata period_
  ) external returns (bytes32 tokenId) {
    if (!isIssuerAllowed[msg.sender]) revert IssuerNotAllowed();

    if (bytes(lotCode).length == 0) revert EmptyValue();
    if (bytes(certTokenURI_).length == 0) revert EmptyValue();
    if (bytes(productType_).length == 0) revert EmptyValue();
    if (bytes(scope_).length == 0) revert EmptyValue();

    tokenId = computeTokenIdFromLot(lotCode);
    if (_cert[tokenId].createdAt != 0) revert AlreadyExists();

    _mint(msg.sender, tokenId, true, "");

    _cert[tokenId] = Certificate({
      issuer: msg.sender,
      lotCode: lotCode,
      productType: productType_,
      scope: scope_,
      period: period_,
      status: Status.Collecting,
      createdAt: uint64(block.timestamp),
      metadataFrozen: false
    });

    actorByRole[tokenId][Role.ISSUER] = msg.sender;
    _tokenURI[tokenId] = certTokenURI_;

    emit CertificateMinted(tokenId, msg.sender, lotCode, certTokenURI_);
    emit CertificateStatusChanged(tokenId, Status.Collecting);
  }

  // --------------------------------------------------
  // Issuer actions
  // --------------------------------------------------

  function authorizeActor(bytes32 tokenId, Role role, address actor) external {
    _requireIssuer(tokenId);
    _requireCollecting(tokenId);

    if (role == Role.ISSUER) revert InvalidRole();
    if (actor == address(0)) revert EmptyValue();
    if (contributionByRole[tokenId][role].frozen) revert ContributionIsFrozen();

    actorByRole[tokenId][role] = actor;
    emit ActorAuthorized(tokenId, role, actor);
  }

  function submitContribution(
    bytes32 tokenId,
    Role role,
    string calldata uri,
    bytes32 digest,
    bytes calldata signature
  ) external {
    _requireCollecting(tokenId);

    if (role == Role.ISSUER) revert InvalidRole();
    if (bytes(uri).length == 0) revert EmptyValue();
    if (digest == bytes32(0)) revert EmptyValue();

    address actor = actorByRole[tokenId][role];
    if (actor == address(0) || msg.sender != actor) revert NotAuthorized();

    Contribution storage c = contributionByRole[tokenId][role];
    if (c.frozen) revert ContributionIsFrozen();

    bytes32 payloadHash = _contributionPayloadHash(tokenId, role, uri, digest);
    address recovered = payloadHash.toEthSignedMessageHash().recover(signature);
    if (recovered != actor) revert InvalidSignature();

    c.contributor = actor;
    c.uri = uri;
    c.digest = digest;
    c.signature = signature;
    c.submittedAt = uint64(block.timestamp);
    c.exists = true;

    emit ContributionSubmitted(tokenId, role, actor, digest, uri);
  }

  function freezeContribution(bytes32 tokenId, Role role) external {
    _requireCollecting(tokenId);

    if (role == Role.ISSUER) revert InvalidRole();

    address actor = actorByRole[tokenId][role];
    if (actor == address(0) || msg.sender != actor) revert NotAuthorized();

    Contribution storage c = contributionByRole[tokenId][role];
    if (!c.exists) revert NothingToFreeze();
    if (c.frozen) revert ContributionIsFrozen();

    c.frozen = true;
    c.frozenAt = uint64(block.timestamp);

    emit ContributionFrozen(tokenId, role, actor);
  }

  function publishAggregate(bytes32 tokenId, string calldata uri, bytes32 digest) external {
    _requireIssuer(tokenId);
    _requireCollecting(tokenId);

    if (bytes(uri).length == 0) revert EmptyValue();
    if (digest == bytes32(0)) revert EmptyValue();

    aggregateURI[tokenId] = uri;
    aggregateDigest[tokenId] = digest;

    emit AggregatePublished(tokenId, digest, uri);
  }

  function setTokenURI(bytes32 tokenId, string calldata newURI) external {
    _requireIssuer(tokenId);
    _requireCollecting(tokenId);

    if (_cert[tokenId].metadataFrozen) revert MetadataFrozen();
    if (bytes(newURI).length == 0) revert EmptyValue();

    _tokenURI[tokenId] = newURI;
    emit TokenURIMetadataUpdated(tokenId, newURI);
  }

  function freezeTokenMetadata(bytes32 tokenId) external {
    _requireIssuer(tokenId);
    _requireCollecting(tokenId);

    _cert[tokenId].metadataFrozen = true;
    emit TokenURIMetadataFrozen(tokenId);
  }

  function freezeCertificate(bytes32 tokenId) external {
    _requireIssuer(tokenId);
    _requireCollecting(tokenId);

    if (!contributionByRole[tokenId][Role.CAM].frozen) revert InvalidStatus();
    if (!contributionByRole[tokenId][Role.CELLS].frozen) revert InvalidStatus();
    if (!contributionByRole[tokenId][Role.LOGISTICS].frozen) revert InvalidStatus();
    if (aggregateDigest[tokenId] == bytes32(0)) revert InvalidStatus();

    _cert[tokenId].status = Status.Frozen;
    emit CertificateStatusChanged(tokenId, Status.Frozen);
  }

  function revokeCertificate(bytes32 tokenId) external {
    _requireIssuer(tokenId);
    _cert[tokenId].status = Status.Revoked;
    emit CertificateStatusChanged(tokenId, Status.Revoked);
  }

  // --------------------------------------------------
  // Internals
  // --------------------------------------------------

  function _requireIssuer(bytes32 tokenId) internal view {
    Certificate memory c = _cert[tokenId];
    if (c.createdAt == 0) revert InvalidStatus();
    if (msg.sender != c.issuer) revert NotIssuer();
  }

  function _requireCollecting(bytes32 tokenId) internal view {
    Certificate memory c = _cert[tokenId];
    if (c.createdAt == 0) revert InvalidStatus();
    if (c.status != Status.Collecting) revert InvalidStatus();
  }

  function _contributionPayloadHash(
    bytes32 tokenId,
    Role role,
    string calldata uri,
    bytes32 digest
  ) internal view returns (bytes32) {
    string memory lot = _cert[tokenId].lotCode;

    return keccak256(
      abi.encodePacked(
        "BatteryCarbonCertificateContribution",
        block.chainid,
        address(this),
        tokenId,
        keccak256(bytes(lot)),
        uint256(role),
        keccak256(bytes(uri)),
        digest
      )
    );
  }
}
