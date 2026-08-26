-- ============================================================
--  A-07 — Alerta de stock bajo
-- ============================================================
--  La prueba funcional F3 declaraba aprobada la generacion de una
--  alerta de stock bajo que no existia en el workflow. El diagrama
--  de elaboracion propia (Figura 1) si la contempla: tras descontar
--  el stock, si queda por debajo de stock_min se emite el evento
--  low_stock_alert.
--
--  Esta tabla es el destino de ese evento: registra cada vez que un
--  producto cruza su umbral de reposicion, con la orden que lo
--  provoco y los valores en ese instante.
--
--  Aplicar:
--    Get-Content migracion_a07.sql | docker exec -i tesis_postgres psql -U n8n_user -d ecommerce_tesis
-- ============================================================

CREATE TABLE IF NOT EXISTS stock_alerts (
    id            SERIAL PRIMARY KEY,
    product_id    INTEGER     NOT NULL REFERENCES products(id),
    order_id      INTEGER     REFERENCES orders(id) ON DELETE SET NULL,
    sku           VARCHAR(50) NOT NULL,
    stock_actual  INTEGER     NOT NULL CHECK (stock_actual >= 0),
    stock_min     INTEGER     NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    data_source   VARCHAR(20) NOT NULL DEFAULT 'measured'
                  CHECK (data_source IN ('measured', 'synthetic'))
);

CREATE INDEX IF NOT EXISTS idx_stock_alerts_product ON stock_alerts (product_id);
CREATE INDEX IF NOT EXISTS idx_stock_alerts_created ON stock_alerts (created_at);

-- Verificacion
SELECT 'stock_alerts creada' AS control,
       (SELECT count(*) FROM information_schema.columns
         WHERE table_name = 'stock_alerts') AS columnas;
