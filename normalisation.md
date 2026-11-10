# Normalisation – Queen Bee

## Les trois anomalies et leurs causes

| Anomalie | Ce qui se passe | DF en cause |
|---|---|---|
| **Mise à jour** | Modifier le pays sur une seule ligne crée un pays fantôme ; l'enquête par pays passe de 3 à 4 pays. | `site_id → pays` : le pays dépend du site, pas de la mesure. Recopié sur chaque mesure du site, il peut diverger. |
| **Suppression** | Supprimer les mesures de Fatou Ndiaye fait disparaître son nom, son téléphone et sa coopérative — elle n'existe plus dans `extrait_plat`. | `telephone → apicultrice` et `apicultrice, site_id → telephone, cooperative` : ces faits sont hébergés dans les lignes de mesure ; sans mesure, pas d'apicultrice. |
| **Insertion** | Impossible d'enregistrer le site « Bamenda, Cameroun » tant qu'il n'y a pas une ruche avec une mesure, à cause du `NOT NULL` sur la clé primaire `(ruche_code, horodatage)`. | `site_id → site_nom, pays` : un fait sur le site ne peut pas exister sans la clé des mesures. |

## Diagnostic par forme normale

| Forme normale | Règle | DF de `extrait_plat` qui la violent |
|---|---|---|
| **1NF** | chaque case contient une seule valeur | aucune : toutes les cases sont atomiques (`pays` est un seul mot, `telephone` est une seule chaîne, pas de liste ni de `{… ; …}`). |
| **2NF** | aucune colonne non-clé ne dépend d'une PARTIE de la clé `(ruche_code, horodatage)` | `ruche_code → site_id, apicultrice, telephone, cooperative` — ces colonnes dépendent de `ruche_code` seul, pas du couple. Donc `pays`, `apicultrice`, etc. sont recopiés 48 fois par ruche sans raison. |
| **3NF** | aucune colonne ne dépend d'une colonne qui n'est pas la clé (pas de « transitive ») | `site_id → site_nom, pays` (site_id n'est pas la clé) et `telephone → apicultrice, cooperative` (telephone non plus). On a `(ruche_code, horodatage) → site_id → pays` : le pays dépend du site, pas directement de la clé. |
| **BCNF** | la partie gauche de toute DF doit être une clé candidate | les DF ci-dessus (site_id → …, ruche_code → …, telephone → …) ont une partie gauche qui n'est PAS une clé candidate de `extrait_plat`. 2NF, 3NF et BCNF sont toutes violées. |

**Conclusion partielle** : `extrait_plat` est en 1NF seulement. C'est ce qui ouvre la porte aux trois anomalies ci-dessus.


## Vérification BCNF des tables `norm`

| Table | Clé | DF restantes | BCNF ? |
|---|---|---|---|
| norm.site | site_id | site_id → site_nom, pays | oui : partie gauche = clé |
| norm.apicultrice | telephone | telephone → apicultrice, site_id, cooperative | oui : partie gauche = clé |
| norm.ruche | ruche_code | ruche_code → telephone | oui : partie gauche = clé |
| norm.mesure | (ruche_code, horodatage) | (ruche_code, horodatage) → poids_kg, temp_int_c | oui : partie gauche = clé |

**Correction post-rendu :** `norm.ruche` ne stocke plus `site_id`. On avait au départ
`norm.ruche (ruche_code, site_id, telephone)`, mais puisque `norm.apicultrice` contient déjà
`telephone → site_id`, garder `site_id` dans `norm.ruche` aurait été une
**dépendance transitive** (`ruche_code → telephone → site_id`), donc une violation 3NF/BCNF —
le même défaut qu'on reprochait à `extrait_plat`. Le site d'une ruche se déduit maintenant
par jointure : `ruche → apicultrice → site`, ce qui garantit qu'il ne peut jamais y avoir
deux versions contradictoires du site d'une ruche.

**Hypothèse métier assumée :** une ruche vit sur le site de son apicultrice. Si ce n'était
plus vrai (une apicultrice pouvant avoir des ruches sur plusieurs sites), il faudrait
créer une table `norm.ruche_site (ruche_code, site_id)` avec sa propre clé étrangère,
et non pas dupliquer `site_id` dans `norm.ruche`.

Toutes les tables sont en **BCNF** : la partie gauche de chaque DF est la clé primaire
de sa table. Aucune donnée n'est recopiée.

## Preuve sans perte

La comparaison `extrait_plat` ⇔ `norm.reconstruit` (vue qui joint les 4 tables)
renvoie **0 ligne** dans les deux sens :

(SELECT * FROM extrait_plat EXCEPT SELECT * FROM norm.reconstruit)
UNION ALL
(SELECT * FROM norm.reconstruit EXCEPT SELECT * FROM extrait_plat);
→ 0 lignes

La jointure redonne exactement les données de départ : la décomposition est
**sans perte** au sens strict (lossless join).

## Attaques rejouées après normalisation

| Attaque | Sur extrait_plat | Sur norm |
|---|---|---|
| Un second pays pour SN-KOLD | accepté (fantôme « Senegal » créé) | **refus** : `duplicate key value violates unique constraint "site_pkey"` |
| Un site sans ruche (Bamenda) | refus (NOT NULL sur la clé composée) | **accepté** : INSERT 0 1 — le site vit indépendamment de ses mesures |
| Modifier une seule copie d'un fait | créait un fantôme | impossible : le fait n'existe qu'à un seul endroit |

## Conclusion

Une seule ligne modifiée a fait passer l'enquête par pays de **3 à 4 pays**
sur `extrait_plat`. La même attaque sur les tables `norm` est soit impossible
(la clé primaire sur `site_id` interdit les doublons), soit modifie tout le
monde en même temps (`UPDATE norm.site SET pays = ...`) : la base ne peut
plus se contredire.

Une base non normalisée ne peut pas servir de preuve : les mêmes faits
y vivent en plusieurs exemplaires qui peuvent diverger silencieusement,
sans qu'aucune règle technique ne le détecte.