-- JK CRED — Parte 3: regras comerciais e solicitações de empréstimo
-- Cole no SQL Editor e rode UMA vez. Substitui o 002 (a função calc_loan antiga é removida).

drop function if exists public.calc_loan(numeric, int);

-- ========== 1. Regras comerciais configuráveis (uma única linha) ==========
create table public.loan_settings (
  id                    boolean primary key default true check (id),
  min_amount            numeric(12,2) not null default 100.00  check (min_amount > 0),
  max_amount            numeric(12,2) not null default 5000.00,
  max_installments      int           not null default 12      check (max_installments >= 1),
  min_days_first_due    int           not null default 7       check (min_days_first_due >= 0),
  max_days_first_due    int           not null default 45,
  charge_percent        numeric(5,2)  not null default 30.00   check (charge_percent >= 0),
  extra_installment_fee numeric(10,2) not null default 10.00   check (extra_installment_fee >= 0),
  suggested_amounts     numeric[]     not null default '{300,500,1000,1500,2000}',
  updated_at            timestamptz   not null default now(),
  constraint loan_settings_faixas check (max_amount >= min_amount and max_days_first_due >= min_days_first_due)
);
insert into public.loan_settings default values;
create trigger loan_settings_updated_at before update on public.loan_settings
  for each row execute function public.set_updated_at();

-- ========== 2. Solicitações ==========
create table public.loan_requests (
  id                     uuid primary key default gen_random_uuid(),
  protocol               text not null unique,
  user_id                uuid not null references public.profiles(id) on delete restrict,
  requested_amount       numeric(12,2) not null check (requested_amount > 0),
  charge_percent         numeric(5,2)  not null,
  charge_amount          numeric(12,2) not null,
  installments           int           not null check (installments >= 1),
  installment_fee        numeric(12,2) not null,
  effective_percent      numeric(7,2)  not null,
  total_amount           numeric(12,2) not null,
  installment_value      numeric(12,2) not null,
  last_installment_value numeric(12,2) not null,
  first_due_date         date          not null,
  schedule               jsonb         not null,
  status                 text          not null default 'aguardando_analise'
    check (status in ('aguardando_analise','em_analise','aprovada','recusada','aguardando_formalizacao','formalizada','cancelada')),
  idempotency_key        uuid          not null,
  created_at             timestamptz   not null default now(),
  updated_at             timestamptz   not null default now(),
  constraint loan_requests_chave_unica unique (user_id, idempotency_key)
);
create index on public.loan_requests (user_id, created_at desc);
create trigger loan_requests_updated_at before update on public.loan_requests
  for each row execute function public.set_updated_at();

-- ========== 3. Funções ==========
-- Protocolo legível: JK-AAAAMMDD-XXXXXX (sem letras/números ambíguos)
create or replace function public.gen_protocol() returns text
language plpgsql volatile set search_path = public as $$
declare chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; s text := ''; i int;
begin
  for i in 1..6 loop s := s || substr(chars, 1 + floor(random() * 32)::int, 1); end loop;
  return 'JK-' || to_char(now() at time zone 'America/Sao_Paulo', 'YYYYMMDD') || '-' || s;
end $$;

-- ÚNICA fonte da fórmula no servidor: encargo % + valor fixo por parcela após a primeira
create or replace function public.loan_calc(
  p_amount numeric, p_installments int, p_charge_percent numeric, p_extra_fee numeric)
returns table (amount numeric, charge numeric, installment_fee numeric, total numeric,
               effective_percent numeric, installment_value numeric, last_installment_value numeric)
language plpgsql immutable set search_path = public as $$
declare a numeric; c numeric; f numeric; t numeric; b numeric;
begin
  if p_amount is null or p_amount < 0.01 or scale(p_amount) > 2 then raise exception 'JK:valor_invalido'; end if;
  if p_installments is null or p_installments < 1 then raise exception 'JK:parcelas_invalidas'; end if;
  a := p_amount;
  c := round(a * p_charge_percent / 100, 2);   -- encargo inicial
  f := (p_installments - 1) * p_extra_fee;     -- adicional de parcelamento (valor fixo, NÃO percentual)
  t := a + c + f;                              -- total
  b := trunc(t / p_installments, 2);           -- parcela; a última absorve os centavos
  return query select a, c, f, t, round((t - a) / a * 100, 2), b, t - b * (p_installments - 1);
end $$;

-- Cria a solicitação: valida limites, RECALCULA tudo no servidor e evita duplicidade
create or replace function public.create_loan_request(
  p_amount numeric, p_installments int, p_first_due date, p_idempotency_key uuid)
