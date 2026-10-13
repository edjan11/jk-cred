$content = Get-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Raw

# Find and remove the stray single quotes
# The issue is: two lines with just '  (single quote)
# They appear before '#/cliente/solicitar'

$search = "'`n'`n  '#/cliente/solicitar':()=>SimuladorEmprestimo,"
$replace = "#/cliente/solicitar':()=>SimuladorEmprestimo,"

if ($content.Contains($search)) {
    $content = $content.Replace($search, $replace)
    Write-Host "Fixed with CRLF"
} else {
    # Try with LF only
    $search2 = "'`n'`n  '#/cliente/solicitar':()=>SimuladorEmprestimo,"
    if ($content.Contains($search2)) {
        $content = $content.Replace($search2, $replace)
        Write-Host "Fixed with LF"
    } else {
        Write-Host "Search pattern not found, trying regex"
        # Use regex to find and remove lines that are just single quotes
        $content = [System.Text.RegularExpressions.Regex]::Replace($content, "^'\s*$", "", [System.Text.RegularExpressions.RegexOptions]::Multiline)
        Write-Host "Applied regex to remove stray quotes"
    }
}

Set-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Value $content -Encoding UTF8
Write-Host "Done"