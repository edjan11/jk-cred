$content = Get-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Raw

$search = "#/cliente/solicitacoes':()=>HistoricoSolicitacoes,"
$indices = @()
$idx = $content.IndexOf($search)
while ($idx -ge 0) {
    $indices += $idx
    $idx = $content.IndexOf($search, $idx + 1)
}

Write-Host "Found at indices: $($indices -join ', ')"

# Remove duplicates (keep first, remove others)
for ($i = $indices.Count - 1; $i -ge 1; $i--) {
    $content = $content.Remove($indices[$i], $search.Length)
    Write-Host "Removed at index $($indices[$i])"
}

Set-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Value $content -Encoding UTF8
Write-Host "Done"