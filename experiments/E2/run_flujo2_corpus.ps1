<#
.SYNOPSIS
    E2 — Ejecuta el corpus de 150 mensajes contra el pipeline real del Flujo 2.

.DESCRIPTION
    Envía cada mensaje de corpus_intents.csv al webhook POST /webhook/whatsapp
    y deja que el pipeline real (Normalizar Mensaje -> GPT-4o-mini -> Parse JSON
    -> Registrar Interacción) lo clasifique. Las clasificaciones quedan en la
    tabla interactions, escritas por el workflow, no por un INSERT a mano.

    Al terminar CONCILIA los mensajes enviados contra las filas efectivamente
    escritas. Esa conciliación no es opcional: es la condición para que el
    accuracy sea publicable (hallazgo B-6.6 del plan).

    Referencia: docs/PLAN_REGENERACION_EVIDENCIA.md §4 y experiments/E2/README.md

.PARAMETER Corpus
    Ruta al corpus. Por defecto corpus_intents.csv de esta carpeta.

.PARAMETER EspaciadoSeg
    Segundos entre envíos. Por defecto 3, para no golpear el rate limit de OpenAI.

.PARAMETER SinEtiquetas
    Permite ejecutar sin que exista etiquetas_ronda1.csv.
    ROMPE EL PROTOCOLO DE GROUND TRUTH CIEGO: si ejecutás antes de etiquetar,
    podés ver la salida del modelo y el etiquetado deja de ser ciego.
    Existe solo para pruebas de humo del script, nunca para la corrida real.

.PARAMETER DryRun
    Muestra qué se enviaría, sin tocar nada.

.PARAMETER Force
    Omite la confirmación interactiva.

.EXAMPLE
    .\run_flujo2_corpus.ps1 -DryRun
    Verifica entorno y muestra el plan, sin enviar.

.EXAMPLE
    .\run_flujo2_corpus.ps1
    Corrida completa: 150 mensajes, ~8 minutos.
#>

[CmdletBinding()]
param(
    [string]$Corpus       = '',
    [int]   $EspaciadoSeg = 3,
    [switch]$SinEtiquetas,
    [switch]$DryRun,
    [switch]$Force
)

# $PSScriptRoot no está poblado al bindear los parámetros, así que el default
# del corpus se resuelve acá y no en el bloque param.
if (-not $Corpus) { $Corpus = Join-Path $PSScriptRoot 'corpus_intents.csv' }

# Reutiliza Invoke-Psql / Get-Escalar de E1 en vez de duplicarlos.
. (Join-Path $PSScriptRoot '..\E1\_comun.ps1')

$UrlChatbot = 'http://localhost:5678/webhook/whatsapp'
$DirSalida  = Join-Path $PSScriptRoot 'resultados'
$Sello      = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " E2 — Corpus del chatbot por el pipeline real" -ForegroundColor Cyan
Write-Host " Endpoint: $UrlChatbot   espaciado: ${EspaciadoSeg}s" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
#  1. Verificación previa
# ------------------------------------------------------------

