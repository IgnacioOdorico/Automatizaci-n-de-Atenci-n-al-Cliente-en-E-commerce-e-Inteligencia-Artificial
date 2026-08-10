# E1 — Prueba de carga del Flujo 1

Scripts de medición del pipeline de órdenes. Referencia: `docs/PLAN_REGENERACION_EVIDENCIA.md` §3.

| Archivo | Qué hace |
|---|---|
| `_comun.ps1` | Funciones compartidas: verificación previa, acceso a psql, envío al webhook, manifiesto. No se ejecuta solo. |
| `run_flujo1_carga.ps1` | **E1.a** — 50 órdenes secuenciales espaciadas 2 s (35 con stock / 15 forzando `no_stock`). |
| `run_flujo1_concurrencia.ps1` | **E1.b** — 20 requests simultáneas contra un stock de 5, 3 rondas. Cierra el hallazgo A-08. |
| `analizar_e1.sql` | Extrae las métricas: n, media, mediana, desvío, mín, máx, p95 para MTTD, MTTR y end-to-end. Solo lee. |
| `resultados/` | Salida: CSV de envíos + manifiesto JSON por corrida. |

---

## Antes de correr nada

**1. El entorno tiene que estar arriba.**

```powershell
docker compose up -d
```

Los scripts abortan solos si `tesis_postgres` o `tesis_n8n` no responden, si el Flujo 1 SIMPLE está inactivo, o si el catálogo está vacío.

**2. Decidir el estado de la base (B-4).**

Estos scripts **no truncan nada**. Miden contra la base tal como esté. Si corrés E1 sobre la base con los datos seed adentro, las métricas van a salir mezcladas con las 107 interacciones y las 32 órdenes sintéticas.

La decisión D-1 del plan (Opción A: base limpia) sigue **pendiente de ejecución**. Mientras no se aplique, el análisis se sostiene igual porque **filtra por prefijo de `order_number`** (`ORD-E1A-%` / `ORD-E1B-%`) — las métricas de E1 salen limpias aunque haya seed alrededor. Lo que NO va a estar limpio es `v_metrics_summary`, que promedia toda la tabla.

**3. D-4 conviene aplicarlo antes.**

Con el Flujo 1 en 12 nodos (estado actual), la rama `no_stock` **no escribe `notified_at`**. Consecuencia concreta: de las 50 órdenes de E1.a, solo las ~35 con stock van a tener MTTR. Las ~15 sin stock salen NULL.

El script lo detecta y avisa en la verificación previa, pero corre igual. Ver `docs/D4_NODO_REGISTRAR_NOTIFICACION_SIN_STOCK.md`.

---

## Correr

```powershell
cd experiments\E1

# Primero SIEMPRE en seco: muestra el plan sin tocar nada
.\run_flujo1_carga.ps1 -DryRun

# La corrida real (~2 minutos). Pide confirmación escribiendo SI.
.\run_flujo1_carga.ps1

# Concurrencia (~1 minuto)
.\run_flujo1_concurrencia.ps1 -DryRun
.\run_flujo1_concurrencia.ps1

# Métricas
Get-Content .\analizar_e1.sql | docker exec -i tesis_postgres psql -U n8n_user -d ecommerce_tesis |
  Tee-Object -FilePath ".\resultados\e1_metricas_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').txt"
```

### Parámetros útiles

```powershell
# Repetir la corrida sin chocar con order_number UNIQUE
.\run_flujo1_carga.ps1 -Prefijo 'ORD-E1A2'

# Otra semilla = otro plan de órdenes (misma semilla = corrida idéntica)
.\run_flujo1_carga.ps1 -Semilla 12345

# Concurrencia más agresiva
.\run_flujo1_concurrencia.ps1 -Requests 50 -Stock 10 -Rondas 5
```

---

## Reproducibilidad (insumo de E6)

Cada corrida deja un manifiesto JSON con: semilla, n, espaciado, commit de git, versión de PowerShell, timestamps UTC y la cantidad de nodos que tenía el Flujo 1 al momento de medir.

El plan de órdenes es **determinístico**: misma semilla + mismo stock inicial = misma secuencia exacta de SKUs y cantidades. Esa es la diferencia entre un experimento y una anécdota.

---

## Decisiones de diseño que hay que poder defender

**Por qué el plan se calcula leyendo el stock real.** Las órdenes "con stock" llevan un libro mayor del stock que va quedando, así ninguna cae en `no_stock` por accidente y contamina el grupo. Las órdenes "sin stock" piden `stock_inicial + 1..3`: como el stock solo baja durante la corrida, esa cantidad siempre resulta insuficiente. Los dos grupos quedan garantizados por construcción, no por suerte.

**Por qué se mezclan los dos grupos.** Si mandás primero las 35 con stock y después las 15 sin stock, el orden temporal se confunde con el tipo de orden: cualquier deriva del sistema (cache, warm-up, carga) queda pegada a la rama. Mezclados con Fisher-Yates, no.

**Por qué se registra el timestamp del cliente.** `received_at` lo pone la base con `NOW()` dentro del nodo `Registrar Orden`, que ya corre *después* de que n8n aceptó el request. El timestamp del cliente permite ver cuánto se pierde antes de ese punto — un tiempo que el MTTD no captura.

**Por qué E1.b reporta la ventana de disparo.** Las 20 requests no salen en el mismo nanosegundo: el bucle que las dispara tarda unos milisegundos. El script mide ese skew y lo guarda. Es el límite de lo que se puede afirmar sobre "simultaneidad", y hay que reportarlo en vez de decir "simultáneas" y quedarse tranquilo.

**Por qué los fallos HTTP se registran en vez de abortar.** Un request que falla es un dato del experimento. Si el script abortara, la muestra quedaría sesgada hacia los casos exitosos — exactamente el problema que el hallazgo B-6.6 detectó en el Flujo 2.

---

## Cosas del sistema que estos scripts esquivan (y hay que documentar)

**Los nombres de cliente no llevan apóstrofes.** El nodo `Registrar Orden` construye el INSERT interpolando los valores del payload directo en el string SQL:

```sql
'{{ $json.body.customer_name }}'
```

Un apóstrofe en el nombre rompe la consulta. Es, además, una vulnerabilidad de inyección SQL en el sistema construido. Los datos de prueba la esquivan a propósito; la tesis debería mencionarla como limitación conocida en vez de dejar que la encuentre el tribunal.

**El SKU tiene que existir.** El INSERT es un `INSERT ... SELECT ... FROM products WHERE sku = ...`. Si el SKU no existe, no inserta ninguna fila y el workflow sigue sin `order_id`. Los scripts solo usan SKUs leídos del catálogo real.

**Emails `@example.com` (B-7).** Dominio reservado por RFC 2606. Las figuras salen limpias de origen, sin retoque posterior — retocar figuras es exactamente lo que produjo el hallazgo C-02.
