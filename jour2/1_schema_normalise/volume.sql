-- volume.sql : 90 jours de mesures pour chaque ruche, toutes les 30 minutes.
-- Lancer UNE SEULE FOIS (le DELETE au début rend le fichier rejouable si besoin).
-- Pour les labs 7, 8, 9, 10 : simule le volume réel (~47 520 mesures).

-- Supprime les anciennes mesures des 90 jours à venir (le DELETE évite le rejeu)
DELETE FROM mesure
WHERE horodatage >= TIMESTAMPTZ '2026-12-14 00:00+00'
  AND horodatage <  TIMESTAMPTZ '2026-12-14 00:00+00' + INTERVAL '90 days';

-- 11 ruches × 90 jours × 48 mesures/jour = 47 520 mesures
INSERT INTO mesure (ruche_id, horodatage, poids_kg, temperature_int, temperature_ext, humidite_pct, activite_sonore, batterie_pct)
SELECT r.id,
       TIMESTAMPTZ '2026-12-14 00:00+00' + h * INTERVAL '30 minutes',
       round((30 + random() * 5)::numeric, 2),                      -- 30 à 35 kg
       round((34 + random() * 2)::numeric, 1),                      -- 34 à 36 °C
       round((22 + random() * 8)::numeric, 1),                      -- 22 à 30 °C
       50 + floor(random() * 30)::int,                              -- 50 à 80 %
       40 + floor(random() * 30)::int,                              -- 40 à 70
       90 + floor(random() * 10)::int                               -- 90 à 100 % batterie
FROM ruche r CROSS JOIN generate_series(0, 90 * 48 - 1) AS h;

ANALYZE mesure;