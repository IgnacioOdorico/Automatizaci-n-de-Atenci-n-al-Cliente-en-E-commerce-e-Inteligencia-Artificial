<#
.SYNOPSIS
    E1.a — Prueba de carga secuencial del Flujo 1 (pipeline de órdenes).

.DESCRIPTION
    Envía n órdenes al webhook POST /webhook/orden-nueva, espaciadas en el
    tiempo, mezclando órdenes con stock disponible y órdenes que fuerzan la
    rama no_stock. Registra el timestamp de envío del lado del cliente para
    poder contrastarlo con el received_at del servidor.

    El plan de órdenes es DETERMINÍSTICO: con la misma semilla y el mismo
    stock inicial se reproduce exactamente la misma corrida (requisito de E6).

    Referencia: docs/PLAN_REGENERACION_EVIDENCIA.md §3 (E1.a).

.PARAMETER N
    Cantidad total de órdenes. Por defecto 50 (la tesis original reportaba 20).

.PARAMETER ConStock
    Cuántas de esas N deben tener stock disponible. Por defecto 35.
    Las (N - ConStock) restantes fuerzan no_stock.

.PARAMETER EspaciadoSeg
    Segundos entre envíos. Por defecto 2.

.PARAMETER Semilla
    Semilla del generador pseudoaleatorio. Fijarla hace la corrida reproducible.

.PARAMETER Prefijo
    Prefijo de order_number. Por defecto ORD-E1A. El script de análisis
    filtra por este prefijo.

.PARAMETER DryRun
    Genera y muestra el plan SIN enviar nada ni tocar la base.

.PARAMETER Force
    Omite la confirmación interactiva.

.EXAMPLE
    .\run_flujo1_carga.ps1 -DryRun
    Muestra qué se va a enviar, sin tocar nada.

.EXAMPLE
    .\run_flujo1_carga.ps1
    Corrida completa: 50 órdenes, ~100 segundos.
#>

[CmdletBinding()]
param(
    [int]$N            = 50,
    [int]$ConStock     = 35,
    [int]$EspaciadoSeg = 2,
    [int]$Semilla      = 20260810,
    [string]$Prefijo   = 'ORD-E1A',
    [switch]$DryRun,
    [switch]$Force
)

. (Join-Path $PSScriptRoot '_comun.ps1')

if ($ConStock -gt $N) { throw "-ConStock ($ConStock) no puede ser mayor que -N ($N)." }
$SinStock = $N - $ConStock

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " E1.a — Carga secuencial del Flujo 1" -ForegroundColor Cyan
Write-Host " n=$N  (con stock: $ConStock / sin stock: $SinStock)  espaciado: ${EspaciadoSeg}s  semilla: $Semilla" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
#  1. Verificación previa
# ------------------------------------------------------------
$estado = Test-Preflight

# ¿Ya hay órdenes de una corrida anterior con este prefijo?
$previas = [int](Get-Escalar -Sql "SELECT COUNT(*) FROM orders WHERE order_number LIKE '$Prefijo-%';")
if ($previas -gt 0) {
    Write-Warning "Ya existen $previas órdenes con el prefijo '$Prefijo'. El INSERT tiene UNIQUE sobre order_number: los envíos con número repetido van a fallar. Usá otro -Prefijo (ej. -Prefijo 'ORD-E1A2') o limpiá la corrida anterior."
}

# ------------------------------------------------------------
#  2. Leer el stock real del catálogo
# ------------------------------------------------------------
$filas = Invoke-Psql -Tuplas -Sql 'SELECT sku, stock, price FROM products ORDER BY sku;'
$catalogo = @()
foreach ($f in $filas) {
    if ([string]::IsNullOrWhiteSpace($f)) { continue }
    $c = $f -split "`t"
    $catalogo += [pscustomobject]@{
        Sku          = $c[0].Trim()
        StockInicial = [int]$c[1].Trim()
        Precio       = [decimal]$c[2].Trim()
    }
}
Write-Host "Catálogo leído: $($catalogo.Count) SKUs, stock total $(($catalogo | Measure-Object StockInicial -Sum).Sum) unidades.`n"

# ------------------------------------------------------------
#  3. Construir el plan (determinístico)
# ------------------------------------------------------------
#  Con stock  : cantidad 1..3, contra un SKU con stock suficiente.
#               Se lleva un libro mayor del stock que va quedando, para que
#               ninguna orden "con stock" caiga por accidente en no_stock.
#  Sin stock  : cantidad = stock_inicial + 1..3. Como el stock solo baja
#               durante la corrida, esa cantidad SIEMPRE resulta insuficiente.
# ------------------------------------------------------------
$rnd = [System.Random]::new($Semilla)
$libro = @{}
foreach ($p in $catalogo) { $libro[$p.Sku] = $p.StockInicial }

