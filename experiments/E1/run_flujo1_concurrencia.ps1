<#
.SYNOPSIS
    E1.b — Prueba de concurrencia y atomicidad del Flujo 1 (cierra A-08).

.DESCRIPTION
    Fija el stock de un producto en un valor conocido y dispara N requests
    SIMULTÁNEAS pidiendo 1 unidad cada una. Repite el ensayo varias rondas.

    Resultado esperado por ronda (stock = 5, 20 requests):
        - exactamente 5 órdenes confirmed
        - 15 en no_stock
        - stock final = 0, nunca negativo

    POR QUÉ IMPORTA: el Flujo 1 lee y escribe el stock en DOS statements
    separados ('Verificar Stock' hace SELECT, 'Actualizar Stock' hace
    UPDATE ... SET stock = stock - n). Entre uno y otro no hay bloqueo.
    Eso es una condición de carrera de manual. El CHECK (stock >= 0) de
    init_simple.sql actúa como red: si hay sobreventa, el UPDATE falla
    ruidosamente en vez de dejar stock negativo en silencio.

    Si aparece sobreventa (o errores del CHECK), NO es un fallo del
    experimento: es el hallazgo. Se documenta la condición de carrera y se
    discute la mitigación (SELECT ... FOR UPDATE o restricción en la base).
    Un hallazgo negativo bien medido vale más que un número lindo inventado.

    Referencia: docs/PLAN_REGENERACION_EVIDENCIA.md §3 (E1.b).

.PARAMETER Sku
    SKU sobre el que se corre el ensayo. Por defecto PROD-005.
    El stock original se restaura al terminar.

.PARAMETER Stock
    Stock a fijar antes de cada ronda. Por defecto 5.

.PARAMETER Requests
    Requests simultáneas por ronda. Por defecto 20.

.PARAMETER Rondas
    Cantidad de repeticiones. Por defecto 3.

.PARAMETER DryRun
    Muestra lo que haría sin enviar nada ni tocar la base.

.EXAMPLE
    .\run_flujo1_concurrencia.ps1 -DryRun

.EXAMPLE
    .\run_flujo1_concurrencia.ps1
#>

[CmdletBinding()]
param(
    [string]$Sku       = 'PROD-005',
    [int]$Stock        = 5,
    [int]$Requests     = 20,
    [int]$Rondas       = 3,
    [string]$Prefijo   = 'ORD-E1B',
    [int]$TimeoutSeg   = 60,
    [switch]$DryRun,
    [switch]$Force
)

. (Join-Path $PSScriptRoot '_comun.ps1')

