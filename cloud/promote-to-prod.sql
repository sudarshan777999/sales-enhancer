-- Promote to production: run migrations 6 + 7 (idempotent, safe)

-- ===== migration-6 (deal status + Met-Project-Head lock) =====
-- =====================================================================
-- Migration 6 — deal status + "Met Project Head" accountability check
-- =====================================================================
alter table public.leads add column if not exists deal_status      text;    -- Prospect/Negotiation/Booked/Closed Won/Closed Lost
alter table public.leads add column if not exists met_project_head  boolean not null default false;
alter table public.leads add column if not exists ph_meeting_date   date;

-- The Project Head must NOT be able to change the Met-Project-Head flag/date
-- (it is an accountability check on them). Enforced server-side like the walk-in lock.
create or replace function public.enforce_ph_meeting_lock() returns trigger
  language plpgsql as $$
begin
  if (new.met_project_head is distinct from old.met_project_head
   or new.ph_meeting_date  is distinct from old.ph_meeting_date)
     and public.auth_role() = 'project_head' then
    raise exception 'The Project Head cannot change the Met-Project-Head status';
  end if;
  return new;
end $$;

drop trigger if exists trg_ph_meeting_lock on public.leads;
create trigger trg_ph_meeting_lock before update on public.leads
  for each row execute function public.enforce_ph_meeting_lock();

-- ===== migration-7 (saved filters + labels) =====
-- =====================================================================
-- Migration 7 — saved (named) filters + salesperson custom labels
--   members.prefs  : per-user JSON (saved filters, personal label definitions)
--   leads.labels   : labels attached to a lead (array of strings)
-- =====================================================================
alter table public.members add column if not exists prefs  jsonb;
alter table public.leads   add column if not exists labels jsonb;
