"""recherche.py (Queen Bee) : version corrigée.

Deux règles :
1. La VALEUR passe par %s (c'est le job du driver).
2. Le NOM DE COLONNE est choisi dans une LISTE BLANCHE, pas copié de la saisie.
   sql.Identifier() construit une référence sûre (guillemets doubles, échappement).
3. Les erreurs de la base ne sont jamais affichées brutes à l'utilisateur :
   un attaquant les lit aussi.
"""
import psycopg
from psycopg import sql

TRIS_AUTORISES = {
    "code_ruche":        sql.Identifier("code_ruche"),
    "date_installation": sql.Identifier("date_installation"),
}

site = input("Site (ex. SN-CASA) : ")
tri  = input("Trier par (code_ruche ou date_installation) : ")

if tri not in TRIS_AUTORISES:
    print("Tri refusé : choisissez code_ruche ou date_installation")
    raise SystemExit(1)

requete = sql.SQL(
    "SELECT code_ruche, site_id, latitude, longitude FROM ruche "
    "WHERE site_id = %s ORDER BY {}"
).format(TRIS_AUTORISES[tri])

try:
    with psycopg.connect() as conn:
        for row in conn.execute(requete, (site,)):
            print(row)
except psycopg.Error:
    # On ne révèle PAS le message de la base. Juste une erreur générique.
    print("Erreur interne — contactez l'administrateur")