// JK CRED — Edge Function "acesso-cliente"
// Faz login por telefone + senha e recuperação de senha por telefone.
// A senha é validada pelo Supabase Auth (hash gerenciado por ele). Nada de senha é salvo aqui.
import { createClient } from "npm:@supabase/supabase-js@2";

const URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // injetada pelo Supabase; nunca vai ao navegador
const SITE = Deno.env.get("SITE_URL") ?? "*";

const cors = {
  "Access-Control-Allow-Origin": SITE,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
const opts = { auth: { persistSession: false, autoRefreshToken: false } };
const sha = async (t: string) =>
  [...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(t)))]
    .map((b) => b.toString(16).padStart(2, "0")).join("");

// Limpeza periódica de tentativas antigas (roda a cada requisição, barato)
async function cleanupOldAttempts(admin: ReturnType<typeof createClient>) {
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(); // 24h
  await admin.from("auth_attempts").delete().lt("created_at", cutoff);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Método não permitido." }, 405);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Requisição inválida." }, 400); }

  const action = body.action === "recuperar" ? "recuperar" : "login";
  const phone = String(body.phone ?? "").replace(/\D/g, "");
  if (!/^[1-9][1-9](9[0-9]{8}|[2-9][0-9]{7})$/.test(phone)) return json({ error: "Informe um telefone válido com DDD." }, 400);

  const admin = createClient(URL, SERVICE, opts);
  const ip = (req.headers.get("x-forwarded-for") ?? "desconhecido").split(",")[0].trim();
  const phoneHash = await sha("tel:" + phone);
  const ipHash = await sha("ip:" + ip);

  // Limite de tentativas: login = 5 por telefone / 30 por IP em 15 min; recuperação = 3 / 10 por hora
  const [minutes, maxPhone, maxIp] = action === "login" ? [15, 5, 30] : [60, 3, 10];
  const since = new Date(Date.now() - minutes * 60000).toISOString();
  const countBy = async (col: string, val: string) => {
    const { count } = await admin.from("auth_attempts").select("id", { count: "exact", head: true })
      .eq("action", action).eq(col, val).gte("created_at", since);
    return count ?? 0;
  };
  if ((await countBy("phone_hash", phoneHash)) >= maxPhone || (await countBy("ip_hash", ipHash)) >= maxIp) {
    return json({ error: "Muitas tentativas. Aguarde alguns minutos e tente novamente." }, 429);
  }
  const record = () => admin.from("auth_attempts").insert({ action, phone_hash: phoneHash, ip_hash: ipHash });

  const { data: prof } = await admin.from("profiles").select("email,status").eq("phone", phone).maybeSingle();
  const email = prof && prof.status === "ativo" ? prof.email : null;

  if (action === "recuperar") {
    await record();
    if (email) await createClient(URL, ANON, opts).auth.resetPasswordForEmail(email);
    // Resposta idêntica exista a conta ou não (não revela quem é cliente)
    await cleanupOldAttempts(admin);
    return json({ ok: true, message: "Se houver uma conta com esse telefone, enviamos um link para o e-mail cadastrado." });
  }

  const password = String(body.password ?? "");
  const fail = async () => { await record(); return json({ error: "Telefone ou senha incorretos." }, 401); };
  if (!email || !password) return await fail();

  const { data, error } = await createClient(URL, ANON, opts).auth.signInWithPassword({ email, password });
  if (error || !data.session) {
    if (error?.code === "email_not_confirmed") {
      return json({ error: "Confirme seu e-mail antes de entrar. Verifique sua caixa de entrada." }, 403);
    }
    return await fail();
  }
  await admin.from("auth_attempts").delete().eq("action", "login").eq("phone_hash", phoneHash);
  await cleanupOldAttempts(admin);
  return json({ session: { access_token: data.session.access_token, refresh_token: data.session.refresh_token } });
});
