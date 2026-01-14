-- =============================================================================
-- Author: Andrea Monzòn
-- Description: ETL para carga granular de Detalle de Declaraciones Juradas.
--              Implementa lógica de negocio para categorización de actividades 
--              (NAES vs CUACM) y normalización de regímenes.
-- Volume: 30 millones
-- =============================================================================

CREATE OR REPLACE PROCEDURE carga_det_djcm-incre IS

    -- Cursor: Selecciona solo transacciones ya validadas en Cabecera (Traceability)
    CURSOR c_pendientes_detalle IS
        SELECT transaccion_afip 
        FROM RAW_DATA.CONTROL_PROCESO
        WHERE procesado = 'S'
          AND procesado_analitic = 'C'; -- 'C' significa que ya pasó por Cabecera

BEGIN
    FOR reg IN c_pendientes_detalle LOOP
        BEGIN
            -- Inserción masiva con transformación de códigos a descripciones
            INSERT INTO CORE_DATA.DETALLE_DJ (
                tipo_contri, cuit, periodo, fecha_periodo, anio, cuota,
                grupo_actividad, desc_grupo, subgrupo, desc_subgrupo,
                cod_actividad, desc_actividad, tratamiento_fiscal, regimen,
                base_imponible, alicuota, impuesto, rectificativa, estado_proceso
            )
            SELECT 
                'Convenio',
                a.cuit,
                SUBSTR(a.anticipo, 1, 6),
                TO_DATE(SUBSTR(a.anticipo, 1, 6) || '01', 'YYYYMMDD'),
                TO_NUMBER(SUBSTR(a.anticipo, 1, 4)),
                TO_NUMBER(SUBSTR(a.anticipo, 5, 2)),
                c.cod_grupo,
                c.desc_grupo,
                c.cod_subgrupo,
                c.desc_subgrupo,
                b.actividad,
                c.desc_actividad,
                -- Normalización de etiquetas para Reporteo (Data Cleaning)
                CASE b.tratamiento 
                    WHEN 0 THEN 'Normal'
                    WHEN 1 THEN 'Exento/Desgravado'
                    WHEN 2 THEN 'Minorista'
                    ELSE 'Otro Tratamiento Fiscal'
                END,
                -- Mapeo de Artículos del Régimen del Convenio Multilateral
                CASE b.regimen 
                    WHEN 1 THEN 'Articulo 2'
                    WHEN 2 THEN 'Articulo 6'
                    WHEN 3 THEN 'Articulo 7'
                    WHEN 4 THEN 'Articulo 8'
                    WHEN 10 THEN 'Articulo 14'
                    ELSE 'Otros Articulos'
                END,
                DECODE(b.signo_base_imponible_final, 1, '-') || b.base_imponible_final,
                b.alicuta,
                DECODE(b.signo_impuesto_determinado, 1, '-') || b.impuesto_determinado,
                a.codigo_rectificativa,
                'I'
            FROM RAW_DATA.DISQUETE_REG_1 a
            JOIN RAW_DATA.DISQUETE_REG_5 b ON a.transaccion_afip = b.transaccion_afip
            JOIN RAW_DATA.DIM_ACTIVIDADES c ON b.actividad = TO_NUMBER(c.cod_actividad)
            WHERE a.transaccion_afip = reg.transaccion_afip
              AND b.jurisdiccion = '905'
              -- Lógica NAES (Nomenclador de Actividades Económicas del Sistema)
              AND c.tipo_act = (CASE WHEN SUBSTR(a.anticipo, 1, 4) >= '2018' THEN 'NAES' ELSE 'CUACM' END)
              AND TO_NUMBER(SUBSTR(a.anticipo, 1, 4)) > 2024;

            -- Marcado de finalización del ciclo de vida de la transacción
            UPDATE RAW_DATA.CONTROL_PROCESO
            SET procesado_analitic = 'S', -- 'S' = Success / Finalizado
                fecha_proceso_analitic = SYSDATE
            WHERE transaccion_afip = reg.transaccion_afip;

            COMMIT;

        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                -- Marcado de error técnico para auditoría
                UPDATE RAW_DATA.CONTROL_PROCESO
                SET procesado_analitic = 'Z', 
                    fecha_proceso_analitic = SYSDATE
                WHERE transaccion_afip = reg.transaccion_afip;
                COMMIT;
        END;
    END LOOP;
END carga_det_djcm-incre;


-- este archivo demuestra:

-- Data Modeling (Relational): Uso de tablas maestras de actividades para enriquecer datos transaccionales.

-- Data Transformation: Uso de CASE y DECODE para transformar códigos técnicos en categorías de negocio legibles (limpieza de datos).

-- SCD (Slowly Changing Dimensions): Manejo de cambios en el tiempo (NAES vs CUACM).

-- Orquestación con Dependencias: El cursor espera a que procesado_analitic = 'C'. Esto significa que el Detalle no puede existir sin su Cabecera.