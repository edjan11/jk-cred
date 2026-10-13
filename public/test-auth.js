// JK CRED — Testes de autenticação (rode após deploy: node test-auth.js)
// Requer: npm i node-fetch@2  (ou use fetch nativo do Node 18+)

const BASE = process.env.TEST_BASE || 'https://SEU-APP.netlify.app/.netlify/functions/acesso-cliente';
// Ou se testando Edge Function direto no Supabase:
// const BASE = 'https://SEU-PROJECT.supabase.co/functions/v1/acesso-cliente';

const PHONE_VALID = '(79) 99999-9999';
const PHONE_INVALID = '(79) 9999-9999';
const PASSWORD = 'Senha123';
const PASSWORD_WRONG = 'SenhaErrada';

async function post(action, body) {
  const res = await fetch(BASE, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, ...body })
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}

async function test(name, fn) {
  try { await fn(); console.log(`✅ ${name}`); }
  catch (e) { console.error(`❌ ${name}:`, e.message); }
}

function assert(cond, msg) { if (!cond) throw new Error(msg); }

console.log('=== TESTES DE AUTENTICAÇÃO JK CRED ===\n');

// --- 1. Validação de telefone ---
await test('Login rejeita telefone inválido', async () => {
  const { status, data } = await post('login', { phone: PHONE_INVALID, password: PASSWORD });
  assert(status === 400, `status ${status}`);
  assert(data.error?.includes('telefone válido'), data.error);
});

await test('Recuperar rejeita telefone inválido', async () => {
  const { status, data } = await post('recuperar', { phone: PHONE_INVALID });
  assert(status === 400, `status ${status}`);
  assert(data.error?.includes('telefone válido'), data.error);
});

// --- 2. Login com conta inexistente ---
await test('Login com telefone inexistente → erro genérico (não revela existência)', async () => {
  const { status, data } = await post('login', { phone: PHONE_VALID, password: PASSWORD });
  assert(status === 401, `status ${status}`);
  assert(data.error === 'Telefone ou senha incorretos.', data.error);
});

// --- 3. Recuperar senha com telefone inexistente ---
await test('Recuperar com telefone inexistente → mensagem idêntica (não revela existência)', async () => {
  const { status, data } = await post('recuperar', { phone: PHONE_VALID });
  assert(status === 200, `status ${status}`);
  assert(data.ok === true, data.ok);
  assert(data.message?.includes('Se houver uma conta'), data.message);
});

// --- 4. Rate limiting: login (5 por telefone / 15 min) ---
console.log('\n--- Rate limit login (5 tentativas) ---');
for (let i = 1; i <= 6; i++) {
  const { status, data } = await post('login', { phone: PHONE_VALID, password: PASSWORD });
  if (i <= 5) {
    assert(status === 401, `Tentativa ${i}: esperava 401, veio ${status}`);
    console.log(`  Tentativa ${i}: 401 OK`);
  } else {
    assert(status === 429, `Tentativa ${i}: esperava 429, veio ${status}`);
    assert(data.error?.includes('Muitas tentativas'), data.error);
    console.log(`  Tentativa ${i}: 429 (bloqueado) OK`);
  }
}

// --- 5. Rate limit: recuperar (3 por telefone / 60 min) ---
console.log('\n--- Rate limit recuperar (3 tentativas) ---');
for (let i = 1; i <= 4; i++) {
  const { status, data } = await post('recuperar', { phone: PHONE_VALID });
  if (i <= 3) {
    assert(status === 200, `Tentativa ${i}: esperava 200, veio ${status}`);
    console.log(`  Tentativa ${i}: 200 OK`);
  } else {
    assert(status === 429, `Tentativa ${i}: esperava 429, veio ${status}`);
    console.log(`  Tentativa ${i}: 429 (bloqueado) OK`);
  }
}

// --- 6. Teste de usuário duplicado (precisa de conta real) ---
// Descomente e configure após criar um usuário real no painel do Supabase
/*
const REAL_PHONE = '(79) 98888-7777'; // telefone de um usuário existente
const REAL_PASSWORD = 'SenhaReal123';

await test('Login com usuário real e senha correta → retorna session', async () => {
  const { status, data } = await post('login', { phone: REAL_PHONE, password: REAL_PASSWORD });
  assert(status === 200, `status ${status}`);
  assert(data.session?.access_token, 'sem access_token');
  assert(data.session?.refresh_token, 'sem refresh_token');
  console.log('  Access token:', data.session.access_token.slice(0, 20) + '...');
});

await test('Login com usuário real e senha errada → 401', async () => {
  const { status, data } = await post('login', { phone: REAL_PHONE, password: PASSWORD_WRONG });
  assert(status === 401, `status ${status}`);
  assert(data.error === 'Telefone ou senha incorretos.', data.error);
});

await test('Recuperar com usuário real → 200 e mensagem padrão', async () => {
  const { status, data } = await post('recuperar', { phone: REAL_PHONE });
  assert(status === 200, `status ${status}`);
  assert(data.ok === true, data.ok);
});
*/

