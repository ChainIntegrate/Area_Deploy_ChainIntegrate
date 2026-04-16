# Condominium Registry System

## Overview

Il **Condominium Registry System** è un sistema basato su **LUKSO LSP8** per rappresentare un condominio come un token digitale unico e tracciabile nel tempo.

Ogni condominio è rappresentato da un **Condominium Token** che contiene:

- identità univoca del condominio
- amministratore associato
- storico delle delibere
- gestione dei lavori e dei fornitori
- registro cronologico degli eventi amministrativi e tecnici

Il sistema è progettato per l’ecosistema **LUKSO / Universal Profile**, garantendo che i ruoli operativi siano gestiti da account compatibili con gli standard LUKSO.

---

## Standard utilizzato

Il contratto utilizza:

- **LSP8 Identifiable Digital Asset** come standard per il token NFT del condominio
- **tokenId di tipo bytes32**
- metadata del condominio gestiti tramite URI e hash
- verifica dei profili tramite **ERC165** e interfaccia **ERC725Y**
- logica custom per:
  - gestione amministratori
  - delibere assembleari
  - lavori e fornitori
  - registro cronologico degli eventi

---

## Identità del condominio

### Token = 1 condominio

Ogni condominio corrisponde a **un solo token**.

### Token ID

Il `tokenId` è un identificativo `bytes32` definito al momento del mint. Può essere generato off-chain in modo deterministico (ad esempio tramite hash di un identificativo amministrativo).

Esempio concettuale:

```solidity
tokenId = keccak256(abi.encodePacked(condominiumIdentifier))
```

Questo garantisce l’univocità del condominio all’interno del sistema.

---

## Ruoli del sistema

### 1. ChainIntegrate

ChainIntegrate è l’**admin del contratto**.

Ha il compito di:

- deployare il contratto
- autorizzare i creator che possono mintare nuovi condomini
- registrare e gestire i fornitori
- revocare autorizzazioni operative

ChainIntegrate **non gestisce direttamente le attività operative del condominio**, che sono di competenza dell’amministratore.

---

### 2. Creator autorizzato

Il creator è il soggetto autorizzato a creare nuovi condomini.

Può:

- mintare un nuovo token LSP8 che rappresenta un condominio
- assegnare il token all’amministratore del condominio

Il creator può operare solo se autorizzato da ChainIntegrate tramite `setAuthorizedCreator`.

---

### 3. Amministratore del condominio

L’amministratore è il **current owner del token LSP8**.

Può:

- gestire le delibere assembleari
- creare e aggiornare i lavori
- assegnare i fornitori ai lavori
- registrare eventi amministrativi e tecnici
- trasferire l’amministrazione a un nuovo amministratore
- attivare o disattivare il condominio

L’amministratore deve essere un **Universal Profile** o un account che supporta l’interfaccia ERC725Y.

---

### 4. Fornitore

Il fornitore è un soggetto esterno che può essere coinvolto nei lavori del condominio.

Esempi:

- impresa edile
- manutentore impianti
- ditta di pulizie
- amministratore energetico
- tecnico specializzato

Il fornitore può essere registrato globalmente dal contract owner e successivamente associato ai lavori.

---

## Architettura generale

### Collection unica

Il sistema è costruito come:

- **1 contratto LSP8**
- **molti token**
- **1 token per ogni condominio**

Il contratto non crea un contratto separato per ogni condominio.

---

## Dati del condominio

Per ogni condominio vengono salvati:

- `tokenId`
- `adminUP`
- `name`
- `location`
- `createdAt`
- `active`

### Significato

- `adminUP`: amministratore del condominio
- `name`: denominazione del condominio
- `location`: ubicazione
- `createdAt`: timestamp di creazione
- `active`: stato operativo del condominio

### Trasferimento dell’amministrazione

L’amministrazione può essere trasferita tramite `transferAdministration`, generando automaticamente un evento di sistema.

---

## Delibere assembleari

Le delibere sono gestite per ogni condominio tramite `createResolution`.

### Struttura logica di una delibera

Ogni delibera contiene:

- `resolutionId`
- `tokenId`
- `category`
- `title`
- `createdAt`
- `approved`
- `dataURI`
- `dataHash`
- `createdBy`

### Categorie di delibera

Le categorie previste sono:

- `Generic`
- `OrdinaryWorks`
- `ExtraordinaryWorks`
- `Heating`
- `AnnualBudget`
- `HeatingBudget`
- `Administrator`
- `Regulation`
- `Other`

### Perché usare URI + hash

Il sistema salva:

- un **URI**
- un **hash verificabile**

Questo approccio consente:

- costi on-chain contenuti
- maggiore flessibilità dei dati
- verifica di integrità del contenuto off-chain
- compatibilità con documenti legali e amministrativi

---

## Gestione dei fornitori

I fornitori sono registrati globalmente dal contract owner.

### Struttura logica di un fornitore

Ogni fornitore contiene:

