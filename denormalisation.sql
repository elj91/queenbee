-- denormalisation.sql : les trois copies conscientes
-- Étape 7.2 : vue matérialisée pour le tableau de bord (UC-G01)
-- Étape 7.3 : vue pseudonymisée pour l'export au bailleur
-- Étape 7.4 : journal d'audit (ajoutée en bas)


-- ──────────────────────────────────────────────
-- Étape 7.2 · La synthèse matérialisée
-- Agrège les mesures par site et par jour. L'index UNIQUE sur (site_id, jour)
-- permettra le REFRESH MATERIALIZED VIEW CONCURRENTLY (rafraîchissement
-- sans bloquer les lecteurs).
-- ──────────────────────────────────────────────

DROP MATERIALIZED VIEW IF EXISTS synthese_site_jour;

CREATE MATERIALIZED VIEW synthese_site_jour AS
SELECT r.site_id,
       (m.horodatage AT TIME ZONE 'UTC')::date AS jour,
       count(*)                                 AS nb_mesures,
       round(avg(m.poids_kg)::numeric, 2)       AS poids_moyen,
       round(min(m.poids_kg)::numeric, 2)       AS poids_min,
       min(m.batterie_pct)                      AS batterie_min
FROM mesure m
JOIN ruche r ON r.id = m.ruche_id
GROUP BY r.site_id, (m.horodatage AT TIME ZONE 'UTC')::date;

CREATE UNIQUE INDEX synthese_site_jour_pk
  ON synthese_site_jour (site_id, jour);

  -- ──────────────────────────────────────────────
-- Étape 7.3 · L'export pour le bailleur
-- Pseudonymisation = HMAC avec une clé secrète (pas un simple hash).
-- La clé est dans une table FERMÉE À PUBLIC : personne ne peut la lire,
-- donc personne ne peut re-calculer les pseudonymes depuis un téléphone.
-- ──────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Table d'une seule ligne : la clé secrète de pseudonymisation
DROP TABLE IF EXISTS cle_pseudonymisation CASCADE;
CREATE TABLE cle_pseudonymisation (
    id   int PRIMARY KEY CHECK (id = 1),
    cle  text NOT NULL
);

INSERT INTO cle_pseudonymisation VALUES
    (1, encode(gen_random_bytes(32), 'hex'));

REVOKE ALL ON cle_pseudonymisation FROM PUBLIC;

-- Vue d'export pour le bailleur : des chiffres, pas de noms
-- - pseudo apicultrice : HMAC(id) tronqué à 12 caractères
-- - pays, site : utiles pour les statistiques régionales
-- - latitude : arrondie à 0,1° (~11 km), impossible de localiser une ruche précise
-- - total des récoltes VALIDÉES : la preuve de production
DROP VIEW IF EXISTS v_export_bailleur CASCADE;
CREATE VIEW v_export_bailleur AS
SELECT left(encode(hmac(a.id::text, k.cle, 'sha256'), 'hex'), 12) AS apicultrice_pseudo,
       s.pays,
       s.nom                                                     AS site_nom,
       round(r.latitude, 1)                                      AS lat_arrondie,
       round(r.longitude, 1)                                     AS lon_arrondie,
       coalesce(sum(rc.quantite_kg) FILTER (WHERE rc.statut = 'validee'), 0) AS kg_valides
FROM apicultrice a
JOIN ruche r       ON r.apicultrice_id = a.id
JOIN site s        ON s.id = r.site_id
LEFT JOIN recolte rc ON rc.ruche_id = r.id
CROSS JOIN cle_pseudonymisation k
GROUP BY a.id, s.pays, s.nom, round(r.latitude, 1), round(r.longitude, 1), k.cle;

REVOKE ALL ON v_export_bailleur FROM PUBLIC;

-- ──────────────────────────────────────────────
-- Étape 7.4 · Le journal d'audit
-- Modèle identique pour GreenFarm et Queen Bee : copié tel quel du PDF.
-- Le trigger qui le remplit (et qui empêche sa modification) sera posé au Lab 8.
-- Pas de clé étrangère vers les tables auditées : si une récolte est supprimée,
-- son trace dans le journal doit survivre.
-- ──────────────────────────────────────────────

DROP TABLE IF EXISTS journal_audit CASCADE;
CREATE TABLE journal_audit (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    horodatage   timestamptz NOT NULL DEFAULT clock_timestamp(),
    acteur       text NOT NULL,                                        -- qui
    table_cible  text NOT NULL,                                        -- sur quoi
    operation    text NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    ligne_id     text,                                                 -- quelle ligne
    avant        jsonb,                                                -- la ligne avant
    apres        jsonb                                                 -- la ligne après
);
REVOKE ALL ON journal_audit FROM