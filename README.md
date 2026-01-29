# Compliance & Traceability Assets – LUKSO

Repository di sviluppo per smart contract e test legati a **certificazione, tracciabilità e valutazione qualitativa** su blockchain **LUKSO**.

Il progetto utilizza gli standard **LSP (LUKSO Standard Proposals)** e segue un approccio incrementale:  
ogni contratto rappresenta un’evoluzione controllata di modelli on-chain orientati a:

- governance
- auditabilità
- privacy by design
- separazione dei ruoli
- integrazione con sistemi off-chain

---

## Scopo

Fornire una base tecnica per:

- emettere certificati come **asset digitali identificabili**
- verificare autenticità, stato e validità dei certificati
- gestire **revoche, sostituzioni e versionamento**
- rappresentare **valutazioni qualitative strutturate**
- limitare l’esposizione dei dati sensibili on-chain
- separare chiaramente **governance**, **emissione** e **detenzione**

La blockchain viene utilizzata come **registro di verifica e audit**, non come database applicativo.

---

## Approccio

- Smart contract **LSP8 (Identifiable Digital Asset)**
- Stato e timeline on-chain
- Identità e dati sensibili gestiti **off-chain**
- Riferimenti on-chain tramite **hash crittografici**
- Logica applicativa e UI off-chain
- Governance basata su **Universal Profile (UP)**

---

## Contratti nel repository

---

## Compliance Certificates

### Contratto operativo

- **ComplianceCertificateLSP8REV2**

Contratto di riferimento per l’uso operativo nel dominio della **certificazione di conformità**.

Introduce:
- freeze dei metadati **per singolo token**
- stato **Revoked** terminale (non reversibile)
- supporto a **Superseded** per versionamento dei certificati
- separazione tra:
  - metadati del certificato (bloccabili)
  - stato legale del certificato (sempre tracciabile)
- freeze indipendente dei metadati di collezione (LSP4 / ERC725Y)

Dettagli di deploy e verifica: vedi `DEPLOYMENT.md`.

---

### Versione precedente

- **ComplianceCertificateLSP8 (REV1)**

Prima versione operativa del modello di certificazione.  
Mantenuta per compatibilità e tracciabilità storica, ma **non più usata come standard**.

---

## Battery Carbon Certificates

### Contratto operativo

- **BatteryCarbonCertificateLSP8**

Contratto LSP8 dedicato all’emissione di **certificati di impronta carbonica per batterie**.

Caratteristiche principali:
- 1 token = 1 certificato di lotto
- `tokenId` derivato da `keccak256(lotCode)`
- metadati del certificato aggiornabili fino a freeze
- stato del certificato tracciato on-chain
- modello multi-attore (issuer, fornitori, logistica, ecc.)

### Modello di emissione e sicurezza

- l’emissione dei certificati è **vincolata a una allowlist**
- solo gli **issuer autorizzati** possono mintare nuovi certificati
- la allowlist è:
  - on-chain
  - gestita esclusivamente dal **proprietario del contratto**
  - amministrata tramite **Universal Profile (UP)**

Questo consente di separare in modo netto:
- **governance del contratto** (UP admin)
- **soggetti autorizzati all’emissione**
- **detentori finali dei certificati**

Dettagli di deploy e verifica: vedi `DEPLOYMENT.md`.

---

## Supplier Quality Evaluations

### Contratto operativo

- **SupplierQualityLSP8**

Contratto LSP8 dedicato alla **valutazione qualitativa periodica dei fornitori**.

Caratteristiche principali:
- 1 token = 1 fornitore
- `tokenId = keccak256("SUP:" + supplierRef)`
- valutazioni **append-only** (es. semestrali)
- punteggi strutturati su più criteri:
  - puntualità
  - qualità
  - documentazione
  - reattività
- calcolo on-chain di:
  - ultimo punteggio
  - media storica
- identità del fornitore risolta **off-chain** tramite hash mapping
- nessun dato sensibile in chiaro on-chain

### Ruoli e governance

- **Owner (UP)**: amministrazione del contratto
- **Quality Office**: mint dei fornitori e inserimento valutazioni
- **Fornitori**: detentori dei token (read-only)

Il contratto è progettato per integrazione diretta con UI di verifica e dashboard di audit.

Dettagli di deploy e verifica: vedi `DEPLOYMENT.md`.  
Schema dati e scelte architetturali: vedi `contract_spec.md`.

---

## Test e prototipi

- **Traceability_test2**

Iterazione di test del modello di tracciabilità e certificazione.  
Utilizzato per validare:
- struttura dei dati
- gestione dello stato
- meccanismi di revoca e supersessione

- **OLD_Traceability_test1**

Primo prototipo sperimentale.  
Abbandonato in fase iniziale a seguito di criticità progettuali.  
Non fa parte del modello attuale.

Questi contratti sono mantenuti **a scopo storico e di confronto**, non per uso operativo.

---

## Stato del progetto

- ✔️ Compliance Certificates REV2 deployato e verificato su LUKSO Testnet
- ✔️ Battery Carbon Certificate deployato e verificato su LUKSO Testnet
- ✔️ Supplier Quality Evaluations deployato e verificato su LUKSO Testnet
- ✔️ Governance basata su Universal Profile
- ✔️ Emissione controllata tramite allowlist / ruoli
- ✔️ Architettura orientata a privacy, auditabilità e antifalsificazione
- ✔️ Base pronta per integrazione UI e sistemi aziendali

---

## Struttura del repository

```text
contracts/
  ComplianceCertificate_Rev2.sol
  ComplianceCertificateLSP8.sol
  BatteryCarbonCertificateLSP8.sol
  SupplierQualityLSP8.sol
  Traceability_test2.sol
  OLD_Traceability_test1.sol

scripts/
  deploy_ComplianceCertificateLSP8.js
  deploy-rev2.js
  deploy_battery_allowlist_testnet.js
  deploySupplierQualityLSP8.js
  allow_issuer_via_up_execute.js

DEPLOYMENT.md
contract_spec.md
README.md
