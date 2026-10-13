$content = Get-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Raw

# Find all occurrences of the solicitacoes route in the routes object
$pattern = "#/cliente/solicitacoes':\(\)=>HistoricoSolicitacoes,"
$matches = [System.Text.RegularExpressions.Regex]::Matches($content, [System.Text.RegularExpressions.Regex]::Escape($pattern))

Write-Host "Found $($matches.Count) occurrences"

# Remove duplicates in the routes object (keep first, remove subsequent)
if ($matches.Count -gt 1) {
    # Remove from the last match backwards
    for ($i = $matches.Count - 1; $i -ge 1; $i--) {
        $idx = $matches[$i].Index
        $content = $content.Remove($idx, $matches[$i].Length)
        Write-Host "Removed duplicate at index $idx"
    }
}

Set-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Value $content -Encoding UTF8
Write-Host "Done"