import pymysql

USER     = "root"
PASSWORD = "Odilehardy1994@"    # anpassen
HOST     = "127.0.0.1"
PORT     = 3306

conn = pymysql.connect(
    host=HOST, user=USER, password=PASSWORD,
    port=PORT, connect_timeout=60
)
cursor = conn.cursor()

settings = [
    "SET GLOBAL net_read_timeout       = 3600",
    "SET GLOBAL net_write_timeout      = 3600",
    "SET GLOBAL wait_timeout           = 28800",
    "SET GLOBAL interactive_timeout    = 28800",
    "SET GLOBAL innodb_lock_wait_timeout = 300",
    "SET GLOBAL max_allowed_packet     = 536870912",
    "SET GLOBAL innodb_buffer_pool_size = 1073741824",
]

for s in settings:
    cursor.execute(s)
    print(f"OK: {s}")

conn.commit()
cursor.close()
conn.close()
print("\nAlle Einstellungen gesetzt!")