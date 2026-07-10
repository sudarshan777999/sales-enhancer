-- =====================================================================
-- Migration 9 — Referral walk-in source + pricing-approval requests
-- =====================================================================

-- Referral as a walk-in source, with referrer name + optional link to an existing lead
alter table public.leads drop constraint if exists leads_walkin_source_check;
alter table public.leads add constraint leads_walkin_source_check
  check (walkin_source in ('Direct','CP','Referral',''));
alter table public.leads add column if not exists referral_name    text;
alter table public.leads add column if not exists referral_lead_id uuid references public.leads(id) on delete set null;

-- Pricing-approval requests: salesperson sends 3 unit options; heads set pre-final + final price
create table if not exists public.pricing_requests (
  id           uuid primary key default gen_random_uuid(),
  company_id   uuid not null references public.companies(id) on delete cascade,
  lead_id      uuid not null references public.leads(id) on delete cascade,
  lead_name    text,
  project_id   uuid references public.projects(id),
  requested_by uuid references public.members(id),
  units        jsonb,      -- [{unit, prefinal, finalp}]
  note         text,
  status       text not null default 'pending' check (status in ('pending','priced')),
  responded_by uuid references public.members(id),
  created_at   timestamptz not null default now(),
  responded_at timestamptz
);
create index if not exists idx_pr_company on public.pricing_requests(company_id);
alter table public.pricing_requests enable row level security;

-- Visible to: Sales Head, the request's Project Head, and the requester
create policy pr_select on public.pricing_requests for select
  using (company_id = public.auth_company_id() and (
    public.auth_role() = 'sales_head'
    or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())
    or requested_by = auth.uid()));
create policy pr_insert on public.pricing_requests for insert
  with check (company_id = public.auth_company_id() and requested_by = auth.uid());
create policy pr_update on public.pricing_requests for update
  using (company_id = public.auth_company_id() and (
    public.auth_role() = 'sales_head'
    or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())))
  with check (company_id = public.auth_company_id());

grant select, insert, update, delete on public.pricing_requests to authenticated;
