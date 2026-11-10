# Durabilité et sauvegarde — Queen Bee

## Les trois réglages de PostgreSQL

| Réglage | Valeur | Ce qu'il garantit |
|---|---|---|
| fsync | on | les écritures sont forcées sur le disque avant d'acquitter |
| synchronous_commit | on | `COMMIT` ne répond qu'une fois le WAL écrit sur disque |
| wal_level | replica | le WAL contient assez d'info pour la réplication et le PITR |

## Sauvegarde, empreinte, restauration

Procédure testée :

pg_dump -Fc -f queenbee_j2.dump queenbee
shasum -a 256 queenbee_j2.dump > queenbee_j2.dump.sha256
createdb queenbee_restore
pg_restore -d queenbee_restore queenbee_j2.dump
psql -d queenbee_restore -c "SELECT count(*) FROM journal_audit"  → N lignes
psql -d queenbee_restore -c "DELETE FROM journal_audit"            → ERROR: en ajout seul
shasum -a 256 -c queenbee_j2.dump.sha256                           → OK

**Deux faits** :
- Le journal est intact après restauration.
- Le trigger `journal_ajout_seul` est restauré et bloque toute modification
  dans la base restaurée aussi.

## Ce qu'on perdrait avec synchronous_commit = off

Les COMMIT acquitteraient **avant** que le WAL soit écrit sur disque. En cas
de panne électrique entre le `COMMIT` et l'écriture physique, les dernières
transactions **validées côté application** seraient **perdues**. C'est le
compromis entre **latence** (le COMMIT répond plus vite) et **durabilité**
(garantie de ne pas perdre). On l'utilise pour des charges en masse où une
perte des N dernières secondes est acceptable.

## Pourquoi garder l'empreinte AILLEURS que la sauvegarde

Si un attaquant altère la sauvegarde, il peut recalculer l'empreinte et
remplacer le fichier `.sha256` aussi. L'empreinte doit vivre **ailleurs** :
- envoyée par mail à une adresse archivée
- publiée sur un journal d'intégrité externe (un CA, un TSA)
- copiée dans un coffre à clés physique

Si la sauvegarde et l'empreinte sont sur le même disque, l'empreinte ne
protège que contre la corruption accidentelle, pas contre un attaquant.

## Ce que pg_dump ne sauvegarde PAS

Les **rôles** PostgreSQL (`qb_apicultrice`, `coord.casa`, `admin.beeafrica`…)
vivent au niveau du serveur, pas de la base. `pg_dump` ne les exporte pas.
Pour les sauvegarder, il faut :

pg_dumpall --roles-only -f roles.sql

Sans ça, la restauration dans une autre instance plante sur tous les
`GRANT ... TO qb_apicultrice` parce que le rôle n'existe pas.

## Durabilité ≠ sauvegarde

- **Durabilité** (ACID — D) : survivre à une **panne électrique** ou à un
  `kill -9` du serveur. Tout ce qui était COMMIT est encore là au redémarrage.
- **Sauvegarde** : survivre à la **perte du disque**, à une **erreur humaine**
  (`DROP TABLE`), ou à un **rançongiciel**.

Un disque chiffré par un rançongiciel laisse la base fonctionnelle (si on paye),
mais la sauvegarde hors-ligne non chiffrée permet de repartir **sans payer**.
C'est pour ça qu'une sauvegarde doit vivre **sur un support physiquement séparé**
(mieux encore : hors ligne).