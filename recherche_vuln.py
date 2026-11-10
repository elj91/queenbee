"""recherche_vuln.py (Queen Bee) : recherche vulnérable à l'injection par le tri.

Le tri est recopié dans l'ORDER BY sans vérification : avec un %s, psycopg
protège la VALEUR ('FR-BEAU') mais pas un nom de colonne (que %s ne saurait
pas insérer). Le développeur pressé fait alors du string concat sur le tri —
et l'attaquant a le champ libre pour injecter.
"""
import psycopg

site = input("Site (ex. SN-CASA) : ")
tri  = input("Trier par (code_ruche ou date_installation) : ")

sql = (
    "SELECT code_ruche, site_id, latitude, longitude FROM ruche "
    "WHERE site_id = %s ORDER BY " + tri
)
try:
    with psycopg.connect() as conn:
        for row in conn.execute(sql, (site,)):
            print(row)
except psycopg.Error as e:
    # Erreur affichée brute : révèle le texte de la requête (fuite d'info)
    print("Erreur :", e)