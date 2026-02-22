# BatteryCarbonCertificateLSP8 — Schema Dati e Scelte Architetturali
## Rev2 (con riferimento storico Rev1)

---

## Obiettivo del Contratto

Lo smart contract `BatteryCarbonCertificateLSP8` gestisce **certificati di Carbon Footprint** per lotti di batterie tramite token **LSP8**.

Ogni certificato è identificato da un `tokenId` deterministico:

- `tokenId = keccak256(lotCode)`

Il contratto è progettato per:

- coordinare **contributi multi-attore** (CAM, CELLS, LOGISTICS)
- garantire **integrità dei dati tramite digest crittografici**
- produrre un **aggregate finale verificabile**
- supportare **freeze granulari**
- mantenere una separazione chiara tra **on-chain (commitment)** e **off-chain (contenuto)**

---

## Evoluzione del Modello (Rev1 → Rev2)

### Rev1 (legacy — deprecata)

- Contributi firmati con **ECDSA**
- Verifica on-chain della firma
- Payload firmato con:
  - chainId
  - contract
  - tokenId
  - lot hash
  - role
  - URI hash
  - digest

**Obiettivo:** non ripudio forte lato applicativo

**Limiti:**
- alta complessità operativa
- UX più articolata
- gestione firme lato client
- ridondanza rispetto alla firma della transazione blockchain

---

### Rev2 (attuale)

- ❌ rimozione firma ECDSA applicativa  
- ✅ contributi via **JSON off-chain (URI)**  
- ✅ integrità tramite **digest (`bytes32`)**  
- ✅ attestazione tramite **transazione blockchain (`msg.sender`)**

**Principio chiave:**

> L’attore non firma un payload → firma la **transazione**.

---

### Motivazione della scelta Rev2

La rimozione della firma ECDSA **non è dovuta a limiti tecnici o semplificazione forzata**, ma a una scelta architetturale consapevole.

Nel modello adottato:

- l’utente si autentica tramite **Universal Profile (firma crittografica)**
- i ruoli sono definiti **on-chain dall’issuer**
- ogni operazione è una **transazione firmata su blockchain**

Questo rende la firma applicativa del payload:

> **ridondante rispetto alle garanzie già fornite dal sistema**

In particolare:

- **Autenticità** → garantita da `msg.sender`
- **Autorizzazione** → garantita da `actorByRole`
- **Non ripudio** → garantito dalla transazione blockchain
- **Integrità contenuto** → garantita dal `digest`

La firma ECDSA su payload duplicava queste proprietà senza aggiungere valore proporzionato alla complessità introdotta.

---

## Classificazione dei Dati

1. Dati in chiaro on-chain  
2. Dati hashati (commitment)  
3. Puntatori off-chain  
4. Metadati LSP4 / ERC725Y  

---

## 1. Dati in Chiaro On-chain

### Certificate

| Campo | Tipo | Descrizione |
|---|---|---|
| `issuer` | `address` | Emittente certificato |
| `lotCode` | `string` | Codice lotto |
| `productType` | `string` | Tipo prodotto |
| `scope` | `string` | Ambito |
| `period` | `string` | Periodo |
| `status` | `Status` | `Collecting / Frozen / Revoked` |
| `createdAt` | `uint64` | Timestamp |
| `metadataFrozen` | `bool` | Freeze metadata |

---

### Actors

| Campo | Tipo |
|---|---|
| `actorByRole[tokenId][role]` | `address` |

Ruoli:
- `ISSUER`
- `CAM`
- `CELLS`
- `LOGISTICS`

---

## 2. Dati Hashati

### Contribution

| Campo | Tipo | Descrizione |
|---|---|---|
| `digest` | `bytes32` | Hash del JSON contributo |

---

### Aggregate

| Campo | Tipo |
|---|---|
| `aggregateDigest[tokenId]` | `bytes32` |

---

## 3. Puntatori Off-chain

| Campo | Tipo | Descrizione |
|---|---|---|
| `_tokenURI[tokenId]` | `string` | Metadata certificato |
| `Contribution.uri` | `string` | JSON contributo |
| `aggregateURI[tokenId]` | `string` | Documento finale |

---

### Linee guida

- usare `ipfs://` quando possibile  
- URI modificabile solo in `Collecting`  
- il digest è la fonte di verità  

---

## 4. Metadati di Contesto (LSP4 / ERC725Y)

| Tipo | Mutabilità |
|---|---|
| Collection metadata | Governata da owner |
| Token metadata | Congelabile per token |

---

## Identità e Access Control

### Owner
- Universal Profile admin  
- gestisce allowlist issuer  

---

### Issuer

Può:
- mintare certificato  
- autorizzare attori  
- aggiornare URI  
- pubblicare aggregate  
- congelare certificato  
- revocare certificato  

---

### Actors

Possono:
- `submitContribution`
- `freezeContribution`

Vincolo:

```solidity
msg.sender == actorByRole[tokenId][role]
