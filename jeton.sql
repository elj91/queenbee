-- jeton.sql : jetons de réinitialisation à usage unique, et sessions ouvertes.
-- Au lab 9, on démontre que le code naïf "vérifier puis agir" peut en
-- ouvrir DEUX avec un seul jeton (race condition).


DROP TABLE IF EXISTS session_app, jeton CASCADE;

CREATE TABLE jeton (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    utilisateur_id  uuid NOT NULL REFERENCES compte(id),
    valeur          text NOT NULL UNIQUE,
    expire_le       timestamptz NOT NULL,
    utilise_le      timestamptz           -- NULL tant que le jeton n'a pas servi
);

CREATE TABLE session_app (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    utilisateur_id  uuid NOT NULL REFERENCES compte(id),
    jeton_id        uuid NOT NULL REFERENCES jeton(id),
    ouverte_le      timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- 30 jetons pour "f.ba" (= a.diop chez nous), de RT-f.ba-1 à RT-f.ba-30,
-- valables un jour.
INSERT INTO jeton (utilisateur_id, valeur, expire_le)
SELECT (SELECT id FROM compte WHERE login = 'a.diop' LIMIT 1),
       'RT-f.ba-' || n,
       now() + INTERVAL '1 day'
FROM generate_series(1, 30) AS n;

-- Attendu : INSERT 0 30