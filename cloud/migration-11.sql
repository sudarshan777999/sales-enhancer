-- =====================================================================
-- Migration 11 — "lost to competitor" + team group chat
-- =====================================================================
alter table public.leads add column if not exists lost_to text;   -- competitor we lost the deal to

create table if not exists public.messages (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  member_id  uuid references public.members(id),
  body       text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_msg on public.messages(company_id, created_at);
alter table public.messages enable row level security;
drop policy if exists msg_select on public.messages;
create policy msg_select on public.messages for select using (company_id = public.auth_company_id());
drop policy if exists msg_insert on public.messages;
create policy msg_insert on public.messages for insert with check (company_id = public.auth_company_id() and member_id = auth.uid());
grant select, insert, update, delete on public.messages to authenticated;
