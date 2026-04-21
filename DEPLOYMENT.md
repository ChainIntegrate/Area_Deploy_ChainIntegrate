## LUKSO Testnet

---

# 🧱 Condominium Registry (V2)

* **Contract:** `CondominiumRegistryLSP8V2`
* **Address:** `TBD`
* **ChainId:** `4201`
* **Verified:** ✅ (Standard JSON Input)
* **Deployed:** `2026-04-21`
* **Owner (Admin):** Universal Profile
  `0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C`
* **Required Profile Interface:**
  `0x629aa694` (ERC725Y – Universal Profile compatibility)
* **Authorized creators:**
  Configurable via `setAuthorizedCreator(address,bool)` by the contract owner.

---

## 🔁 Key Upgrade (V2)

* **Contractors are now scoped per condominium**

  * Each condominium maintains its own contractor registry
  * Contractors are created and managed **only by the condominium administrator**
  * Eliminates global contractor dependency

---

## 🧠 Model Overview

### LSP8 Asset Model

* **1 token = 1 condominium**
* `tokenId` is a `bytes32` identifier defined at mint time
* Token is minted directly to the administrator Universal Profile

---

### 🏢 Condominium Identity

Each condominium stores:

* `name`
* `location`
* `adminUP`
* `createdAt`
* `active`

Administration can be transferred via `transferAdministration`, generating a system event.

---

### 👥 Roles

* **Contract owner (UP):**

  * authorizes creators

* **Authorized creators:**

  * mint new condominiums

* **Condominium administrator:**

  * manages contractors, resolutions, works, and events
  * transfers administration

---

### 🧾 Resolutions (Delibere)

Managed per condominium via `createResolution`.

Each resolution includes:

* `category`
* `title`
* `approved`
* `dataURI`, `dataHash`
* `createdBy`, `createdAt`

---

### 🏗️ Contractor Model (V2)

* Contractors are **NOT global anymore**
* Each contractor is linked to a specific `tokenId`

Each contractor includes:

* `name`
* optional `walletUP`
* `metadataURI`
* `active`
* `createdBy`

Managed via:

* `createContractor(tokenId, ...)`
* `setContractorActive(tokenId, ...)`

---

### 🔧 Work Items

Managed per condominium via `createWorkItem`.

Each work includes:

* optional `resolutionId`
* optional `contractorId`
* `title`, `category`
* `WorkType`: `Generic` | `FixedTerm`
* lifecycle `WorkStatus`
* planned and actual dates

---

### 📜 Registry Events

Every action produces a `RegistryEvent`.

Includes:

* `eventType`
* `timestamp`
* `category`, `title`
* links to resolution/work
* `dataURI`, `dataHash`
* `createdBy`

Ensures full traceability.

---

### 🔐 Access Control

* Contractors → managed by **condominium admin**
* Resolutions, works, events → managed by **condominium admin**
* Minting → controlled by **authorized creators**

---

### 🧩 Data Architecture

* Hybrid **on-chain / off-chain**
* Documents stored off-chain, referenced via:

  * `dataURI`
  * `dataHash`

---

### 🎯 Designed for

* Digital identity of condominiums
* Transparent governance
* Work lifecycle management
* Contractor accountability
* Event-driven audit trail

---

# 📜 Legacy (V1)

* **Contract:** `CondominiumRegistryLSP8`
* **Address:** `0x489F040770f099d48957F7065C88aC0cdB322a0C`
* **Deployed:** `2026-04-16`
* **Verified:** ✅

---

## Key Differences (V1 → V2)

* Contractors were **globally registered**
* Managed only by **contract owner**
* Shared across all condominiums

---

## Limitation

* Did not reflect real-world structure
* Introduced centralization in supplier management

---

## Migration Rationale

V2 introduces:

* decentralized contractor management
* per-condominium isolation
* improved governance model

---

## Status

* V1 remains deployed and functional
* V2 is the **active evolution** of the protocol

---

### Vehicle Passport

**REV1 (current)**
- Contract: `VehiclePassportRegistry`
- Address: `0x97224Dc84d231d1e7e6e76bB210d0Df6a839C378`
- ChainId: `4201`
- Verified: ✅ (Standard JSON Input)
- Deployed: `2026-03-19`
- Owner (Admin): Universal Profile  
  `0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C`
- Authorized dealer / issuer (current setup):  
  `0xAa18E265Bb38cD507eD018AF9abf0FeF16E685C9`
- Notes:
  - LSP8 Identifiable Digital Asset
  - `tokenId = keccak256(normalizedVIN)`
  - One token = one vehicle passport
  - Vehicle origin metadata managed as token-scoped data
  - Origin metadata structure:
    - `originMetadataURI`
    - `originMetadataHash`
    - `writtenBy`
    - `frozen`
  - Origin metadata updatable only by original writer until freeze
  - Origin metadata freeze independent from service record lifecycle
  - Issuer model:
    - contract owner (UP) authorizes dealers / concessionari
    - authorized issuer mints passport to first vehicle owner
  - Ownership model:
    - current token owner controls write authorizations
    - ownership transferable with native LSP8 transfer flow
  - Write authorization model:
    - `authorizationId` per authorization
    - category-scoped authorization
    - `OneShot` or `Reusable`
    - revocable by current owner
  - Automatic invalidation of old authorizations via:
    - `vehicleAuthorizationEpoch`
    - epoch increment on ownership transfer
  - Service record model:
    - one record per relevant intervention
    - operator creates record only after work completion
    - record includes:
      - `workStartedAt`
      - `workCompletedAt`
      - `odometerKm`
      - `recordURI`
      - `recordHash`
      - `category`
      - `cause`
    - records are created already frozen
  - Record cause model includes:
    - `Routine`
    - `Wear`
    - `Accident`
    - `Recall`
    - `InspectionOutcome`
    - `Diagnostic`
    - `Other`
  - Automatic system-generated `OwnershipTransfer` record on token transfer
  - Compatible with:
    - Universal Profile ownership / governance flows
    - standard EOA-compatible holding and transfer at token level
  - Designed for:
    - vehicle lifecycle traceability
    - owner-controlled third-party write access
    - hybrid on-chain / off-chain storage model
    - future UI-driven operational workflows

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



