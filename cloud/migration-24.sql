-- migration-24: retire the "Negotiation" deal status.
-- The app now uses "First Contact Done" and "Prospect" as the two open deal statuses
-- (Negotiation removed). Any lead still marked 'Negotiation' is moved to 'Prospect'
-- so no lead is left on a status the app no longer shows.
-- Safe to run more than once (a second run just matches nothing).
--
-- BEFORE RUNNING: click the Sales Head "⬇︎ Backup" button once (safety net).

update public.leads set deal_status = 'Prospect' where deal_status = 'Negotiation';

-- verify (should be 0):
-- select count(*) from public.leads where deal_status = 'Negotiation';
