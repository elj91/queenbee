# Normalisation Jour 2 – Queen Bee

## Étape 6.1 · La table `formation_plat`

### Dépendances fonctionnelles

- **DF1 : formateur → theme** — un formateur n'enseigne qu'un thème (règle métier).
- **DF2 : (telephone, theme) → formateur** — pour une apicultrice et un thème, un seul formateur (règle métier).

De DF1 et DF2, on déduit aussi `(telephone, formateur) → theme` : si on connaît le
formateur, on connaît le thème, et avec le téléphone on identifie la ligne.

### Clés candidates

- **(telephone, theme)** — c'est la clé primaire actuelle.
- **(telephone, formateur)** — puisque le formateur donne le thème, ce couple
  détermine aussi toute la ligne.

Les trois colonnes font partie d'une clé : il n'y a pas d'attribut non-clé.

### 3NF ? BCNF ?

- **3NF ? Oui.** Un attribut non-clé ne dépend d'aucun attribut non-clé, parce qu'il
  n'y a *aucun* attribut non-clé — toutes les colonnes participent à une clé candidate.
  La 3NF autorise aussi qu'une partie gauche appartienne à une clé, ce qui est le cas
  pour `formateur` (dans la clé candidate `(telephone, formateur)`).

- **BCNF ? Non.** BCNF exige que la partie gauche de toute DF soit une clé
  candidate (ou un sur-ensemble de clé). Or `formateur → theme` a pour partie
  gauche `formateur` seul, qui n'est **pas** une clé candidate (un formateur a
  plusieurs téléphones d'apicultrices). La règle métier « un formateur =
  un thème » n'est donc pas protégée par les contraintes de la table.

  ## Étape 6.2 · L'anomalie, le mauvais et le bon découpage

### L'anomalie provoquée (démonstration en psql, dans une transaction annulée)

Dans un `BEGIN; ... ROLLBACK;`, on a fait passer Moussa Sarr en `capteurs`
pour `+221 77 100 00 02`. La table l'a accepté, puis l'enquête
« formateurs avec plusieurs thèmes » retourne :

| formateur | themes |
|---|---|
| Moussa Sarr | {capteurs, varroa} |

La règle `formateur → theme` est violée **sans aucun message d'erreur**.
C'est pour ça qu'il faut la faire respecter par la structure.

### Le mauvais découpage (par `theme`)

Si on découpe `(telephone, theme)` et `(theme, formateur)`, la colonne
commune `theme` n'est clé d'aucun des deux morceaux (une apicultrice a
plusieurs thèmes, un thème a plusieurs formateurs). La jointure renvoie
**16 lignes** au lieu de 8 : 8 lignes sont inventées. Par exemple,
Fatou Ba (`+221 77 100 00 02`) apparaît suivie par Moussa Sarr, Ibrahima
Fall **et** Kouassi Yao sur le thème `varroa`, alors qu'elle ne suit que
Moussa Sarr.

### Le bon découpage BCNF (par `formateur`)

On crée deux tables :
- `formateur (id, nom UNIQUE, theme CHECK)` — la contrainte `UNIQUE nom`
  et le fait que `theme` est une colonne de `formateur` font respecter
  `formateur → theme` : la règle est désormais **dans la base**.
- `suivi_formation (apicultrice_id, formateur_id)` — clé étrangère
  `apicultrice_id` au lieu de recopier le téléphone.

La jointure `suivi_formation ⋈ apicultrice ⋈ formateur` redonne
exactement les 8 lignes de `formation_plat` (preuve `EXCEPT` croisée
à **0 ligne**). Le découpage est sans perte.

### Pourquoi `suivi_formation` pointe-t-elle vers `apicultrice(id)` au lieu de recopier le téléphone ?

Trois raisons :
- **Pas de redondance** : le téléphone d'une apicultrice n'existe qu'une
  seule fois, dans `apicultrice.telephone`. Si on le recopiait dans
  `suivi_formation`, il faudrait le mettre à jour en deux endroits
  simultanément — et on retomberait sur la même anomalie qu'au Lab 5.
- **Pas de ligne orpheline** : la clé étrangère refuse d'enregistrer un
  suivi pour une apicultrice qui n'existe pas.
- **Robustesse aux changements** : si une apicultrice change de
  numéro, aucune mise à jour cascade n'est nécessaire — l'`id` ne
  change pas.

  ## Étape 6.3 · La règle perdue et le trigger qui la rétablit

### La règle perdue

