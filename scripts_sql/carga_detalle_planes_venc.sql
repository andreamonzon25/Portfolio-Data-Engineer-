CREATE OR REPLACE PROCEDURE carga_detalle_planes_vencimientos AS
    v_fecha_corte DATE;
    v_registros   NUMBER;
    v_existe      NUMBER;
    v_existe_cab  NUMBER;
BEGIN
    -- 1. Estandarización de la fecha de corte
    v_fecha_corte := TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, -1)));

    -- 2. Validación de dependencias (Check de integridad referencial)
    SELECT COUNT(*) INTO v_existe_cab
    FROM analitic.cabecera_planes_facilidades
    WHERE fecha_corte = v_fecha_corte;

    -- 3. Check de Idempotencia (Evitar duplicados)
    SELECT COUNT(*) INTO v_existe
    FROM analitic.detalle_planes_vencimientos
    WHERE fecha_corte = v_fecha_corte;

    IF v_existe_cab > 0 AND v_existe = 0 THEN
        -- 4. Inserción optimizada (Eliminamos la subquery IN para mayor velocidad)
        INSERT INTO analitic.detalle_planes_vencimientos (
            plan_facilidad, anio, impuesto, concepto_obligacion,
            numero_obligacion_impuesto, numero_cuota, numero_rectificativa,
            clave_imponible, importe_plan_facilidad, fecha_corte
        )
        SELECT 
            a.plan_facilidad,
            v.anio,
            v.impuesto,
            v.concepto_obligacion,
            v.numero_obligacion_impuesto,
            v.numero_cuota,
            v.numero_rectificativa,
            v.clave_imponible,
            v.importe_plan_facilidad,
            v_fecha_corte
        FROM 
            analitic.cabecera_planes_facilidades a
        JOIN 
            tbl_vencimientos@tcsdisc v 
            ON a.plan_facilidad = v.plan_facilidad_included
        WHERE 
            a.fecha_corte = v_fecha_corte;

        v_registros := SQL%ROWCOUNT; -- Eficiencia pura: evitamos otro SELECT COUNT

        -- 5. Registro de trazabilidad
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, registros_cargados, fecha_corte, estado, fecha_proceso
        ) VALUES (
            'DETALLE_PLANES_VENCIMIENTOS', v_registros, v_fecha_corte, 'EXITOSO', SYSDATE
        );

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Carga exitosa: ' || v_registros || ' registros vinculados.');

    ELSIF v_existe_cab = 0 THEN
        DBMS_OUTPUT.PUT_LINE('SKIP: No se encontró cabecera para la fecha ' || v_fecha_corte);
    ELSE
        DBMS_OUTPUT.PUT_LINE('SKIP: Datos ya existentes para la fecha corte.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, estado, observaciones, fecha_proceso
        ) VALUES (
            'DETALLE_PLANES_VENCIMIENTOS', 'ERROR', SUBSTR(SQLERRM, 1, 250), SYSDATE
        );
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Error crítico: ' || SQLERRM);
END carga_detalle_planes_vencimientos;