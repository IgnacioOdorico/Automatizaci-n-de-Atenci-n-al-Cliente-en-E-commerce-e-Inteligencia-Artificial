# Guía de edición del `.docx` — de arriba para abajo

Seguí los pasos **en orden**, tal como vas bajando por el documento. Cada paso: 📍 dónde estás ·
🔎 qué buscar · ✅ qué poner (copiar y pegar). Guardá seguido.

---

## PASO 1 — RESUMEN, descripción del sistema (1ª página)

🔎 Buscá:
> "El segundo flujo es un chatbot omnicanal (~21 nodos) que unifica mensajes de WhatsApp, Telegram y email, y utiliza GPT-4o-mini para clasificar intenciones y generar respuestas automatizadas."

✅ Poné:
> "El segundo flujo es un chatbot cuya arquitectura contempla tres canales (WhatsApp, Telegram y email); en esta etapa se implementó y validó uno de ellos —WhatsApp, con envío simulado—, utilizando GPT-4o-mini para clasificar intenciones y generar respuestas automatizadas."

---

## PASO 2 — RESUMEN, párrafo de resultados

🔎 Buscá:
> "un MTTD promedio de 1,79 segundos, un MTTR promedio de 7,69 segundos (tiempo total end-to-end de 9,48 s frente a los 5–30 minutos del procesamiento manual), y un TMR promedio de 2,38 segundos para 107 interacciones del chatbot"

✅ Poné:
> "un MTTD promedio de 0,009 segundos, un MTTR promedio de 0,054 segundos (tiempo total end-to-end de 0,063 s, aproximadamente 780 veces más rápido que el baseline de atención manual medido en 49,1 s), y un TMR promedio de 1,47 segundos para 150 interacciones del chatbot"

---

## PASO 3 — PALABRAS CLAVE

🔎 Buscá: la palabra `omnicanal` en la línea de palabras clave.
✅ Quitala (o dejala si preferís, pero el trabajo ya no se declara omnicanal).

---

## PASO 4 — CAPÍTULO 1 (Introducción)

⚠️ Tu pluma. Dos cosas:
1. Agregá **2–3 citas** en el capítulo (hoy no tiene ninguna). Al menos una que respalde el problema (demoras de atención en PyMEs) y una del uso de automatización/chatbots en e-commerce.
2. Donde diga que el proceso manual toma **"5 a 30 minutos"**, cambialo por:
   > "un baseline de atención manual que medimos en promedio en 49,1 s (ver Experimento E4, §…)"

---

## PASO 5 — CAP. 4.5, FIGURA 3

📍 La captura del dashboard "Pipeline Post-Venta".
✅ Reemplazá la imagen por: `experiments\E5\figuras\flujo1.png`
✅ Epígrafe: "Figura 3. Dashboard del Flujo 1 (Pipeline Post-Venta) en Grafana, alimentado desde las vistas PostgreSQL con los datos medidos del Experimento E1."

---

## PASO 6 — CAP. 4.6.2, FIGURA 4 (Mailpit)

✅ Reemplazá la imagen por: `experiments\E5\figuras\mailpit.png` (dominios `@example.com`).
✅ Epígrafe: "Figura 4. Bandeja de Mailpit con los correos generados por el Flujo 1 durante las pruebas (dominios reservados @example.com)."

---

## PASO 7 — CAP. 4.6, TABLA DE MÉTRICAS (si aparece antes de resultados)

🔎 Buscá los valores `1.79 s` (MTTD) y `7.69 s` (MTTR).
✅ Cambialos por `0,009 s` y `0,054 s`.

---

## PASO 8 — CAP. 5.1, PRUEBA DE CARGA + FIGURA 5

**8a — La tabla de la prueba de carga.**
🔎 Buscá donde dice "12 confirmadas (60%)" y "8 sin stock (40%)".
✅ Reemplazá la tabla por:

| | Órdenes | Confirmadas | Sin stock |
|---|---|---|---|
| Prueba de carga (secuencial, E1.a) | 50 | 35 (70%) | 15 (30%) |

✅ Y agregá una línea: "El dashboard muestra el total medido acumulado (173 órdenes: 66 confirmadas, 58 sin stock, 49 en procesamiento de la prueba de concurrencia E1.b)."

**8b — La Figura 5.**
🔎 Es la misma imagen que la Figura 3 (ese fue el error C-02).
✅ **Eliminá la Figura 5.** Donde el texto la invocaba, referí a la Figura 3.

**8c — Los valores de latencia del §5.1.**
🔎 Buscá `1,79` y `7,69` en el texto de resultados.
✅ Cambialos por `0,009` y `0,054`. El end-to-end `9,48` → `0,063`.

---

## PASO 9 — CAP. 5.2.1, TABLA DE TMR POR INTENT

🔎 Buscá la tabla donde las cuatro filas dicen `2,38 s` (idéntico).
✅ Reemplazala por:

| Intent | Mensajes | TMR promedio |
|---|---|---|
| ESTADO_PEDIDO | 36 | 1,45 s |
| FAQ | 45 | 1,54 s |
| GENERAL | 29 | 1,28 s |
| RECLAMO | 40 | 1,54 s |
| **Total** | **150** | **1,47 s** |

---

## PASO 10 — CAP. 5.2.2, ACCURACY Y CLASIFICACIÓN

