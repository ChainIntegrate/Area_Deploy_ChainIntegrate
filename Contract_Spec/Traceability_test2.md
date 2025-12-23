# Traceability_test2 — Schema Dati e Scelte Architetturali

## Obiettivo del Contratto

Lo smart contract `Traceability_test2` gestisce **certificati digitali di conformità e tracciabilità** tramite token LSP8.

Il contratto **non archivia documenti o dati sensibili**, ma conserva:
- stato del certificato,
- riferimenti temporali,
- collegamenti tra versioni,
- impronte crittografiche (hash) dei dati off-chain.

Questo documento definisce **cosa è on-chain, cosa è off-chain e cosa è intenzionalmente oscurato**, per guidare le evoluzioni future del sistema.

---

## Classificazione dei Dati

Ogni dato gestito dal contratto rientra in una delle seguenti categorie:

1. **Dati in chiaro on-chain**
2. **Dati hashati (commitment crittografici)**
3. **Puntatori a contenuti off-chain**
4. **Metadati di contesto (LSP4 / ERC725Y)**

---

## 1. Dati in Chiaro On-chain

Questi dati sono **leggibili pubblicamente** e fanno parte dello stato logico del certificato.  
Sono considerati **non sensibili** e **necessari alla verifica**.

| Campo | Tipo | Motivazione |
|-----|----|------------|
| `status` | `CertStatus` | Stato legale del certificato |
| `issuedAt` | `uint256` | Data di emissione verificabile |
| `validUntil` | `uint256` | Data di scadenza verificabile |
| `tokenId` | `bytes32` | Identificatore del certificato |
| `ownerOf(tokenId)` | `address` | Titolare del certificato |
| `_supersededBy` | `bytes32` | Collegamento a versione successiva |
| `_supersedes` | `bytes32` | Collegamento a versione precedente |

**Nota:** questi dati sono destinati a rimanere **immutabili o monotonicamente evolutivi**.

---

## 2. Dati Hashati (Commitment Crittografici)

Questi campi contengono **solo hash**, mai dati leggibili.

Servono a:
- garantire integrità,
- proteggere informazioni sensibili,
- permettere verifiche off-chain.

| Campo | Tipo | Contenuto | In Chiaro? |
|-----|----|----------|-----------|
| `certificateId` | `bytes32` | Hash identificativo del certificato | ❌ |
| `companyIdHash` | `bytes32` | Hash ID azienda | ❌ |
| `batchIdHash` | `bytes32` | Hash lotto / batch | ❌ |
| `standardHash` | `bytes32` | Hash standard normativo | ❌ |
| `documentHash` | `bytes32` | Hash documento (PDF / JSON) | ❌ |

**Nota:** l’algoritmo di hashing (es. `keccak256`) è una scelta applicativa off-chain.

---

## 3. Puntatori a Contenuti Off-chain

Questi campi non contengono dati sensibili ma **riferimenti esterni**.

| Campo | Tipo | Descrizione | Rischio |
|-----|----|------------|--------|
| `documentURI` | `string` | URI del documento (IPFS / HTTPS) | Medio |

Linee guida:
- preferire URI content-addressed (`ipfs://`)
- l’integrità è garantita da `documentHash`
- l’URI può diventare **opzionale o eliminabile** in versioni future

---

## 4. Metadati di Contesto (LSP4 / ERC725Y)

I metadata non sono legati al singolo certificato, ma al **contratto / collezione**.

| Tipo | Dove | Mutabilità |
|----|-----|-----------|
| Nome, descrizione | ERC725Y | Mutabile fino a freeze |
| Metadata JSON LSP4 | ERC725Y | Mutabile fino a freeze |

Il freeze dei metadata è **definitivo**.

---

## Relazioni tra Dati

```text
[tokenId]
   │
   ├─ status (chiaro)
   ├─ issuedAt / validUntil (chiaro)
   ├─ certificateId (hash)
   ├─ documentHash (hash)
   ├─ documentURI (off-chain)
   │
   └─ supersession
        ├─ supersedes (old)
        └─ supersededBy (new)
