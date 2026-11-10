-- tests_check.sql : prouver que les CHECK refusent les valeurs impossibles.
-- Lancer SANS ON_ERROR_STOP (les deux ERROR sont voulues) :
--   psql -U postgres -h localhost -d queenbee -f tests_check.sql


-- Test 1 : batterie à 150 % (impossible) → refus
INSERT INTO mesure (ruche_id, horodatage, poids_kg, temperature_int, temperature_ext, humidite_pct, activite_sonore, batterie_pct)
SELECT id, TIMESTAMPTZ '2027-04-01 00:00+00', 30.0, 35.0, 25.0, 55, 50, 150
FROM ruche WHERE code_ruche = 'SN-CASA-001';
-- Attendu : ERROR: ... violates check constraint "mesure_batterie_0_100"


-- Test 2 : statut d'alerte inconnu → refus
UPDATE alerte SET statut = 'fermee' WHERE id = (SELECT id FROM alerte LIMIT 1);
-- Attendu : ERROR: ... violates check constraint "alerte_statut_valide"
