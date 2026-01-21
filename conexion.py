import oracledb
import os
from dotenv import load_dotenv

load_dotenv()

def get_connection():
    try:
        oracledb.init_oracle_client(lib_dir=os.getenv('DB_LIB_DIR'))
        conn = oracledb.connect(
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASS'),
            dsn=os.getenv('DB_DSN')
        )
        return conn
    except Exception as e:
        print(f"❌ Error de conexión: {e}")
        return None



# import oracledb

# # ============================================
# #   CONEXIÓN (MODO THIN - SIN INSTALACIÓN)
# # ============================================
# # IMPORTANTE: No llamar a oracledb.init_oracle_client()

# host = '192.168.15.10'
# port = 7050
# service = 'analitics.dgrcorrientes.gov.ar'
# username = 'analitic'
# password = '98ff293c'

# # En el modo Thin, el DSN se arma igual
# dsn = oracledb.makedsn(host, port, service_name=service)

# try:
#     # Conectamos directamente
#     oracledb.init_oracle_client(
#         lib_dir=r"C:\Users\armonzon\Downloads\sqldeveloper-21.4.2.018.1706-x64\instantclient_21_10"
#     )
#     conn = oracledb.connect(user=username, password=password, dsn=dsn)
#     print("✅ ¡CONECTADO EXITOSAMENTE!")
#     print("Versión de la DB:", conn.version)
    
#     # ... resto de tu código de cursores ...

# except Exception as e:
#     print(f"❌ Error al conectar: {e}")