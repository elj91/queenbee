-- schema.sql : base Queen Bee
-- Toutes les contraintes CHECK et UNIQUE sont nommées pour être lisibles dans les erreurs.
-- Les mots de passe ne sont jamais stockés en clair : mot_de_passe_hash via pgcrypto.

DROP TABLE IF EXISTS adhesion, alerte, recolte, inspection, mesure,
                     compte, ruche, apicultrice, cooperative, site CASCADE;

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- pour crypt() et gen_salt()

-- ──────────────────────────────────────────────
-- Tables qui ne pointent vers aucune autre
-- ──────────────────────────────────────────────

CREATE TABLE site (
    id    text PRIMARY KEY,
    nom   text NOT NULL,
    pays  text NOT NULL
);

CREATE TABLE cooperative (
    id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nom  text NOT NULL
);

-- ──────────────────────────────────────────────
-- Apicultrices
-- ──────────────────────────────────────────────

CREATE TABLE apicultrice (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nom        text NOT NULL,
    telephone  text NOT NULL,
    site_id    text NOT NULL
               CONSTRAINT apicultrice_site_fk REFERENCES site(id),
    CONSTRAINT apicultrice_telephone_unique UNIQUE (telephone)
);

CREATE TABLE ruche (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code_ruche         text NOT NULL
                       CONSTRAINT ruche_code_unique UNIQUE,
    latitude           numeric(8,5),
    longitude          numeric(8,5),
    date_installation  date NOT NULL,
    site_id            text NOT NULL
                       CONSTRAINT ruche_site_fk REFERENCES site(id),
    apicultrice_id     uuid NOT NULL
                       CONSTRAINT ruche_apicultrice_fk REFERENCES apicultrice(id)
);

-- ──────────────────────────────────────────────
-- Adhésion : lien n,n ADHÈRE
-- ──────────────────────────────────────────────

CREATE TABLE adhesion (
    apicultrice_id  uuid NOT NULL
                    CONSTRAINT adhesion_apicultrice_fk REFERENCES apicultrice(id),
    cooperative_id  uuid NOT NULL
                    CONSTRAINT adhesion_cooperative_fk REFERENCES cooperative(id),
    date_adhesion   date NOT NULL DEFAULT current_date,
    PRIMARY KEY (apicultrice_id, cooperative_id)
);

-- ──────────────────────────────────────────────
-- Comptes
-- Correction 1 : mot_de_passe_hash (jamais en clair).
-- Correction 4 : CHECK compte_role_coherent impose la bonne combinaison
--   role / apicultrice_id / site_id selon le type de compte.
-- ──────────────────────────────────────────────

CREATE TABLE compte (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    login               text NOT NULL,                       -- UNIQUE posé au lab 4
    mot_de_passe_hash   text NOT NULL,                       -- hash bcrypt via pgcrypto, jamais en clair
    role                text NOT NULL
                        CONSTRAINT compte_role_valide
                        CHECK (role IN ('apicultrice','coordinateur','gestionnaire','administrateur')),
    apicultrice_id      uuid
                        CONSTRAINT compte_apicultrice_fk REFERENCES apicultrice(id),
    site_id             text
                        CONSTRAINT compte_site_fk REFERENCES site(id),
    CONSTRAINT compte_apicultrice_unique UNIQUE (apicultrice_id),
    CONSTRAINT compte_role_coherent CHECK (
        -- apicultrice : liée à une apicultrice, le site vient d'elle (donc site_id NULL)
        (role = 'apicultrice'    AND apicultrice_id IS NOT NULL AND site_id IS NULL)
     OR -- coordinateur : rattaché à un site, pas à une apicultrice
        (role = 'coordinateur'   AND apicultrice_id IS NULL     AND site_id IS NOT NULL)
     OR -- gestionnaire et administrateur : ni apicultrice ni site
        (role IN ('gestionnaire','administrateur')
                                 AND apicultrice_id IS NULL     AND site_id IS NULL)
    )
);

-- ──────────────────────────────────────────────
-- Mesures
-- ──────────────────────────────────────────────

CREATE TABLE mesure (
    id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ruche_id         uuid NOT NULL
                     CONSTRAINT mesure_ruche_fk REFERENCES ruche(id),
    horodatage       timestamptz NOT NULL,
    poids_kg         numeric(6,2),
    temperature_int  numeric(4,1),
    temperature_ext  numeric(4,1),
    humidite_pct     smallint,
    activite_sonore  smallint,
    batterie_pct     smallint,
    CONSTRAINT mesure_ruche_horodatage_unique UNIQUE (ruche_id, horodatage)   -- anti-rejeu
);

CREATE TABLE inspection (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ruche_id         uuid NOT NULL
                     CONSTRAINT inspection_ruche_fk REFERENCES ruche(id),
    apicultrice_id   uuid NOT NULL
                     CONSTRAINT inspection_apicultrice_fk REFERENCES apicultrice(id),
    date_inspection  timestamptz NOT NULL,
    etat_colonie     text,
    reine_presente   boolean,
    observations     text
);

-- ──────────────────────────────────────────────
-- Récoltes
-- Correction 5 : quantite_kg > 0 (une récolte de 0 kg n'est pas une récolte),
--   et tous les CHECK sont nommés.
-- ──────────────────────────────────────────────

CREATE TABLE recolte (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ruche_id          uuid NOT NULL
                      CONSTRAINT recolte_ruche_fk REFERENCES ruche(id),
    date_recolte      date NOT NULL,
    quantite_kg       numeric(6,2) NOT NULL,
    statut            text NOT NULL DEFAULT 'declaree'
                      CONSTRAINT recolte_statut_valide
                      CHECK (statut IN ('declaree','validee','refusee')),
    validee_par       uuid
                      CONSTRAINT recolte_validee_par_fk REFERENCES compte(id),
    date_validation   timestamptz,
    CONSTRAINT recolte_quantite_positive CHECK (quantite_kg > 0),
    CONSTRAINT recolte_validation_coherente CHECK (
        (statut = 'validee' AND validee_par IS NOT NULL AND date_validation IS NOT NULL)
     OR (statut <> 'validee' AND validee_par IS NULL     AND date_validation IS NULL)
    )
);

CREATE TABLE alerte (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ruche_id          uuid NOT NULL
                      CONSTRAINT alerte_ruche_fk REFERENCES ruche(id),
    horodatage        timestamptz NOT NULL,
    type              text NOT NULL
                      CONSTRAINT alerte_type_valide
                      CHECK (type IN ('essaimage','vol','capteur_silencieux')),
    niveau_confiance  numeric(3,2) NOT NULL
                      CONSTRAINT alerte_confiance_valide
                      CHECK (niveau_confiance BETWEEN 0 AND 1)
);