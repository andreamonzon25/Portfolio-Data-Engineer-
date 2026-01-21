# main.py
from conexion import get_connection
import queries

def auditoria_actividades(tipo_contribuyente):
    conn = get_connection()
    if not conn: return

    try:
        cursor = conn.cursor()
        
        # Le pasamos el tipo (Directo o Convenio) como un parámetro
        print(f"\n>>> Analizando Inconsistencias en: {tipo_contribuyente}")
        cursor.execute(queries.SQL_DUPLIC_ACTIVIDAD, tipo=tipo_contribuyente)
        
        rows = cursor.fetchall()
        
        if not rows:
            print(f" No se encontraron inconsistencias para {tipo_contribuyente}.")
        else:
            print(f"{'AÑO':>4} | {'ACTIVIDAD':>10} | {'DESC. INC.' :>10}")
            print("-" * 40)
            for row in rows:
                print(f"{row[0]:>4} | {row[1]:>10} | {row[2]:>10}")
                
    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        conn.close()


# main.py
# main.py

def comparar_cuit_por_tipo(tipo_contrib):
    conn = get_connection()
    if not conn: return

    try:
        cursor = conn.cursor()
        print(f"\n>>> COMPARACIÓN POR CUIT: {tipo_contrib}")
        
        # Ejecutamos la consulta dinámica que está en queries.py
        cursor.execute(queries.SQL_COMP_CUIT, tipo=tipo_contrib)
        rows = cursor.fetchall()

        if not rows:
            print(f"Sin diferencias detectadas en {tipo_contrib}.")
        else:
            # Definimos los encabezados exactos que pediste
            headers = ["CUIT", "ANTICIPO", "IMP_CABECERA", "IMP_DETALLE", "DIFERENCIA"]
            
            # Imprimimos la cabecera con formato profesional
            print(f"{headers[0]:>15} | {headers[1]:>8} | {headers[2]:>15} | {headers[3]:>15} | {headers[4]:>15}")
            print("-" * 80)

            for row in rows:
                # Extraemos y formateamos cada valor
                cuit      = row[0]
                anticipo  = row[1]
                imp_cab   = row[2] if row[2] is not None else 0.00
                imp_det   = row[3] if row[3] is not None else 0.00
                dif       = row[4] if row[4] is not None else 0.00

                # Imprimimos la fila manteniendo el orden solicitado
                print(f"{cuit:>15} | {anticipo:>8} | {imp_cab:>15.2f} | {imp_det:>15.2f} | {dif:>15.2f}")

    except Exception as e:
        print(f" Error en comparativa CUIT: {e}")
    finally:
        conn.close()


# main.py

def reporte_anticipo_por_tipo(tipo_contrib):
    conn = get_connection()
    if not conn: return

    try:
        cursor = conn.cursor()
        print(f"\n" + "="*95)
        print(f"REPORTE COMPARATIVO DE ANTICIPOS: {tipo_contrib.upper()}")
        print("="*95)
        
        cursor.execute(queries.SQL_COMP_ANTICIPO, tipo=tipo_contrib)
        rows = cursor.fetchall()

        # Encabezados solicitados
        headers = ["ANTICIPO", "IMP_CABECERA", "%_CAB", "IMP_DETALLE", "%_DET", "DIF_ABS", "DIF_%"]
        
        print(f"{headers[0]:>8} | {headers[1]:>15} | {headers[2]:>6} | {headers[3]:>15} | {headers[4]:>6} | {headers[5]:>12} | {headers[6]:>6}")
        print("-" * 95)

        for row in rows:
            anticipo   = row[0]
            imp_cab    = row[1] if row[1] else 0
            porc_cab   = row[2] if row[2] else 0
            imp_det    = row[3] if row[3] else 0
            porc_det   = row[4] if row[4] else 0
            dif_abs    = row[5] if row[5] else 0
            dif_porc   = row[6] if row[6] else 0

            print(f"{anticipo:>8} | {imp_cab:>15.2f} | {porc_cab:>6.2f} | {imp_det:>15.2f} | {porc_det:>6.2f} | {dif_abs:>12.2f} | {dif_porc:>6.2f}%")

    except Exception as e:
        print(f" Error en reporte de anticipo: {e}")
    finally:
        conn.close()

