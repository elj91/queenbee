-- corrections.sql : les deux corrections de l'étape 10.2
-- 1. La vue v_carte_ruches : la réécrire pour qu'elle ne montre que les ruches de l'appelant
-- 2. security_barrier = true sur toutes les vues filtrantes : le filtre de la vue est appliqué AVANT les prédicats de l'utilisateur
-- 3. REVOKE TEMPORARY : les utilisateurs ne peuvent plus créer de fonctions dans pg_temp


BEGIN;

-- ──────────────────────────────────────────────
-- 1. v_carte_ruches : la réécrire pour qu'elle ne montre que les ruches du site
--    de l'appelant (coordinateur) ou de l'appelant (apicultrice)
-- ──────────────────────────────────────────────

DROP VIEW IF EXISTS v_carte_ruches CASCADE;

CREATE VIEW v_carte_ruches
    WITH (security_barrier = true) AS
SELECT r.code_ruche, r.latitude, r.longitude
FROM ruche r
JOIN compte c ON c.login = qui()
WHERE
    -- soit c'est une apicultrice : ses ruches seulement
    (c.role = 'apicultrice'  AND c.apicultrice_id = r.apicultrice_id)
 OR -- soit c'est un coordinateur : les ruches de son site
    (c.role = 'coordinateur' AND c.site_id        = r.site_id);

GRANT SELECT ON v_carte_ruches TO qb_apicultrice, qb_coordinateur;

-- ──────────────────────────────────────────────
-- 2. security_barrier sur TOUTES les vues filtrantes
-- Sans ça, la fonction espion de l'utilisateur est évaluée AVANT le filtre
-- de la vue (parce que son coût est très bas) et voit toutes les lignes.
-- Avec security_barrier, le filtre est posé comme une barrière : l'expression
-- utilisateur ne la traverse pas.
-- ──────────────────────────────────────────────

ALTER VIEW v_moi             SET (security_barrier = true);
ALTER VIEW v_mes_ruches      SET (security_barrier = true);
ALTER VIEW v_mes_mesures     SET (security_barrier = true);
ALTER VIEW v_mes_recoltes    SET (security_barrier = true);
ALTER VIEW v_ruches_site     SET (security_barrier = true);
ALTER VIEW v_recoltes_site   SET (security_barrier = true);

-- ──────────────────────────────────────────────
-- 3. Retirer le droit TEMPORARY à PUBLIC
-- Sans ce droit, les utilisateurs ne peuvent plus créer de fonctions dans
-- pg_temp. L'espion ne peut plus être posé.
-- ──────────────────────────────────────────────

REVOKE TEMPORARY ON DATABASE queenbee FROM PUBLIC;

COMMIT;