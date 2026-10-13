# JK CRED — App de Empréstimo

Sistema completo de gestão de crédito: cadastro, login, solicitação de empréstimos, painel administrativo.

**Stack:** Vanilla JS (SPA) + Supabase (Auth, Database, Edge Functions) + Netlify (Hosting)

---

## 📁 Estrutura do Projeto

```
jk-cred/
├── .github/workflows/          # CI/CD (futuro)
├── supabase/
│   ├── functions/
│   │   └── acesso-cliente/     # Edge Function: login/recuperação por telefone
│   └── migrations/             # SQL migrations (rodar em ordem)
│       ├── 001_schema.sql      # Tabelas, RLS, triggers, admin_users
│       ├── 002_loan_rules.sql  # Função calc_loan (legacy)
│       ├── 003_loans.sql       # loan_settings, loan_requests, create_loan_request
│       └── 004_update_trigger_and_admin.sql  # Trigger anti-race + admin
├── public/                     # Frontend estático (Netlify publish dir)
│   ├── index.html              # SPA: landing, login, dashboards
│   ├── config.js               # Config Supabase (chaves públicas)
│   ├── auth.js                 # Lógica auth: cadastro, login, sessão
│   ├── loan-rules.js           # Cálculo empréstimo (front-end)
│   ├── loan-rules.test.js      # Testes unitários cálculo
│   └── test-auth.js            # Testes integração Edge Function
├── netlify.toml                # Config Netlify (headers, redirects)
├── package.json                # Scripts de teste/deploy
├── .gitignore
└── README.md
```

---

## 🚀 Setup Local

### Pré-requisitos
- Node.js 18+
- Supabase CLI: `npm i -g supabase`
- Netlify CLI: `npm i -g netlify-cli`

### 1. Clone e configure
```bash
git clone <seu-repo>
cd jk-cred
npm install  # só para scripts, sem dependências de produção
```

### 2. Variáveis de ambiente
Crie `.env.local` na raiz:
```env
SUPABASE_URL=https://SEU_PROJECT.supabase.co
SUPABASE_ANON_KEY=sua_anon_key
SUPABASE_SERVICE_ROLE_KEY=sua_service_role_key
SITE_URL=http://localhost:8888
```

### 3. Supabase (Banco + Edge Function)
```bash
# Link do projeto
supabase link --project-ref SEU_PROJECT_REF

# Rode as migrations no SQL Editor do Dashboard (em ordem):
# 1. supabase/migrations/001_schema.sql
# 2. supabase/migrations/003_loans.sql
# 3. supabase/migrations/004_update_trigger_and_admin.sql

# Crie o 1º admin (após criar user no Auth):
# INSERT INTO public.admin_users (user_id) SELECT id FROM auth.users WHERE email = 'seu@email.com';

# Deploy Edge Function
supabase functions deploy acesso-cliente
# No Dashboard: Functions → acesso-cliente → Settings → Require authentication = OFF
# Adicione env var: SITE_URL = https://seu-app.netlify.app
```

### 4. Frontend Local
```bash
# Terminal 1: Edge Function local
supabase functions serve acesso-cliente --env-file .env.local

# Terminal 2: Frontend (Netlify dev)
netlify dev
# Acesse: http://localhost:8888
```

---

## 🧪 Testes

```bash
# Testes de autenticação (precisa da function deployada)
TEST_BASE=https://SEU_PROJECT.supabase.co/functions/v1/acesso-cliente \
ANON_KEY=sua_anon_key \
node public/test-auth.js

# Testes unitários cálculo empréstimo
node public/loan-rules.test.js
```

---

## 🌐 Deploy Produção

### Netlify
1. Conecte repo no Netlify Dashboard
2. Build command: (vazio)
3. Publish directory: `public`
4. Environment variables:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

### Supabase
- Edge Function já deployada via CLI
- `SITE_URL` = URL do Netlify (ex: `https://jkcred.netlify.app`)

---

## 🔐 Autenticação (Edge Function: `acesso-cliente`)

