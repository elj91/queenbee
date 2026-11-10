-- formation.sql : décomposition BCNF des formations Queen Bee
-- Étape 6.1 : table reçue (formation_plat) + preuve des règles métier.
-- Les étapes 6.2 (découpage BCNF) et 6.3 (trigger) viennent en bas du fichier.


DROP TABLE IF EXISTS suivi_formation, formateur, formation_plat CASCADE;

-- ──────────────────────────────────────────────
-- Étape 6.1 · La table reçue
-- Chaque centre de formation envoie un tableau à plat : une ligne par apicultrice,
-- par thème, avec le nom du formateur. Clé primaire : (telephone, theme).
-- Les 8 lignes viennent du PDF.
-- ──────────────────────────────────────────────

CREATE TABLE formation_plat (
    telephone  text NOT NULL,
    theme      text NOT NULL,
    formateur  text NOT NULL,
    PRIMARY KEY (telephone, theme)
);

INSERT INTO formation_plat (telephone, theme, formateur) VALUES
    ('+221 77 100 00 01', 'varroa',   'Moussa Sarr'),
    ('+221 77 100 00 01', 'recolte',  'Khady Ndiaye'),
    ('+221 77 100 00 02', 'varroa',   'Moussa Sarr'),
    ('+221 77 200 00 01', 'varroa',   'Ibrahima Fall'),
    ('+221 77 200 00 01', 'capteurs', 'Oumar Diallo'),
    ('+225 07 100 00 01', 'varroa',   'Kouassi Yao'),
    ('+225 07 100 00 02', 'capteurs', 'Oumar Diallo'),
    ('+237 6 77 100 01',  'recolte',  'Khady Ndiaye');

-- ──────────────────────────────────────────────
-- Les trois tests de règles (attendu : 0 ligne chacun)
-- ──────────────────────────────────────────────

-- Règle 1 : (telephone, theme) est bien la clé primaire
-- ... pas besoin de tester : le PRIMARY KEY le garantit.

-- Règle 2 : un formateur n'enseigne qu'un thème
SELECT formateur, array_agg(DISTINCT theme) AS themes
FROM formation_plat
GROUP BY formateur
HAVING count(DISTINCT theme) > 1;
-- Attendu : 0 ligne

-- Règle 3 : pour un thème, une apicultrice n'a qu'un formateur
SELECT telephone, theme, array_agg(DISTINCT formateur) AS formateurs
FROM formation_plat
GROUP BY telephone, theme
HAVING count(DISTINCT formateur) > 1;
-- Attendu : 0 ligne

-- Règle en bonus : (telephone, formateur) est aussi une clé candidate
-- (puisque le formateur donne le thème)
SELECT telephone, formateur, count(*)
FROM formation_plat
GROUP BY telephone, formateur
HAVING count(*) > 1;
-- Attendu : 0 ligne

-- ──────────────────────────────────────────────
-- Étape 6.2 · Le mauvais découpage (par theme)
-- La colonne commune `theme` n'est clé d'AUCUN des deux morceaux :
-- une apicultrice a plusieurs thèmes, un thème a plusieurs formateurs.
-- La jointure va inventer des lignes.
-- Tables TEMP : elles disparaissent en quittant psql, donc pas de pollution.
-- ──────────────────────────────────────────────

CREATE TEMP TABLE p1 AS SELECT DISTINCT telephone, theme FROM formation_plat;
CREATE TEMP TABLE p2 AS SELECT DISTINCT theme, formateur FROM formation_plat;

-- Jointure : combien de lignes ?
SELECT count(*) AS lignes_jointure FROM p1 JOIN p2 USING (theme);
-- Attendu : 16 (au lieu de 8)