// --- 7. Teste de cadastro duplicado (via frontend Supabase client) ---
// Este teste roda no console do navegador na página de cadastro
// Cole no DevTools após carregar a página:
const TESTE_CADASTRO_DUPLICADO_CONSOLE = `
// Teste: tentar cadastrar 2x com mesmo CPF/telefone/email
async function testarCadastroDuplicado() {
  const sb = window.supabase.createClient(
    window.JK_CONFIG.SUPABASE_URL,
    window.JK_CONFIG.SUPABASE_ANON_KEY,
    { auth: { storage: window.sessionStorage } }
  );

  const timestamp = Date.now();
  const baseEmail = 'teste-duplicado-' + timestamp + '@exemplo.com';
  // CPF válido: 123.456.789-09 (algoritmo: 1*10+2*9+3*8+4*7+5*6+6*5+7*4+8*3+9*2 = 210, 210*10%11=1, 10*10%11=1 -> 09)
  const cpfValido = '12345678909';
  const phoneValido = '79999999999';

  const dados = (email) => ({
    email,
    password: 'Senha123',
    options: {
      data: {
        signup_type: 'cliente',
        full_name: 'Usuario Teste Duplicado',
        cpf: cpfValido,
        phone: phoneValido,
        cep: '49000000',
        street: 'Rua Teste',
        number: '123',
        complement: '',
        district: 'Centro',
        city: 'Aracaju',
        state: 'SE',
        card_limit: 1000,
        card_brand: 'visa',
        terms_version: 'rascunho-1',
        privacy_version: 'rascunho-1'
      }
    }
  });

  console.log('=== TESTE 1: Mesmo CPF ===');
  console.log('1ª tentativa...');
  const r1 = await sb.auth.signUp(dados(baseEmail));
  console.log('Resultado 1:', r1.error?.message || 'OK - user criado:', !!r1.data.user);

  console.log('2ª tentativa (mesmo CPF, email diferente)...');
  const r2 = await sb.auth.signUp(dados('outro-' + baseEmail));
  console.log('Resultado 2:', r2.error?.message || 'OK - user criado:', !!r2.data.user);

  if (r2.error && r2.error.message.includes('JK:cpf_ja_cadastrado')) {
    console.log('✅ Bloqueou CPF duplicado corretamente!');
  } else if (r2.error) {
    console.log('⚠️ Erro diferente:', r2.error.message);
  } else {
    console.log('❌ PERMITIU CPF duplicado! Verificar trigger no banco.');
  }

  console.log('\\n=== TESTE 2: Mesmo telefone ===');
  const r3 = await sb.auth.signUp(dados('telefone-' + baseEmail));
  console.log('Resultado 3:', r3.error?.message || 'OK:', !!r3.data.user);

  console.log('2ª tentativa (mesmo telefone)...');
  const r4 = await sb.auth.signUp(dados('telefone2-' + baseEmail));
  console.log('Resultado 4:', r4.error?.message || 'OK:', !!r4.data.user);

  if (r4.error && r4.error.message.includes('JK:telefone_ja_cadastrado')) {
    console.log('✅ Bloqueou telefone duplicado corretamente!');
  } else if (r4.error) {
    console.log('⚠️ Erro diferente:', r4.error.message);
  } else {
    console.log('❌ PERMITIU telefone duplicado!');
  }

  console.log('\\n=== TESTE 3: Mesmo email ===');
  const r5 = await sb.auth.signUp(dados(baseEmail)); // mesmo email do teste 1
  console.log('Resultado 5 (email duplicado):', r5.error?.message || 'OK:', !!r5.data.user);

  if (r5.error && (r5.error.message.includes('JK:email_ja_cadastrado') || r5.error.message.includes('already registered') || r5.error.message.includes('User already registered'))) {
    console.log('✅ Bloqueou email duplicado corretamente!');
  } else if (r5.error) {
    console.log('⚠️ Erro:', r5.error.message);
  } else {
    console.log('❌ PERMITIU email duplicado!');
  }
}
testarCadastroDuplicado();
`;

console.log('\n=== TESTE DE CADASTRO DUPLICADO (rode no console do navegador) ===');
console.log(TESTE_CADASTRO_DUPLICADO_CONSOLE);

console.log('\n=== FIM DOS TESTES AUTOMATIZADOS ===');
console.log('Configure TEST_BASE com a URL da sua Edge Function e rode novamente.');