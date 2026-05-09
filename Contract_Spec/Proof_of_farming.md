# Proof of Farming System (V1)

## Overview

Il **Proof of Farming System** è un sistema basato su **LUKSO LSP8** progettato per rappresentare un’azienda agricola come identità digitale verificabile e collegarla a uno storico di eventi agricoli, ambientali e documentali.

Il sistema non nasce come semplice tracciabilità di prodotto, ma come **registro del comportamento agricolo nel tempo**.

Ogni azienda agricola è rappresentata da un **Farm Passport**, mentre gli eventi operativi vengono registrati in un contratto separato chiamato **Event Registry**.

L’obiettivo è costruire una base verificabile per:

* identità agricola
* pratiche green / bio
* storico operativo
* audit trail
* anti-greenwashing
* futura reputazione agricola
* futura logica badge / score

Il sistema è progettato per l’ecosistema **LUKSO / Universal Profile**, mantenendo una struttura modulare e compatibile con evoluzioni future.

---

## Versione attuale

La V1 introduce due contratti principali:

1. **ProofOfFarmingPassport**
2. **ProofOfFarmingEventRegistry**

La V1 non include ancora un motore reputazionale on-chain completo.

Badge, score e reputazione avanzata sono previsti come evoluzione futura tramite un terzo contratto dedicato.

---

## Standard utilizzato

Il sistema utilizza:

* **LSP8 Identifiable Digital Asset**
* `tokenId` di tipo `bytes32`
* modello ibrido on-chain / off-chain
* hash on-chain per integrità dati
* eventi Solidity per audit trail
* compatibilità con ecosistema LUKSO / Universal Profile

---

# Architettura generale

## Contract 1 — ProofOfFarmingPassport

Il contratto `ProofOfFarmingPassport` rappresenta l’identità agricola.

### Token = 1 azienda agricola

Ogni azienda agricola corrisponde a **un solo token LSP8**.

### Farm ID

Il `farmId` è un identificativo `bytes32` definito al mint.

```solidity
farmId = tokenId
```

Il `farmId` è il collegamento principale tra il Farm Passport e gli eventi registrati nel sistema.

---

## Contract 2 — ProofOfFarmingEventRegistry

Il contratto `ProofOfFarmingEventRegistry` registra eventi agricoli riferiti a un Farm Passport esistente.

Non crea aziende agricole.

Accetta eventi solo se il `farmId` esiste nel contratto `ProofOfFarmingPassport`.

---

## Collegamento tra i contratti

Il collegamento tra i due contratti avviene tramite:

```text
farmId = tokenId del FarmPassport
```

Il contratto `EventRegistry` riceve in fase di deploy l’indirizzo del contratto `FarmPassport`.

```solidity
constructor(address passportAddress)
```

Il registry controlla l’esistenza dell’azienda agricola tramite:

```solidity
passport.farmExists(farmId)
```

e verifica il proprietario del Farm Passport tramite:

```solidity
passport.tokenOwnerOf(farmId)
```

Questo garantisce che:

* non si possano registrare eventi per aziende inesistenti
* solo il proprietario del Farm Passport o operatori autorizzati possano registrare eventi
* gli eventi siano sempre collegati a un’identità agricola ufficiale

---

# Identità agricola

## Farm Passport

Ogni Farm Passport contiene:

* `farmId`
* `publicName`
* `metadataURI`
* `status`
* `createdAt`
* `updatedAt`

---

## Stati dell’azienda agricola

La V1 prevede i seguenti stati:

* `None`
* `Active`
* `Suspended`
* `Revoked`

---

## Soulbound model

Il Farm Passport è pensato come token **non liberamente trasferibile**.

La logica prevista è:

* mint consentito
* burn eventualmente consentito
* trasferimento tra utenti bloccato

Questo rafforza il concetto di identità agricola stabile e riduce l’uso speculativo del token.

---

# Ruoli del sistema

## 1. Contract owner / ChainIntegrate

Responsabilità:

* deploy dei contratti
* governance generale
* creazione Farm Passport
* gestione validatori nel registro eventi

---

## 2. Farm Passport owner

Rappresenta il proprietario operativo dell’identità agricola.

Può:

* detenere il Farm Passport
* autorizzare operatori agricoli
* registrare eventi direttamente
* collegare l’azienda agricola allo storico operativo

