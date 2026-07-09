-- =====================================================================
-- Migration 5 — store for the Sales Head monthly-report external inputs
-- (previous-month performance, historic realization-by-BHK, etc.)
-- One JSON column on companies; only the Sales Head can edit it (existing RLS).
-- =====================================================================
alter table public.companies add column if not exists report_data jsonb;
