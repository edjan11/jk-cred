#!/usr/bin/env python3
# Fix duplicate AdminShell and add P to auth.js

# Fix 1: Remove duplicate AdminShell from index.html
with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\index.html', 'r', encoding='utf8') as f:
    content = f.read()

# Remove the first AdminShell (lines around 261-266)
old_shell = """</main>`;
const AdminShell=(current,title,body)=>`<div class="shell" id="shell"><aside class="side-nav">${Logo()}
  <nav aria-label="Menu administrativo">${AdminNav.map(([i,l,h])=>`<a href="${h}" class="${h===current?'on':''}">${icon(i)}${l}</a>`).join('')}</nav>
  <nav class="exit"><a href="#/sair">${icon('out')}Sair</a></nav></aside><div class="scrim" id="scrim"></div>
  <div>
  ${Topbar(`<button class="menu-btn" id="menuBtn" aria-label="Abrir menu">${icon('menu')}</button><strong>${title}</strong>`,'<div class="avatar" aria-hidden="true">A</div>')}
  <main class="page">${body}</main></div></div>`;

const AdminDash=()=>AdminShell('#/admin','Visão geral',`"""

new_shell = """</main>`;

const AdminDash=()=>AdminShell('#/admin','Visão geral',`"""

if old_shell in content:
    content = content.replace(old_shell, new_shell)
    print("✅ Removed duplicate AdminShell")
else:
    print("❌ AdminShell pattern not found")

with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\index.html', 'w', encoding='utf8') as f:
    f.write(content)

# Fix 2: Add P definition to auth.js
with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\auth.js', 'r', encoding='utf8') as f:
    auth_content = f.read()

# Add P definition after the S object
old_s = """const S = { user: null, profile: null, admin: false, msg: null };"""

new_s = """const S = { user: null, profile: null, admin: false, msg: null };
const P = {};"""

if old_s in auth_content:
    auth_content = auth_content.replace(old_s, new_s)
    print("✅ Added P definition to auth.js")
else:
    print("❌ S pattern not found in auth.js")

with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\auth.js', 'w', encoding='utf8') as f:
    f.write(auth_content)

print("Done!")