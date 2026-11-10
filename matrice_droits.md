# Matrice des droits — Queen Bee

Base du principe de **moindre privilège** : chacun n'a accès qu'à ce dont son
métier a besoin. Les opérations d'écriture passent par des **vues** ou des
**fonctions** sécurisées, jamais directement sur les tables.

| Objet / Action | apicultrice | coordinateur | gestionnaire | admin |
|---|---|---|---|---|
| ses ruches et leurs mesures | lire | — | — | — |
| mesures et inspections des ruches de son site | — | lire | — | — |
| déclarer une récolte | sur ses ruches | — | — | — |
| valider une récolte (UC-C02) | non | sur son site (via fonction) | — | — |
| ruches et téléphones de son site | — | lire | — | — |
| synthèse et export (UC-G01, UC-G02) | — | — | lire | — |
| comptes utilisateurs (UC-AD01) | — | — | — | CRUD |
| journal d'audit | — | — | — | lire |

### Correspondances rôles ↔ groupes

- `apicultrice` → `qb_apicultrice`
- `coordinateur` → `qb_coordinateur`
- `gestionnaire` → `qb_gestionnaire`
- `administrateur` → `qb_admin`

### Correspondances personnes du PDF (adaptées à notre jeu d'essai)

- `f.ba` (apicultrice) → non présente ; on utilise **`a.diop`** (Aminata Diop, SN-CASA)
- `awa.diop` (apicultrice) → **`a.diop`** (Awa Diop, SN-CASA ; homonyme, on prend celle de +221 77 100 00 03)
- `coord.sn` → **`coord.casa`** (coordinateur SN-CASA, déjà dans notre jeu d'essai)
- `gest.beeafrica` → **`gest.beeafrica`** (à créer, gestionnaire global)
- `admin.beeafrica` → **`admin.beeafrica`** (à créer, admin global)