-- check.sql : contraintes CHECK nommées pour refuser les valeurs impossibles
-- Les tests de violation sont dans tests_check.sql (ailleurs).


BEGIN;

-- mesure : batterie, humidité, poids
ALTER TABLE mesure
    ADD CONSTRAINT mesure_batterie_0_100 CHECK (batterie_pct BETWEEN 0 AND 100),
    ADD CONSTRAINT mesure_humidite_0_100 CHECK (humidite_pct BETWEEN 0 AND 100),
    ADD CONSTRAINT mesure_poids_positif  CHECK (poids_kg IS NULL OR poids_kg >= 0);

-- alerte : colonne statut + CHECK
ALTER TABLE alerte ADD COLUMN IF NOT EXISTS statut text NOT NULL DEFAULT 'ouverte';

ALTER TABLE alerte
    ADD CONSTRAINT alerte_statut_valide CHECK (statut IN ('ouverte','en_cours','traitee'));

COMMIT;