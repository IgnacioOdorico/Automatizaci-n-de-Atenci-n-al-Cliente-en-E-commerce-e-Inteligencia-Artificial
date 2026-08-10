# Plan de Regeneración de Evidencia — TFI UTN FRM

**Estado al 2026-08-10:** bloqueantes B-1 a B-7 ✅ cerrados · **E1 ✅ ejecutado** (§14) · E2 en curso (corpus congelado, falta etiquetar) · E3-E6 pendientes.
**Decisiones:** D-1, D-2, D-5 aprobadas el 2026-08-09 · D-3 y D-4 aplicadas · **D-6 resuelta el 2026-08-10** (§14.4).
**Fecha:** 2026-08-09 · **última actualización:** 2026-08-10
**Autores del TFI:** Santiago Sordi, Ignacio Odorico, Juan Cruz Ana — Director: Prof. Alberto Cortez
**Documento que corrige:** `docs/TESIS_FINAL_UTN_v5.docx` (52 pág)
**Devolución que responde:** `docs/devoluciones/auditoriaTFISordiOdoricoAna.docx` (39 hallazgos, dictamen 4,2/10)

---

## 0. Por qué existe este plan

La auditoría del tribunal detectó en el Capítulo 5 una serie de inconsistencias numéricas: sumas que no cierran (19+7≠32), combinaciones de intent que superan el total de interacciones, un promedio de TMR menor que todos los valores de la serie diaria, y un TMR idéntico al centésimo en los cuatro grupos de intent.

El auditor las trató como errores de transcripción. **No lo son.** La verificación forense contra la base de datos viva (sesión del 2026-08-05) determinó la causa raíz:

> Los resultados del Capítulo 5 no son mediciones. Son filas literales de `seed_expand.sql`.

Evidencia:

| Indicio | Hallazgo |
|---|---|
| Microsegundos | Las 107 filas de `interactions` (IDs 1-107) comparten un único valor `.676503`. Un INSERT batch, no 107 ejecuciones. |
| `ai_response` | Es el literal `'(respuesta automatica del asistente)'` en las 107. GPT nunca respondió. |
| `intent` | Está escrito a mano en el INSERT (`seed_expand.sql:153+`). **GPT-4o-mini nunca clasificó esos mensajes.** |
| `responded_at` | Es `received_at + INTERVAL 'X.XX seconds'` hardcodeado. El TMR es un número inventado, no medido. |
| Órdenes | `ORD-LOAD-001..020` comparten microsegundo `.669039` y están literales en `seed_expand.sql:129-148`. Los MTTD/MTTR de la vista coinciden exacto con los INTERVAL del seed. |
| Canales | `telegram` (29) y `email` (21) son seed. Por eso aparecen en los datos aunque el workflow no tenga esos triggers. |

**Consecuencia académica:** §5.1 (prueba de carga), §5.2.1 (TMR) y §5.2.2 (accuracy 90,7%) no miden nada. La hipótesis H2b es, hoy, imposible de sostener: no existe ninguna clasificación hecha por el modelo.

**Lo que sí es real y hay que preservar:**
- `interactions` IDs 108-116 → 9 filas, 9 microsegundos distintos, respuestas reales de GPT.
- `orders` ORD-DEMO-01 y ORD-DEMO-02 → microsegundos distintos.

Esas 11 filas son la prueba de que **el sistema funciona**. No hay que reconstruir nada. Hay que correr los experimentos por primera vez.

**Esto corrige el pronóstico del auditor.** Él estimó "medio día para reconciliar, si existen las queries y los datos". Los datos existen pero son sintéticos: el Bloque 1 no es re-correr queries, es **ejecutar los experimentos**.

---

## 1. Alcance: qué cubre y qué NO cubre este plan

### Cubre (Bloque 1 de la auditoría, bloqueante)

| Experimento | Qué produce | Hallazgos que cierra |
|---|---|---|
| **E1** — Prueba de carga Flujo 1 | MTTD, MTTR, end-to-end reales | C-03, C-05, A-01, A-08 |
| **E2** — Corpus del chatbot por el pipeline real | Clasificaciones reales de GPT-4o-mini | C-04, A-04, H2b |
| **E3** — TMR por intent | TMR real con `GROUP BY` | A-05, C-05 |
| **E4** — Baseline manual | El denominador de "31,6x" con fuente o medición | A-09, C-08 |
| **E5** — Recaptura de figuras | Figuras 3, 4 y 5 distintas y consistentes | C-02, A-11 |
| **E6** — Paquete de reproducibilidad | Scripts + corpus + queries publicables como Anexo | A-13, Tabla 3.1 |

### NO cubre (queda para el Bloque 2, es trabajo de redacción)

- **C-01 — Omnicanal.** Los mensajes de E2 entran **todos por WhatsApp**. El workflow tiene un solo trigger. Ningún experimento recupera el omnicanal: hay que **declarar el alcance real como monocanal** en las 9 secciones mapeadas (Resumen, §1.6.1, OE2, §3.2, Tabla 3.1, §4.4+Tabla 4.5, panel 6 de Grafana, título §5.2, §6.2).
- **C-06 — La cita "Ram & Yih (2021)" no existe.** Es la única fuente que funda el umbral del 85%. Recomendación: declararlo criterio propio del equipo, con justificación técnica.
- **C-08 — Factor 190x/1900x.** Los valores correctos son 31,6x y 189,9x. Es aritmética, no medición. Cascada: §5.4, §5.3, §6.1.
- Las 4 afirmaciones atribuidas a fuentes que no las contienen.
- **A-07** — El Flujo 1 no tiene rama de alerta de stock bajo, pese a que PF-03 la declara aprobada. Es una discrepancia de documentación, no de datos.

