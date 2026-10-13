#!/usr/bin/env python3
# Script para adicionar rotas da Parte 5 no index.html

with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\index.html', 'r', encoding='utf8') as f:
    content = f.read()

# Patterns to find and replace
# Procurar pelo fechamento do objeto routes e inserir novas rotas antes do fecho

# Pattern 1: Encontrar o fechamento do routes object
# O routes termina com "};" na linha 484
pattern_old = "};\nAdminNav.slice"
pattern_new = "  '#admin/emprestimos':()=>AdminLoanControl,\n  '#admin/pagamentos':()=>PaymentRecordingForm,\n  '#admin/emprestimo/:id':(id)=>AdminLoanDetail(id),\n  '#cliente/emprestimo/:protocol':(protocol)=>ClientLoanView(protocol),\n};\nAdminNav.slice"

if pattern_old in content:
    content = content.replace(pattern_old, pattern_new)
    with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\index.html', 'w', encoding='utf8') as f:
        f.write(content)
    print('Sucesso: Rotas da Parte 5 adicionadas')
else:
    print('Padrao nao encontrado - tentando alternativa')
    # Try alternative pattern
    pattern_old2 = "];\nAdminNav.slice"
    pattern_new2 = "  '#admin/emprestimos':()=>AdminLoanControl,\n  '#admin/pagamentos':()=>PaymentRecordingForm,\n  '#admin/emprestimo/:id':(id)=>AdminLoanDetail(id),\n  '#cliente/emprestimo/:protocol':(protocol)=>ClientLoanView(protocol),\n};\nAdminNav.slice"
    
    if pattern_old2 in content:
        content = content.replace(pattern_old2, pattern_new2)
        with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\index.html', 'w', encoding='utf8') as f:
            f.write(content)
        print('Sucesso: Rotas adicionadas (padrao alternativo)')
    else:
        print('Nenhum padrao encontrado')
        # Show what comes after '#admin'
        idx = content.find("#'admin'")
        if idx >= 0:
            print('Contexto encontrado em indice:', idx)
            print('Contexto:', content[idx-20:idx+100])