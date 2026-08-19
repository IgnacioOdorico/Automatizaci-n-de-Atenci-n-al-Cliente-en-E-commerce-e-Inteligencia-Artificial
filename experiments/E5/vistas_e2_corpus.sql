-- ============================================================
--  E5 — Vista del CORPUS de E2/E3 (150 mensajes con ground truth)
-- ============================================================
--  El dashboard "measured" del Flujo 2 mezcla 274 interacciones
--  (corrida 1 parcial + corrida 2 + sueltas). Las TABLAS de resultados
--  del Cap. 5 se reportan sobre el CORPUS RIGUROSO: la corrida 2 completa,
--  150 mensajes, que es la que tiene ground truth (etiquetas_ronda2.csv).
--
--  Identificador del corpus: batch de la corrida 2, ejecutada el
--  2026-08-12 ~23:00 (ver experiments/E2/resultados/e2_envios_2026-08-12_20-45-25.csv
--  y e2_corrida2_clasificaciones.csv). Se aísla por ventana horaria porque
--  los user_id se repiten entre corridas y no sirven de clave.
--
--  Aplicar:
--    Get-Content experiments/E5/vistas_e2_corpus.sql | `
--      docker exec -i tesis_postgres psql -U n8n_user -d ecommerce_tesis
-- ============================================================

CREATE OR REPLACE VIEW v_chatbot_corpus AS
SELECT
    i.id,
    i.channel,
    i.user_id,
    i.intent,                              -- intent PREDICHO por el modelo
    i.received_at,
    i.responded_at,
    EXTRACT(EPOCH FROM (i.responded_at - i.received_at)) AS tmr_seconds,
    i.is_urgent
FROM interactions i
WHERE i.data_source = 'measured'
  AND i.responded_at IS NOT NULL
  AND i.received_at >= '2026-08-12 23:00:00'
  AND i.received_at <  '2026-08-13 00:00:00';
