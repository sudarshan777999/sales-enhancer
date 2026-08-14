-- migration-26: keep the history of planned visits and whether they actually happened.
--
-- Why: planned_visit held only the CURRENT pending visit and was wiped once the revisit
-- was logged, so there was no record that the visit was honoured — and no way to measure
-- how reliably a salesperson converts "he'll come Saturday" into an actual visit.
--
-- visit_plans is an array of {d, by, at, done}:
--   d    = the date the visit was planned for
--   by   = member who planned it
--   at   = the date it was planned on
--   done = the date the visit actually happened (null = still pending / missed)
--
-- planned_visit (migration-25) stays as the current pending date, kept in sync by the app,
-- so existing filters, the calendar and the alerts keep working unchanged.
-- Idempotent — safe to run more than once.

alter table public.leads add column if not exists visit_plans jsonb not null default '[]'::jsonb;

-- verify:
-- select count(*) from public.leads where jsonb_array_length(visit_plans) > 0;
