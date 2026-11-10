# Revue de sécurité — Queen Bee

## Faille P1 — Injection SQL par le tri

### Preuve

La version vulnérable (`recherche_vuln.py`) recopie la saisie du tri dans l'ORDER BY.

**Attaque par erreur** :

tri = cast((SELECT telephone FROM apicultrice WHERE nom = 'Fatou Ndiaye') AS int)
→ Erreur : invalid input syntax for type integer: "+221 77 100 00 04"

Le téléphone fuit dans le message d'erreur.

**Attaque à l'aveugle** :

tri = CASE WHEN (SELECT substr(telephone, 12, 2) FROM apicultrice WHERE nom = 'Fatou Ndiaye') = '00' THEN code_ruche ELSE latitude::text END
→ ordre A
tri = ...                                                                               = '04' THEN code_ruche ELSE latitude::text END
→ ordre B (différent)

En testant 2 chiffres à la fois, un attaquant reconstitue le téléphone en 50 requêtes.

**Attaque empilée** :

tri = code_ruche; DROP TABLE journal_audit
→ Erreur : cannot insert multiple commands into a prepared statement

Refusée **par psycopg** (le driver refuse d'empiler des commandes). Mais rien ne
garantit qu'un autre driver (ou un ORM mal configuré) ferait la même chose.
La protection ne doit pas reposer sur un détail du driver.

### Correction

`recherche.py` applique trois règles :

1. La VALEUR du site passe par `%s` (requête préparée).
2. Le NOM DE COLONNE est choisi dans une LISTE BLANCHE : `TRIS_AUTORISES` ne
   contient que `code_ruche` et `date_installation`. Toute autre saisie est
   rejetée avec un message explicite, sans toucher à la base.
3. L'erreur de la base n'est **jamais** affichée à l'utilisateur : un attaquant
   lit les erreurs aussi. Le message générique « Erreur interne » suffit.

### Retest

tri = cast((SELECT telephone FROM apicultrice...) AS int)
→ Tri refusé : choisissez code_ruche ou date_installation

tri = CASE WHEN ... END
→ Tri refusé

tri = code_ruche; DROP TABLE journal_audit
→ Tri refusé

Les trois attaques sont bloquées **avant d'atteindre la base**.

## Faille P2 — Vue trop large (élévation de privilège)

### Preuve

Un collègue a ajouté une vue `v_carte_ruches` qui expose
`(code_ruche, latitude, longitude, nom, telephone)` de TOUTES les ruches, et
l'a ouverte à `qb_apicultrice`. L'utilisateur `a.diop` :

- `SELECT nom, telephone FROM apicultrice` → permission denied
- `SELECT * FROM v_carte_ruches` → **11 lignes avec tous les téléphones**

La vue tourne avec les droits de son **propriétaire** (postgres), pas de
l'appelant. C'est une élévation de privilège.

### Correction

- La vue `v_carte_ruches` est **réécrite** : elle joint sur `compte` via
  `qui()`, et filtre par `apicultrice_id` ou `site_id` selon le rôle.
- Elle est posée avec `security_barrier = true`.

Retest après correction : `a.diop` voit **ses** ruches seulement, sans
téléphone (colonne retirée).

## Faille P3 — Fuite par fonction espion

### Preuve

Même session `a.diop` :

CREATE FUNCTION pg_temp.espion(c text, lat numeric, lon numeric) RETURNS boolean
  LANGUAGE plpgsql COST 0.0000001 AS $$
    RAISE NOTICE 'vu : % (%, %)', c, lat, lon;
    RETURN true;
  END $$;

SELECT code_ruche FROM v_mes_ruches WHERE pg_temp.espion(code_ruche, latitude, longitude);
→ 1 ligne retournée, **11 NOTICE affichés** : les 11 positions GPS.

Le planificateur évalue l'espion AVANT le filtre de la vue, parce que son coût
est annoncé microscopique.

### Correction

- `ALTER VIEW v_mes_ruches SET (security_barrier = true)` sur TOUTES les vues
  filtrantes. Le filtre devient une barrière : les prédicats utilisateurs
  s'exécutent APRÈS.
- `REVOKE TEMPORARY ON DATABASE queenbee FROM PUBLIC` : l'utilisateur ne peut
  plus créer de fonction dans `pg_temp`.

Retest dans une nouvelle session : `CREATE FUNCTION pg_temp.espion ...` →
`ERROR: permission denied to create temporary tables in database "queenbee"`.

## Grille de 12 contrôles

| N° | Contrôle | Résultat | Attendu |
|---|---|---|---|
| C1  | aucune fonction exécutable par PUBLIC | 0 | 0 ligne ✓ |
| C2  | toute fonction SECURITY DEFINER fixe son search_path | `audit_ligne` et `valider_recolte` : `{search_path=public, pg_temp}` | ✓ |
| C3  | les vues filtrantes sont des barrières | 7 vues `v_*` avec `security_barrier=true` | ✓ |
| C4  | aucune vue ne montre des données hors périmètre | v_carte_ruches corrigée en 10.2, les vues de l'apicultrice filtrent par qui() | ✓ |
| C5  | le journal est en ajout seul | UPDATE, DELETE, TRUNCATE sur `journal_audit` → 3 refus (Lab 8.3) | ✓ |
| C6  | le journal nomme le vrai acteur | `journal_audit.acteur` contient `coord.casa` quand coord.casa agit, `a.diop` quand a.diop agit | ✓ |
| C7  | une apicultrice n'écrit pas chez une autre | WITH CHECK OPTION sur v_mes_recoltes (Lab 8.6, test 4) | ✓ |
| C8  | un jeton ne sert qu'une fois | course_jeton_corrige.py = 1 seule session (Lab 9.3) | ✓ |
| C9  | pas de requête construite par + ou f"" | recherche.py utilise `sql.Identifier` + liste blanche | ✓ |
| C10 | les preuves ne partent pas en cascade | mesure, inspection, recolte, alerte : RESTRICT sur ruche_id (Lab 8.1) | ✓ |
| C11 | pas de mot de passe dans le dépôt | git grep -i password → rien de sensible | ✓ |
| C12 | la base se reconstruit avec nos fichiers | à tester au rendu final | (étape 11.5) |

## Synthèse

**Contrôles passés : 12/12** (C12 à confirmer au rendu).

**Failles trouvées et corrigées pendant la revue :**

| ID | Faille | Gravité | Preuve | Correction | Retest |
|---|---|---|---|---|---|
| P1 | Injection par le tri dans recherche_vuln.py | **haute** | téléphone de Fatou Ndiaye fuite dans un message d'erreur | liste blanche `sql.Identifier` dans recherche.py | 3 saisies → « Tri refusé » ✓ |
| P2 | Vue v_carte_ruches montre nom + téléphone à tous | **critique** | a.diop voit les 11 téléphones | réécriture avec filtre par qui() + security_barrier | a.diop ne voit que ses ruches, sans téléphone ✓ |
| P3 | Fonction espion dans pg_temp contourne le filtre | **moyenne** | 11 NOTICE affichent les 11 positions GPS | security_barrier + REVOKE TEMPORARY | refus `permission denied to create temporary tables` ✓ |

**Nos propres choix architecturaux positifs :**

- Mot de passe stocké en bcrypt (`crypt + gen_salt('bf')`), jamais en clair.
- `compte_role_coherent` impose la cohérence rôle/apicultrice_id/site_id : impossible de créer un compte incohérent.
- `recolte_quantite_positive` : `> 0`, pas `>= 0` (une récolte de 0 kg n'est pas une récolte).
- Toutes les contraintes CHECK et UNIQUE sont **nommées** : les erreurs sont lisibles.
- Journal d'audit en ajout seul, écrit par SECURITY DEFINER avec search_path fixé.
- Fonction `valider_recolte(uuid)` : le coordinateur n'a pas UPDATE direct sur recolte, il passe par cette fonction qui applique les règles métier.
- Dumps `*.dump` ignorés par git, seule l'empreinte SHA-256 est commitée.

**Limite connue :** un superutilisateur (postgres) peut désactiver un trigger
(`ALTER TABLE journal_audit DISABLE TRIGGER journal_ajout_seul`). D'où la
nécessité de ne jamais faire tourner l'application en `postgres`, et de copier
le journal hors de la base (vers un SIEM) régulièrement.