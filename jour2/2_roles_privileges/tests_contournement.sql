-- tests_contournement.sql : on joue l'attaquant.
-- Pour chaque test : commande, résultat réel (en commentaire), attendu.
-- Lancer SANS ON_ERROR_STOP (les erreurs sont voulues) :
--   psql -U postgres -h localhost -d queenbee -f tests_contournement.sql
--
-- Note : f.ba du PDF → a.diop dans mon jeu d'essai (Aminata Diop +221 77 100 00 01).


-- ──────────────────────────────────────────────
-- On range des ids dans des variables psql, en postgres
-- ──────────────────────────────────────────────

SELECT id AS ruche_autre FROM ruche WHERE site_id = 'SN-KOLD' LIMIT 1 \gset
SELECT id AS exploitant_autre FROM apicultrice WHERE site_id = 'CI-BOUA' LIMIT 1 \gset
SELECT id AS recolte_declaree FROM recolte
  WHERE statut = 'declaree' AND ruche_id IN (SELECT id FROM ruche WHERE site_id = 'SN-CASA')
  LIMIT 1 \gset
SELECT id AS recolte_autre_site FROM recolte
  WHERE ruche_id IN (SELECT id FROM ruche WHERE site_id = 'CI-BOUA') LIMIT 1 \gset


-- ──────────────────────────────────────────────
-- 10 tests en tant que a.diop (apicultrice)
-- ──────────────────────────────────────────────
SET ROLE "a.diop";

-- 1. Lire apicultrice directement → REFUSÉ
SELECT nom, telephone FROM apicultrice;

-- 2. Lire v_mes_ruches → ACCEPTÉ, ses ruches seulement
SELECT code_ruche FROM v_mes_ruches;

-- 3. Déclarer une récolte sur SA ruche, via v_mes_recoltes → ACCEPTÉ
INSERT INTO v_mes_recoltes (ruche_id, date_recolte, volume_kg)
SELECT id, DATE '2027-11-15', 7.50 FROM v_mes_ruches LIMIT 1;

-- 4. Déclarer une récolte sur la ruche d'une AUTRE apicultrice → REFUSÉ (CHECK OPTION)
INSERT INTO v_mes_recoltes (ruche_id, date_recolte, volume_kg)
VALUES (:'ruche_autre', DATE '2027-11-15', 20.00);

-- 5. INSERT INTO recolte directement avec statut = 'validee' → REFUSÉ (pas de droits)
INSERT INTO recolte (ruche_id, date_recolte, quantite_kg, statut)
SELECT id, DATE '2027-11-16', 10.00, 'validee' FROM v_mes_ruches LIMIT 1;

-- 6. UPDATE recolte SET volume_kg = 99 → REFUSÉ
UPDATE recolte SET quantite_kg = 99;

-- 7. Appeler valider_recolte → REFUSÉ
SELECT valider_recolte(:'recolte_declaree');

-- 8. Écrire dans journal_audit → REFUSÉ
INSERT INTO journal_audit (acteur, table_cible, operation) VALUES ('faux', 'recolte', 'INSERT');

-- 9. Désactiver le trigger recolte_audit → REFUSÉ (must be owner)
ALTER TABLE recolte DISABLE TRIGGER recolte_audit;

RESET ROLE;


-- ──────────────────────────────────────────────
-- 2 tests en tant que coord.casa (coordinateur)
-- ──────────────────────────────────────────────
SET ROLE "coord.casa";

-- 10. Valider la récolte du test 3, puis la revalider → d'abord ACCEPTÉ, puis REFUSÉ
SELECT id AS recolte_test3 FROM recolte
  WHERE ruche_id IN (SELECT id FROM ruche WHERE site_id = 'SN-CASA')
    AND statut = 'declaree'
    AND quantite_kg = 7.50
  LIMIT 1 \gset
SELECT valider_recolte(:'recolte_test3');
SELECT valider_recolte(:'recolte_test3');  -- revalidation → refus

-- 11. Valider une récolte d'un autre site (CI-BOUA) → REFUSÉ
SELECT valider_recolte(:'recolte_autre_site');

RESET ROLE;


-- ──────────────────────────────────────────────
-- 1 test en tant que admin.beeafrica (admin)
-- ──────────────────────────────────────────────
SET ROLE "admin.beeafrica";

-- 12. Lire le journal (ACCEPTÉ : les actions d'a.diop et coord.casa sont tracées)
--     Puis essayer de supprimer un utilisateur (REFUSÉ : l'admin a INSERT/UPDATE mais pas DELETE)
SELECT acteur, table_cible, operation, apres ->> 'login' AS login_touche
FROM journal_audit WHERE table_cible = 'compte'
UNION ALL
SELECT acteur, table_cible, operation, apres ->> 'quantite_kg'
FROM journal_audit WHERE table_cible = 'recolte'
ORDER BY 1, 2;

DELETE FROM compte WHERE login = 'a.diop';  -- REFUSÉ

RESET ROLE;