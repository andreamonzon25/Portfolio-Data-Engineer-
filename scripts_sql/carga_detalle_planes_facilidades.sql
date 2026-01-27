CREATE OR REPLACE PROCEDURE carga_detalle_planes_facilidades AS
    v_fecha_corte DATE;
    v_registros   NUMBER;
    v_existe      NUMBER;
BEGIN
    -- 1. Definimos la fecha de corte como DATE (Evitamos TO_CHAR en comparaciones de fecha)
    v_fecha_corte := TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, -1)));

    -- 2. Verificar existencia (usando la variable DATE)
    SELECT COUNT(*)
    INTO v_existe
    FROM analitic.detalle_planes_facilidades
    WHERE fecha_corte = v_fecha_corte;

    IF v_existe = 0 THEN
        -- 3. Inserción Masiva con llamadas a funciones de interfaz remota
        INSERT INTO analitic.detalle_planes_facilidades (
            cuit, razon_social, plan_facilidad, numero_cuota, fecha_venc,
            numero_acogimiento, importe, importe_actualizado, importe_pagado,
            impuesto, concepto_obligacion, numero_obligacion_impuesto,
            numero_rectificativa, anticipo, fecha_corte
        )
        SELECT
            -- Llamadas a funciones remotas (TCSDISC)
            pa_persona.get_cuit@tcsdisc(v.contribuyente) AS cuit,
            pa_persona.get_razon_social@tcsdisc(v.contribuyente) AS razon_social,
            v.plan_facilidad,
            v.numero_cuota,
            v.fecha_primer_vencimiento AS fecha_venc,
            p.numero_acogimiento,
            -- Cálculo de Importes mediante Business Logic remota
            pa_cuentas_corrientes.importe_original@tcsdisc(
                v.impuesto, v.concepto_obligacion, v.numero_obligacion_impuesto, 
                v.numero_rectificativa, v.numero_cuota) AS importe,
            pa_actualizacion.actualizar_vencimiento@tcsdisc(
                v.impuesto, v.concepto_obligacion, v.numero_obligacion_impuesto, 
                v.numero_rectificativa, v.numero_cuota, v_fecha_corte) AS importe_actualizado,
            ABS(pa_cuentas_corrientes.pagos_vencimiento@tcsdisc(
                v.impuesto, v.concepto_obligacion, v.numero_obligacion_impuesto, 
                v.numero_rectificativa, v.numero_cuota, v_fecha_corte)) AS importe_pagado,
            v.impuesto,
            v.concepto_obligacion,
            v.numero_obligacion_impuesto,
            v.numero_rectificativa,
            -- Formateo de flags
            DECODE(v.cuota_anticipo_plan, 'S', 'Si', 'No') AS anticipo,
            v_fecha_corte AS fecha_corte
        FROM
            tbl_vencimientos@tcsdisc v
        JOIN 
            tbl_planes_facilidades@tcsdisc p 
            ON v.plan_facilidad = p.plan_facilidad;

        -- Capturamos cantidad de registros sin nueva consulta
        v_registros := SQL%ROWCOUNT;

        -- 4. Logging de Auditoría
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, registros_cargados, fecha_corte, estado, fecha_proceso
        ) VALUES (
            'DETALLE_PLANES_FACILIDADES', v_registros, v_fecha_corte, 'EXITOSO', SYSDATE
        );

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Carga Detalle: ' || v_registros || ' registros procesados.');

    ELSE
        DBMS_OUTPUT.PUT_LINE('Carga omitida: La fecha ' || TO_CHAR(v_fecha_corte, 'DD/MM/YYYY') || ' ya existe.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, estado, observaciones, fecha_proceso
        ) VALUES (
            'DETALLE_PLANES_FACILIDADES', 'ERROR', SUBSTR(SQLERRM, 1, 250), SYSDATE
        );
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Error crítico: ' || SQLERRM);
END carga_detalle_planes_facilidades;