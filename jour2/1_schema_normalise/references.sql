-- references.sql : règles ON DELETE pour toutes les clés étrangères
--
-- Choix justifiés pour Queen Bee :
--
-- CASCADE pour les tables de LIEN sans valeur propre :
--   adhesion.apicultrice_id, adhesion.cooperative_id
--
-- RESTRICT pour les tables qui gardent une PREUVE historique (on refuse de perdre
-- une mesure, une inspection, une récolte ou une alerte en cascade) :
--   mesure.ruche_id, inspection.ruche_id, recolte.ruche_id, alerte.ruche_id
--
-- Les autres FK gardent le défaut (NO ACTION = refus) :
--   apicultrice.site_id, ruche.site_id, ruche.apicultrice_id,
--   inspection.apicultrice_id, recolte.validee_par, compte.apicultrice_id,
--   compte.site_id
-- → supprimer un site, une apicultrice ou un compte doit forcer à nettoyer
--   explicitement les ruches, inspections, etc.


BEGIN;

-- ──────────────────────────────────────────────
-- CASCADE pour les adhésions
-- Une adhésion est un pur lien : si l'apicultrice ou la coopérative disparaît,
-- la ligne d'adhésion n'a plus de sens. Elle peut partir sans message.
-- ──────────────────────────────────────────────

ALTER TABLE adhesion DROP CONSTRAINT adhesion_apicultrice_fk,
                     ADD  CONSTRAINT adhesion_apicultrice_fk FOREIGN KEY (apicultrice_id)
                          REFERENCES apicultrice(id) ON DELETE CASCADE;

ALTER TABLE adhesion DROP CONSTRAINT adhesion_cooperative_fk,
                     ADD  CONSTRAINT adhesion_cooperative_fk FOREIGN KEY (cooperative_id)
                          REFERENCES cooperative(id) ON DELETE CASCADE;

-- ──────────────────────────────────────────────
-- RESTRICT pour les preuves attachées à une ruche
-- Une mesure, une inspection, une récolte ou une alerte sont des faits
-- historiques. Si on tente de supprimer la ruche, la base refuse explicitement
-- plutôt que d'effacer les preuves en silence.
-- ──────────────────────────────────────────────

ALTER TABLE mesure DROP CONSTRAINT mesure_ruche_fk,
                   ADD  CONSTRAINT mesure_ruche_fk FOREIGN KEY (ruche_id)
                        REFERENCES ruche(id) ON DELETE RESTRICT;

ALTER TABLE inspection DROP CONSTRAINT inspection_ruche_fk,
                       ADD  CONSTRAINT inspection_ruche_fk FOREIGN KEY (ruche_id)
                            REFERENCES ruche(id) ON DELETE RESTRICT;

ALTER TABLE recolte DROP CONSTRAINT recolte_ruche_fk,
                    ADD  CONSTRAINT recolte_ruche_fk FOREIGN KEY (ruche_id)
                         REFERENCES ruche(id) ON DELETE RESTRICT;

ALTER TABLE alerte DROP CONSTRAINT alerte_ruche_fk,
                   ADD  CONSTRAINT alerte_ruche_fk FOREIGN KEY (ruche_id)
                        REFERENCES ruche(id) ON DELETE RESTRICT;

COMMIT;


-- ──────────────────────────────────────────────
-- Vérification : qui est en CASCADE, qui est en RESTRICT, qui est en NO ACTION ?
-- Attendu : 2 CASCADE (adhésions), 4 RESTRICT (preuves), les autres NO ACTION.
-- ──────────────────────────────────────────────

SELECT conrelid::regclass AS table_, conname,
       CASE confdeltype
         WHEN 'a' THEN 'NO ACTION'
         WHEN 'r' THEN 'RESTRICT'
         WHEN 'c' THEN 'CASCADE'
         WHEN 'n' THEN 'SET NULL'
       END AS on_delete
FROM pg_constraint
WHERE contype = 'f' AND connamespace = 'public'::regnamespace
ORDER BY on_delete, conrelid::regclass::text, conname;