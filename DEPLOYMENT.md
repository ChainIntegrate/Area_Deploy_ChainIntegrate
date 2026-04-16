## LUKSO Testnet

---

### Condominium Registry

- **Contract:** `CondominiumRegistryLSP8`
- **Address:** `0x489F040770f099d48957F7065C88aC0cdB322a0C`
- **ChainId:** `4201`
- **Verified:** ✅ (Standard JSON Input)
- **Deployed:** `2026-04-16`
- **Owner (Admin):** Universal Profile  
  `0x83cBE526D949A3AaaB4EF9a03E48dd862e81472C`
- **Required Profile Interface:**  
  `0x629aa694` (ERC725Y – Universal Profile compatibility)
- **Authorized creators:**  
  Configurable via `setAuthorizedCreator(address,bool)` by the contract owner.

#### Notes

- **LSP8 Identifiable Digital Asset**
  - One token = one condominium.
  - `tokenId` is a `bytes32` identifier defined at mint time.
  - Token is minted directly to the condominium administrator Universal Profile.

- **Deployment and governance model**
  - Contract deployed by ChainIntegrate.
  - Contract ownership assigned to the ChainIntegrate Universal Profile.
  - Only addresses supporting the required ERC165 interface (`ERC725Y`) can act as:
    - condominium administrators
    - authorized creators
    - contractor profiles (if a wallet is provided)

- **Condominium identity model**
  - Each condominium stores:
    - `name`
    - `location`
    - `adminUP`
    - `createdAt`
    - `active` status
  - Administration can be transferred via `transferAdministration`, generating a system event.

- **Creator model**
  - Only **authorized creators** can mint new condominiums using `mintCondominium`.
  - Authorization is managed by the contract owner.
  - Minting assigns the LSP8 token directly to the administrator UP.

- **Resolutions (Delibere)**
  - Managed per condominium via `createResolution`.
  - Each resolution includes:
    - `category`
    - `title`
    - `approved` status
    - `dataURI` and `dataHash` for off-chain documentation
    - `createdBy` and `createdAt`
  - Supported `ResolutionCategory` values:
    - `Generic`
    - `OrdinaryWorks`
    - `ExtraordinaryWorks`
    - `Heating`
    - `AnnualBudget`
    - `HeatingBudget`
    - `Administrator`
    - `Regulation`
    - `Other`

- **Contractor model**
  - Contractors are globally registered by the contract owner.
  - Each contractor includes:
    - `name`
    - optional `walletUP` (must support the required profile interface)
    - `metadataURI`
    - `active` status
  - Contractors can be assigned to work items.

- **Work items**
  - Managed per condominium via `createWorkItem`.
  - Each work includes:
    - optional link to a `resolutionId`
    - optional `contractorId`
    - `title` and `category`
    - `WorkType` (`Generic` or `FixedTerm`)
    - `WorkStatus` lifecycle:
      - `Planned`
      - `Approved`
      - `InProgress`
      - `Completed`
      - `Closed`
      - `Suspended`
      - `Cancelled`
    - planned and actual start/end dates
  - Contractor assignment is handled via `assignContractorToWork`.
  - Status updates are managed through `updateWorkStatus`.

- **Registry events (chronological log)**
  - Every significant action generates a `RegistryEvent`, ensuring full traceability.
  - Events can be added manually via `addEvent` or automatically by the system.
  - Each event includes:
    - `eventType`
    - `timestamp`
    - `category` and `title`
    - optional links to `resolutionId` and `workId`
    - `dataURI` and `dataHash`
    - `createdBy`
  - Supported `EventType` values:
    - `AssembleaConvocata`
    - `VerbalePubblicato`
    - `DeliberaPubblicata`
    - `BilancioPubblicato`
    - `FornitoreSelezionato`
    - `LavoriAvviati`
    - `LavoriConclusi`
    - `ContestazioneAperta`
    - `ContestazioneChiusa`
    - `AmministratoreAggiornato`

- **Lifecycle management**
  - Condominiums can be activated or deactivated via `setCondominiumActive`.
  - Administrative changes and operational milestones are permanently recorded as events.

- **Access control model**
  - **Contract owner (UP):**
    - authorizes creators
    - manages contractor registry
  - **Authorized creators:**
    - mint new condominium tokens
  - **Condominium administrator (token owner):**
    - manages resolutions, works, and events
    - transfers administration

- **Data architecture**
  - Hybrid **on-chain/off-chain** model.
  - Legal and operational documents are stored off-chain and referenced via:
    - `dataURI`
    - `dataHash` (integrity verification)

- **Compatibility**
  - Fully compatible with:
    - Universal Profile ownership and governance flows
    - ERC165 interface detection
    - Standard LSP8 transfer mechanisms
    - EOA-compatible token holding and transfer

- **Designed for**
  - Digital identity of condominiums
  - Transparent governance and traceability
  - Lifecycle management of resolutions and works
  - Supplier and contractor accountability
  - Event-driven historical registry
  - Future UI-driven operational workflows

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



