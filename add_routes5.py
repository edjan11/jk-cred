#!/usr/bin/env python3
import re

with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\index.html', 'r', encoding='utf8') as f:
    content = f.read()

# Find the routes object and add Part 5 routes before the closing ;
# Pattern: the routes object ends with "};" on line 484
# We need to insert new routes before that closing ;

# Strategy: replace the last "};" in the routes section with the new routes + "};"
# Look for the pattern near the end of the file where routes is defined

# Find "#/admin':AdminDash," and add new routes after it
old_pattern = "  '#admin':AdminDash,"
new_pattern = """  '#admin':AdminDash,
  '#admin/emprestimos':()=>AdminLoanControl,
  '#admin/pagamentos':()=>PaymentRecordingForm,
  '#admin/emprestimo/:id':(id)=>AdminLoanDetail(id),
  '#cliente/emprestimo/:protocol':(protocol)=>ClientLoanView(protocol),
"""

if old_pattern in content:
    content = content.replace(old_pattern, new_pattern)
    with open(r'C:\Users\silvo\Downloads\files\jk-cred\public\index.html', 'w', encoding='utf8') as f:
        f.write(content)
    print('Sucesso: Rotas da Parte 5 adicionadas')
else:
    print('Padrao nao encontrado')
    # Try to find where #admin is
    idx = content.find("#'admin'")
    if idx >= 0:
        print('Encontrado em:', idx)
        # Show surrounding context
        start = max(0, idx - 50)
        end = min(len(content), idx + 100)
        print('Contexto:', repr(content[start:end]))