## Question 1 
Les 10 choses de Queen Bee :

Site rucher : plusieurs informations (nom, pays), 8 exemplaires
Ruche : code, position GPS, date d’installation
Apicultrice : nom, téléphone
Coopérative : l’apicultrice adhère à une ou plusieurs coopératives, donc elles existent en plusieurs exemplaires
Mesure : poids, température intérieure, température extérieure, humidité, activité sonore, batterie
Inspection : état de la colonie, présence de la reine, observations
Récolte : date, quantité
Alerte : type (essaimage, vol, capteur silencieux), niveau de confiance
Compte utilisateur : pour se connecter, avec un rôle



## Question 2 

| Chose | Ce qu'on garde | Ce qui la distingue |
|---|---|---|
| Site rucher | nom, pays | un numéro attribué (deux sites peuvent avoir le même nom dans des pays différents) |
| Ruche | code, position GPS, date d'installation | le code (ex. SN-CASA-014) |
| Apicultrice | nom, téléphone | un numéro attribué (deux apicultrices peuvent avoir le même nom) |
| Coopérative | nom | un numéro attribué (ou le nom, s'il est garanti unique) |
| Mesure | date et heure, poids, température intérieure, température extérieure, humidité, activité sonore, niveau de batterie | le capteur et l'heure |
| Inspection | date, état de la colonie, présence de la reine, observations | la ruche et la date (un numéro attribué si plusieurs inspections par jour) |
| Récolte | date, quantité, statut de validation | un numéro attribué (une ruche peut être récoltée plusieurs fois le même jour) |
| Alerte | type, niveau de confiance, date et heure de déclenchement | un numéro attribué |
| Compte utilisateur | identifiant de connexion, mot de passe, rôle | un numéro attribué (ou l'identifiant de connexion, s'il est unique) |



## Question 3 

| Lien | Dans un sens | Dans l'autre sens |
|---|---|---|
| ruche – apicultrice | une ruche appartient à une seule apicultrice | une apicultrice possède zéro, une ou plusieurs ruches |
| site – ruche | une ruche est installée sur un seul site | un site accueille zéro, une ou plusieurs ruches |
| apicultrice – coopérative | une apicultrice adhère à une ou plusieurs coopératives | une coopérative a plusieurs adhérentes |
| ruche – mesure | une mesure provient d'une seule ruche | une ruche a zéro, une ou plusieurs mesures |
| ruche – récolte | une récolte porte sur une seule ruche | une ruche a zéro, une ou plusieurs récoltes |
| coordinateur – récolte validée | une récolte est validée par au plus un coordinateur (zéro tant qu'elle n'est pas validée) | un coordinateur valide zéro, une ou plusieurs récoltes |
| apicultrice – compte de connexion | une apicultrice a au plus un compte | un compte appartient au plus à une apicultrice (un compte de gestionnaire ou d'administrateur n'est lié à aucune apicultrice) |



## Question 4

| Question au client | Notre hypothèse |
|---|---|
| Une ruche peut-elle changer d'apicultrice (transmission, départ) ? | oui, mais on ne garde que l'apicultrice actuelle |
| Une ruche peut-elle avoir plusieurs capteurs ? | non, un seul capteur par ruche à la fois |
| Peut-on faire plusieurs inspections de la même ruche le même jour ? | oui, donc une inspection reçoit un numéro attribué |
| Un coordinateur est-il rattaché à un seul site ou à plusieurs ? | un seul site |
| Une personne peut-elle avoir plusieurs rôles (apicultrice et coordinatrice par exemple) ? | non, un compte a un seul rôle |


## Question 5

1. Position GPS des ruches : repérer où elles sont pour les voler (ruches, miel, matériel). Les alertes « vol » existent précisément pour ça : celui qui connaît les positions sait où frapper.

2. Récoltes déclarées (date, quantité) et leur validation : gonfler ou inventer des quantités pour toucher plus (primes, paiements, ventes), ou faire valider de fausses récoltes. Une fausse récolte validée fausse aussi les chiffres de l'association.

3. Identifiants de connexion et rôles (login, mot de passe, rôle) : se connecter à la place d'un coordinateur ou d'un administrateur, valider ses propres récoltes, effacer des alertes ou lire toutes les données.

## Partie C · Sensibilité et menaces (STRIDE)

| Entité | Sensibilité | Qui lit | Qui modifie | Menace STRIDE et ce que gagne l'attaquant |
|---|---|---|---|---|
| SITE RUCHER | interne | tous les rôles | gestionnaire, administrateur | I : connaître les 8 sites pour cibler ceux à voler |
| RUCHE | confidentielle | apicultrice propriétaire, coordinateur du site, gestionnaire, administrateur | apicultrice propriétaire, administrateur | I : connaître la position GPS pour voler la ruche |
| APICULTRICE | confidentielle (téléphone) | l'apicultrice elle-même, coordinateur du site, gestionnaire, administrateur | l'apicultrice elle-même, administrateur | I : démarchage, hameçonnage ciblé |
| COOPÉRATIVE | publique | tous les rôles | gestionnaire, administrateur | T : ajouter une fausse adhésion pour bénéficier d'aides |
| COMPTE | critique | administrateur | administrateur, titulaire (son mot de passe) | S : se connecter à la place d'un coordinateur pour valider ses propres récoltes |
| MESURE | interne | apicultrice propriétaire, coordinateur, gestionnaire, administrateur | aucun (écrit par le capteur, jamais modifié) | **T (rejeu) : renvoyer une ancienne mesure de poids pour masquer un vol en cours** |
| INSPECTION | interne | apicultrice propriétaire, coordinateur, gestionnaire | apicultrice qui l'a faite, administrateur | R : nier avoir constaté la perte de la reine |
| RÉCOLTE | confidentielle | apicultrice propriétaire, coordinateur du site, gestionnaire | apicultrice (déclaration), coordinateur (validation) | **R : récolte validée sans trace du coordinateur qui l'a validée, impossible de remonter à lui** |
| ALERTE | interne | coordinateur, gestionnaire, administrateur | système (création), coordinateur (traitement) | D : saturer le système d'alertes pour qu'un vrai vol passe inaperçu |
| HISTORIQUE DES ACTIONS (journal) | critique | administrateur | aucun (ajout seulement) | **E : un compte efface l'historique pour masquer ses actions, puis se donne des droits** |


## Lab 2
## Schéma relationnel



| Table | Clé primaire | Autres colonnes | Clés étrangères (vers quelle table) |
|---|---|---|---|
| site | id (text, ex. SN-CASA) | nom, pays | — |
| cooperative | id (uuid) | nom | — |
| apicultrice | id (uuid) | nom, telephone | site_id (site) |
| ruche | id (uuid) | code_ruche (UNIQUE), position_gps, date_installation | site_id (site), apicultrice_id (apicultrice) |
| mesure | id (bigint, généré) | horodatage, poids_kg, temperature_int, temperature_ext, humidite_pct, activite_sonore, batterie_pct | ruche_id (ruche) |
| inspection | id (uuid) | date_inspection, etat_colonie, reine_presente, observations | ruche_id (ruche), apicultrice_id (apicultrice) |
| recolte | id (uuid) | date_recolte, quantite_kg, statut, date_validation | ruche_id (ruche), validee_par (compte) |
| alerte | id (uuid) | horodatage, type, niveau_confiance | ruche_id (ruche) |
| compte | id (uuid) | login, mot_de_passe, role | apicultrice_id (apicultrice) UNIQUE, site_id (site) |
| adhesion | (apicultrice_id, cooperative_id) — clé composée | date_adhesion | apicultrice_id (apicultrice), cooperative_id (cooperative) |
