# E2 — Corpus del chatbot por el pipeline real

Cierra los hallazgos **C-04**, **A-04** y sostiene **H2b**. Es el experimento de mayor rendimiento académico del Bloque 1 y el camino crítico del plan.

Ver `docs/PLAN_REGENERACION_EVIDENCIA.md` §4.

---

## Qué problema resuelve

El accuracy de 90,7% que declara §5.2.2 de la tesis **no está medido contra nada**. Las etiquetas de `intent` de las 107 interacciones están escritas a mano en el `INSERT` de `seed_expand.sql:153+`. GPT-4o-mini nunca clasificó esos mensajes y no existe ningún ground truth independiente.

E2 construye ese ground truth y mide contra él.

---

## Desvío respecto del plan original: un solo anotador

El plan §4.2 asumía **dos anotadores** (dos de los tres autores) y **κ de Cohen** entre ellos. El trabajo lo está haciendo **una sola persona**, así que la concordancia entre anotadores no es medible.

**Qué se hace en su lugar:**

| Plan original | Ejecución real |
|---|---|
| 2 anotadores independientes | 1 anotador |
| κ de Cohen (inter-anotador) | **Concordancia intra-anotador (test-retest)** sobre 50 mensajes re-etiquetados en orden aleatorizado |
| Anotador externo deseable | No disponible |

**Esto no invalida el experimento.** El hallazgo A-04 no reprocha la cantidad de anotadores: reprocha que no existiera ground truth alguno. Un corpus congelado antes de ejecutarse y etiquetado a ciegas por un humano lo resuelve. Lo que se pierde es la métrica de confiabilidad del etiquetado, y se reemplaza por una más débil pero real.

**Va declarado textualmente en §5.2**, no insinuado:

> El etiquetado del corpus fue realizado por un único anotador. En consecuencia se reporta concordancia intra-anotador (test-retest) en lugar del κ de Cohen inter-anotador, lo cual constituye una limitación de validez declarada de este trabajo.

---

## Separación entre autoría del corpus y etiquetado

Hay una trampa metodológica que el corpus original tenía y que acá se evita: **si la misma persona redacta el mensaje y le pone la etiqueta, escribir el corpus ya es etiquetarlo**. El ground truth sale inflado y nadie lo nota.

Por eso:

- **El corpus lo redactó un asistente de IA (Claude)** partiendo de los mensajes de `seed_expand.sql` (verosímiles, escritos por el equipo) y ampliándolos con casos de frontera.
- **Las intenciones previstas al redactarlo NO se persistieron en ningún archivo.** No existe una "clave de respuestas". El único ground truth es la columna que produce el anotador humano.
- **El anotador no participó en la redacción.**

Que el redactor del corpus sea un LLM es una limitación a declarar. No contamina el ground truth —que es humano— pero sí puede sesgar la *dificultad* del corpus. Por eso se incluyeron casos ambiguos deliberados (ver abajo).

---

## El corpus

`corpus_intents.csv` — **150 mensajes**, español rioplatense, columnas `id,user_id,mensaje`. **Sin columna de etiqueta.**

- **n = 150** por decisión D-2: cruza el umbral de significancia (p ≈ 0,043 contra H₀ = 0,85). Con n = 107 el test da p ≈ 0,060 — no significativo, exactamente el reproche ya recibido.
- `user_id` son números sintéticos secuenciales (`549261000XXXX`), inválidos como celulares reales.
- Los emails dentro de los mensajes usan `@example.com` (RFC 2606), por B-7.
- Incluye **casos ambiguos y de frontera** a propósito (mensajes que mezclan consulta general con reclamo, o estado de pedido con FAQ). Un corpus donde todo es obvio infla el accuracy artificialmente.

> ⚠️ **El corpus se commitea ANTES de etiquetar y ANTES de ejecutar.** La marca de tiempo de git es la prueba de que no se ajustó a posteriori. No lo edites después.

### Las cuatro categorías

Son las del `CHECK` de `interactions` en `init_simple.sql:76`:

| Intent | Criterio |
|---|---|
| `FAQ` | Pregunta general sobre la tienda: envíos, pagos, garantía, políticas, horarios |
| `ESTADO_PEDIDO` | Pregunta por **su** compra concreta: dónde está, cuándo llega, tracking |
| `RECLAMO` | Algo salió mal; se queja o exige una solución |
| `GENERAL` | Saludo, agradecimiento, charla, o nada clasificable en las anteriores |

---

## Protocolo de etiquetado

### Ronda 1 — los 150

1. Abrí `etiquetar.html` en el navegador (doble clic, no necesita servidor).
2. Elegí `corpus_intents.csv`.
3. Botón **"Ronda 1 — los 150"**.
4. Teclas `1` `2` `3` `4`. `←` o `Backspace` corrige el anterior.
5. Al terminar, **Descargar CSV** → guardalo acá como `etiquetas_ronda1.csv`.