def buscar_huerfanos_cabecera(tipo_contrib):
    conn = get_connection()
    if not conn: return

    try:
        cursor = conn.cursor()
        print(f"\n>>> AUDITORÍA: DETALLE SIN CABECERA ({tipo_contrib})")
        
        # Dentro de buscar_huerfanos_detalle:
        sql = queries.SQL_NO_CABECERA_DIRECTO if tipo_contrib == 'Directo' else queries.SQL_NO_CABECERA_CONVENIO
        cursor.execute(sql)
        rows = cursor.fetchall()
         
        if not rows:
            print(f" Integridad OK: Todos los detalle tienen cabecera.")
            return 0
        else:
            headers = ["CUIT", "ANTICIPO", "RECTIF.", "FECHA_PRES", "NRO_OBLIG", "IMP_DET"]
            print(f"{headers[0]:>15} | {headers[1]:>8} | {headers[2]:>7} | {headers[3]:>12} | {headers[4]:>15} | {headers[5]:>15}")
            print("-" * 100)

            for row in rows:
                # Manejo de Nulos y Formateo
                cuit         = row[0] if row[0] else ""
                anticipo     = row[1] if row[1] else ""
                rectificativa = row[2] if row[2] is not None else 0
                fecha_pres   = row[3].strftime("%Y-%m-%d") if row[3] else "N/A"
                nro_oblig    = row[4] if row[4] else ""
                impuesto     = row[5] if row[5] is not None else 0.00

                print(f"{cuit:>15} | {anticipo:>8} | {rectificativa:>7} | {fecha_pres:>12} | {nro_oblig:>15} | {impuesto:>15.2f}")
            return(len(rows))
    except Exception as e:
        print(f" Error buscando huérfanos: {e}")
    finally:
        conn.close()
 
 

def buscar_huerfanos_detalle(tipo_contrib):
    conn = get_connection()
    if not conn: return

    try:
        cursor = conn.cursor()
        print(f"\n>>> AUDITORÍA: CABECERA SIN DETALLE ({tipo_contrib})")
        
        if tipo_contrib == 'Directo':
            sql = queries.SQL_NO_DETALLE_DIRECTO
        else:
            sql = queries.SQL_NO_DETALLE_CONVENIO
        
        cursor.execute(sql) # Ya no necesita pasar el parámetro :tipo dentro del SQL
        rows = cursor.fetchall()

        if not rows:
            print(f" Integridad OK: Todos las cabecera tienen su detalle correspondiente.")
            return 0  # <--- Retornamos 0 si no hay errores
        else:
            headers = ["CUIT", "ANTICIPO", "RECTIF.", "FECHA_PRES", "NRO_OBLIG", "IMP_DETALLE"]
            print(f"{headers[0]:>15} | {headers[1]:>8} | {headers[2]:>7} | {headers[3]:>12} | {headers[4]:>15} | {headers[5]:>15}")
            print("-" * 100)

            for row in rows:
                # Formateo preventivo para evitar errores de tipo
                cuit     = str(row[0]) if row[0] else ""
                ant      = str(row[1]) if row[1] else ""
                rect     = str(row[2]) if row[2] is not None else "0"
                fecha    = row[3].strftime("%Y-%m-%d") if row[3] else "N/A"
                oblig    = str(row[4]) if row[4] else ""
                imp      = row[5] if row[5] is not None else 0.00

                print(f"{cuit:>15} | {ant:>8} | {rect:>7} | {fecha:>12} | {oblig:>15} | {imp:>15.2f}")
                
            return len(rows)
    except Exception as e:
        print(f" Error buscando detalles huérfanos: {e}")
    finally:
        conn.close()       
        
  
def auditoria_origen_afip(tipo_contrib): # <-- Agregamos el parámetro
    conn = get_connection()
    if not conn: return 0

    try:
        cursor = conn.cursor()
        print(f"\n" + "!"*75)
        print(f"ALERTA: TRANSACCIONES EN MULAT NO ENCONTRADAS EN CABECERA ({tipo_contrib})")
        print("!"*75)
        
        cursor.execute(queries.SQL_NO_CABECERA_MULAT)
        rows = cursor.fetchall()
        
        if not rows:
            print("Sincronización perfecta: Mulat y Cabecera coinciden.")
            return 0
        else:
            # ... (tu código de impresión de tabla aquí) ...
            # headers = [...]
            # print(...)
            return len(rows) # <-- IMPORTANTE: retornamos la cantidad para el IF del main

    except Exception as e:
        print(f" Error en auditoría Mulat: {e}")
        return 0
    finally:
        conn.close()
        
