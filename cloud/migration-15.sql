-- =====================================================================
-- Migration 15 — assignable tasks (a head asks the walk-in's owner for info)
-- =====================================================================
-- A head assigns a task (a question / to-do) to the lead's owner. The owner
-- answers in a text box and marks it done. Surfaces as a floating label.
create table if not exists public.tasks (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  lead_id     uuid not null references public.leads(id) on delete cascade,
  lead_name   text,
  assigned_to uuid references public.members(id),   -- the walk-in's owner
  assigned_by uuid references public.members(id),   -- the head who set it
  body        text not null,
  status      text not null default 'open' check (status in ('open','done')),
  response    text default '',
  created_at  timestamptz not null default now(),
  done_at     timestamptz
);
create index if not exists idx_tasks_company on public.tasks(company_id);
create index if not exists idx_tasks_lead on public.tasks(lead_id);
alter table public.tasks enable row level security;

-- Read: the assignee, the assigner, or anyone who can already see the lead
drop policy if exists tasks_select on public.tasks;
create policy tasks_select on public.tasks for select using (
  company_id = public.auth_company_id() and (
    assigned_to = auth.uid() or assigned_by = auth.uid() or public.can_see_lead(lead_id)));

-- Create: heads only, on a lead they can see, as themselves
drop policy if exists tasks_insert on public.tasks;
create policy tasks_insert on public.tasks for insert with check (
  company_id = public.auth_company_id() and assigned_by = auth.uid()
  and public.auth_role() in ('sales_head','project_head') and public.can_see_lead(lead_id));

-- Update (respond / mark done): the assignee, the assigner, or a head who can see the lead
drop policy if exists tasks_update on public.tasks;
create policy tasks_update on public.tasks for update using (
  company_id = public.auth_company_id() and (
    assigned_to = auth.uid() or assigned_by = auth.uid() or public.can_see_lead(lead_id)))
  with check (company_id = public.auth_company_id());

grant select, insert, update, delete on public.tasks to authenticated;
