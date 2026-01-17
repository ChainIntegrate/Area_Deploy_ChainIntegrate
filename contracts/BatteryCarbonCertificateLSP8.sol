// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// LUKSO LSP8
import {
  LSP8IdentifiableDigitalAsset
} from "@lukso/lsp8-contracts/contracts/LSP8IdentifiableDigitalAsset.sol";

// OpenZeppelin ECDSA
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * Battery Carbon Footprint Certificate - LSP8
 *
 * - 1 tokenId = 1 certificato (es: lotto PACK-75-0425)
 * - chi fa mint (msg.sender) diventa owner iniziale del token (tipicamente un UP)
 * - token trasferibile anche a EOA (es. MetaMask)
 * - 4 attori/ruoli: ISSUER, CAM, CELLS, LOGISTICS
 * - ogni attore pubblica e firma il proprio contributo (URI + digest + signature)
 * - ogni attore può "freezare" il proprio contributo (più auditabile)
 * - l'issuer pubblica l'aggregato e chiude il certificato (freeze globale)
 * - freeze metadata SOLO per token (tokenURI), nessun freeze di collezione
 */
contract BatteryCarbonCertificateLSP8 is LSP8IdentifiableDigitalAsset {
  using ECDSA for bytes32;

  // --- Ruoli ---
  enum Role {
    ISSUER,    // emittente batteria
    CAM,       // materiali attivi
    CELLS,     // produttore celle
    LOGISTICS  // logistica
  }

  enum Status {
    Draft,
    Collecting,
    Frozen,
    Revoked
  }

  // --- Contributo per ruolo ---
  struct Contribution {
    address contributor; // address autorizzato per quel ruolo
    string uri;          // JSON off-chain del contributo
    bytes32 digest;      // hash del JSON normalizzato
    bytes signature;     // firma ECDSA del contributore
    uint64 submittedAt;  // timestamp invio (ultima versione)
    bool exists;
    bool frozen;         // freeze del contributo (per-role)
    uint64 frozenAt;     // timestamp freeze contributo
  }

  // --- Dati certificato ---
  struct Certificate {
    address issuer;          // minter iniziale (issuer logico)
    string productType;      // es: "EV Pack 75 kWh"
    string scope;            // es: "Cradle-to-Gate"
    string period;           // es: "Q1 2025" (opzionale)
    Status status;
    uint64 createdAt;
    bool metadataFrozen;     // freeze tokenURI
  }

  // tokenId => cert data
  mapping(bytes32 => Certificate) private _cert;

  // tokenId => tokenURI (metadata root del certificato)
  mapping(bytes32 => string) private _tokenURI;

  // tokenId => role => actorAddress (autorizzato)
  mapping(bytes32 => mapping(Role => address)) public actorByRole;

  // tokenId => role => contribution
  mapping(bytes32 => mapping(Role => Contribution)) public contributionByRole;

  // tokenId => aggregato finale (URI + digest)
  mapping(bytes32 => string) public aggregateURI;
  mapping(bytes32 => bytes32) public aggregateDigest;

  // --- Eventi ---
  event CertificateMinted(bytes32 indexed tokenId, address indexed issuer, string tokenURI);
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

  // --- Errori custom ---
  error NotIssuer();
  error NotAuthorized();
  error InvalidStatus();
  error InvalidRole();
  error InvalidSignature();
  error AlreadyExists();
  error MetadataFrozen();
  error ContributionIsFrozen();
  error NothingToFreeze();
  error EmptyValue();

  constructor(string memory name_, string memory symbol_)
    LSP8IdentifiableDigitalAsset(
      name_,
      symbol_,
      msg.sender, // owner del contratto (amministrazione generale, se ti serve)
      0,          // lsp4TokenType (non critico qui)
      true        // isNonDivisible
    )
  {}

  // -------------------------
  // Views
  // -------------------------

  function tokenURI(bytes32 tokenId) external view returns (string memory) {
    return _tokenURI[tokenId];
  }

  function getCertificate(bytes32 tokenId) external view returns (Certificate memory) {
    return _cert[tokenId];
  }

  function getContribution(bytes32 tokenId, Role role) external view returns (Contribution memory) {
    return contributionByRole[tokenId][role];
  }

  // -------------------------
  // Mint: msg.sender diventa owner iniziale (possessore) del token
  // -------------------------

  function mintCertificate(
    bytes32 tokenId,
    string calldata certTokenURI_,
    string calldata productType_,
    string calldata scope_,
    string calldata period_
  ) external {
    if (bytes(certTokenURI_).length == 0) revert EmptyValue();
    if (bytes(productType_).length == 0) revert EmptyValue();
    if (bytes(scope_).length == 0) revert EmptyValue();

    if (_cert[tokenId].createdAt != 0) revert AlreadyExists();

    // mint a msg.sender (UP o EOA)
    _mint(msg.sender, tokenId, true, "");

    _cert[tokenId] = Certificate({
      issuer: msg.sender,
      productType: productType_,
      scope: scope_,
      period: period_,
      status: Status.Collecting,
      createdAt: uint64(block.timestamp),
      metadataFrozen: false
    });

    // issuer come role ISSUER
    actorByRole[tokenId][Role.ISSUER] = msg.sender;

    _tokenURI[tokenId] = certTokenURI_;

    emit CertificateMinted(tokenId, msg.sender, certTokenURI_);
    emit CertificateStatusChanged(tokenId, Status.Collecting);
  }

  // -------------------------
  // Authorize actors (solo issuer) - modificabile finché Collecting
  // -------------------------

  function authorizeActor(bytes32 tokenId, Role role, address actor) external {
    _requireIssuer(tokenId);
    _requireCollecting(tokenId);

    if (role == Role.ISSUER) revert InvalidRole();
    if (actor == address(0)) revert EmptyValue();

    // se già frozen il contributo di quel ruolo, non permettere cambio attore
    if (contributionByRole[tokenId][role].frozen) revert ContributionIsFrozen();

    actorByRole[tokenId][role] = actor;
    emit ActorAuthorized(tokenId, role, actor);
  }

  // -------------------------
  // Submit contribution (solo attore autorizzato) - aggiornabile finché non frozen (per ruolo)
  // -------------------------

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

    // verifica firma
    bytes32 payloadHash = _contributionPayloadHash(tokenId, role, uri, digest);
    address recovered = payloadHash.toEthSignedMessageHash().recover(signature);
    if (recovered != actor) revert InvalidSignature();

    // sovrascrive l'ultima versione (audit trail resta negli eventi)
    c.contributor = actor;
    c.uri = uri;
    c.digest = digest;
    c.signature = signature;
    c.submittedAt = uint64(block.timestamp);
    c.exists = true;

    emit ContributionSubmitted(tokenId, role, actor, digest, uri);
  }

  // -------------------------
  // Freeze contributo (solo attore del ruolo) - più auditabile
  // -------------------------

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

  // -------------------------
  // Publish aggregate (solo issuer) - aggiornabile finché Collecting
  // -------------------------

  function publishAggregate(bytes32 tokenId, string calldata uri, bytes32 digest) external {
    _requireIssuer(tokenId);
    _requireCollecting(tokenId);

    if (bytes(uri).length == 0) revert EmptyValue();
    if (digest == bytes32(0)) revert EmptyValue();

    aggregateURI[tokenId] = uri;
    aggregateDigest[tokenId] = digest;

    emit AggregatePublished(tokenId, digest, uri);
  }

  // -------------------------
  // Token metadata URI update + freeze (solo issuer)
  // -------------------------

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

  // -------------------------
  // Freeze certificato (solo issuer) - consigliato: richiedi contributi frozen + aggregato presente
  // -------------------------

  function freezeCertificate(bytes32 tokenId) external {
    _requireIssuer(tokenId);
    _requireCollecting(tokenId);

    // Regola consigliata: non chiudere se manca qualcosa
    if (!contributionByRole[tokenId][Role.CAM].frozen) revert InvalidStatus();
    if (!contributionByRole[tokenId][Role.CELLS].frozen) revert InvalidStatus();
    if (!contributionByRole[tokenId][Role.LOGISTICS].frozen) revert InvalidStatus();
    if (aggregateDigest[tokenId] == bytes32(0)) revert InvalidStatus();

    _cert[tokenId].status = Status.Frozen;
    emit CertificateStatusChanged(tokenId, Status.Frozen);
  }

  // opzionale: revoca (solo issuer)
  function revokeCertificate(bytes32 tokenId) external {
    _requireIssuer(tokenId);
    _cert[tokenId].status = Status.Revoked;
    emit CertificateStatusChanged(tokenId, Status.Revoked);
  }

  // -------------------------
  // Internals
  // -------------------------

  function _requireIssuer(bytes32 tokenId) internal view {
    Certificate memory c = _cert[tokenId];
    if (c.createdAt == 0) revert InvalidStatus();

    // issuer logico = minter iniziale (anche se il token viene poi trasferito)
    if (msg.sender != c.issuer) revert NotIssuer();
  }

  function _requireCollecting(bytes32 tokenId) internal view {
    Certificate memory c = _cert[tokenId];
    if (c.createdAt == 0) revert InvalidStatus();
    if (c.status != Status.Collecting) revert InvalidStatus();
  }

  /**
   * Payload firmato dall'attore.
   * Include chainId e address(this) per prevenire replay cross-chain/cross-contract.
   * uri entra come hash (keccak256(bytes(uri))) per evitare ambiguità.
   */
  function _contributionPayloadHash(
    bytes32 tokenId,
    Role role,
    string calldata uri,
    bytes32 digest
  ) internal view returns (bytes32) {
    return keccak256(
      abi.encodePacked(
        "BatteryCarbonCertificateContribution",
        block.chainid,
        address(this),
        tokenId,
        uint256(role),
        keccak256(bytes(uri)),
        digest
      )
    );
  }
}
