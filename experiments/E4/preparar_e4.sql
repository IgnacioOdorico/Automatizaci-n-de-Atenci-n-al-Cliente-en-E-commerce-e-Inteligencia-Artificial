-- ============================================================
--  E4 — Baseline de atención manual
--  Prepara las 12 órdenes que el operador procesa a mano.
--
--  Uso:
--    Get-Content experiments\E4\preparar_e4.sql | docker exec -i tesis_postgres psql -U n8n_user -d ecommerce_tesis
--
--  Ver experiments/E4/README.md y docs/PLAN_REGENERACION_EVIDENCIA.md §6
-- ============================================================

\set ON_ERROR_STOP on

-- ------------------------------------------------------------
--  GUARDAS — antes de tocar nada
-- ------------------------------------------------------------
DO $$
BEGIN
    -- No pisar una medición ya hecha.
    IF EXISTS (SELECT 1 FROM orders WHERE order_number LIKE 'ORD-E4-%') THEN
        RAISE EXCEPTION
            'E4 ya fue preparado: existen ordenes ORD-E4-*. Aborto para no pisar una medicion previa. Para rehacer, ver el DELETE comentado al final de este archivo.';
    END IF;

    -- La columna de procedencia (B-5) es obligatoria: sin ella, estas 12 ordenes
    -- contaminan el MTTD/MTTR de E1 y no hay forma de separarlas despues.
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'orders' AND column_name = 'data_source'
    ) THEN
        RAISE EXCEPTION
            'Falta la columna orders.data_source (B-5). Aplicala antes de correr E4.';
    END IF;
END $$;

-- ------------------------------------------------------------
--  LAS 12 ÓRDENES
--
--  - Emails @example.com (RFC 2606), por B-7.
--  - Telefonos sinteticos, invalidos como celulares reales.
--  - total_amount se calcula desde products: no se hardcodea.
--  - data_source = 'e4_manual' — NO es 'measured'. Ver README, "Trampa critica".
--  - Las #1 y #2 son de familiarizacion (efecto de aprendizaje declarado).
--  - Las #5, #9 y #12 piden 999 unidades: van a la rama SIN STOCK.
-- ------------------------------------------------------------
INSERT INTO orders (
    order_number, customer_name, customer_email, customer_phone,
    product_id, quantity, total_amount, status, received_at, data_source
)
SELECT
    v.orden,
    v.nombre,
    v.email,
    v.tel,
    p.id,
    v.cant,
    ROUND(p.price * v.cant, 2),
    'pending',
    NOW(),
    'e4_manual'
FROM (VALUES
    ('ORD-E4-001', 'Lucia Bertolotti',  'lucia.bertolotti@example.com',  '5492614000001', 'PROD-002',   1),
    ('ORD-E4-002', 'Martin Quiroga',    'martin.quiroga@example.com',    '5492614000002', 'PROD-007',   2),
    ('ORD-E4-003', 'Sofia Nardelli',    'sofia.nardelli@example.com',    '5492614000003', 'PROD-003',   1),
    ('ORD-E4-004', 'Emiliano Paz',      'emiliano.paz@example.com',      '5492614000004', 'PROD-008',   3),
    ('ORD-E4-005', 'Carla Miranda',     'carla.miranda@example.com',     '5492614000005', 'PROD-005', 999),
    ('ORD-E4-006', 'Nicolas Vergara',   'nicolas.vergara@example.com',   '5492614000006', 'PROD-006',   1),
    ('ORD-E4-007', 'Julieta Ferrero',   'julieta.ferrero@example.com',   '5492614000007', 'PROD-002',   2),
    ('ORD-E4-008', 'Ramiro Olguin',     'ramiro.olguin@example.com',     '5492614000008', 'PROD-001',   1),
    ('ORD-E4-009', 'Agustina Rossi',    'agustina.rossi@example.com',    '5492614000009', 'PROD-004', 999),
    ('ORD-E4-010', 'Federico Lazcano',  'federico.lazcano@example.com',  '5492614000010', 'PROD-007',   1),
    ('ORD-E4-011', 'Valentina Duarte',  'valentina.duarte@example.com',  '5492614000011', 'PROD-003',   2),
    ('ORD-E4-012', 'Tomas Alcaraz',     'tomas.alcaraz@example.com',     '5492614000012', 'PROD-001', 999)
) AS v(orden, nombre, email, tel, sku, cant)
JOIN products p ON p.sku = v.sku;

-- ------------------------------------------------------------
--  CONTROL DE INTEGRIDAD
-- ------------------------------------------------------------
DO $$
DECLARE
    n INTEGER;
BEGIN
    SELECT COUNT(*) INTO n FROM orders WHERE order_number LIKE 'ORD-E4-%';
    IF n <> 12 THEN
        RAISE EXCEPTION
            'Se esperaban 12 ordenes E4 y hay %. Revisa que existan los SKU PROD-001..PROD-008.', n;
    END IF;
    RAISE NOTICE 'OK: 12 ordenes E4 creadas, todas en pending, data_source = e4_manual.';
END $$;

-- ------------------------------------------------------------
--  VERIFICACION — que las 12 quedaron creadas y en pending.
--
--  OJO: esta salida NO muestra el stock ni la rama que le toca a
--  cada orden, A PROPOSITO. Averiguar si hay stock es justamente
--  el trabajo que mide la fase T1: si el operador ya lo sabe
--  antes de arrancar el cronometro, T1 queda subestimada y la
--  medicion no vale. El operador lo descubre consultando, no
--  leyendo esta tabla.
-- ------------------------------------------------------------
\echo
\echo ==========================================================
\echo  E4 - 12 ordenes creadas. Se procesan en orden de numero.
\echo  Las dos primeras son de familiarizacion (se reportan aparte).
\echo  Las consultas de cada fase te las muestra cronometro.html
\echo ==========================================================
\echo

SELECT
    o.order_number                              AS "orden",
    o.customer_name                             AS "cliente",
    p.sku                                       AS "sku",
    o.quantity                                  AS "pide",
    o.status                                    AS "estado",
    o.data_source                               AS "procedencia"
FROM orders o
JOIN products p ON p.id = o.product_id
WHERE o.order_number LIKE 'ORD-E4-%'
ORDER BY o.order_number;

\echo
\echo Listo. Ahora abri experiments/E4/cronometro.html y segui las fases.
\echo Deja esta consola abierta: es donde vas a correr las sentencias.
\echo

-- ============================================================
--  REHACER LA MEDICION — descomentar y correr a mano.
--  Ojo: borra las 12 ordenes y NO devuelve el stock descontado.
--
--  DELETE FROM orders WHERE order_number LIKE 'ORD-E4-%';
-- ============================================================
