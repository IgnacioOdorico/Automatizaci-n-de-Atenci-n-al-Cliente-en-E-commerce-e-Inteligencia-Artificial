-- ############################################################
-- ##                                                        ##
-- ##   ARCHIVO CONGELADO — NO EJECUTAR                      ##
-- ##                                                        ##
-- ############################################################
--
-- Congelado el 2026-08-09 por B-3 del plan de regeneracion de
-- evidencia (docs/PLAN_REGENERACION_EVIDENCIA.md).
--
-- POR QUE NO SE EJECUTA MAS:
--
--   1) La linea del TRUNCATE de mas abajo borra tickets,
--      interactions y orders con RESTART IDENTITY CASCADE.
--      Correr este archivo DESTRUYE toda la evidencia medida.
--
--   2) Las filas de orders (ORD-HIST-*, ORD-LOAD-*), de
--      interactions y de tickets que inserta este script son
--      DATOS SINTETICOS. Fueron reportadas como resultados
--      experimentales en el Cap. 5 de la tesis v5, y esa es la
--      causa raiz del Bloque 1 de la auditoria academica.
--      En la BD quedan marcadas con data_source = 'synthetic'.
--
-- QUE USAR EN SU LUGAR:
--
--   - Para reinicializar el catalogo (productos y FAQs), usar
--     seed_catalogo.sql — mismo contenido, sin TRUNCATE y sin
--     datos transaccionales.
--
--   - Para generar datos de orders/interactions/tickets, correr
--     los experimentos de experiments/ (E1 y E2 del plan). Los
--     datos los escriben los workflows de n8n, no un INSERT.
--
-- Se conserva unicamente como registro historico de que produjo
-- los numeros del Cap. 5 de la v5.
-- ############################################################

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

-- ============================================================
-- RESET de datos transaccionales (reproducibilidad de metricas)
-- NO toca products ni faq_responses.
-- ============================================================
TRUNCATE tickets, interactions, orders RESTART IDENTITY CASCADE;

