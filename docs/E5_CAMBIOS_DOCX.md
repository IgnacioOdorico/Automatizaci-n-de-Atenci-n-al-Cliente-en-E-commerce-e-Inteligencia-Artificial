# Mapa de cambios del `.docx` — cerrar la auditoría (4,2 → 6,5-7,0)

Documento de trabajo. Cada fila dice **dónde**, **qué dice hoy** y **qué va**. Está ordenado por
los Bloques del plan de corrección del jurado. Aplicar sobre `TESIS_FINAL_UTN_v5.docx`.

**Leyenda:** 🔧 cambio mecánico (reemplazo de número/texto) · ✍️ necesita tu pluma (redacción) ·
📊 reemplazo de figura/tabla.

**Decisiones ya tomadas (2026-08-19):**
- **C-01** → declarar **1 canal simulado** (no se implementan los 3).
- **C-06** → umbral 85% = **criterio propio del equipo** (se saca la cita falsa).
- **A-03** → se suma **evaluador externo** (tarea en paralelo del equipo).

---

## 0. Números canónicos (la fuente de verdad)

| Métrica | Valor viejo (seed/inventado) | **Valor nuevo (medido)** | Fuente |
|---|---|---|---|
| MTTD | 1,79 s | **0,009 s** | E1.a n=50 |
| MTTR | 7,69 s | **0,054 s** | E1.a n=50 |
| End-to-end | 9,48 s | **0,063 s** | E1.a n=50 |
| Baseline manual | "5–30 min" (sin medir) | **49,1 s** (IC95 [43,3; 55,0]) | E4 |
| Factor de mejora | 190x / 1900x | **≈780x** (49,1 / 0,063) | E4 vs E1.a |
| Accuracy global | 90,7% (97/107, sin medir) | **92,7%** (139/150, medido) | E2 corrida 2 |
| TMR global | 2,38 s | **1,47 s** | E2/E3 corpus 150 |
| n del corpus | 107 | **150** | E2 |
| Órdenes en dashboard | 32 | **173** (66 conf / 58 sin stock / 49 pending) | E1 measured |
| Tickets | 32 / 37 | **40** (sobre RECLAMO predicho) | E2/E3 |

---

## 1. BLOQUE 1 — Reconciliar la evidencia (bloqueante)

### 1.1 🔧 Resumen / Abstract
- MTTD **1,79 → 0,009 s**, MTTR **7,69 → 0,054 s**, E2E **9,48 → 0,063 s**, TMR **2,38 → 1,47 s**, accuracy **90,7 → 92,7%**.
- ✍️ Reescribir la frase de impacto: en vez de "190/1900 veces frente al proceso manual de 5–30 min", va **"≈780 veces más rápido que el baseline manual medido de 49,1 s"** (cierra C-08 y C-09).

### 1.2 📊 Figuras (cierra C-02, C-03, C-04, C-05, A-04)
- **Fig. 3 (§4.5)** → reemplazar por `experiments/E5/figuras/flujo1.png` (dashboard Flujo 1, datos medidos).
- **Fig. 4 (§4.6.2)** → reemplazar por `experiments/E5/figuras/mailpit.png` (dominios `@example.com`, cierra A-04).
- **Fig. 5 (§5.1)** → **eliminar** como figura separada (era copia de Fig. 3, ese fue C-02). §5.1 referencia la Fig. 3.
- **Nueva figura (§5.2)** → `experiments/E5/figuras/flujo2.png` (dashboard Chatbot, corpus 150). Numerarla y escribir epígrafe.

### 1.3 🔧📊 Tabla de la prueba de carga (§5.1) — cierra C-03
Reemplazar por los valores de E1.a (n=50 secuencial):

| | Órdenes | Confirmadas | Sin stock |
|---|---|---|---|
| Prueba de carga (E1.a) | **50** | **35 (70%)** | **15 (30%)** |
| Total medido en dashboard | **173** | 66 | 58 (+49 pending) |

> Nota ✍️: aclarar que el dashboard muestra TODO lo medido (E1.a + E1.b concurrencia), y que la
> tabla de carga reporta E1.a. Ya no hay "19/7/32 imposible".

### 1.4 🔧 Titular de latencia (§5.1, §5.3) — cierra C-05
- MTTD **0,009 s**, MTTR **0,054 s**. Ya no contradice la serie diaria (todo sub-segundo).
- ✍️ Quitar cualquier afirmación de "promedio bajo carga = promedio global = 1,79/7,69". Ahora el headline es E1.a controlado (n=50); E1.b (concurrencia) se reporta aparte como atomicidad.

---

## 2. BLOQUE 2 — Alcance e integridad bibliográfica (bloqueante)

### 2.1 ✍️ C-01 — Reescribir el alcance del Flujo 2 (1 canal simulado)
Tocar los **5 lugares** que hoy dicen "omnicanal":
- **Resumen**: "chatbot omnicanal (WhatsApp + Telegram + correo)" → "chatbot con arquitectura **diseñada** para tres canales, del cual se **implementó y validó uno** (WhatsApp, con envío simulado)".
- **Objetivo específico 2**: misma corrección.
- **Tabla de nodos (Cap. 4)**: marcar cuáles nodos están en el flujo ejecutado (13) y cuáles quedan en el archivo de producción no ejecutado.
- **Título §5.2**: "Resultados del Flujo 2 — Chatbot (canal WhatsApp simulado)".
- **§6.2 (cumplimiento OE2)**: declarar cumplido **parcialmente** — un canal validado.

