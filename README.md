# Compliance Certificates – LUKSO

Repository di sviluppo per smart contract e test legati alla **certificazione di conformità su blockchain LUKSO**.

Il progetto utilizza gli standard **LSP (LUKSO Standard Proposals)** e segue un approccio incrementale: ogni contratto rappresenta un’evoluzione controllata del modello di certificazione.

---

## Scopo

Fornire una base tecnica per:
- emettere certificati come asset digitali identificabili
- verificare l’autenticità dei documenti associati
- gestire revoche e sostituzioni
- limitare l’esposizione dei dati on-chain

La blockchain viene usata come **registro di verifica**, non come database.

---

## Approccio

- Smart contract **LSP8** per rappresentare certificati
- Stato e timeline on-chain
- Dati identificativi salvati solo come hash
- Hash dei documenti per antifalsificazione
- Logica applicativa e dati in chiaro gestiti off-chain

---

## Contratti nel repository

### Contratto operativo

- **ComplianceCertificateLSP8REV2**

Contratto di riferimento per l’uso operativo.  
Introduce:
- freeze dei metadati **per singolo token**
- stato **Revoked** terminale (non reversibile)
- supporto a **Superseded** per versionamento dei certificati
- separazione tra:
  - metadati del certificato (bloccabili)
  - stato legale del certificato (sempre tracciabile)

Dettagli di deploy e verifica: vedi `DEPLOYMENT.md`.

---

### Versione precedente

- **ComplianceCertificateLSP8 (REV1)**  
Prima versione operativa del modello.  
Mantenuta per compatibilità e tracciabilità storica, ma **non più usata come standard**.

---

### Test e prototipi

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

- ✔️ Contratto REV2 deployato e verificato su LUKSO Testnet
- ✔️ Modello di certificazione con stati legali on-chain
- ✔️ Architettura orientata a privacy, auditabilità e antifalsificazione
- ✔️ Base pronta per integrazione UI e sistemi aziendali

---

## Struttura

```text
contracts/
  ComplianceCertificate_Rev2.sol
  ComplianceCertificateLSP8.sol
  Traceability_test2.sol
  OLD_Traceability_test1.sol

scripts/
  deploy_ComplianceCertificateLSP8.js
  deploy-rev2.js

DEPLOYMENT.md
README.md
