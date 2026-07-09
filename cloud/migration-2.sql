-- =====================================================================
-- Migration 2 — handoff requests + cross-project interest
-- Safe to run once on the existing Sales Enhancer Supabase project.
-- Adds two tables, their RLS, and two RPCs. Nothing existing is dropped.
-- =====================================================================

-- ---------- 1) Salesperson -> salesperson handoff requests ----------
create table if not exists public.transfer_requests (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete cascade,
  lead_id      uuid not null references public.leads(id) on delete cascade,
  lead_name    text,                                   -- denormalized so the target can see who, without seeing the lead row
  from_member  uuid references public.members(id),
  to_member    uuid not null references public.members(id),
  status       text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  note         text,
  created_at   timestamptz not null default now(),
  resolved_at  timestamptz
);
create index if not exists idx_tr_company on public.transfer_requests(company_id);
create index if not exists idx_tr_lead    on public.transfer_requests(lead_id);
create index if not exists idx_tr_to      on public.transfer_requests(to_member);

alter table public.transfer_requests enable row level security;

-- Visible to: anyone who can see the lead (sales_head / project_head-of-project / current owner)
-- PLUS the person the request is addressed to (they don't own the lead yet).
create policy tr_select on public.transfer_requests for select
  using (company_id = public.auth_company_id()
    and (public.can_see_lead(lead_id) or to_member = auth.uid()));

-- Only the current owner of the lead can raise a request, addressed from themselves.
create policy tr_insert on public.transfer_requests for insert
  with check (company_id = public.auth_company_id()
    and from_member = auth.uid()
    and public.can_see_lead(lead_id));

-- ---------- 2) Cross-project interest referrals ----------
create table if not exists public.cross_interest (
  id                uuid primary key default gen_random_uuid(),
  company_id        uuid not null references public.companies(id) on delete cascade,
  lead_id           uuid not null references public.leads(id) on delete cascade,
  lead_name         text,                              -- denormalized for the target project head
  source_project_id uuid references public.projects(id),
  target_project_id uuid references public.projects(id),
  note              text,
  status            text not null default 'open' check (status in ('open','closed')),
  created_by        uuid references public.members(id),
  created_at        timestamptz not null default now()
);
create index if not exists idx_ci_company on public.cross_interest(company_id);
create index if not exists idx_ci_target  on public.cross_interest(target_project_id);

alter table public.cross_interest enable row level security;

-- Visible to: sales_head (all), the TARGET project's head/reps, and the source side.
create policy ci_select on public.cross_interest for select
  using (company_id = public.auth_company_id()
    and (public.auth_role() = 'sales_head'
      or target_project_id = public.auth_project_id()
      or public.can_see_lead(lead_id)));

create policy ci_insert on public.cross_interest for insert
  with check (company_id = public.auth_company_id()
    and created_by = auth.uid()
    and public.can_see_lead(lead_id));

create policy ci_update on public.cross_interest for update
  using (company_id = public.auth_company_id()
    and (public.auth_role() = 'sales_head'
      or created_by = auth.uid()
      or target_project_id = public.auth_project_id()));

-- ---------- 3) Accept / decline a handoff (SECURITY DEFINER, safe) ----------
create or replace function public.accept_transfer(p_request uuid)
  returns void language plpgsql security definer set search_path = public as $$
declare r public.transfer_requests;
begin
  select * into r from public.transfer_requests where id = p_request and status = 'pending';
  if r.id is null then raise exception 'Request not found or already handled'; end if;
  if r.to_member <> auth.uid() then raise exception 'Not your request to accept'; end if;
  update public.leads
     set owner_id   = r.to_member,
         stage      = case when stage = 'new' then 'assigned' else stage end,
         assigned_at = current_date
   where id = r.lead_id;
  update public.transfer_requests set status = 'accepted', resolved_at = now() where id = r.id;
end $$;

create or replace function public.decline_transfer(p_request uuid)
  returns void language plpgsql security definer set search_path = public as $$
declare r public.transfer_requests;
begin
  select * into r from public.transfer_requests where id = p_request and status = 'pending';
  if r.id is null then raise exception 'Request not found or already handled'; end if;
  if r.to_member <> auth.uid() then raise exception 'Not your request to decline'; end if;
  update public.transfer_requests set status = 'declined', resolved_at = now() where id = r.id;
end $$;

-- ---------- Grants ----------
grant select, insert, update, delete on public.transfer_requests to authenticated;
grant select, insert, update, delete on public.cross_interest    to authenticated;
grant execute on function public.accept_transfer(uuid)  to authenticated;
grant execute on function public.decline_transfer(uuid) to authenticated;
