# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es este proyecto

Trabajo Final de Grado (UTN FRM 2026) — sistema de automatización del ciclo post-venta de un e-commerce, **orquestado con n8n**. No es un codebase tradicional: **no hay build, no hay `npm install`, no hay test runner**. La lógica de negocio vive dentro de n8n, exportada como **workflows JSON** en `workflows/`. Lo que se versiona en este repo es:

- **Workflows n8n** (`workflows/*.json`) — la lógica real, se importa desde la UI de n8n.
- **Schema SQL** (`init_simple.sql`, `seed_expand.sql`) — tablas, vistas de métricas y datos seed.
- **Infra** (`docker-compose.yml`) — levanta los 4 servicios.
- **Scripts de operación** (`backup.ps1`, `restore.ps1`) — PowerShell.
- **Docs** (`docs/`) — specs técnicas y la tesis.

Idioma del proyecto: español rioplatense (voseo). Mantenerlo en todo lo que se escriba.

## Arquitectura — dos flujos sobre una BD compartida

Todo corre en n8n (`tesis_n8n`) contra una única PostgreSQL (`ecommerce_tesis`). Ambos flujos comparten la misma BD, y ahí está el acoplamiento clave entre ellos:

**Flujo 1 — Pipeline de Órdenes** (`POST /webhook/orden-nueva`): webhook → registra orden → verifica stock → rama con stock (descuenta, confirma, email de confirmación) o sin stock (marca `no_stock`, email de aviso) → responde al webhook. Captura timestamps `received_at`/`processed_at`/`notified_at` en `orders` para calcular **MTTD** y **MTTR**.

**Flujo 2 — Chatbot Omnicanal IA** (triggers WhatsApp `/webhook/whatsapp`, Telegram, Gmail poll): normaliza el mensaje → inyecta FAQ como contexto → GPT-4o-mini clasifica intent (`FAQ`/`ESTADO_PEDIDO`/`RECLAMO`/`GENERAL`) y genera respuesta → enruta por intent (busca en `orders` o crea `ticket`) → responde por el mismo canal → registra en `interactions`. Captura `received_at`/`responded_at` para el **TMR**.

**Punto de unión:** cuando el chatbot recibe `ESTADO_PEDIDO`, consulta la tabla `orders` que escribe el Flujo 1. Una métrica (MTTD/MTTR/TMR) es el eje de la tesis y se visualiza en Grafana sobre las 5 vistas `v_*`.

## Variantes SIMPLE vs PRODUCCION

Cada flujo tiene dos archivos JSON:

- **SIMPLE / (sin sufijo)** — para demo local. Usa Mailpit como SMTP, sin APIs externas reales. **Son los que se activan** para presentar.
- **PRODUCCION** — usa OpenAI real, WhatsApp Business Cloud API, Telegram Bot, Gmail OAuth. Se importan pero **se dejan inactivos** (tienen placeholders como `PHONE_ID`, `TU_CHAT_ID` que hay que configurar).

Al editar lógica de un flujo, verificá si el cambio aplica a una variante o a ambas.

## Gotcha crítico: las specs describen un schema más rico que el desplegado

`docs/SPEC_FLUJO1_*.md` y `SPEC_FLUJO2_*.md` referencian columnas y tablas que **NO existen en el schema activo** (`init_simple.sql`):

| Las specs asumen | La realidad en `init_simple.sql` |
|---|---|
| Tabla `pipeline_events` (bitácora de eventos) | **No existe** |
| `orders.raw_payload`, `*.metadata` (JSONB) | **No existen** |
| `TIMESTAMPTZ` | Es `TIMESTAMP` (sin tz) |
| Índices, extensiones, COMMENTs | No están |

`init_simple.sql` es la versión simplificada para la demo (lo dice su cabecera). Es la que monta `docker-compose.yml` (`/docker-entrypoint-initdb.d/01_init.sql`). El `init.sql` del README **ya no existe como archivo** (quedó un directorio vacío). **Antes de tocar SQL o un nodo que escriba a la BD, mirá `init_simple.sql`, no la spec** — si seguís la spec vas a referenciar `pipeline_events` y va a explotar.

## Conexiones dentro de Docker

n8n se comunica con los otros servicios por **nombre de servicio Docker**, no por `localhost`:
- PostgreSQL: host `postgres` (no `localhost`), puerto `5432`, BD `ecommerce_tesis`, user `n8n_user` / `n8n_pass`.
- SMTP (Mailpit): host `mailpit`, puerto `1025`, sin auth, sin TLS.

`localhost:5432`, `localhost:8025`, etc. son solo para acceder desde la máquina host (Grafana datasource, psql, navegador).

## Comandos

```powershell
# Levantar / detener todo
docker compose up -d
docker compose down                      # NO borra datos (volúmenes persisten)
docker compose logs -f n8n

# Crear schema (init_simple.sql también se auto-ejecuta en el primer arranque del volumen)
Get-Content init_simple.sql | docker exec -i tesis_postgres psql -U n8n_user -d ecommerce_tesis
Get-Content seed_expand.sql | docker exec -i tesis_postgres psql -U n8n_user -d ecommerce_tesis

# Consola SQL
docker exec -it tesis_postgres psql -U n8n_user -d ecommerce_tesis

# Backup / restore (incluye workflows y credenciales de n8n desde la BD)
.\backup.ps1                             # genera backups\<fecha>\
.\restore.ps1

# Ver métricas
docker exec tesis_postgres psql -U n8n_user -d ecommerce_tesis -c "SELECT * FROM v_metrics_summary;"
```

| Servicio | URL host | Credenciales |
|---|---|---|
| n8n | http://localhost:5678 | admin / admin123 |
| Grafana | http://localhost:3000 | admin / admin |
| Mailpit (inbox) | http://localhost:8025 | — |
| PostgreSQL | localhost:5432 | n8n_user / n8n_pass |

## Testing — es manual, disparando webhooks

No hay suite automatizada. Se prueba enviando requests a los webhooks y verificando BD + Mailpit:

```powershell
Invoke-RestMethod -Uri "http://localhost:5678/webhook/orden-nueva" -Method POST `
  -ContentType "application/json" `
  -Body '{"order_number":"ORD-TEST-001","customer_name":"Test","customer_email":"t@t.com","customer_phone":"549...","product_sku":"PROD-001","quantity":1}'
```

El payload del Flujo 2 imita la estructura de la WhatsApp Cloud API (`entry[].changes[].value.messages[]`). Para forzar la rama "sin stock" del Flujo 1, pedí más unidades de las que hay en stock. El README tiene el catálogo de SKUs de prueba y ejemplos en PowerShell, curl y Postman.

## Flujo de trabajo al cambiar un workflow

1. Editás en la UI de n8n (http://localhost:5678), no el JSON a mano salvo cambios triviales.
2. Exportás el workflow actualizado a `workflows/` (Download / Export from file).
3. Para persistir credenciales/workflows fuera de la UI, corré `.\backup.ps1` (los lee desde las tablas `workflow_entity` / `credentials_entity` de la BD de n8n).

Las credenciales reales de n8n NO se versionan; `CREDENCIALES.example.md` es la guía de qué configurar.