**10a — El accuracy global.**
🔎 Buscá `90,7%`.  ✅ Cambialo por `92,7%` (139/150) en TODO el capítulo.

**10b — Agregá la matriz de confusión** (fila = intent real, columna = predicho):

| real ＼ pred | ESTADO_PEDIDO | FAQ | GENERAL | RECLAMO | Total real |
|---|---|---|---|---|---|
| ESTADO_PEDIDO | 32 | 1 | 1 | 1 | 35 |
| FAQ | 1 | 44 | 2 | 1 | 48 |
| GENERAL | 0 | 0 | 25 | 0 | 25 |
| RECLAMO | 3 | 0 | 1 | 38 | 42 |
| **Total pred** | 36 | 45 | 29 | 40 | 150 |

**10c — Reemplazá la tabla de "precisión por clase"** por precisión, recall y F1 reales:

| Clase | Precisión | Recall | F1 |
|---|---|---|---|
| ESTADO_PEDIDO | 88,9% | 91,4% | 0,901 |
| FAQ | 97,8% | 91,7% | 0,946 |
| GENERAL | 86,2% | 100% | 0,926 |
| RECLAMO | 95,0% | 90,5% | 0,927 |

⚠️ Aclará en una frase: "Lo que en la versión anterior se reportaba como 'precisión' correspondía en realidad a la exhaustividad (recall); aquí se reportan las tres métricas."

---

## PASO 11 — CAP. 5.2 / 5.3, UMBRAL 85% E HIPÓTESIS

**11a — El umbral 85% (sacar la cita falsa).**
🔎 Buscá la cita "Ram, P., & Yih, W.-T. (2021)" o la frase que dice que el 85% "es consistente con estándares reportados…".
✅ Reemplazá por: "Se adoptó el 85% como criterio de aceptación definido por el equipo, apropiado para un prototipo académico de clasificación de intenciones en un dominio acotado."
✅ Y **borrá la entrada bibliográfica** de Ram & Yih del Capítulo 8.

**11b — La tabla de hipótesis.**
✅ Reemplazá los valores:

| Hipótesis | Criterio | Resultado | Estado |
|---|---|---|---|
| H1 | MTTD+MTTR < 30 s | E2E 0,063 s | CONFIRMADA |
| H2a | TMR < 10 s | 1,47 s | CONFIRMADA |
| H2b | Accuracy ≥ 85% | 92,7% · IC95 [88,2%; 96,3%] | CONFIRMADA |

⚠️ Agregá bajo la tabla: "Con n=150, el intervalo de confianza de Wilson al 95% para el accuracy es [88,2%; 96,3%]; su límite inferior supera el umbral de 85%, por lo que H2b se sostiene estadísticamente."

---

## PASO 12 — CAP. 5.3 / 5.4, FACTORES DE MEJORA

🔎 Buscá "190 veces", "1900 veces", o "menos del 1%/3%".
✅ Reemplazá por: "El pipeline procesa una orden en 0,063 s frente a los 49,1 s de la atención manual medida, una reducción de aproximadamente 780 veces."
✅ Sacá cualquier "5 a 30 minutos".

---

## PASO 13 — CAP. 5.2, TICKETS

🔎 Buscá donde dice "32 tickets" (o 37).
✅ Cambialo por "40 tickets" y agregá: "Los tickets se generan a partir de los mensajes clasificados como RECLAMO por el modelo (40), no de los reclamos reales (42); tres reclamos mal clasificados no generaron ticket y dos no-reclamos mal clasificados sí lo hicieron."

---

## PASO 14 — CAP. 6.2, TABLA DE OBJETIVOS

✅ Reemplazá las tres filas:

| Obj. | Enunciado | Resultado | Estado |
|---|---|---|---|
| OE1 | Pipeline: MTTD y MTTR < 30 s | MTTD 0,009 s / MTTR 0,054 s / Total 0,063 s. 50/50 órdenes sin errores. | CUMPLIDO |
| OE2 | Chatbot < 10 s y precisión ≥ 85% | TMR 1,47 s / Accuracy 92,7%. Un canal (WhatsApp) implementado y validado. | CUMPLIDO (un canal) |
| OE3 | Schema: 5 tablas, 5 vistas, índices | 5 tablas y 5 vistas implementadas. | CUMPLIDO PARCIAL* |

*⚠️ OE3: hoy el schema NO tiene índices (lo prometía el objetivo). O agregás los índices (te ayudo con el SQL en el Bloque 4), o acá declarás "índices pendientes / no implementados en esta etapa".

---

## PASO 15 — CAP. 8, BIBLIOGRAFÍA

✅ Borrá la entrada "Ram, P., & Yih, W.-T. (2021)" (ya reemplazaste su función en el Paso 11a).
⚠️ Retirá o reasigná las afirmaciones sin fuente (podés hacerlo después, no bloquea):
- 68% de expectativa multicanal, <200 órdenes/día por PyME, "PostgreSQL el más usado", y la comparación con el artículo de revisión.

---

## Cuando termines los Pasos 1 a 14
Ya cubriste todo el Bloque 1 y el Bloque 2 → es el salto de 4,2 a 6,5-7,0. El Paso 15 (biblio fina),
los índices y la forma (numerar figuras/tablas) son la última pasada hacia el 7,5-8,0.