Va a tardar unos 40 minutos. Se guarda solo en el navegador mientras avanzás: si cerrás la pestaña, retomás donde ibas.

**Regla dura: no mires la salida del modelo antes de terminar.** Ni las ejecuciones de n8n, ni la tabla `interactions`. Si la mirás, el ground truth deja de ser ciego y el experimento se cae.

### Ronda 2 — control de 50 (test-retest)

**Idealmente al día siguiente.** Cuanto más tiempo pase, más genuina es la medición: si re-etiquetás a los 10 minutos estás recordando tu respuesta, no re-juzgando el mensaje.

1. Misma herramienta, mismo CSV, botón **"Ronda 2 — control de 50 al azar"**.
2. La herramienta toma 50 al azar y los presenta en orden aleatorizado.
3. Guardá como `etiquetas_ronda2.csv`.

De ahí sale el κ intra-anotador.

### Ronda 3 — ejecución (esto lo corre la máquina)

Recién con las dos rondas cerradas se envía el corpus a `POST /webhook/whatsapp` y se compara.

---

## Payload — ojo con esto

El Anexo E de la tesis y el `CLAUDE.md` del repo **describen mal el payload**. Dicen que es la estructura de la WhatsApp Cloud API (`entry[].changes[].value.messages[]`). No lo es.

`Normalizar Mensaje` lee campos planos (verificado en B-6.5):

```json
{ "user_id": "5492610000001", "name": "...", "message": "hola" }
```

Y `canal` está **hardcodeado** a `'whatsapp'` — no se detecta. Es la evidencia más dura de que el sistema es monocanal (C-01).

Endpoint real: `/webhook/whatsapp` (el Anexo E dice `/webhook/chatbot-whatsapp` y **no reproduce**).

---

## Conciliación obligatoria (hallazgo B-6.6)

Sin esto el accuracy no es publicable. `Parse JSON` traga los fallos de dos maneras y **las dos empujan el accuracy hacia arriba**:

1. **Etiqueta fuera de vocabulario → la fila se pierde.** Si el modelo devuelve `"CONSULTA"`, el `INSERT` viola el `CHECK (intent IN (...))` y la fila nunca se escribe. Esos casos —los peores del modelo— **desaparecen del denominador**.
2. **Fallo de parseo → se registra como `GENERAL`.** Un error técnico queda indistinguible de una clasificación, y si el ground truth era `GENERAL`, **se cuenta como acierto**.

Por lo tanto:

- Conciliar **150 enviados contra filas efectivamente escritas**. Si faltan, explicar cada una. Nunca ignorarlas.
- Capturar la salida cruda del LLM por mensaje (log de ejecuciones de n8n).
- Los fallos de parseo se reportan como **categoría propia**, jamás como acierto.
- **El accuracy se informa sobre los 150 enviados**, no sobre los registrados.

---

## Métricas a extraer

- Accuracy global con **IC de Wilson** al 95% (el intervalo normal se rompe con proporciones cercanas a 1).
- **Matriz de confusión 4×4** — la tesis nunca la presentó y es el estándar del área.
- **Precision, recall y F1 por intent.** El global esconde que `ESTADO_PEDIDO` puede ser el más débil.
- **Test binomial exacto de una cola** contra H₀: p = 0,85, con el p-valor explícito.
- **κ intra-anotador** (ronda 1 vs ronda 2 sobre los 50).
- **E3** sale de los mismos datos: TMR por intent con `GROUP BY` (cierra A-05).

---

## Limitación de alcance — se declara, no se insinúa

Los 150 mensajes entran **todos por WhatsApp**. El experimento mide **clasificación de intents**, no omnicanalidad. El workflow tiene un solo trigger y `canal` es una constante.

---

## Archivos

```
experiments/E2/
├── README.md                 # esto
├── corpus_intents.csv        # 150 mensajes SIN etiqueta — congelado en git
├── etiquetar.html            # herramienta de etiquetado (offline, sin dependencias)
├── etiquetas_ronda1.csv      # ← lo generás vos (150)
└── etiquetas_ronda2.csv      # ← lo generás vos (50 de control)
```

## Estado

- [x] Corpus construido (150, sin etiquetas)
- [x] Herramienta de etiquetado
- [ ] Commit del corpus **antes de etiquetar**
- [ ] Ronda 1 — 150 etiquetas
- [ ] Ronda 2 — 50 de control
- [ ] Script de ejecución contra `/webhook/whatsapp`
- [ ] Análisis: accuracy, Wilson, matriz de confusión, F1, binomial, κ
