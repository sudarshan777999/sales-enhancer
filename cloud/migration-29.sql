-- migration-29: make Row Level Security fast. NO change to who can see what.
--
-- The problem
-- -----------
-- The policies called helper functions directly, e.g.
--     using (company_id = auth_company_id() and can_see_lead(lead_id))
-- Postgres evaluates those ONCE PER ROW. Reading 2,409 lead_activity rows meant
-- 2,409 calls to can_see_lead(), each of which re-ran auth_company_id(),
-- auth_role() (up to three times), auth_project_id() and auth.uid() — every one a
-- members lookup and/or a JWT parse. That was the bulk of the app's load time.
--
-- The fix (two standard techniques, no behaviour change)
-- -----------------------------------------------------
-- 1. Wrap each helper in a scalar sub-select: (select auth_role()).
--    Postgres then evaluates it ONCE per statement as an InitPlan, not per row.
-- 2. Short-circuit the sales_head case before the per-row lead lookup. A Sales Head
--    can see every lead in the company, so checking each parent lead was pure waste.
--
-- The visibility rules below are copied from the live policies unchanged:
--   sales_head    -> everything in the company
--   project_head  -> their project
--   sales         -> leads they own or co-own
--   reception     -> only leads with a planned visit within a week (migration-27)
--
-- Idempotent — safe to run more than once.

-- ---------------------------------------------------------------- leads
drop policy if exists lead_select on public.leads;
create policy lead_select on public.leads for select
  using (
    company_id = (select public.auth_company_id())
    and (
      (select public.auth_role()) = 'sales_head'
      or ((select public.auth_role()) = 'project_head' and project_id = (select public.auth_project_id()))
      or ((select public.auth_role()) = 'sales'
          and (owner_id = (select auth.uid()) or (select auth.uid()) = any(co_owners)))
      or ((select public.auth_role()) = 'reception'
          and planned_visit is not null
          and planned_visit between current_date - 7 and current_date + 7)
    )
  );

drop policy if exists lead_update on public.leads;
create policy lead_update on public.leads for update
  using (
    company_id = (select public.auth_company_id())
    and (
      (select public.auth_role()) = 'sales_head'
      or ((select public.auth_role()) = 'project_head' and project_id = (select public.auth_project_id()))
      or ((select public.auth_role()) = 'sales'
          and (owner_id = (select auth.uid()) or (select auth.uid()) = any(co_owners)))
    )
  )
  with check (company_id = (select public.auth_company_id()));

-- ------------------------------------------------------- lead_activity
-- Same rule as before (company match + can_see_lead), but the head case no longer
-- does a per-row lookup, and the auth helpers resolve once for the whole statement.
drop policy if exists activity_select on public.lead_activity;
create policy activity_select on public.lead_activity for select
  using (
    company_id = (select public.auth_company_id())
    and (
      (select public.auth_role()) = 'sales_head'
      or exists (
        select 1 from public.leads l
        where l.id = lead_activity.lead_id
          and l.company_id = (select public.auth_company_id())
          and (
            ((select public.auth_role()) = 'project_head' and l.project_id = (select public.auth_project_id()))
            or ((select public.auth_role()) = 'sales'
                and (l.owner_id = (select auth.uid()) or (select auth.uid()) = any(l.co_owners)))
          )
      )
    )
  );

-- ---------------------------------------------------------------- tasks
drop policy if exists tasks_select on public.tasks;
create policy tasks_select on public.tasks for select
  using (
    company_id = (select public.auth_company_id())
    and (
      assigned_to = (select auth.uid())
      or assigned_by = (select auth.uid())
      or (select public.auth_role()) = 'sales_head'
      or exists (
        select 1 from public.leads l
        where l.id = tasks.lead_id
          and l.company_id = (select public.auth_company_id())
          and (
            ((select public.auth_role()) = 'project_head' and l.project_id = (select public.auth_project_id()))
            or ((select public.auth_role()) = 'sales'
                and (l.owner_id = (select auth.uid()) or (select auth.uid()) = any(l.co_owners)))
          )
      )
    )
  );

-- Helps the exists() lookups above and the app's per-lead timeline reads.
create index if not exists idx_activity_lead_created on public.lead_activity(lead_id, created_at);

analyze public.leads;
analyze public.lead_activity;

-- verify (should list the three rewritten policies):
-- select tablename, policyname from pg_policies
--  where policyname in ('lead_select','lead_update','activity_select','tasks_select')
--  order by tablename, policyname;
