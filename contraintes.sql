-- contraintes.sql : vérifier les DF, puis durcir les logins
-- Chaque bloc s'exécute dans le Query Tool de pgAdmin ; le résultat est collé en commentaire.


-- ──────────────────────────────────────────────
-- Étape 4.3 · Confronter les DF aux données
-- ──────────────────────────────────────────────
-- Principe : une DF X → Y est vraie si et seulement si aucune valeur de X
-- n'est associée à plusieurs valeurs distinctes de Y. On teste donc :
--   SELECT X FROM extrait_plat GROUP BY X HAVING count(DISTINCT Y) > 1;
-- Attendu : 0 ligne pour une vraie DF.


-- DF1 : site_id → site_nom, pays
SELECT site_id, count(DISTINCT (site_nom, pays)) AS versions
FROM extrait_plat
GROUP BY site_id
HAVING count(DISTINCT (site_nom, pays)) > 1;
-- Résultat : 0 ligne


-- DF2 : ruche_code → site_id, apicultrice, telephone, cooperative
SELECT ruche_code, count(DISTINCT (site_id, apicultrice, telephone, cooperative)) AS versions
FROM extrait_plat
GROUP BY ruche_code
HAVING count(DISTINCT (site_id, apicultrice, telephone, cooperative)) > 1;
-- Résultat : 0 ligne


-- DF3 : telephone → apicultrice, site_id, cooperative
SELECT telephone, count(DISTINCT (apicultrice, site_id, cooperative)) AS versions
FROM extrait_plat
GROUP BY telephone
HAVING count(DISTINCT (apicultrice, site_id, cooperative)) > 1;
-- Résultat : 0 ligne


-- DF4 : (apicultrice, site_id) → telephone, cooperative
SELECT apicultrice, site_id, count(DISTINCT (telephone, cooperative)) AS versions
FROM extrait_plat
GROUP BY apicultrice, site_id
HAVING count(DISTINCT (telephone, cooperative)) > 1;
-- Résultat : 0 ligne


-- DF5 : (ruche_code, horodatage) → poids_kg, temp_int_c
SELECT ruche_code, horodatage, count(DISTINCT (poids_kg, temp_int_c)) AS versions
FROM extrait_plat
GROUP BY ruche_code, horodatage
HAVING count(DISTINCT (poids_kg, temp_int_c)) > 1;
-- Résultat : 0 ligne


-- Fausse DF : apicultrice → telephone
-- Attendu : « Aminata Diop » avec 2 téléphones (homonymes).
SELECT apicultrice, count(DISTINCT telephone) AS nb_telephones
FROM extrait_plat
GROUP BY apicultrice
HAVING count(DISTINCT telephone) > 1;
-- Résultat : 1 ligne  →  Aminata Diop  |  2


-- Conséquence (à copier aussi dans dependances.md) :
-- Si l'application identifiait les apicultrices par leur NOM, elle fusionnerait les
-- deux « Aminata Diop ». Ruches, mesures, inspections, récoltes et comptes seraient
-- attribués à la mauvaise personne. C'est pour ça que la clé primaire est un UUID,
-- et que le couple (nom, site) ou le téléphone servent à retrouver la bonne ligne,
-- jamais le nom seul.


-- ──────────────────────────────────────────────
-- Étape 4.4 · Rendre les logins uniques
-- Exécuter UNE COMMANDE À LA FOIS, dans l'ordre, dans le Query Tool.
-- ──────────────────────────────────────────────


-- Commande 1 : afficher les logins en double
SELECT c.login, a.nom, a.site_id
FROM compte c
LEFT JOIN apicultrice a ON a.id = c.apicultrice_id
WHERE c.login IN (
    SELECT login FROM compte GROUP BY login HAVING count(*) > 1
)
ORDER BY c.login, a.nom;
-- Résultat attendu : 3 lignes
--   a.diop | Aminata Diop   | SN-CASA
--   a.diop | Aminata Diop   | SN-KOLD
--   a.diop | Awa Diop       | SN-CASA


-- Commande 2 : poser la contrainte UNIQUE sur login → DOIT ÉCHOUER
ALTER TABLE compte ADD CONSTRAINT compte_login_unique UNIQUE (login);
-- Résultat :
-- ERROR:  could not create unique index "compte_login_unique"
-- DETAIL: Key (login)=(a.diop) is duplicated.


-- Commande 3 : donner un login différent à chaque personne
-- Convention : initiale + "." + nom + suffixe du site si collision
UPDATE compte
SET login = 'a.diop.sncasa'
WHERE id = (SELECT c.id
            FROM compte c JOIN apicultrice a ON a.id = c.apicultrice_id
            WHERE a.nom = 'Aminata Diop' AND a.site_id = 'SN-CASA');

UPDATE compte
SET login = 'a.diop.snkold'
WHERE id = (SELECT c.id
            FROM compte c JOIN apicultrice a ON a.id = c.apicultrice_id
            WHERE a.nom = 'Aminata Diop' AND a.site_id = 'SN-KOLD');

UPDATE compte
SET login = 'awa.diop'
WHERE id = (SELECT c.id
            FROM compte c JOIN apicultrice a ON a.id = c.apicultrice_id
            WHERE a.nom = 'Awa Diop');
-- Résultat : 3 × UPDATE 1


-- Commande 4 : poser la contrainte UNIQUE → DOIT PASSER MAINTENANT
ALTER TABLE compte ADD CONSTRAINT compte_login_unique UNIQUE (login);
-- Résultat : ALTER TABLE


-- Commande 5 : insérer A.Diop → ACCEPTÉ (majuscule différente)
INSERT INTO compte (login, mot_de_passe, role) VALUES ('A.Diop', 'x', 'administrateur');
-- Résultat : INSERT 0 1   (la contrainte UNIQUE ne voit pas 'a.diop.sncasa' ≠ 'A.Diop')

-- Puis suppression pour nettoyer avant la commande 6
DELETE FROM compte WHERE login = 'A.Diop';
-- Résultat : DELETE 1


-- Commande 6 : index unique insensible à la casse, puis retenter A.Diop → DOIT ÉCHOUER
CREATE UNIQUE INDEX compte_login_ci ON compte (lower(login));
INSERT INTO compte (login, mot_de_passe, role) VALUES ('A.Diop', 'x', 'administrateur');
-- Résultat :
-- CREATE INDEX
-- ERROR:  duplicate key value violates unique constraint "compte_login_ci"
-- DETAIL: Key (lower(login))=(a.diop) already exists


-- ──────────────────────────────────────────────
-- Conclusion : quelles lettres STRIDE un login partagé permet-il ?
-- ──────────────────────────────────────────────
-- S (Spoofing / usurpation) : trois personnes utilisent 'a.diop', donc n'importe
--   laquelle peut se présenter comme l'autre. L'authentification ne distingue plus
--   les identités.
-- R (Repudiation) : une action tracée comme faite par 'a.diop' ne désigne personne
--   en particulier. Les trois Diop peuvent toutes nier avoir agi : les logs sont
--   inutilisables comme preuve.
-- E (Elevation of privilege) : si l'une des trois Diop est administrateur et une autre
--   simple apicultrice, un login partagé laisse l'apicultrice hériter des droits de
--   l'admin sans qu'aucun acte malveillant explicite n'ait été nécessaire.
--
-- L'index unique sur lower(login) ajoute une seconde protection : il empêche
-- 'A.Diop' et 'a.diop' de coexister, car la plupart des écrans de connexion
-- ignorent la casse. Sans cet index, 'A.Diop' s'authentifierait comme 'a.diop'
-- côté application mais serait vu comme un compte différent côté base.