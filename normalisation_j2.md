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