create or replace PROCEDURE                                              carga_detalledjib_incre_test IS

    -- =============================================================================
-- Author: Andrea Monzòn
-- Description: ETL de Carga Incremental para Contribuyentes Directos.
--              Implementa estrategia de Upsert (MERGE) para manejar 
--              rectificativas y optimizar el rendimiento en tablas masivas.
-- Volumen: Diseñado para entornos de +30M de registros.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ANTES (Legacy): Se utilizaba un bucle FOR con un DELETE y un INSERT por cada registro.
--   - Problema: Generaba latencia por "Context Switching" entre PL/SQL y SQL.
--   - Problema: Alto consumo de UNDO/REDO TABLESPACE al procesar millones de filas.
--
-- AHORA (Optimizado): Se implementa lógica SET-BASED mediante sentencia MERGE.
--   - Mejora: Operación atómica que reduce el I/O en el servidor Oracle.
--   - Mejora: Idempotencia garantizada sin necesidad de borrar datos previamente.
--   - Escala: Diseñado para tablas históricas de +30M de registros.
-- =============================================================================

    -- Definimos constantes para los filtros de negocio
    v_impuesto_id     VARCHAR2(4) := '0035';
    v_concepto_id     VARCHAR2(4) := '0017';
    v_anio_corte      NUMBER      := 2024;

BEGIN
    -- 1. OPERACIÓN DE CARGA MASIVA (UPSERT)
    -- El MERGE es más eficiente que DELETE + INSERT en tablas de gran escala
    MERGE INTO CORE_DATA.DETALLE_DJ dest
    USING (
        -- Origen: Vista de transformación que ya trae los datos limpios de la capa RAW
        SELECT * FROM CORE_DATA.VW_DDJJ_TRANSFORMADA
        WHERE anio > v_anio_corte
    ) src
    ON (
        dest.numero_obligacion_impuesto = src.numero_obligacion_impuesto AND
        dest.numero_rectificativa = src.numero_rectificativa AND
        dest.actividad = src.actividad AND
        dest.tipo_contrib = 'Directo'
    )
    -- CASO A: El registro ya existe (Se actualiza por posible rectificativa)
    WHEN MATCHED THEN
        UPDATE SET 
            dest.base_imponible   = src.base,
            dest.impuesto         = src.impuesto,
            dest.alicuota_declarada = src.alicuota,
            dest.fecha_presentacion = src.fecha_presentacion,
            dest.modo_proceso     = 'U', -- 'U' de Update
            dest.fecha_actualizacion = SYSDATE

    -- CASO B: El registro es nuevo (Se inserta en la tabla analítica)
    WHEN NOT MATCHED THEN
        INSERT (
            tipo_contrib, cuit, anticipo, anticipo_fecha, anio, numero_cuota,
            cod_grupo, desc_grupo, cod_subgrupo, desc_subgrupo, actividad,
            desc_actividad, base_imponible, impuesto, alicuota_declarada,
            numero_rectificativa, fecha_presentacion, numero_obligacion_impuesto, 
            modo_proceso, fecha_carga
        )
        VALUES (
            'Directo',
            src.cuit,
            src.anio || LPAD(src.numero_cuota, 2, '0'),
            TO_DATE(src.anio || LPAD(src.numero_cuota, 2, '0') || '01', 'YYYYMMDD'),
            src.anio,
            src.numero_cuota,
            src.cod_grupo,
            src.grupo_descrip,
            src.cod_subgrupo,
            src.subgrupo_descrip,
            src.actividad,
            src.act_descrip,
            src.base,
            src.impuesto,
            src.alicuota,
            src.numero_rectificativa,
            src.fecha_presentacion,
            src.numero_obligacion_impuesto,
            'I', -- 'I' de Insert
            SYSDATE
        );

    -- 2. ACTUALIZACIÓN DE TRAZABILIDAD EN ORIGEN (BATCH UPDATE)
    -- En lugar de actualizar fila por fila en un loop, lo hacemos en un solo bloque 
    -- para reducir la latencia de red del DBLink.
    UPDATE RAW_DATA.DDJJ_PARA_PROCESAR@REMOTE_PROD o
       SET o.procesada = 'C', -- 'C' de Completado
           o.fecha_proceso = SYSDATE
     WHERE o.procesada = 'N'
       AND o.impuesto = v_impuesto_id
       AND o.concepto_obligacion = v_concepto_id
       AND o.anio > v_anio_corte
       -- Solo marcamos lo que efectivamente procesamos en el paso anterior
       AND EXISTS (
           SELECT 1 
           FROM CORE_DATA.VW_DDJJ_TRANSFORMADA v
           WHERE v.numero_obligacion_impuesto = o.numero_obligacion_impuesto
             AND v.anio = o.anio
             AND v.numero_cuota = o.numero_cuota
             AND v.numero_rectificativa = o.numero_rectificativa
       );

    -- Confirmamos los cambios de forma atómica
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('Proceso finalizado');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        -- Registro de error (Sugerencia: podrías insertar en una tabla de LOG_ERRORES)
        DBMS_OUTPUT.PUT_LINE('ERROR en detalle_dj: ' || SQLERRM);
        RAISE;