function Test-PreflightE2 {
    <#
      Verificaciones propias de E2. Aborta ante lo que invalida la medición.
      No reutiliza Test-Preflight de E1 porque aquella valida el Flujo 1.
    #>
    $estado = @{}
    Write-Host "`n=== Verificación previa ===" -ForegroundColor Cyan

    # --- Docker y contenedores ---
    $prefPrevia = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $nombres = @(& docker ps --format '{{.Names}}' 2>$null) }
    finally { $ErrorActionPreference = $prefPrevia }

    if ($LASTEXITCODE -ne 0) {
        throw "Docker no responde. Levantá el entorno con 'docker compose up -d'."
    }
    foreach ($req in @('tesis_postgres', 'tesis_n8n')) {
        if ($nombres -notcontains $req) {
            throw "El contenedor '$req' no está corriendo. Ejecutá 'docker compose up -d'."
        }
    }
    Write-Host "  [OK] Contenedores arriba"

    $null = Get-Escalar -Sql 'SELECT 1;'
    Write-Host "  [OK] PostgreSQL responde"

    # --- Banco de FAQs: se inyecta como contexto del prompt ---
    $faqs = [int](Get-Escalar -Sql 'SELECT COUNT(*) FROM faq_responses;')
    if ($faqs -lt 1) {
        throw "faq_responses está vacía. El Flujo 2 inyecta las FAQ como contexto del prompt: sin ellas el modelo clasifica en otras condiciones. Cargá seed_catalogo.sql."
    }
    $estado.Faqs = $faqs
    Write-Host "  [OK] Banco de FAQs: $faqs entradas"

    # --- data_source en interactions (B-5) ---
    $tieneDs = (Get-Escalar -Sql @"
SELECT COUNT(*) FROM information_schema.columns
WHERE table_name = 'interactions' AND column_name = 'data_source';
"@) -eq '1'
    $estado.DataSource = $tieneDs
    if ($tieneDs) { Write-Host "  [OK] Columna interactions.data_source presente (B-5)" }
    else { Write-Warning "  interactions.data_source NO existe. Las filas no van a quedar marcadas como 'measured'." }

    # --- Flujo 2 SIMPLE activo ---
    #     Si la consulta falla por un cambio de schema de n8n se degrada a
    #     aviso: no debe bloquear el experimento.
    $estado.FlujoActivo = $null
    try {
        $fila = Invoke-Psql -Tuplas -Sql @"
SELECT active, jsonb_array_length(nodes::jsonb)
FROM workflow_entity
WHERE name LIKE 'Flujo 2%' AND name NOT LIKE '%PRODUCCION%'
ORDER BY "updatedAt" DESC LIMIT 1;
"@
        $campos = (($fila | Where-Object { $_ -ne '' } | Select-Object -First 1) -split "`t")
        if ($campos.Count -ge 2) {
            $estado.FlujoActivo = ($campos[0].Trim() -eq 't')
            if (-not $estado.FlujoActivo) {
                throw "El Flujo 2 SIMPLE está INACTIVO en n8n. Activalo en http://localhost:5678 antes de medir."
            }
            Write-Host "  [OK] Flujo 2 SIMPLE activo ($($campos[1].Trim()) nodos)"
        }
    } catch {
        if ($_.Exception.Message -like '*INACTIVO*') { throw }
        Write-Warning "  No se pudo leer el estado del Flujo 2 desde workflow_entity: $($_.Exception.Message)"
    }

    # --- Credencial de OpenAI (B-6.2) ---
    try {
        $cred = [int](Get-Escalar -Sql "SELECT COUNT(*) FROM credentials_entity WHERE type = 'openAiApi';")
        if ($cred -lt 1) {
            Write-Warning "  No se encontró una credencial de tipo openAiApi. Si el nodo OpenAI no puede autenticar, TODOS los mensajes van a caer al catch de Parse JSON y registrarse como GENERAL."
        } else {
            Write-Host "  [OK] Credencial de OpenAI configurada"
        }
    } catch {
        Write-Warning "  No se pudo verificar la credencial de OpenAI: $($_.Exception.Message)"
    }

    return $estado
}

$estado = Test-PreflightE2

# ------------------------------------------------------------
#  2. Corpus y candado del protocolo ciego
# ------------------------------------------------------------

if (-not (Test-Path $Corpus)) { throw "No existe el corpus: $Corpus" }

$filas = @(Import-Csv -Path $Corpus -Encoding UTF8)
if ($filas.Count -lt 1) { throw "El corpus está vacío." }
foreach ($col in @('id', 'user_id', 'mensaje')) {
    if ($filas[0].PSObject.Properties.Name -notcontains $col) {
        throw "El corpus no tiene la columna '$col'."
    }
}
Write-Host "  [OK] Corpus: $($filas.Count) mensajes"

