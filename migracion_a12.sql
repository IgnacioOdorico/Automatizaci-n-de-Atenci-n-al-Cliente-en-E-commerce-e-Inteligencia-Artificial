-- ============================================================
--  A-12 — Mejoras de schema (auditoría, Bloque 4)
-- ============================================================
--  Qué hace:
--    1. Índices de rendimiento que OE3 prometía y no existían
--       (solo había PKs y UNIQUEs). Cada índice responde a una
--       query real de los flujos o de las vistas v_*.
--    2. Tabla order_items: una orden hoy solo admite UN producto
--       (orders.product_id + quantity). Esta tabla normaliza la
--       relación orden→ítems (N productos por orden) y hace
--       backfill de las órdenes existentes (1 ítem por orden).
--       orders.product_id se CONSERVA por compatibilidad con los
--       workflows actuales; el diseño objetivo es order_items.
--
--  NO destructivo: no borra ni modifica ninguna fila existente.
--  Idempotente: usa IF NOT EXISTS / chequeos previos.
--
--  Aplicar:
--    Get-Content migracion_a12.sql | docker exec -i tesis_postgres psql -U n8n_user -d ecommerce_tesis
--
--  Nota TIMESTAMPTZ: el diseño canónico (init_simple.sql) migra los
--  timestamps a TIMESTAMPTZ. En esta instancia de demo se conservan
--  como TIMESTAMP porque las 6 vistas v_* dependen de esas columnas
--  y las métricas son DIFERENCIAS de tiempo (idénticas con o sin tz).
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. ÍNDICES (cada uno con la query que lo justifica)
-- ------------------------------------------------------------

-- Flujo 1 / Grafana: filtros por estado (pie de estados, conteos)
CREATE INDEX IF NOT EXISTS idx_orders_status
    ON orders (status);

-- Vistas de métricas: WHERE data_source='measured' + orden temporal
CREATE INDEX IF NOT EXISTS idx_orders_source_received
    ON orders (data_source, received_at);

-- Chatbot: breakdown por intent (TMR por intent, pie de intents)
CREATE INDEX IF NOT EXISTS idx_interactions_intent
    ON interactions (intent);

-- Chatbot: breakdown por canal (WhatsApp/Telegram) + ventana temporal
CREATE INDEX IF NOT EXISTS idx_interactions_channel_received
    ON interactions (channel, received_at);

-- Vistas de métricas: WHERE data_source='measured'
CREATE INDEX IF NOT EXISTS idx_interactions_source
    ON interactions (data_source);

-- FK sin índice: joins ticket→orden e interacción→orden
CREATE INDEX IF NOT EXISTS idx_interactions_order_id
    ON interactions (order_id);
CREATE INDEX IF NOT EXISTS idx_tickets_order_id
    ON tickets (order_id);

-- Tickets: tablero por estado (abiertos/resueltos)
CREATE INDEX IF NOT EXISTS idx_tickets_status
    ON tickets (status);

-- ------------------------------------------------------------
-- 2. TABLA order_items (normaliza orden→productos)
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS order_items (
    id          SERIAL PRIMARY KEY,
    order_id    INTEGER NOT NULL REFERENCES orders(id)   ON DELETE CASCADE,
    product_id  INTEGER NOT NULL REFERENCES products(id),
    quantity    INTEGER NOT NULL CHECK (quantity > 0),
    unit_price  NUMERIC(10,2) NOT NULL CHECK (unit_price >= 0),
    subtotal    NUMERIC(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id
    ON order_items (product_id);

-- Backfill: 1 ítem por orden existente (unit_price = total/cantidad,
-- que preserva el precio efectivo al momento de la compra).
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT o.id, o.product_id, o.quantity,
       ROUND(o.total_amount / o.quantity, 2)
FROM orders o
WHERE o.product_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.id);

COMMIT;

-- ------------------------------------------------------------
-- 3. VERIFICACIÓN
-- ------------------------------------------------------------
SELECT 'indices nuevos' AS control, count(*) AS valor
FROM pg_indexes
WHERE schemaname='public' AND indexname LIKE 'idx_%'
UNION ALL
SELECT 'ordenes con product_id', count(*) FROM orders WHERE product_id IS NOT NULL
UNION ALL
SELECT 'filas en order_items', count(*) FROM order_items
UNION ALL
SELECT 'items cuyo subtotal difiere del total de la orden (esperado: solo redondeos)',
       count(*)
FROM order_items oi JOIN orders o ON o.id = oi.order_id
WHERE abs(oi.subtotal - o.total_amount) > 0.05;
