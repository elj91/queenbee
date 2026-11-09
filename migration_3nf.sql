-- migration_3nf.sql : découper extrait_plat en tables normalisées (une par déterminant)

BEGIN;

DROP SCHEMA IF EXISTS norm CASCADE;
CREATE SCHEMA norm;

-- ──────────────────────────────────────────────
-- Une table par déterminant du MCD
-- ──────────────────────────────────────────────

-- Déterminant : site_id → site_nom, pays
CREATE TABLE norm.site (
    site_id   text PRIMARY KEY,
    site_nom  text NOT NULL,
    pays      text NOT NULL
);

-- Déterminant : telephone → apicultrice, site_id, cooperative
-- (le téléphone identifie une personne de façon unique, le nom non — homonymes)
CREATE TABLE norm.apicultrice (
    telephone    text PRIMARY KEY,
    apicultrice  text NOT NULL,
    site_id      text NOT NULL REFERENCES norm.site(site_id),
    cooperative  text NOT NULL
);

-- Déterminant : ruche_code → site_id, telephone (donc apicultrice et coop par transitivité)
CREATE TABLE norm.ruche (
    ruche_code  text PRIMARY KEY,
    site_id     text NOT NULL REFERENCES norm.site(site_id),
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
-- Remplissage : chaque table reçoit SELECT DISTINCT de ses colonnes
-- Si les données sont corrompues (plusieurs pays pour un site_id),
-- la clé primaire REFUSE la ligne en double → la migration échoue.
-- ──────────────────────────────────────────────

INSERT INTO norm.site        SELECT DISTINCT site_id, site_nom, pays           FROM extrait_plat;
INSERT INTO norm.apicultrice SELECT DISTINCT telephone, apicultrice, site_id, cooperative FROM extrait_plat;
INSERT INTO norm.ruche       SELECT DISTINCT ruche_code, site_id, telephone    FROM extrait_plat;
INSERT INTO norm.mesure      SELECT DISTINCT ruche_code, horodatage, poids_kg, temp_int_c FROM extrait_plat;

COMMIT;