END ;carga_detalledjib_incre_test;


       /* CURSOR transacciones IS
        SELECT *
        FROM ddjj_para_procesar
        WHERE procesada = 'N'
          AND anio > 2024
          AND numero_cuota >= 1 ;

    CURSOR detalle (
        p_numero_obligacion    NUMBER,
        p_anio                 NUMBER,
        p_numero_cuota         NUMBER,
        p_numero_rectificativa NUMBER
    ) IS
        SELECT DISTINCT *
        FROM analitic.vw_ddjj_para_procesar
        WHERE numero_obligacion_impuesto = p_numero_obligacion
          AND anio = p_anio
          AND numero_cuota = p_numero_cuota
          AND numero_rectificativa = p_numero_rectificativa;

    v_count NUMBER;
BEGIN
    FOR c1_reg IN transacciones LOOP
        BEGIN
            -- ✅ Verifica si hay registros en la vista antes de intentar insertar
            SELECT COUNT(*)
            INTO v_count
            FROM analitic.vw_ddjj_para_procesar
            WHERE numero_obligacion_impuesto = c1_reg.numero_obligacion_impuesto
              AND anio = c1_reg.anio
              AND numero_cuota = c1_reg.numero_cuota
              AND numero_rectificativa = c1_reg.numero_rectificativa;

            IF v_count > 0 THEN
                --  Elimina registros anteriores
                DELETE FROM analitic.detalle_dj
                 WHERE numero_obligacion_impuesto = c1_reg.numero_obligacion_impuesto
                   AND anio = c1_reg.anio
                   AND numero_cuota = c1_reg.numero_cuota
                   AND numero_rectificativa = c1_reg.numero_rectificativa
                   AND tipo_contrib = 'Directo';

                --  Inserta nuevos registros desde la vista
                FOR i IN detalle(c1_reg.numero_obligacion_impuesto, c1_reg.anio, c1_reg.numero_cuota, c1_reg.numero_rectificativa) LOOP
                    BEGIN
                        INSERT INTO analitic.detalle_dj (
                            tipo_contrib,
                            cuit,
                            anticipo,
                            anticipo_fecha,
                            anio,
                            numero_cuota,
                            cod_grupo,
                            desc_grupo,
                            cod_subgrupo,
                            desc_subgrupo,
                            actividad,
                            desc_actividad,
                            base_imponible,
                            impuesto,
                            alicuota_declarada,
                            numero_rectificativa,
                            fecha_presentacion,
                            numero_obligacion_impuesto,
                            modo_proceso
                        ) VALUES (
                            'Directo',
                            i.cuit,
                            i.anio || lpad(i.numero_cuota, 2, '0'),
                            TO_DATE(i.anio || lpad(i.numero_cuota, 2, '0') || '01', 'YYYYMMDD'),
                            i.anio,
                            i.numero_cuota,
                            i.cod_grupo,
                            i.grupo_descrip,
                            i.cod_subgrupo,
                            i.subgrupo_descrip,
                            i.actividad,
                            i.act_descrip,
                            i.base,
                            i.impuesto,
                            i.alicuota,
                            i.numero_rectificativa,
                            i.fecha_presentacion,
                            i.numero_obligacion_impuesto,
                            'I'
                        );
                    EXCEPTION
                        WHEN OTHERS THEN
                            dbms_output.put_line(' Error insertando detalle ' ||
                                c1_reg.numero_obligacion_impuesto || ': ' || SQLERRM);
                    END;
                END LOOP;

                --  Solo si encontró detalle, actualiza el estado
                UPDATE ddjj_para_procesar@tcsprod.dgrcorrientes.gov.ar
                   SET procesada = 'C',
                       fecha_proceso = SYSDATE
                 WHERE procesada = 'N'
                   AND impuesto = '0035'
                   AND concepto_obligacion = '0017'
                   AND anio = c1_reg.anio
                   AND numero_cuota = c1_reg.numero_cuota
                   AND numero_rectificativa = c1_reg.numero_rectificativa
                   AND numero_obligacion_impuesto = c1_reg.numero_obligacion_impuesto;

                COMMIT;

                dbms_output.put_line(' Cargado correctamente: ' ||
                    c1_reg.numero_obligacion_impuesto || ' (' ||
                    c1_reg.anio || '-' || c1_reg.numero_cuota || ')');

            ELSE
                dbms_output.put_line('No hay datos en VW_DDJJ_PARA_PROCESAR para obligación ' ||
                    c1_reg.numero_obligacion_impuesto || ' (' ||
                    c1_reg.anio || '-' || c1_reg.numero_cuota || ')');
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                dbms_output.put_line(' Error procesando obligación ' ||
                    c1_reg.numero_obligacion_impuesto || ': ' || SQLERRM);
        END;
    END LOOP;
END;*/



