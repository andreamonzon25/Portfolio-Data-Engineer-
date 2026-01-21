

SQL_DUPLIC_ACTIVIDAD = """
SELECT
    ANIO,
    ACTIVIDAD,
    COUNT(DISTINCT DESC_ACTIVIDAD) AS DESCRIPCIONES_INCONSISTENTES
FROM
    ANALITIC.DETALLE_DJ
WHERE
    tipo_contrib = :tipo
GROUP BY
    ANIO,
    ACTIVIDAD
HAVING
    COUNT(DISTINCT DESC_ACTIVIDAD) > 1
ORDER BY
    ANIO ASC,
    ACTIVIDAD
"""


SQL_COMP_CUIT = """
SELECT 
    c.cuit,
    c.anticipo,
    c.impuesto_cabecera,
    d.impuesto_detalle,
    (trunc(c.impuesto_cabecera) - trunc(d.impuesto_detalle)) AS diferencia
FROM (
    SELECT cuit, anticipo, SUM(impuesto_determinado) AS impuesto_cabecera
    FROM analitic.cabecera_dj
    WHERE anticipo >= 202501 
      AND tipo_contri = :tipo
      AND (:tipo <> 'Convenio' OR CM04 = 'N') -- Si es Convenio filtra CM04, si no, pasa de largo
    GROUP BY cuit, anticipo
) c
JOIN (
    SELECT cuit, anticipo, SUM(impuesto) AS impuesto_detalle
    FROM analitic.detalle_dj
    WHERE anticipo >= 202501 
      AND tipo_contrib = :tipo
      AND (:tipo <> 'Convenio' OR procesado_art8 = 'N') -- Lo mismo para el detalle
    GROUP BY cuit, anticipo
) d
ON c.cuit = d.cuit AND c.anticipo = d.anticipo
WHERE (trunc(c.impuesto_cabecera) - trunc(d.impuesto_detalle)) <> 0
ORDER BY anticipo, cuit
"""


# queries.py

SQL_COMP_ANTICIPO = """
SELECT 
    c.anticipo,
    c.impuesto_cabecera,
    c.porcentaje_cabecera,
    d.impuesto_detalle,
    d.porcentaje_detalle,
    (c.impuesto_cabecera - d.impuesto_detalle) AS diferencia_absoluta,
    CASE WHEN d.impuesto_detalle = 0 THEN NULL
         ELSE ROUND(((c.impuesto_cabecera - d.impuesto_detalle) * 100 / d.impuesto_detalle), 2)
    END AS diferencia_porcentual,
    sysdate AS fecha_proceso
FROM (
    SELECT 
        anticipo, 
        SUM(impuesto_determinado) AS impuesto_cabecera,
        ROUND((SUM(impuesto_determinado) * 100) / SUM(SUM(impuesto_determinado)) OVER (), 2) AS porcentaje_cabecera
    FROM analitic.cabecera_dj
    WHERE anticipo >= 202501 AND tipo_contri = :tipo
    GROUP BY anticipo
) c
JOIN (
    SELECT 
        anticipo,
        SUM(impuesto) AS impuesto_detalle,
        ROUND((SUM(impuesto) * 100) / SUM(SUM(impuesto)) OVER (), 2) AS porcentaje_detalle
    FROM analitic.detalle_dj
    WHERE anticipo >= 202501 AND tipo_contrib = :tipo
    GROUP BY anticipo
) d ON c.anticipo = d.anticipo
ORDER BY anticipo
"""

# queries.py
SQL_NO_DETALLE_DIRECTO = """
SELECT c.CUIT, c.ANTICIPO, c.NUMERO_RECTIFICATIVA, c.FECHA_PRESENTACION,
       c.NUMERO_OBLIGACION_IMPUESTO, c.IMPUESTO_DETERMINADO
FROM analitic.cabecera_dj c
WHERE c.anticipo >= 202501
  AND c.tipo_contri = 'Directo'
  AND NOT EXISTS (
      SELECT 1
      FROM analitic.detalle_dj d
      WHERE d.anio = c.anio
        AND d.numero_cuota = c.numero_cuota
        AND d.numero_rectificativa = c.numero_rectificativa
        AND d.tipo_contrib = 'Directo'
        AND d.numero_obligacion_impuesto = c.numero_obligacion_impuesto
  )
"""

SQL_NO_DETALLE_CONVENIO = """
SELECT c.CUIT, c.ANTICIPO, c.NUMERO_RECTIFICATIVA, c.FECHA_PRESENTACION,
       c.NUMERO_OBLIGACION_IMPUESTO, c.IMPUESTO_DETERMINADO
FROM analitic.cabecera_dj c
WHERE c.anticipo >= 202501
  AND c.tipo_contri = 'Convenio'
  AND NOT EXISTS (
      SELECT 1
      FROM analitic.detalle_dj d
      WHERE d.anio = c.anio
        AND d.numero_cuota = c.numero_cuota
        AND d.numero_rectificativa = c.numero_rectificativa
        AND d.tipo_contrib = 'Convenio'
        AND d.cuit = c.cuit
  )
"""

