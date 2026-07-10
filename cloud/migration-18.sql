-- =====================================================================
-- Migration 18 — flag walk-ins entered by the front desk (GRE)
-- =====================================================================
alter table public.leads add column if not exists via_gre boolean default false;
