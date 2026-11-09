-- tests_schema.sql : essayer de casser la base
-- l'attendu puis l'obtenu (collé après exécution).


-- ──────────────────────────────────────────────
-- Test 1 : une ruche dont l'apicultrice n'existe pas
-- Attendu : refus (violation de ruche_apicultrice_fk)
-- ──────────────────────────────────────────────
INSERT INTO ruche (code_ruche, site_id, apicultrice_id, latitude, longitude, date_installation)
VALUES ('XX-TEST-001', 'SN-CASA', gen_random_uuid(), 12.5, -16.2, DATE '2026-11-09');
-- Obtenu :
-- ERROR:  insert or update on table "ruche" violates foreign key constraint "ruche_apicultrice_fk"


-- ──────────────────────────────────────────────
-- Test 2 : supprimer une apicultrice qui a des ruches
-- Attendu : refus (la clé étrangère ruche_apicultrice_fk protège l'apicultrice)
-- ──────────────────────────────────────────────
DELETE FROM apicultrice
WHERE telephone = '+221 77 100 00 03';   -- Awa Diop, qui a 3 ruches
-- Obtenu :
-- ERROR:  update or delete on table "apicultrice" violates foreign key constraint "ruche_apicultrice_fk" on table "ruche"


-- ──────────────────────────────────────────────
-- Test 3 : une ruche sans apicultrice
-- Attendu : refus (NOT NULL sur ruche.apicultrice_id)
-- ──────────────────────────────────────────────
INSERT INTO ruche (code_ruche, site_id, apicultrice_id, latitude, longitude, date_installation)
VALUES ('XX-TEST-003', 'SN-CASA', NULL, 12.5, -16.2, DATE '2026-11-09');
-- Obtenu :
-- ERROR:  null value in column "apicultrice_id" of relation "ruche" violates not-null constraint


-- ──────────────────────────────────────────────
-- Test 4 : une table SANS clé étrangère ; y mettre une ruche orpheline,
--          puis la joindre aux apicultrices
-- Attendu : INSERT accepté, puis 0 ligne retournée (l'orpheline devient invisible)
-- ──────────────────────────────────────────────
DROP TABLE IF EXISTS ruche_libre;
CREATE TABLE ruche_libre (
    code_ruche     text PRIMARY KEY,
    apicultrice_id uuid NOT NULL           -- pas de REFERENCES : aucune protection
);
INSERT INTO ruche_libre (code_ruche, apicultrice_id)
VALUES ('XX-LIBRE-001', gen_random_uuid());   -- UUID bidon, n'existe pas dans apicultrice

-- Le JOIN ne trouve personne : la ruche orpheline disparaît silencieusement du résultat
SELECT rl.code_ruche, a.nom
FROM ruche_libre rl
JOIN apicultrice a ON a.id = rl.apicultrice_id;
-- Obtenu : 0 ligne

DROP TABLE ruche_libre;
-- Leçon : sans clé étrangère, les données orphelines s'ajoutent sans problème
-- et deviennent invisibles aux jointures — pire qu'une erreur, car silencieux.


-- ──────────────────────────────────────────────
-- Test 5 : une table avec id serial ; y insérer 3 lignes
-- Attendu : les id sont 1, 2, 3 — devinables (/objets/1 → /objets/2)
-- ──────────────────────────────────────────────
DROP TABLE IF EXISTS cible_devinable;
CREATE TABLE cible_devinable (
    id     serial PRIMARY KEY,
    donnee text
);
INSERT INTO cible_devinable (donnee) VALUES ('premier'), ('deuxieme'), ('troisieme');
SELECT * FROM cible_devinable;
-- Obtenu : id = 1, 2, 3
-- Leçon : un id serial est trivial à énumérer par un attaquant qui connaît une URL.

DROP TABLE cible_devinable;


-- ──────────────────────────────────────────────
-- Test 6 : une mesure déjà reçue (même ruche, même instant)
-- Attendu : refus (UNIQUE anti-rejeu sur (ruche_id, horodatage))
-- ──────────────────────────────────────────────
INSERT INTO mesure (ruche_id, horodatage, poids_kg, temperature_int, temperature_ext, humidite_pct, activite_sonore, batterie_pct)
SELECT ruche_id, horodatage, 99.99, 35.0, 25.0, 55, 50, 80
FROM mesure
ORDER BY horodatage LIMIT 1;
-- Obtenu :
-- ERROR:  duplicate key value violates unique constraint "mesure_ruche_id_horodatage_key"


-- ──────────────────────────────────────────────
-- Test 7 : les ruches dont le site diffère de celui de leur apicultrice
-- Attendu : 0 ligne (hypothèse du lab 1 : une apicultrice est rattachée à un seul site,
--           et ses ruches vivent sur ce même site)
-- ──────────────────────────────────────────────
SELECT r.code_ruche, r.site_id AS site_ruche, a.site_id AS site_apicultrice
FROM ruche r
JOIN apicultrice a ON a.id = r.apicultrice_id
WHERE r.site_id <> a.site_id;
-- Obtenu : 0 ligne
-- Remarque : rien dans le schéma ne force cette cohérence ; c'est le jeu d'essai qui la respecte.
-- Pour la garantir, il faudrait un trigger ou une contrainte composée.


-- ──────────────────────────────────────────────
-- Test 8 : passer une récolte « déclarée » à « validée » sans validateur
-- Attendu : refus (CHECK sur la cohérence statut / validee_par / date_validation)
-- ──────────────────────────────────────────────
UPDATE recolte
SET statut = 'validee'
WHERE statut = 'declaree'
  AND id = (SELECT id FROM recolte WHERE statut = 'declaree' LIMIT 1);
-- Obtenu :
-- ERROR:  new row for relation "recolte" violates check constraint "recolte_check"


-- ──────────────────────────────────────────────
-- Conclusion
-- ──────────────────────────────────────────────
-- Question : un UUID suffit-il à protéger la ruche d'une autre apicultrice ?
--
-- Non. L'UUID empêche seulement de DEVINER l'identifiant d'une ressource (pas de /ruches/42
-- → /ruches/43). Il ne dit rien sur QUI a le droit de la lire ou de la modifier.
-- Deux failles restent possibles :
--   1. Fuite d'UUID : un UUID qui sort dans une URL, un log, un email, un screenshot,
--      est aussi exploitable qu'un id = 42 une fois connu.
--   2. Absence d'autorisation : si l'application ne vérifie pas que
--      ruche.apicultrice_id = compte_courant.apicultrice_id (ou le rôle du compte),
--      n'importe qui connaissant l'UUID peut lire ou modifier la ruche.
-- L'UUID protège contre l'énumération ; il ne remplace jamais le contrôle d'accès.