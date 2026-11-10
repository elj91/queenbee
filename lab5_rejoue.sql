-- lab5_rejoue.sql : rejoue le Lab 5 de bout en bout, de façon automatique.
-- Attendu : la preuve finale (requête EXCEPT croisée) retourne 0 ligne.
--
-- Ce fichier s'enchaîne après schema.sql + donnees.sql :
--   psql -U postgres -h localhost -d queenbee -v ON_ERROR_STOP=1 -f schema.sql
--   psql -U postgres -h localhost -d queenbee -v ON_ERROR_STOP=1 -f donnees.sql
--   psql -U postgres -h localhost -d queenbee -v ON_ERROR_STOP=1 -f plat.sql
--   psql -U postgres -h localhost -d queenbee -v ON_ERROR_STOP=1 -f anomalies.sql
--   psql -U postgres -h localhost -d queenbee -v ON_ERROR_STOP=1 -f lab5_rejoue.sql


-- ──────────────────────────────────────────────
-- 1. Nettoyage des incohérences introduites par anomalies.sql
--    (qui étaient volontaires : Sénégal → Senegal sur une ligne,
--     +221 77 100 00 03 → +221 99 99 99 99 sur trois mesures d'Awa Diop)
-- ──────────────────────────────────────────────

UPDATE extrait_plat SET pays = 'Sénégal'
WHERE pays = 'Senegal';

UPDATE extrait_plat SET telephone = '+221 77 100 00 03'
WHERE telephone = '+221 99 99 99 99';

-- Vérification : plus aucun site ne doit avoir plusieurs pays
DO $$
DECLARE conflits int;
BEGIN
    SELECT count(*) INTO conflits
    FROM (SELECT site_id FROM extrait_plat GROUP BY site_id HAVING count(DISTINCT pays) > 1) s;
    IF conflits > 0 THEN
        RAISE EXCEPTION 'Nettoyage incomplet : % site(s) avec plusieurs pays', conflits;
    END IF;
END $$;

-- Si l'anomalie 3 a posé une clé primaire sur (ruche_code, horodatage), on la retire :
-- la table originale n'en avait pas. On ne veut pas garder un effet de bord.
ALTER TABLE extrait_plat DROP CONSTRAINT IF EXISTS extrait_plat_pkey;


-- ──────────────────────────────────────────────
-- 2. Migration BCNF : on relance migration_3nf.sql (via \i)
-- ──────────────────────────────────────────────

\i migration_3nf.sql


-- ──────────────────────────────────────────────
-- 3. Vue de reconstruction (si pas déjà créée dans migration_3nf.sql)
-- ──────────────────────────────────────────────

CREATE OR REPLACE VIEW norm.reconstruit AS
SELECT r.ruche_code,
       s.site_id,
       s.site_nom,
       s.pays,
       a.apicultrice,
       a.telephone,
       a.cooperative,
       m.horodatage,
       m.poids_kg,
       m.temp_int_c
FROM norm.mesure m
JOIN norm.ruche r        ON r.ruche_code = m.ruche_code
JOIN norm.apicultrice a  ON a.telephone  = r.telephone
JOIN norm.site s         ON s.site_id    = a.site_id;


-- ──────────────────────────────────────────────
-- 4. Preuve sans perte : EXCEPT croisé doit renvoyer 0 ligne
-- ──────────────────────────────────────────────

\echo 'Preuve sans perte (attendu : 0 ligne) :'

SELECT count(*) AS lignes_de_difference FROM (
    (SELECT * FROM extrait_plat   EXCEPT SELECT * FROM norm.reconstruit)
    UNION ALL
    (SELECT * FROM norm.reconstruit EXCEPT SELECT * FROM extrait_plat)
) AS diff;

-- Vérification bloquante : si ce n'est pas 0, on fait planter le script
DO $$
DECLARE diff_rows int;
BEGIN
    SELECT count(*) INTO diff_rows FROM (
        (SELECT * FROM extrait_plat   EXCEPT SELECT * FROM norm.reconstruit)
        UNION ALL
        (SELECT * FROM norm.reconstruit EXCEPT SELECT * FROM extrait_plat)
    ) AS diff;
    IF diff_rows <> 0 THEN
        RAISE EXCEPTION 'Décomposition avec perte : % ligne(s) de différence', diff_rows;
    END IF;
END $$;


-- ──────────────────────────────────────────────
-- 5. Comptes de contrôle
-- ──────────────────────────────────────────────

\echo 'Comptes après migration (attendu : 4 sites, 8 apicultrices, 11 ruches, 528 mesures) :'

SELECT (SELECT count(*) FROM norm.site)        AS sites,
       (SELECT count(*) FROM norm.apicultrice) AS apicultrices,
       (SELECT count(*) FROM norm.ruche)       AS ruches,
       (SELECT count(*) FROM norm.mesure)      AS mesures;