# El etiquetado humano TIENE que existir antes de correr esto. Si el corpus se
# ejecuta primero, la salida del modelo queda visible y el ground truth deja de
# ser ciego: el experimento pierde su validez y no hay forma de recuperarla.
$rutaEtiquetas = Join-Path $PSScriptRoot 'etiquetas_ronda1.csv'
if (-not (Test-Path $rutaEtiquetas)) {
    if (-not $SinEtiquetas) {
        throw @"
No existe etiquetas_ronda1.csv.

El ground truth humano se construye ANTES de ejecutar el corpus. Si corrés
esto primero, podés ver cómo clasificó el modelo y el etiquetado deja de ser
ciego — que es exactamente el hallazgo A-04 que este experimento viene a cerrar.

Etiquetá primero con experiments/E2/etiquetar.html.
(Si esto es solo una prueba de humo del script, usá -SinEtiquetas.)
"@
    }
    Write-Warning "Corriendo SIN etiquetas_ronda1.csv (-SinEtiquetas). Esta corrida NO sirve como evidencia."
} else {
    $etq = @(Import-Csv -Path $rutaEtiquetas -Encoding UTF8)
    Write-Host "  [OK] Ground truth presente: $($etq.Count) etiquetas"

    if ($etq.Count -ne $filas.Count) {
        Write-Warning "  El ground truth tiene $($etq.Count) etiquetas para $($filas.Count) mensajes del corpus."
    }

    # Control de validez del etiquetado (README §Protocolo). Un etiquetado
    # apurado da un ground truth aleatorio, y el accuracy medido contra eso no
    # mide nada. Se avisa, no se bloquea: la decisión es del anotador.
    if ($etq[0].PSObject.Properties.Name -contains 'segundos') {
        $segs = @($etq | ForEach-Object { [double]$_.segundos } | Sort-Object)
        $mediana = $segs[[int][math]::Floor($segs.Count / 2)]
        if ($mediana -lt 3) {
            Write-Warning "  Mediana de $([math]::Round($mediana,2)) s por mensaje en el etiquetado. Por debajo de ~3 s es dudoso que se hayan leído los mensajes. Revisá el ground truth antes de publicar cualquier accuracy."
        } else {
            Write-Host "  [OK] Etiquetado: mediana $([math]::Round($mediana,1)) s por mensaje"
        }
    }
}

# Filas previas del corpus ya en la BD (por si se re-corre)
$idsCorpus = ($filas | ForEach-Object { "'$($_.user_id)'" }) -join ','
$previas = [int](Get-Escalar -Sql "SELECT COUNT(*) FROM interactions WHERE user_id IN ($idsCorpus);")
if ($previas -gt 0) {
    Write-Warning "Ya hay $previas interacciones en la BD con user_id de este corpus. Una nueva corrida se va a mezclar con la anterior. Limpialas o filtrá por received_at al analizar."
}

# ------------------------------------------------------------
#  3. Confirmación
# ------------------------------------------------------------

$duracionMin = [math]::Round($filas.Count * $EspaciadoSeg / 60, 1)
Write-Host "`n--- Plan ---" -ForegroundColor Yellow
Write-Host "  Mensajes:  $($filas.Count)"
Write-Host "  Espaciado: ${EspaciadoSeg}s  ->  ~$duracionMin minutos"
Write-Host "  Payload:   PLANO {user_id, name, message}  (NO la estructura de WhatsApp Cloud API)"
Write-Host "  Destino:   $UrlChatbot"
Write-Host "  Costo:     ~USD 0,05 en gpt-4o-mini"

if ($DryRun) {
    Write-Host "`n[DryRun] Primeros 5 envíos:" -ForegroundColor Yellow
    $filas | Select-Object -First 5 | ForEach-Object {
        Write-Host "  #$($_.id) [$($_.user_id)] $($_.mensaje)"
    }
    Write-Host "`n[DryRun] No se envió nada." -ForegroundColor Yellow
    return
}

if (-not $Force) {
    $r = Read-Host "`n¿Ejecutar? Consume cuota de OpenAI y escribe en la BD. (s/N)"
    if ($r -notin @('s', 'S', 'si', 'SI', 'sí')) { Write-Host "Cancelado."; return }
}

# ------------------------------------------------------------
#  4. Envío
# ------------------------------------------------------------

if (-not (Test-Path $DirSalida)) { $null = New-Item -ItemType Directory -Path $DirSalida }

$envios = New-Object System.Collections.Generic.List[object]
$i = 0

