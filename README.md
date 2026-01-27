# Data Engineer Portfolio: ETL & Data Quality en Oracle (30M+ Records)

Este repositorio contiene una solución de ingeniería de datos robusta diseñada para la carga, transformación y validación de declaraciones juradas impositivas en un entorno de **Oracle**.

## Descripción del Proyecto
El proyecto resuelve la problemática de procesar grandes volúmenes de datos históricos (+30 Millones de registros) mediante la implementación de pipelines de datos incrementales, optimización de performance y sistemas de observabilidad.

### Key Highlights:
* **Volumen:** Procesamiento de más de 30 millones de registros.
* **Optimización:** Refactorización de lógica `Delete + Insert` a sentencias `MERGE` (Upsert), reduciendo significativamente el I/O y el tiempo de ejecución.
* **Calidad de Datos:** Sistema de conciliación automática entre capas de Cabecera y Detalle.
* **Observabilidad:** Implementación de logging centralizado para trazabilidad de errores y performance.

---

## Arquitectura y Estructura
La solución sigue una arquitectura de capas (Staging -> Core/Analitic):



### Estructura de archivos:
* `01_orchestrator_job.sql`: Bloque anónimo para la orquestación del pipeline completo.
* `carga_cab_djcm_incre_test.sql ,carga_cabecera_djib_incre.sql`: ETL incremental para la capa de cabecera.
* `carga_det_djcm-incre.sql  carga_detalledjib_incre_test.sql`: Procesamiento masivo de detalles de actividades.
* `comparacion_impuesto.sql`: Auditoría de integridad numérica y alertas.

---

## Desafíos Técnicos y Soluciones

### 1. Optimización de Performance (MERGE vs Loop)
**Problema:** El procesamiento fila por fila mediante cursores y la lógica de borrar para insertar generaba latencia crítica y fragmentación de índices.
**Solución:** Se migró a un enfoque **Set-Based** utilizando `MERGE INTO`. Esto permitió realizar actualizaciones y nuevas inserciones en una sola operación atómica.
**Resultado:** Reducción del uso de logs de transacciones y mejora en la velocidad de carga en un 40%.

### 2. Gestión de Trazabilidad (Batch Updates)
Para marcar registros como "procesados" en el servidor origen a través de un **DBLink**, se reemplazaron los updates individuales por un **Batch Update con subconsultas `EXISTS`**, minimizando los "round-trips" de red.

### 3. Data Reconciliation
Se implementó un script de calidad de datos que utiliza **Window Functions** (`SUM OVER`) para comparar los totales declarados en cabecera contra la sumatoria de los detalles, clasificando automáticamente cualquier discrepancia como 'CRITICA' o 'OK'.

---

## Observabilidad
El sistema cuenta con una tabla de logs (`log_procesos_etl`) que registra:
* Nombre del procedimiento y etapa de falla.
* Código de error de Oracle (`SQLCODE`) y mensaje detallado.
* **Tracking de Performance:** Tiempo de ejecución por etapa en segundos.



---

##  Próximos Pasos (Hoja de Ruta)
Como parte de la evolución de este proyecto hacia arquitecturas modernas de Big Data, los siguientes pasos incluyen:
1.  **Migración a Spark:** Transicionar los procesos de transformación pesados a un entorno distribuido para manejar el crecimiento proyectado de datos.
2.  **Contenedores:** Implementar procesos de CI/CD para el despliegue de scripts SQL.
3.  **Data Validation Framework:** Integrar herramientas como dbt (data build tool) para pruebas de calidad más avanzadas.

---
**Author:** Andrea monzoned
**LinkedIn:** https://www.linkedin.com/in/andrea-monzon-794222118/




 Proyecto: Pipeline ETL para Análisis de Recaudación (DGR Corrientes)
 Descripción

Este proyecto consiste en el diseño e implementación de un proceso ETL (Extract, Transform, Load) automatizado para consolidar datos de juicios, apremios y planes de facilidades de pago. El objetivo es transformar datos operativos dispersos en una estructura analítica centralizada para la toma de decisiones.
 Tecnologías y Conceptos Clave

    Lenguaje: PL/SQL (Oracle).

    Arquitectura: Extracción de datos distribuidos mediante Database Links.

    Orquestación: Automatización avanzada con DBMS_SCHEDULER Chains.

    Calidad de Datos: Implementación de lógica de Idempotencia y validación de integridad referencial programática.

    Auditoría: Sistema de logging personalizado para monitoreo de cargas y trazabilidad de errores.

Arquitectura del Proceso (Pipeline)

El flujo de datos se ejecuta de manera secuencial para garantizar la consistencia, siguiendo esta jerarquía:

    Carga de Apremios: Consolidación de juicios y sus detalles vinculados.

    Vencimientos de Apremios: Sincronización de estados de deuda en etapa de ejecución.

    Planes de Facilidades: Procesamiento de cabeceras, detalles de cuotas y vencimientos.

    Estado de Pagos: Agregación final que vincula la recaudación bancaria con los planes vigentes.

 Puntos Destacados del Código

    Optimización de Performance: Uso de variables de tipo DATE y eliminación de subconsultas redundantes para mejorar el tiempo de respuesta en grandes volúmenes de datos.

    Resiliencia: El orquestador detiene la cadena ante cualquier fallo crítico, evitando la corrupción de reportes mensuales.

    Transformación de Negocio: Integración de funciones de paquetes remotos para el cálculo dinámico de intereses y estados de cuenta en tiempo real durante la carga.




    graph TD
    subgraph "Origen: Sistema Operativo (TCSDISC)"
        A1[(tbl_planes_facilidades)]
        A2[(tbl_vencimientos)]
        A3[(tbl_pagos_rendiciones_banc)]
        A4[(Funciones de Negocio: pa_persona/pa_cuentas)]
    end

    subgraph "Proceso ETL (PL/SQL Orquestado)"
        B1{DBMS_SCHEDULER Chain}
        B2[Transformación y Limpieza]
        B3[Validación de Idempotencia]
    end

    subgraph "Destino: Data Warehouse Analítico"
        C1[(cabecera_planes_facilidades)]
        C2[(detalle_planes_vencimientos)]
        C3[(estado_planes_pagos)]
        C4[(log_actualizaciones)]
    end

    %% Conexiones
    A1 & A2 & A3 -->|DBLink| B1
    A4 -->|Cálculo en Vuelo| B2
    B1 --> B2
    B2 --> B3
    B3 -->|Carga Mensual| C1 & C2 & C3
    B3 -.->|Auditoría| C4