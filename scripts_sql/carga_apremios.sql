CREATE OR REPLACE PROCEDURE carga_apremios AS
    v_fecha_remota   DATE;
    v_fecha_local    DATE;
    v_ultimo_dia_mes_anterior DATE;
    v_registros      INT;
BEGIN
    -- 1. Obtener fechas de control
    SELECT MAX(fecha_corte) INTO v_fecha_remota FROM estadistico_apremios@tcsdisc;
    SELECT MAX(fecha_corte) INTO v_fecha_local FROM analitic.apremios;

    -- 2. Simplificación del cálculo de fecha (Último día mes anterior)
    v_ultimo_dia_mes_anterior := LAST_DAY(ADD_MONTHS(TRUNC(SYSDATE), -1));

    -- 3. Validación y Carga
    IF v_fecha_remota = v_ultimo_dia_mes_anterior 
       AND (v_fecha_local IS NULL OR v_fecha_remota > v_fecha_local) THEN

        INSERT INTO analitic.apremios
        SELECT * FROM estadistico_apremios@tcsdisc
        WHERE fecha_corte = v_fecha_remota;
        
        -- Capturamos la cantidad de registros insertados de forma eficiente
        v_registros := SQL%ROWCOUNT;

        -- 4. Registro en Log de éxito
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, registros_cargados, fecha_corte, fecha_proceso, estado
        ) VALUES (
            'APREMIOS', v_registros, v_fecha_remota, SYSDATE, 'EXITOSO'
        );

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Carga exitosa: ' || v_registros || ' registros.');

    ELSE
        DBMS_OUTPUT.PUT_LINE('No se requiere carga. Fecha ya procesada o remota no disponible.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        -- Log de error para que sepas qué falló sin mirar la consola
        INSERT INTO analitic.log_actualizaciones (
            nombre_tabla, estado, observaciones, fecha_proceso
        ) VALUES (
            'APREMIOS', 'ERROR', SUBSTR(SQLERRM, 1, 200), SYSDATE
        );
        COMMIT;
END carga_apremios;


-- SCRIPT PARA PROGRAMAR LA CARGA AUTOMÁTICA
BEGIN
  DBMS_SCHEDULER.create_job (
    job_name        => 'JOB_CARGA_APREMIOS_MENSUAL',
    job_type        => 'STORED_PROCEDURE',
    job_action      => 'carga_apremios',
    start_date      => TRUNC(SYSDATE) + 5, -- Inicia el próximo 5
    repeat_interval => 'FREQ=MONTHLY; BYMONTHDAY=5; BYHOUR=8; BYMINUTE=0',
    enabled         => TRUE,
    comments        => 'Carga de apremios el día 5 de cada mes desde TCSDISC');
END;