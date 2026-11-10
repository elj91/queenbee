-- check.sql : contraintes CHECK nommées pour refuser les valeurs impossibles
--
-- Le type smallint accepte 140 pour une humidité : la base doit refuser 140 %.
-- Chaque contrainte est NOMMÉE pour que les erreurs soient lisibles.
--
-- Rappel : certains CHECK sont déjà dans schema.sql (recolte_quantite_positive,
-- recolte_statut_valide, recolte_validation_coherente, compte_role_valide,
-- compte_role_coherent, alerte_type_valide, alerte_confiance_valide).
-- Ici on ajoute celles qui manquent.


BEGIN;

-- ──────────────────────────────────────────────
-- mesure : batterie entre 0 et 100, humidité entre 0 et 100, poids positif ou nul
-- ──────────────────────────────────────────────

ALTER TABLE mesure
    ADD CONSTRAINT mesure_batterie_0_100 CHECK (batterie_pct BETWEEN 0 AND 100),
    ADD CONSTRAINT mesure_humidite_0_100 CHECK (humidite_pct BETWEEN 0 AND 100),
    ADD CONSTRAINT mesure_poids_positif  CHECK (poids_kg IS NULL OR poids_kg >= 0);

-- ──────────────────────────────────────────────
-- alerte : nouveau statut CHECK (ouverte, en_cours, traitee)
-- Jusqu'ici, alerte n'avait pas de colonne statut : on l'ajoute avec son CHECK.
-- ──────────────────────────────────────────────

ALTER TABLE alerte ADD COLUMN IF NOT EXISTS statut text NOT NULL DEFAULT 'ouverte';

ALTER TABLE alerte
    ADD CONSTRAINT alerte_statut_valide CHECK (statut IN ('ouverte','en_cours','traitee'));

COMMIT;


-- ──────────────────────────────────────────────
-- Tests : les deux valeurs invalides doivent être refusées
-- ──────────────────────────────────────────────

-- Test 1 : batterie à 150 % (impossible) → refus
INSERT INTO mesure (ruche_id, horodatage, poids_kg, temperature_int, temperature_ext, humidite_pct, activite_sonore, batterie_pct)
SELECT id, TIMESTAMPTZ '2027-04-01 00:00+00', 30.0, 35.0, 25.0, 55, 50, 150
FROM ruche WHERE code_ruche = 'SN-CASA-001';

-- Test 2 : statut d'alerte inconnu → refus
UPDATE alerte SET statut = 'fermee' WHERE id = (SELECT id FROM alerte LIMIT 1);