$plan = New-Object System.Collections.ArrayList

# --- Órdenes con stock ---
$candidatos = @($catalogo | Where-Object { $_.StockInicial -ge 5 })
if ($candidatos.Count -eq 0) { throw "Ningún SKU tiene stock >= 5. Recargá el catálogo con seed_catalogo.sql." }

for ($i = 0; $i -lt $ConStock; $i++) {
    $cant = $rnd.Next(1, 4)   # 1..3
    $elegibles = @($candidatos | Where-Object { $libro[$_.Sku] -ge $cant })
    if ($elegibles.Count -eq 0) {
        throw "El catálogo se quedó sin stock para armar $ConStock órdenes con stock disponible. Bajá -ConStock o recargá el catálogo."
    }
    $p = $elegibles[$rnd.Next(0, $elegibles.Count)]
    $libro[$p.Sku] -= $cant
    [void]$plan.Add([pscustomobject]@{
        GrupoEsperado     = 'con_stock'
        Sku               = $p.Sku
        Cantidad          = $cant
        StockInicialSku   = $p.StockInicial
    })
}

# --- Órdenes que fuerzan no_stock ---
for ($i = 0; $i -lt $SinStock; $i++) {
    $p = $catalogo[$rnd.Next(0, $catalogo.Count)]
    $cant = $p.StockInicial + $rnd.Next(1, 4)   # stock_inicial + 1..3
    [void]$plan.Add([pscustomobject]@{
        GrupoEsperado     = 'no_stock'
        Sku               = $p.Sku
        Cantidad          = $cant
        StockInicialSku   = $p.StockInicial
    })
}

# --- Mezclar (Fisher-Yates con la misma semilla) ---
#     Intercalar los dos grupos evita que el orden temporal se confunda
#     con el tipo de orden al analizar los tiempos.
for ($i = $plan.Count - 1; $i -gt 0; $i--) {
    $j = $rnd.Next(0, $i + 1)
    $tmp = $plan[$i]; $plan[$i] = $plan[$j]; $plan[$j] = $tmp
}

# --- Asignar número de orden y datos de cliente ---
#  B-7: dominios reservados RFC 2606 (@example.com) desde el arranque,
#       para que las figuras salgan limpias de origen.
#  Los nombres NO llevan apóstrofes: 'Registrar Orden' interpola los
#  valores directo en el SQL, una comilla simple rompe el INSERT.
$ordenes = @()
for ($i = 0; $i -lt $plan.Count; $i++) {
    $seq = $i + 1
    $nn  = '{0:D3}' -f $seq
    $ordenes += [pscustomobject]@{
        Seq             = $seq
        GrupoEsperado   = $plan[$i].GrupoEsperado
        StockInicialSku = $plan[$i].StockInicialSku
        Payload         = @{
            order_number   = "$Prefijo-$nn"
            customer_name  = "Cliente de Prueba $nn"
            customer_email = "cliente$nn@example.com"
            customer_phone = "+5492610000$nn"
            product_sku    = $plan[$i].Sku
            quantity       = $plan[$i].Cantidad
        }
    }
}

