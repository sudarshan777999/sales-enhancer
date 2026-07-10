-- Sandbox one-shot setup: full schema + migrations 2..11

-- =====================================================================
-- Sales Enhancer — multi-tenant schema for Supabase (Postgres)
-- Run this in the Supabase SQL editor on a fresh project.
-- Tenancy: every row carries company_id; Row Level Security (RLS)
-- guarantees a user can only ever touch their own company's data.
-- Auth: Supabase Auth (email + password, email-based reset) owns auth.users.
-- =====================================================================

-- ---------- Tables ----------

create table public.companies (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,                         -- e.g. "Bricks & Milestones"
  plan          text not null default 'trial',         -- billing slot for later (trial|pro|...)
  status        text not null default 'active',        -- active|suspended
  created_at    timestamptz not null default now()
);

create table public.projects (
  id            uuid primary key default gen_random_uuid(),
  company_id    uuid not null references public.companies(id) on delete cascade,
  name          text not null,                         -- e.g. "Earthscape", "Solcrest"
  created_at    timestamptz not null default now()
);

-- One row per user; id == auth.users.id. Role + project scope live here.
create table public.members (
  id            uuid primary key references auth.users(id) on delete cascade,
  company_id    uuid not null references public.companies(id) on delete cascade,
  name          text not null,
  email         text,
  role          text not null check (role in ('sales_head','project_head','sales')),
  project_id    uuid references public.projects(id),   -- scope for project_head / sales
  created_at    timestamptz not null default now()
);

create table public.leads (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  project_id     uuid references public.projects(id),
  owner_id       uuid references public.members(id),    -- null = unassigned / disqualified pool
  name           text not null,
  phone          text not null,
  email          text,
  source         text not null check (source in ('digital','walkin')),
  src_detail     text,
  walkin_source  text check (walkin_source in ('Direct','CP','')),  -- walk-ins only
  cp_name        text,
  location       text,
  company_name   text,                                  -- the customer's employer (walk-ins)
  budget         text,
  notes          text,
  stage          text not null default 'new'
                  check (stage in ('new','assigned','qualified','booked','lost','not_qualified')),
  qualified      boolean,                               -- null=undecided, true, false
  nq_reason      text,
  disqualified_by text,
  lost_reason    text,
  temp           text check (temp in ('Hot','Warm','Cold')),
  next_follow_up date,
  assigned_at    date,                                  -- drives the 7-day decision SLA
  created_at     date not null default current_date     -- == walk-in date for walk-ins
);

-- The chronological history: notes, follow-ups, revisits, and system events.
create table public.lead_activity (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  lead_id        uuid not null references public.leads(id) on delete cascade,
  kind           text not null check (kind in ('note','revisit','system')),
  body           text,                                  -- the comment / description
  next_follow_up date,                                  -- set when kind='note' schedules a reminder
  author_id      uuid references public.members(id),
  created_at     timestamptz not null default now()
);

-- Optional: AI closing-likelihood history.
create table public.assessments (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  lead_id        uuid not null references public.leads(id) on delete cascade,
  likelihood     int,
  temperature    text,
  rationale      text,
  signals        jsonb,
  created_at     timestamptz not null default now()
);

-- Team invitations (Phase 2 onboarding).
create table public.invitations (
  id             uuid primary key default gen_random_uuid(),
  company_id     uuid not null references public.companies(id) on delete cascade,
  email          text not null,
  role           text not null check (role in ('sales_head','project_head','sales')),
  project_id     uuid references public.projects(id),
  token          uuid not null default gen_random_uuid(),
  status         text not null default 'pending',       -- pending|accepted|revoked
  created_at     timestamptz not null default now()
);

create index on public.projects(company_id);
create index on public.members(company_id);
create index on public.leads(company_id);
create index on public.leads(owner_id);
create index on public.leads(project_id);
create index on public.leads(stage);
create index on public.leads(next_follow_up);
create index on public.lead_activity(lead_id);
create index on public.lead_activity(company_id);

-- ---------- Helper functions (SECURITY DEFINER so they bypass RLS safely) ----------
-- These read the caller's own membership to answer "which company / role / project am I?".

create or replace function public.auth_company_id() returns uuid
  language sql stable security definer set search_path = public as $$
  select company_id from public.members where id = auth.uid()
$$;

create or replace function public.auth_role() returns text
  language sql stable security definer set search_path = public as $$
  select role from public.members where id = auth.uid()
$$;

create or replace function public.auth_project_id() returns uuid
  language sql stable security definer set search_path = public as $$
  select project_id from public.members where id = auth.uid()
