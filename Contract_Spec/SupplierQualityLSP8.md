# SupplierQualityLSP8 — Schema Dati e Scelte Architetturali

## Obiettivo del Contratto

Lo smart contract `SupplierQualityLSP8` gestisce **valutazioni qualitative dei fornitori** tramite token **LSP8 Identifiable Digital Asset**.

Ogni fornitore è rappresentato da **un token univoco**, identificato da un `tokenId` (`bytes32`), al quale vengono associate **valutazioni periodiche append-only** (es. semestrali).

Il contratto **non archivia dati sensibili o identificativi reali**, ma conserva:
- punteggi strutturati,
- riferimenti temporali,
- statistiche aggregate,
- identificativi hashati.

Questo documento definisce **cosa è on-chain, cosa è off-chain e cosa è intenzionalmente offuscato**, per garantire **trasparenza, privacy e verificabilità**.

---

## Classificazione dei Dati

Ogni dato gestito dal contratto rientra in una delle seguenti categorie:

1. **Dati in chiaro on-chain**
2. **Dati hashati (commitment crittografici)**
3. **Dati opzionali di supporto UI**
4. **Metadati di contesto (LSP4 / ERC725Y)**

---

## 1. Dati in Chiaro On-chain

Questi dati sono **leggibili pubblicamente** e rappresentano lo **stato logico delle valutazioni**.  
Sono considerati **non sensibili** e **necessari alla verifica oggettiva**.

### Identità del fornitore (token-level)

| Campo | Tipo | Motivazione |
|-----|----|------------|
| `tokenId` | `bytes32` | Identificatore stabile del fornitore |
| `ownerOf(tokenId)` | `address` | Wallet del fornitore |
| `createdAt` | `uint64` | Data di creazione del fornitore |
| `supplierRef` | `bytes32` | Riferimento interno hashato |
| `exists` | `bool` | Validità del token |

### Valutazioni periodiche

Ogni valutazione è **immutabile e append-only**.

| Campo | Tipo | Descrizione |
|-----|----|------------|
| `period` | `uint32` | Periodo valutazione (es. `20261` = H1 2026) |
| `createdAt` | `uint64` | Timestamp di consolidamento |
| `scores.punctuality` | `enum Level` | Puntualità |
| `scores.quality` | `enum Level` | Qualità |
| `scores.documentation` | `enum Level` | Documentazione |
| `scores.reactivity` | `enum Level` | Reattività |
| `overall` | `uint16` | Punteggio pesato (0–1000) |
| `note` | `string` | Nota descrittiva (≤150 bytes) |

### Statistiche aggregate

Calcolate **on-chain in O(1)** per facilitare UI e query.

| Campo | Tipo | Descrizione |
|-----|----|------------|
| `currentOverall` | `uint16` | Ultima valutazione |
| `sumOverall` | `uint64` | Somma storica |
| `count` | `uint32` | Numero valutazioni |
| `lastPeriod` | `uint32` | Ultimo periodo valutato |

**Nota:** le statistiche sono derivate esclusivamente da dati immutabili.

---

## 2. Dati Hashati (Commitment Crittografici)

Questi campi contengono **solo hash**, mai dati leggibili.  
Servono a garantire **privacy, integrità e disaccoppiamento identità ↔ blockchain**.

| Campo | Tipo | Contenuto | In chiaro? |
|-----|----|----------|-----------|
| `tokenId` | `bytes32` | Hash del fornitore | ❌ |
| `supplierRef` | `bytes32` | Hash riferimento interno | ❌ |

### Linee guida hashing
- algoritmo: `keccak256`
- input: stringhe normalizzate (`SUP:ACME-001`)
- **pepper segreto off-chain** (server / UQ)
- mapping hash ↔ fornitore **mai on-chain**

---

## 3. Dati Opzionali di Supporto UI

Questi dati **non sono necessari alla sicurezza**, ma facilitano demo, test e interfacce.

| Campo | Tipo | Uso | Sensibilità |
|-----|----|----|------------|
| `name` | `string` | Etichetta UI | Bassa |

**Nota:**  
Il campo `name` può essere:
- rimosso in versioni future
- reso opzionale
- popolato solo in ambienti demo

---

## 4. Metadati di Contesto (LSP4 / ERC725Y)

I metadata non appartengono al singolo fornitore, ma alla **collezione di token**.

| Tipo | Dove | Mutabilità |
|----|-----|-----------|
| Nome, simbolo | ERC725Y | Mutabile |
| Tipo token (NFT) | ERC725Y | Immutabile |
| TokenId format (HASH) | ERC725Y | Immutabile |

Il formato `HASH` è **definitivo** e garantisce coerenza del sistema.

---

## Controllo degli Accessi

| Ruolo | Permessi |
|----|---------|
| `owner` | Amministrazione |
| `qualityOffice` | Mint + valutazioni |
| Fornitore | Lettura |

Le funzioni critiche sono protette da `onlyQualityOffice`.

---

## Relazioni tra Dati

```text
[tokenId (bytes32)]
   │
   ├─ supplierRef (hash)
   ├─ owner (wallet fornitore)
   ├─ stats
   │    ├─ currentOverall
   │    ├─ avgOverall
   │    └─ count
   │
   └─ evaluations[]
        ├─ period
        ├─ scores (4 criteri)
        ├─ overall
        └─ note
