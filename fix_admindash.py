# Fix duplicate AdminDash in index.html
with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\index.html', 'r', encoding='utf8') as f:
    content = f.read()

# Find and remove the first AdminDash (the incomplete one)
old = """</main>`;

const AdminDash=()=>AdminShell('#/admin','Visão geral',`
  <h1>Visão geral</h1><p class="muted">Indicadores da operação. Os números reais serão exibidos quando o sistema estiver conectado aos dados.</p>
  <section class="grid g5">
   ${Stat('users','Total de clientes','—','Aguardando dados')}
   ${Stat('inbox','Solicitações pendentes','—','Aguardando dados')}
   ${Stat('wallet','Empréstimos ativos','—','Aguardando dados')}
   ${Stat('trend','Total a receber','—','Aguardando dados')}
   ${Stat('alert','Parcelas vencidas','—','Aguardando dados')}
  </section>
  <section class="grid g2">
   <article class="card"><div class="section-h"><h2>Evolução da carteira</h2><span class="tag">Placeholder</span></div>
    <div class="chart">${Empty('trend','Gráfico em desenvolvimento','Será preenchido na próxima etapa.')}</div></article>
   <article class="card"><div class="section-h"><h2>Parcelas por status</h2><span class="tag">Placeholder</span></div>
    <div class="chart">${Empty('card','Gráfico em desenvolvimento','Sem dados por enquanto.')}</div></article>
  </section>
  <section class="card" style="margin-top:1.1rem"><div class="section-h"><h2>Atividades recentes</h2></div>
   <div class="table-wrap"><table><thead><tr><th>Data</th><th>Cliente</th><th>Atividade</th><th>Status</th></tr></thead>
   <tbody><tr><td colspan="4">${Empty('doc','Nenhuma atividade registrada','As movimentações da operação aparecerão nesta tabela.')}</td></tr></tbody></table></div></section>`);

const AdminStub=(h)=>{const n=AdminNav.find(x=>x[2]===h);return AdminShell(h,n[1],`<h1>${n[1]}</h1>${Empty(n[0],'Tela em desenvolvimento','Esta seção será construída nas próximas etapas.',Btn('Voltar à visão geral',{href:'#/admin',variant:'ghost',ico:'back'}))}`)};
const ClientStub=(title,ico)=>`${Topbar(Logo(),`<a class="btn btn-ghost" href="#/cliente">${icon('back')}Início</a>`)}<main class="page"><h1>${title}</h1>${Empty(ico,'Tela em desenvolvimento','Esta funcionalidade será implementada nas próximas etapas.',Btn('Voltar ao início',{href:'#/cliente',variant:'ghost',ico:'back'}))}</main>`;

/* ===== Views Administrativas ===== */"""

new = """</main>`;

const AdminStub=(h)=>{const n=AdminNav.find(x=>x[2]===h);return AdminShell(h,n[1],`<h1>${n[1]}</h1>${Empty(n[0],'Tela em desenvolvimento','Esta seção será construída nas próximas etapas.',Btn('Voltar à visão geral',{href:'#/admin',variant:'ghost',ico:'back'}))}`)};
const ClientStub=(title,ico)=>`${Topbar(Logo(),`<a class="btn btn-ghost" href="#/cliente">${icon('back')}Início</a>`)}<main class="page"><h1>${title}</h1>${Empty(ico,'Tela em desenvolvimento','Esta funcionalidade será implementada nas próximas etapas.',Btn('Voltar ao início',{href:'#/cliente',variant:'ghost',ico:'back'}))}</main>`;

/* ===== Views Administrativas ===== */"""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\index.html', 'w', encoding='utf8') as f:
        f.write(content)
    print("✅ Fixed duplicate AdminDash")
else:
    print("❌ Pattern not found")
    # Debug: show what's around the area
    idx = content.find("const AdminDash=()=>AdminShell('#/admin','Visão geral',")
    if idx >= 0:
        print(f"Found AdminDash at index {idx}")
        print("Context:", repr(content[idx-50:idx+200]))