> **Regla de oro del orden de trabajo (ya acordada):** primero los DATOS, después las FIGURAS, y recién al final la REDACCIÓN. Corregir el texto antes obliga a rehacerlo dos veces.

---

## 2. Bloqueantes previos — resolver ANTES de ejecutar

Estos siete puntos se atacan en orden. Si alguno falla, el experimento correspondiente no arranca.

### B-1 — Levantar el entorno
Docker está apagado (verificado hoy). Además corre bajo el nombre de proyecto `pipeline-de-automatizacin-del-ciclo-post-venta`, por lo que `docker compose ps` sale vacío desde el cwd actual — usar `docker ps`.

### B-2 — Backup íntegro antes de tocar nada
`.\backup.ps1` genera `backups\<fecha>\` e incluye workflows y credenciales leídas de las tablas de n8n. **Sin este backup no se ejecuta ningún paso posterior.** Es la única red de seguridad frente a una pérdida de las 11 filas reales.

### B-3 — ⚠️ NUNCA volver a correr `seed_expand.sql`
La línea 110 hace:

```sql
TRUNCATE tickets, interactions, orders RESTART IDENTITY CASCADE;
```

Eso destruiría las 11 filas reales y todo lo que generemos. **El archivo queda congelado.** Si hace falta reinicializar productos o FAQs, extraer solo esas secciones a un archivo aparte (`seed_catalogo.sql`) que no toque tablas transaccionales.

### B-4 — Decidir el destino de los datos seed

Es la decisión de mayor impacto del plan. Dos caminos:

| | **Opción A — BD limpia** *(recomendada)* | **Opción B — Convivencia** |
|---|---|---|
| Qué se hace | Truncar transaccionales, correr los experimentos, reportar exactamente lo que salga | Dejar el seed, marcarlo como sintético, correr experimentos aparte y reportar solo estos |
| A favor | Integridad total. Toda fila de la BD es medición. Ante la pregunta "¿esto lo midieron?" la respuesta es sí, sin matices | No se pierde la serie de 14 días que alimenta las figuras diarias |
| En contra | Se pierde la dispersión temporal: los datos reales serán de una o pocas jornadas | Hay que sostener la separación en cada query, cada vista y cada panel. Un `GROUP BY` mal filtrado vuelve a mezclar todo. Y el tribunal ya desconfía de los números |
| Efecto en figuras | La serie diaria se reemplaza por un **histograma de distribución** — que es mejor estadística: muestra dispersión, outliers y forma, no solo promedios | Se conserva la serie, pero es sintética |

**Recomendación: Opción A.** El costo (perder una serie temporal decorativa) es menor que el beneficio (que no quede ni una fila cuestionable). Y el histograma responde mejor a los hallazgos del Bloque 3 sobre estadística que la serie diaria.

En cualquiera de las dos: **preservar antes las 11 filas reales** exportándolas a `experiments/baseline_real_previo.sql`.

### B-5 — Marca de procedencia de los datos
Para que este problema no pueda repetirse, agregar a las tablas transaccionales:

```sql
ALTER TABLE orders       ADD COLUMN data_source VARCHAR(20) DEFAULT 'measured';
ALTER TABLE interactions ADD COLUMN data_source VARCHAR(20) DEFAULT 'measured';
```

Toda fila insertada a mano lleva `'synthetic'`. Toda fila escrita por un workflow lleva el default. Es una columna, y vuelve auditable la BD para siempre. *(Nivel de gobernanza: HIGH — modifica el schema. Requiere aprobación explícita.)*

### B-6 — Verificaciones técnicas del pipeline (pre-vuelo)

| # | Qué verificar | Por qué importa |
|---|---|---|
| 1 | ¿La rama `no_stock` del Flujo 1 escribe `notified_at`? | En la rama con stock lo hace el nodo `Registrar Notificación`. En la rama sin stock la secuencia es `Marcar Sin Stock → Enviar Email Sin Stock → Respuesta Sin Stock` — **no se ve un nodo que registre la notificación**. Si no lo escribe, el MTTR de las órdenes sin stock sale NULL y la muestra se parte al medio. |
| 2 | ¿Está configurada la credencial de OpenAI en el Flujo 2 SIMPLE? | El workflow SIMPLE usa el nodo `OpenAI Chat Model` (`lmChatOpenAi`). Necesita API key real. Sin esto E2 no corre. |
| 3 | ¿`Registrar Interacción` escribe `responded_at` con el timestamp real de fin? | Es la mitad del TMR. Si toma `NOW()` en el nodo equivocado, mide otra cosa. |
| 4 | ¿El endpoint es `/webhook/whatsapp`? | El Anexo E de la tesis apunta a `/webhook/chatbot-whatsapp` — **no reproduce**. Fijar el valor correcto ahora y corregir el anexo después. |
| 5 | ¿El payload del Anexo E tiene la estructura de la WhatsApp Cloud API? | Hoy usa `product_id` en vez de `product_sku` y no respeta `entry[].changes[].value.messages[]`. |

### B-7 — Emails con dominios reservados desde el arranque
La Figura 4 de la tesis expone 10 direcciones de email reales. En vez de censurarla después, **generar todos los datos de E1 con dominios reservados** (`@example.com`, RFC 2606). La figura sale limpia de origen y no hay que retocar imágenes — retocar figuras es exactamente lo que produjo C-02.

---

## 3. E1 — Prueba de carga del Flujo 1

### Objetivo
Medir MTTD, MTTR y tiempo end-to-end reales del pipeline de órdenes, con evidencia de atomicidad bajo concurrencia.

### Diseño

**E1.a — Carga secuencial (la muestra principal)**

- **n = 50 órdenes** (la tesis reportaba 20). No cuesta nada — es local, sin APIs externas — y 50 da un intervalo de confianza notablemente más angosto sobre el MTTD/MTTR.
- Distribución: ~35 con stock disponible, ~15 forzando `no_stock` (pedir más unidades de las que hay).
- Envío secuencial con espaciado de 2 s, contra `POST /webhook/orden-nueva`.
- SKUs del catálogo real (`PROD-001..PROD-020`), emails `@example.com`.
- Cada request registra el timestamp de envío del lado del cliente, para poder contrastarlo con `received_at` del servidor.

**E1.b — Prueba de concurrencia / atomicidad (cierra A-08)**

Este es el experimento que la tesis nunca hizo y que el tribunal marcó:

1. Fijar un producto con `stock = 5`.
2. Disparar **20 requests simultáneas** pidiendo 1 unidad cada una.
3. Resultado esperado: exactamente 5 confirmadas, 15 en `no_stock`, y `stock = 0`. Nunca negativo.
4. Repetir 3 veces.

Si aparece sobreventa, es un hallazgo legítimo y publicable: se documenta la condición de carrera y se discute la mitigación (`SELECT ... FOR UPDATE` o restricción a nivel BD). **Un hallazgo negativo bien medido vale más académicamente que un número lindo inventado.** Y el `CHECK (stock >= 0)` de `init_simple.sql` ya actúa como red: la sobreventa fallaría ruidosamente, no en silencio.

### Métricas a extraer

| Métrica | Definición | Origen |
|---|---|---|
| MTTD | `processed_at − received_at` | `v_order_processing_time` |
| MTTR | `notified_at − processed_at` | `v_order_processing_time` |
| End-to-end | `notified_at − received_at` | `v_order_processing_time` |

Reportar para cada una: **n, media, mediana, desvío estándar, mín, máx, p95**. La tesis actual solo reporta el promedio — el Bloque 3 de la auditoría pide dispersión.

### Costo y duración
~10 minutos de ejecución. Sin costo monetario.

### Riesgo conocido
Si B-6.1 confirma que la rama `no_stock` no escribe `notified_at`, hay dos salidas: (a) agregar el nodo faltante al workflow — cambio real de sistema, hay que documentarlo como tal; o (b) reportar el MTTR solo sobre la rama con stock y declarar explícitamente esa limitación. **La opción (a) es preferible**, pero es una modificación del sistema construido y merece su propia aprobación.

---

## 4. E2 — Corpus del chatbot por el pipeline real

Es el experimento más caro en tiempo humano y **el de mayor rendimiento académico**. Es el único que puede sostener H2b.

### 4.1 Tamaño de la muestra — decisión estadística

La auditoría (Bloque 3) señala que con n=107 y p̂=0,907, el test de una cola contra H₀: p = 0,85 da **p = 0,060** — no significativo al 5%. Es decir: **aun si los 107 fueran reales, no alcanzaban para afirmar que se supera el umbral.**

| n | IC Wilson aprox. (p̂≈0,90) | p-valor vs H₀=0,85 | Etiquetado humano |
|---|---|---|---|
| 107 | [83,7 – 94,8] | ≈ 0,060 — **no significativo** | ~2 h × 2 anotadores |
| **150** | **[84,2 – 94,0]** | **≈ 0,043 — significativo** | **~3 h × 2 anotadores** |
| 200 | [85,2 – 93,6] | ≈ 0,024 — cómodo | ~4 h × 2 anotadores |

**Recomendación: n = 150.** Cruza el umbral de significancia con margen, y el costo incremental de etiquetado sobre 107 es de una hora por anotador. Con 107 se corre el riesgo de repetir exactamente el reproche que ya recibimos.

### 4.2 Protocolo de ground truth ciego (cierra A-04)

El defecto de fondo del 90,7% original no es solo que fuera inventado: es que **no existe un ground truth independiente** contra el cual medir. Protocolo:

1. **Construir el corpus** de 150 mensajes en español rioplatense, cubriendo los 4 intents con distribución realista. Base: los mensajes de `seed_expand.sql` sirven como material de partida (son verosímiles), pero hay que ampliarlos y agregar **casos ambiguos y de frontera** — un corpus donde todo es obvio infla el accuracy artificialmente.
2. **Congelar el corpus** en `experiments/corpus_intents.csv` y hacer commit **antes** de ejecutar nada. La marca de tiempo de git es la prueba de que no se ajustó a posteriori.
3. **Etiquetado ciego e independiente:** dos anotadores etiquetan por separado, sin ver la salida del modelo. Ideal: uno de los anotadores es externo al equipo.
4. **Medir la concordancia entre anotadores** con **kappa de Cohen**. Si κ < 0,70, el esquema de intents es ambiguo y hay que refinar las definiciones antes de seguir — eso también es un resultado reportable.
5. **Resolver desacuerdos** con un tercer evaluador o por consenso documentado.
6. **Recién entonces** ejecutar el corpus contra `/webhook/whatsapp` y comparar.

### 4.3 Ejecución

- Envío secuencial con espaciado de 3 s (para no golpear el rate limit de OpenAI).
- Payload con la estructura real de la WhatsApp Cloud API.
- Cada mensaje deja una fila en `interactions` con el `intent` **producido por el modelo** y el `responded_at` real.
- Cruce contra el ground truth por `user_id` + texto del mensaje.

### 4.4 Métricas a extraer

- **Accuracy global** con **IC de Wilson** al 95% (no el intervalo normal — con proporciones cercanas a 1 el normal se rompe).
- **Matriz de confusión 4×4.** La tesis nunca la presentó y es el estándar del área.
- **Precision, recall y F1 por intent.** El accuracy global esconde que ESTADO_PEDIDO puede ser el intent más débil.
- **Test de una cola** contra H₀: p = 0,85 (binomial exacto), con el p-valor reportado explícitamente.
- **κ de Cohen** entre anotadores.

### Costo y duración
~150 llamadas a `gpt-4o-mini` ≈ **USD 0,05**. Ejecución: ~10 min. **El costo real es el etiquetado: media jornada de dos personas.**

### Limitación a declarar sin rodeos
Los 150 mensajes entran **todos por WhatsApp**. El experimento mide la clasificación de intents, **no la omnicanalidad**. Va escrito así en §5.2, no insinuado.

---

## 5. E3 — TMR por intent

No requiere ejecución propia: **sale de los mismos datos de E2**, con la query correcta.

El error original fue copiar el promedio global en las cuatro filas de la tabla en vez de hacer `GROUP BY`. La medición previa contra la BD viva ya mostró que los valores reales difieren entre sí — tal como predijo A-05:

| Intent | TMR (s) | n |
|---|---|---|
| GENERAL | 2,50 | 37 |
| RECLAMO | 2,63 | 33 |
| FAQ | 2,54 | 32 |
| ESTADO_PEDIDO | 2,73 | 14 |

*(Valores de la BD al 2026-08-05, mezcla de seed y real — ilustran el método, no son el resultado final.)*

**Definir explícitamente el límite de medición.** El TMR calculado como `responded_at − received_at` incluye el overhead de n8n y la latencia de red hacia OpenAI, pero **no** el tiempo de entrega al canal. La tesis debe decir qué mide exactamente. Sin esa definición, el número no es comparable con nada.

---

## 6. E4 — Baseline de atención manual

El factor "31,6x" tiene numerador medido (9,48 s) y **denominador sin fundamento**: el rango "5-30 minutos" de atención manual no está citado ni medido. Es el mismo tipo de defecto que C-06.

Tres salidas, en orden de preferencia:

1. **Medirlo.** Un operador humano procesa 10 órdenes manualmente (leer el pedido, verificar stock en la BD, actualizar, redactar y enviar el email) con cronómetro. Es una hora de trabajo y convierte el denominador en un dato propio y defendible.
2. **Citarlo** con una fuente real y verificable de la industria.
3. **Degradarlo** a supuesto declarado: "bajo el supuesto de un tiempo de atención manual de X minutos...". Honesto, pero pierde fuerza.

**Recomendación: la opción 1.** Una hora de trabajo transforma la afirmación más vistosa de la tesis de "sin respaldo" a "medida por los autores".

---

## 7. E5 — Recaptura de figuras

**Solo después de que E1-E4 estén cerrados.** Recapturar antes obliga a rehacerlo.

| Figura | Problema | Acción |
|---|---|---|
| **Fig. 3** (§4.5, configuración) y **Fig. 5** (§5.1, resultado) | **Son la misma imagen** — huella criptográfica idéntica (C-02) | Dos capturas genuinamente distintas: Fig. 3 muestra la *configuración* del panel; Fig. 5 muestra el *resultado* con los datos de E1 |
| **Fig. 4** | Expone 10 emails reales | Se resuelve solo si se aplica B-7 (dominios `@example.com` desde el origen) |
| Paneles de Grafana | Los números contradicen las tablas | Recapturar todos contra la BD post-experimentos, **el mismo día**, y anotar la fecha de captura al pie |

**Control de consistencia obligatorio:** antes de dar por cerrado el Cap. 5, verificar hash de cada imagen (que no haya dos iguales) y que **todo número de una figura aparezca idéntico en la tabla correspondiente**. Es un check mecánico de 15 minutos que evita el hallazgo más embarazoso de la auditoría.

---

## 8. E6 — Paquete de reproducibilidad

La Tabla 3.1 promete un "Script SQL con DDL completo" como entregable que nunca se publica. Aprovechamos los experimentos para cumplirlo:

```
experiments/
├── README.md                      # cómo reproducir todo, paso a paso
├── baseline_real_previo.sql       # las 11 filas reales preservadas (B-4)
├── corpus_intents.csv             # 150 mensajes + ground truth (congelado antes de ejecutar)
├── run_flujo1_carga.ps1           # E1.a
├── run_flujo1_concurrencia.ps1    # E1.b
├── run_flujo2_corpus.ps1          # E2
├── queries_resultados.sql         # TODAS las queries del Cap. 5, ejecutables
└── resultados/
    ├── e1_ordenes.csv
    ├── e2_clasificaciones.csv
    └── e3_tmr_por_intent.csv
