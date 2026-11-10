"""course_jeton.py (Queen Bee) : deux clics simultanés sur le même lien.

Démontre la race condition "vérifier puis agir" :
  1. SELECT utilise_le
  2. [sleep]
  3. UPDATE utilise_le = now()
  4. INSERT session

Les deux threads passent la vérification avant que l'un ait commité.
Résultat attendu : 2 sessions ouvertes avec un seul jeton.

Lancer : python3 course_jeton.py RT-f.ba-10
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
            depart.wait()                   # les deux threads partent ensemble

            # 1. Vérifier
            row = conn.execute(
                "SELECT id, utilisateur_id, utilise_le FROM jeton WHERE valeur = %s",
                (JETON,),
            ).fetchone()
            if row is None or row[2] is not None:
                resultats[nom] = "refusé : lien déjà utilisé"
                return

            # [petit délai : l'app envoie un email, par exemple]
            time.sleep(0.5)

            # 2. Agir
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