| Endpoint | Método | Body | Descrição |
|----------|--------|------|-----------|
| Login | POST | `{action:"login", phone:"79999999999", password:"..."}` | Retorna session tokens |
| Recuperar senha | POST | `{action:"recuperar", phone:"79999999999"}` | Envia link por email |

**Segurança:**
- Rate limiting: 5 login/15min por telefone, 30/IP; 3 recuperar/hora
- Validação telefone: regex DDD + 8/9 dígitos
- Senha gerenciada pelo Supabase Auth (hash bcrypt)
- Respostas idênticas para usuário existente/inexistente (não revela existência)

---

## 💰 Regra de Empréstimo

**Fórmula (servidor = fonte da verdade):**
- Encargo inicial: **30%** sobre o valor
- Adicional parcelamento: **R$ 10,00** por parcela após a 1ª
- Tudo calculado em centavos (inteiros) → sem erro de ponto flutuante

**Exemplo:** R$ 1.000,00 em 3x
- Encargo: R$ 300,00 (30%)
- Adicional: R$ 20,00 (2 parcelas × R$ 10)
- Total: R$ 1.320,00
- Parcelas: 3 × R$ 440,00

**Arquivos:**
- Frontend: `public/loan-rules.js` (simulação)
- Backend: `supabase/migrations/003_loans.sql` → `loan_calc()`, `create_loan_request()`

---

## 🗄️ Banco de Dados (Principais Tabelas)

| Tabela | Descrição |
|--------|-----------|
| `profiles` | Dados do cliente (CPF, telefone, endereço, cartão) |
| `admin_users` | Usuários administradores (FK auth.users) |
| `loan_settings` | Regras configuráveis (valores, parcelas, juros) |
| `loan_requests` | Solicitações de empréstimo (status, valores calculados) |
| `auth_attempts` | Controle de tentativas login/recuperar (hashes) |
| `consent_log` | Log de aceite termos/privacidade |

**RLS (Row Level Security):**
- Cliente: lê/edita próprio perfil, lê próprias solicitações
- Admin: lê tudo, altera status solicitações
- Service Role (Edge Function): acesso total (ignora RLS)

---

## 📱 Fluxos Principais

### Cadastro Cliente
1. `/cliente/cadastro` → preenche dados + aceite termos
2. `supabase.auth.signUp()` com metadados → trigger cria `profile`
3. Email confirmação → link para `/redefinir-senha`
4. Define senha → login automático → dashboard

### Login
1. `/cliente/login` → telefone + senha
2. Edge Function valida telefone → busca email no profile
3. `signInWithPassword(email, password)` → session tokens
4. Rate limit: 5 tentativas/15min

### Solicitar Empréstimo (próxima feature)
1. `/cliente/solicitar` → valor, parcelas, 1º vencimento
2. Chama RPC `create_loan_request()` → valida limites + calcula no servidor
3. Retorna protocolo + resumo calculado
4. Admin analisa → aprova/recusa → gera parcelas

---

## 🛠️ Scripts Disponíveis

```bash
npm run test:auth          # Testes integração auth
npm run test:loan-rules    # Testes unitários cálculo
npm run supabase:deploy    # Deploy Edge Function
npm run supabase:serve     # Edge Function local
npm run netlify:dev        # Frontend local
```

---

## 📋 Próximas Features (Roadmap)

1. **Solicitar Empréstimo** (cliente) — UI + RPC `create_loan_request`
2. **Minhas Solicitações** (cliente) — listar + detalhes
3. **Painel Admin: Solicitações** — tabela, filtros, ações
4. **Aprovar/Recusar** (admin) — update status + gerar parcelas
5. **Tabela Parcelas** — migration + geração automática
6. **Cobrança/WhatsApp** — integração futura

---

## 🔗 Links Úteis

- [Supabase Dashboard](https://supabase.com/dashboard/project/cluxbeysuboablzeawnm)
- [Netlify Dashboard](https://app.netlify.com/)
- [Documentação Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Documentação Netlify](https://docs.netlify.com/)

---

**Desenvolvido para JK CRED** — Crédito com clareza, do pedido à última parcela.