-- =========================================================
-- CONECTCOMPANY - PATCH V4.1 FOLLOW-UP ANTI-BAN
-- Só 2h e 24h. Sem reativação de 3 dias.
-- =========================================================

alter table if exists public.leads_memoria_imobiliaria
  add column if not exists optout boolean default false,
  add column if not exists ultimo_followup_em timestamptz,
  add column if not exists qtd_followups_enviados integer default 0,
  add column if not exists followup_bloqueado_motivo text;

-- Garante que a etapa de 3 dias fique desligada/ignorada.
alter table if exists public.leads_memoria_imobiliaria
  add column if not exists reativacao_3d_enviada boolean default false;

create index if not exists idx_leads_memoria_followup_antiban
on public.leads_memoria_imobiliaria (imobiliaria, followup_1_enviado, followup_24h_enviado, optout, updated_at);

create index if not exists idx_leads_memoria_ultimo_followup
on public.leads_memoria_imobiliaria (ultimo_followup_em);

alter table if exists public.followups_imobiliaria
  add column if not exists antiban_status text,
  add column if not exists antiban_motivo text;

-- Opcional: quando o cliente pedir para parar, marque optout = true manualmente
-- ou crie no workflow principal uma regra para atualizar essa coluna.
-- Exemplo manual:
-- update public.leads_memoria_imobiliaria set optout = true where telefone = '55DDDNUMERO@c.us';