-- ============================================================
-- ORDENES (32) - 12 historico + 20 prueba de carga
-- Deltas: MTTD promedio=1.79s, MTTR promedio=7.69s, end-to-end=9.48s
-- ============================================================
INSERT INTO orders (order_number, customer_name, customer_email, customer_phone, product_id, quantity, total_amount, status, received_at, processed_at, notified_at) VALUES
    ('ORD-HIST-001','Martina Lopez','martina.lopez@mail.com','5492616978022',12,3,362.36,'delivered',NOW() - INTERVAL '12 days',NOW() - INTERVAL '12 days' + INTERVAL '1.75 seconds',NOW() - INTERVAL '12 days' + INTERVAL '10.47 seconds'),
    ('ORD-HIST-002','Facundo Rios','facundo.rios@mail.com','5492615721627',2,4,793.01,'delivered',NOW() - INTERVAL '11 days',NOW() - INTERVAL '11 days' + INTERVAL '1.56 seconds',NOW() - INTERVAL '11 days' + INTERVAL '7.14 seconds'),
    ('ORD-HIST-003','Camila Suarez','camila.suarez@mail.com','5492613052109',11,3,659.87,'delivered',NOW() - INTERVAL '10 days',NOW() - INTERVAL '10 days' + INTERVAL '2.73 seconds',NOW() - INTERVAL '10 days' + INTERVAL '12.48 seconds'),
    ('ORD-HIST-004','Ignacio Blanco','ignacio.blanco@mail.com','5492611340075',10,4,300.62,'delivered',NOW() - INTERVAL '9 days',NOW() - INTERVAL '9 days' + INTERVAL '0.86 seconds',NOW() - INTERVAL '9 days' + INTERVAL '7.97 seconds'),
    ('ORD-HIST-005','Valentina Cruz','valentina.cruz@mail.com','5492611941959',18,3,193.75,'delivered',NOW() - INTERVAL '8 days',NOW() - INTERVAL '8 days' + INTERVAL '0.9 seconds',NOW() - INTERVAL '8 days' + INTERVAL '6.99 seconds'),
    ('ORD-HIST-006','Lucas Fernandez','lucas.fernandez@mail.com','5492612984458',4,2,564.69,'delivered',NOW() - INTERVAL '7 days',NOW() - INTERVAL '7 days' + INTERVAL '1.68 seconds',NOW() - INTERVAL '7 days' + INTERVAL '7.32 seconds'),
    ('ORD-HIST-007','Agustina Moreno','agustina.moreno@mail.com','5492616070765',2,2,479.87,'delivered',NOW() - INTERVAL '6 days',NOW() - INTERVAL '6 days' + INTERVAL '1.58 seconds',NOW() - INTERVAL '6 days' + INTERVAL '9.3 seconds'),
    ('ORD-HIST-008','Tomas Gutierrez','tomas.gutierrez@mail.com','5492616972209',1,4,528.75,'shipped',NOW() - INTERVAL '5 days',NOW() - INTERVAL '5 days' + INTERVAL '2.06 seconds',NOW() - INTERVAL '5 days' + INTERVAL '9.68 seconds'),
    ('ORD-HIST-009','Micaela Vargas','micaela.vargas@mail.com','5492618062963',14,4,351.92,'shipped',NOW() - INTERVAL '4 days',NOW() - INTERVAL '4 days' + INTERVAL '1.23 seconds',NOW() - INTERVAL '4 days' + INTERVAL '10.62 seconds'),
    ('ORD-HIST-010','Bruno Herrera','bruno.herrera@mail.com','5492611476760',8,2,181.45,'shipped',NOW() - INTERVAL '3 days',NOW() - INTERVAL '3 days' + INTERVAL '1.47 seconds',NOW() - INTERVAL '3 days' + INTERVAL '6.63 seconds'),
    ('ORD-HIST-011','Sofia Castro','sofia.castro@mail.com','5492613477715',18,4,802.45,'shipped',NOW() - INTERVAL '2 days',NOW() - INTERVAL '2 days' + INTERVAL '2.57 seconds',NOW() - INTERVAL '2 days' + INTERVAL '8.13 seconds'),
    ('ORD-HIST-012','Mateo Diaz','mateo.diaz@mail.com','5492619033657',8,1,34.6,'shipped',NOW() - INTERVAL '1 days',NOW() - INTERVAL '1 days' + INTERVAL '1.52 seconds',NOW() - INTERVAL '1 days' + INTERVAL '9.68 seconds'),
    ('ORD-LOAD-001','Julieta Romero','julieta.romero@mail.com','5492613326285',14,3,863.46,'confirmed',NOW() - INTERVAL '40 minutes',NOW() - INTERVAL '40 minutes' + INTERVAL '1.21 seconds',NOW() - INTERVAL '40 minutes' + INTERVAL '9.36 seconds'),
    ('ORD-LOAD-002','Benjamin Silva','benjamin.silva@mail.com','5492611637682',19,1,758.81,'no_stock',NOW() - INTERVAL '38 minutes',NOW() - INTERVAL '38 minutes' + INTERVAL '0.95 seconds',NOW() - INTERVAL '38 minutes' + INTERVAL '11.03 seconds'),
    ('ORD-LOAD-003','Catalina Ruiz','catalina.ruiz@mail.com','5492619731684',17,3,319.83,'confirmed',NOW() - INTERVAL '36 minutes',NOW() - INTERVAL '36 minutes' + INTERVAL '1.54 seconds',NOW() - INTERVAL '36 minutes' + INTERVAL '7.83 seconds'),
    ('ORD-LOAD-004','Thiago Molina','thiago.molina@mail.com','5492611191416',11,1,598.92,'no_stock',NOW() - INTERVAL '34 minutes',NOW() - INTERVAL '34 minutes' + INTERVAL '2.65 seconds',NOW() - INTERVAL '34 minutes' + INTERVAL '8.45 seconds'),
    ('ORD-LOAD-005','Emma Torres','emma.torres@mail.com','5492614721835',8,4,71.3,'confirmed',NOW() - INTERVAL '32 minutes',NOW() - INTERVAL '32 minutes' + INTERVAL '2.89 seconds',NOW() - INTERVAL '32 minutes' + INTERVAL '12.4 seconds'),
    ('ORD-LOAD-006','Joaquin Sosa','joaquin.sosa@mail.com','5492617695356',17,2,835.96,'confirmed',NOW() - INTERVAL '30 minutes',NOW() - INTERVAL '30 minutes' + INTERVAL '2.0 seconds',NOW() - INTERVAL '30 minutes' + INTERVAL '10.27 seconds'),
    ('ORD-LOAD-007','Renata Aguirre','renata.aguirre@mail.com','5492615626517',12,2,514.2,'confirmed',NOW() - INTERVAL '28 minutes',NOW() - INTERVAL '28 minutes' + INTERVAL '2.49 seconds',NOW() - INTERVAL '28 minutes' + INTERVAL '9.13 seconds'),
    ('ORD-LOAD-008','Bautista Ortiz','bautista.ortiz@mail.com','5492618705233',11,2,349.76,'confirmed',NOW() - INTERVAL '26 minutes',NOW() - INTERVAL '26 minutes' + INTERVAL '1.08 seconds',NOW() - INTERVAL '26 minutes' + INTERVAL '7.38 seconds'),
    ('ORD-LOAD-009','Isabella Medina','isabella.medina@mail.com','5492616237740',15,4,809.38,'confirmed',NOW() - INTERVAL '24 minutes',NOW() - INTERVAL '24 minutes' + INTERVAL '2.29 seconds',NOW() - INTERVAL '24 minutes' + INTERVAL '9.27 seconds'),
    ('ORD-LOAD-010','Santino Rojas','santino.rojas@mail.com','5492613579994',7,2,572.65,'confirmed',NOW() - INTERVAL '22 minutes',NOW() - INTERVAL '22 minutes' + INTERVAL '1.12 seconds',NOW() - INTERVAL '22 minutes' + INTERVAL '11.12 seconds'),
    ('ORD-LOAD-011','Delfina Nunez','delfina.nunez@mail.com','5492619778303',16,1,856.39,'no_stock',NOW() - INTERVAL '20 minutes',NOW() - INTERVAL '20 minutes' + INTERVAL '1.07 seconds',NOW() - INTERVAL '20 minutes' + INTERVAL '10.19 seconds'),
    ('ORD-LOAD-012','Lorenzo Gimenez','lorenzo.gimenez@mail.com','5492612412764',14,1,582.42,'no_stock',NOW() - INTERVAL '18 minutes',NOW() - INTERVAL '18 minutes' + INTERVAL '1.14 seconds',NOW() - INTERVAL '18 minutes' + INTERVAL '10.71 seconds'),
    ('ORD-LOAD-013','Victoria Ramos','victoria.ramos@mail.com','5492615446211',10,3,501.12,'no_stock',NOW() - INTERVAL '16 minutes',NOW() - INTERVAL '16 minutes' + INTERVAL '2.46 seconds',NOW() - INTERVAL '16 minutes' + INTERVAL '12.15 seconds'),
    ('ORD-LOAD-014','Felipe Acosta','felipe.acosta@mail.com','5492611307902',5,1,898.95,'no_stock',NOW() - INTERVAL '14 minutes',NOW() - INTERVAL '14 minutes' + INTERVAL '2.83 seconds',NOW() - INTERVAL '14 minutes' + INTERVAL '9.51 seconds'),
    ('ORD-LOAD-015','Guadalupe Ferrari','guadalupe.ferrari@mail.com','5492616145748',18,2,767.83,'confirmed',NOW() - INTERVAL '12 minutes',NOW() - INTERVAL '12 minutes' + INTERVAL '1.52 seconds',NOW() - INTERVAL '12 minutes' + INTERVAL '6.55 seconds'),
    ('ORD-LOAD-016','Dante Benitez','dante.benitez@mail.com','5492617385104',19,1,860.88,'no_stock',NOW() - INTERVAL '10 minutes',NOW() - INTERVAL '10 minutes' + INTERVAL '1.92 seconds',NOW() - INTERVAL '10 minutes' + INTERVAL '10.94 seconds'),
    ('ORD-LOAD-017','Alma Vega','alma.vega@mail.com','5492612760290',18,2,869.34,'confirmed',NOW() - INTERVAL '8 minutes',NOW() - INTERVAL '8 minutes' + INTERVAL '2.12 seconds',NOW() - INTERVAL '8 minutes' + INTERVAL '10.54 seconds'),
    ('ORD-LOAD-018','Ciro Pereyra','ciro.pereyra@mail.com','5492616597046',3,2,664.67,'confirmed',NOW() - INTERVAL '6 minutes',NOW() - INTERVAL '6 minutes' + INTERVAL '2.36 seconds',NOW() - INTERVAL '6 minutes' + INTERVAL '12.44 seconds'),
    ('ORD-LOAD-019','Mia Cabrera','mia.cabrera@mail.com','5492614183925',18,3,293.17,'no_stock',NOW() - INTERVAL '4 minutes',NOW() - INTERVAL '4 minutes' + INTERVAL '1.79 seconds',NOW() - INTERVAL '4 minutes' + INTERVAL '10.17 seconds'),
    ('ORD-LOAD-020','Gael Dominguez','gael.dominguez@mail.com','5492615791217',6,3,279.86,'confirmed',NOW() - INTERVAL '2 minutes',NOW() - INTERVAL '2 minutes' + INTERVAL '1.94 seconds',NOW() - INTERVAL '2 minutes' + INTERVAL '7.51 seconds');

