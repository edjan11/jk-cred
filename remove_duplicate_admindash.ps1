$content = Get-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Raw

# Find the first AdminDash and remove it (keep the second one which is complete)
# The first one ends with ");`n`nconst AdminStub"
# The second one is after AdminShell definition

$idx1 = $content.IndexOf("const AdminDash=()=>AdminShell('#/admin','Visão geral',")
if ($idx1 -ge 0) {
    # Find the end of first AdminDash - look for ");\n\nconst AdminStub"
    $endIdx = $content.IndexOf(");`n`nconst AdminStub", $idx1)
    if ($endIdx -ge 0) {
        $endIdx += ");`n`n".Length  # Include the closing ); and newlines
        $content = $content.Remove($idx1, $endIdx - $idx1)
        Set-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Value $content -Encoding UTF8
        Write-Host "Removed first AdminDash (index $idx1 to $endIdx)"
    } else {
        Write-Host "Could not find end of first AdminDash"
    }
} else {
    Write-Host "First AdminDash not found"
}