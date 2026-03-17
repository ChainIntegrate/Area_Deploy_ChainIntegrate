# Vehicle Passport System

## Overview

Il **Vehicle Passport System** è un sistema basato su **LUKSO LSP8** per rappresentare un veicolo come un token digitale unico e tracciabile nel tempo.

Ogni veicolo è rappresentato da un **Vehicle Passport Token** che contiene:

- identità univoca del veicolo
- metadata originari del veicolo
- storico degli interventi rilevanti
- storico dei trasferimenti di proprietà
- sistema di autorizzazioni temporanee o monouso per consentire la scrittura dei record da parte degli operatori

Il sistema è pensato principalmente per l’ecosistema **LUKSO / Universal Profile**, ma i token possono essere detenuti anche da wallet standard non-UP, perché il contratto lavora semplicemente con indirizzi `address`.

---

## Standard utilizzato

Il contratto utilizza:

- **LSP8 Identifiable Digital Asset** come standard per il token NFT del veicolo
- **tokenId di tipo bytes32**
- metadata del singolo veicolo gestiti come **token-scoped data**
- logica custom per:
  - autorizzazioni di scrittura
  - record interventi
  - freeze metadata originari
  - ownership transfer record automatico

---

## Identità del veicolo

### Token = 1 veicolo

Ogni veicolo corrisponde a **un solo token**.

### Token ID

Il `tokenId` è il risultato dell’hash del **VIN / numero di telaio** già normalizzato off-chain.

Esempio concettuale:

```solidity
tokenId = keccak256(normalizedVIN)
```

### Regole di normalizzazione del VIN

La normalizzazione del VIN deve avvenire **off-chain** prima del mint, in modo coerente.

Regola consigliata:

- uppercase
- trim
- nessuno spazio
- nessun separatore extra

Esempio:

- input utente: ` wvw zzz1jzxw000001 `
- VIN normalizzato: `WVWZZZ1JZXW000001`

Questo garantisce che lo stesso veicolo produca sempre lo stesso `tokenId`.

---

## Ruoli del sistema

## 1. ChainIntegrate

ChainIntegrate è l’**admin del contratto**.

Ha il compito di:

- deployare il contratto
- autorizzare i concessionari che possono emettere passport
- revocare un concessionario
- aggiornare eventuale stato amministrativo del passport

ChainIntegrate **non scrive i record di manutenzione** e **non agisce come proprietario del veicolo**.

---

## 2. Concessionario autorizzato

Il concessionario è l’**issuer** del Vehicle Passport.

Può:

- mintare un nuovo passport
- assegnarlo al primo proprietario
- scrivere i metadata originari del veicolo
- correggere i metadata originari finché non vengono freezati
- freezare i metadata originari

Il concessionario può fare queste operazioni solo se è stato prima autorizzato da ChainIntegrate.

---

## 3. Proprietario del veicolo

Il proprietario è il **current owner del token LSP8**.

Può:

- detenere il passport del veicolo
- autorizzare operatori a scrivere record
- revocare le autorizzazioni
- trasferire il token a un nuovo proprietario in caso di vendita

Il proprietario **non crea ticket** e **non scrive record tecnici** nel modello V1.

---

## 4. Operatore autorizzato

L’operatore è il soggetto che esegue un intervento sul veicolo.

Esempi:

- officina meccanica
- carrozzeria
- gommista
- centro revisione
- soggetto che esegue aggiornamenti software
- soggetto che esegue campagne di richiamo

L’operatore può:

- ricevere un’autorizzazione dal proprietario
- creare un record di intervento a fine lavoro

L’operatore **non può scrivere record senza autorizzazione valida**.

---

## Architettura generale

## Collection unica

Il sistema è costruito come:

- **1 contratto LSP8**
- **molti token**
- **1 token per ogni veicolo**

Il contratto non crea un contratto separato per ogni veicolo.

---

## Dati originari del veicolo

I dati originari del veicolo sono rappresentati tramite un **JSON di riferimento** associato al token.

Nel contratto vengono salvati:

