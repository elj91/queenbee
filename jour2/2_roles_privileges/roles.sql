-- roles.sql : 4 groupes, 5 personnes, vues de moindre privilège, GRANTs
-- Le PDF dit : TEMPORARY n'est PAS retiré (il sera utilisé au lab 10
-- pour montrer l'attaque de la fonction espion). On garde REVOKE CONNECT,
-- pas REVOKE ALL ON DATABASE.


-- ──────────────────────────────────────────────
-- 1. Les groupes (NOLOGIN) et les personnes (LOGIN)
-- ──────────────────────────────────────────────

-- Groupes : rôles sans login
DO $$ BEGIN
  CREATE ROLE qb_apicultrice   NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE qb_coordinateur  NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE qb_gestionnaire  NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE qb_admin         NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Personnes : logins
-- (adaptation PDF : f.ba, awa.diop sont des apicultrices de ton jeu d'essai)
DO $$ BEGIN
  CREATE ROLE "a.diop" LOGIN PASSWORD 'Queen-cp-2027' IN ROLE qb_apicultrice;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE "awa.diop" LOGIN PASSWORD 'Queen-ad-2027' IN ROLE qb_apicultrice;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE "coord.casa" LOGIN PASSWORD 'Queen-co-2027' IN ROLE qb_coordinateur;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE "gest.beeafrica" LOGIN PASSWORD 'Queen-ge-2027' IN ROLE qb_gestionnaire;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE "admin.beeafrica" LOGIN PASSWORD 'Queen-ad-2027' IN ROLE qb_admin;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ──────────────────────────────────────────────
-- Ajouter "gest.beeafrica" et "admin.beeafrica" aussi dans la table compte
-- (pour que qui() renvoie quelque chose de métier côté application)
-- ──────────────────────────────────────────────
INSERT INTO compte (login, mot_de_passe_hash, role, apicultrice_id, site_id)
SELECT 'gest.beeafrica', crypt('Queen-ge-2027', gen_salt('bf')), 'gestionnaire', NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM compte WHERE login = 'gest.beeafrica');

-- ──────────────────────────────────────────────
-- 2. Fermeture maximale
-- ──────────────────────────────────────────────

REVOKE CONNECT ON DATABASE queenbee FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;

-- Ouverture minimale : se connecter et utiliser le schéma public
GRANT CONNECT ON DATABASE queenbee TO qb_apicultrice, qb_coordinateur, qb_gestionnaire, qb_admin;
GRANT USAGE  ON SCHEMA public       TO qb_apicultrice, qb_coordinateur, qb_gestionnaire, qb_admin;
GRANT EXECUTE ON FUNCTION qui()     TO qb_apicultrice, qb_coordinateur, qb_gestionnaire, qb_admin;

-- ──────────────────────────────────────────────
-- 3. Les vues de l'apicultrice (WITH CHECK OPTION pour v_mes_recoltes)
-- ──────────────────────────────────────────────

DROP VIEW IF EXISTS v_moi, v_mes_ruches, v_mes_mesures, v_mes_recoltes CASCADE;

-- Son propre compte
CREATE VIEW v_moi AS
SELECT id, login, role, apicultrice_id
FROM compte WHERE login = qui();

-- Ses ruches
CREATE VIEW v_mes_ruches AS
SELECT r.id, r.code_ruche, r.latitude, r.longitude, r.date_installation, r.site_id
FROM ruche r
JOIN compte c ON c.apicultrice_id = r.apicultrice_id
WHERE c.login = qui();

-- Ses mesures (par ruche_id dans v_mes_ruches)
CREATE VIEW v_mes_mesures AS
SELECT m.id, m.ruche_id, m.horodatage, m.poids_kg, m.temperature_int, m.temperature_ext,
       m.humidite_pct, m.activite_sonore, m.batterie_pct
FROM mesure m
WHERE m.ruche_id IN (SELECT id FROM v_mes_ruches);

-- Ses récoltes : INSERT autorisé mais UNIQUEMENT sur ses ruches, et jamais validée.
-- WITH CHECK OPTION refuse l'INSERT qui donnerait une ligne invisible à travers la vue.
CREATE VIEW v_mes_recoltes AS
SELECT rc.id, rc.ruche_id, rc.date_recolte, rc.quantite_kg AS volume_kg, rc.statut
FROM recolte rc
WHERE rc.ruche_id IN (SELECT id FROM v_mes_ruches)
  AND rc.statut = 'declaree'
