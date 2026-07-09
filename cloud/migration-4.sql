-- =====================================================================
-- Migration 4 — walk-in phase (Phase 1 / Phase 2), chosen at walk-in level.
-- Safe to run even if you already ran the booking column (idempotent).
-- =====================================================================
alter table public.leads add column if not exists booking      jsonb;   -- (from migration 3; harmless if already present)
alter table public.leads add column if not exists walkin_phase text;    -- Phase 1 / Phase 2