# ------------------------------------------------------------
#  4. Mostrar el plan
# ------------------------------------------------------------
Write-Host "--- Plan de envío ---" -ForegroundColor Yellow
$ordenes | ForEach-Object {
    '{0,3}  {1,-14} {2,-10} x{3,-4} -> {4}' -f `
        $_.Seq, $_.Payload.order_number, $_.Payload.product_sku, $_.Payload.quantity, $_.GrupoEsperado
} | Write-Host

$duracion = [math]::Round(($N * $EspaciadoSeg) / 60.0, 1)
Write-Host "`nDuración estimada: ~$duracion minutos.`n" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host "DRY RUN — no se envió nada y no se tocó la base." -ForegroundColor Green
    return
}

if (-not $Force) {
    Write-Host "Esto va a ESCRIBIR $N órdenes en la base y descontar stock real." -ForegroundColor Yellow
    $r = Read-Host "Escribí SI para continuar"
    if ($r -ne 'SI') { Write-Host "Cancelado." -ForegroundColor Red; return }
}

# ------------------------------------------------------------
#  5. Enviar
# ------------------------------------------------------------
Initialize-DirSalida
$sello    = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$rutaCsv  = Join-Path $script:DirSalida "e1a_envios_$sello.csv"
$rutaMan  = Join-Path $script:DirSalida "e1a_manifiesto_$sello.json"

$inicio     = (Get-Date).ToUniversalTime()
$resultados = @()

Write-Host "`n--- Enviando ---" -ForegroundColor Cyan
foreach ($o in $ordenes) {
    $reg = Send-Orden -Orden $o.Payload
    $reg | Add-Member -NotePropertyName seq               -NotePropertyValue $o.Seq
    $reg | Add-Member -NotePropertyName grupo_esperado    -NotePropertyValue $o.GrupoEsperado
    $reg | Add-Member -NotePropertyName stock_inicial_sku -NotePropertyValue $o.StockInicialSku
    $resultados += $reg

    $marca = if ($reg.http_ok) { 'OK  ' } else { 'FALLA' }
    $color = if ($reg.http_ok) { 'Gray' } else { 'Red' }
    Write-Host ("  [{0}] {1,3}/{2}  {3}  {4,-10} x{5,-4} {6,8} ms  {7}" -f `
        $marca, $o.Seq, $N, $reg.order_number, $reg.product_sku, $reg.quantity, $reg.latencia_ms, $reg.respuesta_status) -ForegroundColor $color

    if ($o.Seq -lt $N) { Start-Sleep -Seconds $EspaciadoSeg }
}
$fin = (Get-Date).ToUniversalTime()

# ------------------------------------------------------------
#  6. Guardar evidencia
# ------------------------------------------------------------
$resultados |
    Select-Object seq, order_number, product_sku, quantity, grupo_esperado,
                  stock_inicial_sku, ts_envio_utc, ts_respuesta_utc,
                  latencia_ms, http_ok, http_status, respuesta_status, error |
    Export-Csv -Path $rutaCsv -NoTypeInformation -Encoding UTF8

Write-Manifiesto -Ruta $rutaMan -Datos @{
    experimento      = 'E1.a - carga secuencial Flujo 1'
    n                = $N
    con_stock        = $ConStock
    sin_stock        = $SinStock
    espaciado_seg    = $EspaciadoSeg
    semilla          = $Semilla
    prefijo          = $Prefijo
    inicio_utc       = $inicio.ToString('yyyy-MM-dd HH:mm:ss')
    fin_utc          = $fin.ToString('yyyy-MM-dd HH:mm:ss')
    nodos_flujo1     = $estado.NodosFlujo1
    d4_aplicado      = ($estado.NodosFlujo1 -ge 13)
    data_source      = $estado.DataSource
    archivo_csv      = (Split-Path $rutaCsv -Leaf)
}

# ------------------------------------------------------------
#  7. Contraste cliente vs. servidor
# ------------------------------------------------------------
Write-Host "`n--- Resultado ---" -ForegroundColor Cyan
$okHttp = @($resultados | Where-Object http_ok).Count
Write-Host "  Respuestas HTTP OK : $okHttp / $N"
if ($okHttp -lt $N) {
    Write-Warning "  $($N - $okHttp) envíos fallaron. Están en el CSV con su error — NO los descartes del reporte."
}

Write-Host "`n  Estado en la base (lo que cuenta):"
$resumen = Invoke-Psql -Sql @"
SELECT status, COUNT(*) AS n,
       COUNT(processed_at) AS con_processed_at,
       COUNT(notified_at)  AS con_notified_at
FROM orders WHERE order_number LIKE '$Prefijo-%'
GROUP BY status ORDER BY status;
"@
$resumen | Write-Host

$huerfanas = [int](Get-Escalar -Sql "SELECT $N - COUNT(*) FROM orders WHERE order_number LIKE '$Prefijo-%';")
if ($huerfanas -ne 0) {
    Write-Warning "  Se enviaron $N órdenes pero en la base hay $($N - $huerfanas). Faltan ${huerfanas}: revisá el CSV y los logs de n8n (docker logs tesis_n8n)."
}

Write-Host "`n  CSV: $rutaCsv" -ForegroundColor Green
Write-Host "`nSiguiente paso — extraer las métricas:" -ForegroundColor Cyan
Write-Host "  Get-Content `"$PSScriptRoot\analizar_e1.sql`" | docker exec -i $script:Contenedor psql -U $script:UsuarioBd -d $script:BaseDatos`n"