WITH CHECK OPTION;

-- ──────────────────────────────────────────────
-- 4. Les vues du coordinateur (sur SON site)
-- ──────────────────────────────────────────────

DROP VIEW IF EXISTS v_recoltes_site, v_ruches_site CASCADE;

CREATE VIEW v_ruches_site AS
SELECT r.id, r.code_ruche, r.latitude, r.longitude, r.date_installation,
       r.site_id, r.apicultrice_id, a.nom AS apicultrice_nom, a.telephone
FROM ruche r
JOIN apicultrice a ON a.id = r.apicultrice_id
JOIN compte c      ON c.login = qui()
WHERE r.site_id = c.site_id;

CREATE VIEW v_recoltes_site AS
SELECT rc.id, rc.ruche_id, rc.date_recolte, rc.quantite_kg, rc.statut,
       rc.validee_par, rc.date_validation
FROM recolte rc
JOIN ruche r  ON r.id = rc.ruche_id
JOIN compte c ON c.login = qui()
WHERE r.site_id = c.site_id;

-- ──────────────────────────────────────────────
-- 5. Les GRANTs conformes à la matrice
-- ──────────────────────────────────────────────

-- Apicultrice : voit son compte, ses ruches, ses mesures. Peut INSÉRER
-- (déclarer) une récolte sur v_mes_recoltes (ruche_id, date_recolte, volume_kg).
GRANT SELECT ON v_moi, v_mes_ruches, v_mes_mesures TO qb_apicultrice;
GRANT SELECT ON v_mes_recoltes TO qb_apicultrice;
GRANT INSERT (ruche_id, date_recolte, volume_kg) ON v_mes_recoltes TO qb_apicultrice;

-- Coordinateur : voit les ruches et récoltes de SON site.
-- Pour valider une récolte, il passe par la fonction (étape 8.5), pas par UPDATE.
GRANT SELECT ON v_ruches_site, v_recoltes_site TO qb_coordinateur;

-- Gestionnaire : lecture des synthèses et de l'export du bailleur
GRANT SELECT ON synthese_site_jour, v_export_bailleur TO qb_gestionnaire;

-- Admin : CRUD sur compte (sauf DELETE pour forcer la désactivation plutôt
-- que la suppression — on garde la trace), lecture du journal.
GRANT SELECT, INSERT, UPDATE ON compte TO qb_admin;
GRANT SELECT ON journal_audit TO qb_admin;

-- ──────────────────────────────────────────────
-- Étape 8.5 · Fonction valider_recolte(uuid)
-- Un coordinateur UPDATE sa récolte par cette fonction, pas par un UPDATE direct.
-- SECURITY DEFINER : la fonction tourne avec les droits de son propriétaire
-- (postgres), qui peut modifier recolte ; l'appelant (coord.casa) n'a aucun
-- droit sur recolte directement.
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION valider_recolte(p_recolte uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_login   text := qui();
    v_compte  compte%ROWTYPE;
    n_touche  int;
BEGIN
    -- 1. Récupérer le compte appelant
    SELECT * INTO v_compte FROM compte WHERE login = v_login;
    IF NOT FOUND OR v_compte.role <> 'coordinateur' THEN
        RAISE EXCEPTION 'Seuls les coordinateurs peuvent valider une récolte';
    END IF;

    -- 2. UPDATE conditionnel : seulement si la récolte est declaree
    --    et sur une ruche du site du coordinateur
    UPDATE recolte
    SET statut          = 'validee',
        validee_par     = v_compte.id,
        date_validation = now()
    WHERE id = p_recolte
      AND statut = 'declaree'
      AND ruche_id IN (SELECT id FROM ruche WHERE site_id = v_compte.site_id);

    GET DIAGNOSTICS n_touche = ROW_COUNT;

    IF n_touche = 0 THEN
        RAISE EXCEPTION 'récolte introuvable, déjà traitée ou hors de votre site';
    END IF;
END;
$$;

-- Fermée à tous, ouverte au seul qb_coordinateur
REVOKE ALL ON FUNCTION valider_recolte(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION valider_recolte(uuid) TO qb_coordinateur;