-- ============================================================
--  SEED DE CATALOGO — productos y FAQs unicamente
--
--  Extraido de seed_expand.sql el 2026-08-09 (B-3 del plan
--  docs/PLAN_REGENERACION_EVIDENCIA.md).
--
--  Este archivo es SEGURO de ejecutar: no contiene TRUNCATE ni
--  toca orders / interactions / tickets. Solo repuebla el
--  catalogo de productos y el banco de FAQs, ambos con
--  ON CONFLICT DO NOTHING (idempotente).
--
--  El catalogo NO es dato experimental: es configuracion del
--  sistema. Por eso puede recrearse sin comprometer la
--  integridad de las mediciones.
--
--  Uso:
--    Get-Content seed_catalogo.sql | docker exec -i tesis_postgres `
--        psql -U n8n_user -d ecommerce_tesis
-- ============================================================

-- ============================================================
-- LIMPIAR FAQs DUPLICADAS (mantener solo ids 1-6)
-- ============================================================
DELETE FROM faq_responses WHERE id > 6;

-- ============================================================
-- EXPANDIR FAQs — de 6 a 22 entradas reales y útiles
-- ============================================================
INSERT INTO faq_responses (question, answer, category) VALUES

-- PAGOS
('¿Puedo pagar en cuotas?',
 'Sí, con tarjetas de crédito Visa, Mastercard y American Express podés pagar en hasta 12 cuotas sin interés en productos seleccionados. Las cuotas disponibles se muestran en el checkout.',
 'Pagos'),

('¿Es seguro pagar con tarjeta en la web?',
 'Totalmente. Usamos encriptación SSL y procesamos los pagos a través de MercadoPago, que cumple con los estándares PCI-DSS. Nunca almacenamos los datos de tu tarjeta.',
 'Pagos'),

-- ENVÍOS
('¿Hacen envíos a todo el país?',
 'Sí, enviamos a todo el territorio argentino. Trabajamos con OCA, Andreani y correo argentino. El costo de envío se calcula en el checkout según tu código postal.',
 'Envíos'),

('¿Puedo hacer el seguimiento de mi envío?',
 'Sí. Una vez despachado tu pedido, te enviamos un email con el número de tracking y el enlace directo para seguir el paquete en tiempo real.',
 'Envíos'),

('¿Hacen envíos internacionales?',
 'Por el momento solo enviamos dentro de Argentina. Estamos trabajando para expandir a países limítrofes próximamente.',
 'Envíos'),

('¿Qué pasa si no estoy en casa cuando llega el pedido?',
 'El transportista deja un aviso y hace un segundo intento al día siguiente. Si tampoco podés recibirlo, el paquete queda disponible para retiro en la sucursal más cercana por 5 días hábiles.',
 'Envíos'),

-- DEVOLUCIONES
('¿Cuál es la política de cambios?',
 'Podés cambiar un producto dentro de los 30 días de recibido, siempre que esté en su embalaje original y sin uso. Los gastos de envío del cambio corren por nuestra cuenta si el error fue nuestro.',
 'Devoluciones'),

('¿Cómo inicio una devolución?',
 'Escribinos por este chat o al email devoluciones@techstore.com.ar con tu número de pedido y el motivo. Te enviamos una etiqueta prepaga para el retiro en 24hs hábiles.',
 'Devoluciones'),

-- GARANTÍA
('¿Qué cubre la garantía?',
 'La garantía cubre defectos de fabricación. NO cubre daños por mal uso, caídas, líquidos o modificaciones no autorizadas. Ante cualquier falla, contactanos y gestionamos el service con el fabricante.',
 'Garantía'),

('¿Cómo hago válida la garantía?',
 'Guardá el comprobante de compra (te lo enviamos por email). Si el producto falla, escribinos con foto o video del problema y tu número de pedido. Nos encargamos de todo el proceso de garantía.',
 'Garantía'),

-- PRODUCTOS
('¿Los productos son originales?',
 'Sí, todos nuestros productos son 100% originales con garantía oficial del fabricante. Somos distribuidores autorizados de todas las marcas que comercializamos.',
 'Productos'),

('¿Tienen stock en físico para retirar?',
 'Por el momento somos una tienda 100% online y no contamos con local a la calle. Todos los pedidos se despachan desde nuestro depósito en Mendoza.',
 'Productos'),

('¿Cómo sé si un producto tiene stock?',
 'Si podés agregarlo al carrito, hay stock disponible. Si aparece como "Sin stock", podés anotarte en la lista de espera y te avisamos cuando vuelva a estar disponible.',
 'Productos'),

-- FACTURACIÓN
('¿Hacen factura A para empresas?',
 'Sí, emitimos factura A para responsables inscriptos. Durante el checkout elegís el tipo de comprobante e ingresás el CUIT y razón social de tu empresa.',
 'Facturación'),

('¿Cuándo recibo la factura?',
 'La factura electrónica se genera automáticamente al confirmar el pago y te llega por email en minutos. Si no la recibís, revisá la carpeta de spam o escribinos.',
 'Facturación'),

-- PEDIDOS
('¿Puedo cancelar un pedido?',
 'Podés cancelar sin costo dentro de las 2 horas de realizado, siempre que no haya sido despachado. Después del despacho, el proceso es una devolución normal.',
 'Pedidos'),

('¿Cómo recibo el comprobante de compra?',
 'Te enviamos un email de confirmación inmediatamente después del pago con todos los detalles del pedido y la factura adjunta.',
 'Pedidos')

ON CONFLICT DO NOTHING;

-- ============================================================
-- AGREGAR 12 PRODUCTOS NUEVOS con más variedad
-- ============================================================
INSERT INTO products (sku, name, price, stock, stock_min, category) VALUES
    ('PROD-009', 'Tablet Samsung Galaxy Tab A9',         229.99, 12, 2, 'Tablets'),
    ('PROD-010', 'Impresora HP LaserJet Pro M15w',       189.99,  6, 2, 'Impresoras'),
    ('PROD-011', 'Router TP-Link AX3000 WiFi 6',         89.99, 18, 3, 'Redes'),
    ('PROD-012', 'Memoria RAM Kingston 16GB DDR4',        54.99, 22, 4, 'Componentes'),
    ('PROD-013', 'Notebook HP Victus 15 Gaming',         799.99,  5, 2, 'Notebooks'),
    ('PROD-014', 'Monitor LG 27" 4K UltraFine',         449.99,  3, 1, 'Monitores'),
    ('PROD-015', 'Silla Gamer DXRacer Formula',          349.99,  7, 2, 'Mobiliario'),
    ('PROD-016', 'Micrófono Blue Yeti USB',              129.99, 10, 2, 'Audio'),
    ('PROD-017', 'Disco Rígido Seagate 2TB HDD',          64.99, 20, 4, 'Almacenamiento'),
    ('PROD-018', 'Pendrive Kingston 64GB USB 3.2',         9.99, 80, 10, 'Almacenamiento'),
    ('PROD-019', 'Pad Mouse XL Antideslizante',            14.99, 60, 8, 'Accesorios'),
    ('PROD-020', 'Hub USB-C 7 en 1 Anker',                39.99, 25, 5, 'Accesorios')
ON CONFLICT (sku) DO NOTHING;

