-- =====================================================================
-- Migration 16 — receptionist role (front-desk walk-in entry)
-- =====================================================================
-- A reception member can create walk-ins and assign them to a salesperson,
-- but doesn't manage the pipeline. Existing lead_insert policy already lets
-- any non-'sales' role insert with any owner, so no policy change is needed.
alter table public.members     drop constraint if exists members_role_check;
alter table public.members     add  constraint members_role_check
  check (role in ('sales_head','project_head','sales','reception'));

alter table public.invitations drop constraint if exists invitations_role_check;
alter table public.invitations add  constraint invitations_role_check
  check (role in ('sales_head','project_head','sales','reception'));