---

## 3. Farm operator

Operatore autorizzato dal Farm Passport owner.

Può:

* registrare eventi agricoli
* registrare attività operative
* creare dati hashati collegati al Farm Passport

Esempi:

* agricoltore
* dipendente aziendale
* tecnico aziendale
* collaboratore autorizzato

---

## 4. Validator

Soggetto autorizzato alla validazione o revoca degli eventi.

Può:

* validare eventi registrati
* revocare eventi errati o contestati

Esempi:

* agronomo
* tecnico
* auditor
* ente autorizzato
* ChainIntegrate in fase iniziale

---

# Event Registry

## Struttura evento

Ogni evento agricolo contiene:

* `eventId`
* `farmId`
* `plotId`
* `eventType`
* `status`
* `dataHash`
* `operator`
* `validator`
* `createdAt`
* `validatedAt`

---

## Event ID

L’`eventId` è un identificativo `bytes32` univoco.

Può essere generato off-chain a partire da:

```text
farmId + plotId + eventType + timestamp + nonce
```

oppure da una logica applicativa definita dal backend / frontend.

---

## Plot ID

Il `plotId` identifica un appezzamento, campo, serra o area agricola.

La V1 non registra direttamente l’anagrafica completa degli appezzamenti on-chain.

Il dettaglio dell’appezzamento resta off-chain e viene collegato tramite JSON e hash.

---

## Data Hash

Il `dataHash` rappresenta l’hash del documento JSON off-chain contenente i dati completi dell’evento.

Esempio:

```text
dataHash = keccak256(JSON normalizzato)
```

Il dato completo resta off-chain, mentre l’integrità viene ancorata on-chain.

---

# Tipi di evento supportati

La V1 supporta i seguenti `EventType`:

* `None`
* `CropStarted`
* `SoilWork`
* `Fertilization`
* `Treatment`
* `Irrigation`
* `Harvest`
* `SoilAnalysis`
* `Biodiversity`
* `Energy`
* `RecoveredWater`
* `AgriculturalWaste`
* `Certification`
* `Audit`
* `NonCompliance`
* `NonComplianceClosed`
* `BadgeAssigned`
* `BadgeRevoked`
* `ScoreUpdated`

---

## Nota sui badge e score nella V1

I tipi:

* `BadgeAssigned`
* `BadgeRevoked`
* `ScoreUpdated`

sono presenti come eventi registrabili, ma la V1 non implementa ancora una vera logica reputazionale autonoma.

La logica consigliata è spostare badge, score e reputazione in un contratto futuro dedicato:

```text
ProofOfFarmingReputation
```

---

# Stato degli eventi

Ogni evento può avere uno dei seguenti stati:

* `None`
* `Registered`
* `Validated`
* `Revoked`

---

## Lifecycle evento

Flusso previsto:

```text
Registered → Validated
Registered → Revoked
Validated → Revoked
```

---

## Registrazione evento

Un evento può essere registrato da:

* proprietario del Farm Passport
* operatore autorizzato per quello specifico `farmId`

La funzione principale è:

```solidity
registerEvent(
    bytes32 farmId,
    bytes32 plotId,
    bytes32 eventId,
    EventType eventType,
    bytes32 dataHash
)
```

---

## Validazione evento

Un evento può essere validato da:

* contract owner
* validator autorizzato

Funzione:

```solidity
validateEvent(bytes32 eventId)
```

---

## Revoca evento

Un evento può essere revocato da:

* contract owner
* validator autorizzato

Funzione:

```solidity
revokeEvent(bytes32 eventId)
```

---

# Architettura dati

## On-chain

Sono registrati on-chain:

* identità Farm Passport
* stato azienda
* ownership del Farm Passport
* collegamento eventi / farm
* `eventId`
* `farmId`
* `plotId`
* `eventType`
* `dataHash`
* operatore
* validatore
* timestamp
* stato evento

---

## Off-chain

Restano off-chain:

* dettagli agricoli completi
* documenti
* fotografie
* analisi
* certificazioni
* dati sensibili
* coordinate precise
* allegati tecnici
* report
* JSON evento completo

---

## Motivo del modello ibrido

Il modello ibrido consente di:

