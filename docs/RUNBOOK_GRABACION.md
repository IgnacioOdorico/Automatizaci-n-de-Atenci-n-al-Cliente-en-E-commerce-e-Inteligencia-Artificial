# 🎥 RUNBOOK de grabación — Bloques de Santiago (B5 y B6)

Libreto de acciones para grabar las dos demos en vivo. Seguilo de arriba a abajo.
Tus bloques concentran el **45% de la nota** (Metodología + Desarrollo + Resultados). Hacelo tranquilo.

---

## ✅ PRE-VUELO (hacer ANTES de apretar REC)

- [ ] `docker compose ps` → 4 contenedores **Up/healthy**.
- [ ] **OpenAI con crédito** cargado y el chatbot **probado 1 vez** (que clasifique OK).
- [ ] **Flujo 1 y Flujo 2 ACTIVOS y PUBLICADOS** en n8n (toggle Active + Publish).
- [ ] **Mailpit vacío** → http://localhost:8025 → borrar inbox.
- [ ] **Grafana** → los 2 dashboards abiertos, rango **"Last 30 days"**, con datos visibles.
- [ ] Comandos PowerShell **en un `.txt` al lado** para copiar/pegar (NO tipear en vivo).
- [ ] Silenciar teléfono, cerrar notificaciones, Slack, mail. Buen micrófono.
- [ ] Pestañas abiertas y ordenadas, en este orden:
  1. n8n → canvas **Flujo 1**
  2. n8n → canvas **Flujo 2**
  3. Mailpit (8025)
  4. Grafana **Dashboard 1 — Pipeline** (`/d/tesis-flujo1`)
  5. Grafana **Dashboard 2 — Chatbot** (`/d/tesis-flujo2`)
  6. Terminal **PowerShell**

> ⚠️ Las capturas del doc ya están sacadas en estado limpio (32/107). Cuando dispares las demos, Grafana va a mostrar 34 órdenes / 109 interacciones. **Eso está BIEN** — narralo: *"ahí se sumaron las que acabo de crear, es en vivo"*.

---

## 🟢 BLOQUE 5 — Metodología / Demo de los flujos (4:30 – 6:30)

### Paso 1 — Mostrar el Flujo 1 en n8n
🖥️ **Pantalla:** canvas del Flujo 1.
🗣️ *"Este es el pipeline de órdenes: 11 nodos. Entra el webhook, registra la orden, verifica stock y se abre en dos ramas. Lo disparo en vivo."*

### Paso 2 — Orden CON stock
🖥️ **Pantalla:** terminal. Pegá y ejecutá:
```powershell
Invoke-RestMethod -Uri "http://localhost:5678/webhook/orden-nueva" -Method POST `
  -ContentType "application/json" `
  -Body '{"order_number":"ORD-DEMO-01","customer_name":"Cliente Demo","customer_email":"demo@cliente.com","customer_phone":"5492610000000","product_sku":"PROD-002","quantity":1}'
```
🗣️ *"El webhook respondió en menos de un segundo. Voy a la base de datos a confirmar."*

### Paso 3 — Verificar la orden en la BD
```powershell
docker exec tesis_postgres psql -U n8n_user -d ecommerce_tesis -c "SELECT order_number, status, received_at, processed_at, notified_at FROM orders WHERE order_number='ORD-DEMO-01';"
```
🗣️ *"Orden confirmada, con los tres timestamps. Esa diferencia de tiempos es el instrumento con el que medimos MTTD y MTTR."*

### Paso 4 — Mostrar el email
🖥️ **Pantalla:** cambiar a Mailpit (8025).
🗣️ *"Y el correo de confirmación llegó automáticamente. Ahora la otra rama: sin stock."*

### Paso 5 — Orden SIN stock
🖥️ **Pantalla:** terminal.
```powershell
Invoke-RestMethod -Uri "http://localhost:5678/webhook/orden-nueva" -Method POST `
  -ContentType "application/json" `
  -Body '{"order_number":"ORD-DEMO-02","customer_name":"Cliente Demo","customer_email":"demo@cliente.com","customer_phone":"5492610000000","product_sku":"PROD-001","quantity":9999}'
```
🗣️ *"Pedí más unidades de las que hay. El sistema detectó la falta de stock, marcó la orden como no_stock y avisó, sin intervención humana."*

