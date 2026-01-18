# Compliance Certificates – LUKSO

Repository di sviluppo per smart contract e test legati alla **certificazione di conformità e tracciabilità su blockchain LUKSO**.

Il progetto utilizza gli standard **LSP (LUKSO Standard Proposals)** e segue un approccio incrementale:  
ogni contratto rappresenta un’evoluzione controllata del modello di certificazione, con particolare attenzione a:

- governance
- auditabilità
- privacy
- separazione dei ruoli

---

## Scopo

Fornire una base tecnica per:

- emettere certificati come asset digitali identificabili
- verificare l’autenticità dei documenti associati
- gestire revoche e sostituzioni
- limitare l’esposizione dei dati on-chain
- separare chiaramente **governance**, **emissione** e **detenzione** dei certificati

La blockchain viene usata come **registro di verifica**, non come database.

---

## Approccio

- Smart contract **LSP8** per rappresentare certificati
- Stato e timeline on-chain
- Dati identificativi salvati solo come hash
- Hash dei documenti per antifalsificazione
- Logica applicativa e dati in chiaro gestiti off-chain
- Governance basata su **Universal Profile (UP)**

---

## Contratti nel repository

---

## Compliance Certificates

### Contratto operativo

- **ComplianceCertificateLSP8REV2**

Contratto di riferimento per l’uso operativo nel dominio della certificazione di conformità.

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

L’issuer può essere:
- un Universal Profile
- un EOA

La governance non dipende dal wallet che firma, ma dal controllo dell’UP.

Dettagli di deploy e verifica: vedi `DEPLOYMENT.md`.

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

- ✔️ Contratto Compliance REV2 deployato e verificato su LUKSO Testnet
- ✔️ Contratto Battery Carbon Certificate deployato e verificato su LUKSO Testnet
- ✔️ Modello di governance basato su Universal Profile
- ✔️ Emissione controllata tramite allowlist on-chain
- ✔️ Architettura orientata a privacy, auditabilità e antifalsificazione
- ✔️ Base pronta per integrazione UI e sistemi aziendali

---

## Struttura del repository

```text
contracts/
  ComplianceCertificate_Rev2.sol
  ComplianceCertificateLSP8.sol
  BatteryCarbonCertificateLSP8.sol
  Traceability_test2.sol
  OLD_Traceability_test1.sol

scripts/
  deploy_ComplianceCertificateLSP8.js
  deploy-rev2.js
  deploy_battery_allowlist_testnet.js
  allow_issuer_via_up_execute.js // script per il set di allow di BatteryCarbonCertificate

DEPLOYMENT.md
README.md
