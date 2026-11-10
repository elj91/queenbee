-- migration_3nf.sql : découpe extrait_plat en tables BCNF (une par déterminant)
-- Correction : norm.ruche NE garde PAS site_id (dépendance transitive via telephone).
-- Le site d'une ruche remonte depuis son apicultrice.

BEGIN;

DROP SCHEMA IF EXISTS norm CASCADE;
CREATE SCHEMA norm;

-- ──────────────────────────────────────────────
-- Une table par déterminant
-- ──────────────────────────────────────────────

-- Déterminant : site_id → site_nom, pays
CREATE TABLE norm.site (
    site_id   text PRIMARY KEY,
    site_nom  text NOT NULL,
    pays      text NOT NULL
);

-- Déterminant : telephone → apicultrice (nom), site_id, cooperative
-- Le téléphone identifie une personne (nom insuffisant à cause des homonymes "Aminata Diop").
CREATE TABLE norm.apicultrice (
    telephone    text PRIMARY KEY,
    apicultrice  text NOT NULL,
    site_id      text NOT NULL REFERENCES norm.site(site_id),
    cooperative  text NOT NULL
);

-- Déterminant : ruche_code → telephone
-- On NE stocke PAS site_id ici : il se déduit par norm.apicultrice.
-- Garder ruche_code → site_id serait une dépendance transitive (violation 3NF).
CREATE TABLE norm.ruche (
    ruche_code  text PRIMARY KEY,
    telephone   text NOT NULL REFERENCES norm.apicultrice(telephone)
);

-- Clé composée : (ruche_code, horodatage) → poids_kg, temp_int_c
CREATE TABLE norm.mesure (
    ruche_code  text NOT NULL REFERENCES norm.ruche(ruche_code),
    horodatage  timestamptz NOT NULL,
    poids_kg    numeric(6,2),
    temp_int_c  numeric(4,1),
    PRIMARY KEY (ruche_code, horodatage)
);

-- ──────────────────────────────────────────────
-- Remplissage : une ligne par valeur distincte du déterminant
-- ──────────────────────────────────────────────

INSERT INTO norm.site        SELECT DISTINCT site_id, site_nom, pays               FROM extrait_plat;
INSERT INTO norm.apicultrice SELECT DISTINCT telephone, apicultrice, site_id, cooperative FROM extrait_plat;
INSERT INTO norm.ruche       SELECT DISTINCT ruche_code, telephone                 FROM extrait_plat;
INSERT INTO norm.mesure      SELECT DISTINCT ruche_code, horodatage, poids_kg, temp_int_c FROM extrait_plat;

COMMIT;


-- ──────────────────────────────────────────────
-- Vue de reconstruction : le site d'une ruche vient de son apicultrice
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