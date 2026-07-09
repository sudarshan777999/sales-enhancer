-- =====================================================================
-- Migration 7 — saved (named) filters + salesperson custom labels
--   members.prefs  : per-user JSON (saved filters, personal label definitions)
--   leads.labels   : labels attached to a lead (array of strings)
-- =====================================================================
alter table public.members add column if not exists prefs  jsonb;
alter table public.leads   add column if not exists labels jsonb;
