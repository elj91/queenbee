# Queen Bee — Dossier de conception, jour 2 — Elyes Jaffel

## Les 5 parties

1. Schéma normalisé : `1_schema_normalise/`
2. Rôles et privilèges : `2_roles_privileges/` (4 rôles, 7 vues, 1 fonction de validation)
3. Trigger d'audit : `3_trigger_audit/` (tables auditées : recolte, compte)
4. Test de concurrence : `4_test_concurrence/` (2 sessions ouvertes avant correction, 1 après)
5. Revue de sécurité : `5_revue_securite/` (3 constats, 3 corrigés)

## Reconstruire (base vide, avec -v ON_ERROR_STOP=1)

1. `schema.sql` (racine du dépôt, structure jour 1)
2. `donnees.sql` (racine, jeu d'essai)
3. `jour2/1_schema_normalise/formation.sql`
4. `jour2/1_schema_normalise/volume.sql` (47 520 mesures, une seule fois)
5. `jour2/1_schema_normalise/denormalisation.sql`
6. `jour2/1_schema_normalise/references.sql` puis `check.sql`
7. `jour2/3_trigger_audit/audit.sql`
8. `jour2/2_roles_privileges/roles.sql`
9. `jour2/4_test_concurrence/jeton.sql`
10. `jour2/5_revue_securite/corrections.sql`

Puis les scripts Python du dossier 4 (variables PGUSER, PGPASSWORD, PGHOST, PGDATABASE).

## Nos choix principaux

- **BCNF + trigger** pour les formations : `formateur` a `UNIQUE(nom)` (donc `formateur → theme`), et `suivi_un_formateur_par_theme()` rétablit la règle perdue par le découpage.
- **Vue matérialisée** `synthese_site_jour` : rafraîchie la nuit ; le vol est détecté sur les mesures brutes en temps réel.
- **HMAC + clé secrète** pour l'export au bailleur, clé dans une table fermée à PUBLIC.
- **Mot de passe en bcrypt**, jamais en clair (correction jour 1).

## Limites connues

- Un superutilisateur peut désactiver un trigger. D'où la copie du journal hors de la base (SIEM).
- Les logins non uniques dans le jeu d'essai initial exposent des lignes d'autres apicultrices via `v_mes_ruches` : la contrainte unique sur `login` et `lower(login)` (lab 4) corrige ça.
- `pg_dump` ne sauvegarde pas les rôles : `pg_dumpall --roles-only` à faire séparément.
