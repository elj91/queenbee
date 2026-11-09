# Dépendances fonctionnelles – Queen Bee

## Les DF de extrait_plat

| DF | En français |
|---|---|
| site_id → site_nom, pays | un site a un seul nom et un seul pays |
| ruche_code → site_id, apicultrice, telephone, cooperative | le code identifie une ruche, donc son site, son apicultrice (et son téléphone, sa coopérative) |
| telephone → apicultrice, site_id, cooperative | le téléphone est propre à une apicultrice (deux Aminata Diop ont deux téléphones), donc à son site et à sa coopérative |
| apicultrice, site_id → telephone, cooperative | le nom seul ne suffit pas (homonymes) ; le nom + site identifie une apicultrice, donc son téléphone et sa coopérative |
| ruche_code, horodatage → poids_kg, temp_int_c | une seule mesure par ruche et par instant (UNIQUE anti-rejeu du lab 2) |

## Fermetures

### {site_id}⁺

| Tour | DF utilisée | {site_id}⁺ |
|---|---|---|
| 0 | aucune | {site_id} |
| 1 | site_id → site_nom, pays | + site_nom, pays |
| 2 | plus rien ne s'ajoute | 3 colonnes sur 10 : **pas une clé** |

### {ruche_code}⁺

| Tour | DF utilisée | {ruche_code}⁺ |
|---|---|---|
| 0 | aucune | {ruche_code} |
| 1 | ruche_code → site_id, apicultrice, telephone, cooperative | + site_id, apicultrice, telephone, cooperative |
| 2 | site_id → site_nom, pays | + site_nom, pays |
| 3 | plus rien ne s'ajoute | 7 colonnes sur 10 : **pas une clé** (il manque horodatage, poids_kg, temp_int_c) |

### {ruche_code, horodatage}⁺

| Tour | DF utilisée | {ruche_code, horodatage}⁺ |
|---|---|---|
| 0 | aucune | {ruche_code, horodatage} |
| 1 | ruche_code → site_id, apicultrice, telephone, cooperative | + site_id, apicultrice, telephone, cooperative |
| 2 | site_id → site_nom, pays | + site_nom, pays |
| 3 | ruche_code, horodatage → poids_kg, temp_int_c | + poids_kg, temp_int_c |
| 4 | plus rien ne s'ajoute | **10 colonnes sur 10 : c'est une clé** |

## Clé candidate

**{ruche_code, horodatage}** est la clé candidate de `extrait_plat`.

On ne peut rien en retirer :
- Retirer `horodatage` : il reste `{ruche_code}`, qui ne donne que 7 colonnes (il manque `horodatage`, `poids_kg`, `temp_int_c` — une ruche a 48 mesures différentes).
-

## Ce qui se passerait si l'application identifiait les apicultrices par leur nom

La fausse DF `apicultrice → telephone` a mis en évidence deux « Aminata Diop » avec
deux téléphones différents. Identifier une apicultrice par son nom reviendrait à
fusionner ces deux personnes :
- leurs ruches seraient attribuées à la mauvaise personne,
- une inspection faite par l'Aminata Diop de SN-CASA serait imputée à celle de SN-KOLD,
- une alerte de vol sur une ruche remonterait à la mauvaise apicultrice,
- un compte de connexion donnerait accès aux ruches de l'autre.
C'est pourquoi la clé primaire d'`apicultrice` est un UUID, et que le nom seul ne
suffit jamais à retrouver une apicultrice : il faut le couple (nom, site), ou le
téléphone, ou l'UUID directement.