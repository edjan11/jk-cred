$content = Get-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Raw

# Fix the stray single quotes in routes object
$old = """'
'
  '#/cliente/solicitar':()=>SimuladorEmprestimo,"""

$new = """'#/cliente/solicitar':()=>SimuladorEmprestimo,"""

if ($content.Contains($old)) {
    $content = $content.Replace($old, $new)
    Write-Host "Fixed stray quotes"
} else {
    Write-Host "Pattern not found - trying alternative"
    # Try with different line endings
    $old2 = \"'\n'\n  '#/cliente/solicitar':()=>SimuladorEmprestimo,\"
    if ($content.Contains($old2)) {
        $content = $content.Replace($old2, $new)
        Write-Host "Fixed with alternative"
    } else {
        Write-Host "Still not found - checking raw content around line 1172"
        $idx = $content.IndexOf(\"#/cliente/solicitar':()=>SimuladorEmprestimo,\")
        if (\$idx -ge 0) {
            Write-Host "Found at index \$idx"
            Write-Host "Context: " + \$content.Substring(\$idx - 50, 100)
        }
    }
}

Set-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Value $content -Encoding UTF8
Write-Host "Done"