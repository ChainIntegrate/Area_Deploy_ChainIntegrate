// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import { LSP8IdentifiableDigitalAsset } from
  "@lukso/lsp8-contracts/contracts/LSP8IdentifiableDigitalAsset.sol";
import { _LSP4_TOKEN_TYPE_NFT } from "@lukso/lsp4-contracts/contracts/LSP4Constants.sol";
import { _LSP8_TOKENID_FORMAT_HASH } from "@lukso/lsp8-contracts/contracts/LSP8Constants.sol";



/**
 * Supplier Evaluation LSP8
 * - tokenId (bytes32) = fornitore
 * - mint: QualityOffice minta e manda subito al fornitore
 * - valutazioni semestrali append-only
 * - overall on-chain + currentOverall + media storica
 */
contract SupplierQualityLSP8 is LSP8IdentifiableDigitalAsset {
  // =========================
  // Config
  // =========================
  uint16 public constant MAX_NOTE_BYTES = 150;

  // Pesi in "per mille" (somma 1000)
  uint16 public constant W_PUNCTUALITY   = 300; // 30%
  uint16 public constant W_QUALITY       = 400; // 40%
  uint16 public constant W_DOCUMENTATION = 200; // 20%
  uint16 public constant W_REACTIVITY    = 100; // 10%

  // =========================
  // Roles
  // =========================
  address public qualityOffice; // chi può mintare e scrivere valutazioni

  modifier onlyQualityOffice() {
    require(msg.sender == qualityOffice, "Not Quality Office");
    _;
  }

  // =========================
  // Types
  // =========================
  // 0..4 come da tua scelta
  enum Level {
    Unknown,     // 0
    Critical,    // 1
    Sufficient,  // 2
    Good,        // 3
    Excellent    // 4
  }

  struct Scores {
    Level punctuality;
    Level quality;
    Level documentation;
    Level reactivity;
  }

  struct Evaluation {
    uint32 period;     // es: 20261 (H1 2026), 20262 (H2 2026)
    uint64 createdAt;  // timestamp consolidamento
    Scores scores;     // 4 criteri
    uint16 overall;    // 0..1000 (pesato)
    string note;       // opzionale, max 150 bytes
  }

  struct SupplierIdentity {
    bytes32 supplierRef; // tuo codice/hash interno
    string name;         // opzionale demo/UI
    uint64 createdAt;
    bool exists;
  }

  struct SupplierStats {
    uint16 currentOverall; // ultimo overall
    uint64 sumOverall;     // somma overall storici (0..1000 ciascuno)
    uint32 count;          // numero valutazioni
    uint32 lastPeriod;     // ultimo period registrato (comodo per UI)
  }

  // =========================
  // Storage
  // =========================
  mapping(bytes32 => SupplierIdentity) private _supplier;
  mapping(bytes32 => SupplierStats) private _stats;

  // tokenId => evaluations[]
  mapping(bytes32 => Evaluation[]) private _evaluations;

  // tokenId => period => index+1 (0=assente)
  mapping(bytes32 => mapping(uint32 => uint256)) private _periodIndexPlusOne;

  // =========================
  // Events
  // =========================
  event QualityOfficeSet(address indexed newQualityOffice);

  event SupplierMinted(
    bytes32 indexed tokenId,
    address indexed supplierWallet,
    bytes32 supplierRef,
    string name
  );

  event EvaluationAdded(
    bytes32 indexed tokenId,
    uint32 period,
    uint16 overall,
    Level punctuality,
    Level quality,
    Level documentation,
    Level reactivity,
    string note
  );

  // =========================
  // Constructor
  // =========================
  constructor(
    string memory name_,
    string memory symbol_,
    address chainIntegrateOwner_,
    address qualityOffice_
  )
   LSP8IdentifiableDigitalAsset(
  name_,
  symbol_,
  chainIntegrateOwner_,
  _LSP4_TOKEN_TYPE_NFT,
  _LSP8_TOKENID_FORMAT_HASH
)

  {
    require(chainIntegrateOwner_ != address(0), "Owner=0");
    require(qualityOffice_ != address(0), "QualityOffice=0");
    qualityOffice = qualityOffice_;
    emit QualityOfficeSet(qualityOffice_);
  }

  // =========================
  // Admin
  // =========================
  function setQualityOffice(address newQualityOffice) external onlyOwner {
    require(newQualityOffice != address(0), "QualityOffice=0");
    qualityOffice = newQualityOffice;
    emit QualityOfficeSet(newQualityOffice);
  }

  // =========================
  // Mint (QualityOffice)
  // =========================
  /**
   * Minta il token del fornitore e lo manda subito nel wallet del fornitore.
   * tokenId: bytes32 (stabile) -> es: keccak256(abi.encodePacked("SUP:", supplierCode))
   */
  function mintSupplierTo(
    address supplierWallet,
    bytes32 tokenId,
    bytes32 supplierRef,
    string calldata supplierName
  ) external onlyQualityOffice {
    require(supplierWallet != address(0), "SupplierWallet=0");
    require(!_supplier[tokenId].exists, "Supplier already exists");

    _supplier[tokenId] = SupplierIdentity({
      supplierRef: supplierRef,
      name: supplierName,
      createdAt: uint64(block.timestamp),
      exists: true
    });

    // force = true: consenti mint anche verso EOA/non LSP1 (in demo spesso utile)
    _mint(supplierWallet, tokenId, true, "");

    emit SupplierMinted(tokenId, supplierWallet, supplierRef, supplierName);
  }

  // =========================
  // Add evaluation (append-only)
  // =========================
  function addEvaluation(
    bytes32 tokenId,
    uint32 period,
    Scores calldata scores,
    string calldata note
  ) external onlyQualityOffice {
    require(_supplier[tokenId].exists, "Unknown supplier");
    require(period != 0, "Invalid period");
    _ensureValidScores(scores);
    _ensureNoteLen(note);

    require(_periodIndexPlusOne[tokenId][period] == 0, "Period already evaluated");

    uint16 overall = _calcOverall(scores);

    Evaluation memory e = Evaluation({
      period: period,
      createdAt: uint64(block.timestamp),
      scores: Scores({
        punctuality: scores.punctuality,
        quality: scores.quality,
        documentation: scores.documentation,
        reactivity: scores.reactivity
      }),
      overall: overall,
      note: note
    });

    _evaluations[tokenId].push(e);
    _periodIndexPlusOne[tokenId][period] = _evaluations[tokenId].length;

    // stats O(1)
    SupplierStats storage st = _stats[tokenId];
    st.currentOverall = overall;
    st.sumOverall += overall;
    st.count += 1;
    st.lastPeriod = period;

    emit EvaluationAdded(
      tokenId,
      period,
      overall,
      e.scores.punctuality,
      e.scores.quality,
      e.scores.documentation,
      e.scores.reactivity,
      note
    );
  }

  // =========================
  // Read (UI-friendly)
  // =========================
  function getSupplier(bytes32 tokenId) external view returns (SupplierIdentity memory) {
    require(_supplier[tokenId].exists, "Unknown supplier");
    return _supplier[tokenId];
  }

  function getStats(bytes32 tokenId)
    external
    view
    returns (
      uint16 currentOverall,
      uint16 avgOverall,
      uint32 count,
      uint32 lastPeriod
    )
  {
    require(_supplier[tokenId].exists, "Unknown supplier");
    SupplierStats memory st = _stats[tokenId];

    currentOverall = st.currentOverall;
    count = st.count;
    lastPeriod = st.lastPeriod;

    if (st.count == 0) {
      avgOverall = 0;
    } else {
      // avg in 0..1000
      avgOverall = uint16(st.sumOverall / st.count);
    }
  }

  function getEvaluationsCount(bytes32 tokenId) external view returns (uint256) {
    require(_supplier[tokenId].exists, "Unknown supplier");
    return _evaluations[tokenId].length;
  }

  function getEvaluationByIndex(bytes32 tokenId, uint256 index)
    external
    view
    returns (Evaluation memory)
  {
    require(_supplier[tokenId].exists, "Unknown supplier");
    require(index < _evaluations[tokenId].length, "Index out of bounds");
    return _evaluations[tokenId][index];
  }

  function getEvaluationByPeriod(bytes32 tokenId, uint32 period)
    external
    view
    returns (Evaluation memory)
  {
    require(_supplier[tokenId].exists, "Unknown supplier");
    uint256 idxPlus = _periodIndexPlusOne[tokenId][period];
    require(idxPlus != 0, "No evaluation for period");
    return _evaluations[tokenId][idxPlus - 1];
  }

  // =========================
  // Internals
  // =========================
  function _ensureValidLevel(Level v) internal pure {
    require(uint8(v) <= uint8(Level.Excellent), "Invalid level");
  }

  function _ensureValidScores(Scores calldata s) internal pure {
    _ensureValidLevel(s.punctuality);
    _ensureValidLevel(s.quality);
    _ensureValidLevel(s.documentation);
    _ensureValidLevel(s.reactivity);
  }

  function _ensureNoteLen(string calldata note) internal pure {
    // Limite su bytes (per note ASCII è 1:1 con “caratteri”)
    require(bytes(note).length <= MAX_NOTE_BYTES, "Note too long");
  }

  // Level (0..4) -> points (0..1000)
  function _levelToPoints(Level v) internal pure returns (uint16) {
    if (v == Level.Unknown) return 0;
    if (v == Level.Critical) return 250;
    if (v == Level.Sufficient) return 500;
    if (v == Level.Good) return 750;
    return 1000; // Excellent
  }

  // overall 0..1000
  function _calcOverall(Scores calldata s) internal pure returns (uint16) {
    uint256 p = _levelToPoints(s.punctuality);
    uint256 q = _levelToPoints(s.quality);
    uint256 d = _levelToPoints(s.documentation);
    uint256 r = _levelToPoints(s.reactivity);

    uint256 overall =
      (p * W_PUNCTUALITY +
       q * W_QUALITY +
       d * W_DOCUMENTATION +
       r * W_REACTIVITY) / 1000;

    return uint16(overall); // 0..1000
  }
}
