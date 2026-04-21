# Condominium Registry System (V2)

## Overview

Il **Condominium Registry System** è un sistema basato su **LUKSO LSP8** per rappresentare un condominio come un token digitale unico e tracciabile nel tempo.

Ogni condominio è rappresentato da un **Condominium Token** che contiene:

* identità univoca del condominio
* amministratore associato
* storico delle delibere
* gestione dei lavori e dei fornitori
* registro cronologico degli eventi amministrativi e tecnici

Il sistema è progettato per l’ecosistema **LUKSO / Universal Profile**, garantendo che i ruoli operativi siano gestiti da account compatibili con gli standard LUKSO.

---

## 🆕 Evoluzione V2

La V2 introduce una modifica strutturale fondamentale:

* i fornitori non sono più globali
* ogni condominio ha il proprio registro fornitori
* i fornitori sono creati e gestiti dall’amministratore del condominio
* eliminata la dipendenza operativa dal contract owner

---

## Standard utilizzato

Il contratto utilizza:

* **LSP8 Identifiable Digital Asset**
* `tokenId` di tipo `bytes32`
* metadata tramite URI + hash
* verifica profili via **ERC165 + ERC725Y**

---

## Identità del condominio

### Token = 1 condominio

Ogni condominio corrisponde a **un solo token**.

### Token ID

Il `tokenId` è un identificativo `bytes32` definito al mint:

```solidity
tokenId = keccak256(abi.encodePacked(condominiumIdentifier))
```

---

## Ruoli del sistema

### 1. ChainIntegrate

* deploy del contratto
* autorizzazione creator
* governance generale

⚠️ Non gestisce più i fornitori nella V2.

---

### 2. Creator autorizzato

* mint dei condomini
* assegnazione del token all’amministratore

---

### 3. Amministratore del condominio

* gestione completa operativa
* fornitori (V2)
* delibere
* lavori
* eventi
* trasferimento amministrazione

---

### 4. Fornitore (V2)

* entità **specifica del singolo condominio**
* non più globale

Esempi:

* impresa edile
* manutentore
* tecnico
* fornitori servizi

---

## Architettura generale

* 1 contratto LSP8
* N condomini (token)
* isolamento dati per `tokenId`

---

## Dati del condominio

* `tokenId`
* `adminUP`
* `name`
* `location`
* `createdAt`
* `active`

---

## Delibere

Gestite per condominio:

* `resolutionId`
* `category`
* `title`
* `approved`
* `dataURI`
* `dataHash`
* `createdBy`

---

## Fornitori (V2)

Registro **per-condominio**

### Struttura

* `contractorId`
* `tokenId`
* `name`
* `walletUP` (opzionale)
* `metadataURI`
* `createdAt`
* `active`
* `createdBy`

### Gestione

* `createContractor(tokenId, ...)`
* `setContractorActive(tokenId, ...)`

---

## Lavori

Ogni intervento è un `WorkItem`.

### Struttura

* `workId`
* `tokenId`
* `resolutionId` (opzionale)
* `contractorId` (stesso condominio)
* `title`
* `category`
* `workType`
* `status`
* date pianificate e reali

---

## Eventi

Ogni azione genera un evento.

### Struttura

* `eventId`
* `tokenId`
* `eventType`
* `timestamp`
* `category`
* `title`
* `dataURI`
* `dataHash`
* `createdBy`

---

## Lifecycle

### Setup

1. Deploy contratto
2. Autorizzazione creator

### Creazione

1. Mint condominio
2. Assegnazione admin

### Operatività

1. Creazione delibere
2. Creazione fornitori (V2)
3. Creazione lavori
4. Assegnazione fornitori
5. Aggiornamento stato lavori
6. Registrazione eventi

### Trasferimento

* cambio amministratore
* evento automatico

### Disattivazione

* tramite `setCondominiumActive`

---

## Architettura dati

* **on-chain:** stato e relazioni
* **off-chain:** documenti e contenuti

---

## Off-chain

* documenti assembleari
* contratti
* bilanci
* allegati
* media

---

## Fuori scope

* votazioni
* millesimi
* contabilità
* pagamenti
* notifiche

---

## Obiettivi UI

### ChainIntegrate

* gestione creator

### Creator

* mint condominio

### Amministratore

* gestione completa sistema

### Consultazione

* storico completo

---

## Compatibilità

* Universal Profile
* ERC725Y
* ecosistema LUKSO

---

## 📜 Legacy (V1)

### Differenza principale

* fornitori globali
* gestiti dal contract owner

### Limite

* modello centralizzato
* non aderente alla realtà dei condomini

### Evoluzione

V2 introduce:

* isolamento per condominio
* gestione decentralizzata
* modello più realistico

---

## Sintesi

Sistema in cui:

* ogni condominio = token LSP8
* governance distribuita
* fornitori per-condominio
* tracciabilità completa
* modello ibrido dati

Base per:

* smart contract evoluti
* UI operativa
* backend
* sistemi di audit
