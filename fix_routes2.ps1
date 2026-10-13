$content = Get-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Raw

# Fix duplicate route - exact match from file
$old = """#/cliente/solicitacoes':()=>HistoricoSolicitacoes,
#/cliente/solicitacoes':()=>HistoricoSolicitacoes,
  '#/cliente/solicitar':()=>SimuladorEmprestimo,"""

$new = """#/cliente/solicitacoes':()=>HistoricoSolicitacoes,
  '#/cliente/solicitar':()=>SimuladorEmprestimo,"""

if ($content.Contains($old)) {
    $content = $content.Replace($old, $new)
    Write-Host "Fixed duplicate route"
} else {
    Write-Host "Route pattern not found - trying alternative"
    # Try with different spacing
    $old2 = \"#/cliente/solicitacoes':()=>HistoricoSolicitacoes,\n#/cliente/solicitacoes':()=>HistoricoSolicitacoes,\n  '#/cliente/solicitar':()=>SimuladorEmprestimo,\"
    if ($content.Contains($old2)) {
        $content = $content.Replace($old2, $new)
        Write-Host "Fixed with alternative pattern"
    } else {
        Write-Host "Still not found"
    }
}

Set-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Value $content -Encoding UTF8
Write-Host "Done"