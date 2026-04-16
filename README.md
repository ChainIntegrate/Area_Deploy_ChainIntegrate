# Compliance, Traceability & Asset Lifecycle – LUKSO

Repository di sviluppo per smart contract legati a **certificazione, tracciabilità e gestione del ciclo di vita degli asset reali** su blockchain **LUKSO**.

Il progetto utilizza gli standard **LSP (LUKSO Standard Proposals)** e segue un approccio incrementale:  
ogni contratto rappresenta un’evoluzione controllata di modelli on-chain orientati a:

- governance
- auditabilità
- privacy by design
- separazione dei ruoli
- integrazione con sistemi off-chain
- rappresentazione del **lifecycle di asset fisici**

---

## Scopo

Fornire una base tecnica per:

- emettere certificati e asset come **identità digitali verificabili**
- tracciare **eventi, stati e trasformazioni nel tempo**
- gestire **revoche, sostituzioni e versionamento**
- modellare **interazioni multi-attore su asset fisici**
- limitare l’esposizione dei dati sensibili on-chain
- separare chiaramente:
  - governance
  - emissione
  - operatività
  - detenzione

La blockchain viene utilizzata come **registro di verità e audit**, non come database applicativo.

---

## Asset Lifecycle Model

Con l’introduzione di VehiclePassport, il repository evolve da un insieme di contratti di certificazione a un modello più generale:

**asset-centric lifecycle tracking**

Pattern principali:

- 1 token = 1 asset fisico
- eventi rappresentati come **record append-only**
- controllo scrittura delegato dal proprietario
- separazione tra:
  - identità dell’asset
  - dati originari
  - eventi operativi
- invalidazione automatica dei permessi su cambio ownership
- integrazione nativa con:
  - sistemi off-chain (ERP, officine, supply chain)
  - UI operative

Questo pattern è riutilizzabile per:
- veicoli
- macchinari industriali
- componenti critici
- asset certificati lungo supply chain
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

### CondominiumRegistry

Sistema di identità, governance e tracciabilità del ciclo di vita dei condomini basato su standard LUKSO (LSP8).

Non è un semplice NFT descrittivo, ma un modello strutturato che rappresenta:

- identità del condominio
- amministrazione e governance
- storico verificabile delle delibere
- gestione dei lavori e dei fornitori
- registro cronologico degli eventi

Introduce:

- identificazione univoca del condominio tramite `tokenId` di tipo `bytes32`
- mint del token direttamente all’amministratore del condominio (Universal Profile)
- controllo dei creator autorizzati:
  - definiti dal contract owner (ChainIntegrate)
  - abilitati al mint di nuovi condomini
- modello di governance:
  - l’amministratore del condominio coincide con il proprietario del token LSP8
  - trasferimento dell’amministrazione tramite trasferimento del token
  - possibilità di attivare o disattivare il condominio
- sistema di gestione delle delibere:
  - una delibera per ogni decisione assembleare
  - classificazione tramite `ResolutionCategory`
  - documentazione gestita via `dataURI` + `dataHash`
  - tracciabilità di autore e timestamp
- gestione dei fornitori:
  - registro globale dei fornitori gestito dal contract owner
  - associazione dei fornitori ai lavori del condominio
  - supporto opzionale per wallet Universal Profile dei fornitori
- modello di gestione dei lavori:
  - un `WorkItem` per ogni intervento rilevante
  - collegamento opzionale a una delibera e a un fornitore
  - tipologie di lavoro:
    - `Generic`
    - `FixedTerm` con data di fine pianificata
  - ciclo di vita del lavoro:
    - `Planned`
    - `Approved`
    - `InProgress`
    - `Completed`
    - `Closed`
    - `Suspended`
    - `Cancelled`
  - gestione di date pianificate e reali (`planned` e `actual`)
