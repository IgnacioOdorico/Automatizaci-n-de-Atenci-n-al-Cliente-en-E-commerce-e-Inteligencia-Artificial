-- ============================================================
--  QUERIES para la DEMO (pgAdmin) — Tesis Post-Venta n8n
--  Conectado al Postgres de Docker: localhost:5433 / ecommerce_tesis
--  Tip: seleccioná el bloque que querés y apretá F5 (o el ▶) para ejecutar.
--       Todas ordenan por fecha DESC -> lo último que disparaste queda ARRIBA.
-- ============================================================


-- ============================================================
--  FLUJO 1 — ÓRDENES
-- ============================================================

-- 1) Últimas órdenes (con estado y tiempos) — RECARGÁ tras disparar una orden
SELECT
    order_number,
    status,
    quantity,
    received_at,
    processed_at,
    notified_at,
    ROUND(EXTRACT(EPOCH FROM (processed_at - received_at))::numeric, 2) AS mttd_seg,
    ROUND(EXTRACT(EPOCH FROM (notified_at  - processed_at))::numeric, 2) AS mttr_seg,
    ROUND(EXTRACT(EPOCH FROM (notified_at  - received_at))::numeric, 2)  AS total_seg
FROM orders
ORDER BY received_at DESC
LIMIT 10;

-- 2) Buscar UNA orden puntual (la de la demo de ESTADO_PEDIDO)
SELECT order_number, status, quantity, received_at, processed_at, notified_at
FROM orders
WHERE order_number = 'ORD-DEMO-01';

-- 3) Stock de productos (para mostrar el descuento tras una orden con stock)
SELECT sku, name, stock, stock_min, price
FROM products
ORDER BY sku
LIMIT 10;


-- ============================================================
--  FLUJO 2 — CHATBOT
-- ============================================================

-- 4) Últimas interacciones (intent + mensaje + TMR) — RECARGÁ tras cada mensaje
SELECT
    id,
    channel,
    intent,
    message,
    LEFT(ai_response, 90) AS respuesta,
    received_at,
    responded_at,
    ROUND(EXTRACT(EPOCH FROM (responded_at - received_at))::numeric, 2) AS tmr_seg
FROM interactions
ORDER BY received_at DESC
LIMIT 10;

-- 5) Tickets creados por los RECLAMOS
SELECT id, interaction_id, subject, status, priority, created_at
FROM tickets
ORDER BY created_at DESC
LIMIT 10;


-- ============================================================
--  MÉTRICAS (las vistas que también lee Grafana)
-- ============================================================

-- 6) Resumen ejecutivo (MTTD, MTTR, TMR, totales) — el número "titular"
SELECT * FROM v_metrics_summary;

-- 7) TMR promedio por intent
SELECT
    intent,
    COUNT(*) AS mensajes,
    ROUND(AVG(EXTRACT(EPOCH FROM (responded_at - received_at)))::numeric, 2) AS tmr_prom_seg
FROM interactions
GROUP BY intent
ORDER BY intent;

-- 8) Detalle de tiempos de órdenes (vista MTTD/MTTR)
SELECT * FROM v_order_processing_time
ORDER BY received_at DESC
LIMIT 10;

-- 9) Detalle de tiempos del chatbot (vista TMR)
SELECT * FROM v_chatbot_response_time
ORDER BY received_at DESC
LIMIT 10;


-- ============================================================
--  LIMPIEZA / RESET (para poder re-disparar órdenes en el ensayo)
--  El order_number es UNICO -> si re-mandás el mismo, Postman da error.
--  Borralo antes, o mejor: cambiá el número en Postman cada vez.
-- ============================================================

-- 10) Borrar UNA orden puntual
DELETE FROM orders WHERE order_number = 'ORD-DEMO-01';

-- 11) Borrar TODAS las órdenes de demo (reset entre ensayos)
--     Versión segura: primero suelta las referencias, después borra.
UPDATE interactions SET order_id = NULL
  WHERE order_id IN (SELECT id FROM orders WHERE order_number LIKE 'ORD-DEMO-%');
DELETE FROM orders WHERE order_number LIKE 'ORD-DEMO-%';

-- 12) (Opcional) Borrar interacciones de prueba (las que vos disparaste, id > 107)
DELETE FROM interactions WHERE id > 107;
