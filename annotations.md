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