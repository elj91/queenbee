-- audit.sql : trigger d'audit SECURITY DEFINER + protection du journal
--
-- L'écriture dans journal_audit se fait via un trigger exécuté avec les droits
-- du propriétaire (SECURITY DEFINER), car PUBLIC n'a plus de droits sur journal_audit.
-- Les utilisateurs qui n'ont PAS le droit d'écrire dans journal_audit peuvent
-- quand même modifier recolte/compte : c'est le trigger qui écrit pour eux.


BEGIN;

-- ──────────────────────────────────────────────
-- 1. qui() : retourne le rôle actif (SET ROLE) sinon l'utilisateur connecté
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION qui() RETURNS text
LANGUAGE sql STABLE AS $$
    SELECT CASE WHEN current_setting('role') = 'none' THEN session_user::text
                ELSE current_setting('role') END
$$;

-- ──────────────────────────────────────────────
-- 2. audit_ligne() : une ligne de journal par ligne touchée
-- SECURITY DEFINER = la fonction écrit dans journal_audit avec les droits
-- de son propriétaire (postgres), même si l'appelant n'y a aucun droit.
-- SET search_path = public, pg_temp : évite qu'un attaquant détourne la fonction
-- en créant un objet fantôme dans un schéma plus prioritaire.
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION audit_ligne() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    INSERT INTO journal_audit (acteur, table_cible, operation, ligne_id, avant, apres)
    VALUES (qui(),
            TG_TABLE_NAME,
            TG_OP,
            CASE WHEN TG_OP = 'DELETE' THEN OLD.id::text ELSE NEW.id::text END,
            CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
            CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END);
    RETURN NULL;   -- AFTER trigger : la valeur de retour n'est pas utilisée
END;
$$;

-- ──────────────────────────────────────────────
-- 3. journal_interdit() : refuse UPDATE, DELETE et TRUNCATE sur journal_audit
-- Le journal est en AJOUT SEUL : on peut INSERT (via les autres triggers), mais
-- ni modifier, ni supprimer, ni vider.
-- ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION journal_interdit() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'journal_audit est en ajout seul : % interdit', TG_OP;
END;
$$;

-- ──────────────────────────────────────────────
-- Attachement des triggers
-- ──────────────────────────────────────────────

-- recolte : preuve de production (UC-C02 : « validations tracées »)
DROP TRIGGER IF EXISTS recolte_audit ON recolte;
CREATE TRIGGER recolte_audit
AFTER INSERT OR UPDATE OR DELETE ON recolte
FOR EACH ROW EXECUTE FUNCTION audit_ligne();

-- compte : gestion des utilisateurs (UC-AD01 : « toutes les actions tracées »)
DROP TRIGGER IF EXISTS compte_audit ON compte;
CREATE TRIGGER compte_audit
AFTER INSERT OR UPDATE OR DELETE ON compte
FOR EACH ROW EXECUTE FUNCTION audit_ligne();

-- journal_audit : ajout seul (UPDATE, DELETE refusés par ligne)
DROP TRIGGER IF EXISTS journal_ajout_seul ON journal_audit;
CREATE TRIGGER journal_ajout_seul
BEFORE UPDATE OR DELETE ON journal_audit
FOR EACH ROW EXECUTE FUNCTION journal_interdit();

-- journal_audit : TRUNCATE a besoin de son propre trigger (pas par ligne)
DROP TRIGGER IF EXISTS journal_sans_truncate ON journal_audit;
CREATE TRIGGER journal_sans_truncate
BEFORE TRUNCATE ON journal_audit
FOR EACH STATEMENT EXECUTE FUNCTION journal_interdit();

COMMIT;