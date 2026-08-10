-- ============================================================
--  E1 — Extracción de métricas de la prueba de carga del Flujo 1
--  Tesis UTN FRM — Plan de Regeneración de Evidencia, §3
--
--  Uso:
--    Get-Content experiments\E1\analizar_e1.sql | `
--      docker exec -i tesis_postgres psql -U n8n_user -d ecommerce_tesis
--
--  Solo LEE. No modifica nada.
--
--  Reporta n, media, mediana, desvío, mín, máx y p95 para MTTD, MTTR y
--  end-to-end. La tesis actual reporta únicamente el promedio; el Bloque 3
--  de la auditoría pide dispersión.
-- ============================================================

\pset border 2
\pset null '(NULL)'

\echo ''
\echo '============================================================'
\echo ' 0. INTEGRIDAD DE LA MUESTRA'
\echo '============================================================'
\echo ''

SELECT
    CASE
        WHEN order_number LIKE 'ORD-E1A-%' THEN 'E1.a (carga secuencial)'
        ELSE 'E1.b (concurrencia)'
    END                                                   AS experimento,
    COUNT(*)                                              AS ordenes,
    COUNT(*) FILTER (WHERE status = 'confirmed')          AS confirmed,
    COUNT(*) FILTER (WHERE status = 'no_stock')           AS no_stock,
    COUNT(*) FILTER (WHERE status NOT IN ('confirmed','no_stock')) AS otros_estados,
    COUNT(processed_at)                                   AS con_processed_at,
    COUNT(notified_at)                                    AS con_notified_at,
    MIN(received_at)                                      AS primera,
    MAX(received_at)                                      AS ultima
FROM orders
WHERE order_number LIKE 'ORD-E1A-%' OR order_number LIKE 'ORD-E1B%'
GROUP BY 1
ORDER BY 1;

\echo ''
\echo '--- Procedencia de los datos (B-5) --------------------------'
\echo '  Todo lo de E1 tiene que decir "measured". Si dice "synthetic",'
\echo '  hay filas seed contaminando la muestra.'
\echo ''

SELECT data_source, COUNT(*) AS n
FROM orders
WHERE order_number LIKE 'ORD-E1A-%' OR order_number LIKE 'ORD-E1B%'
GROUP BY data_source
ORDER BY data_source;

\echo ''
\echo '--- Cobertura de notified_at por rama (hallazgo B-6.1) ------'
\echo '  Si la rama no_stock tiene notified_at NULL, el nodo'
\echo '  "Registrar Notificacion Sin Stock" (D-4) NO esta aplicado y el'
\echo '  MTTR solo se puede reportar sobre la rama con stock. Declaralo.'
\echo ''

SELECT
    status,
    COUNT(*)                                        AS n,
    COUNT(notified_at)                              AS con_notified_at,
    COUNT(*) - COUNT(notified_at)                   AS sin_notified_at,
    ROUND(100.0 * COUNT(notified_at) / NULLIF(COUNT(*), 0), 1) AS pct_cobertura
FROM orders
WHERE order_number LIKE 'ORD-E1A-%'
GROUP BY status
ORDER BY status;

\echo ''
\echo '============================================================'
\echo ' 1. E1.a — DESCRIPTIVOS DE MTTD, MTTR Y END-TO-END'
\echo '============================================================'
\echo '  MTTD = processed_at - received_at   (deteccion)'
\echo '  MTTR = notified_at  - processed_at  (respuesta)'
\echo '  E2E  = notified_at  - received_at   (extremo a extremo)'
\echo '  Valores en SEGUNDOS. n cuenta solo filas no nulas.'
\echo ''

WITH base AS (
    SELECT
        o.order_number,
        o.status,
        EXTRACT(EPOCH FROM (o.processed_at - o.received_at)) AS mttd,
        EXTRACT(EPOCH FROM (o.notified_at  - o.processed_at)) AS mttr,
        EXTRACT(EPOCH FROM (o.notified_at  - o.received_at))  AS e2e
    FROM orders o
    WHERE o.order_number LIKE 'ORD-E1A-%'
),
larga AS (
    SELECT status, 1 AS orden, 'MTTD' AS metrica, mttd AS v FROM base
    UNION ALL
    SELECT status, 2,          'MTTR',            mttr       FROM base
    UNION ALL
    SELECT status, 3,          'E2E',             e2e        FROM base
)
SELECT
    metrica,
    -- GROUPING() distingue el subtotal de un status que fuera NULL.
    -- COALESCE los confundiría; acá el subtotal es explícito.
    CASE WHEN GROUPING(status) = 1 THEN '** TODAS **' ELSE status END      AS rama,
    COUNT(v)                                                               AS n,
    ROUND(AVG(v)::numeric, 3)                                              AS media,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY v))::numeric, 3)    AS mediana,
    ROUND(STDDEV_SAMP(v)::numeric, 3)                                      AS desvio,
    ROUND(MIN(v)::numeric, 3)                                              AS minimo,
    ROUND(MAX(v)::numeric, 3)                                              AS maximo,
    ROUND((PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY v))::numeric, 3)   AS p95
FROM larga
GROUP BY GROUPING SETS ((orden, metrica), (orden, metrica, status))
ORDER BY orden, rama;

\echo ''
\echo '--- IC 95% de la media (t aproximado con z=1,96) ------------'
\echo '  Valido solo si n es razonable. Con n<30 usar t de Student.'
\echo ''

WITH base AS (
    SELECT
        EXTRACT(EPOCH FROM (processed_at - received_at)) AS mttd,
        EXTRACT(EPOCH FROM (notified_at  - processed_at)) AS mttr,
        EXTRACT(EPOCH FROM (notified_at  - received_at))  AS e2e
    FROM orders WHERE order_number LIKE 'ORD-E1A-%'
),
larga AS (
    SELECT 1 AS orden, 'MTTD' AS metrica, mttd AS v FROM base
    UNION ALL SELECT 2, 'MTTR', mttr FROM base
    UNION ALL SELECT 3, 'E2E',  e2e  FROM base
)
SELECT
    metrica,
    COUNT(v)                                          AS n,
    ROUND(AVG(v)::numeric, 3)                         AS media,
    ROUND((AVG(v) - 1.96 * STDDEV_SAMP(v) / SQRT(COUNT(v)))::numeric, 3) AS ic95_inf,
    ROUND((AVG(v) + 1.96 * STDDEV_SAMP(v) / SQRT(COUNT(v)))::numeric, 3) AS ic95_sup
FROM larga
GROUP BY orden, metrica
ORDER BY orden;

\echo ''
\echo '--- Valores extremos (para descartar cold start) ------------'
\echo '  El primer request tras levantar n8n suele ser un outlier.'
\echo '  Si aparece, se reporta y se justifica; no se borra en silencio.'
\echo ''

SELECT
    order_number,
    status,
    received_at,
    ROUND(EXTRACT(EPOCH FROM (processed_at - received_at))::numeric, 3) AS mttd_seg,
    ROUND(EXTRACT(EPOCH FROM (notified_at  - received_at))::numeric, 3) AS e2e_seg
FROM orders
WHERE order_number LIKE 'ORD-E1A-%' AND processed_at IS NOT NULL
ORDER BY (processed_at - received_at) DESC
LIMIT 5;

\echo ''
\echo '============================================================'
\echo ' 2. E1.b — ATOMICIDAD BAJO CONCURRENCIA'
\echo '============================================================'
\echo '  Con stock=5 y 20 requests: se esperan 5 confirmed y 15 no_stock.'
\echo '  "confirmadas > stock_inicial" = SOBREVENTA = condicion de carrera.'
\echo ''

SELECT
    SUBSTRING(order_number FROM '(ORD-E1B[0-9]*-R[0-9]+)-')  AS ronda,
    COUNT(*)                                           AS ordenes,
    COUNT(*) FILTER (WHERE status = 'confirmed')       AS confirmed,
    COUNT(*) FILTER (WHERE status = 'no_stock')        AS no_stock,
    COUNT(*) FILTER (WHERE status NOT IN ('confirmed','no_stock')) AS otros,
    ROUND(EXTRACT(EPOCH FROM (MAX(received_at) - MIN(received_at)))::numeric, 3) AS ventana_llegada_seg,
    ROUND(AVG(EXTRACT(EPOCH FROM (processed_at - received_at)))::numeric, 3)     AS mttd_medio_seg,
    ROUND(MAX(EXTRACT(EPOCH FROM (processed_at - received_at)))::numeric, 3)     AS mttd_max_seg
FROM orders
WHERE order_number LIKE 'ORD-E1B%'
GROUP BY 1
ORDER BY 1;

\echo ''
\echo '--- Estado del stock (el CHECK stock >= 0 como red) ---------'
\echo ''

SELECT sku, name, stock, stock_min
FROM products
WHERE stock <= 0 OR stock < stock_min
ORDER BY stock, sku;

\echo ''
\echo '============================================================'
\echo ' 3. CONTROL FINAL'
\echo '============================================================'
\echo ''

SELECT
    'ordenes E1 totales'                                       AS control,
    (SELECT COUNT(*)::text FROM orders
      WHERE order_number LIKE 'ORD-E1A-%' OR order_number LIKE 'ORD-E1B%') AS valor
UNION ALL
SELECT 'ordenes sin processed_at (pipeline cortado)',
    (SELECT COUNT(*)::text FROM orders
      WHERE (order_number LIKE 'ORD-E1A-%' OR order_number LIKE 'ORD-E1B%')
        AND processed_at IS NULL)
UNION ALL
SELECT 'ordenes en estado error',
    (SELECT COUNT(*)::text FROM orders
      WHERE (order_number LIKE 'ORD-E1A-%' OR order_number LIKE 'ORD-E1B%')
        AND status = 'error')
UNION ALL
SELECT 'productos con stock negativo (deberia ser 0)',
    (SELECT COUNT(*)::text FROM products WHERE stock < 0);

\echo ''
\echo 'Listo. Guarda esta salida como evidencia en:'
\echo '  experiments/E1/resultados/e1_metricas_<fecha>.txt'
\echo ''
