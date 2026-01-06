# Compliance Certificates – LUKSO

Repository di sviluppo per smart contract e test legati alla **certificazione di conformità su blockchain LUKSO**.

Il progetto utilizza gli standard **LSP (LUKSO Standard Proposals)** e segue un approccio incrementale: ogni contratto rappresenta un’evoluzione o una sperimentazione del modello.

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

### Contratto attuale
- **ComplianceCertificateLSP8**  
  Contratto principale, progettato per l’uso operativo e per successive evoluzioni.

Dettagli di deploy e verifica: vedi `DEPLOYMENT.md`.

---

### Test e prototipi precedenti

- **Traceability_test2**  
  Seconda iterazione di test del modello di tracciabilità e certificazione.  
  Utilizzato per validare:
  - struttura dei dati
  - gestione dello stato
  - meccanismi di revoca e supersessione

- **OLD_Traceability_test1**  
  Primo prototipo sperimentale.  
  Abbandonato in fase iniziale a seguito di criticità progettuali.  
  Non è considerato parte del modello attuale.
Questi contratti sono mantenuti nel repository **a scopo storico e di confronto**, non per uso operativo.

---

## Stato del progetto

- ✔️ Contratto operativo deployato e verificato su LUKSO testnet
- ✔️ Architettura orientata a privacy e verificabilità
- ✔️ Base pronta per estensioni future

---

## Struttura

```text
contracts/
  ComplianceCertificateLSP8.sol
  Traceability_test2.sol
  OLD_Traceability_test1.sol

scripts/
  deploy_ComplianceCertificateLSP8.js

DEPLOYMENT.md
README.md