> 🎥 **FLUJO DE LA DEMO DEL CHATBOT (Postman → canvas en vivo → Mailpit)**
> Para que el canvas se ANIME en vivo, usá el **modo escucha**: en n8n clic en **"Execute workflow"** (Listen for test event).
> En ese modo el webhook es **`/webhook-test/whatsapp`** (con `-test-`) y sirve para **UN envío**: volvés a clickear "Execute workflow" antes de cada mensaje.
> El webhook devuelve `{"message":"Workflow was started"}`; la respuesta de la IA aparece en el **canvas** (nodos) y en **Mailpit**.

### Paso 6 — Poner el chatbot "en escucha"
🖥️ **Pantalla:** canvas del Flujo 2 → clic en **"Execute workflow"** (queda escuchando, se va a animar).
🗣️ *"Este es el chatbot. Le voy a mandar una consulta de estado de pedido —donde se ve la integración con el Flujo 1."*

### Paso 7 — Enviar desde Postman (ESTADO_PEDIDO)
🖥️ **Pantalla:** Postman → POST `http://localhost:5678/webhook-test/whatsapp` → Body raw JSON:
```json
{"message":"Hola, queria saber el estado de mi pedido ORD-DEMO-01","from":"5492611234567","name":"Cliente Demo"}
```
🗣️ *"Mando la consulta desde Postman..."*

### Paso 8 — Mostrar el canvas ejecutándose
🖥️ **Pantalla:** volvé al canvas de n8n → los nodos se ponen verdes en vivo (Normalizar → Buscar FAQ → OpenAI Chat Model → Switch Intent → Buscar Pedido → Registrar). Clic en el nodo de la IA para mostrar el **intent clasificado**.
🗣️ *"GPT-4o-mini clasificó el mensaje como consulta de estado, buscó la orden en la MISMA base que escribió el Flujo 1, y generó la respuesta. Los dos flujos integrados."*

### Paso 9 — Mostrar la respuesta final en Mailpit
🖥️ **Pantalla:** Mailpit (http://localhost:8025) → abrí el email **"Respuesta TechStore..."** → mostrá la respuesta generada por la IA.
🗣️ *"Y esta es la respuesta que recibe el cliente, generada y enviada automáticamente. Cada interacción queda registrada con su intent y sus timestamps, que alimentan el TMR. Vamos a Grafana."*

> **Opcional (2º mensaje, ej. FAQ):** repetí el ciclo → "Execute workflow" → Postman con
> `{"message":"Cuales son los medios de pago que aceptan?","from":"5492611234567","name":"Cliente Demo"}` → canvas → Mailpit.

---

## 🟢 BLOQUE 6 — Resultados / Grafana (6:30 – 8:00)

### Paso 1 — Dashboard 1: Pipeline (Flujo 1)
🖥️ **Pantalla:** Grafana → `/d/tesis-flujo1`.
🗣️ *"Estos son los resultados sobre datos reales. MTTD de 1,79 segundos, MTTR de 7,69, y end-to-end de 9,48 segundos —muy por debajo de los 30 que nos propusimos, y de los 5 a 30 minutos del proceso manual. La prueba de carga fue de 20 órdenes concurrentes, cero errores. En la torta ven la distribución de estados."*

**Interpretá, no leas.** Cada número con su "esto significa...".

### Paso 2 — Dashboard 2: Chatbot (Flujo 2)
🖥️ **Pantalla:** Grafana → `/d/tesis-flujo2`.
🗣️ *"Para el chatbot: un TMR promedio de 2,47 segundos sobre 107 interacciones —el más lento es estado de pedido, con 2,83, porque consulta la base—. Y una precisión de clasificación del 90,7%. En la torta, la distribución de intents. Estos paneles se actualizan con cada mensaje, como los que disparé recién."*

🗣️ **Cierre del bloque:** *"Con esto les paso a Ignacio y Juan Cruz para las conclusiones."*

---

## 🎬 Reglas de oro de la grabación

1. **Ensayo en seco primero.** Corré TODOS los comandos una vez antes de la toma buena. Nunca grabes la primera corrida.
2. Si un comando falla en vivo: **no entres en pánico.** Tené un segundo intento o una captura de respaldo.
3. **Narrá lo que hace el mouse.** No te quedes en silencio esperando.
4. Grafana mostrará 34/109 tras las demos → **narralo como algo bueno** (es en vivo).
5. **Audio > video.** Un buen micrófono salva todo.
