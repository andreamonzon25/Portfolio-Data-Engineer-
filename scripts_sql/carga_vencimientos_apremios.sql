CREATE OR REPLACE PROCEDURE carga_vencimientos_apremios AS
    v_fecha_remota   DATE;
    v_fecha_local    DATE;
    v_fecha_corte    DATE;
    v_registros      INT;
BEGIN
    -- 1. Obtener metadatos de control
    SELECT MAX(fecha_corte) INTO v_fecha_remota 
    FROM vencimientos_apremios@tcsdisc;

    SELECT MAX(fecha_corte) INTO v_fecha_local 
    FROM analitic.vencimientos_apremios;

    -- Simplificación de fecha: Último día del mes anterior
    v_fecha_corte := LAST_DAY(ADD_MONTHS(TRUNC(SYSDATE), -1));

    -- 2. Validación de carga (Idempotencia y Disponibilidad)
    IF v_fecha_remota = v_fecha_corte AND 
       (v_fecha_local IS NULL OR v_fecha_remota > v_fecha_local) THEN

        -- Inserción en tabla de Staging (Datos crudos)
        INSERT INTO analitic.vencimientos_apremios
        SELECT * FROM vencimientos_apremios@tcsdisc
        WHERE fecha_corte = v_fecha_remota;
        
        v_registros := SQL%ROWCOUNT;

        -- Inserción en tabla de Producción/Analítica
        -- Nota: Es mejor listar las columnas explícitamente en lugar de SELECT *
        INSERT INTO analitic.tbl_vencimientos_apremios
        SELECT * FROM vencimientos_apremios@tcsdisc
        WHERE fecha_corte = v_fecha_remota;

        -- 3. Registro en log de auditoría
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, registros_cargados, fecha_corte, estado, fecha_proceso
        ) VALUES (
            'VENCIMIENTOS_APREMIOS', v_registros, v_fecha_remota, 'EXITOSO', SYSDATE
        );

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Carga exitosa: ' || v_registros || ' registros.');

    ELSE
        DBMS_OUTPUT.PUT_LINE('SKIP: Datos ya actualizados o remota no disponible para ' || v_fecha_corte);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, estado, observaciones, fecha_proceso
        ) VALUES (
            'VENCIMIENTOS_APREMIOS', 'ERROR', SUBSTR(SQLERRM, 1, 250), SYSDATE
        );
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END carga_vencimientos_apremios;