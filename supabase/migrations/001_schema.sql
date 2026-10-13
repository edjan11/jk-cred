-- JK CRED — Etapa 1: banco de dados, restrições e segurança (RLS)
-- Cole tudo no SQL Editor do Supabase e clique em "Run". Pode rodar uma vez só.

-- ========== 1. Funções de apoio ==========
create or replace function public.only_digits(t text) returns text
language sql immutable set search_path = public as $$
  select regexp_replace(coalesce(t, ''), '\D', '', 'g')
$$;

create or replace function public.is_valid_cpf(c text) returns boolean
language plpgsql immutable set search_path = public as $$
declare d text := public.only_digits(c); s int; r int;
begin
  if length(d) <> 11 or d ~ '^(\d)\1{10}$' then return false; end if;
  s := 0; for i in 1..9 loop s := s + substr(d, i, 1)::int * (11 - i); end loop;
  r := (s * 10) % 11; if r = 10 then r := 0; end if;
  if r <> substr(d, 10, 1)::int then return false; end if;
  s := 0; for i in 1..10 loop s := s + substr(d, i, 1)::int * (12 - i); end loop;
  r := (s * 10) % 11; if r = 10 then r := 0; end if;
  return r = substr(d, 11, 1)::int;
end $$;

create or replace function public.set_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at := now(); return new; end $$;

-- ========== 2. Tabelas ==========
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null check (char_length(full_name) between 5 and 120),
  email       text not null,
  cpf         char(11) not null,
  phone       text not null,
  cep         char(8) not null check (cep ~ '^[0-9]{8}$'),
  street      text not null check (char_length(street) between 2 and 120),
  number      text not null check (char_length(number) between 1 and 15),
  complement  text check (char_length(complement) <= 80),
  district    text not null check (char_length(district) between 2 and 80),
  city        text not null check (char_length(city) between 2 and 80),
  state       char(2) not null check (state in ('AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO')),
  card_limit  numeric(12,2) not null check (card_limit >= 0 and card_limit <= 10000000),
  card_brand  text not null check (card_brand in ('visa','mastercard','elo','amex','hipercard','diners','outra','nao_informado')),
  status      text not null default 'ativo' check (status in ('ativo','suspenso','bloqueado')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint profiles_cpf_valido check (public.is_valid_cpf(cpf)),
  constraint profiles_phone_valido check (phone ~ '^[1-9][1-9](9[0-9]{8}|[2-9][0-9]{7})$'),
  constraint profiles_cpf_unico unique (cpf),
  constraint profiles_phone_unico unique (phone),
  constraint profiles_email_unico unique (email)
);
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

create table public.consent_log (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  document    text not null check (document in ('termos_de_uso','politica_de_privacidade')),
  version     text not null check (char_length(version) between 1 and 20),
  accepted_at timestamptz not null default now()
);

create table public.admin_users (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Controle de tentativas (usado só pela Edge Function; guarda apenas hashes)
create table public.auth_attempts (
  id         bigint generated always as identity primary key,
  action     text not null,
  phone_hash text not null,
  ip_hash    text not null,
  created_at timestamptz not null default now()
);
create index on public.auth_attempts (action, phone_hash, created_at);
create index on public.auth_attempts (action, ip_hash, created_at);

-- ========== 3. Administrador ==========
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid())
$$;

-- ========== 4. Cadastro automático do perfil (validado no servidor) ==========
-- Só cria perfil quando o cadastro vem do formulário de cliente. Contas criadas
-- pelo painel (ex.: administradores) não são afetadas. Papéis NUNCA vêm dos metadados.
-- EVITA race condition: verifica CPF/telefone/email ANTES de inserir profile.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  cpf_clean text := public.only_digits(m->>'cpf');
  phone_clean text := public.only_digits(m->>'phone');
  email_clean text := lower(new.email);
  existing_profile public.profiles;
begin
  if coalesce(m->>'signup_type', '') <> 'cliente' then return new; end if;
  if coalesce(m->>'terms_version', '') = '' or coalesce(m->>'privacy_version', '') = '' then
    raise exception 'consentimento obrigatorio';
  end if;

  -- Verifica duplicidade ANTES de inserir (evita race condition + user fantasma no Auth)
  select * into existing_profile from public.profiles
   where cpf = cpf_clean or phone = phone_clean or email = email_clean
   limit 1;

  if found then
    -- Erro específico para o frontend tratar
    if existing_profile.cpf = cpf_clean then
      raise exception 'JK:cpf_ja_cadastrado';
    elsif existing_profile.phone = phone_clean then
      raise exception 'JK:telefone_ja_cadastrado';
    else
      raise exception 'JK:email_ja_cadastrado';
    end if;
  end if;

  insert into public.profiles (id, full_name, email, cpf, phone, cep, street, number,
      complement, district, city, state, card_limit, card_brand)
  values (new.id, btrim(m->>'full_name'), email_clean, cpf_clean,
      phone_clean, public.only_digits(m->>'cep'), btrim(m->>'street'),
      btrim(m->>'number'), nullif(btrim(m->>'complement'), ''), btrim(m->>'district'),
      btrim(m->>'city'), upper(btrim(m->>'state')), (m->>'card_limit')::numeric, m->>'card_brand');
  insert into public.consent_log (user_id, document, version) values
      (new.id, 'termos_de_uso', m->>'terms_version'),
      (new.id, 'politica_de_privacidade', m->>'privacy_version');
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ========== 5. Segurança: RLS + permissões mínimas ==========
alter table public.profiles      enable row level security;
alter table public.consent_log   enable row level security;
alter table public.admin_users   enable row level security;
alter table public.auth_attempts enable row level security;

revoke all on public.profiles, public.consent_log, public.admin_users, public.auth_attempts
  from anon, authenticated;

-- Cliente: lê e edita só o próprio perfil (e só colunas não sensíveis)
create policy "cliente le o proprio perfil" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "admin le todos os perfis" on public.profiles
  for select to authenticated using (public.is_admin());
create policy "cliente atualiza o proprio perfil" on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

grant select on public.profiles to authenticated;
grant update (cep, street, number, complement, district, city, state, card_limit, card_brand)
  on public.profiles to authenticated;
-- Sem INSERT/DELETE para clientes. CPF, telefone, e-mail e status não são editáveis por eles.

-- Consentimentos: leitura apenas do próprio histórico
create policy "cliente le os proprios aceites" on public.consent_log
  for select to authenticated using (user_id = (select auth.uid()));
create policy "admin le todos os aceites" on public.consent_log
  for select to authenticated using (public.is_admin());
grant select on public.consent_log to authenticated;

-- admin_users e auth_attempts: sem políticas e sem permissões = inacessíveis pela API
-- (a Edge Function usa a chave de serviço, que fica só no servidor do Supabase)

-- ========== 6. Criar o primeiro administrador (rode DEPOIS de criar o usuário no painel) ==========
-- insert into public.admin_users (user_id)
-- select id from auth.users where email = 'SEU-EMAIL-ADMIN@exemplo.com';
