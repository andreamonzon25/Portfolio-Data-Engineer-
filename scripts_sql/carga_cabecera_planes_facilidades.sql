CREATE OR REPLACE PROCEDURE carga_cabecera_planes_facilidades AS
    v_fecha_corte DATE;
    v_registros   NUMBER;
    v_existe      NUMBER;
BEGIN
    -- 1. Definir la fecha de corte una sola vez para consistencia y legibilidad
    v_fecha_corte := TRUNC(LAST_DAY(ADD_MONTHS(SYSDATE, -1)));

    -- 2. Verificar si ya existe en la tabla
    SELECT COUNT(*)
    INTO v_existe
    FROM analitic.cabecera_planes_facilidades
    WHERE fecha_corte = v_fecha_corte;

    IF v_existe = 0 THEN
        -- 3. Insertar con lógica de negocio integrada
        INSERT INTO analitic.cabecera_planes_facilidades (
            cuotas_generadas, estado, fecha_corte, fecha_generacion,
            importe_descuento, interes_de_actualizacion, interes_de_financiacion,
            numero_acogimiento, plan_facilidad, saldo_a_financiar,
            tipo_plan_facilidades, tipo_plan_facilidades_abrev,
            total_deuda, total_deuda_incluida, total_plan,
            valor_anticipo, valor_cuota_total, usuario_alta
        )
        SELECT 
            r.cuotas_generadas,
            r.estado,
            v_fecha_corte, -- Usamos la variable definida arriba
            r.fecha_generacion,
            r.importe_descuento,
            (r.total_deuda - r.total_deuda_incluida) AS interes_de_actualizacion,
            r.interes_finan_calc AS interes_de_financiacion,
            r.numero_acogimiento,
            r.plan_facilidad,
            r.saldo_finan_calc AS saldo_a_financiar,
            r.tipo_plan_facilidades,
            r.tipo_plan_facilidades_abrev,
            r.total_deuda,
            r.total_deuda_incluida,
            (r.total_deuda + r.interes_finan_calc) AS total_plan,
            r.valor_anticipo,
            r.valor_cuota_total,
            r.usuario_alta
        FROM (
            SELECT 
                pf.plan_facilidad,
                pf.tipo_plan_facilidades,
                dp.tipo_plan_facilidades_abrev,
                pf.numero_acogimiento,
                pf.fecha_generacion,
                pf.total_deuda,
                pf.valor_anticipo,
                pf.valor_cuota_total,
                pf.cuotas_generadas,
                pf.importe_descuento,
                pf.usuario_alta,
                -- Llamada a función remota para estado
                pa_cuentas_corrientes.plan@tcsdisc(sysdate, pf.plan_facilidad) AS estado,
                -- Subquery para total deuda incluida
                (SELECT SUM(importe_plan_facilidad)
                 FROM tbl_vencimientos@tcsdisc
                 WHERE plan_facilidad_incluido = pf.plan_facilidad) AS total_deuda_incluida,
                -- Cálculos intermedios
                ((pf.valor_cuota_total - pf.valor_cuotas) * pf.cantidad_cuotas_anio) AS interes_finan_calc,
                (pf.valor_cuota_total * 12) AS saldo_finan_calc
            FROM 
                tbl_planes_facilidades@tcsdisc pf
            JOIN 
                tbl_tipos_planes_facilidades@tcsdisc dp 
                ON pf.tipo_plan_facilidades = dp.tipo_plan_facilidades
        ) r;

        -- Capturamos registros insertados sin re-consultar la tabla (eficiencia)
        v_registros := SQL%ROWCOUNT;

        -- 4. Registrar en log de éxito
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, registros_cargados, fecha_corte, fecha_proceso, estado
        ) VALUES (
            'CABECERA_PLANES_FACILIDADES', v_registros, v_fecha_corte, SYSDATE, 'EXITOSO'
        );

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Carga exitosa: ' || v_registros || ' registros.');

    ELSE
        DBMS_OUTPUT.PUT_LINE('La fecha_corte ' || TO_CHAR(v_fecha_corte, 'DD/MM/YYYY') || ' ya está cargada.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        -- Log de error para trazabilidad en el portfolio
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, estado, observaciones, fecha_proceso
        ) VALUES (
            'CABECERA_PLANES_FACILIDADES', 'ERROR', SUBSTR(SQLERRM, 1, 250), SYSDATE
        );
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END carga_cabecera_planes_facilidades;