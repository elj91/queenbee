-- schema.sql : base Queen Bee

DROP TABLE IF EXISTS adhesion, alerte, recolte, inspection, mesure,
                     compte, ruche, apicultrice, cooperative, site CASCADE;


CREATE TABLE site (
    id    text PRIMARY KEY,
    nom   text NOT NULL,
    pays  text NOT NULL
);

CREATE TABLE cooperative (
    id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nom  text NOT NULL
);


CREATE TABLE apicultrice (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nom        text NOT NULL,
    telephone  text NOT NULL,
    site_id    text NOT NULL
               CONSTRAINT apicultrice_site_fk REFERENCES site(id)
);

CREATE TABLE ruche (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code_ruche         text NOT NULL UNIQUE,
    latitude           numeric(8,5),
    longitude          numeric(8,5),
    date_installation  date NOT NULL,
    site_id            text NOT NULL
                       CONSTRAINT ruche_site_fk REFERENCES site(id),
    apicultrice_id     uuid NOT NULL
                       CONSTRAINT ruche_apicultrice_fk REFERENCES apicultrice(id)
);


CREATE TABLE adhesion (
    apicultrice_id  uuid NOT NULL
                    CONSTRAINT adhesion_apicultrice_fk REFERENCES apicultrice(id),
    cooperative_id  uuid NOT NULL
                    CONSTRAINT adhesion_cooperative_fk REFERENCES cooperative(id),
    date_adhesion   date NOT NULL DEFAULT current_date,
    PRIMARY KEY (apicultrice_id, cooperative_id)
);


CREATE TABLE compte (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    login           text NOT NULL,
    mot_de_passe    text NOT NULL,
    role            text NOT NULL
                    CHECK (role IN ('apicultrice','coordinateur','gestionnaire','administrateur')),
    apicultrice_id  uuid UNIQUE
                    CONSTRAINT compte_apicultrice_fk REFERENCES apicultrice(id),
    site_id         text
                    CONSTRAINT compte_site_fk REFERENCES site(id)
);


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
    UNIQUE (ruche_id, horodatage)
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

CREATE TABLE recolte (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ruche_id          uuid NOT NULL
                      CONSTRAINT recolte_ruche_fk REFERENCES ruche(id),
    date_recolte      date NOT NULL,
    quantite_kg       numeric(6,2) NOT NULL,
    statut            text NOT NULL DEFAULT 'declaree'
                      CHECK (statut IN ('declaree','validee','refusee')),
    validee_par       uuid
                      CONSTRAINT recolte_validee_par_fk REFERENCES compte(id),
    date_validation   timestamptz,
    CHECK (quantite_kg >= 0),
    CHECK (
        (statut = 'validee' AND validee_par IS NOT NULL AND date_validation IS NOT NULL)
        OR
        (statut <> 'validee' AND validee_par IS NULL AND date_validation IS NULL)
    )
);

CREATE TABLE alerte (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ruche_id          uuid NOT NULL
                      CONSTRAINT alerte_ruche_fk REFERENCES ruche(id),
    horodatage        timestamptz NOT NULL,
    type              text NOT NULL
                      CHECK (type IN ('essaimage','vol','capteur_silencieux')),
    niveau_confiance  numeric(3,2) NOT NULL
                      CHECK (niveau_confiance BETWEEN 0 AND 1)
);