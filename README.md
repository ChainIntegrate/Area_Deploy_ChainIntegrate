# Compliance, Traceability & Asset Lifecycle – LUKSO

Repository di sviluppo per smart contract legati a **certificazione, tracciabilità e gestione del ciclo di vita degli asset reali** su blockchain **LUKSO**.

Il progetto utilizza gli standard **LSP (LUKSO Standard Proposals)** e segue un approccio incrementale orientato a:

* governance
* auditabilità
* privacy by design
* separazione dei ruoli
* integrazione con sistemi off-chain
* lifecycle management di asset fisici
* identità digitali verificabili

---

# Scopo

Fornire una base tecnica per:

* emettere certificati e asset come identità digitali verificabili
* tracciare eventi, stati e trasformazioni nel tempo
* gestire revoche, sostituzioni e versionamento
* modellare interazioni multi-attore su asset fisici
* ridurre l’esposizione di dati sensibili on-chain
* separare governance, emissione, operatività e detenzione

La blockchain viene utilizzata come:

* registro di verità
* audit trail
* layer di integrità

non come database applicativo.

---

# Asset Lifecycle Model

Il repository evolve verso un modello generale di:

```text
asset-centric lifecycle tracking
```

Pattern principali:

* 1 token = 1 asset fisico
* eventi append-only
* ownership e governance separate
* controllo scrittura delegabile
* modello ibrido on-chain / off-chain
* integrazione con UI operative e sistemi esterni

Pattern riutilizzabile per:

* veicoli
* condomini
* supply chain
* componenti industriali
* identità agricole
* audit trail green / bio

---

# Approccio

* Smart contract LSP8
* Timeline e stato on-chain
* Dati estesi off-chain
* Hash crittografici on-chain
* Governance tramite Universal Profile
* UI e logica applicativa off-chain

---

# Contratti nel repository

---

## 🌱 Proof of Farming

Sistema di identità agricola e registrazione eventi agricoli basato su standard LUKSO (LSP8).

Il modello separa:

* identità agricola (`ProofOfFarmingPassport`)
* eventi operativi (`ProofOfFarmingEventRegistry`)
* futura reputazione (`ProofOfFarmingReputation`)

Approccio:

* mobile-first
* hybrid on-chain / off-chain
* audit trail verificabile
* anti-greenwashing
* futura reputazione agricola decentralizzata

Documentazione:

* `proof_of_farming_contractspec.md`
* `DEPLOYMENT.md`

---

## 🏢 Condominium Registry

Sistema di identità, governance e tracciabilità del ciclo di vita dei condomini basato su standard LUKSO (LSP8).

Caratteristiche principali:

* 1 token = 1 condominio
* governance condominiale verificabile
* storico delibere e lavori
* gestione fornitori
* audit trail eventi
* isolamento per-condominio (V2)

Documentazione:

* `CondominiumRegistry_contractspec.md`
* `DEPLOYMENT.md`

---

## 🚗 Vehicle Passport

Sistema di certificazione e tracciabilità del ciclo di vita del veicolo.

Caratteristiche principali:

* 1 token = 1 veicolo
* `tokenId = keccak256(VIN)`
* ownership transfer tracking
* autorizzazioni dinamiche per operatori
* service records append-only
* metadata originari congelabili
* invalidazione automatica permessi su cambio ownership

Documentazione:

* `VehiclePassport_contractspec.md`
* `DEPLOYMENT.md`

---

## 📜 Compliance Certificates

Sistema di certificazione di conformità basato su LSP8.

Caratteristiche principali:

* freeze metadata per-token
* stati `Valid / Revoked / Superseded`
* lifecycle certificato tracciabile
* separazione tra metadata e stato legale
* governance tramite Universal Profile

Documentazione:

* `ComplianceCertificate_contractspec.md`
* `DEPLOYMENT.md`

---

## 🔋 Battery Carbon Certificates

Sistema di certificazione impronta carbonica per lotti batteria.

Caratteristiche principali:

* 1 token = 1 lotto
* modello multi-attore
* contribution flow off-chain + hash on-chain
* freeze per-contribution
* aggregate verification
* governance separata dai contributor operativi

Documentazione:

* `BatteryCarbonCertificate_contractspec.md`
* `DEPLOYMENT.md`

---

## 🏭 Supplier Quality Evaluations

Sistema di valutazione qualitativa fornitori.

Caratteristiche principali:

* 1 token = 1 fornitore
* valutazioni append-only
* score multi-criterio
* media storica on-chain
* identità fornitore risolta off-chain

Documentazione:

* `SupplierQuality_contractspec.md`
* `DEPLOYMENT.md`

---

## 🔄 Traceability & Conformity Evolution

Area repository dedicata alle iterazioni architetturali e all’evoluzione dei modelli di tracciabilità e conformità.

Include:

* `Traceability_test2`
* `OLD_Traceability_test1`

Documentazione:

* `Traceability_test2_spec.md`
* `DEPLOYMENT.md`

---

# Stato del progetto

* ✔️ Battery Compliance Certificates deployato e verificato
* ✔️ Supplier Quality Evaluations deployato e verificato
* ✔️ Vehicle Passport deployato e verificato
* ✔️ Condominium Registry V1 deployato e verificato
* ✔️ Condominium Registry V2 deployato e verificato
* ✔️ Proof of Farming V1 deployato e verificato
* ✔️ Governance basata su Universal Profile
* ✔️ Modello dati ibrido (on-chain + off-chain)
* ✔️ Architettura orientata a lifecycle tracking e auditabilità
* ⏳ Evoluzione reputation layer e UI operative avanzate

---
