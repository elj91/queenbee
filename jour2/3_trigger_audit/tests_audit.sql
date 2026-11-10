-- tests_audit.sql : tests du trigger d'audit, étape 8.3 du lab


-- 1. UPDATE recolte → une ligne dans journal_audit avec avant/apres
UPDATE recolte SET quantite_kg = 14.00
WHERE ruche_id = (SELECT id FROM ruche WHERE code_ruche = 'SN-CASA-001');

SELECT acteur, table_cible, operation,
       avant ->> 'quantite_kg' AS avant_kg,
       apres ->> 'quantite_kg' AS apres_kg
FROM journal_audit
WHERE table_cible = 'recolte'
ORDER BY id DESC LIMIT 1;
-- Résultat : postgres | recolte | UPDATE | 12.50 | 14.00


-- 2. UPDATE journal_audit → refus
UPDATE journal_audit SET acteur = 'pirate';
-- ERROR : journal_audit est en ajout seul : UPDATE interdit


-- 3. DELETE FROM journal_audit → refus
DELETE FROM journal_audit;
-- ERROR : journal_audit est en ajout seul : DELETE interdit


-- 4. TRUNCATE journal_audit → refus
TRUNCATE journal_audit;
-- ERROR : journal_audit est en ajout seul : TRUNCATE interdit


-- 5. ALTER TABLE ... DISABLE TRIGGER (en postgres, propriétaire) → accepté
ALTER TABLE journal_audit DISABLE TRIGGER journal_ajout_seul;
ALTER TABLE journal_audit ENABLE TRIGGER journal_ajout_seul;
-- Limite documentée : un superutilisateur peut désactiver un trigger.
-- C'est pourquoi le journal doit aussi être copié hors de la base (SIEM).
