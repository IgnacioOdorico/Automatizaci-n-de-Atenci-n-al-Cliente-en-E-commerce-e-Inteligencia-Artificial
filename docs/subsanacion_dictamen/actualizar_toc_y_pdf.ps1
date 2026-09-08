# Regenera el indice de Word y exporta el PDF. Word es quien pagina, no un conversor.
$ErrorActionPreference = 'Stop'
$base = 'C:\workspace\University\2026\tesis\Automatizacion-de-Atencion-al-Cliente-en-E-commerce-e-Inteligencia-Artificial\docs\'
$docx = $base + 'TESIS_FINAL_UTN_v6.docx'
$pdf  = $base + 'TESIS_FINAL_UTN_v6.pdf'
$word = New-Object -ComObject Word.Application
$word.Visible = $false; $word.DisplayAlerts = 0
try {
    $doc = $word.Documents.Open($docx, $false, $false)
    foreach ($toc in $doc.TablesOfContents) { $toc.Update() }
    $doc.Fields.Update() | Out-Null
    foreach ($sr in $doc.StoryRanges) { $sr.Fields.Update() | Out-Null }
    $doc.Repaginate()
    Write-Output ("paginas: " + $doc.ComputeStatistics(2) + " | palabras: " + $doc.ComputeStatistics(0))
    $doc.Save()
    # 17 = PDF, con marcadores desde los encabezados
    $doc.ExportAsFixedFormat($pdf, 17, $false, 0, 0, 1, 1, 0, $true, $true, 1)
    $doc.Close($true)
} finally {
    $word.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
}
# la instancia headless a veces queda colgada con su lock; se cierra solo la que no tiene ventana
Start-Sleep -Seconds 2
Get-Process WINWORD -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -eq 0 } | ForEach-Object { $_.Kill() }
Write-Output 'LISTO'
