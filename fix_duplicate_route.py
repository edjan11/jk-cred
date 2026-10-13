#!/usr/bin/env python3
# Fix duplicate route in index.html

with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\index.html', 'r', encoding='utf8') as f:
    content = f.read()

# Fix duplicate #/cliente/solicitacoes route
old = """#/cliente/solicitacoes':()=>HistoricoSolicitacoes,
#/cliente/solicitacoes':()=>HistoricoSolicitacoes,
  '#/cliente/solicitar':()=>SimuladorEmprestimo,"""

new = """#/cliente/solicitacoes':()=>HistoricoSolicitacoes,
  '#/cliente/solicitar':()=>SimuladorEmprestimo,"""

if old in content:
    content = content.replace(old, new)
    with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\index.html', 'w', encoding='utf8') as f:
        f.write(content)
    print('Duplicate route fixed')
else:
    print('Pattern not found')
    # Try alternative
    idx = content.find("#/cliente/solicitacoes':()=>HistoricoSolicitacoes,")
    if idx >= 0:
        print(f'Found at index {idx}')
        print('Context:', repr(content[idx:idx+150]))