foreach ($fila in $filas) {
    $i++
    $cuerpo = @{
        user_id = $fila.user_id
        name    = "Anotador E2"
        message = $fila.mensaje
    } | ConvertTo-Json -Compress

    $tEnvio = (Get-Date).ToUniversalTime()
    $cron   = [System.Diagnostics.Stopwatch]::StartNew()
    # $error es variable automática de PowerShell: no se pisa.
    $estadoHttp = $null; $mensajeError = $null

    try {
        $resp = Invoke-WebRequest -Uri $UrlChatbot -Method POST `
                    -ContentType 'application/json; charset=utf-8' `
                    -Body ([System.Text.Encoding]::UTF8.GetBytes($cuerpo)) `
                    -UseBasicParsing -TimeoutSec 60
        $estadoHttp = $resp.StatusCode
    } catch {
        $estadoHttp = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        $mensajeError = $_.Exception.Message
    }
    $cron.Stop()

    $envios.Add([pscustomobject]@{
        id            = $fila.id
        user_id       = $fila.user_id
        mensaje       = $fila.mensaje
        enviado_utc   = $tEnvio.ToString('yyyy-MM-dd HH:mm:ss.fff')
        http          = $estadoHttp
        latencia_ms   = [int]$cron.ElapsedMilliseconds
        error         = $mensajeError
    })

    $marca = if ($estadoHttp -eq 200) { 'OK ' } else { 'ERR' }
    Write-Host ("  [{0,3}/{1}] {2} {3,4}ms  {4}" -f $i, $filas.Count, $marca, $cron.ElapsedMilliseconds, $fila.mensaje.Substring(0, [math]::Min(46, $fila.mensaje.Length)))

    if ($i -lt $filas.Count) { Start-Sleep -Seconds $EspaciadoSeg }
}

$rutaEnvios = Join-Path $DirSalida "e2_envios_$Sello.csv"
$envios | Export-Csv -Path $rutaEnvios -NoTypeInformation -Encoding UTF8
Write-Host "`n  Envios -> $rutaEnvios"

# ------------------------------------------------------------
#  5. Conciliación — B-6.6, sin esto el accuracy no es publicable
# ------------------------------------------------------------

Write-Host "`n=== Conciliación (B-6.6) ===" -ForegroundColor Cyan
Start-Sleep -Seconds 3   # margen para que termine la última ejecución

$okHttp = @($envios | Where-Object { $_.http -eq 200 }).Count
Write-Host "  Enviados con HTTP 200: $okHttp de $($filas.Count)"

# ¿Qué user_id del corpus dejaron fila? Se compara contra los enviados.
$escritos = @(Invoke-Psql -Tuplas -Sql @"
SELECT user_id FROM interactions WHERE user_id IN ($idsCorpus);
"@ | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() })

$faltantes = @($filas | Where-Object { $escritos -notcontains $_.user_id })

Write-Host "  Filas escritas en interactions: $($escritos.Count)"
Write-Host "  Mensajes SIN fila:              $($faltantes.Count)"

if ($faltantes.Count -gt 0) {
    Write-Warning @"
Hay $($faltantes.Count) mensajes enviados que NO dejaron fila en interactions.

Causa mas probable (B-6.6): el modelo devolvio una etiqueta fuera del
vocabulario y el INSERT violo el CHECK (intent IN (...)). Esos casos son
justamente los peores del modelo: si se los deja afuera, DESAPARECEN DEL
DENOMINADOR y el accuracy sube solo.

Hay que explicar cada uno mirando el log de ejecuciones de n8n. Nunca
ignorarlos, y nunca calcular el accuracy sobre los registrados: se informa
sobre los $($filas.Count) ENVIADOS.
"@
    $faltantes | Select-Object id, user_id, mensaje |
        Export-Csv -Path (Join-Path $DirSalida "e2_faltantes_$Sello.csv") -NoTypeInformation -Encoding UTF8
    Write-Host "  Faltantes -> $(Join-Path $DirSalida "e2_faltantes_$Sello.csv")"
}

# Distribución de intents producida por el modelo
Write-Host "`n--- Intents asignados por el modelo ---"
Invoke-Psql -Sql @"
SELECT intent, COUNT(*) AS n,
       ROUND(AVG(EXTRACT(EPOCH FROM (responded_at - received_at)))::numeric, 3) AS tmr_seg
FROM interactions
WHERE user_id IN ($idsCorpus)
GROUP BY intent ORDER BY n DESC;
"@

# Manifiesto de la corrida
[pscustomobject]@{
    experimento    = 'E2'
    sello          = $Sello
    corpus         = (Resolve-Path $Corpus).Path
    corpus_sha256  = (Get-FileHash -Path $Corpus -Algorithm SHA256).Hash
    mensajes       = $filas.Count
    espaciado_seg  = $EspaciadoSeg
    http_ok        = $okHttp
    filas_escritas = $escritos.Count
    faltantes      = $faltantes.Count
    endpoint       = $UrlChatbot
    faqs_contexto  = $estado.Faqs
} | ConvertTo-Json | Set-Content -Path (Join-Path $DirSalida "e2_manifiesto_$Sello.json") -Encoding UTF8

Write-Host "`nListo. Siguiente paso:" -ForegroundColor Green
Write-Host "  python analizar_e2.py"
