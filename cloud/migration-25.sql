-- migration-25: scheduled (planned) revisits.
--
-- Why: the app tracked revisits that ALREADY happened (lead_activity kind='revisit')
-- and follow-up call reminders (leads.next_follow_up), but there was no way to record
-- "the customer said he'll visit again on Saturday". This column holds that planned
-- visit date so it can be shown on a calendar and rolled up for the heads.
--
-- The date is cleared automatically by the app once the revisit is actually logged.
-- Idempotent — safe to run more than once.

alter table public.leads add column if not exists planned_visit date;

-- verify:
-- select count(*) from public.leads where planned_visit is not null;