# main.py

def ejecutar_remediacion_mulat(tipo_contrib):
    conn = get_connection()
    if not conn: return

    try:
        cursor = conn.cursor()
        print(f"\n" + "⚙️" * 30)
        print("EJECUTANDO REMEDIACIÓN: RESETEO DE PROCESADO_ANALITIC EN MULAT")
        
        # Ejecutamos el Update
        cursor.execute(queries.SQL_UPDATE_MULAT_CONVENIO)
        filas_afectadas = cursor.rowcount
        
        # Confirmamos los cambios
        conn.commit()
        
        print(f" Proceso finalizado exitosamente.")
        print(f"Filas marcadas para reprocesar: {filas_afectadas}")
        
    except Exception as e:
        print(f" Error durante el Update en Mulat: {e}")
        conn.rollback() # Si algo sale mal, deshacemos cambios
    finally:
        conn.close()
        
        
# main.py


def ejecutar_remediacion_directo():
    conn = get_connection()
    if not conn: return

    try:
        cursor = conn.cursor()
        
        print("INICIANDO REMEDIACIÓN INTEGRAL DE DIRECTOS (TCSPROD)")
        
        # 1. Update para los que no tienen Detalle (Seteamos 'N')
        print("Pasando a 'N' registros sin Detalle...")
        cursor.execute(queries.SQL_UPDATE_NO_DETALLE_DIRECTO)
        u_detalle = cursor.rowcount
        
        # 2. Update para los que no tienen Cabecera (Seteamos 'C')
        print("Pasando a 'C' registros sin Cabecera...")
        cursor.execute(queries.SQL_UPDATE_NO_CABECERA_DIRECTO)
        u_cabecera = cursor.rowcount
        
        # Confirmamos AMBOS cambios
        conn.commit()
        
        print(f"\n Remediación finalizada con éxito.")
        print(f" Reseteados a 'N' (Sin Detalle): {u_detalle}")
        print(f" Marcados como 'C' (Sin Cabecera): {u_cabecera}")
        

    except Exception as e:
        print(f"Error crítico en remediación Directo: {e}")
        conn.rollback() # Deshace todo si falla algún paso
    finally:
        conn.close()
        
    
if __name__ == "__main__":
    print("========================================")
    print("         SISTEMA DE AUDITORÍA   ")
    print("========================================")
    
    # 1. Selección de perfil
    opcion = input("Seleccione tipo (1: Directo, 2: Convenio): ")
    tipo_seleccionado = 'Directo' if opcion == '1' else 'Convenio'
    
    print(f"\nIniciando proceso para: {tipo_seleccionado.upper()}")
    print("-" * 40)

    # 2. Auditorías Generales (Solo del tipo seleccionado)
    auditoria_actividades(tipo_seleccionado)
    comparar_cuit_por_tipo(tipo_seleccionado)
    reporte_anticipo_por_tipo(tipo_seleccionado)
    
    # 3. Auditorías de Integridad (Guardamos resultados para decidir remediación)
    err_cab = buscar_huerfanos_cabecera(tipo_seleccionado)
    err_det = buscar_huerfanos_detalle(tipo_seleccionado)
    
    # 4. Lógica específica por Tipo
    if tipo_seleccionado == 'Convenio':
        # Reporte extra de AFIP/Mulat
        err_mulat = auditoria_origen_afip(tipo_seleccionado)
        
        # Remediación Inteligente
        if err_mulat > 0 or err_cab > 0 or err_det > 0:
            print(f"\nInconsistencias detectadas: Mulat({err_mulat})")
            res = input("¿Ejecutar remediación automática en MULAT? (s/n): ")
            if res.lower() == 's':
                ejecutar_remediacion_mulat()
        else:
            print("\n Todo en orden para Convenio. No hace falta remediar.")

    elif tipo_seleccionado == 'Directo':
        # Remediación Inteligente
        if err_cab > 0 or err_det > 0:
            print(f"\n Inconsistencias detectadas: {err_cab + err_det} registros.")
            res = input("¿Desea resetear registros 'S' en TCSPROD? (s/n): ")
            if res.lower() == 's':
                ejecutar_remediacion_directo()
        else:
            print("\n Integridad perfecta en Directos. No hace falta remediar.")

    print("\n Proceso finalizado.")