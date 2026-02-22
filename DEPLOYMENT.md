## LUKSO Testnet

### Compliance Certificates

**REV1**
- Contract: `ComplianceCertificateLSP8`
- Address: `0x8dD5006251d2e3D89fEaf6e8A016B07538d5C1f1`
- ChainId: `4201`
- Verified: ✅
- Deployed: `2025-12-23`

**REV2**
- Contract: `ComplianceCertificateLSP8REV2`
- Address: `0xA646887F752D1Ff976472118E270329b23AeeCd5`
- ChainId: `4201`
- Verified: ✅ (Standard JSON Input)
- Deployed: `2026-01-07`
- Notes:
  - Per-token metadata freeze (`freezeTokenMetadata`)
  - `Revoked` is terminal (cannot transition to any other state)
  - Superseding allowed only from `Valid → Superseded`
  - LSP4 / ERC725Y contract metadata has independent global freeze

---

### Battery Carbon Certificates

**REV2 (current)**
- Contract: `BatteryCarbonCertificateLSP8_Rev2`
- Address: `0xE0F24982fA686fEAD94f6b32C532B545c3cEB6CC`
- ChainId: `4201`
- Verified: ✅ (Standard JSON Input)
- Deployed: `2026-02-22`
- Owner (Admin): Universal Profile  
  `0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C`
- Notes:
  - LSP8 Identifiable Digital Asset
  - `tokenId = keccak256(lotCode)`
  - Multi-actor contribution model (`CAM`, `CELLS`, `LOGISTICS`)
  - Contribution flow based on:
    - **JSON off-chain (URI)**
    - **digest (`bytes32`) on-chain**
  - Signature ECDSA **removed by design (Rev2)**
    - Authentication via Universal Profile
    - Authorization via `actorByRole`
    - Non-repudiation via blockchain transaction (`msg.sender`)
    - Integrity via digest
  - Contribution submission restricted to authorized actor per role
  - Per-role contribution freeze (`freezeContribution`)
  - Certificate freeze requires:
    - all contributions frozen
    - aggregate present
  - Aggregate structure:
    - `aggregateURI`
    - `aggregateDigest`
  - Separation between:
    - governance (issuer allowlist via UP)
    - operational roles (actors per token)
    - data layer (off-chain JSON)
  - Designed for:
    - simplified UX
    - real-world integration
    - reduced operational complexity vs Rev1

---

**REV1**
- Contract: `BatteryCarbonCertificateLSP8`
- Address: `0xA0EB23c4e8c08f6d497FD8B80fF9CC9B91452E0A`
- ChainId: `4201`
- Verified: ✅ (Standard JSON Input)
- Deployed: `2026-01-18`
- Owner (Admin): Universal Profile  
  `0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C`
- Notes:
  - LSP8 Identifiable Digital Asset
  - `tokenId = keccak256(lotCode)`
  - Certificate issuance restricted via **issuer allowlist**
  - Allowlist managed exclusively by contract owner (UP) via `UP.execute`
  - Multi-actor contribution model
  - Contribution included:
    - digest (`bytes32`)
    - URI (off-chain)
    - **ECDSA signature (payload-level)**
  - On-chain signature verification:
    - binding between actor, content, and context
  - Higher complexity due to:
    - payload signing
    - signature validation
    - client-side cryptographic handling
  - Model designed for stronger payload-level non-repudiation
  - Superseded by Rev2 due to architectural redundancy of signature layer

  ---

### Traceability / Conformity Certificates

**REV2**
- Contract: `Traceability_test2`
- Address: `0xbF8bc6982326fEA71e9A0f4891893B153F0Eb1a8`
- ChainId: `4201` (LUKSO Testnet)
- Verified: ✅ (Blockscout — Standard JSON Input)
- Deployed: `2025-12-16`
- Deploy block: `6637857`
- Deploy tx: `0x70fc91b912ff27b0bbcc4343fae5ed68a3e5c44690fa365054c9aca9ac5dcf7e`
- Owner (Admin): Universal Profile  
  `0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C`
- Notes:
  - LSP8 Identifiable Digital Asset + Burnable extension
  - `mintCert()` restricted to contract owner (UP governance)
  - One token = one conformity certificate
  - Conformity data stored fully on-chain (`setConformityData`)
  - Certificate lifecycle:
    - `Valid`
    - `Revoked`
    - `Superseded`
  - Explicit superseding graph:
    - `oldTokenId → newTokenId`
    - Bidirectional lookup (`supersededBy`, `supersedes`)
  - Dual freeze model:
    - `freezeConformity()` → locks conformity + status transitions
    - `freezeMetadata()` → locks LSP4 / ERC725Y metadata
  - Governance and data lifecycle separated from metadata lifecycle
  
**REV1**
- Internal prototype (short-lived, replaced by REV2)