$$;

-- Central "can this user see this lead?" rule, reused by activity/assessment policies.
create or replace function public.can_see_lead(p_lead uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.leads l
    where l.id = p_lead
      and l.company_id = public.auth_company_id()
      and (
        public.auth_role() = 'sales_head'
        or (public.auth_role() = 'project_head' and l.project_id = public.auth_project_id())
        or (public.auth_role() = 'sales' and l.owner_id = auth.uid())
      )
  )
$$;

-- ---------- Enable RLS ----------
alter table public.companies    enable row level security;
alter table public.projects     enable row level security;
alter table public.members      enable row level security;
alter table public.leads        enable row level security;
alter table public.lead_activity enable row level security;
alter table public.assessments  enable row level security;
alter table public.invitations  enable row level security;

-- ---------- Policies ----------

-- companies: see your own; only the Sales Head edits it.
create policy company_select on public.companies for select
  using (id = public.auth_company_id());
create policy company_update on public.companies for update
  using (id = public.auth_company_id() and public.auth_role() = 'sales_head');

-- projects: everyone in the company reads; Sales Head manages.
create policy project_select on public.projects for select
  using (company_id = public.auth_company_id());
create policy project_write on public.projects for all
  using (company_id = public.auth_company_id() and public.auth_role() = 'sales_head')
  with check (company_id = public.auth_company_id() and public.auth_role() = 'sales_head');

-- members: read your teammates; Sales Head manages; anyone can update their own name.
create policy member_select on public.members for select
  using (company_id = public.auth_company_id());
create policy member_admin on public.members for all
  using (company_id = public.auth_company_id() and public.auth_role() = 'sales_head')
  with check (company_id = public.auth_company_id() and public.auth_role() = 'sales_head');
create policy member_self_update on public.members for update
  using (id = auth.uid()) with check (id = auth.uid());

-- leads: company isolation + role-based visibility.
create policy lead_select on public.leads for select
  using (
    company_id = public.auth_company_id()
    and (
      public.auth_role() = 'sales_head'
      or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())
      or (public.auth_role() = 'sales' and owner_id = auth.uid())
    )
  );

create policy lead_insert on public.leads for insert
  with check (
    company_id = public.auth_company_id()
    and (public.auth_role() <> 'sales' or owner_id = auth.uid())  -- salesperson auto-owns
  );

create policy lead_update on public.leads for update
  using (
    company_id = public.auth_company_id()
    and (
      public.auth_role() = 'sales_head'
      or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())
      or (public.auth_role() = 'sales' and owner_id = auth.uid())
    )
  )
  with check (company_id = public.auth_company_id());

create policy lead_delete on public.leads for delete
  using (
    company_id = public.auth_company_id()
    and (
      public.auth_role() = 'sales_head'
      or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())
    )
  );

-- lead_activity + assessments: follow the parent lead's visibility.
create policy activity_select on public.lead_activity for select
  using (company_id = public.auth_company_id() and public.can_see_lead(lead_id));
create policy activity_insert on public.lead_activity for insert
  with check (company_id = public.auth_company_id() and public.can_see_lead(lead_id)
              and (author_id is null or author_id = auth.uid()));

create policy assessment_select on public.assessments for select
  using (company_id = public.auth_company_id() and public.can_see_lead(lead_id));
create policy assessment_insert on public.assessments for insert
  with check (company_id = public.auth_company_id() and public.can_see_lead(lead_id));

-- invitations: Sales Head manages within their company.
create policy invite_admin on public.invitations for all
  using (company_id = public.auth_company_id() and public.auth_role() = 'sales_head')
  with check (company_id = public.auth_company_id() and public.auth_role() = 'sales_head');

-- ---------- Business-rule trigger: lock walk-in date & source ----------
-- Only the Sales Head may change created_at (walk-in date) or the source fields.
create or replace function public.enforce_walkin_locks() returns trigger
  language plpgsql as $$
begin
  if (new.created_at   is distinct from old.created_at
   or new.walkin_source is distinct from old.walkin_source
   or new.cp_name      is distinct from old.cp_name)
     and public.auth_role() <> 'sales_head' then
    raise exception 'Only the Sales Head can change the walk-in date or source';
  end if;
  return new;
end $$;

create trigger trg_walkin_locks
  before update on public.leads
  for each row execute function public.enforce_walkin_locks();

