CREATE OR REPLACE PROCEDURE carga_estado_planes_pagos AS
    v_fecha_corte DATE;
    v_existe      NUMBER;
    v_registros   NUMBER;
BEGIN
    -- 1. Estandarizar fecha (Usamos DATE para performance de índices)
    v_fecha_corte := TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, - 1)));

    -- 2. Verificar existencia
    SELECT COUNT(*) INTO v_existe
    FROM analitic.estado_planes_pagos
    WHERE fecha_corte = v_fecha_corte;

    IF v_existe = 0 THEN
        -- 3. Inserción con Consolidación de Datos
        INSERT INTO analitic.estado_planes_pagos (
            razon_social_ente, impuesto, concepto_id, concepto_abrev, anio, 
            numero_cuota, fecha_venc, numero_rectificativa, fecha_carga, 
            fecha_pago, fecha_acreditacion, fecha_acred_bancaria, cuit, 
            contribuyente, importe_original, importe_intereses, importe_abonado, 
            numero_acogimiento, fecha_actualizacion_deuda, fecha_reversion, 
            estado_plan, fecha_corte, fecha_generacion_plan, numero_obligacion
        )
        SELECT
            b.razon_social,
            c.impuesto,
            c.concepto_obligacion,
            d.concepto_obligacion_abrev,
            f.anio,
            f.numero_cuota,
            f.fecha_primer_vencimiento,
            f.numero_rectificativa,
            TRUNC(c.fecha_movimiento),
            TRUNC(c.fecha_pago),
            TRUNC(c.fecha_acreditacion),
            c.fecha_acreditacion_bancaria,
            e.cuit,
            e.razon_social,
            SUM(NVL(c.importe_original, 0)),
            SUM(NVL(c.importe_intereses, 0)),
            SUM(NVL(c.importe, 0)),
            p.numero_acogimiento,
            p.fecha_actualizacion_deuda,
            p.fecha_reversion,
            -- Invocación de lógica de negocio remota
            pa_cuentas_corrientes.plan@tcsdisc(SYSDATE, p.plan_facilidad),
            v_fecha_corte,
            p.fecha_generacion,
            c.numero_obligacion_impuesto
        FROM
            tbl_entes_recaudadores@tcsdisc a
            JOIN tbl_personas@tcsdisc b ON a.persona_id = b.persona_id
            JOIN tbl_pagos_rendiciones_banc@tcsdisc c ON a.persona_id = c.ente_recaudador
            JOIN tbl_conceptos_obligaciones@tcsdiscd ON c.concepto_obligacion = d.concept_obligacion
            JOIN tbl_personas@tcsdisce ON c.contribuyente = e.persona_id
            JOIN tbl_vencimientos@tcsdisc f ON (
                c.impuesto = f.impuesto AND 
                c.concepto_obligacion = f.concepto_obligacion AND 
                c.numero_obligacion_impuesto = f.numero_obligacion_impuesto AND 
                c.numero_rectificativa = f.numero_rectificativa AND 
                c.numero_cuota = f.numero_cuota
            )
            JOIN tbl_planes_facilidades@tcsdisc p ON f.plan_facilidad = p.plan_facilidad
        WHERE
            c.fecha_anulacion IS NULL
            AND c.concepto_obligacion IN ('0093', '0094', '0097')
        GROUP BY
            b.razon_social, c.impuesto, c.concepto_obligacion, d.concept_obligacion_abrev,
            f.anio, f.numero_cuota, f.fecha_primer_vencimiento, f.numero_rectificativa,
            c.fecha_movimiento, c.fecha_pago, c.fecha_acreditacion, c.numero_obligacion_impuesto,
            e.cuit, e.razon_social, p.numero_acogimiento, p.fecha_actualizacion_deuda,
            p.fecha_reversion, p.plan_facilidad, p.fecha_generacion, c.fecha_acreditacion_bancaria;

        v_registros := SQL%ROWCOUNT;

        -- 4. Registro en Log
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, registros_cargados, fecha_corte, estado, fecha_proceso
        ) VALUES (
            'ESTADO_PLANES_PAGOS', v_registros, v_fecha_corte, 'EXITOSO', SYSDATE
        );

        COMMIT;
    ELSE
        DBMS_OUTPUT.PUT_LINE('SKIP: Carga ya realizada para la fecha de corte.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, estado, observaciones, fecha_proceso
        ) VALUES (
            'ESTADO_PLANES_PAGOS', 'ERROR', SUBSTR(SQLERRM, 1, 250), SYSDATE
        );
        COMMIT;
END carga_estado_planes_pagos;