-- Les lignes INVENTÉES (dans la jointure mais pas dans l'original)
SELECT telephone, theme, formateur FROM p1 JOIN p2 USING (theme)
EXCEPT
SELECT telephone, theme, formateur FROM formation_plat
ORDER BY telephone, theme;
-- Attendu : 8 lignes inventées. Fatou Ba (+221 77 100 00 02) apparaît
-- suivie par Moussa Sarr, Ibrahima Fall et Kouassi Yao sur le thème varroa.


-- ──────────────────────────────────────────────
-- Étape 6.2 · Le bon découpage (BCNF) par `formateur`
-- La colonne commune `formateur` EST la clé de la table `formateur`.
-- La jointure redonnera exactement 8 lignes.
-- ──────────────────────────────────────────────

CREATE TABLE formateur (
    id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nom    text NOT NULL UNIQUE,                           -- formateur → theme
    theme  text NOT NULL CHECK (theme IN ('varroa','recolte','capteurs'))
);

CREATE TABLE suivi_formation (
    apicultrice_id  uuid NOT NULL REFERENCES apicultrice(id),
    formateur_id    uuid NOT NULL REFERENCES formateur(id),
    PRIMARY KEY (apicultrice_id, formateur_id)
);

-- Remplissage : 5 formateurs
INSERT INTO formateur (nom, theme)
SELECT DISTINCT formateur, theme FROM formation_plat;

-- Remplissage : 8 suivis. On retrouve l'apicultrice par son téléphone (unique).
-- Note : un téléphone de formation_plat peut ne correspondre à AUCUNE apicultrice
-- de la base (c'est le reproche du PDF « moins de 8 : corrigez la ligne »).
-- Dans notre jeu d'essai Queen Bee, les téléphones ci-dessous n'existent PAS
-- dans apicultrice ; on insère donc à la volée les apicultrices manquantes
-- (rattachées à SN-CASA par défaut) pour que le test fonctionne.
INSERT INTO apicultrice (nom, telephone, site_id)
SELECT DISTINCT 'Apicultrice ' || right(fp.telephone, 2), fp.telephone, 'SN-CASA'
FROM formation_plat fp
WHERE NOT EXISTS (SELECT 1 FROM apicultrice a WHERE a.telephone = fp.telephone);

INSERT INTO suivi_formation (apicultrice_id, formateur_id)
SELECT a.id, f.id
FROM formation_plat fp
JOIN apicultrice a ON a.telephone = fp.telephone
JOIN formateur   f ON f.nom       = fp.formateur;


-- ──────────────────────────────────────────────
-- Preuve sans perte : la jointure redonne exactement formation_plat
-- ──────────────────────────────────────────────

(SELECT fp.telephone, fp.theme, fp.formateur FROM formation_plat fp
 EXCEPT
 SELECT a.telephone, f.theme, f.nom
 FROM suivi_formation s
 JOIN apicultrice a ON a.id = s.apicultrice_id
 JOIN formateur   f ON f.id = s.formateur_id)
UNION ALL
(SELECT a.telephone, f.theme, f.nom
 FROM suivi_formation s
 JOIN apicultrice a ON a.id = s.apicultrice_id
 JOIN formateur   f ON f.id = s.formateur_id
 EXCEPT
 SELECT fp.telephone, fp.theme, fp.formateur FROM formation_plat fp);
-- Attendu : 0 ligne


-- ──────────────────────────────────────────────
-- Comptes de contrôle
-- ──────────────────────────────────────────────

SELECT (SELECT count(*) FROM formateur)       AS nb_formateurs,   -- 5
       (SELECT count(*) FROM suivi_formation) AS nb_suivis;        -- 8

       -- ──────────────────────────────────────────────
-- Étape 6.3 · Le trigger qui rétablit la règle
-- Un trigger est une fonction que PostgreSQL lance tout seul à chaque INSERT
-- ou UPDATE sur suivi_formation. Il refuse si l'apicultrice a déjà un autre
-- formateur pour le même thème.
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION suivi_un_formateur_par_theme() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM suivi_formation s
        JOIN formateur f ON f.id = s.formateur_id
        WHERE s.apicultrice_id = NEW.apicultrice_id   -- même apicultrice
          AND s.formateur_id   <> NEW.formateur_id    -- un AUTRE formateur
          AND f.theme = (SELECT theme FROM formateur WHERE id = NEW.formateur_id)
                                                      -- ... pour le MÊME thème
    ) THEN
        RAISE EXCEPTION 'DF violée : cette apicultrice a déjà un formateur pour ce thème';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS suivi_formation_df ON suivi_formation;
CREATE TRIGGER suivi_formation_df
BEFORE INSERT OR UPDATE ON suivi_formation
FOR EACH ROW EXECUTE FUNCTION suivi_un_formateur_par_theme();