- `originMetadataURI`
- `originMetadataHash`
- `writtenBy`
- `updatedAt`
- `frozen`

### Significato

- `originMetadataURI`: URI del JSON originario del veicolo
- `originMetadataHash`: hash del contenuto JSON
- `writtenBy`: soggetto che ha scritto i metadata
- `updatedAt`: timestamp ultimo aggiornamento
- `frozen`: blocco finale dei metadata originari

### Regola di scrittura

I metadata originari possono essere:

- scritti dal concessionario issuer
- corretti solo dal soggetto che li ha scritti
- modificati solo finché `frozen == false`

Quando vengono freezati, non sono più modificabili.

---

## Perché usare URI + hash

Il sistema non salva l’intero JSON on-chain.

Salva invece:

- un **URI**
- un **hash verificabile**

Questo approccio consente:

- costi on-chain più contenuti
- maggiore flessibilità dei dati
- verifica di integrità del contenuto off-chain
- compatibilità con strutture JSON più ricche

---

## Freeze dei metadata originari

Il freeze dei metadata originari serve a bloccare i dati iniziali del vehicle passport una volta verificati.

### Logica

1. il concessionario scrive i metadata
2. verifica che non ci siano errori
3. esegue il freeze
4. da quel momento i metadata originari diventano immutabili

### Chi può fare il freeze

Solo il soggetto che ha scritto i metadata originari.

---

## Autorizzazioni di scrittura

Il proprietario del token può autorizzare un operatore a scrivere un record.

Ogni autorizzazione ha un identificativo univoco:

- `authorizationId`

### Dati principali di una autorizzazione

- `authorizationId`
- `tokenId`
- `grantedBy`
- `operator`
- `category`
- `mode`
- `validFrom`
- `validUntil`
- `epoch`
- `active`

### Significato campi

- `grantedBy`: proprietario che concede l’autorizzazione
- `operator`: soggetto autorizzato a scrivere
- `category`: tipo di intervento consentito
- `mode`: `OneShot` oppure `Reusable`
- `validFrom`: inizio validità
- `validUntil`: fine validità, oppure `0` se senza scadenza
- `epoch`: versione autorizzativa del veicolo al momento della concessione
- `active`: autorizzazione ancora attiva o revocata

---

## Tipologie di autorizzazione

## OneShot

Autorizzazione valida per **un solo record**.

Uso tipico:

- il proprietario porta l’auto in officina
- autorizza l’officina
- l’officina registra quell’intervento
- l’autorizzazione si consuma automaticamente

---

## Reusable

Autorizzazione valida per più record, fino a quando:

- non viene revocata
- non scade
- non cambia proprietario del veicolo

Uso tipico:

- officina di fiducia
- manutentore ricorrente
- gestione continuativa del mezzo

---

## Revoca autorizzazioni

Il proprietario può revocare manualmente un’autorizzazione.

Questo consente un modello operativo molto pratico:

1. il proprietario autorizza il meccanico
2. il meccanico effettua il lavoro
3. il proprietario revoca l’autorizzazione

Nel caso di autorizzazioni `OneShot`, spesso la revoca manuale non serve perché l’autorizzazione si consuma automaticamente alla creazione del record.

---

## vehicleAuthorizationEpoch

Per ogni veicolo esiste un contatore chiamato:

- `vehicleAuthorizationEpoch[tokenId]`

### A cosa serve

Serve a invalidare automaticamente tutte le autorizzazioni precedenti quando cambia il proprietario del veicolo, senza dover iterare tutte le autorizzazioni una per una.

### Come funziona

Quando il proprietario crea una nuova autorizzazione, questa memorizza l’epoch attuale del veicolo.

Quando il token viene trasferito a un nuovo owner:

- `vehicleAuthorizationEpoch[tokenId]` aumenta di 1

Da quel momento tutte le autorizzazioni create con l’epoch precedente diventano automaticamente inutilizzabili.

### Vantaggio

Questo rende il cambio di proprietà:

- più pulito
- più sicuro
- più economico lato gas rispetto a una revoca massiva in loop

---

## Record interventi

