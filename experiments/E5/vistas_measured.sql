-- ============================================================
--  E5 — Vistas de métricas FILTRADAS a data_source = 'measured'
-- ============================================================
--  Contexto: init_simple.sql define las mismas 5 vistas SIN filtro
--  (FROM orders / FROM interactions a secas). Eso sirve para la DEMO,
--  pero para las FIGURAS de resultados de la tesis contamina el promedio
--  con el seed sintético (synthetic) y el baseline manual (e4_manual).
--
--  Este archivo hace CREATE OR REPLACE de las 5 vistas agregando
--  WHERE data_source = 'measured' en cada tabla. NO borra ninguna fila:
--  las 32/107/32 synthetic y las 12 e4_manual quedan intactas, solo se
--  excluyen del reporte de resultados (para eso se creó la columna en B-5).
--
--  Aplicar SOLO sobre la BD viva que se va a capturar:
--    Get-Content experiments/E5/vistas_measured.sql | `
--      docker exec -i tesis_postgres psql -U n8n_user -d ecommerce_tesis
--
--  Revertir (volver a las vistas de la demo, sin filtro):
--    re-ejecutar el bloque "VISTAS" de init_simple.sql (líneas 113-192).
-- ============================================================

-- Flujo 1 — MTTD/MTTR por orden (mide E1)
CREATE OR REPLACE VIEW v_order_processing_time AS
SELECT
    o.id,
    o.order_number,
    o.customer_email,
    o.status,
    o.received_at,
    o.processed_at,
    o.notified_at,
    EXTRACT(EPOCH FROM (o.processed_at - o.received_at))   AS mttd_seconds,
    EXTRACT(EPOCH FROM (o.notified_at - o.processed_at))   AS mttr_seconds,
    EXTRACT(EPOCH FROM (o.notified_at - o.received_at))    AS total_seconds
FROM orders o
WHERE o.processed_at IS NOT NULL
  AND o.data_source = 'measured';

-- Flujo 1 — resumen diario (time series y estados del dashboard)
CREATE OR REPLACE VIEW v_daily_order_summary AS
SELECT
    DATE(received_at)           AS fecha,
    COUNT(*)                    AS total_ordenes,
    COUNT(*) FILTER (WHERE status = 'confirmed')  AS confirmadas,
    COUNT(*) FILTER (WHERE status = 'shipped')    AS enviadas,
    COUNT(*) FILTER (WHERE status = 'delivered')  AS entregadas,
    COUNT(*) FILTER (WHERE status = 'no_stock')   AS sin_stock,
    COUNT(*) FILTER (WHERE status = 'error')      AS errores,
    SUM(total_amount) FILTER (WHERE status IN ('confirmed','shipped','delivered'))
                                AS ingresos_del_dia,
    ROUND(AVG(EXTRACT(EPOCH FROM (processed_at - received_at)))::NUMERIC, 2)
                                AS avg_mttd_seg,
    ROUND(AVG(EXTRACT(EPOCH FROM (notified_at - processed_at)))::NUMERIC, 2)
                                AS avg_mttr_seg
FROM orders
WHERE data_source = 'measured'
GROUP BY DATE(received_at)
ORDER BY fecha DESC;

-- Flujo 2 — TMR por interacción (mide E2/E3)
CREATE OR REPLACE VIEW v_chatbot_response_time AS
SELECT
    i.id,
    i.channel,
    i.user_id,
    i.intent,
    i.received_at,
    i.responded_at,
    EXTRACT(EPOCH FROM (i.responded_at - i.received_at))   AS tmr_seconds,
    i.is_urgent
FROM interactions i
WHERE i.responded_at IS NOT NULL
  AND i.data_source = 'measured';

-- Flujo 2 — resumen diario de chatbot
CREATE OR REPLACE VIEW v_daily_chatbot_summary AS
SELECT
    DATE(received_at)           AS fecha,
    COUNT(*)                    AS total_interacciones,
    COUNT(*) FILTER (WHERE intent = 'FAQ')              AS faq,
    COUNT(*) FILTER (WHERE intent = 'ESTADO_PEDIDO')    AS estado_pedido,
    COUNT(*) FILTER (WHERE intent = 'RECLAMO')          AS reclamos,
    COUNT(*) FILTER (WHERE intent = 'GENERAL')          AS general,
    COUNT(*) FILTER (WHERE channel = 'whatsapp')        AS via_whatsapp,
    COUNT(*) FILTER (WHERE channel = 'telegram')        AS via_telegram,
    COUNT(*) FILTER (WHERE channel = 'email')           AS via_email,
    ROUND(AVG(EXTRACT(EPOCH FROM (responded_at - received_at)))::NUMERIC, 2)
                                AS avg_tmr_seg,
    COUNT(*) FILTER (WHERE is_urgent)                   AS urgentes
FROM interactions
WHERE data_source = 'measured'
GROUP BY DATE(received_at)
ORDER BY fecha DESC;

-- Resumen ejecutivo — todo medido
CREATE OR REPLACE VIEW v_metrics_summary AS
SELECT
    (SELECT COUNT(*) FROM orders WHERE data_source = 'measured')
                                                        AS total_orders,
    (SELECT COUNT(*) FROM orders
      WHERE data_source = 'measured' AND status = 'confirmed')
                                                        AS orders_confirmed,
    (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (processed_at - received_at)))::NUMERIC, 2)
     FROM orders
      WHERE data_source = 'measured' AND processed_at IS NOT NULL)
                                                        AS avg_mttd_seg,
    (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (notified_at - processed_at)))::NUMERIC, 2)
     FROM orders
      WHERE data_source = 'measured' AND notified_at IS NOT NULL)
                                                        AS avg_mttr_seg,
    (SELECT COUNT(*) FROM interactions WHERE data_source = 'measured')
                                                        AS total_interactions,
    (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (responded_at - received_at)))::NUMERIC, 2)
     FROM interactions
      WHERE data_source = 'measured' AND responded_at IS NOT NULL)
                                                        AS avg_tmr_seg,
    (SELECT COUNT(*) FROM tickets WHERE data_source = 'measured')
                                                        AS total_tickets,
    (SELECT COUNT(*) FROM tickets
      WHERE data_source = 'measured' AND status = 'resolved')
                                                        AS tickets_resolved;
