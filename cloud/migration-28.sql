-- migration-28: WhatsApp smart drip — the "already sent" ledger.
--
-- One small map per lead: { "<templateId>": "YYYY-MM-DD", ... }
-- Keyed by template id so writes are idempotent and the drip engine can ask
-- "has this step gone out?" in O(1) while it runs once per lead per render.
--
-- Dates are stored as LOCAL YYYY-MM-DD (never toISOString()) — a UTC conversion
-- shifts an evening action in IST back to the previous day and throws off every
-- "sent N days ago" label and day-gap calculation.
--
-- The templates themselves live in companies.report_data.msgTemplates, which
-- already exists and is already writable by heads (migration-23) — no change needed.
-- Idempotent — safe to run more than once.

alter table public.leads add column if not exists msg_sent jsonb not null default '{}'::jsonb;

-- verify:
-- select count(*) from public.leads where msg_sent <> '{}'::jsonb;
