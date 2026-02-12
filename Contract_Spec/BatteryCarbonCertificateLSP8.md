# BatteryCarbonCertificateLSP8 — Schema Dati e Scelte Architetturali

## Obiettivo del Contratto

Lo smart contract `BatteryCarbonCertificateLSP8` gestisce **certificati di Carbon Footprint** per lotti di batterie tramite token **LSP8**.

Ogni certificato è identificato da un `tokenId` deterministico:

- `tokenId = keccak256(lotCode)`

Il contratto è progettato per:
- **coordinare contributi multi-attore** (CAM, CELLS, LOGISTICS) su un singolo certificato,
- garantire integrità e non ripudio tramite **digest + firma ECDSA**,
- produrre un **aggregate digest/URI** finale,
- supportare freeze granulari (per contributi e per metadata token).

---

## Classificazione dei Dati

Ogni dato gestito dal contratto rientra in una delle seguenti categorie:

1. **Dati in chiaro on-chain**
2. **Dati hashati (commitment crittografici)**
3. **Puntatori a contenuti off-chain**
4. **Metadati di contesto (LSP4 / ERC725Y)**

---

## 1. Dati in Chiaro On-chain

Questi dati sono **leggibili pubblicamente** e fanno parte della logica del certificato.
Sono considerati necessari per governare il lifecycle e per la verifica.

### Certificate (per tokenId)

| Campo | Tipo | Motivazione |
|---|---|---|
| `issuer` | `address` | Identità del soggetto emittente (account allowlisted) |
| `lotCode` | `string` | Codice lotto in chiaro per UX/operatività |
| `productType` | `string` | Categoria/prodotto (non sensibile, utile per consultazione) |
| `scope` | `string` | Ambito / perimetro (utile per audit) |
| `period` | `string` | Periodo di riferimento (utile per audit) |
| `status` | `Status` | Stato del certificato: `Collecting/Frozen/Revoked` |
| `createdAt` | `uint64` | Timestamp creazione certificato |
| `metadataFrozen` | `bool` | Freeze per tokenURI metadata |

### Actors (autorizzazioni)

| Campo | Tipo | Dove | Motivazione |
|---|---|---|---|
| `actorByRole[tokenId][role]` | `address` | mapping | Autorizza l’attore per quel ruolo sul token |

Ruoli previsti:
- `ISSUER` (sempre l’emittente)
- `CAM`
- `CELLS`
- `LOGISTICS`

**Nota:** l’issuer può autorizzare solo ruoli ≠ `ISSUER`.

---

## 2. Dati Hashati (Commitment Crittografici)

Questi campi contengono **hash/digest**, mai dati completi.  
Servono a garantire integrità e verificabilità dei documenti off-chain.

### Contribution (per tokenId + role)

| Campo | Tipo | Contenuto | In Chiaro? |
|---|---|---|---|
| `digest` | `bytes32` | Hash del contenuto (PDF/JSON/CSV/etc.) | ❌ |
| `signature` | `bytes` | Firma ECDSA sul payload | ❌ (è pubblica ma non “leggibile” come testo) |

### Aggregate

| Campo | Tipo | Contenuto | In Chiaro? |
|---|---|---|---|
| `aggregateDigest[tokenId]` | `bytes32` | Hash del pacchetto finale aggregato | ❌ |

---

## 3. Puntatori a Contenuti Off-chain

Questi campi sono riferimenti esterni. L’integrità è garantita dai digest.

| Campo | Tipo | Descrizione | Rischio |
|---|---|---|---|
| `_tokenURI[tokenId]` | `string` | Token URI del certificato (metadati documento) | Medio |
| `Contribution.uri` | `string` | URI del contributo per ruolo | Medio |
| `aggregateURI[tokenId]` | `string` | URI dell’aggregato finale | Medio |

Linee guida:
- preferire URI content-addressed (`ipfs://`) o gateway controllati
- la **fonte** può sparire, ma la **prova di integrità** resta via digest
- l’URI è modificabile solo finché lo stato è `Collecting`

---

## 4. Metadati di Contesto (LSP4 / ERC725Y)

Essendo LSP8, il contratto usa anche i metadata di collezione (LSP4 / ERC725Y) tramite il parent.

| Tipo | Dove | Mutabilità |
|---|---|---|
| Nome, simbolo, metadata LSP4 | ERC725Y | mutabile secondo il parent / owner |
| TokenURI per token (`_tokenURI`) | storage contract | congelabile **per token** |

Nel design attuale:
- esiste un **freeze per token metadata** (`freezeTokenMetadata`)
- non c’è un freeze globale del contratto in questo snippet (dipende dal parent e da come lo gestisci a livello governance)

---

## Identità e Access Control

### Owner (governance)
- L’owner del contratto è un **Universal Profile admin** (immutabile in constructor).
- L’owner gestisce l’allowlist:
  - `setIssuerAllowed`
  - `setIssuersAllowed`
- La governance passa via `onlyOwner` (es. `UP.execute`).

### Issuer (lifecycle operativo)
- L’issuer è l’account che ha mintato quel certificato.
- Solo l’issuer può:
  - autorizzare attori (`authorizeActor`)
  - pubblicare aggregate (`publishAggregate`)
  - aggiornare tokenURI (`setTokenURI`)
  - congelare metadata token (`freezeTokenMetadata`)
  - congelare certificato (`freezeCertificate`)
  - revocare (`revokeCertificate`)

### Actors (contributori)
- Un actor può:
  - inviare contributo per il proprio ruolo (`submitContribution`)
  - congelare il proprio contributo (`freezeContribution`)
- L’actor è valido solo se:
  - è stato autorizzato dall’issuer
  - `msg.sender == actorByRole[tokenId][role]`

---

## Lifecycle e Stati

### Status (certificate)
- `Collecting`: fase di raccolta contributi + modifiche possibili
- `Frozen`: certificato chiuso, tutti i contributi congelati + aggregate presente
- `Revoked`: certificato revocato dall’issuer (stato terminale)

### Condizioni per passare a `Frozen`
`freezeCertificate(tokenId)` richiede:
- contributo CAM frozen
- contributo CELLS frozen
- contributo LOGISTICS frozen
- `aggregateDigest != 0`

Se uno di questi manca → revert `InvalidStatus()`.

---

## Firma ECDSA dei Contributi

Ogni contributo include:
- `uri`
- `digest`
- `signature`

La signature è verificata on-chain con:

- `payloadHash = keccak256(abi.encodePacked(...))`
- `recovered = payloadHash.toEthSignedMessageHash().recover(signature)`
- deve combaciare con `actor`

Il payload lega la firma a:
- chain id (`block.chainid`)
- contract address (`address(this)`)
- tokenId
- hash del lotCode (`keccak256(bytes(lot))`)
- role
- hash uri (`keccak256(bytes(uri))`)
- digest

Questo impedisce riuso della firma su:
- altre chain
- altri contratti
- altri tokenId
- altri ruoli
- altri URI/digest

---

## Relazioni tra Dati

```text
[tokenId = keccak256(lotCode)]
  │
  ├─ Certificate (issuer, lotCode, productType, scope, period, status, createdAt, metadataFrozen)
  │
  ├─ Actor authorization
  │    ├─ role CAM -> address
  │    ├─ role CELLS -> address
  │    └─ role LOGISTICS -> address
  │
  ├─ Contributions (per role)
  │    ├─ uri (off-chain)
  │    ├─ digest (hash)
  │    ├─ signature (ECDSA)
  │    └─ frozen / frozenAt
  │
  └─ Aggregate
       ├─ aggregateURI (off-chain)
       └─ aggregateDigest (hash)
