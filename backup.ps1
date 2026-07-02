# ============================================================
#  BACKUP — Tesis UTN FRM
#  Guarda credenciales y workflows de n8n desde PostgreSQL
#  Uso: .\backup.ps1
#
#  Nota de implementacion: los dumps se generan DENTRO del
#  contenedor (pg_dump -f / COPY ... TO archivo) y se extraen
#  con `docker cp`. Esto evita que PowerShell 5.1 escriba los
#  archivos en UTF-16 con BOM (que rompe el restore) y resuelve
#  el quoting del identificador "updatedAt".
# ============================================================

$fecha = Get-Date -Format "yyyy-MM-dd_HH-mm"
$dir = "backups\$fecha"
New-Item -ItemType Directory -Path $dir -Force | Out-Null

$ctr = "tesis_postgres"

Write-Host ""
Write-Host "Haciendo backup en: $dir"
Write-Host ""

# ------------------------------------------------------------
# 1. Workflows + credenciales de n8n -> CSV
#    COPY server-side a un archivo del contenedor, luego docker cp.
#    El SQL se manda como archivo (-f) para que las comillas del
#    identificador "updatedAt" sobrevivan intactas.
# ------------------------------------------------------------
Write-Host "[1/5] Exportando workflows y credenciales (CSV)..."
$exportSql = @"
COPY (SELECT id, name, active, nodes, connections, settings, "updatedAt" FROM workflow_entity ORDER BY id) TO '/tmp/n8n_workflows.csv' WITH CSV HEADER;
COPY (SELECT id, name, type, data, "updatedAt" FROM credentials_entity ORDER BY id) TO '/tmp/n8n_credentials.csv' WITH CSV HEADER;
"@
$sqlPath = Join-Path $env:TEMP "n8n_export.sql"
Set-Content -Path $sqlPath -Value $exportSql -Encoding ascii
docker cp $sqlPath "${ctr}:/tmp/n8n_export.sql" | Out-Null
docker exec $ctr psql -U n8n_user -d ecommerce_tesis -v ON_ERROR_STOP=1 -f /tmp/n8n_export.sql
docker cp "${ctr}:/tmp/n8n_workflows.csv"   "$dir\n8n_workflows.csv"
docker cp "${ctr}:/tmp/n8n_credentials.csv" "$dir\n8n_credentials.csv"
Write-Host "      OK -> n8n_workflows.csv / n8n_credentials.csv"

# ------------------------------------------------------------
# 2. Datos de la tesis (tablas propias)
# ------------------------------------------------------------
Write-Host "[2/5] Exportando datos de la tesis..."
docker exec $ctr pg_dump -U n8n_user -d ecommerce_tesis `
    --table=products --table=orders --table=interactions --table=tickets --table=faq_responses `
    --data-only --inserts -f /tmp/tesis_data.sql
docker cp "${ctr}:/tmp/tesis_data.sql" "$dir\tesis_data.sql"
Write-Host "      OK -> tesis_data.sql"

# ------------------------------------------------------------
# 3. Backup completo de la BD (esquema + datos)
# ------------------------------------------------------------
Write-Host "[3/5] Backup completo de PostgreSQL..."
docker exec $ctr pg_dump -U n8n_user -d ecommerce_tesis -f /tmp/full_backup.sql
docker cp "${ctr}:/tmp/full_backup.sql" "$dir\full_backup.sql"
Write-Host "      OK -> full_backup.sql"

# ------------------------------------------------------------
# 4. Copiar JSONs de workflows del repo
# ------------------------------------------------------------
Write-Host "[4/5] Copiando workflows JSON..."
Copy-Item "workflows\*" "$dir\" -ErrorAction SilentlyContinue
Write-Host "      OK -> JSONs copiados"

# ------------------------------------------------------------
# 5. Limpiar temporales del contenedor y del host
# ------------------------------------------------------------
Write-Host "[5/5] Limpiando temporales..."
docker exec $ctr sh -c "rm -f /tmp/n8n_export.sql /tmp/n8n_workflows.csv /tmp/n8n_credentials.csv /tmp/tesis_data.sql /tmp/full_backup.sql" | Out-Null
Remove-Item $sqlPath -ErrorAction SilentlyContinue
Write-Host "      OK"

Write-Host ""
Write-Host "Backup completado en: $dir"
Write-Host ""