- registro cronologico degli eventi:
  - ogni azione rilevante genera un `RegistryEvent`
  - eventi manuali o generati automaticamente dal sistema
  - collegamenti opzionali a delibere e lavori
  - principali tipologie di evento:
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
- modello ibrido:
  - on-chain → stato, relazioni e integrità dei dati
  - off-chain → contenuti estesi (documenti, verbali, bilanci, contratti, media)
- controllo degli accessi:
  - **ChainIntegrate (contract owner)**:
    - autorizza i creator
    - gestisce il registro dei fornitori
  - **Creator autorizzati**:
    - mintano nuovi condomini
  - **Amministratore (token owner)**:
    - gestisce delibere, lavori ed eventi
    - trasferisce l’amministrazione
- compatibilità:
  - Universal Profile (esperienza completa e governance avanzata)
  - account compatibili ERC725Y
  - interoperabilità con l’ecosistema LUKSO

Costituisce la base per un **registro digitale del condominio verificabile**, con governance trasparente, tracciabilità delle decisioni e piena auditabilità delle attività nel tempo.

---

### VehiclePassport

Sistema di certificazione e tracciabilità del ciclo di vita del veicolo basato su standard LUKSO (LSP8).

Non è un semplice NFT descrittivo, ma un modello strutturato che rappresenta:

- identità del veicolo
- ownership
- storico operativo verificabile

Introduce:

- identificazione univoca tramite VIN hashato (`tokenId`)
- metadata originari del veicolo:
  - gestiti via URI + hash
  - modificabili solo dall’issuer iniziale
  - congelabili (`freeze`) in modo definitivo
- separazione tra:
  - dati originari del veicolo (issuer-controlled)
  - record operativi append-only (operator-controlled)
- sistema di autorizzazioni dinamiche per la scrittura:
  - `OneShot` (una singola operazione)
  - `Reusable` (più operazioni)
- autorizzazioni:
  - concesse dal proprietario corrente
  - revocabili
  - invalidate automaticamente al cambio proprietà tramite `vehicleAuthorizationEpoch`
- modello record:
  - un record per intervento rilevante
  - creato dall’operatore a fine lavoro
  - immutabile (frozen at creation)
- struttura record:
  - `category` (MechanicalRepair, BodyRepair, ecc.)
  - `cause` (Accident, Wear, Routine, ecc.)
  - `workStartedAt`, `workCompletedAt`
  - `odometerKm`
  - `recordURI` (off-chain)
  - `recordHash` (integrità)
- generazione automatica del record:
  - `OwnershipTransfer` al trasferimento del token
- modello ibrido:
  - on-chain → stato, relazioni, integrità
  - off-chain → contenuto esteso (JSON, documenti, media)
- compatibilità:
  - Universal Profile (esperienza avanzata)
  - wallet EOA standard (interoperabilità)

Costituisce la base per un **libretto digitale del veicolo verificabile**, con controllo in capo al proprietario e piena auditabilità.


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

## Traceability & Conformity Evolution

### Traceability_test2

Iterazione architetturale avanzata del modello di certificazione e tracciabilità.

Non è un semplice prototipo sperimentale, ma una revisione strutturata che ha introdotto:

- gestione esplicita dello stato (`Valid / Revoked / Superseded`)
- grafo bidirezionale di supersessione
- separazione tra:
  - freeze dei dati di conformità
  - freeze dei metadata LSP4 / ERC725Y
- governance tramite Universal Profile

Il contratto è stato utilizzato per consolidare il modello lifecycle prima della standardizzazione definitiva nel dominio Compliance.

Dettagli di deploy e verifica: vedi `DEPLOYMENT.md`.  
Schema dati e scelte architetturali: vedi `Traceability_test2_spec.md`.

---

### OLD_Traceability_test1

Primo prototipo esplorativo del modello di tracciabilità.

Abbandonato in fase iniziale a seguito di criticità progettuali e ripensamento architetturale.

Mantenuto esclusivamente a scopo storico e comparativo.


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

