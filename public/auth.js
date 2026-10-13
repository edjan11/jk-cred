/* JK CRED — auth.js: cadastro, login, recuperação e sessão (Supabase). Carregado depois do app. */
(() => {
const C = window.JK_CONFIG || {};
const TERMS = 'rascunho-1'; // troque pela versão real quando os documentos oficiais existirem
const $ = (s, r = document) => r.querySelector(s);
const d = v => String(v || '').replace(/\D/g, '');
const S = { user: null, profile: null, admin: false, msg: null };
const P = {};

if (!window.supabase || !C.SUPABASE_URL) {
  document.getElementById('app').textContent = 'Configuração do Supabase ausente (config.js).';
  return;
}
// Sessão só em sessionStorage (some ao fechar a aba). Nenhum dado pessoal é guardado no navegador.
const sb = window.supabase.createClient(C.SUPABASE_URL, C.SUPABASE_ANON_KEY, {
  auth: { storage: window.sessionStorage, persistSession: true, autoRefreshToken: true, detectSessionInUrl: false },
});

Object.assign(P, {
  eye: '<path d="M2 12s3.6-7 10-7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  eyeoff: '<path d="M3 3l18 18M10.6 5.1A10 10 0 0112 5c6.4 0 10 7 10 7a17 17 0 01-3.2 4M6.6 6.6C3.7 8.4 2 12 2 12s3.6 7 10 7c1.6 0 3-.4 4.3-1M9.9 9.9a3 3 0 004.2 4.2"/>',
  phone: '<rect x="6.5" y="2.5" width="11" height="19" rx="2.5"/><path d="M11 18.5h2"/>',
  pin: '<path d="M12 21s7-5.6 7-11a7 7 0 10-14 0c0 5.4 7 11 7 11z"/><circle cx="12" cy="10" r="2.5"/>',
});

/* ---------- máscaras e validações ---------- */
const mask = {
  cpf: v => d(v).slice(0, 11).replace(/(\d{3})(\d)/, '$1.$2').replace(/(\d{3})(\d)/, '$1.$2').replace(/(\d{3})(\d{1,2})$/, '$1-$2'),
  tel: v => { v = d(v).slice(0, 11); return v.length > 10 ? v.replace(/(\d{2})(\d{5})(\d{0,4})/, '($1) $2-$3') : v.length > 6 ? v.replace(/(\d{2})(\d{4})(\d{0,4})/, '($1) $2-$3') : v.length > 2 ? v.replace(/(\d{2})(\d+)/, '($1) $2') : v; },
  cep: v => d(v).slice(0, 8).replace(/(\d{5})(\d)/, '$1-$2'),
  brl: v => { const n = d(v).slice(0, 11); return n ? (Number(n) / 100).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) : '' },
  simulador: v => { const n = Number(v); return isNaN(n) ? '0,00' : n.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) },
  parcela: v => { const n = Number(v); return isNaN(n) ? '0,00' : n.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }
};

/* ---------- cálculo de empréstimo ---------- */
const CHARGE_RATE_PERCENT = 30;
const EXTRA_INSTALLMENT_FEE = 1000; // centavos (R$ 10,00) por parcela após a primeira

function calcularEmprestimo(valor, parcelas) {
  const cents = Math.round(Number(valor) * 100);
  if (!Number.isFinite(valor) || cents < 1) throw new Error('Valor inválido');
  if (!Number.isInteger(parcelas) || parcelas < 1) throw new Error('Parcelas inválidas');
  const charge = Math.round(cents * CHARGE_RATE_PERCENT / 100);
  const installmentFee = (parcelas - 1) * EXTRA_INSTALLMENT_FEE;
  const total = cents + charge + installmentFee;
  const base = Math.floor(total / parcelas);
  const last = total - base * (parcelas - 1);
  const installmentValue = parcelas === 1 ? total : base;
  const effectivePercent = Math.round(((charge + installmentFee) / cents) * 100 * 100) / 100;
  return {
    valorSolicitado: Number(valor).toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'}),
    valorTotal: Number(total).toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'}),
    valorParcela: Number(installmentValue).toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'}),
    ultimoValor: Number(last).toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'}),
    encargoInicial: Number(charge).toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'}),
    adicionalParcelamento: Number(installmentFee / 100).toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'}),
    totalEncargos: Number(charge + installmentFee).toLocaleString('pt-BR', {style: 'currency', currency: 'BRL'}),
    percentualEfetivo: effectivePercent + '%',
    cronograma: cronogramaFracionamento(parcelas, total, new Date())
  };
}

