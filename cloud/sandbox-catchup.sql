-- Sandbox catch-up: migrations 8..11 (idempotent, safe to re-run)

-- ===== migration-8 =====
-- =====================================================================
-- Migration 8 — shared owners (co-ownership) + price offered + block(s) + competitors
-- =====================================================================
alter table public.leads add column if not exists co_owners     uuid[];   -- extra salespeople with equal access
alter table public.leads add column if not exists price_offered text;     -- price quoted to the customer
alter table public.leads add column if not exists blocks        jsonb;    -- blocks of interest, e.g. ["A","C"]
alter table public.leads add column if not exists competitors   text;     -- other projects/competitors in play

-- Let a salesperson also reach leads shared with them (co_owners), with equal access.
drop policy if exists lead_select on public.leads;
create policy lead_select on public.leads for select
  using (
    company_id = public.auth_company_id()
    and (
      public.auth_role() = 'sales_head'
      or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())
      or (public.auth_role() = 'sales' and (owner_id = auth.uid() or auth.uid() = any(co_owners)))
    )
  );

drop policy if exists lead_update on public.leads;
create policy lead_update on public.leads for update
  using (
    company_id = public.auth_company_id()
    and (
      public.auth_role() = 'sales_head'
      or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())
      or (public.auth_role() = 'sales' and (owner_id = auth.uid() or auth.uid() = any(co_owners)))
    )
  )
  with check (company_id = public.auth_company_id());

-- Activity/assessment visibility follows the same rule.
create or replace function public.can_see_lead(p_lead uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.leads l
    where l.id = p_lead
      and l.company_id = public.auth_company_id()
      and (
        public.auth_role() = 'sales_head'
        or (public.auth_role() = 'project_head' and l.project_id = public.auth_project_id())
        or (public.auth_role() = 'sales' and (l.owner_id = auth.uid() or auth.uid() = any(l.co_owners)))
      )
  )
$$;

-- ===== migration-9 =====
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
drop policy if exists pr_select on public.pricing_requests;
create policy pr_select on public.pricing_requests for select
  using (company_id = public.auth_company_id() and (
    public.auth_role() = 'sales_head'
    or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())
    or requested_by = auth.uid()));
drop policy if exists pr_insert on public.pricing_requests;
create policy pr_insert on public.pricing_requests for insert
  with check (company_id = public.auth_company_id() and requested_by = auth.uid());
drop policy if exists pr_update on public.pricing_requests;
create policy pr_update on public.pricing_requests for update
  using (company_id = public.auth_company_id() and (
    public.auth_role() = 'sales_head'
    or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())))
  with check (company_id = public.auth_company_id());

grant select, insert, update, delete on public.pricing_requests to authenticated;

-- ===== migration-10 =====
-- =====================================================================
-- Migration 10 — Wonderwall tracking (proposed at first visit) + conversion
-- =====================================================================
alter table public.leads add column if not exists wonderwall_suggested boolean not null default false;
alter table public.leads add column if not exists wonderwall_visited   boolean not null default false;

-- ===== migration-11 =====
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
