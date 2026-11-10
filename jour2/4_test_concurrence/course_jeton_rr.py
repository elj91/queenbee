"""course_jeton_rr.py (Queen Bee) : isolation REPEATABLE READ.

Même logique que course_jeton.py (vérifier puis agir), mais chaque thread
démarre sa transaction en REPEATABLE READ. PostgreSQL détecte alors que
les deux ont lu la même ligne et modifient la même ligne : le second
échoue avec "could not serialize access".

Lancer : python3 course_jeton_rr.py RT-f.ba-15
"""
import sys
import threading
import time
import psycopg

JETON = sys.argv[1]
depart = threading.Barrier(2)
resultats = {}


def reinitialiser(nom):
    try:
        with psycopg.connect() as conn:
            conn.isolation_level = psycopg.IsolationLevel.REPEATABLE_READ
            depart.wait()
            with conn.transaction():
                row = conn.execute(
                    "SELECT id, utilisateur_id, utilise_le FROM jeton WHERE valeur = %s",
                    (JETON,),
                ).fetchone()
                if row is None or row[2] is not None:
                    resultats[nom] = "refusé : lien déjà utilisé"
                    return
                time.sleep(0.5)
                conn.execute(
                    "UPDATE jeton SET utilise_le = now() WHERE id = %s",
                    (row[0],),
                )
                conn.execute(
                    "INSERT INTO session_app (utilisateur_id, jeton_id) VALUES (%s, %s)",
                    (row[1], row[0]),
                )
                resultats[nom] = "accepté : session ouverte"
    except psycopg.Error as e:
        resultats[nom] = "erreur de la base : " + str(e.diag.message_primary or e)


fils = [threading.Thread(target=reinitialiser, args=(n,)) for n in ("clic 1", "clic 2")]
for f in fils:
    f.start()
for f in fils:
    f.join()

for nom in sorted(resultats):
    print(nom, "->", resultats[nom])

with psycopg.connect() as conn:
    n = conn.execute(
        "SELECT count(*) FROM session_app s JOIN jeton j ON j.id = s.jeton_id "
        "WHERE j.valeur = %s",
        (JETON,),
    ).fetchone()[0]
print("sessions ouvertes avec ce jeton :", n)