# Concurrence — Queen Bee

## Étape 9.1 · L'action et sa trace, ensemble

### Démo 1 : sans transaction, le journal ment

Une application naïve écrit dans son **propre** journal avant d'agir :

INSERT INTO journal_appli : 'compte a.diop passé superviseur'  → 1 ligne
UPDATE compte SET role = 'superviseur' WHERE login = 'a.diop'  → ERROR: compte_role_valide

SELECT role FROM compte WHERE login = 'a.diop'  → apicultrice (inchangé)
SELECT * FROM journal_appli                     → la ligne de « passage superviseur » reste

**Le journal annonce une action qui n'a pas eu lieu.** C'est inexploitable comme
preuve.

### Démo 2 : avec transaction + trigger d'audit, trace et action partent ensemble

Dans un `BEGIN; ... ROLLBACK;` :

count(journal_audit) avant = X
UPDATE compte SET role = 'coordinateur' WHERE login = 'a.diop'  (le trigger journalise)
count(journal_audit) dans la transaction = X + 1
SELECT 1/0  → ERROR: division by zero
SELECT ...  → ERROR: current transaction is aborted
ROLLBACK
count(journal_audit) après = X   (la ligne a disparu)
role de a.diop                 = apicultrice   (inchangé)

**Atomicité** : soit la ligne de journal et la modification de la table partent
ensemble (`COMMIT`), soit aucune ne part (`ROLLBACK` ou erreur). Le journal ne
peut jamais raconter une action qui n'a pas eu lieu.

### Pourquoi l'invite devient `queenbee=!#` après une erreur dans une transaction ?

`!` signale que la transaction est **aborted** : tout `SELECT`, `UPDATE`, etc.
est refusé avec `current transaction is aborted, commands ignored until end of
transaction block`. Pour sortir : taper `ROLLBACK;` (ou `COMMIT;`, qui sera
converti en ROLLBACK dans ce cas). On ne peut pas valider une transaction
abortée.

## Étape 9.2 · La course au jeton dans deux terminaux

### Le scénario "vérifier, puis agir"

Dans deux terminaux A et B, on joue ces temps :

| T | Terminal A | Terminal B |
|---|---|---|
| T1 | BEGIN |  |
| T2 |  | BEGIN |
| T3 | SELECT jeton RT-f.ba-1 → utilise_le NULL |  |
| T4 |  | SELECT jeton RT-f.ba-1 → utilise_le NULL (A n'a rien commité) |
| T5 | UPDATE + INSERT session |  |
| T6 | COMMIT |  |
| T7 |  | UPDATE + INSERT session (B croit encore que c'est libre) |
| T8 |  | COMMIT |

SELECT count(*) FROM session_app JOIN jeton ... WHERE valeur = 'RT-f.ba-1'
→ **2 sessions ouvertes avec un seul jeton**

### Pourquoi ?

Le `SELECT` de T4 n'a pas pris de verrou. Il a vu la **ligne d'avant le commit
de A**. Entre T4 et T7, B croit toujours que le jeton est libre. Le `UPDATE` de
T7 attend que A finisse, puis **écrit par-dessus** la valeur `utilise_le` déjà
posée par A (overwrite silencieux). B ne voit aucun conflit.

### Les 4 corrections (étape 9.4 à venir)

1. `SELECT ... FOR UPDATE` : B attend A puis voit la ligne modifiée.
2. `UPDATE ... WHERE utilise_le IS NULL RETURNING id` : une seule instruction.
3. `UNIQUE (jeton_id)` sur `session_app` : la base refuse le doublon.
4. `ISOLATION LEVEL REPEATABLE READ` : B échoue avec `could not serialize`.

## Étape 9.3 · La course par un programme

### Résultats mesurés

Lancé sur `RT-f.ba-10` avec `course_jeton.py` (vérifier puis agir) :

clic 1 -> accepté : session ouverte
clic 2 -> accepté : session ouverte
sessions ouvertes avec ce jeton : 2

Lancé sur `RT-f.ba-11` avec `course_jeton_corrige.py` (UPDATE ... RETURNING) :

clic 1 -> accepté : session ouverte
clic 2 -> refusé : lien déjà utilisé ou expiré
sessions ouvertes avec ce jeton : 1

### Pourquoi la correction tient

L'`UPDATE` prend un verrou exclusif sur la ligne du jeton. Le second clic
attend que le premier finisse (COMMIT). Puis le `WHERE utilise_le IS NULL`
est **réévalué** : `utilise_le` n'est plus NULL, 0 ligne est renvoyée,
`RETURNING` est vide, l'INSERT ne se fait pas.

Une seule instruction = pas de fenêtre entre "vérifier" et "agir".

## Étape 9.4 · Les quatre corrections comparées

| Correction | Où agit-elle ? | Que voit la seconde requête ? | Avantage | Limite |
|---|---|---|---|---|
| `SELECT ... FOR UPDATE` | sur la ligne du jeton | attend A, puis voit `utilise_le` rempli | explicite, lisible | demande d'écrire BEGIN + SELECT FOR UPDATE + UPDATE (3 étapes) |
| `UPDATE ... WHERE utilise_le IS NULL RETURNING` | sur la ligne du jeton | attend A, le WHERE est réévalué, 0 ligne | une seule instruction, pas de transaction explicite | dépend de la discipline de tous les codes qui touchent au jeton |
| `UNIQUE (jeton_id)` sur session_app | sur la table session_app | duplicate key error au moment de l'INSERT | la base refuse le doublon, quel que soit le code | ne refuse pas le double UPDATE sur jeton, seulement le double INSERT ; doit nettoyer les doublons existants avant d'être posée |
| `REPEATABLE READ` | sur toute la transaction | `could not serialize access due to concurrent update` | protection générique sans réécrire la requête | force l'application à retry sur serialization_failure, plus coûteux en CPU |

### Le trigger du Lab 6 est aussi un "vérifier puis agir"

`suivi_un_formateur_par_theme()` fait exactement ça : il regarde s'il existe
déjà une ligne avec la même apicultrice et un autre formateur du même thème,
puis il laisse passer. Deux insertions simultanées pour la même (apicultrice,
thème) via deux formateurs différents peuvent **passer les deux** si les deux
exécutent le SELECT avant que l'autre ait commité.

**Correction** : poser `UNIQUE (apicultrice_id, theme)` sur `suivi_formation`
avec `theme` recopié et une FK composée `(formateur_id, theme) REFERENCES
formateur(id, theme)`. La base refuse alors le doublon directement, sans
race condition. C'est le "pour aller plus loin" du PDF.

Une contrainte unique est **toujours plus solide qu'un trigger** pour les
courses : la contrainte est évaluée au moment de l'INSERT/UPDATE définitif,
avec un verrou d'index, pas via un SELECT qui peut mentir.