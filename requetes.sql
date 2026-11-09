-- requetes.sql : cinq questions à la base Queen Bee
-- Pour chacune : algèbre en commentaire, requête SQL, nombre de lignes obtenu.


-- ──────────────────────────────────────────────
-- Q1. Les ruches du site SN-CASA, avec leur position
-- Algèbre : π code_ruche, latitude, longitude ( σ site_id = 'SN-CASA' ( ruche ) )
-- ──────────────────────────────────────────────
SELECT code_ruche, latitude, longitude
FROM ruche
WHERE site_id = 'SN-CASA'
ORDER BY code_ruche;
-- Résultat : 4 lignes (SN-CASA-001, SN-CASA-014, SN-CASA-099, SN-CASA-120)


-- ──────────────────────────────────────────────
-- Q2. Chaque apicultrice et son nombre de ruches
-- Algèbre : (apicultrice ⟕ ruche) puis GROUP BY a.id
-- LEFT JOIN pour garder les apicultrices sans ruche ;
-- GROUP BY a.id compte par personne, pas par nom → les deux « Aminata Diop » séparées.
-- ──────────────────────────────────────────────
SELECT a.nom, a.telephone, a.site_id, count(r.id) AS nb_ruches
FROM apicultrice a
LEFT JOIN ruche r ON r.apicultrice_id = a.id
GROUP BY a.id, a.nom, a.telephone, a.site_id
ORDER BY nb_ruches DESC, a.nom;
-- Résultat : 8 lignes (une par apicultrice ; les deux Aminata Diop apparaissent séparément,
--           Awa Diop a 3 ruches, Marie Kouassi en a 2, les autres 1 ou 0)


-- ──────────────────────────────────────────────
-- Q3. Les ruches jamais inspectées
-- Algèbre : ruche − π ruche_id ( inspection )
-- ──────────────────────────────────────────────
SELECT code_ruche
FROM ruche
WHERE id IN (
    SELECT id FROM ruche
    EXCEPT
    SELECT ruche_id FROM inspection
)
ORDER BY code_ruche;
-- Résultat : 7 lignes (SN-CASA-099, SN-CASA-120, SN-KOLD-005, CI-BOUA-007,
--           CI-BOUA-013, CM-FOUM-004, CM-FOUM-009)


-- ──────────────────────────────────────────────
-- Q4. Les sites qui ont au moins une alerte
-- Algèbre : π site_id ( ruche ⋈ alerte )
-- DISTINCT pour que chaque site n'apparaisse qu'une fois.
-- ──────────────────────────────────────────────
SELECT DISTINCT s.id, s.nom, s.pays
FROM site s
JOIN ruche r  ON r.site_id = s.id
JOIN alerte al ON al.ruche_id = r.id
ORDER BY s.id;
-- Résultat : 2 lignes (SN-CASA, CI-BOUA) — bien 2 sites distincts


-- ──────────────────────────────────────────────
-- Q5. Vue v_ruche_coordinateur : code, site, dernière pesée
-- Expose uniquement ce dont un coordinateur a besoin —
-- SANS nom, téléphone, ni position GPS.
-- Un coordinateur voit l'état des ruches, pas les données personnelles.
-- ──────────────────────────────────────────────
CREATE OR REPLACE VIEW v_ruche_coordinateur AS
SELECT r.code_ruche,
       r.site_id,
       derniere.horodatage AS derniere_pesee,
       derniere.poids_kg
FROM ruche r
LEFT JOIN LATERAL (
    SELECT m.horodatage, m.poids_kg
    FROM mesure m
    WHERE m.ruche_id = r.id
    ORDER BY m.horodatage DESC
    LIMIT 1
) AS derniere ON true;

SELECT * FROM v_ruche_coordinateur ORDER BY code_ruche;
-- Résultat : 11 lignes (une par ruche, avec sa dernière pesée)


-- ──────────────────────────────────────────────
-- Fin : pourquoi SELECT * est à proscrire sur la table des apicultrices
-- ──────────────────────────────────────────────
-- Faire SELECT * sur apicultrice ramène TOUTES les colonnes, y compris le téléphone
-- (donnée personnelle sensible). Une application qui n'a besoin que du nom pour afficher
-- un libellé laisse ainsi fuiter un numéro à chaque requête, dans ses logs, dans le trafic
-- réseau, dans d'éventuels caches. En plus :
--   1. Le jour où le schéma gagne une colonne (mot_de_passe_hash, email, adresse),
--      SELECT * la fera remonter sans que personne n'ait rien demandé.
--   2. C'est la base de l'exploit du Test de l'étape 3.2 : une injection UNION s'appuie
--      sur le nombre de colonnes exposées ; plus il y en a, plus l'attaque est utile.
-- Règle : lister explicitement les colonnes nécessaires (projection π), et créer une vue
-- quand plusieurs écrans partagent la même projection restreinte (ex. v_ruche_coordinateur).