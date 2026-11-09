import psycopg

conn = psycopg.connect()

code = input("Code ruche : ")

sql = "SELECT code_ruche, site_id FROM ruche WHERE code_ruche = '" + code + "'"
print("Requête envoyée :", sql)

count = 0
for row in conn.execute(sql):
    print(row)
    count += 1
print(f"{count} ligne(s)")