returns public.loan_requests
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); s public.loan_settings; cl record; r public.loan_requests;
  sched jsonb; proto text;
  today date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  if uid is null then raise exception 'JK:nao_autenticado'; end if;
  if p_idempotency_key is null then raise exception 'JK:chave_invalida'; end if;
  if not exists (select 1 from public.profiles where id = uid and status = 'ativo') then
    raise exception 'JK:conta_inativa';
  end if;

  -- mesma chave = mesmo envio (duplo clique, nova tentativa de rede): devolve a existente
  select * into r from public.loan_requests where user_id = uid and idempotency_key = p_idempotency_key;
  if found then return r; end if;

  select * into s from public.loan_settings;
  if p_amount is null or p_amount < s.min_amount or p_amount > s.max_amount then raise exception 'JK:valor_fora_do_limite'; end if;
  if p_installments is null or p_installments < 1 or p_installments > s.max_installments then raise exception 'JK:parcelas_fora_do_limite'; end if;
  if p_first_due is null or p_first_due < today + s.min_days_first_due or p_first_due > today + s.max_days_first_due then
    raise exception 'JK:data_fora_do_limite';
  end if;

  -- mesma simulação, ainda aguardando análise, criada há menos de 10 min = envio duplicado
  select * into r from public.loan_requests
   where user_id = uid and requested_amount = p_amount and installments = p_installments
     and first_due_date = p_first_due and status = 'aguardando_analise'
     and created_at > now() - interval '10 minutes'
   order by created_at desc limit 1;
  if found then return r; end if;

  select * into cl from public.loan_calc(p_amount, p_installments, s.charge_percent, s.extra_installment_fee);

  -- vencimentos mês a mês a partir da data escolhida; dia 31 vira o último dia do mês quando preciso
  select jsonb_agg(jsonb_build_object(
           'n', i,
           'value', case when i = p_installments then cl.last_installment_value else cl.installment_value end,
           'due_date', to_char((p_first_due + (i - 1) * interval '1 month')::date, 'YYYY-MM-DD')) order by i)
    into sched from generate_series(1, p_installments) i;

  loop
    proto := public.gen_protocol();
    begin
      insert into public.loan_requests (protocol, user_id, requested_amount, charge_percent, charge_amount,
          installments, installment_fee, effective_percent, total_amount, installment_value,
          last_installment_value, first_due_date, schedule, idempotency_key)
      values (proto, uid, p_amount, s.charge_percent, cl.charge, p_installments, cl.installment_fee,
          cl.effective_percent, cl.total, cl.installment_value, cl.last_installment_value,
          p_first_due, sched, p_idempotency_key)
      returning * into r;
      return r;
    exception when unique_violation then
      select * into r from public.loan_requests where user_id = uid and idempotency_key = p_idempotency_key;
      if found then return r; end if;
      -- senão foi colisão de protocolo: gera outro e tenta de novo
    end;
  end loop;
end $$;

-- ========== 4. Segurança ==========
alter table public.loan_settings enable row level security;
alter table public.loan_requests enable row level security;
revoke all on public.loan_settings, public.loan_requests from anon, authenticated;

create policy "autenticados leem as regras" on public.loan_settings
  for select to authenticated using (true);
create policy "admin altera as regras" on public.loan_settings
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
grant select, update on public.loan_settings to authenticated;

create policy "cliente le as proprias solicitacoes" on public.loan_requests
  for select to authenticated using (user_id = (select auth.uid()));
create policy "admin le todas as solicitacoes" on public.loan_requests
  for select to authenticated using (public.is_admin());
create policy "admin altera o status" on public.loan_requests
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
grant select on public.loan_requests to authenticated;
grant update (status) on public.loan_requests to authenticated;   -- só a coluna status, e só admin (política acima)
-- Clientes não têm INSERT/DELETE: só criam solicitações pela função create_loan_request.

revoke all on function public.gen_protocol() from public, anon;
revoke all on function public.loan_calc(numeric, int, numeric, numeric) from public, anon;
revoke all on function public.create_loan_request(numeric, int, date, uuid) from public, anon;
grant execute on function public.create_loan_request(numeric, int, date, uuid) to authenticated;

-- ========== 5. Como mudar as regras comerciais (exemplo; valores atuais são PROVISÓRIOS) ==========
-- update public.loan_settings set min_amount = 200, max_amount = 3000, max_installments = 10,
--   min_days_first_due = 5, max_days_first_due = 40, suggested_amounts = '{300,500,1000,2000}';

-- ========== 6. Conferência do cálculo (esperado: 1300/1300, 1310/655, 1320/440, 1340/268) ==========
-- select total, installment_value, last_installment_value from public.loan_calc(1000, 1, 30, 10);
-- select total, installment_value, last_installment_value from public.loan_calc(1000, 2, 30, 10);
-- select total, installment_value, last_installment_value from public.loan_calc(1000, 3, 30, 10);
-- select total, installment_value, last_installment_value from public.loan_calc(1000, 5, 30, 10);
