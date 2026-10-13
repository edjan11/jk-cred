$content = Get-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Raw

# Fix AdminStub - remove extra ) in template literal
$old = 'const AdminStub=(h)=>{const n=AdminNav.find(x=>x[2]===h);return AdminShell(h,n[1],`<h1>${n[1]}</h1>${Empty(n[0],'"'"'Tela em desenvolvimento'"'"','"'"'Esta seção será construída nas próximas etapas.'"'"',Btn('"'"'Voltar à visão geral'"'"',{href:'"'"'#/admin'"'"',variant:'"'"'ghost'"'"',ico:'"'"'back'"'"'}))}`)};'

$new = 'const AdminStub=(h)=>{const n=AdminNav.find(x=>x[2]===h);return AdminShell(h,n[1],`<h1>${n[1]}</h1>${Empty(n[0],'"'"'Tela em desenvolvimento'"'"','"'"'Esta seção será construída nas próximas etapas.'"'"',Btn('"'"'Voltar à visão geral'"'"',{href:'"'"'#/admin'"'"',variant:'"'"'ghost'"'"',ico:'"'"'back'"'"'}))}`)};'

if ($content.Contains($old)) {
    $content = $content.Replace($old, $new)
    Write-Host "Fixed AdminStub"
} else {
    Write-Host "AdminStub pattern not found"
}

# Fix ClientStub - remove extra )
$old2 = 'const ClientStub=(title,ico)=>`${Topbar(Logo(),`<a class="btn btn-ghost" href="#/cliente">${icon('"'"'back'"'"')}Início</a>`)}<main class="page"><h1>${title}</h1>${Empty(ico,'"'"'Tela em desenvolvimento'"'"','"'"'Esta funcionalidade será implementada nas próximas etapas.'"'"',Btn('"'"'Voltar ao início'"'"',{href:'"'"'#/cliente'"'"',variant:'"'"'ghost'"'"',ico:'"'"'back'"'"'}))}</main>`;'

$new2 = 'const ClientStub=(title,ico)=>`${Topbar(Logo(),`<a class="btn btn-ghost" href="#/cliente">${icon('"'"'back'"'"')}Início</a>`)}<main class="page"><h1>${title}</h1>${Empty(ico,'"'"'Tela em desenvolvimento'"'"','"'"'Esta funcionalidade será implementada nas próximas etapas.'"'"',Btn('"'"'Voltar ao início'"'"',{href:'"'"'#/cliente'"'"',variant:'"'"'ghost'"'"',ico:'"'"'back'"'"'}))}</main>`;'

if ($content.Contains($old2)) {
    $content = $content.Replace($old2, $new2)
    Write-Host "Fixed ClientStub"
} else {
    Write-Host "ClientStub pattern not found"
}

Set-Content 'C:\Users\silvo\Downloads\files\jk-cred\public\index.html' -Value $content -Encoding UTF8
Write-Host "Done"