```

Con esto, la respuesta a "¿podemos reproducir sus resultados?" pasa a ser: *"clonen el repo y corran `experiments/README.md`"*. Es la diferencia entre un trabajo defendible y uno que hay que creer.

---

## 9. Orden de ejecución y dependencias

```
B-1 levantar entorno
 └─ B-2 backup íntegro          ⟵ sin esto no sigue nada
     └─ B-6 verificaciones pre-vuelo (5 checks)
         ├─ [DECISIÓN B-4] destino del seed
         │   └─ B-5 columna data_source  (requiere aprobación HIGH)
         │       └─ B-7 dominios reservados
         │
         ├─ E1  carga Flujo 1 ────────────┐   (10 min, sin costo)
         ├─ E1b concurrencia/atomicidad ──┤   (15 min, sin costo)
         │                                │
         ├─ E2  corpus chatbot ───────────┤   (media jornada de etiquetado + 10 min)
         │   └─ E3 TMR por intent ────────┤   (sale de E2, solo queries)
         │                                │
         └─ E4  baseline manual ──────────┤   (1 hora)
                                          │
                                          ▼
                                    E5 recaptura de figuras
                                          │
                                          ▼
                                    E6 paquete reproducible
                                          │
                                          ▼
                            ═══ recién acá: REDACCIÓN ═══
                              Bloques 2, 3 y 4 de la auditoría