Ogni intervento rilevante viene rappresentato come un **Service Record**.

Il sistema segue il modello:

- **un record per ogni intervento**
- record creato **a fine lavoro**
- record già completo e già frozen

### Il proprietario non apre ticket

Nel modello V1:

- il proprietario **non apre ticket**
- il proprietario **non crea bozze**
- il proprietario **autorizza**
- l’operatore **crea direttamente il record finale**

---

## Struttura logica di un record

Ogni record contiene:

- `recordId`
- `tokenId`
- `authorizationId`
- `category`
- `cause`
- `writer`
- `createdAt`
- `workStartedAt`
- `workCompletedAt`
- `odometerKm`
- `recordURI`
- `recordHash`
- `frozen`
- `supersedesRecordId`
- `systemGenerated`

### Significato campi principali

- `recordId`: identificativo del record
- `tokenId`: veicolo a cui il record appartiene
- `authorizationId`: autorizzazione utilizzata per creare il record
- `category`: tipo di intervento
- `cause`: causa o motivo dell’intervento
- `writer`: operatore che scrive il record
- `workStartedAt`: inizio lavori
- `workCompletedAt`: fine lavori
- `odometerKm`: chilometraggio
- `recordURI`: URI del JSON del record
- `recordHash`: hash del contenuto JSON
- `frozen`: sempre `true` al momento della creazione nella V1
- `supersedesRecordId`: eventuale record precedente sostituito
- `systemGenerated`: indica se il record è generato dal contratto

---

## Modello di creazione record

Il sistema usa **Opzione A**.

Questo significa che l’operatore, a fine lavoro, chiama una sola funzione per creare il record completo.

### Non esistono quindi:

- draft record
- update successivo del record
- freeze in una chiamata separata

### Esiste invece:

- creazione unica del record finale

Il record nasce già:

- completo
- immutabile
- frozen

---

## Categorie di record

Le categorie previste sono:

- `OrdinaryMaintenance`
- `ExtraordinaryMaintenance`
- `MechanicalRepair`
- `BodyRepair`
- `TireService`
- `InspectionRevision`
- `SoftwareUpdate`
- `RecallCampaign`
- `OwnershipTransfer`

### Nota importante

`OwnershipTransfer` **non è una categoria scrivibile dagli operatori**.

È una categoria **di sistema**, usata solo dal contratto per registrare automaticamente il passaggio di proprietà del veicolo.

---

## Cause di intervento

Le cause previste sono:

- `None`
- `Routine`
- `Wear`
- `Accident`
- `Recall`
- `InspectionOutcome`
- `Diagnostic`
- `Other`

### Esempi

- `MechanicalRepair + Accident`
- `BodyRepair + Accident`
- `OrdinaryMaintenance + Routine`
- `InspectionRevision + InspectionOutcome`

In questo modello, l’incidente **non è una categoria autonoma**, ma una causa dell’intervento.

---

## Correzioni di record

Nella V1, un record nasce già frozen e non viene modificato.

Se serve correggere un errore, si crea un **nuovo record** che può referenziare il precedente tramite:

- `supersedesRecordId`

Questo permette di mantenere una storia chiara e auditabile, senza alterare i dati già registrati.

---

## Ownership transfer automatico

Quando il token viene trasferito da un proprietario a un altro:

1. cambia il proprietario del token
2. si aggiorna `lastOwnershipChangeAt`
3. aumenta `vehicleAuthorizationEpoch[tokenId]`
4. tutte le autorizzazioni precedenti diventano stale
5. il contratto crea automaticamente un record di tipo `OwnershipTransfer`

### Caratteristiche del record automatico

- `category = OwnershipTransfer`
- `authorizationId = 0`
- `writer = address(0)`
- `systemGenerated = true`
- `frozen = true`

Questo consente di avere uno storico dei cambi proprietà direttamente nel passport.

---

## Wallet supportati

Il contratto è progettato per funzionare con:

- **Universal Profile LUKSO**
- **wallet normali EOA**

### Conseguenza pratica

Il sistema è compatibile con casi in cui il passport sia detenuto da:

