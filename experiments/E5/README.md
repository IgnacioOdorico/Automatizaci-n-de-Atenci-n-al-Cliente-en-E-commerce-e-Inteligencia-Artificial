# E5 — Recaptura de figuras + control de consistencia

Cierra dos hallazgos de la auditoría: **C-02** (Fig. 3 y Fig. 5 eran la misma imagen) y
**A-11** (los números de las figuras contradecían las tablas). El objetivo no es "sacar
screenshots": es que **cada número de cada figura coincida con su tabla**, y que las
figuras salgan de **datos medidos**, no del seed sintético.

## Qué se hizo antes de capturar (ya aplicado)

1. **Vistas `v_*` filtradas a `data_source='measured'`** → `vistas_measured.sql` (aplicado a la BD viva).
2. **7 paneles de Grafana corregidos** (via API, dashboards `tesis-flujo1` / `tesis-flujo2`, exportados a `grafana/dashboards/`):
   - MTTD / MTTR / End-to-end → scopeados a **E1.a secuencial** (`ORD-E1A-%`), 3 decimales.
   - Pie de estados (F1), TMR por intent y pie de intents (F2) → `WHERE data_source='measured'`.
   - Panel Accuracy → de `90.7` (viejo, sin medir) a **`92.7`** (139/150 medido).

## Números canónicos (figura ↔ tabla del Cap. 5)

| Métrica | Valor medido | Población | Panel |
|---|---|---|---|
| MTTD | **0,009 s** | E1.a (n=50) | F1 · MTTD |
| MTTR | **0,054 s** | E1.a (n=50) | F1 · MTTR |
| End-to-end | **0,063 s** | E1.a (n=50) | F1 · End-to-end |
| Órdenes medidas | **173** (66 confirmed / 58 no_stock / 49 pending) | measured | F1 · pie + totales |
| Accuracy | **92,7%** (139/150) | E2 corrida 2 | F2 · Accuracy |
| TMR FAQ | **2,17 s** (n=97) | measured | F2 · TMR/intent |
| TMR RECLAMO | **2,05 s** (n=81) | measured | F2 · TMR/intent |
| TMR GENERAL | **1,74 s** (n=58) | measured | F2 · TMR/intent |
| TMR ESTADO_PEDIDO | **1,48 s** (n=38) | measured | F2 · TMR/intent |
| TMR promedio | **1,95 s** (n=274) | measured | F2 · TMR promedio |

> **Nota para el pie de Fig. 5:** las latencias (MTTD/MTTR/E2E) son de **E1.a secuencial**
> (medición controlada, sin contención). El volumen (173 órdenes) y la atomicidad son de
> E1.a **+ E1.b**. E1.b es el test de concurrencia (5 confirmadas, cero sobreventa) y se
> reporta como resultado de atomicidad, **no** como latencia. Aclararlo en el epígrafe.

## Figuras capturadas (decisión: 2 dashboards = 2 figuras)

Se eliminó la redundancia que causó C-02 (Fig. 3 y Fig. 5 eran el mismo dashboard de
Flujo 1). Ahora cada figura muestra un sistema distinto. Guardadas en `experiments/E5/figuras/`:

| Archivo | Figura en la tesis | Qué muestra |
|---|---|---|
| `flujo1.png` | **Fig. 3** (§4.5) | Dashboard "Pipeline Post-Venta" (Flujo 1): MTTD 0,009 / MTTR 0,054 / E2E 0,063 / pie estados / time series. |
| `mailpit.png` | **Fig. 4** (§4.6.2) | Bandeja de Mailpit con emails reales del Flujo 1, todos `@example.com` (3 confirmación + 2 aviso sin stock). |
| `flujo2.png` | **nueva, §5.2** | Dashboard "Chatbot Omnicanal" (Flujo 2): TMR 1,95 / accuracy 92,7% / TMR por intent / distribución de intents. |

Control de hashes: las 3 tienen SHA-256 distintos → C-02 no se reproduce.

## Control de consistencia (obligatorio, ~15 min)

- [ ] Correr el control de hashes:
  ```powershell
  cd experiments\E5
  .\control_hashes.ps1
  ```
  Tiene que decir **"hashes distintos, C-02 no se reproduce"**. Si grita duplicado, recapturá.
- [ ] Verificar a ojo: **cada número visible en Fig. 5 aparece idéntico en su tabla del Cap. 5**
  (usar la tabla de "números canónicos" de arriba).

## Pendiente en el `.docx` (último tramo de E5)

### 1. Sincronizar números de las tablas del Cap. 5

Las tablas de la tesis todavía tienen los números viejos del seed. Reemplazar:

| Donde dice (seed) | Va (medido) |
|---|---|
| MTTD 1,79 s | **0,009 s** |
| MTTR 7,69 s | **0,054 s** |
| Accuracy 90,7% | **92,7%** |
| TMR (varios, ~2,38 s) | usar la tabla de números canónicos por intent |

### 2. Reestructurar las figuras (elimina la redundancia C-02)

- **Fig. 3 (§4.5):** epígrafe queda como está (dashboard del Flujo 1) → usar `flujo1.png`.
- **Fig. 4 (§4.6.2):** Mailpit → usar `mailpit.png`.
- **Fig. 5 (§5.1, vieja):** era otra copia del dashboard del Flujo 1. Se elimina como figura
  aparte; §5.1 referencia la Fig. 3 en lugar de duplicarla.
- **Nueva figura (§5.2):** dashboard del Flujo 2 → usar `flujo2.png`. Numerarla y escribir
  epígrafe (TMR promedio, accuracy, TMR por intent, distribución de intents).
- Revisar la **lista de figuras** del índice y renumerar si hace falta.

> Todo esto se coordina aparte (edición del `.docx`), es el último tramo de E5.
