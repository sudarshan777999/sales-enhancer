-- =====================================================================
-- Migration 10 — Wonderwall tracking (proposed at first visit) + conversion
-- =====================================================================
alter table public.leads add column if not exists wonderwall_suggested boolean not null default false;
alter table public.leads add column if not exists wonderwall_visited   boolean not null default false;
