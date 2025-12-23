# Contract Spec — ComplianceCertificateLSP8 (LUKSO / LSP8)

> **Scopo**: smart contract per la gestione di **certificati di conformità/verifica** come token **LSP8** su LUKSO.  
> **Privacy**: i dati identificativi e descrittivi sono salvati **solo come hash (`bytes32`) calcolati off-chain con pepper segreto**.  
> **Verifica antifalsificazione**: il contratto ancora l’autenticità del documento tramite `documentHash`.

---

## 1) Obiettivi di progetto

- Fornire un **registro pubblico verificabile** di certificati (esistenza, stato, timeline).
- Permettere la **verifica di autenticità** di un PDF/JSON tramite confronto hash.
- Limitare l’esposizione dati: on-chain solo **hash con pepper** + pochi campi in chiaro necessari.
- Gestire **revoca** e **sostituzione** (supersession/versioning).
- Supportare metadata LSP4 su ERC725Y con possibilità di **freeze**.

---

## 2) Standard e dipendenze

- **Rete**: LUKSO
- **Token standard**: `LSP8IdentifiableDigitalAsset`
- **Estensione**: `LSP8Burnable`
- **Metadata standard**: LSP4 (via ERC725Y / `_setData`)
- **Solidity**: `^0.8.22`

---

## 3) Modello di sicurezza e privacy

### 3.1 Dati in chiaro vs hashati

**In chiaro on-chain (pubblici):**
- `inspectionDate` (timestamp data esecuzione verifica)
- `outcome` (esito verifica, enum)
- `validUntil` (timestamp scadenza)
- `issuedAt` (timestamp emissione = `block.timestamp` al mint)
- `status` (Valid/Revoked/Superseded)

**Hashati on-chain (non leggibili senza pepper):**
- Nome Azienda
- Partita IVA
- Codice Fiscale
- Nr certificato
- Tipologia certificato
- Tipologia bene certificato
- Modello
- Matricola
- Anno di costruzione
- Normativa di riferimento
- Riferimento verbale verifica
- Responsabile tecnico

**Ancora documento (hash):**
- `documentHash` (hash del PDF/JSON)

> Nota: gli hash dei campi “hashati” sono **pre-calcolati off-chain** usando un **pepper segreto** (non presente nel codice, non on-chain).

---

### 3.2 Pepper: definizione e responsabilità

- **Pepper** = segreto server-side (per cliente/azienda o globale per tenant).
- Non deve mai finire in:
  - JS pubblico
  - repository
  - storage on-chain
- Il frontend invia al backend i dati in chiaro, il backend:
  - normalizza
  - calcola `keccak256(pepper || field_normalized)`
  - ritorna `bytes32` da scrivere on-chain

---

## 4) Concetti chiave

### 4.1 Token = Certificato

Ogni `tokenId (bytes32)` identifica un certificato univoco.

### 4.2 Ciclo di vita del certificato

```solidity
enum CertStatus { Valid, Revoked, Superseded }