Après le découpage BCNF, `suivi_formation(apicultrice_id, formateur_id)` autorise
qu'une apicultrice soit suivie par **deux formateurs** différents **pour le même
thème**. On l'a vérifié dans un `BEGIN; ... ROLLBACK;` :

INSERT INTO suivi_formation SELECT Fatou Ba, Ibrahima Fall
→ INSERT 0 1 (accepté, alors que Fatou Ba a déjà Moussa Sarr en varroa)

SELECT ... HAVING count(*) > 1
→ Apicultrice 02 | varroa | {"Moussa Sarr","Ibrahima Fall"}

### Le trigger qui la rétablit

On pose un trigger `BEFORE INSERT OR UPDATE ON suivi_formation` qui refuse si
l'apicultrice a déjà un autre formateur pour le même thème :

- Insertion de Fatou Ba chez Ibrahima Fall (varroa) :
  → ERROR: DF violée : cette apicultrice a déjà un formateur pour ce thème
- Insertion de Fatou Ba chez Khady Ndiaye (récolte, nouveau thème) :
  → INSERT 0 1

### Pourquoi `s.formateur_id <> NEW.formateur_id` dans la condition ?

Sans cette condition, le trigger refuserait une **mise à jour** qui ne change rien
(l'apicultrice est déjà chez ce formateur, ce formateur est déjà sur ce thème) :
sans l'exclusion, la ligne existante serait vue comme un conflit avec elle-même.
L'inégalité des `formateur_id` vérifie qu'on parle bien d'un **autre** formateur.

## Étape 6.4 · Revue BCNF du schéma Queen Bee entier

| Table | Clé primaire | Autres clés (UNIQUE) | DF non triviales | BCNF ? |
|---|---|---|---|---|
| site | id | — | id → nom, pays | oui : partie gauche = clé |
| cooperative | id | — | id → nom | oui |
| apicultrice | id | telephone | id → nom, telephone, site_id ; telephone → id (et tout le reste) | oui : les deux parties gauches sont des clés |
| ruche | id | code_ruche | id → code_ruche, lat, long, date, site_id, apicultrice_id ; code_ruche → id | oui |
| adhesion | (apicultrice_id, cooperative_id) | — | (apicultrice_id, cooperative_id) → date_adhesion | oui |
| compte | id | apicultrice_id (si non NULL) | id → login, hash, role, apicultrice_id, site_id | oui (le login sera UNIQUE au lab 4, et la cohérence rôle/site/apicultrice est garantie par `compte_role_coherent`) |
| mesure | id | (ruche_id, horodatage) | id → tout ; (ruche_id, horodatage) → tout le reste | oui |
| inspection | id | — | id → tout | oui |
| recolte | id | — | id → tout | oui |
| alerte | id | — | id → tout | oui |
| formateur | id | nom | id → nom, theme ; nom → theme | oui (les deux parties gauches sont des clés) |
| suivi_formation | (apicultrice_id, formateur_id) | — | (apicultrice_id, formateur_id) → ∅ | oui (table de pur lien) |

### Le cas `apicultrice.site_id` / `ruche.site_id` : règle métier ou coïncidence ?

La requête de vérification confirme que **chaque apicultrice n'a de ruches que
sur son propre site** dans le


## Étape 7.2 · La synthèse matérialisée et son prix

### Les deux temps

| Requête | Mesures parcourues | Execution Time |
|---|---|---|
| Tableau de bord brut (`mesure` + `ruche`) | 48 048 lignes, Seq Scan + Hash Join | **0.63 ms** |
| Tableau de bord sur la vue matérialisée `synthese_site_jour` | lecture directe de l'index | **~0.1 ms** |

Le tableau de bord devient ~200× plus rapide.

### Le prix : le vol invisible

Le 15 mars à 6 h, la ruche SN-CASA-001 perd 25 kg : poids passe de ~33 kg à 8.40 kg
(UC-CY04 : vol de ruche).

- Avant `REFRESH` : la synthèse montre `poids_min` normal, 192 mesures.
- Après `REFRESH MATERIALIZED VIEW CONCURRENTLY` : `poids_min = 8.40`, 193 mesures.

### Si la vue n'est rafraîchie que la nuit…

Un vol commis à 6 h du matin reste **invisible dans la synthèse jusqu'au prochain
rafraîchissement** (jusqu'à ~18 h si le cron tourne à minuit chaque nuit). C'est
une fenêtre d'exposition de **plusieurs heures** pendant laquelle un coordinateur
qui consulte le tableau de bord ne verra rien d'anormal.

### Où détecter un vol : dans la synthèse ou dans les mesures brutes ?

**Dans les mesures brutes**, pas dans la synthèse. Un vol est une **anomalie en
temps réel** : la synthèse agrège sur un pas journalier et par site, elle ne peut
pas détecter une chute brutale sur une ruche précise. Le détecteur de vol doit
lire `mesure` au fil de l'eau (ou un stream), comparer la nouvelle mesure à la
précédente pour cette ruche, et déclencher une alerte (table `alerte`) si la
chute dépasse un seuil. La synthèse sert aux tableaux de bord métier, pas à la
sécurité temps réel.

## Étape 7.3 · L'export pour le bailleur

### Pourquoi pas un simple hash ?

Un `sha256(telephone)` est trivialement cassable. Les téléphones ont ~1 million
de combinaisons possibles dans un préfixe donné (`+221 77 100 00 __`), donc on
essaie tous les hash en moins d'une seconde.

**Preuve** : avec le hash de Fatou Ndiaye et le début `+221 77 100 00`, retrouvé
en **___ ms** (ici : collez le temps mesuré avec `\timing on`).

### La bonne pseudonymisation : HMAC + clé secrète

HMAC = SHA-256 + une **clé secrète**. L'attaquant qui vole la vue mais pas la clé
ne peut plus essayer tous les téléphones : il lui manque la clé.

Trois précautions :

1. **La clé vit dans `cle_pseudonymisation`**, table à une seule ligne.
2. **`REVOKE ALL ON cle_pseudonymisation FROM PUBLIC`** : personne (hors
   propriétaire) ne peut la lire.
3. **La clé n'est pas dans la définition de la vue** : vérifié par la requête
   `SELECT position((SELECT cle ...) IN definition) > 0 FROM pg_views`.
   Résultat : `cle_visible = f`.

### Colonnes retirées, et pourquoi

| Colonne retirée | Raison |
|---|---|
| nom de l'apicultrice | donnée personnelle (RGPD) |
| téléphone | donnée personnelle (RGPD) |
| code_ruche | identifiant unique de la ruche, permettrait de la retrouver |
| latitude/longitude précises | 5 décimales = quelques mètres près, donc la ruche est localisable → risque de vol |

**Colonnes gardées** :

| Colonne gardée | Raison |
|---|---|
| apicultrice_pseudo (HMAC tronqué) | le bailleur veut une unité de comptage, pas l'identité |
| pays, site_nom | statistiques régionales utiles au bailleur |
| lat/lon arrondies à 0,1° (~11 km) | ordre de grandeur géographique, non exploitable |
| kg_valides | la preuve de production financée |

### RGPD

L'export reste une **donnée personnelle au sens du RGPD** : avec la clé, on
retrouve la personne. Il faut donc la même protection que la base principale
(stockage sécurisé, accès restreint, journal d'accès), même si le bailleur ne
voit que des chiffres.

## Étape 7.4 · Le journal d'audit (une copie voulue, protégée)

### Pourquoi `ligne_id` n'est-il PAS une clé étrangère vers `recolte` ?

Le journal doit **survivre à la suppression de la ligne qu'il décrit**. Si on
mettait `FOREIGN KEY (ligne_id) REFERENCES recolte(id)` :

- avec `ON DELETE CASCADE` : supprimer la récolte supprimerait sa trace →
  l'attaquant n'aurait qu'à effacer la récolte pour effacer la preuve.
- avec `ON DELETE RESTRICT` (défaut) : impossible de supprimer une récolte →
  blocage métier inacceptable (une récolte peut légitimement être supprimée).
- avec `ON DELETE SET NULL` : le journal garderait la trace mais plus le lien.
  Plus simple : ne pas mettre de FK du tout, `ligne_id` reste un `text` libre.

Le journal est une **archive immuable**, pas un index sur les tables actives.

### Pourquoi `avant` et `apres` en `jsonb` (lignes entières) ?

C'est accepté ici parce que :
- Les tables auditées sont petites (quelques champs par ligne).
- Enregistrer la ligne entière permet de **rejouer** l'état de la base à tout
  instant du passé, sans dépendre du schéma de l'époque.
- `jsonb` est indexable et compacté, donc le coût de stockage est raisonnable.

Limite : si les lignes contenaient des champs volumineux (texte long, blob),
il faudrait soit filtrer les champs inutiles, soit pointer vers un stockage
externe.

### Pourquoi `clock_timestamp()` et pas `now()` ?

Dans une transaction, `now()` renvoie **toujours** l'heure du `BEGIN`.
Si plusieurs opérations sont enregistrées dans la même transaction (ex.
`UPDATE recolte` qui déclenche le trigger d'audit), elles auraient toutes
le même horodatage. `clock_timestamp()` renvoie **l'heure réelle au moment
de l'appel**, donc chaque ligne de journal a son propre horodatage et l'ordre
chronologique est exact.

## Étape 8.2 · Les CHECK nommés

| Table | Contrainte | Règle |
|---|---|---|
| mesure | mesure_batterie_0_100 | batterie entre 0 et 100 |
| mesure | mesure_humidite_0_100 | humidité entre 0 et 100 |
| mesure | mesure_poids_positif | poids positif ou nul |
| alerte | alerte_statut_valide | statut ∈ {ouverte, en_cours, traitee} |
| alerte | alerte_type_valide | type ∈ {essaimage, vol, capteur_silencieux} (déjà en Jour 1) |
| alerte | alerte_confiance_valide | niveau entre 0 et 1 (déjà en Jour 1) |
| recolte | recolte_quantite_positive | quantité > 0 (corrigée en Jour 1) |
| recolte | recolte_statut_valide | statut ∈ {declaree, validee, refusee} |
| recolte | recolte_validation_coherente | validation complète ou absente |
| compte | compte_role_valide | role ∈ {apicultrice, coordinateur, gestionnaire, administrateur} |
| compte | compte_role_coherent | cohérence rôle ↔ apicultrice_id ↔ site_id (corrigée en Jour 1) |

Pourquoi des CHECK nommés : le message d'erreur cite le nom de la contrainte,
donc le développeur (ou le mainteneur) sait immédiatement **quelle règle métier**
a été violée, pas juste quelle colonne.

### Tests

- `batterie_pct = 150` → `ERROR: violates check constraint "mesure_batterie_0_100"` ✓
- `statut = 'fermee'` → `ERROR: violates check constraint "alerte_statut_valide"` ✓

## Étape 8.3 · Le trigger d'audit

### Trois fonctions

- **`qui()`** : retourne le rôle actif (`current_setting('role')` après `SET ROLE`),
  ou l'utilisateur connecté (`session_user`) si pas de `SET ROLE`. Permet de nommer
  le **vrai acteur** dans le journal, même quand la commande s'exécute via une
  fonction `SECURITY DEFINER`.

- **`audit_ligne()`** : trigger de ligne, `SECURITY DEFINER` avec
  `search_path = public, pg_temp` (anti-détournement). Écrit une ligne dans
  `journal_audit` avec `qui()`, la table, l'opération, l'`id`, et les versions
  JSONB `avant`/`apres`.

- **`journal_interdit()`** : trigger de refus. Lance une exception quelle que
  soit l'opération. Attaché en `BEFORE UPDATE OR DELETE` (par ligne) et en
  `BEFORE TRUNCATE` (par instruction) sur `journal_audit`.

### Attachement

- `recolte_audit` sur `recolte` → preuve de production (UC-C02).
- `compte_audit` sur `compte` → gestion des utilisateurs (UC-AD01).
- `journal_ajout_seul` + `journal_sans_truncate` → journal immuable.

### Tests

- `UPDATE recolte SET quantite_kg = 14` → 1 ligne de journal avec `avant_kg = 12.50`, `apres_kg = 14.00` ✓
- `UPDATE journal_audit SET acteur = 'pirate'` → refus ✓
- `DELETE FROM journal_audit` → refus ✓
- `TRUNCATE journal_audit` → refus ✓

### Limite : un superutilisateur peut désactiver un trigger

`ALTER TABLE journal_audit DISABLE TRIGGER journal_ajout_seul` passe sous
`postgres` (propriétaire). Trois conséquences :

1. Ne jamais faire tourner l'application en `postgres`.
2. Copier le journal **hors de la base** (vers un SIEM) régulièrement, pour avoir
   une copie que le DBA lui-même ne peut pas modifier sur la base principale.
3. Le journal protège contre les attaques **par l'application**, pas contre
   un attaquant qui prend le serveur.

   ## Étape 8.4 · Les rôles et les vues de moindre privilège

### 4 groupes + 5 personnes

| Groupe (NOLOGIN) | Personne (LOGIN) | Rôle métier |
|---|---|---|
| qb_apicultrice | a.diop, awa.diop | déclarer ses récoltes, lire ses mesures |
| qb_coordinateur | coord.casa | valider les récoltes de son site |
| qb_gestionnaire | gest.beeafrica | lire la synthèse, l'export bailleur |
| qb_admin | admin.beeafrica | CRUD sur compte, lire le journal |

### Vues

- **v_moi** : son propre compte. Pas de FK vers apicultrice, pas de hash.
- **v_mes_ruches** : ses ruches (via `compte.apicultrice_id`).
- **v_mes_mesures** : mesures des ruches dans v_mes_ruches (sous-requête).
- **v_mes_recoltes** : ses récoltes **declarees** uniquement, avec `WITH CHECK OPTION`
  (empêche un INSERT qui donnerait une ligne invisible — statut = 'validee' par exemple).
- **v_ruches_site** : ruches du site du coordinateur, avec le téléphone de l'apicultrice
  (le coordinateur a besoin de contacter l'apicultrice pour une inspection urgente).
- **v_recoltes_site** : récoltes du site du coordinateur, pour qu'il voit lesquelles
  valider.

### GRANTs minimaux

L'apicultrice **n'a pas** `SELECT` sur `apicultrice`, `ruche` ou `mesure` directement.
Seules les vues lui sont ouvertes, et chaque vue filtre par `qui()`. Cela
rend la base **autonome** vis-à-vis de l'application : même si l'application est
bogguée et ne filtre pas, PostgreSQL le fait.

## Étape 8.5 · La validation d'une récolte, par fonction

### Pourquoi une fonction et pas un UPDATE direct ?

Donner `UPDATE ON recolte TO qb_coordinateur` serait trop large : le coordinateur
pourrait changer `quantite_kg`, le statut à `refusee` sans raison, ou la date.
La fonction `valider_recolte(uuid)` ne fait **qu'une chose** : passer `declaree`
→ `validee` sur une récolte de son site, avec son `id` comme `validee_par` et
`now()` comme `date_validation`.

### SECURITY DEFINER

La fonction tourne avec les droits de son **propriétaire** (postgres), pas de
son appelant (coord.casa). Le coordinateur n'a donc **aucun droit direct** sur
la table `recolte`, mais peut l'écrire **à travers** la fonction. Trois garde-fous :

1. `SET search_path = public, pg_temp` : un attaquant ne peut pas détourner la
   fonction en créant un objet dans un autre schéma.
2. `GRANT EXECUTE ... TO qb_coordinateur` seulement : l'apicultrice ne peut même
   pas appeler la fonction (elle obtient `permission denied for function`).
3. Vérifications métier dans le corps : rôle du compte, statut `declaree`,
   ruche du bon site. `GET DIAGNOSTICS ... ROW_COUNT = 0` → exception explicite.

### Tests

- coord.casa valide une récolte declaree de SN-CASA → OK (statut = validee, trace dans journal_audit via le trigger recolte_audit) ✓
- coord.casa revalide la même récolte → `ERROR: récolte introuvable, déjà traitée ou hors de votre site` ✓
- a.diop tente d'appeler la fonction → `ERROR: permission denied for function valider_recolte` ✓

## Étape 8.6 · Les 12 tests de contournement

12 tests, tous donnent le refus (ou l'acceptation) attendu :

| # | Qui | Tentative | Attendu | Observé |
|---|---|---|---|---|
| 1 | a.diop | `SELECT * FROM apicultrice` | permission denied | ✓ |
| 2 | a.diop | `SELECT * FROM v_mes_ruches` | ses ruches seulement | ✓ |
| 3 | a.diop | `INSERT INTO v_mes_recoltes` sur sa ruche | accepté | ✓ |
| 4 | a.diop | `INSERT INTO v_mes_recoltes` sur une autre ruche | CHECK OPTION | ✓ |
| 5 | a.diop | `INSERT INTO recolte ... statut = 'validee'` | permission denied | ✓ |
| 6 | a.diop | `UPDATE recolte SET quantite_kg = 99` | permission denied | ✓ |
| 7 | a.diop | `SELECT valider_recolte(...)` | permission denied | ✓ |
| 8 | a.diop | `INSERT INTO journal_audit` | permission denied | ✓ |
| 9 | a.diop | `ALTER TABLE recolte DISABLE TRIGGER` | must be owner | ✓ |
| 10 | coord.casa | revalider la même récolte | refus explicite | ✓ |
| 11 | coord.casa | valider une récolte d'un autre site | refus explicite | ✓ |
| 12 | admin.beeafrica | `DELETE FROM compte` | permission denied (seuls SELECT/INSERT/UPDATE) | ✓ |

**Le journal nomme les vrais acteurs** : les actions de a.diop (via v_mes_recoltes)
et de coord.casa (via valider_recolte) apparaissent dans `journal_audit.acteur`
comme `a.diop` et `coord.casa`, grâce à la fonction `qui()` et à
`SET search_path` sur les fonctions SECURITY DEFINER.