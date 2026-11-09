# Pourquoi query.py résiste :
# psycopg envoie la requête et les valeurs SÉPARÉMENT au serveur PostgreSQL.
# Le serveur prépare d'abord la requête (il sait qu'il attend UNE chaîne pour code_ruche),
# puis reçoit la valeur comme donnée pure : les apostrophes, mots-clés SQL et commentaires
# -- sont traités comme des caractères, pas comme du code. L'injection devient
# une recherche de ruche dont le code_ruche vaut "' OR '1'='1" — qui n'existe pas.

import psycopg

conn = psycopg.connect()

code = input("Code ruche : ")

rows = conn.execute(
    "SELECT code_ruche, site_id FROM ruche WHERE code_ruche = %s",
    (code,)
).fetchall()

for row in rows:
    print(row)
print(f"{len(rows)} ligne(s)")