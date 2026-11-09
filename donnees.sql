-- donnees.sql : jeu d'essai Queen Bee
BEGIN;

-- ──────────────────────────────────────────────
-- Sites : 4, dans 3 pays, dont 2 au Sénégal (avec l'accent)
-- ──────────────────────────────────────────────
INSERT INTO site (id, nom, pays) VALUES
    ('SN-CASA', 'Casamance',       'Sénégal'),
    ('SN-KOLD', 'Kolda',           'Sénégal'),
    ('CI-BOUA', 'Bouaké',          'Côte d''Ivoire'),
    ('CM-FOUM', 'Foumban',         'Cameroun');

-- ──────────────────────────────────────────────
-- Coopératives : 1 par site
-- ──────────────────────────────────────────────
INSERT INTO cooperative (nom) VALUES
    ('Miel de Casamance'),
    ('Coop Kolda Nature'),
    ('Ruches de Bouaké'),
    ('Apiculteurs Foumban');

-- ──────────────────────────────────────────────
-- Apicultrices : 8, dont 2 "Aminata Diop" et 1 "Awa Diop"
-- ──────────────────────────────────────────────
INSERT INTO apicultrice (nom, telephone, site_id) VALUES
    ('Aminata Diop',  '+221 77 100 00 01', 'SN-CASA'),   -- homonyme 1
    ('Aminata Diop',  '+221 77 100 00 02', 'SN-KOLD'),   -- homonyme 2
    ('Awa Diop',      '+221 77 100 00 03', 'SN-CASA'),
    ('Fatou Ndiaye',  '+221 77 100 00 04', 'SN-KOLD'),
    ('Marie Kouassi', '+225 07 200 00 05', 'CI-BOUA'),
    ('Adjoua Yao',    '+225 07 200 00 06', 'CI-BOUA'),
    ('Nguena Ngono',  '+237 6 55 00 00 07', 'CM-FOUM'),
    ('Mireille Fotso','+237 6 55 00 00 08', 'CM-FOUM');

-- ──────────────────────────────────────────────
-- Ruches : 11, dont SN-CASA-099
-- Awa Diop en possède plusieurs
-- Les UUID des apicultrices sont retrouvés par leur téléphone (unique)
-- ──────────────────────────────────────────────
INSERT INTO ruche (code_ruche, site_id, apicultrice_id, latitude, longitude, date_installation) VALUES
    ('SN-CASA-001', 'SN-CASA', (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 01'), 12.55000, -16.27000, DATE '2025-03-10'),
    ('SN-CASA-014', 'SN-CASA', (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 03'), 12.55100, -16.27100, DATE '2025-04-02'),
    ('SN-CASA-099', 'SN-CASA', (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 03'), 12.55200, -16.27200, DATE '2025-05-18'),  -- Awa Diop a 2 ruches ici
    ('SN-CASA-120', 'SN-CASA', (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 03'), 12.55300, -16.27300, DATE '2025-06-01'),  -- et une 3e
    ('SN-KOLD-005', 'SN-KOLD', (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 02'), 12.89000, -14.95000, DATE '2025-03-15'),
    ('SN-KOLD-011', 'SN-KOLD', (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 04'), 12.89100, -14.95100, DATE '2025-04-20'),
    ('CI-BOUA-002', 'CI-BOUA', (SELECT id FROM apicultrice WHERE telephone = '+225 07 200 00 05'), 7.68000,  -5.03000,  DATE '2025-02-28'),
    ('CI-BOUA-007', 'CI-BOUA', (SELECT id FROM apicultrice WHERE telephone = '+225 07 200 00 05'), 7.68100,  -5.03100,  DATE '2025-03-05'),
    ('CI-BOUA-013', 'CI-BOUA', (SELECT id FROM apicultrice WHERE telephone = '+225 07 200 00 06'), 7.68200,  -5.03200,  DATE '2025-05-12'),
    ('CM-FOUM-004', 'CM-FOUM', (SELECT id FROM apicultrice WHERE telephone = '+237 6 55 00 00 07'), 5.72000, 10.90000,  DATE '2025-03-22'),
    ('CM-FOUM-009', 'CM-FOUM', (SELECT id FROM apicultrice WHERE telephone = '+237 6 55 00 00 08'), 5.72100, 10.90100,  DATE '2025-04-11');

-- ──────────────────────────────────────────────
-- Adhésions : chaque apicultrice adhère à la coopérative de son site
-- On s'appuie sur le fait que coop(i) correspond au site(i) : les noms font le lien
-- ──────────────────────────────────────────────
INSERT INTO adhesion (apicultrice_id, cooperative_id)
SELECT a.id,
       (SELECT c.id FROM cooperative c WHERE c.nom =
          CASE a.site_id
            WHEN 'SN-CASA' THEN 'Miel de Casamance'
            WHEN 'SN-KOLD' THEN 'Coop Kolda Nature'
            WHEN 'CI-BOUA' THEN 'Ruches de Bouaké'
            WHEN 'CM-FOUM' THEN 'Apiculteurs Foumban'
          END)
FROM apicultrice a;

-- ──────────────────────────────────────────────
-- Comptes : un par apicultrice (login "initiale.nom"), + 1 coordinateur + 1 administrateur
-- Login : première lettre du prénom + "." + nom de famille, en minuscules
-- Les trois "Diop" produisent "a.diop" en triple (volontaire, exploité au lab 4)
-- ──────────────────────────────────────────────
INSERT INTO compte (login, mot_de_passe, role, apicultrice_id, site_id)
SELECT lower(left(a.nom, 1)) || '.' || lower(split_part(a.nom, ' ', 2)),
       'motdepasse_a_changer',
       'apicultrice',
       a.id,
       a.site_id
FROM apicultrice a;

INSERT INTO compte (login, mot_de_passe, role, site_id) VALUES
    ('coord.casa', 'motdepasse_a_changer', 'coordinateur',   'SN-CASA'),
    ('admin',      'motdepasse_a_changer', 'administrateur', NULL);

-- ──────────────────────────────────────────────
-- Mesures : une toutes les 30 minutes pendant 24 h, pour chaque ruche
-- 48 mesures par ruche × 11 ruches = 528
-- ──────────────────────────────────────────────
INSERT INTO mesure (ruche_id, horodatage, poids_kg, temperature_int, temperature_ext, humidite_pct, activite_sonore, batterie_pct)
SELECT r.id,
       TIMESTAMPTZ '2026-11-01 00:00+00' + h * INTERVAL '30 minutes',
       round((30 + random() * 10)::numeric, 2),
       round((34 + random() * 2)::numeric, 1),
       round((22 + random() * 8)::numeric, 1),
       50 + floor(random() * 30)::int,
       40 + floor(random() * 30)::int,
       70 + floor(random() * 30)::int
FROM ruche r CROSS JOIN generate_series(0, 47) AS h;

-- ──────────────────────────────────────────────
-- Inspections : 6, en laissant au moins 2 ruches jamais inspectées
-- (on choisit 4 ruches, deux d'entre elles reçoivent 2 inspections chacune)
-- ──────────────────────────────────────────────
INSERT INTO inspection (ruche_id, apicultrice_id, date_inspection, etat_colonie, reine_presente, observations) VALUES
    ((SELECT id FROM ruche WHERE code_ruche = 'SN-CASA-001'),
     (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 01'),
     TIMESTAMPTZ '2026-10-15 09:00+00', 'colonie saine',       true,  'Bonne activité'),
    ((SELECT id FROM ruche WHERE code_ruche = 'SN-CASA-014'),
     (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 03'),
     TIMESTAMPTZ '2026-10-18 10:30+00', 'colonie faible',      true,  'Peu d''activité, surveiller'),
    ((SELECT id FROM ruche WHERE code_ruche = 'SN-CASA-014'),
     (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 03'),
     TIMESTAMPTZ '2026-10-28 10:00+00', 'colonie saine',       true,  'Nette amélioration'),
    ((SELECT id FROM ruche WHERE code_ruche = 'SN-KOLD-011'),
     (SELECT id FROM apicultrice WHERE telephone = '+221 77 100 00 04'),
     TIMESTAMPTZ '2026-10-20 08:00+00', 'colonie saine',       true,  'RAS'),
    ((SELECT id FROM ruche WHERE code_ruche = 'CI-BOUA-002'),
     (SELECT id FROM apicultrice WHERE telephone = '+225 07 200 00 05'),
     TIMESTAMPTZ '2026-10-22 11:00+00', 'reine non vue',       false, 'Reine à chercher'),
    ((SELECT id FROM ruche WHERE code_ruche = 'CI-BOUA-002'),
     (SELECT id FROM apicultrice WHERE telephone = '+225 07 200 00 05'),
     TIMESTAMPTZ '2026-10-29 11:30+00', 'reine présente',      true,  'Nouvelle reine confirmée');
-- SN-CASA-099, SN-CASA-120, SN-KOLD-005, CI-BOUA-007, CI-BOUA-013, CM-FOUM-004, CM-FOUM-009 : jamais inspectées (7 ruches)

-- ──────────────────────────────────────────────
-- Récoltes : 3 (1 déclarée, 1 validée, 1 refusée pour varier)
-- ──────────────────────────────────────────────
INSERT INTO recolte (ruche_id, date_recolte, quantite_kg, statut, validee_par, date_validation) VALUES
    ((SELECT id FROM ruche WHERE code_ruche = 'SN-CASA-001'),
     DATE '2026-10-20', 12.50, 'declaree', NULL, NULL),
    ((SELECT id FROM ruche WHERE code_ruche = 'SN-CASA-014'),
     DATE '2026-10-22', 18.75, 'validee',
     (SELECT id FROM compte WHERE login = 'coord.casa'),
     TIMESTAMPTZ '2026-10-25 14:30+00'),
    ((SELECT id FROM ruche WHERE code_ruche = 'CI-BOUA-002'),
     DATE '2026-10-24',  8.20, 'declaree', NULL, NULL);

-- ──────────────────────────────────────────────
-- Alertes : 4, sur 2 sites (SN-CASA et CI-BOUA)
-- ──────────────────────────────────────────────
INSERT INTO alerte (ruche_id, horodatage, type, niveau_confiance) VALUES
    ((SELECT id FROM ruche WHERE code_ruche = 'SN-CASA-099'),
     TIMESTAMPTZ '2026-11-05 03:12+00', 'vol',                0.87),
    ((SELECT id FROM ruche WHERE code_ruche = 'SN-CASA-120'),
     TIMESTAMPTZ '2026-11-06 14:40+00', 'essaimage',          0.72),
    ((SELECT id FROM ruche WHERE code_ruche = 'CI-BOUA-007'),
     TIMESTAMPTZ '2026-11-07 02:00+00', 'capteur_silencieux', 0.95),
    ((SELECT id FROM ruche WHERE code_ruche = 'CI-BOUA-013'),
     TIMESTAMPTZ '2026-11-08 18:15+00', 'essaimage',          0.64);

COMMIT;


-- La règle qui protège : la clé primaire, qui interdit deux lignes avec le même identifiant. 
-- L’effet s’applique aussi à toutes les autres tables : 
-- si le script passait la barrière des sites, il échouerait ensuite sur cooperative, ruche, etc. pour la même raison