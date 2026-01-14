-- =============================================================================
-- Author: Andrea Monzòn
-- Description: Conciliación de datos con sistema de Logging de errores.
-- Improvement: Integración de tabla analitic.log_procesos_etl para auditoría.
-- =============================================================================

CREATE OR REPLACE PROCEDURE comparacion_impuestos AS
    v_proc_name     CONSTANT VARCHAR2(100) := 'CREAR_COMPARACION_IMPUESTOS';
    v_inicio        TIMESTAMP := SYSTIMESTAMP;
    v_etapa         VARCHAR2(100);
BEGIN
-- 1. Limpieza de ventana de tiempo actual
    -- Se utiliza una estrategia de reemplazo para el periodo vigente
    v_etapa := 'LIMPIEZA_DATOS';
    DELETE FROM analitic.comparacion_impuestos WHERE anticipo >= 202501;

-- 2. Cálculo de métricas y detección de diferencias (Data Auditing)
    -- Se utilizan Window Functions (OVER) para calcular porcentajes sobre el total
    v_etapa := 'CALCULO_CONCILIACION';
    INSERT INTO analitic.comparacion_impuestos (
        anticipo,
        tipo_contribuyente,
        impuesto_cabecera,
        impuesto_detalle,
        diferencia_absoluta,
        diferencia_porcentual,
        fecha_proceso
    )
    SELECT 
        c.anticipo, c.tipo_contri, c.total_cab, d.total_det,
        (c.total_cab - d.total_det),
        CASE WHEN d.total_det = 0 THEN NULL 
             ELSE ROUND(((c.total_cab - d.total_det) * 100 / d.total_det), 2) END,
        SYSDATE
    FROM (
        SELECT anticipo, tipo_contri, SUM(impuesto_determinado) as total_cab
        FROM analitic.cabecera_dj WHERE anticipo >= 202501
        GROUP BY tipo_contri, anticipo
    ) c
    JOIN (
        SELECT anticipo, tipo_contrib, SUM(impuesto) as total_det
        FROM analitic.detalle_dj WHERE anticipo >= 202501
        GROUP BY tipo_contrib, anticipo
    ) d ON c.anticipo = d.anticipo AND c.tipo_contri = d.tipo_contrib;

    -- Log de éxito (Opcional pero recomendado)
    v_etapa := 'FINALIZADO_OK';
    INSERT INTO analitic.log_procesos_etl (nombre_procedimiento, etapa, mensaje_error, duracion_segundos)
    VALUES (v_proc_name, v_etapa, 'Proceso completado con éxito', 
            EXTRACT(SECOND FROM (SYSTIMESTAMP - v_inicio)));

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        -- Registro automático del error en la tabla de LOGS
        INSERT INTO analitic.log_procesos_etl (
            nombre_procedimiento, 
            etapa, 
            mensaje_error, 
            codigo_oracle, 
            duracion_segundos
        )
        VALUES (
            v_proc_name, 
            v_etapa, 
            SQLERRM, 
            SQLCODE,
            EXTRACT(SECOND FROM (SYSTIMESTAMP - v_inicio))
        );
        COMMIT; -- Commit del log para no perder la traza del error
        RAISE;
END comparacion_impuestos;