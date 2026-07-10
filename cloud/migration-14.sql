-- =====================================================================
-- Migration 14 — payment-scheme / promotion catalog + scheme on pricing
-- =====================================================================
-- A company-scoped list of payment schemes / promo codes (Pre EMI, CLP,
-- and any added later). Everyone in the company can read it; heads manage it.
create table if not exists public.promotions (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  name        text not null,
  description text default '',
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique(company_id, name)
);
create index if not exists idx_promo_company on public.promotions(company_id);
alter table public.promotions enable row level security;

-- Read: anyone in the company (salespeople need it when requesting pricing)
drop policy if exists promo_select on public.promotions;
create policy promo_select on public.promotions for select
  using (company_id = public.auth_company_id());

-- Manage: Sales Head only
drop policy if exists promo_write on public.promotions;
create policy promo_write on public.promotions for all
  using (company_id = public.auth_company_id() and public.auth_role() = 'sales_head')
  with check (company_id = public.auth_company_id() and public.auth_role() = 'sales_head');

grant select, insert, update, delete on public.promotions to authenticated;

-- The payment scheme chosen on a pricing-approval request
alter table public.pricing_requests add column if not exists scheme text;
