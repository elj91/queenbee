-- anomalies.sql : provoquer les trois anomalies classiques d'une table non normalisée
-- Chaque commande s'exécute UNE PAR UNE dans le Query Tool ; résultat collé en commentaire.


-- ──────────────────────────────────────────────
-- Anomalie 1 · Mise à jour
-- Un fait (le pays d'un site) est recopié sur chaque mesure du site.
-- Modifier une seule copie crée un fantôme : le même site a deux pays.
-- ──────────────────────────────────────────────

-- 1.1 : enquête de référence
SELECT pays, count(*) AS nb_mesures, round(avg(poids_kg)::numeric, 2) AS poids_moyen
FROM extrait_plat
GROUP BY pays
ORDER BY pays;
-- Résultat attendu : 3 pays (Cameroun, Côte d'Ivoire, Sénégal) — Sénégal regroupe SN-CASA et SN-KOLD


-- 1.2 : on casse le pays d'UNE SEULE mesure — « Sénégal » devient « Senegal » (sans accent)
UPDATE extrait_plat SET pays = 'Senegal'
WHERE ruche_code = 'SN-KOLD-011'
  AND horodatage = (SELECT min(horodatage) FROM extrait_plat WHERE ruche_code = 'SN-KOLD-011');
-- Résultat attendu : UPDATE 1


-- 1.3 : on relance l'enquête — elle passe à 4 pays
SELECT pays, count(*) AS nb_mesures, round(avg(poids_kg)::numeric, 2) AS poids_moyen
FROM extrait_plat
GROUP BY pays
ORDER BY pays;
-- Résultat attendu : 4 pays — « Senegal » (1 mesure) apparaît comme un pays fantôme à côté de « Sénégal »


-- 1.4 : même astuce pour le téléphone d'une apicultrice
-- (on casse le téléphone d'Awa Diop sur UNE mesure parmi ses 144 — 3 ruches × 48)
UPDATE extrait_plat SET telephone = '+221 99 99 99 99'
WHERE apicultrice = 'Awa Diop'
  AND horodatage = (SELECT min(horodatage) FROM extrait_plat WHERE apicultrice = 'Awa Diop');
-- Résultat attendu : UPDATE 1


-- ──────────────────────────────────────────────
-- Anomalie 2 · Suppression
-- Supprimer toutes les mesures d'une apicultrice efface son existence
-- (nom, téléphone, coopérative) : son identité est noyée dans les mesures.
-- BEGIN / ROLLBACK pour annuler ensuite.
-- ──────────────────────────────────────────────
BEGIN;

-- 2.1 : on prend une apicultrice qui n'a qu'UNE ruche (donc 48 mesures)
-- Fatou Ndiaye possède SN-KOLD-011 (1 seule ruche d'après notre jeu d'essai)
DELETE FROM extrait_plat WHERE apicultrice = 'Fatou Ndiaye';
-- Résultat attendu : DELETE 48

-- 2.2 : on cherche son téléphone — il a disparu
SELECT count(*) AS lignes_fatou FROM extrait_plat WHERE apicultrice = 'Fatou Ndiaye';
-- Résultat attendu : 0

-- Son téléphone n'existe plus nulle part dans extrait_plat :
-- supprimer des mesures a fait disparaître une personne.

ROLLBACK;


-- ──────────────────────────────────────────────
-- Anomalie 3 · Insertion
-- Avec (ruche_code, horodatage) en clé primaire, impossible d'ajouter
-- un site qui n'a encore ni ruche ni mesure.
-- ──────────────────────────────────────────────

-- 3.1 : on pose la clé primaire sur le couple (ruche_code, horodatage)
ALTER TABLE extrait_plat ADD PRIMARY KEY (ruche_code, horodatage);
-- Résultat attendu : ALTER TABLE


-- 3.2 : on tente d'enregistrer un nouveau site, sans ruche ni mesure
INSERT INTO extrait_plat (site_id, site_nom, pays)
VALUES ('CM-BAMI', 'Bamenda', 'Cameroun');
-- Résultat attendu :
-- ERROR:  null value in column "ruche_code" of relation "extrait_plat" violates not-null constraint
-- Le fait « Bamenda est au Cameroun » ne peut pas être enregistré tant qu'il n'y a pas de mesure :
-- un fait sur le site est tenu en otage par les mesures des ruches.