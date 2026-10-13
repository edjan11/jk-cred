$content = Get-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Raw

# 1. Fix duplicate HistoricoSolicitacoes - remove the second one
# The first one is around line 410, second around line 1164
# Find both occurrences and keep only the first
$idx1 = $content.IndexOf("const HistoricoSolicitacoes")
$idx2 = $content.LastIndexOf("const HistoricoSolicitacoes")

if ($idx1 -ne $idx2) {
    # Find the end of the second one
    $endIdx = $content.IndexOf("};", $idx2)
    if ($endIdx -ge 0) {
        $endIdx += 2  # Include };
        $content = $content.Remove($idx2, $endIdx - $idx2)
        Write-Host "Removed duplicate HistoricoSolicitacoes at index $idx2"
    }
}

# 2. Verify routes object is correct
# 3. Save
Set-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Value $content -Encoding UTF8
Write-Host "Done"