```

**Paralelizable:** E1/E1b y el etiquetado de E2 pueden avanzar en simultáneo (el etiquetado es trabajo humano, la carga es máquina). E4 lo puede hacer una tercera persona en cualquier momento.

**Camino crítico:** el etiquetado ciego de E2. Es lo único que no se puede acelerar con más máquina.

---

## 10. Estimación

| Ítem | Máquina | Humano |
|---|---|---|
| B-1 … B-7 (preparación) | 20 min | 1 h |
| E1 + E1b | 25 min | — |
| E2 — construir corpus de 150 | — | 2 h |
| E2 — etiquetado ciego (×2 anotadores) | — | 3 h c/u |
| E2 — ejecución + cruce | 15 min | 30 min |
| E3 — queries | 5 min | 30 min |
| E4 — baseline manual | — | 1 h |
| E5 — recaptura + control de consistencia | — | 2 h |
| E6 — paquete reproducible | — | 2 h |
| **Total** | **~1 h** | **~15 h** (≈ 2 jornadas, repartibles entre 3 autores) |

Costo monetario: **≈ USD 0,05** (OpenAI).

---

## 11. Qué se gana

| Momento | Nota estimada |
|---|---|
| Hoy | **4,2** — "requiere revisión profunda antes de la defensa" |
| Con este plan ejecutado (Bloque 1) + redacción del Bloque 2 | **6,5 – 7,0** |
| Sumando Bloques 3 y 4 (estadística, modelado, bibliografía) | **7,5 – 8,0** |

Y algo que no entra en la nota pero pesa en la defensa: **cada número del Capítulo 5 va a tener detrás una fila que el sistema escribió y un script que cualquiera puede correr.** Si el tribunal pregunta "¿esto lo midieron ustedes?", la respuesta es sí, y se puede demostrar en vivo.

---

## 12. Decisiones que requieren aprobación explícita

Nivel de gobernanza **CRÍTICO** (integridad académica). Nada de esto se ejecuta sin respuesta:

### Resueltas (2026-08-09)

| # | Decisión | Resolución |
|---|---|---|
| **D-1** | Destino de los datos seed | ✅ **Opción A — BD limpia.** Se truncan las tablas transaccionales (previa preservación de las 11 filas reales en `experiments/baseline_real_previo.sql`) y se reporta exactamente lo que produzcan los experimentos. La serie diaria de §5.1 se reemplaza por un **histograma de distribución**. |
| **D-2** | Tamaño del corpus del chatbot | ✅ **n = 150.** Cruza el umbral de significancia (p ≈ 0,043 contra H₀ = 0,85) con un costo incremental de ~1 h de etiquetado por anotador respecto de 107. |
| **D-5** | Baseline de atención manual | ✅ **Medirlo.** Un operador procesa 10 órdenes a mano con cronómetro (leer pedido → verificar stock en BD → actualizar → redactar y enviar email). El denominador del factor 31,6x pasa a ser un dato propio. |

### Pendientes

| # | Decisión | Recomendación | Cuándo se resuelve |
|---|---|---|---|
| **D-3** | ¿Se agrega la columna `data_source`? (modifica el schema, gobernanza HIGH) | **Sí** | Antes de B-5 |
| **D-4** | Si la rama `no_stock` no escribe `notified_at`: ¿se agrega el nodo al workflow o se reporta la limitación? | **Agregar el nodo**, documentándolo como cambio de sistema | Después de la verificación B-6.1 |
| **D-6** | ¿Hay un anotador externo disponible para el ground truth ciego? | Deseable. Si no, dos autores etiquetando por separado y sin consultarse | Antes de arrancar E2 |

### Consecuencias de D-1 sobre la redacción (ver también §13)

Adoptar la BD limpia obliga a dos cambios de forma en el Cap. 5, que van anotados desde ahora para no descubrirlos tarde:

1. **La serie diaria desaparece.** Los datos reales serán de una o pocas jornadas. El panel de Grafana "resumen diario" y la figura correspondiente se reemplazan por un histograma de MTTD/MTTR con media, mediana y p95 marcados.
2. **`v_daily_order_summary` y `v_daily_chatbot_summary` pierden sentido como fuente de figuras** (van a devolver una sola fila). Siguen existiendo en el schema — son parte del entregable — pero el Cap. 5 deja de citarlas.

---

## 13. Resultados de B-1, B-2 y B-6 (ejecutado 2026-08-09)

### B-1 — Entorno ✅
Docker Desktop levantado. Los 4 contenedores subieron solos por su restart policy: `tesis_postgres` (healthy), `tesis_n8n`, `tesis_grafana`, `tesis_mailpit` (healthy).

Estado de los workflows en `workflow_entity`: las variantes SIMPLE de ambos flujos están **activas**; las dos PRODUCCION, inactivas. Es la configuración esperada.

### B-2 — Backup íntegro y verificado ✅
`backups/2026-08-09_15-19/` — `full_backup.sql` (337 KB), `tesis_data.sql` (53 KB), `n8n_workflows.csv` (4 workflows), `n8n_credentials.csv` (3 credenciales) y los 4 JSON del repo.

Verificado **por dentro**, no por el mensaje del script: products 20 · orders 34 · interactions 116 · tickets 33 · faq_responses 23. **Las 11 filas reales están en el dump** (ORD-DEMO-01, ORD-DEMO-02 y las 9 interactions con respuesta genuina de GPT). `backups/` está en `.gitignore:17` → las credenciales no se versionan.

> ⚠️ **n8n comparte la base `ecommerce_tesis` con las tablas de la tesis.** `full_backup.sql` contiene 72 tablas y vistas, incluidas `workflow_entity` y `credentials_entity`. Al ejecutar B-4, el `TRUNCATE` debe nombrar **exactamente** `tickets, interactions, orders` — un `CASCADE` mal apuntado puede llevarse los workflows y las credenciales.

### B-6 — Verificaciones pre-vuelo

| # | Verificación | Resultado |
|---|---|---|
| 1 | ¿La rama `no_stock` escribe `notified_at`? | ❌ **NO** |
| 2 | ¿Credencial de OpenAI configurada? | ✅ Sí |
| 3 | ¿`responded_at` es el timestamp real de fin? | ⚠️ Sí, con matices |
| 4 | ¿El endpoint es `/webhook/whatsapp`? | ✅ Sí — el Anexo E está mal |
| 5 | ¿El payload es de la WhatsApp Cloud API? | ❌ **NO** |
| 6 | *(no planificada)* Manejo de fallos de clasificación | ❌ **Sesga E2 hacia arriba** |

#### B-6.1 ❌ La rama `no_stock` no registra la notificación → **activa D-4**

Cadena real: `Marcar Sin Stock → Enviar Email Sin Stock → Respuesta Sin Stock`. No hay ningún nodo equivalente a `Registrar Notificación` (que sí existe en la rama con stock, con `UPDATE orders SET notified_at = NOW()`).

Confirmado contra la BD:

| status | filas | con `notified_at` | sin `notified_at` |
|---|---|---|---|
| confirmed | 13 | 13 | 0 |
| delivered | 7 | 7 | 0 |
| **no_stock** | **9** | **8** | **1** |
| shipped | 5 | 5 | 0 |

Las 8 filas `no_stock` que tienen `notified_at` son **seed**. La única orden `no_stock` real —`ORD-DEMO-02`— lo tiene **vacío**.

**Agravante silencioso:** `v_metrics_summary` calcula el MTTR con `WHERE notified_at IS NOT NULL`. Con la BD limpia, eso **excluye sin avisar todas las órdenes sin stock**, y el MTTR queda medido solo sobre la rama feliz. El promedio saldría igual, pero sobre una muestra sesgada — y nadie lo notaría mirando el número.

Además, `Respuesta Sin Stock` le devuelve al cliente `"Se notificó al cliente"`, una afirmación que ninguna fila respalda.

**Confirma la recomendación de D-4: agregar el nodo.** Es un nodo Postgres de una línea, idéntico al que ya existe en la otra rama. Sin él, E1 mide la mitad del pipeline.

#### B-6.2 ✅ OpenAI configurado
Las 3 credenciales existen en `credentials_entity`: SMTP (128 B), Postgres (152 B) y **OpenAi account (280 B)**. El nodo `OpenAI Chat Model` apunta a `gpt-4o-mini` y referencia esa credencial. E2 puede correr.

#### B-6.3 ⚠️ El TMR mide de verdad, pero hay que declarar el límite

- `received_at` ← `new Date().toISOString()` dentro del nodo `Normalizar Mensaje` (reloj de n8n, UTC).
- `responded_at` ← `NOW()` de PostgreSQL en `Registrar Interacción`, que corre **después** de enviar la respuesta.

**Relojes verificados en sincronía:** Postgres en UTC y `date -u` de n8n coinciden al segundo. Los TMR reales son coherentes (2,06 – 8,46 s).

**Definición a escribir en §5.2.1:** el TMR va desde la normalización del mensaje dentro de n8n hasta después de despachar la respuesta. **No** incluye la latencia de red del cliente al webhook ni la entrega final en el canal.

> ⚠️ **Trampa latente:** el contenedor de n8n corre con `GENERIC_TIMEZONE=America/Argentina/Mendoza`. `new Date().toISOString()` devuelve UTC y por eso hoy funciona. Si alguien reemplaza esa expresión por el `$now` de n8n (Luxon, que sí respeta `GENERIC_TIMEZONE`), el `received_at` entra con hora de Mendoza contra un `NOW()` en UTC: **TMR desviado 3 horas**. No tocar ese nodo.

#### B-6.4 ✅ El endpoint es `/webhook/whatsapp`
`path: "whatsapp"`. El **Anexo E de la tesis apunta a `/webhook/chatbot-whatsapp` y no reproduce**. Corregir en la fase de redacción.

#### B-6.5 ❌ El payload NO es el de la WhatsApp Cloud API

`Normalizar Mensaje` lee campos planos:

```js
const data = $json.body || $json;
user:    data.user_id || data.from || data.phone || data.user || 'unknown',
message: data.message || data.text || '',
canal:   'whatsapp',
```

Espera `{user_id, name, message}`, **no** `entry[].changes[].value.messages[]`. Dos documentos lo describen mal: el Anexo E de la tesis y el `CLAUDE.md` del repo. Los scripts de E2 deben usar el payload plano real.

**Y algo más para C-01:** `canal` está **hardcodeado** a `'whatsapp'`. El canal no se detecta — es una constante. Es la evidencia más dura de que el sistema es monocanal, y conviene citarla textualmente al declarar el alcance.

#### B-6.6 ❌ *(hallazgo no planificado)* El manejo de errores infla el accuracy

`Parse JSON` traga los fallos de dos maneras, y **las dos empujan el accuracy hacia arriba**:

```js
intent: data.intent || 'GENERAL',      // etiqueta fuera de vocabulario: pasa tal cual
// ...
catch (e) { return [{ intent: 'GENERAL', /* respuesta enlatada */ }] }
```

1. **Etiqueta fuera de vocabulario → la fila se pierde.** Si el modelo devuelve, por ejemplo, `"CONSULTA"`, el valor viaja hasta el `INSERT`, que **viola el `CHECK (intent IN (...))`** de `interactions`. La fila nunca se escribe. Esos casos —justamente los peores del modelo— **desaparecen del denominador** y el accuracy sube solo.
2. **Fallo de parseo → se registra como `GENERAL`.** Un error técnico queda indistinguible de una clasificación. Y si el ground truth de ese mensaje era `GENERAL`, **se contabiliza como acierto**.

**Protocolo obligatorio para E2 (sin esto, el accuracy no vale):**
- Conciliar **150 mensajes enviados contra filas efectivamente escritas**. Si faltan, hay que explicar cada una — nunca ignorarlas.
- Capturar la salida cruda del LLM por mensaje (log de ejecuciones de n8n) para poder clasificar cada caso perdido.
- Reportar los fallos de parseo como **categoría propia**, jamás como acierto.
- Informar el accuracy sobre los **150 enviados**, no sobre los registrados.

#### B-6.7 📉 Dato incómodo: el TMR real es peor que el que declara la tesis

Las 9 interacciones reales dan **TMR promedio ≈ 3,80 s** (rango 2,06 – 8,46; el 8,46 es un arranque en frío). La tesis declara **2,47 s**, tomado del seed.

Las mediciones honestas van a dar **~54% peor que lo publicado**. No cambia ninguna conclusión —3,8 s sigue siendo excelente frente a cualquier baseline manual— pero conviene saberlo ahora y no cuando haya que reescribir §5.2.1 de apuro. El factor de mejora del §5.4 se recalcula con el número real.

*(n = 9, y una de esas filas —la #108— tiene el `message` vacío: es una prueba degenerada. Las interacciones reales utilizables como evidencia son **8, no 9**.)*

### Estado tras B-6

| Bloqueante | Estado |
|---|---|
| B-1 entorno | ✅ |
| B-2 backup | ✅ verificado |
| B-3 congelar `seed_expand.sql` | ⏳ pendiente |
| B-4 truncar (decidido: Opción A) | ⏳ pendiente — **requiere aprobación puntual** |
| B-5 columna `data_source` | ⏳ pendiente — **D-3** |
| B-6 pre-vuelo | ✅ 5 verificaciones + 2 hallazgos nuevos |
| B-7 dominios reservados | ⏳ se aplica al escribir los scripts de E1 |

**Se agregan al trabajo, por lo encontrado en B-6:**
- **D-4 resuelto de hecho:** hay que agregar el nodo `Registrar Notificación Sin Stock` al Flujo 1. Es un cambio del sistema construido y se documenta como tal.
- **Nuevo requisito para E2:** el protocolo de conciliación de B-6.6 es condición para que el accuracy sea publicable.

---

## 14. Ejecución — resultados reales (2026-08-10)

### 14.1 D-4 aplicado — el Flujo 1 pasó de 12 a 13 nodos

Se agregó el nodo Postgres `Registrar Notificación Sin Stock`. Cableado verificado leyendo `connections` de `workflow_entity`:

```
Marcar Sin Stock → Enviar Email Sin Stock → Registrar Notificación Sin Stock → Respuesta Sin Stock
```

Prueba puntual `ORD-VERIF-D4` (PROD-014 ×999) → `status = no_stock`, `notified_at` cargado, `mttr_seg = 0,074`.

> **Para la redacción:** la tesis declara **12 nodos** en el Flujo 1. Hay que actualizar el conteo a **13** y declarar el cambio como modificación del sistema construido, con su justificación (B-6.1).

### 14.2 E1.a — carga secuencial, n = 50 ✅

50/50 requests HTTP OK. **35 confirmed / 15 no_stock**, exactamente la distribución planificada.

| Métrica | media | mediana | desvío | mín | máx | p95 | IC 95% |
|---|---|---|---|---|---|---|---|
| **MTTD** | 0,009 | 0,009 | 0,003 | 0,005 | 0,023 | 0,011 | [0,008; 0,009] |
| **MTTR** | 0,054 | 0,054 | 0,003 | 0,051 | 0,072 | 0,056 | [0,053; 0,055] |
| **E2E** | 0,063 | 0,062 | 0,005 | 0,057 | 0,095 | 0,066 | [0,061; 0,064] |

*(segundos, n = 50)*

**Controles de integridad:**
- Cobertura de `notified_at`: **100% en ambas ramas** (35/35 con stock, 15/15 sin stock). Antes de D-4 la rama sin stock daba 0%.
- `data_source`: **170 measured, 0 synthetic**. Ninguna fila seed contamina la muestra.
- **Cold start** visible y esperado: `ORD-E1A-001` es el máximo en MTTD (0,023) y E2E (0,095). **Se reporta y se justifica, no se borra.**

> ⚠️ **Estos números son ~150 veces menores que los publicados en la v5** (que declaraba MTTD 1,79 s, MTTR 7,69 s, E2E 9,48 s). No es una mejora del sistema: los valores de la v5 eran `INTERVAL` hardcodeados en el seed. Los reales son de un pipeline local sin APIs externas. **El factor de mejora de §5.4 hay que recalcularlo entero**, y el denominador sale de E4.

### 14.3 E1.b — concurrencia: **cierra A-08 con un hallazgo propio** ✅

6 rondas (2 corridas × 3) de 20 requests simultáneas contra un producto con `stock = 5`.

**No hay sobreventa.** Exactamente 5 confirmadas por ronda, stock final 0, nunca negativo. El `CHECK (stock >= 0)` de `init_simple.sql` es el control que funcionó.

**Pero la condición de carrera está confirmada, y se manifiesta de otra manera:**

> **49 de 120 órdenes (~40%) quedaron huérfanas en `pending`**, con `processed_at` y `notified_at` en NULL.

**Mecanismo, con evidencia dura.** `execution_entity` registra 23 ejecuciones en `error` en la primera corrida — exactamente las 23 `pending` de esa corrida. El error es `violates check constraint "products_stock_check"` en el nodo `Actualizar Stock`.

`Verificar Stock` (SELECT) y `Actualizar Stock` (UPDATE) son **dos statements separados sin bloqueo**. Todas las ejecuciones concurrentes leen `stock > 0`; las que llegan tarde al UPDATE violan el CHECK, **la ejecución aborta, y la orden queda registrada pero sin procesar, sin email y sin respuesta al cliente.**

**El agravante que importa académicamente:** como esas filas tienen `processed_at` NULL, ni `v_order_processing_time` ni `v_metrics_summary` las ven. **El fallo es invisible en el tablero de Grafana.** Las métricas se calculan solo sobre las que sobrevivieron. Es exactamente el tipo de sesgo silencioso que la auditoría vino a buscar, y lo encontramos nosotros primero.

**Ventana de simultaneidad medida:** 0,43 – 22,81 ms entre el primer y el último disparo (el 22,81 es el warm-up del HttpClient). Es el límite honesto de lo que podemos llamar "simultáneo".

**Mitigaciones a discutir en la tesis** (no implementadas — se documenta el hallazgo):

1. `SELECT ... FOR UPDATE` sobre la fila del producto.
2. UPDATE condicional `WHERE stock >= n`, verificando filas afectadas.
3. Manejo de error en el nodo, para que la orden termine en `failed` en vez de quedar huérfana.

**Un hallazgo negativo bien medido vale más que un número lindo inventado.** Esto le da al Cap. 5 algo que la v5 no tenía: un límite real del sistema, medido, reproducible y con mitigación propuesta.

#### Lección metodológica sobre el instrumental

La primera versión de `run_flujo1_concurrencia.ps1` **declaró "Atomicidad OK" y tapó el hallazgo**: su `invariante_ok` solo verificaba sobreventa, la hipótesis obvia. Corregido para exigir además `otros_estados = 0` y `huerfanas_pending = 0`, con columnas propias para huérfanas y ejecuciones en error, y un veredicto dedicado para "condición de carrera sin sobreventa".

> **Un veredicto automático que solo chequea la hipótesis esperada puede esconder el resultado real.** Vale la pena decirlo en la tesis: es un aprendizaje sobre el diseño del instrumento de medición.

*Salvedad conocida:* la columna `ejecuciones_error` cuenta errores de los últimos 3 minutos sin filtrar por corrida, así que arrastra los de corridas previas. La confiable es `huerfanas_pending`, que sí filtra por prefijo.

### 14.4 D-6 resuelta — **un solo anotador**

El plan §4.2 asumía dos anotadores (dos de los tres autores) y **κ de Cohen** entre ellos. El trabajo lo está haciendo **una sola persona**.

| Plan original | Ejecución real |
|---|---|
| 2 anotadores independientes | 1 anotador |
| κ de Cohen (inter-anotador) | **Concordancia intra-anotador (test-retest)** sobre 50 mensajes re-etiquetados en orden aleatorizado, idealmente al día siguiente |
| Anotador externo deseable | No disponible |

**Esto no invalida E2.** A-04 no reprocha la cantidad de anotadores: reprocha que **no existiera ground truth alguno**. Un corpus congelado antes de ejecutarse y etiquetado a ciegas por un humano lo resuelve. Se pierde la métrica de confiabilidad del etiquetado y se reemplaza por una más débil pero real.

**Redacción obligatoria en §5.2:**

> El etiquetado del corpus fue realizado por un único anotador. En consecuencia se reporta concordancia intra-anotador (test-retest) en lugar del κ de Cohen inter-anotador, lo cual constituye una limitación de validez declarada de este trabajo.

**Separación entre autoría del corpus y etiquetado.** Si la misma persona redacta el mensaje y le pone la etiqueta, escribir el corpus **ya es etiquetarlo** y el ground truth sale inflado. Por eso el corpus lo redactó un asistente de IA a partir de los mensajes de `seed_expand.sql` más casos de frontera, **las intenciones previstas al redactarlo no se persistieron en ningún archivo** (no existe clave de respuestas), y el anotador no participó de la redacción. Que el redactor sea un LLM es una limitación a declarar: no contamina el ground truth —que es humano— pero puede sesgar la dificultad del corpus.

**Estado de E2:** corpus de 150 congelado y commiteado (`e380553`) **antes** de etiquetar. Falta la ronda 1 (150) y la ronda 2 (50 de control).

> **Control de validez antes de aceptar cualquier etiquetado** — quedó probado que hace falta: (1) mediana de segundos por mensaje (por debajo de ~3 s es sospechoso), (2) spot-check contra 10 casos evidentes del corpus, (3) distribución (si sale uniforme 25/25/25/25, revisar).

### 14.5 Estado de los bloqueantes

| Bloqueante | Estado |
|---|---|
| B-1 entorno | ✅ |
| B-2 backup | ✅ verificado por dentro |
| B-3 congelar `seed_expand.sql` | ✅ cabecera de archivo congelado + `seed_catalogo.sql` |
| B-4 truncar (Opción A) | ✅ |
| B-5 columna `data_source` | ✅ en `orders`, `interactions` y `tickets` |
| B-6 pre-vuelo | ✅ 5 verificaciones + 2 hallazgos nuevos |
| B-7 dominios reservados | ✅ aplicado en E1 y en el corpus de E2 |

### 14.6 Qué queda

| # | Tarea | Depende de |
|---|---|---|
| 1 | **Etiquetar el corpus de E2** — ronda 1 (150) + ronda 2 (50) | Trabajo humano, ~40 min + ~15 min |
| 2 | Ejecutar E2 contra `/webhook/whatsapp` y conciliar (B-6.6) | Ronda 1 |
| 3 | E3 — TMR por intent con `GROUP BY` | E2 |
| 4 | E4 — baseline manual con cronómetro | Independiente, 1 h |
| 5 | E5 — recaptura de figuras + control de hashes | E1-E4 cerrados |
| 6 | E6 — paquete de reproducibilidad | Todo lo anterior |
| 7 | Redacción — Bloques 2, 3 y 4 de la auditoría | Todo lo anterior |
