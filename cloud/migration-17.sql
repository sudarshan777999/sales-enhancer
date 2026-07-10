-- =====================================================================
-- Migration 17 — front-desk "revisit" walk-ins + merge into earlier walk-in
-- =====================================================================
-- Receptionist can mark a walk-in as a revisit (customer has been here before).
-- The salesperson then merges it into the customer's earlier walk-in (matched
-- by phone). The merged-away entry is hidden via merged_into (not deleted, so a
-- salesperson — who can't delete — can still do it via a normal update).
alter table public.leads add column if not exists pending_revisit boolean default false;
alter table public.leads add column if not exists merged_into     uuid references public.leads(id) on delete set null;
