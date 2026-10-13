$content = Get-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Raw

# Search for the exact string
$search = "#/cliente/solicitacoes':()=>HistoricoSolicitacoes,"
$idx = $content.IndexOf($search)
$count = 0
while ($idx -ge 0) {
    Write-Host "Found at index $idx"
    $count++
    $idx = $content.IndexOf($search, $idx + 1)
}
Write-Host "Total: $count"