function cronogramaFracionamento(parcelas, total, dataInicial) {
  const cronograma = [];
  let data = new Date(dataInicial);
  for (let i = 1; i <= parcelas; i++) {
    let vencimento = new Date(data);
    vencimento.setMonth(vencimento.getMonth() + i);
    let dia = Math.min(31, vencimento.getMonth() === 1 ? 28 : vencimento.getMonth() === 3 || vencimento.getMonth() === 5 || vencimento.getMonth() === 8 || vencimento.getMonth() === 10 ? 31 : vencimento.getMonth() === 12 ? 31 : 30);
    cronograma.push({ parcela: i, valor: Number((total / parcelas).toFixed(2)), vencimento: dia + '/' + (vencimento.getMonth() + 1).toString().padStart(2, '0') + '/' + vencimento.getFullYear() });
  }
  return cronograma;
}

/* ---------- mensagem WhatsApp ---------- */
function gerarMensagemWhatsApp(cliente, simulacao) {
  const {nome, cpf, telefone, endereco} = cliente;
  const {valorSolicitado, valorTotal, valorParcela, encargoInicial, adicionalParcelamento, percentualEfetivo, cronograma, parcelas} = simulacao;
  let itensParcelas = '';
  cronograma.forEach(p => { itensParcelas += 'Parcela ' + p.parcela + ': R$ ' + Number(p.valor).toLocaleString('pt-BR', {style:'currency',currency:'BRL'}) + ' — Vencimento: ' + p.vencimento + '\n'; });
  const cpfMasked = cpf ? cpf.replace(/^(\d{3})\d{3}(\d{3})$/ , '$1***$3') : 'Não informado';
  const enderecoResumido = endereco ? endereco.split(',').slice(0,2).join(', ') : 'Não informado';
  return 'Olá! Gostaria de solicitar uma análise de empréstimo com a JK CRED.\n\n'
  + '━━━━━━━━━━━━━━━━━━\n'
  + 'DADOS DO CLIENTE\n'
  + '━━━━━━━━━━━━━━━━━━\n'
  + 'Nome completo: ' + nome + '\n'
  + 'CPF: ' + cpfMasked + '\n'
  + 'Telefone: ' + telefone + '\n'
  + 'Endereço: ' + enderecoResumido + '\n\n'
  + '━━━━━━━━━━━━━━━━━━\n'
  + 'DADOS DO EMPRÉSTIMO\n'
  + '━━━━━━━━━━━━━━━━━━\n'
  + 'Valor solicitado: ' + valorSolicitado + '\n'
  + 'Percentual inicial: 30%\n'
  + 'Valor do acréscimo inicial: ' + encargoInicial + '\n\n'
  + 'Quantidade de parcelas: ' + parcelas + '\n'
  + 'Adicional por parcelamento: ' + adicionalParcelamento + '\n'
  + 'Total de encargos: ' + Number(encargoInicial) + Number(adicionalParcelamento).toLocaleString('pt-BR', {style:'currency',currency:'BRL'}) + '\n'
  + 'Percentual efetivo total dos encargos: ' + percentualEfetivo + '\n\n'
  + 'Valor total estimado a pagar: ' + valorTotal + '\n'
  + 'Valor das parcelas: ' + valorParcela + '\n\n'
  + '━━━━━━━━━━━━━━━━━━\n'
  + 'CRONOGRAMA DE PAGAMENTO\n'
  + '━━━━━━━━━━━━━━━━━━\n'
  + itensParcelas + '\n'
  + '━━━━━━━━━━━━━━━━━━\n'
  + 'RESUMO DA SOLICITAÇÃO\n'
  + '━━━━━━━━━━━━━━━━━━\n'
  + 'Protocolo: ' + gerarProtocolo() + '\n'
  + 'Data da solicitação: ' + new Date().toLocaleDateString('pt-BR') + '\n'
  + 'Status: Aguardando análise e aprovação.\n\n'
  + 'Gostaria de receber informações sobre a análise e os próximos passos para a formalização do empréstimo.\n'
  + 'Obrigado!';
}

function gerarProtocolo() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 6; i++) { s += chars[Math.floor(Math.random() * chars.length)]; }
  return 'JK-' + new Date().toLocaleString('pt-BR', {timeZone: 'America/Sao_Paulo'}).replace('/','').replace('/','').padStart(6,'0') + '-' + s;
}

// ✅ Setup do objeto JKAuth esperado pelo render()
window.JKAuth = {
  ready: true,
  user: S.user,
  profile: S.profile,
  admin: S.admin,
  redirectFor: function(h0) {
    // Rotas públicas que não precisam de login
    const publicRoutes = ['#/', '#/login', '#/cadastro', '#/recuperar'];
    if (publicRoutes.includes(h0)) return h0;
    
    // Se não estiver logado e tentar acessar rota protegida, redireciona para login
    if (!S.user && h0.startsWith('#/')) return '#/login';
    return h0;
  },
  logout: function() {
    S.user = null;
    S.profile = null;
    S.admin = false;
    localStorage.removeItem('jk-session');
    location.hash = '#/login';
  },
  bind: function(path) {
    // Pode ser usado para armazenar qual rota o usuário estava tentando acessar
    localStorage.setItem('jk-last-path', path);
  }
};
})();