-- ============================================================
-- INTERACCIONES (107) - TMR: FAQ 2.17s, RECLAMO 2.61s, ESTADO_PEDIDO 2.83s, GENERAL 2.46s (total 2.47s)
-- ============================================================
INSERT INTO interactions (channel, user_id, message, intent, ai_response, order_id, is_urgent, received_at, responded_at) VALUES
    ('telegram','5492611341636','gracias por todo','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '12 days' - INTERVAL '15 hours',NOW() - INTERVAL '12 days' - INTERVAL '15 hours' + INTERVAL '2.02 seconds'),
    ('email','5492613907133','tienen local fisico?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '11 days' - INTERVAL '19 hours',NOW() - INTERVAL '11 days' - INTERVAL '19 hours' + INTERVAL '2.37 seconds'),
    ('whatsapp','5492614418879','Tienen tiendas fisicas?','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '11 days' - INTERVAL '6 hours',NOW() - INTERVAL '11 days' - INTERVAL '6 hours' + INTERVAL '1.55 seconds'),
    ('whatsapp','5492619242340','Cuanto tarda el envio?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '13 days' - INTERVAL '4 hours',NOW() - INTERVAL '13 days' - INTERVAL '4 hours' + INTERVAL '2.66 seconds'),
    ('telegram','5492612690395','seguimiento de mi compra','ESTADO_PEDIDO','(respuesta automatica del asistente)',27,false,NOW() - INTERVAL '1 days' - INTERVAL '11 hours',NOW() - INTERVAL '1 days' - INTERVAL '11 hours' + INTERVAL '2.97 seconds'),
    ('email','5492613012368','hola','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '13 days' - INTERVAL '18 hours',NOW() - INTERVAL '13 days' - INTERVAL '18 hours' + INTERVAL '3.15 seconds'),
    ('email','5492612781734','Puedo pagar en cuotas?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '7 days' - INTERVAL '0 hours',NOW() - INTERVAL '7 days' - INTERVAL '0 hours' + INTERVAL '2.45 seconds'),
    ('telegram','5492618898749','El producto vino fallado','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '8 days' - INTERVAL '10 hours',NOW() - INTERVAL '8 days' - INTERVAL '10 hours' + INTERVAL '1.75 seconds'),
    ('whatsapp','5492618097983','Hacen factura A?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '3 days' - INTERVAL '10 hours',NOW() - INTERVAL '3 days' - INTERVAL '10 hours' + INTERVAL '2.39 seconds'),
    ('whatsapp','5492617621411','quiero la devolucion de mi plata','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '13 days' - INTERVAL '16 hours',NOW() - INTERVAL '13 days' - INTERVAL '16 hours' + INTERVAL '2.18 seconds'),
    ('whatsapp','5492616311090','buenas, una pregunta','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '3 days' - INTERVAL '8 hours',NOW() - INTERVAL '3 days' - INTERVAL '8 hours' + INTERVAL '1.89 seconds'),
    ('email','5492612528431','Tienen garantia los productos?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '4 days' - INTERVAL '3 hours',NOW() - INTERVAL '4 days' - INTERVAL '3 hours' + INTERVAL '1.77 seconds'),
    ('telegram','5492613701817','Nadie responde mi reclamo anterior','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '13 days' - INTERVAL '23 hours',NOW() - INTERVAL '13 days' - INTERVAL '23 hours' + INTERVAL '3.11 seconds'),
    ('telegram','5492617636513','Pague y me dicen sin stock','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '2 days' - INTERVAL '18 hours',NOW() - INTERVAL '2 days' - INTERVAL '18 hours' + INTERVAL '1.81 seconds'),
    ('whatsapp','5492613916362','Me llego el producto equivocado','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '11 days' - INTERVAL '4 hours',NOW() - INTERVAL '11 days' - INTERVAL '4 hours' + INTERVAL '2.67 seconds'),
    ('whatsapp','5492613589425','Pague y me dicen sin stock','RECLAMO','(respuesta automatica del asistente)',NULL,true,NOW() - INTERVAL '4 days' - INTERVAL '4 hours',NOW() - INTERVAL '4 days' - INTERVAL '4 hours' + INTERVAL '2.58 seconds'),
    ('telegram','5492613736998','cuanto sale el envio a cordoba?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '3 days' - INTERVAL '14 hours',NOW() - INTERVAL '3 days' - INTERVAL '14 hours' + INTERVAL '2.17 seconds'),
    ('whatsapp','5492617120699','Me llego el producto equivocado','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '10 days' - INTERVAL '3 hours',NOW() - INTERVAL '10 days' - INTERVAL '3 hours' + INTERVAL '2.03 seconds'),
    ('email','5492619739556','buenas, una pregunta','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '0 days' - INTERVAL '9 hours',NOW() - INTERVAL '0 days' - INTERVAL '9 hours' + INTERVAL '2.37 seconds'),
    ('whatsapp','5492616248095','Tienen tiendas fisicas?','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '7 days' - INTERVAL '17 hours',NOW() - INTERVAL '7 days' - INTERVAL '17 hours' + INTERVAL '2.84 seconds'),
    ('whatsapp','5492612765758','Hace 10 dias que espero y no llega','RECLAMO','(respuesta automatica del asistente)',NULL,true,NOW() - INTERVAL '10 days' - INTERVAL '4 hours',NOW() - INTERVAL '10 days' - INTERVAL '4 hours' + INTERVAL '3.86 seconds'),
    ('whatsapp','5492613986800','Hacen factura A?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '9 days' - INTERVAL '11 hours',NOW() - INTERVAL '9 days' - INTERVAL '11 hours' + INTERVAL '2.74 seconds'),
    ('telegram','5492614264715','buenas, una pregunta','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '8 days' - INTERVAL '4 hours',NOW() - INTERVAL '8 days' - INTERVAL '4 hours' + INTERVAL '1.57 seconds'),
    ('telegram','5492617642384','Excelente atencion, gracias!','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '10 days' - INTERVAL '16 hours',NOW() - INTERVAL '10 days' - INTERVAL '16 hours' + INTERVAL '3.27 seconds'),
    ('whatsapp','5492612602340','consulta general','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '10 days' - INTERVAL '3 hours',NOW() - INTERVAL '10 days' - INTERVAL '3 hours' + INTERVAL '2.18 seconds'),
    ('whatsapp','5492612573916','Hacen envios a todo el pais?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '8 days' - INTERVAL '11 hours',NOW() - INTERVAL '8 days' - INTERVAL '11 hours' + INTERVAL '2.03 seconds'),
    ('telegram','5492612021333','quiero la devolucion de mi plata','RECLAMO','(respuesta automatica del asistente)',NULL,true,NOW() - INTERVAL '2 days' - INTERVAL '4 hours',NOW() - INTERVAL '2 days' - INTERVAL '4 hours' + INTERVAL '1.72 seconds'),
    ('whatsapp','5492617788001','seguimiento de mi compra','ESTADO_PEDIDO','(respuesta automatica del asistente)',26,false,NOW() - INTERVAL '9 days' - INTERVAL '10 hours',NOW() - INTERVAL '9 days' - INTERVAL '10 hours' + INTERVAL '3.08 seconds'),
    ('whatsapp','5492615364584','Hace 10 dias que espero y no llega','RECLAMO','(respuesta automatica del asistente)',NULL,true,NOW() - INTERVAL '4 days' - INTERVAL '12 hours',NOW() - INTERVAL '4 days' - INTERVAL '12 hours' + INTERVAL '2.52 seconds'),
    ('whatsapp','5492616378219','Cuanto tarda el envio?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '1 days' - INTERVAL '6 hours',NOW() - INTERVAL '1 days' - INTERVAL '6 hours' + INTERVAL '2.86 seconds'),
    ('whatsapp','5492612999486','Me llego el producto equivocado','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '12 days' - INTERVAL '1 hours',NOW() - INTERVAL '12 days' - INTERVAL '1 hours' + INTERVAL '4.14 seconds'),
    ('telegram','5492614249423','quiero la devolucion de mi plata','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '11 days' - INTERVAL '22 hours',NOW() - INTERVAL '11 days' - INTERVAL '22 hours' + INTERVAL '2.48 seconds'),
    ('telegram','5492612218043','Aceptan MercadoPago?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '2 days' - INTERVAL '8 hours',NOW() - INTERVAL '2 days' - INTERVAL '8 hours' + INTERVAL '2.82 seconds'),
    ('whatsapp','5492614950271','Ya despacharon lo mio?','ESTADO_PEDIDO','(respuesta automatica del asistente)',5,false,NOW() - INTERVAL '6 days' - INTERVAL '10 hours',NOW() - INTERVAL '6 days' - INTERVAL '10 hours' + INTERVAL '2.79 seconds'),
    ('email','5492617159955','Me llego el producto equivocado','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '8 days' - INTERVAL '20 hours',NOW() - INTERVAL '8 days' - INTERVAL '20 hours' + INTERVAL '2.1 seconds'),
    ('telegram','5492611267315','El paquete llego roto','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '3 days' - INTERVAL '3 hours',NOW() - INTERVAL '3 days' - INTERVAL '3 hours' + INTERVAL '3.11 seconds'),
    ('telegram','5492612279133','Me llego el producto equivocado','RECLAMO','(respuesta automatica del asistente)',NULL,true,NOW() - INTERVAL '10 days' - INTERVAL '0 hours',NOW() - INTERVAL '10 days' - INTERVAL '0 hours' + INTERVAL '2.91 seconds'),
    ('whatsapp','5492613968822','gracias por todo','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '0 days' - INTERVAL '5 hours',NOW() - INTERVAL '0 days' - INTERVAL '5 hours' + INTERVAL '3.48 seconds'),
    ('whatsapp','5492616947320','hola','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '0 days' - INTERVAL '11 hours',NOW() - INTERVAL '0 days' - INTERVAL '11 hours' + INTERVAL '2.12 seconds'),
    ('whatsapp','5492612411673','Muy buenos productos','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '8 days' - INTERVAL '4 hours',NOW() - INTERVAL '8 days' - INTERVAL '4 hours' + INTERVAL '1.84 seconds'),
    ('email','5492615204822','El paquete llego roto','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '3 days' - INTERVAL '9 hours',NOW() - INTERVAL '3 days' - INTERVAL '9 hours' + INTERVAL '3.13 seconds'),
    ('whatsapp','5492611295300','hola','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '12 days' - INTERVAL '6 hours',NOW() - INTERVAL '12 days' - INTERVAL '6 hours' + INTERVAL '2.14 seconds'),
    ('email','5492617756146','Tienen tiendas fisicas?','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '13 days' - INTERVAL '7 hours',NOW() - INTERVAL '13 days' - INTERVAL '7 hours' + INTERVAL '2.71 seconds'),
    ('whatsapp','5492613215921','Aceptan MercadoPago?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '11 days' - INTERVAL '4 hours',NOW() - INTERVAL '11 days' - INTERVAL '4 hours' + INTERVAL '2.46 seconds'),
    ('whatsapp','5492613935614','Hace 10 dias que espero y no llega','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '12 days' - INTERVAL '16 hours',NOW() - INTERVAL '12 days' - INTERVAL '16 hours' + INTERVAL '2.91 seconds'),
    ('telegram','5492614435238','mi pedido figura confirmado pero no llega','ESTADO_PEDIDO','(respuesta automatica del asistente)',30,false,NOW() - INTERVAL '7 days' - INTERVAL '12 hours',NOW() - INTERVAL '7 days' - INTERVAL '12 hours' + INTERVAL '3.44 seconds'),
    ('whatsapp','5492615850535','Excelente atencion, gracias!','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '5 days' - INTERVAL '9 hours',NOW() - INTERVAL '5 days' - INTERVAL '9 hours' + INTERVAL '2.04 seconds'),
    ('whatsapp','5492615801511','mi pedido figura confirmado pero no llega','ESTADO_PEDIDO','(respuesta automatica del asistente)',21,false,NOW() - INTERVAL '4 days' - INTERVAL '21 hours',NOW() - INTERVAL '4 days' - INTERVAL '21 hours' + INTERVAL '2.94 seconds'),
    ('whatsapp','5492615294300','Quiero saber el estado de mi orden','ESTADO_PEDIDO','(respuesta automatica del asistente)',29,false,NOW() - INTERVAL '6 days' - INTERVAL '8 hours',NOW() - INTERVAL '6 days' - INTERVAL '8 hours' + INTERVAL '3.88 seconds'),
    ('whatsapp','5492613627627','quiero la devolucion de mi plata','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '11 days' - INTERVAL '20 hours',NOW() - INTERVAL '11 days' - INTERVAL '20 hours' + INTERVAL '2.82 seconds'),
    ('telegram','5492617776590','Hacen factura A?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '0 days' - INTERVAL '8 hours',NOW() - INTERVAL '0 days' - INTERVAL '8 hours' + INTERVAL '2.78 seconds'),
    ('telegram','5492612479773','tienen descuentos?','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '9 days' - INTERVAL '7 hours',NOW() - INTERVAL '9 days' - INTERVAL '7 hours' + INTERVAL '3.37 seconds'),
    ('telegram','5492611862923','El producto vino fallado','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '4 days' - INTERVAL '18 hours',NOW() - INTERVAL '4 days' - INTERVAL '18 hours' + INTERVAL '3.63 seconds'),
    ('telegram','5492617115357','quiero la devolucion de mi plata','RECLAMO','(respuesta automatica del asistente)',NULL,true,NOW() - INTERVAL '6 days' - INTERVAL '1 hours',NOW() - INTERVAL '6 days' - INTERVAL '1 hours' + INTERVAL '1.5 seconds'),
    ('whatsapp','5492618166230','Ya despacharon lo mio?','ESTADO_PEDIDO','(respuesta automatica del asistente)',15,false,NOW() - INTERVAL '3 days' - INTERVAL '6 hours',NOW() - INTERVAL '3 days' - INTERVAL '6 hours' + INTERVAL '2.41 seconds'),
    ('email','5492618811626','Pague y me dicen sin stock','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '13 days' - INTERVAL '15 hours',NOW() - INTERVAL '13 days' - INTERVAL '15 hours' + INTERVAL '1.48 seconds'),
    ('telegram','5492612833245','Donde esta mi pedido?','ESTADO_PEDIDO','(respuesta automatica del asistente)',26,false,NOW() - INTERVAL '4 days' - INTERVAL '8 hours',NOW() - INTERVAL '4 days' - INTERVAL '8 hours' + INTERVAL '2.71 seconds'),
    ('whatsapp','5492617702822','Me cobraron dos veces','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '0 days' - INTERVAL '7 hours',NOW() - INTERVAL '0 days' - INTERVAL '7 hours' + INTERVAL '1.89 seconds'),
    ('telegram','5492613995461','Me llego el producto equivocado','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '8 days' - INTERVAL '7 hours',NOW() - INTERVAL '8 days' - INTERVAL '7 hours' + INTERVAL '3.15 seconds'),
    ('whatsapp','5492618061179','Nadie responde mi reclamo anterior','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '0 days' - INTERVAL '15 hours',NOW() - INTERVAL '0 days' - INTERVAL '15 hours' + INTERVAL '2.65 seconds'),
    ('whatsapp','5492617521270','consulta general','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '5 days' - INTERVAL '2 hours',NOW() - INTERVAL '5 days' - INTERVAL '2 hours' + INTERVAL '3.45 seconds'),
    ('telegram','5492616067508','Excelente atencion, gracias!','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '7 days' - INTERVAL '17 hours',NOW() - INTERVAL '7 days' - INTERVAL '17 hours' + INTERVAL '1.58 seconds'),
    ('email','5492613935050','Cuanto tarda el envio?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '10 days' - INTERVAL '7 hours',NOW() - INTERVAL '10 days' - INTERVAL '7 hours' + INTERVAL '1.64 seconds'),
    ('email','5492618226803','Quiero saber el estado de mi orden','ESTADO_PEDIDO','(respuesta automatica del asistente)',12,false,NOW() - INTERVAL '0 days' - INTERVAL '18 hours',NOW() - INTERVAL '0 days' - INTERVAL '18 hours' + INTERVAL '2.18 seconds'),
    ('email','5492618407438','Nadie responde mi reclamo anterior','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '3 days' - INTERVAL '23 hours',NOW() - INTERVAL '3 days' - INTERVAL '23 hours' + INTERVAL '2.47 seconds'),
    ('email','5492619351530','Tienen tiendas fisicas?','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '1 days' - INTERVAL '0 hours',NOW() - INTERVAL '1 days' - INTERVAL '0 hours' + INTERVAL '2.0 seconds'),
    ('whatsapp','5492619684320','tienen local fisico?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '12 days' - INTERVAL '15 hours',NOW() - INTERVAL '12 days' - INTERVAL '15 hours' + INTERVAL '2.78 seconds'),
    ('telegram','5492611375758','Me llego el producto equivocado','RECLAMO','(respuesta automatica del asistente)',NULL,true,NOW() - INTERVAL '8 days' - INTERVAL '4 hours',NOW() - INTERVAL '8 days' - INTERVAL '4 hours' + INTERVAL '1.45 seconds'),
    ('whatsapp','5492611209056','buenas, una pregunta','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '0 days' - INTERVAL '2 hours',NOW() - INTERVAL '0 days' - INTERVAL '2 hours' + INTERVAL '3.74 seconds'),
    ('telegram','5492613429012','seguimiento de mi compra','ESTADO_PEDIDO','(respuesta automatica del asistente)',17,false,NOW() - INTERVAL '4 days' - INTERVAL '5 hours',NOW() - INTERVAL '4 days' - INTERVAL '5 hours' + INTERVAL '1.95 seconds'),
    ('telegram','5492619664989','Tienen garantia los productos?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '0 days' - INTERVAL '22 hours',NOW() - INTERVAL '0 days' - INTERVAL '22 hours' + INTERVAL '2.2 seconds'),
    ('telegram','5492613571417','Puedo pagar en cuotas?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '13 days' - INTERVAL '8 hours',NOW() - INTERVAL '13 days' - INTERVAL '8 hours' + INTERVAL '1.83 seconds'),
    ('whatsapp','5492612051909','buenas, una pregunta','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '12 days' - INTERVAL '14 hours',NOW() - INTERVAL '12 days' - INTERVAL '14 hours' + INTERVAL '1.46 seconds'),
    ('whatsapp','5492618130493','Nadie responde mi reclamo anterior','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '2 days' - INTERVAL '20 hours',NOW() - INTERVAL '2 days' - INTERVAL '20 hours' + INTERVAL '2.75 seconds'),
    ('whatsapp','5492612896093','Hacen factura A?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '11 days' - INTERVAL '15 hours',NOW() - INTERVAL '11 days' - INTERVAL '15 hours' + INTERVAL '2.75 seconds'),
    ('telegram','5492618510824','hola','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '1 days' - INTERVAL '9 hours',NOW() - INTERVAL '1 days' - INTERVAL '9 hours' + INTERVAL '3.56 seconds'),
    ('whatsapp','5492617247025','Hacen envios a todo el pais?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '13 days' - INTERVAL '9 hours',NOW() - INTERVAL '13 days' - INTERVAL '9 hours' + INTERVAL '1.84 seconds'),
    ('whatsapp','5492618416747','seguimiento de mi compra','ESTADO_PEDIDO','(respuesta automatica del asistente)',26,false,NOW() - INTERVAL '7 days' - INTERVAL '4 hours',NOW() - INTERVAL '7 days' - INTERVAL '4 hours' + INTERVAL '2.95 seconds'),
    ('whatsapp','5492613890197','Tienen tiendas fisicas?','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '8 days' - INTERVAL '18 hours',NOW() - INTERVAL '8 days' - INTERVAL '18 hours' + INTERVAL '1.91 seconds'),
    ('email','5492611593704','tienen descuentos?','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '3 days' - INTERVAL '5 hours',NOW() - INTERVAL '3 days' - INTERVAL '5 hours' + INTERVAL '1.79 seconds'),
    ('whatsapp','5492613134722','consulta general','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '11 days' - INTERVAL '12 hours',NOW() - INTERVAL '11 days' - INTERVAL '12 hours' + INTERVAL '3.29 seconds'),
    ('email','5492617991165','hola','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '2 days' - INTERVAL '14 hours',NOW() - INTERVAL '2 days' - INTERVAL '14 hours' + INTERVAL '1.57 seconds'),
    ('whatsapp','5492614691517','Hace 10 dias que espero y no llega','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '1 days' - INTERVAL '5 hours',NOW() - INTERVAL '1 days' - INTERVAL '5 hours' + INTERVAL '3.53 seconds'),
    ('email','5492615582124','buenas, una pregunta','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '1 days' - INTERVAL '11 hours',NOW() - INTERVAL '1 days' - INTERVAL '11 hours' + INTERVAL '3.18 seconds'),
    ('whatsapp','5492613131420','tienen local fisico?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '5 days' - INTERVAL '4 hours',NOW() - INTERVAL '5 days' - INTERVAL '4 hours' + INTERVAL '1.32 seconds'),
    ('email','5492614037155','Cuanto tarda el envio?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '7 days' - INTERVAL '9 hours',NOW() - INTERVAL '7 days' - INTERVAL '9 hours' + INTERVAL '1.7 seconds'),
    ('whatsapp','5492616641376','Hacen factura A?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '5 days' - INTERVAL '15 hours',NOW() - INTERVAL '5 days' - INTERVAL '15 hours' + INTERVAL '1.83 seconds'),
    ('email','5492619404372','Hacen envios a todo el pais?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '7 days' - INTERVAL '3 hours',NOW() - INTERVAL '7 days' - INTERVAL '3 hours' + INTERVAL '1.94 seconds'),
    ('telegram','5492617781314','tienen descuentos?','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '4 days' - INTERVAL '10 hours',NOW() - INTERVAL '4 days' - INTERVAL '10 hours' + INTERVAL '1.87 seconds'),
    ('whatsapp','5492618212330','Excelente atencion, gracias!','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '11 days' - INTERVAL '13 hours',NOW() - INTERVAL '11 days' - INTERVAL '13 hours' + INTERVAL '2.29 seconds'),
    ('whatsapp','5492616277492','Cuanto tarda el envio?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '13 days' - INTERVAL '2 hours',NOW() - INTERVAL '13 days' - INTERVAL '2 hours' + INTERVAL '1.33 seconds'),
    ('whatsapp','5492615912700','gracias por todo','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '9 days' - INTERVAL '9 hours',NOW() - INTERVAL '9 days' - INTERVAL '9 hours' + INTERVAL '2.08 seconds'),
    ('telegram','5492611548510','consulta general','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '5 days' - INTERVAL '20 hours',NOW() - INTERVAL '5 days' - INTERVAL '20 hours' + INTERVAL '2.19 seconds'),
    ('email','5492615770053','El producto vino fallado','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '0 days' - INTERVAL '0 hours',NOW() - INTERVAL '0 days' - INTERVAL '0 hours' + INTERVAL '2.61 seconds'),
    ('telegram','5492615503335','El producto vino fallado','RECLAMO','(respuesta automatica del asistente)',NULL,true,NOW() - INTERVAL '4 days' - INTERVAL '17 hours',NOW() - INTERVAL '4 days' - INTERVAL '17 hours' + INTERVAL '4.16 seconds'),
    ('whatsapp','5492611012645','Tienen tiendas fisicas?','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '3 days' - INTERVAL '7 hours',NOW() - INTERVAL '3 days' - INTERVAL '7 hours' + INTERVAL '1.47 seconds'),
    ('whatsapp','5492617255821','Hacen factura A?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '0 days' - INTERVAL '8 hours',NOW() - INTERVAL '0 days' - INTERVAL '8 hours' + INTERVAL '1.86 seconds'),
    ('whatsapp','5492614325308','buenas, una pregunta','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '8 days' - INTERVAL '23 hours',NOW() - INTERVAL '8 days' - INTERVAL '23 hours' + INTERVAL '3.14 seconds'),
    ('whatsapp','5492616563620','tienen local fisico?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '6 days' - INTERVAL '2 hours',NOW() - INTERVAL '6 days' - INTERVAL '2 hours' + INTERVAL '2.19 seconds'),
    ('whatsapp','5492612180785','Cuanto tarda el envio?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '1 days' - INTERVAL '18 hours',NOW() - INTERVAL '1 days' - INTERVAL '18 hours' + INTERVAL '1.5 seconds'),
    ('whatsapp','5492615793406','Me cobraron dos veces','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '1 days' - INTERVAL '11 hours',NOW() - INTERVAL '1 days' - INTERVAL '11 hours' + INTERVAL '2.8 seconds'),
    ('whatsapp','5492616952660','buenas, una pregunta','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '5 days' - INTERVAL '23 hours',NOW() - INTERVAL '5 days' - INTERVAL '23 hours' + INTERVAL '3.43 seconds'),
    ('whatsapp','5492613247011','Tienen tiendas fisicas?','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '0 days' - INTERVAL '21 hours',NOW() - INTERVAL '0 days' - INTERVAL '21 hours' + INTERVAL '3.75 seconds'),
    ('whatsapp','5492616890424','Me cobraron dos veces','RECLAMO','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '11 days' - INTERVAL '1 hours',NOW() - INTERVAL '11 days' - INTERVAL '1 hours' + INTERVAL '1.62 seconds'),
    ('email','5492613755590','Aceptan MercadoPago?','FAQ','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '8 days' - INTERVAL '20 hours',NOW() - INTERVAL '8 days' - INTERVAL '20 hours' + INTERVAL '2.38 seconds'),
    ('email','5492611991637','Ya despacharon lo mio?','ESTADO_PEDIDO','(respuesta automatica del asistente)',22,false,NOW() - INTERVAL '3 days' - INTERVAL '2 hours',NOW() - INTERVAL '3 days' - INTERVAL '2 hours' + INTERVAL '2.66 seconds'),
    ('whatsapp','5492614001830','tienen descuentos?','GENERAL','(respuesta automatica del asistente)',NULL,false,NOW() - INTERVAL '7 days' - INTERVAL '20 hours',NOW() - INTERVAL '7 days' - INTERVAL '20 hours' + INTERVAL '2.27 seconds');

-- ============================================================
-- TICKETS - uno por cada RECLAMO (escalado por diseno)
-- ============================================================
INSERT INTO tickets (interaction_id, channel, user_id, subject, status, priority) VALUES
    (8,'whatsapp','5492614863264','Reclamo del cliente (interaccion #8)','open','normal'),
    (10,'whatsapp','5492617416293','Reclamo del cliente (interaccion #10)','open','urgent'),
    (13,'whatsapp','5492618460244','Reclamo del cliente (interaccion #13)','open','urgent'),
    (14,'whatsapp','5492616349818','Reclamo del cliente (interaccion #14)','open','normal'),
    (15,'whatsapp','5492618005709','Reclamo del cliente (interaccion #15)','open','urgent'),
    (16,'whatsapp','5492616477252','Reclamo del cliente (interaccion #16)','open','high'),
    (18,'whatsapp','5492613368194','Reclamo del cliente (interaccion #18)','open','high'),
    (21,'whatsapp','5492618742668','Reclamo del cliente (interaccion #21)','open','high'),
    (27,'whatsapp','5492615454704','Reclamo del cliente (interaccion #27)','open','urgent'),
    (29,'whatsapp','5492619527979','Reclamo del cliente (interaccion #29)','open','normal'),
    (31,'whatsapp','5492616592248','Reclamo del cliente (interaccion #31)','open','urgent'),
    (32,'whatsapp','5492615480956','Reclamo del cliente (interaccion #32)','open','urgent'),
    (35,'whatsapp','5492619412922','Reclamo del cliente (interaccion #35)','open','normal'),
    (36,'whatsapp','5492617350574','Reclamo del cliente (interaccion #36)','open','high'),
    (37,'whatsapp','5492617130169','Reclamo del cliente (interaccion #37)','open','urgent'),
    (41,'whatsapp','5492616935447','Reclamo del cliente (interaccion #41)','open','high'),
    (45,'whatsapp','5492613310655','Reclamo del cliente (interaccion #45)','open','high'),
    (50,'whatsapp','5492614041100','Reclamo del cliente (interaccion #50)','open','urgent'),
    (53,'whatsapp','5492615567941','Reclamo del cliente (interaccion #53)','open','high'),
    (54,'whatsapp','5492618297477','Reclamo del cliente (interaccion #54)','open','normal'),
    (56,'whatsapp','5492619737450','Reclamo del cliente (interaccion #56)','open','high'),
    (58,'whatsapp','5492614596293','Reclamo del cliente (interaccion #58)','open','high'),
    (59,'whatsapp','5492611486009','Reclamo del cliente (interaccion #59)','open','urgent'),
    (60,'whatsapp','5492616774786','Reclamo del cliente (interaccion #60)','open','high'),
    (65,'whatsapp','5492612365412','Reclamo del cliente (interaccion #65)','open','normal'),
    (68,'whatsapp','5492617228136','Reclamo del cliente (interaccion #68)','open','high'),
    (74,'whatsapp','5492617067868','Reclamo del cliente (interaccion #74)','open','normal'),
    (83,'whatsapp','5492617881820','Reclamo del cliente (interaccion #83)','open','urgent'),
    (94,'whatsapp','5492615808859','Reclamo del cliente (interaccion #94)','open','normal'),
    (95,'whatsapp','5492617952472','Reclamo del cliente (interaccion #95)','open','urgent'),
    (101,'whatsapp','5492617472305','Reclamo del cliente (interaccion #101)','open','urgent'),
    (104,'whatsapp','5492613023571','Reclamo del cliente (interaccion #104)','open','urgent');
