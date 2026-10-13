$content = Get-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Raw

# Fix duplicate route
$old = """#/cliente/solicitacoes':()=>HistoricoSolicitacoes,
#/cliente/solicitacoes':()=>HistoricoSolicitacoes,
'#/cliente/solicitar':()=>SimuladorEmprestimo,"""

$new = """#/cliente/solicitacoes':()=>HistoricoSolicitacoes,
'#/cliente/solicitar':()=>SimuladorEmprestimo,"""

if ($content.Contains($old)) {
    $content = $content.Replace($old, $new)
    Write-Host "Fixed duplicate route"
} else {
    Write-Host "Route pattern not found"
}

# Also fix AdminNav duplicate entries (the AdminNav.slice(1) adds them again)
# The AdminNav already has the routes, so AdminNav.slice(1) adds duplicates
# Check if routes already have the admin routes
# This is actually OK - AdminNav.slice(1) adds the admin sub-routes to routes object

Set-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Value $content -Encoding UTF8
Write-Host "Done"