* ridurre costi on-chain
* evitare pubblicazione di dati sensibili
* mantenere flessibilità documentale
* garantire integrità tramite hash
* costruire dashboard e report off-chain

---

# Esempio JSON evento off-chain

## Irrigazione

```json
{
  "eventType": "IRRIGATION",
  "farmId": "0x...",
  "plotId": "campo-nord",
  "method": "goccia",
  "durationMinutes": 45,
  "waterSource": "pozzo",
  "estimatedVolumeLiters": 1200,
  "createdBy": "0x...",
  "createdAt": "2026-05-09T09:30:00Z"
}
```

---

# Lifecycle operativo

## Setup

1. Deploy `ProofOfFarmingPassport`
2. Deploy `ProofOfFarmingEventRegistry`
3. Collegamento EventRegistry → FarmPassport tramite address del Passport
4. Configurazione validatori

---

## Creazione azienda agricola

1. Definizione `farmId`
2. Mint del Farm Passport
3. Assegnazione al proprietario / Universal Profile aziendale
4. Registrazione metadataURI

---

## Operatività agricola

1. Autorizzazione operatori
2. Registrazione eventi da mobile / webapp
3. Creazione JSON off-chain
4. Calcolo `dataHash`
5. Ancoraggio evento on-chain
6. Eventuale validazione
7. Eventuale uso futuro per score e badge

---

## Validazione

1. Il validator legge evento e JSON off-chain
2. Verifica coerenza e documentazione
3. Chiama `validateEvent`
4. L’evento passa a stato `Validated`

---

## Revoca

1. Viene individuato un evento errato, non conforme o contestato
2. Il validator chiama `revokeEvent`
3. L’evento resta nello storico ma viene marcato come `Revoked`

---

# Obiettivi UI

## Mobile-first

La UI principale deve essere mobile-first.

L’agricoltore deve poter registrare eventi rapidamente dal campo.

Esempi di azioni mobile:

* registra irrigazione
* registra trattamento
* registra raccolta
* carica foto
* allega documento
* salva nota campo

---

## Desktop / dashboard

Il desktop è più adatto per:

* gestione azienda
* gestione operatori
* report
* audit
* configurazione appezzamenti
* esportazioni
* dashboard reputazionale futura

---

# Fuori scope V1

La V1 non gestisce direttamente:

* pagamenti
* marketplace
* certificazione legale bio automatica
* calcolo reputazionale on-chain completo
* score agricolo automatico
* badge NFT reputazionali completi
* sensori IoT nativi
* gestione amministrativa aziendale
* fiscalità
* logistica completa
* dati meteorologici automatici
* vendita prodotto al consumatore

---

# Evoluzione futura

## ProofOfFarmingReputation

Contratto futuro dedicato a:

* score snapshots
* badge
* livelli reputazionali
* revoche
* validità temporale
* valutazioni derivate dagli eventi validati

---

## Direzione architetturale

```text
FarmPassport = identity
EventRegistry = behavior
Reputation = evaluation
```

---

## Possibili badge futuri

* Soil Safe
* Water Responsible
* Biodiversity Positive
* Bio Documented
* Low Carbon Farm
* Regenerative Farm

---

## Possibili score futuri

* `soilScore`
* `waterScore`
* `biodiversityScore`
* `carbonScore`
* `overallScore`

---

# Compatibilità

Il sistema è pensato per:

* LUKSO Testnet / Mainnet
* Universal Profile
* LSP8 Identifiable Digital Asset
* modello on-chain / off-chain
* frontend mobile-first
* backend per JSON, hash e documenti
* futura dashboard pubblica

---

# Sintesi

Proof of Farming è un sistema in cui:

* ogni azienda agricola = Farm Passport LSP8
* ogni evento agricolo = record verificabile
* gli eventi sono collegati al Farm Passport tramite `farmId`
* i dettagli restano off-chain
* l’integrità è garantita tramite `dataHash`
* gli operatori sono autorizzati dal proprietario del Farm Passport
* i validator possono validare o revocare eventi
* badge e score sono previsti come layer successivo

Base per:

* smart contract agricoli evoluti
* mobile app agricola
* dashboard reputazionale
* audit trail green / bio
* layer anti-greenwashing
* futura reputazione agricola decentralizzata