# queries.py
SQL_NO_CABECERA_DIRECTO = """
SELECT CUIT, ANTICIPO, NUMERO_RECTIFICATIVA, FECHA_PRESENTACION, NUMERO_OBLIGACION_IMPUESTO, IMPUESTO
FROM analitic.detalle_dj c
WHERE c.anticipo >= 202501 AND c.tipo_contrib = 'Directo'
  AND NOT EXISTS (
      SELECT 1 FROM analitic.cabecera_dj d
      WHERE d.numero_obligacion_impuesto = c.numero_obligacion_impuesto
        AND d.anio = c.anio AND d.numero_rectificativa = c.numero_rectificativa
        AND d.tipo_contri = 'Directo'
  )
"""

SQL_NO_CABECERA_CONVENIO = """
SELECT CUIT, ANTICIPO, NUMERO_RECTIFICATIVA, FECHA_PRESENTACION, NUMERO_OBLIGACION_IMPUESTO, IMPUESTO
FROM analitic.detalle_dj c
WHERE c.anticipo >= 202501 AND c.tipo_contrib = 'Convenio'
  AND NOT EXISTS (
      SELECT 1 FROM analitic.cabecera_dj d
      WHERE d.cuit = c.cuit
        AND d.anio = c.anio AND d.numero_rectificativa = c.numero_rectificativa
        AND d.tipo_contri = 'Convenio'
  )
"""

# queries.py

SQL_NO_CABECERA_MULAT = """
 SELECT 
    t.transaccion_afip,
    t.fecha_alta,
    t.procesado,
    t.fecha_proceso,t.fecha_proceso_analitic
FROM mulat.transacciones_proceso@mulat.dgrcorrientes.gov.ar t
WHERE t.procesado = 'S'
  AND t.procesado_analitic IN ('S', 'C')
  AND EXTRACT(YEAR FROM t.fecha_proceso_analitic) > 2025
  AND NOT EXISTS (
      SELECT 1
      FROM analitic.cabecera_dj b
      WHERE b.anio > 2024
        AND b.numero_cuota >= 1
        AND b.tipo_contri = 'Convenio'
        AND t.transaccion_afip = b.transaccion_afip
  )
"""

# queries.py

SQL_UPDATE_MULAT_CONVENIO = """
UPDATE mulat.transacciones_proceso@mulat.dgrcorrientes.gov.ar t 
SET t.procesado_analitic = 'N'
WHERE t.procesado = 'S'
  AND t.procesado_analitic IN ('S', 'C') 
  AND EXTRACT(YEAR FROM fecha_proceso_analitic) > 2024 
  AND NOT EXISTS (
      SELECT 1
      FROM analitic.cabecera_dj b
      WHERE b.anio > 2023
        AND b.numero_cuota >= 1
        AND b.tipo_contri = 'Convenio' 
        AND t.transaccion_afip = b.transaccion_afip
  )
"""

# queries.py

SQL_UPDATE_NO_DETALLE_DIRECTO = """
UPDATE ddjj_para_procesar@tcsprod.dgrcorrientes.gov.ar p
SET p.procesada = 'N',
    p.fecha_proceso = NULL
WHERE p.procesada = 'S'
  AND p.anio = 2025
  AND p.numero_cuota >= 1
  AND NOT EXISTS (
      SELECT 1
      FROM analitic.detalle_dj d
      WHERE d.numero_obligacion_impuesto = p.numero_obligacion_impuesto
        AND d.anio = p.anio
        AND d.numero_cuota = p.numero_cuota
        AND d.numero_rectificativa = p.numero_rectificativa
        AND d.tipo_contrib = 'Directo'
  )
"""

# queries.py

SQL_UPDATE_NO_CABECERA_DIRECTO = """
UPDATE ddjj_para_procesar@tcsprod.dgrcorrientes.gov.ar p
SET p.procesada = 'C',
    p.fecha_proceso = NULL
WHERE p.procesada = 'S'
  AND p.anio = 2025
  AND p.numero_cuota >= 1
  AND NOT EXISTS (
      SELECT 1
      FROM analitic.cabecera_dj d
      WHERE d.numero_obligacion_impuesto = p.numero_obligacion_impuesto
        AND d.anio = p.anio
        AND d.numero_cuota = p.numero_cuota
        AND d.numero_rectificativa = p.numero_rectificativa
        AND d.tipo_contri = 'Directo'
  )
"""