if ($PSVersionTable.PSVersion.Major -lt 6) {
    Add-Type -AssemblyName System.Net.Http
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " E1.b — Concurrencia y atomicidad del Flujo 1" -ForegroundColor Cyan
Write-Host " SKU: $Sku   stock por ronda: $Stock   requests: $Requests   rondas: $Rondas" -ForegroundColor Cyan
Write-Host " Esperado por ronda: $Stock confirmed / $($Requests - $Stock) no_stock / stock final 0" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
#  1. Verificación previa
# ------------------------------------------------------------
$estado = Test-Preflight

$stockOriginal = Get-Escalar -Sql "SELECT stock FROM products WHERE sku = '$Sku';"
if ([string]::IsNullOrWhiteSpace($stockOriginal)) {
    throw "El SKU '$Sku' no existe en products. Elegí uno del catálogo."
}
$stockOriginal = [int]$stockOriginal
Write-Host "Stock original de ${Sku}: $stockOriginal (se restaura al terminar).`n"

$previas = [int](Get-Escalar -Sql "SELECT COUNT(*) FROM orders WHERE order_number LIKE '$Prefijo-%';")
if ($previas -gt 0) {
    Write-Warning "Ya hay $previas órdenes con prefijo '$Prefijo'. order_number es UNIQUE: los repetidos van a fallar. Usá otro -Prefijo o limpiá la corrida anterior."
}

if ($DryRun) {
    Write-Host "DRY RUN — no se envió nada y no se tocó la base." -ForegroundColor Green
    Write-Host "Se habrían disparado $($Rondas * $Requests) órdenes en $Rondas rondas contra $Sku."
    return
}

if (-not $Force) {
    Write-Host "Esto va a ESCRIBIR $($Rondas * $Requests) órdenes y modificar el stock de $Sku." -ForegroundColor Yellow
    $r = Read-Host "Escribí SI para continuar"
    if ($r -ne 'SI') { Write-Host "Cancelado." -ForegroundColor Red; return }
}

# ------------------------------------------------------------
#  2. Ejecutar las rondas
# ------------------------------------------------------------
Initialize-DirSalida
$sello      = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$rutaCsv    = Join-Path $script:DirSalida "e1b_envios_$sello.csv"
$rutaResCsv = Join-Path $script:DirSalida "e1b_rondas_$sello.csv"
$rutaMan    = Join-Path $script:DirSalida "e1b_manifiesto_$sello.json"

$detalle  = @()
$porRonda = @()

$cliente = [System.Net.Http.HttpClient]::new()
$cliente.Timeout = [TimeSpan]::FromSeconds($TimeoutSeg)

try {
    for ($ronda = 1; $ronda -le $Rondas; $ronda++) {

        Write-Host "`n--- Ronda $ronda / $Rondas ---" -ForegroundColor Cyan

        # --- Fijar el stock ---
        $null = Invoke-Psql -Sql "UPDATE products SET stock = $Stock WHERE sku = '$Sku';"
        $stockAntes = [int](Get-Escalar -Sql "SELECT stock FROM products WHERE sku = '$Sku';")
        Write-Host "  Stock fijado en $stockAntes"

        # --- Armar los payloads por adelantado ---
        #     Se serializa TODO antes de disparar, para que el trabajo de
        #     construcción no se cuele dentro de la ventana de disparo.
        $contenidos = @()
        $numeros    = @()
        for ($k = 1; $k -le $Requests; $k++) {
            $nn  = '{0:D2}' -f $k
            $num = "$Prefijo-R$ronda-$nn"
            $numeros += $num
            $json = @{
                order_number   = $num
                customer_name  = "Cliente Concurrente $nn"
                customer_email = "concurrente$nn@example.com"
                customer_phone = "+5492610001$nn"
                product_sku    = $Sku
                quantity       = 1
            } | ConvertTo-Json -Compress
            $contenidos += [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
        }

        # --- Disparo simultáneo ---
        #     Se mide la VENTANA DE DISPARO (skew entre el primer y el último
        #     envío). Hay que reportarla: es el límite de "simultaneidad" que
        #     este experimento puede afirmar honestamente.
        $tareas   = New-Object 'System.Collections.Generic.List[System.Threading.Tasks.Task]'
        $reloj    = [System.Diagnostics.Stopwatch]::StartNew()
        $tsInicio = (Get-Date).ToUniversalTime()
        $skews    = @()

        foreach ($c in $contenidos) {
            $skews += [math]::Round($reloj.Elapsed.TotalMilliseconds, 2)
            $tareas.Add($cliente.PostAsync($script:UrlWebhook, $c))
        }
        $ventanaDisparoMs = [math]::Round($reloj.Elapsed.TotalMilliseconds, 2)

        try {
            [System.Threading.Tasks.Task]::WaitAll($tareas.ToArray(), ($TimeoutSeg + 30) * 1000) | Out-Null
        } catch {
            Write-Warning "  Al menos una request terminó con excepción (se registra por request más abajo)."
        }
        $reloj.Stop()
        Write-Host ("  Ventana de disparo: {0} ms   |   Total hasta última respuesta: {1} ms" -f $ventanaDisparoMs, [math]::Round($reloj.Elapsed.TotalMilliseconds, 1))

        # --- Recolectar el resultado de cada request ---
        $okHttp = 0
        for ($k = 0; $k -lt $tareas.Count; $k++) {
            $t = $tareas[$k]
            $httpStatus = $null
            $err        = $null
            $cuerpo     = $null

            if ($t.IsFaulted) {
                $err = ($t.Exception.GetBaseException()).Message
            } elseif ($t.Status -eq 'RanToCompletion') {
                $httpStatus = [int]$t.Result.StatusCode
                if ($httpStatus -ge 200 -and $httpStatus -lt 300) { $okHttp++ }
                try { $cuerpo = $t.Result.Content.ReadAsStringAsync().Result } catch { }
            } else {
                $err = "Tarea en estado $($t.Status) (timeout probable)"
            }

            $detalle += [pscustomobject]@{
                ronda            = $ronda
                order_number     = $numeros[$k]
                sku              = $Sku
                quantity         = 1
                skew_disparo_ms  = $skews[$k]
                http_status      = $httpStatus
                http_ok          = ($httpStatus -ge 200 -and $httpStatus -lt 300)
                respuesta        = if ($cuerpo) { $cuerpo.Substring(0, [Math]::Min(300, $cuerpo.Length)) } else { $null }
                error            = $err
            }
        }

        # --- Verificar el invariante contra la base ---
        $stockFinal = [int](Get-Escalar -Sql "SELECT stock FROM products WHERE sku = '$Sku';")
        $conf   = [int](Get-Escalar -Sql "SELECT COUNT(*) FROM orders WHERE order_number LIKE '$Prefijo-R$ronda-%' AND status = 'confirmed';")
        $sinStk = [int](Get-Escalar -Sql "SELECT COUNT(*) FROM orders WHERE order_number LIKE '$Prefijo-R$ronda-%' AND status = 'no_stock';")
        $otras  = [int](Get-Escalar -Sql "SELECT COUNT(*) FROM orders WHERE order_number LIKE '$Prefijo-R$ronda-%' AND status NOT IN ('confirmed','no_stock');")
        $enBd   = [int](Get-Escalar -Sql "SELECT COUNT(*) FROM orders WHERE order_number LIKE '$Prefijo-R$ronda-%';")

        # Órdenes huérfanas: registradas por 'Registrar Orden' pero cuya ejecución
        # murió antes de resolver la rama. Quedan en 'pending' con processed_at NULL,
        # o sea INVISIBLES para v_order_processing_time y v_metrics_summary.
        $pendientes = [int](Get-Escalar -Sql "SELECT COUNT(*) FROM orders WHERE order_number LIKE '$Prefijo-R$ronda-%' AND status = 'pending' AND processed_at IS NULL;")
        $ejecError  = [int](Get-Escalar -Sql "SELECT COUNT(*) FROM execution_entity WHERE status = 'error' AND ""startedAt"" > NOW() - INTERVAL '3 minutes';")

        $sobreventa    = ($conf -gt $Stock)
        $stockNegativo = ($stockFinal -lt 0)
        $perdidas      = $Requests - $enBd

        Write-Host "  Confirmadas: $conf (esperado $Stock)   no_stock: $sinStk   otros estados: $otras   huérfanas en pending: $pendientes"
        Write-Host "  Órdenes en la base: $enBd / $Requests    Stock final: $stockFinal (esperado 0)   ejecuciones n8n con error: $ejecError"

        if ($sobreventa) {
            Write-Host "  >>> SOBREVENTA: $conf confirmadas contra un stock de $Stock. Condición de carrera CONFIRMADA." -ForegroundColor Red
        } elseif ($stockNegativo) {
            Write-Host "  >>> STOCK NEGATIVO ($stockFinal). El CHECK no contuvo." -ForegroundColor Red
        } elseif ($pendientes -gt 0 -or $otras -gt 0) {
            # NO es atomicidad OK. El CHECK evitó la sobreventa, pero la ejecución
            # murió en 'Actualizar Stock' y la orden quedó huérfana: sin email,
            # sin respuesta al cliente y fuera de todas las vistas de métricas.
            Write-Host "  >>> CONDICION DE CARRERA CONFIRMADA (sin sobreventa): $pendientes órdenes huérfanas en 'pending'." -ForegroundColor Red
            Write-Host "      El CHECK (stock >= 0) evitó vender de más, pero el workflow no maneja el error:" -ForegroundColor Red
            Write-Host "      la ejecución aborta en 'Actualizar Stock' y la orden desaparece del pipeline en silencio." -ForegroundColor Red
        } elseif ($conf -eq $Stock -and $stockFinal -eq 0 -and $perdidas -eq 0) {
            Write-Host "  >>> Atomicidad OK: el invariante se sostuvo, sin órdenes huérfanas." -ForegroundColor Green
        } else {
            Write-Host "  >>> Desvío (órdenes perdidas: $perdidas). Revisá docker logs tesis_n8n." -ForegroundColor Yellow
        }

        $porRonda += [pscustomobject]@{
            ronda               = $ronda
            sku                 = $Sku
            stock_inicial       = $stockAntes
            requests            = $Requests
            ventana_disparo_ms  = $ventanaDisparoMs
            duracion_total_ms   = [math]::Round($reloj.Elapsed.TotalMilliseconds, 1)
            http_ok             = $okHttp
            ordenes_en_bd       = $enBd
            ordenes_perdidas    = $perdidas
            confirmed           = $conf
            no_stock            = $sinStk
            otros_estados       = $otras
            huerfanas_pending   = $pendientes
            ejecuciones_error   = $ejecError
            stock_final         = $stockFinal
            sobreventa          = $sobreventa
            stock_negativo      = $stockNegativo
            # El invariante SOLO se sostiene si además no quedaron órdenes
            # huérfanas. Sin esta condición el veredicto tapa el hallazgo real.
            invariante_ok       = (-not $sobreventa -and -not $stockNegativo -and $conf -eq $Stock -and $stockFinal -eq 0 -and $perdidas -eq 0 -and $otras -eq 0 -and $pendientes -eq 0)
        }

        if ($ronda -lt $Rondas) { Start-Sleep -Seconds 5 }
    }
}
finally {
    # --- Restaurar el stock original SIEMPRE, aunque algo explote ---
    try {
        $null = Invoke-Psql -Sql "UPDATE products SET stock = $stockOriginal WHERE sku = '$Sku';"
        Write-Host "`nStock de $Sku restaurado a $stockOriginal." -ForegroundColor DarkGray
    } catch {
        Write-Warning "NO se pudo restaurar el stock de $Sku a $stockOriginal. Hacelo a mano: UPDATE products SET stock = $stockOriginal WHERE sku = '$Sku';"
    }
    $cliente.Dispose()
}

# ------------------------------------------------------------
#  3. Guardar evidencia
# ------------------------------------------------------------
$detalle  | Export-Csv -Path $rutaCsv    -NoTypeInformation -Encoding UTF8
$porRonda | Export-Csv -Path $rutaResCsv -NoTypeInformation -Encoding UTF8

Write-Manifiesto -Ruta $rutaMan -Datos @{
    experimento     = 'E1.b - concurrencia y atomicidad Flujo 1'
    sku             = $Sku
    stock_por_ronda = $Stock
    requests        = $Requests
    rondas          = $Rondas
    prefijo         = $Prefijo
    stock_original  = $stockOriginal
    nodos_flujo1    = $estado.NodosFlujo1
    archivo_detalle = (Split-Path $rutaCsv -Leaf)
    archivo_rondas  = (Split-Path $rutaResCsv -Leaf)
}

# ------------------------------------------------------------
#  4. Veredicto
# ------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " Resumen por ronda" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
$porRonda | Format-Table ronda, stock_inicial, confirmed, no_stock, huerfanas_pending, ordenes_perdidas, stock_final, sobreventa, invariante_ok -AutoSize

$conSobreventa = @($porRonda | Where-Object sobreventa).Count
$okTodas       = @($porRonda | Where-Object invariante_ok).Count
$totalHuerf    = ($porRonda | Measure-Object huerfanas_pending -Sum).Sum
$totalReq      = $Rondas * $Requests

if ($conSobreventa -gt 0) {
    Write-Host "VEREDICTO: sobreventa en $conSobreventa de $Rondas rondas." -ForegroundColor Red
    Write-Host "La condición de carrera entre 'Verificar Stock' y 'Actualizar Stock' está confirmada empíricamente."
    Write-Host "Es un hallazgo publicable: documentalo y discutí la mitigación (SELECT ... FOR UPDATE)."
} elseif ($totalHuerf -gt 0) {
    $pct = [math]::Round(100.0 * $totalHuerf / $totalReq, 1)
    Write-Host "VEREDICTO: CONDICION DE CARRERA CONFIRMADA, sin sobreventa." -ForegroundColor Red
    Write-Host ""
    Write-Host "  $totalHuerf de $totalReq órdenes ($pct%) quedaron huérfanas en estado 'pending'."
    Write-Host ""
    Write-Host "  Mecanismo: 'Verificar Stock' y 'Actualizar Stock' son dos statements sin bloqueo."
    Write-Host "  Varias ejecuciones leen el mismo stock, todas creen tenerlo, y al descontar"
    Write-Host "  las que llegan tarde violan CHECK (stock >= 0). El workflow no maneja ese error:"
    Write-Host "  la ejecución aborta en 'Actualizar Stock' y la orden queda registrada pero sin"
    Write-Host "  procesar, sin email y sin respuesta al cliente."
    Write-Host ""
    Write-Host "  AGRAVANTE: esas órdenes tienen processed_at NULL, así que v_order_processing_time"
    Write-Host "  y v_metrics_summary NO LAS VEN. Las métricas se calculan solo sobre las que"
    Write-Host "  sobrevivieron: el fallo es invisible en el tablero." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  El CHECK (stock >= 0) evitó la sobreventa. Ese es el control que sí funcionó."
    Write-Host "  Mitigación a discutir: SELECT ... FOR UPDATE, UPDATE condicional con"
    Write-Host "  'WHERE stock >= n' verificando filas afectadas, o manejo de error en el nodo."
} elseif ($okTodas -eq $Rondas) {
    Write-Host "VEREDICTO: el invariante se sostuvo en las $Rondas rondas. Sin sobreventa ni órdenes huérfanas." -ForegroundColor Green
    Write-Host "Reportá la ventana de disparo (columna ventana_disparo_ms) como límite de la afirmación de simultaneidad."
} else {
    Write-Host "VEREDICTO: sin sobreventa, pero hubo desvíos (órdenes perdidas o estados inesperados)." -ForegroundColor Yellow
    Write-Host "Revisá e1b_envios_*.csv y 'docker logs tesis_n8n' antes de reportar."
}

Write-Host "`n  Detalle: $rutaCsv"    -ForegroundColor Green
Write-Host "  Rondas : $rutaResCsv`n" -ForegroundColor Green
