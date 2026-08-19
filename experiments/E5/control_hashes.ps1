# ============================================================
#  E5 — Control de consistencia de figuras (mata el hallazgo C-02)
# ============================================================
#  C-02 fue: Fig. 3 y Fig. 5 eran la MISMA imagen (hash idéntico).
#  Este script calcula el SHA-256 de cada figura y GRITA si hay dos
#  iguales. Si encuentra un duplicado, sale con código 1 (falla).
#
#  Uso:
#    .\control_hashes.ps1                      # mira .\figuras\
#    .\control_hashes.ps1 -Dir "..\..\docs\fotos\figuras_e5"
#
#  Convención de nombres esperada (para el chequeo de cobertura):
#    flujo1.png   -> Fig. 3 (dashboard Pipeline / Flujo 1, §4.5)
#    mailpit.png  -> Fig. 4 (bandeja Mailpit, @example.com, §4.6.2)
#    flujo2.png   -> figura de resultados del Chatbot / Flujo 2 (§5.2)
# ============================================================
param(
    [string]$Dir = "$PSScriptRoot\figuras"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Dir)) {
    Write-Host "No existe el directorio de figuras: $Dir" -ForegroundColor Red
    Write-Host "Creá la carpeta y guardá ahí fig3_config.png / fig4_mailpit.png / fig5_resultado.png"
    exit 2
}

$imgs = Get-ChildItem -Path $Dir -File -Include *.png,*.jpg,*.jpeg -Recurse
if ($imgs.Count -eq 0) {
    Write-Host "No hay imágenes en $Dir" -ForegroundColor Red
    exit 2
}

Write-Host "== SHA-256 de las figuras en $Dir ==" -ForegroundColor Cyan
$rows = @()
foreach ($f in $imgs) {
    $h = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
    $rows += [pscustomobject]@{ Archivo = $f.Name; SHA256 = $h }
    "{0,-22} {1}" -f $f.Name, $h | Write-Host
}

# --- Detección de duplicados (el corazón del control C-02) ---
$dups = $rows | Group-Object SHA256 | Where-Object { $_.Count -gt 1 }

Write-Host ""
if ($dups) {
    Write-Host "FALLA C-02: hay figuras con hash IDÉNTICO (son la misma imagen):" -ForegroundColor Red
    foreach ($g in $dups) {
        $names = ($g.Group.Archivo -join ", ")
        Write-Host "   $names  =>  $($g.Name)" -ForegroundColor Red
    }
    Write-Host "Recapturá las que estén repetidas: cada figura tiene que ser una captura genuinamente distinta." -ForegroundColor Yellow
    exit 1
}
else {
    Write-Host "OK: las $($imgs.Count) figuras tienen hashes distintos. C-02 no se reproduce." -ForegroundColor Green
}

# --- Cobertura de las 3 figuras esperadas (aviso, no bloquea) ---
$esperadas = @("flujo1", "flujo2", "mailpit")
$faltan = @()
foreach ($e in $esperadas) {
    if (-not ($imgs | Where-Object { $_.BaseName -eq $e })) { $faltan += $e }
}
if ($faltan) {
    Write-Host ""
    Write-Host "Aviso: faltan figuras esperadas: $($faltan -join ', ')" -ForegroundColor Yellow
}
exit 0
