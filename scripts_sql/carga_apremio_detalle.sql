CREATE OR REPLACE PROCEDURE carga_apremios_detalle AS
  v_fecha_remota DATE;
  v_fecha_local DATE;
  v_ultimo_dia_mes_anterior DATE;
  v_registros INT;
BEGIN
  -- 1. Obtención de Metadatos
  SELECT MAX(fecha_corte) INTO v_fecha_remota 
  FROM estadistico_apremios_detalle@tcsdisc;

  SELECT MAX(fecha_corte) INTO v_fecha_local 
  FROM analitic.apremios_detalle;

  -- Último día del mes pasado de forma simplificada
  v_ultimo_dia_mes_anterior := LAST_DAY(ADD_MONTHS(TRUNC(SYSDATE), -1));

  -- 2. Validación de Carga
  IF v_fecha_remota = v_ultimo_dia_mes_anterior AND 
     (v_fecha_local IS NULL OR v_fecha_remota > v_fecha_local) THEN

    -- CARGA 1: Datos Crudos
    INSERT INTO analitic.apremios_detalle
    SELECT *
    FROM estadistico_apremios_detalle@tcsdisc
    WHERE fecha_corte = v_fecha_remota;
    
    v_registros := SQL%ROWCOUNT; -- Capturamos registros insertados

    -- CARGA 2: Transformación (Enriquecimiento con usuario_alta)
    -- Es una buena práctica listar las columnas destino explícitamente
    INSERT INTO analitic.tbl_apremios_detalle (
        TITULO_EJECUTIVO, SALDO_DEUDA_PLAN_ACT, SALDO_DEUDA_PLAN, 
        SALDO_DEUDA_APREMIO_ACT, SALDO_DEUDA_APREMIO, PLAN_FACILIDAD, 
        PAGO_ID, MONTO_PLAN_FINANCIAR, MONTO_PLAN, JUICIO_ID, 
        INTERESES_FINANCIACION, IMPUESTO, IMPORTE_PLAN_FACILIDAD, 
        IMPORTE_PAGO, IMPORTE_INTERESES, IMPORTE_INGRESADO, 
        FECHA_PROCESO, FECHA_PLAN, FECHA_INICIO, FECHA_CORTE, 
        FECHA_CANCELACION, ESTADO_PLAN, DEUDA_APREMIO_INCLUIDA, 
        DEUDA_APREMIO_ACT_EMISION, DESCUENTOS, CREDITO_REVER, 
        CONTRIBUYENTE, CONCEPTO_OBLIGACION, CLAVE_IMPONIBLE, 
        CANT_VENC_PLAN, CANT_VENC_JUICIOS, CANT_PAGOS, ANTICIPO, 
        ANIO_INICIO_JUICIO, USUARIO_ALTA
    )
    SELECT 
        a.TITULO_EJECUTIVO, a.SALDO_DEUDA_PLAN_ACT, a.SALDO_DEUDA_PLAN,
        a.SALDO_DEUDA_APREMIO_ACT, a.SALDO_DEUDA_APREMIO, a.PLAN_FACILIDAD,
        a.PAGO_ID, a.MONTO_PLAN_FINANCIAR, a.MONTO_PLAN, a.JUICIO_ID,
        a.INTERESES_FINANCIACION, a.IMPUESTO, a.IMPORTE_PLAN_FACILIDAD,
        a.IMPORTE_PAGO, a.IMPORTE_INTERESES, a.IMPORTE_INGRESADO,
        a.FECHA_PROCESO, a.FECHA_PLAN, a.FECHA_INICIO, a.FECHA_CORTE,
        a.FECHA_CANCELACION, a.ESTADO_PLAN, a.DEUDA_APREMIO_INCLUIDA,
        a.DEUDA_APREMIO_ACT_EMISION, a.DESCUENTOS, a.CREDITO_REVER,
        a.CONTRIBUYENTE, a.CONCEPTO_OBLIGACION, a.CLAVE_IMPONIBLE,
        a.CANT_VENC_PLAN, a.CANT_VENC_JUICIOS, a.CANT_PAGOS, a.ANTICIPO,
        a.ANIO_INICIO_JUICIO, j.usuario_alta
    FROM analitic.apremios_detalle a
    LEFT JOIN analitic.vw_tbl_juicios j ON j.juicio_id = a.juicio_id
    WHERE a.fecha_corte = v_fecha_remota;

    -- 3. Logging de Éxito
    INSERT INTO analitic.log_actualizaciones (
        nombre_tabla, registros_cargados, fecha_corte, estado, fecha_proceso
    ) VALUES (
        'APREMIOS_DETALLE', v_registros, v_fecha_remota, 'EXITOSO', SYSDATE
    );

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Carga Detalle Finalizada: ' || v_registros || ' filas.');

  ELSE
    DBMS_OUTPUT.PUT_LINE('Condición no cumplida para carga de detalle.');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    INSERT INTO analitic.log_actualizaciones (
        nombre_tabla, estado, observaciones, fecha_proceso
    ) VALUES (
        'APREMIOS_DETALLE', 'ERROR', SUBSTR(SQLERRM, 1, 250), SYSDATE
    );
    COMMIT;
END carga_apremios_detalle;