- `contractorId`
- `name`
- `walletUP` (opzionale)
- `metadataURI`
- `createdAt`
- `active`

I fornitori possono essere successivamente associati ai lavori del condominio.

---

## Gestione dei lavori

Ogni intervento sul condominio è rappresentato come un **Work Item**.

### Struttura logica di un lavoro

Ogni lavoro contiene:

- `workId`
- `tokenId`
- `resolutionId` (opzionale)
- `contractorId` (opzionale)
- `title`
- `category`
- `workType`
- `status`
- `createdAt`
- `plannedStartDate`
- `plannedEndDate`
- `actualStartDate`
- `actualEndDate`

### Tipologie di lavoro

- `Generic`
- `FixedTerm` (richiede una data di fine pianificata)

### Stati del lavoro

- `Planned`
- `Approved`
- `InProgress`
- `Completed`
- `Closed`
- `Suspended`
- `Cancelled`

### Assegnazione del fornitore

L’associazione tra lavoro e fornitore avviene tramite `assignContractorToWork`.

---

## Registro cronologico degli eventi

Ogni azione rilevante genera un **Registry Event**, garantendo la tracciabilità completa della vita del condominio.

### Struttura logica di un evento

Ogni evento contiene:

- `eventId`
- `tokenId`
- `relatedResolutionId`
- `relatedWorkId`
- `eventType`
- `timestamp`
- `category`
- `title`
- `dataURI`
- `dataHash`
- `createdBy`

### Tipologie di evento

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

Gli eventi possono essere creati manualmente dall’amministratore o automaticamente dal contratto.

---

## Lifecycle del condominio

### Fase 1 - Setup piattaforma

1. ChainIntegrate deploya il contratto.
2. ChainIntegrate autorizza uno o più creator.

### Fase 2 - Creazione del condominio

1. Il creator autorizzato minta il token LSP8.
2. Il token viene assegnato all’amministratore del condominio.
3. Vengono registrati nome e ubicazione.

### Fase 3 - Gestione operativa

1. L’amministratore crea le delibere.
2. Vengono pianificati i lavori.
3. I fornitori vengono assegnati.
4. Gli stati dei lavori vengono aggiornati.
5. Gli eventi vengono registrati nel tempo.

### Fase 4 - Trasferimento dell’amministrazione

1. L’amministratore trasferisce il token a un nuovo amministratore.
2. Il contratto registra automaticamente l’evento `AmministratoreAggiornato`.

### Fase 5 - Disattivazione del condominio

L’amministratore può impostare lo stato del condominio come inattivo tramite `setCondominiumActive`.

---

## Wallet supportati

Il contratto è progettato per funzionare con:

- **Universal Profile LUKSO**
- account compatibili con **ERC725Y**

Questo garantisce:

- integrazione con i flussi di governance LUKSO
- gestione sicura delle autorizzazioni
- interoperabilità con l’ecosistema esistente

---

## Cosa resta off-chain

Il contratto salva solo la **traccia essenziale on-chain**.

Resta off-chain:

- documenti assembleari
- bilanci e rendiconti
- contratti con fornitori
- descrizioni dettagliate dei lavori
- eventuali allegati e PDF
- fotografie e documentazione tecnica

Tali informazioni sono referenziate tramite `dataURI` e `dataHash`.

---

## Cosa resta fuori dal contratto

Le seguenti logiche non sono gestite on-chain nella V1:

- gestione delle votazioni assembleari
- calcolo dei millesimi
- gestione della contabilità condominiale
- workflow approvativi complessi
- notifiche e comunicazioni ai condomini
- gestione dei pagamenti

Queste funzionalità possono essere implementate a livello di UI o backend off-chain.

---

## Obiettivi della UI

La UI dovrà consentire almeno queste operazioni:

### lato ChainIntegrate
- autorizzare/revocare creator
- registrare e gestire fornitori

### lato creator
- mintare un nuovo condominio

### lato amministratore
- vedere i dati del condominio
- creare e consultare delibere
- pianificare e gestire lavori
- assegnare fornitori
- registrare eventi
- trasferire l’amministrazione
- attivare/disattivare il condominio

### lato consultazione
- visualizzare lo storico delle delibere
- visualizzare lo storico dei lavori
- visualizzare il registro cronologico degli eventi

---

## Sintesi finale

Il Condominium Registry System è un modello in cui:

- il condominio è rappresentato da un token LSP8 unico
- l’identità è definita da un identificativo `bytes32`
- ChainIntegrate gestisce la governance del contratto
- i creator autorizzati possono creare nuovi condomini
- l’amministratore controlla la gestione operativa
- i fornitori sono registrati e associati ai lavori
- ogni evento rilevante è tracciato on-chain
- i documenti sono gestiti tramite un modello ibrido on-chain/off-chain
- il sistema è progettato per l’integrazione con Universal Profile

Questo costituisce la base funzionale per costruire:

- smart contract
- UI operativa
- JSON schema
- backend di supporto
- consultazione del registro del condominio