- un utente con UP
- un utente con wallet standard
- un soggetto che poi in futuro migra a UP

### Filosofia progettuale

L’esperienza migliore è attesa nel contesto LUKSO / UP, ma il contratto resta neutro e interoperabile.

---

## Flusso operativo completo

## Fase 1 - Setup piattaforma

1. ChainIntegrate deploya il contratto
2. ChainIntegrate autorizza il concessionario X come issuer

---

## Fase 2 - Emissione passport

1. il concessionario normalizza il VIN off-chain
2. calcola il `tokenId`
3. minta il Vehicle Passport
4. assegna il token al primo proprietario
5. scrive `originMetadataURI` e `originMetadataHash`
6. verifica il contenuto
7. freeza i metadata originari

---

## Fase 3 - Utilizzo del veicolo

1. il proprietario porta il veicolo presso un operatore
2. il proprietario crea una autorizzazione
3. l’operatore esegue il lavoro
4. a fine lavoro l’operatore crea il record
5. se l’autorizzazione è `OneShot`, si consuma automaticamente

---

## Fase 4 - Revoca

1. il proprietario può revocare l’autorizzazione
2. oppure l’autorizzazione `OneShot` si esaurisce da sola

---

## Fase 5 - Vendita del veicolo

1. il proprietario trasferisce il token al nuovo proprietario
2. il contratto aggiorna l’epoch del veicolo
3. le vecchie autorizzazioni diventano invalide
4. il contratto crea il record automatico `OwnershipTransfer`

---

## Logica di validità di una autorizzazione

Una autorizzazione è considerata realmente utilizzabile solo se tutte queste condizioni sono vere:

- esiste
- è attiva
- appartiene al veicolo corretto
- l’epoch coincide con quella corrente del veicolo
- il proprietario attuale del token coincide con `grantedBy`
- è nel periodo di validità
- non è stata revocata
- l’operatore chiamante è quello autorizzato

---

## Cosa resta off-chain

Il contratto salva solo la **traccia essenziale on-chain**.

Resta off-chain:

- JSON metadata del veicolo
- JSON dei record
- descrizione dettagliata lavori
- eventuali allegati
- eventuali PDF
- eventuali foto
- eventuali documenti amministrativi

Il PDF **non è obbligatorio**.

---

## Cosa resta fuori dal contratto

Le seguenti logiche non sono gestite on-chain nella V1:

- classificazione operatori per tipologia
- whitelist operator types on-chain
- gestione ticket preliminari
- manutenzioni personali o poco rilevanti
- gestione targa come identità primaria
- storico targa come record autonomo
- workflow approvativi complessi

Queste parti possono vivere in UI, backend o metadata off-chain.

---

## Obiettivi della UI

La UI dovrà consentire almeno queste operazioni:

### lato ChainIntegrate
- autorizzare/revocare concessionari

### lato concessionario
- mintare un passport
- scrivere metadata originari
- correggere metadata originari prima del freeze
- freezare metadata originari

### lato proprietario
- vedere il passport del veicolo
- vedere i metadata originari
- autorizzare un operatore
- revocare un’autorizzazione
- trasferire il token

### lato operatore
- vedere se è autorizzato
- inserire il record a fine lavoro
- pubblicare URI e hash del record

### lato consultazione
- vedere storico record del veicolo
- vedere storico passaggi di proprietà
- distinguere record operatore da record di sistema

---

## Sintesi finale

Il Vehicle Passport System è un modello in cui:

- il veicolo è un token LSP8 unico
- l’identità è il VIN hashato
- il concessionario emette il passport
- il proprietario controlla chi può scrivere
- l’operatore registra gli interventi reali
- il contratto registra automaticamente i cambi di proprietà
- i metadata originari sono verificabili e freezabili
- le autorizzazioni precedenti decadono automaticamente al cambio owner
- il sistema è compatibile sia con Universal Profile sia con wallet normali

Questo costituisce la base funzionale per costruire:
- smart contract
- UI operativa
- JSON schema
- backend di supporto
- consultazione del passport
