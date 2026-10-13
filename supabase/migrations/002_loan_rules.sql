-- JK CRED — regra de cálculo do empréstimo no servidor (fonte da verdade)
-- Encargo inicial de 30% + R$ 10,00 fixos por parcela adicional após a primeira.
-- Cole no SQL Editor e rode uma vez. Quando existir a tabela de solicitações (Parte 3),
-- ela deve gravar os valores a partir desta função, ignorando qualquer total vindo do navegador.

create or replace function public.calc_loan(p_amount numeric, p_installments int)
returns table (
  amount numeric, charge numeric, installment_fee numeric, total numeric,
  installments int, installment_value numeric, last_installment_value numeric
)
language plpgsql immutable set search_path = public as $$
declare a numeric; c numeric; f numeric; t numeric; base numeric;
begin
  if p_amount is null or p_amount < 0.01 or scale(p_amount) > 2 then
    raise exception 'valor solicitado invalido';
  end if;
  if p_installments is null or p_installments < 1 then
    raise exception 'quantidade de parcelas invalida';
  end if;
  a := p_amount;
  c := round(a * 0.30, 2);                 -- encargo inicial
  f := (p_installments - 1) * 10.00;       -- adicional de parcelamento
  t := a + c + f;                          -- valor total
  base := trunc(t / p_installments, 2);    -- parcela; a última absorve os centavos
  return query select a, c, f, t, p_installments, base, t - base * (p_installments - 1);
end $$;

revoke all on function public.calc_loan(numeric, int) from public, anon;
grant execute on function public.calc_loan(numeric, int) to authenticated;

-- Conferência (esperado: 1320.00 / 440.00 e 1340.00 / 268.00):
-- select * from public.calc_loan(1000, 3);
-- select * from public.calc_loan(1000, 5);
