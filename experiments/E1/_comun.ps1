# ============================================================
#  E1 — Funciones comunes a los scripts de la prueba de carga
#  Tesis UTN FRM — Plan de Regeneración de Evidencia, §3
#
#  No se ejecuta solo. Lo cargan run_flujo1_carga.ps1 y
#  run_flujo1_concurrencia.ps1 con dot-sourcing.
# ============================================================

$ErrorActionPreference = 'Stop'

# ---- Configuración del entorno (docker-compose.yml) ---------
$script:Contenedor  = 'tesis_postgres'
$script:BaseDatos   = 'ecommerce_tesis'
$script:UsuarioBd   = 'n8n_user'
$script:UrlWebhook  = 'http://localhost:5678/webhook/orden-nueva'
$script:DirSalida   = Join-Path $PSScriptRoot 'resultados'

# ============================================================
#  Acceso a PostgreSQL vía docker exec
# ============================================================

function Invoke-Psql {
    <#
      Ejecuta SQL contra ecommerce_tesis y devuelve la salida.
      -Tuplas: sin encabezados ni bordes, campos separados por TAB
               (para parsear desde PowerShell).
    #>
    param(
        [Parameter(Mandatory)][string]$Sql,
        [switch]$Tuplas
    )

    $argumentos = @(
        'exec', '-i', $script:Contenedor,
        'psql', '-U', $script:UsuarioBd, '-d', $script:BaseDatos,
        '-v', 'ON_ERROR_STOP=1'
    )
    if ($Tuplas) { $argumentos += @('-t', '-A', '-F', "`t") }

    # psql escribe NOTICE/WARNING por stderr aun cuando todo salió bien.
    # Con $ErrorActionPreference = 'Stop', un stderr redirigido de un comando
    # nativo hace que PowerShell 5.1 lance NativeCommandError y aborte la
    # corrida por un aviso inofensivo. Se baja la preferencia solo acá y se
    # decide por $LASTEXITCODE, que es la señal confiable.
    $prefPrevia = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $crudo = $Sql | & docker @argumentos 2>&1
    } finally {
        $ErrorActionPreference = $prefPrevia
    }

    # Separar lo que vino por stdout de lo que vino por stderr.
    $stdout = @($crudo | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
    $stderr = @($crudo | Where-Object { $_ -is  [System.Management.Automation.ErrorRecord] })

    if ($LASTEXITCODE -ne 0) {
        throw "psql falló (exit $LASTEXITCODE): $(($stderr + $stdout) -join "`n")"
    }
    if ($stderr.Count -gt 0) {
        Write-Verbose "psql (stderr): $($stderr -join '; ')"
    }
    return $stdout
}

function Get-Escalar {
    param([Parameter(Mandatory)][string]$Sql)
    $r = Invoke-Psql -Sql $Sql -Tuplas
    return ($r | Where-Object { $_ -ne '' } | Select-Object -First 1).Trim()
}

# ============================================================
#  Verificaciones previas — que nadie mida contra un entorno roto
# ============================================================

function Test-Preflight {
    <#
      Corre las verificaciones mínimas antes de tocar nada.
      Devuelve un hashtable con el estado detectado.
      Aborta (throw) solo ante lo que invalida la medición.
    #>
    param([switch]$Silencioso)

    $estado = @{}

    Write-Host "`n=== Verificación previa ===" -ForegroundColor Cyan

    # --- 1. Docker y los contenedores ---
    $prefPrevia = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $nombres = @(& docker ps --format '{{.Names}}' 2>$null) }
    finally { $ErrorActionPreference = $prefPrevia }

    if ($LASTEXITCODE -ne 0) {
        throw "Docker no responde. Levantá el entorno con 'docker compose up -d' antes de medir."
    }
    foreach ($req in @('tesis_postgres', 'tesis_n8n')) {
        if ($nombres -notcontains $req) {
            throw "El contenedor '$req' no está corriendo. Ejecutá 'docker compose up -d'."
        }
    }
    Write-Host "  [OK] Contenedores arriba (tesis_postgres, tesis_n8n)"

    # --- 2. Base de datos alcanzable ---
    $null = Get-Escalar -Sql 'SELECT 1;'
    Write-Host "  [OK] PostgreSQL responde ($script:BaseDatos)"

    # --- 3. Catálogo cargado ---
    $productos = [int](Get-Escalar -Sql 'SELECT COUNT(*) FROM products;')
    if ($productos -lt 1) {
        throw "La tabla products está vacía. Cargá el catálogo con seed_catalogo.sql (NO con seed_expand.sql, está congelado)."
    }
    $estado.Productos = $productos
    Write-Host "  [OK] Catálogo: $productos productos"

    # --- 4. Columna data_source (B-5) ---
    $tieneDataSource = (Get-Escalar -Sql @"
SELECT COUNT(*) FROM information_schema.columns
WHERE table_name = 'orders' AND column_name = 'data_source';
"@) -eq '1'
    $estado.DataSource = $tieneDataSource
    if ($tieneDataSource) {
        Write-Host "  [OK] Columna orders.data_source presente (B-5)"
    } else {
        Write-Warning "  orders.data_source NO existe. Las órdenes de este experimento no van a quedar marcadas como 'measured'. Aplicá B-5 antes de medir en serio."
    }

    # --- 5. Estado del Flujo 1 en n8n (activo + D-4) ---
    #     n8n comparte la base ecommerce_tesis: workflow_entity vive acá.
    #     Si la consulta falla (cambio de schema de n8n), se degrada a aviso:
    #     esta verificación NO debe bloquear el experimento.
    $estado.FlujoActivo = $null
    $estado.NodosFlujo1 = $null
    try {
        $fila = Invoke-Psql -Tuplas -Sql @"
SELECT active, jsonb_array_length(nodes::jsonb)
FROM workflow_entity
WHERE name LIKE 'Flujo 1%' AND name NOT LIKE '%PRODUCCION%'
ORDER BY "updatedAt" DESC LIMIT 1;
"@
        $campos = (($fila | Where-Object { $_ -ne '' } | Select-Object -First 1) -split "`t")
        if ($campos.Count -ge 2) {
            $estado.FlujoActivo = ($campos[0].Trim() -eq 't')
            $estado.NodosFlujo1 = [int]$campos[1].Trim()

            if ($estado.FlujoActivo) {
                Write-Host "  [OK] Flujo 1 SIMPLE activo en n8n ($($estado.NodosFlujo1) nodos)"
            } else {
                throw "El Flujo 1 SIMPLE está INACTIVO en n8n. Activalo en http://localhost:5678 antes de medir."
            }

            if ($estado.NodosFlujo1 -lt 13) {
                Write-Warning @"
  D-4 NO APLICADO — el Flujo 1 tiene $($estado.NodosFlujo1) nodos, se esperan 13.
  Falta 'Registrar Notificacion Sin Stock' (ver docs/D4_NODO_REGISTRAR_NOTIFICACION_SIN_STOCK.md).
  CONSECUENCIA: las órdenes que caigan en no_stock van a tener notified_at NULL,
  y el MTTR se va a poder calcular SOLO sobre la rama con stock. El experimento
  corre igual, pero la muestra de MTTR queda partida al medio (hallazgo B-6.1).
"@
            } else {
                Write-Host "  [OK] D-4 aplicado (13 nodos): el MTTR se puede medir en ambas ramas"
            }
        }
    } catch {
        if ($_.Exception.Message -like '*INACTIVO*') { throw }
        Write-Warning "  No se pudo inspeccionar workflow_entity ($($_.Exception.Message)). Verificá a mano que el Flujo 1 SIMPLE esté activo."
    }

    Write-Host ""
    return $estado
}

# ============================================================
#  Envío de una orden al webhook
# ============================================================

function Send-Orden {
    <#
      Manda una orden al webhook y devuelve el registro de la medición.
      Nunca lanza excepción: un fallo HTTP es un dato del experimento,
      no un motivo para abortar la corrida.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Orden,
        [int]$TimeoutSeg = 30
    )

    $cuerpo = $Orden | ConvertTo-Json -Compress
    $reloj  = [System.Diagnostics.Stopwatch]::StartNew()
    $tsEnvio = (Get-Date).ToUniversalTime()

    $registro = [ordered]@{
        order_number         = $Orden.order_number
        product_sku          = $Orden.product_sku
        quantity             = $Orden.quantity
        ts_envio_utc         = $tsEnvio.ToString('yyyy-MM-dd HH:mm:ss.fff')
        ts_respuesta_utc     = $null
        latencia_ms          = $null
        http_ok              = $false
        http_status          = $null
        respuesta_status     = $null
        error                = $null
    }

    try {
        $resp = Invoke-RestMethod -Uri $script:UrlWebhook -Method POST `
                                  -ContentType 'application/json; charset=utf-8' `
                                  -Body ([System.Text.Encoding]::UTF8.GetBytes($cuerpo)) `
                                  -TimeoutSec $TimeoutSeg
        $reloj.Stop()
        $registro.http_ok          = $true
        $registro.http_status      = 200
        $registro.respuesta_status = if ($resp.status) { $resp.status } elseif ($resp.mensaje) { $resp.mensaje } else { ($resp | ConvertTo-Json -Compress) }
    }
    catch {
        $reloj.Stop()
        $registro.error = $_.Exception.Message
        if ($_.Exception.Response) {
            try { $registro.http_status = [int]$_.Exception.Response.StatusCode } catch { }
        }
    }

    $registro.ts_respuesta_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss.fff')
    $registro.latencia_ms      = [math]::Round($reloj.Elapsed.TotalMilliseconds, 1)
    return [pscustomobject]$registro
}

# ============================================================
#  Manifiesto de corrida — insumo del paquete reproducible (E6)
# ============================================================

function Write-Manifiesto {
    param(
        [Parameter(Mandatory)][string]$Ruta,
        [Parameter(Mandatory)][hashtable]$Datos
    )

    $commit = try { (& git rev-parse --short HEAD 2>$null) } catch { 'desconocido' }
    if (-not $commit) { $commit = 'desconocido' }

    $Datos['git_commit']       = "$commit".Trim()
    $Datos['host_powershell']  = $PSVersionTable.PSVersion.ToString()
    $Datos['ejecutado_utc']    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
    $Datos['endpoint']         = $script:UrlWebhook

    $Datos | ConvertTo-Json -Depth 6 | Out-File -FilePath $Ruta -Encoding utf8
    Write-Host "  Manifiesto: $Ruta" -ForegroundColor DarkGray
}

function Initialize-DirSalida {
    if (-not (Test-Path $script:DirSalida)) {
        New-Item -ItemType Directory -Path $script:DirSalida -Force | Out-Null
    }
}
