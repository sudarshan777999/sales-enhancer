-- =====================================================================
-- Migration 3 — booking details captured when a lead is marked Booked (won)
-- One new column on leads (a flexible JSON holder). Nothing is dropped.
-- =====================================================================
alter table public.leads add column if not exists booking jsonb;