### 2.2 ✍️ C-06 — Umbral 85% como criterio propio
- Sacar la cita "Ram, P., & Yih, W.-T. (2021)" (no existe).
- Reformular: "Se adoptó **85% como criterio de aceptación definido por el equipo**, apropiado para un prototipo académico de clasificación de intents en dominio acotado."

### 2.3 ✍️ C-07 — Retirar/reasignar 4 afirmaciones sin fuente
- 68% expectativa multicanal → retirar o buscar fuente real.
- <200 órdenes/día por PyME → retirar o degradar a supuesto.
- "PostgreSQL el gestor open-source más usado" → retirar (el ranking pone MySQL arriba).
- Comparación con "resultados" de un artículo de revisión → retirar (no reporta resultados propios).

### 2.4 ✍️ C-09 — Baseline + citas del Cap. 1
- Reemplazar "5–30 min" por **"baseline manual medido de 49,1 s (E4, ver §…)"** en todos lados.
- Agregar **al menos 2-3 citas al Capítulo 1** (hoy no tiene ninguna).

---

## 3. BLOQUE 3 — Estadística (sube a 7,5-8,0)

### 3.1 🔧📊 Tabla de accuracy por clase (§5.2.2) — cierra A-10
Reemplazar la tabla vieja por precisión/recall/F1 reales + agregar la **matriz de confusión**:

**Matriz de confusión** (fila = intent real, columna = predicho):

| real ＼ pred | ESTADO_PEDIDO | FAQ | GENERAL | RECLAMO | real |
|---|---|---|---|---|---|
| ESTADO_PEDIDO | 32 | 1 | 1 | 1 | 35 |
| FAQ | 1 | 44 | 2 | 1 | 48 |
| GENERAL | 0 | 0 | 25 | 0 | 25 |
| RECLAMO | 3 | 0 | 1 | 38 | 42 |
| **pred** | 36 | 45 | 29 | 40 | **150** |

**Precisión / Recall / F1:**

| Clase | Precisión | Recall | F1 |
|---|---|---|---|
| ESTADO_PEDIDO | 88,9% | 91,4% | 0,901 |
| FAQ | 97,8% | 91,7% | 0,946 |
| GENERAL | 86,2% | 100% | 0,926 |
| RECLAMO | 95,0% | 90,5% | 0,927 |
| **Global** | — | **92,7%** | — |

> ✍️ Aclarar que lo que antes se llamaba "precisión" era **recall**. Ahora se reportan las tres.

### 3.2 🔧📊 Tabla de TMR por intent (§5.2.1) — cierra A-05
Reemplazar las cuatro medias idénticas de 2,38 s por las reales del corpus (agrupadas por intent predicho, como el dashboard):

| Intent | n (predicho) | TMR |
|---|---|---|
| ESTADO_PEDIDO | 36 | 1,45 s |
| FAQ | 45 | 1,54 s |
| GENERAL | 29 | 1,28 s |
| RECLAMO | 40 | 1,54 s |
| **Global** | 150 | **1,47 s** |

### 3.3 ✍️ Tabla de hipótesis (§5.3) — cierra A-01
- **H1** (MTTD+MTTR < 30s): CONFIRMADA con E2E **0,063 s** (margen enorme).
- **H2a** (TMR < 10s): CONFIRMADA con **1,47 s**.
- **H2b** (accuracy ≥ 85%): ahora **SÍ se sostiene**. Con 150 casos y 92,7%, el **IC95 Wilson = [88,2%; 96,3%]**, cuyo piso (88,2%) **supera** el umbral de 85%. Reportar el IC y el valor-p. (Con los 107 viejos no se sostenía; con 150 sí.)

### 3.4 ✍️ A-11 — Tickets/resolución sobre intent predicho
- Los tickets salen de los RECLAMO **predichos** = **40** (no de los 42 reales). Coincide con la BD.
- Aclarar que 3 reclamos reales mal clasificados **no** generaron ticket, y 2 no-reclamos mal clasificados **sí** lo generaron (enrutamiento por predicción).

### 3.5 ✍️ A-08, A-09
- **A-08** (atomicidad): reemplazar por E1.b — 20 pedidos concurrentes contra stock 5 → 5 confirmadas, **cero sobreventa**, stock nunca negativo. Ahora SÍ prueba atomicidad.
- **A-09**: unificar "media vs mediana" (usamos media, declararlo consistente) y retirar el supuesto de normalidad.

---

## 4. Lo que este mapa NO cubre (para después)

- **Bloque 4 — schema (A-12):** tabla de ítems de orden, índices, `TIMESTAMPTZ`, restricciones de estado/stock. Es trabajo de SQL, no de `.docx`. Coordinar aparte.
- **A-03 — evaluador externo:** tarea humana en paralelo (conseguir la persona, re-etiquetar, κ de Cohen).
- **Forma (A-06, B-01..B-08):** numerar/referenciar figuras y tablas, bibliografía (lista única, sangría francesa, cursivas), índice. Es la última pasada.

---

## Orden sugerido de ataque
1. Bloque 1 completo (números + figuras) → es lo que más sube la nota y lo tenés todo acá.
2. Bloque 2 (los 4 ítems de alcance/biblio) → mayormente redacción, sin datos nuevos.
3. Bloque 3 (pegar las tablas nuevas + reformular hipótesis) → ya calculado arriba.
4. Bloque 4 + forma → al final.