-- ---------- Onboarding RPC: first signup creates a company + becomes its Sales Head ----------
create or replace function public.create_company_and_owner(company_name text, full_name text)
  returns uuid language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if exists (select 1 from public.members where id = auth.uid()) then
    raise exception 'User already belongs to a company';
  end if;
  insert into public.companies(name) values (company_name) returning id into cid;
  insert into public.members(id, company_id, role, name, email)
    values (auth.uid(), cid, 'sales_head', full_name,
            (select email from auth.users where id = auth.uid()));
  return cid;
end $$;

-- Accept an invitation: link the current user to an existing company/role.
create or replace function public.accept_invite(p_token uuid, full_name text)
  returns uuid language plpgsql security definer set search_path = public as $$
declare inv public.invitations;
begin
  select * into inv from public.invitations where token = p_token and status = 'pending';
  if inv.id is null then raise exception 'Invalid or used invitation'; end if;
  insert into public.members(id, company_id, role, project_id, name, email)
    values (auth.uid(), inv.company_id, inv.role, inv.project_id, full_name,
            (select email from auth.users where id = auth.uid()));
  update public.invitations set status = 'accepted' where id = inv.id;
  return inv.company_id;
end $$;

-- ---------- Grants ----------
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on all functions in schema public to authenticated;

-- =====================================================================
-- Notes:
--  * The three roles map 1:1 to the prototype: sales_head / project_head / sales.
--  * Disqualify = set stage='not_qualified', disqualified_by=<name>, owner_id=NULL.
--    Because owner_id becomes NULL, the row leaves the salesperson's view
--    automatically (RLS), landing in the shared disqualified pool that heads reassign.
--  * The two 7-day SLAs are computed in the app / notification job (see BUILD-PLAN.md),
--    using assigned_at (decision SLA) and the latest lead_activity date (stale-qualified).
-- =====================================================================

-- ===== migration-2 =====
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

-- ===== migration-3 =====
-- =====================================================================
-- Migration 3 — booking details captured when a lead is marked Booked (won)
-- One new column on leads (a flexible JSON holder). Nothing is dropped.
-- =====================================================================
alter table public.leads add column if not exists booking jsonb;

-- ===== migration-4 =====
-- =====================================================================
-- Migration 4 — walk-in phase (Phase 1 / Phase 2), chosen at walk-in level.
-- Safe to run even if you already ran the booking column (idempotent).
-- =====================================================================
alter table public.leads add column if not exists booking      jsonb;   -- (from migration 3; harmless if already present)
alter table public.leads add column if not exists walkin_phase text;    -- Phase 1 / Phase 2

-- ===== migration-5 =====
-- =====================================================================
-- Migration 5 — store for the Sales Head monthly-report external inputs
-- (previous-month performance, historic realization-by-BHK, etc.)
-- One JSON column on companies; only the Sales Head can edit it (existing RLS).
-- =====================================================================
alter table public.companies add column if not exists report_data jsonb;

-- ===== migration-6 =====
-- =====================================================================
-- Migration 6 — deal status + "Met Project Head" accountability check
-- =====================================================================
alter table public.leads add column if not exists deal_status      text;    -- Prospect/Negotiation/Booked/Closed Won/Closed Lost
alter table public.leads add column if not exists met_project_head  boolean not null default false;
alter table public.leads add column if not exists ph_meeting_date   date;

-- The Project Head must NOT be able to change the Met-Project-Head flag/date
-- (it is an accountability check on them). Enforced server-side like the walk-in lock.
create or replace function public.enforce_ph_meeting_lock() returns trigger
  language plpgsql as $$
begin
  if (new.met_project_head is distinct from old.met_project_head
   or new.ph_meeting_date  is distinct from old.ph_meeting_date)
     and public.auth_role() = 'project_head' then
    raise exception 'The Project Head cannot change the Met-Project-Head status';
  end if;
  return new;
end $$;

drop trigger if exists trg_ph_meeting_lock on public.leads;
create trigger trg_ph_meeting_lock before update on public.leads
  for each row execute function public.enforce_ph_meeting_lock();

-- ===== migration-7 =====
-- =====================================================================
-- Migration 7 — saved (named) filters + salesperson custom labels
--   members.prefs  : per-user JSON (saved filters, personal label definitions)
--   leads.labels   : labels attached to a lead (array of strings)
-- =====================================================================
alter table public.members add column if not exists prefs  jsonb;
alter table public.leads   add column if not exists labels jsonb;

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
create policy msg_select on public.messages for select using (company_id = public.auth_company_id());
create policy msg_insert on public.messages for insert with check (company_id = public.auth_company_id() and member_id = auth.uid());
grant select, insert, update, delete on public.messages to authenticated;
