"""course_jeton_corrige.py (Queen Bee) : UPDATE ... RETURNING en une instruction.

La correction remplace "vérifier puis agir" par une seule instruction.
L'UPDATE prend un verrou sur la ligne, le second clic attend, puis réévalue
le WHERE (IS NULL devient faux) et renvoie 0 ligne.

Lancer : python3 course_jeton_corrige.py RT-f.ba-11
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
            depart.wait()
            time.sleep(0.1)

            # Une SEULE instruction : UPDATE conditionnel + RETURNING
            row = conn.execute(
                """
                UPDATE jeton
                SET utilise_le = now()
                WHERE valeur = %s
                  AND utilise_le IS NULL
                  AND expire_le > now()
                RETURNING id, utilisateur_id
                """,
                (JETON,),
            ).fetchone()

            if row is None:
                resultats[nom] = "refusé : lien déjà utilisé ou expiré"
                return

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