-- migration-21: let salespeople disqualify their own leads.
--
-- Disqualifying a lead sets owner_id = NULL (moves it to the "disqualified pool").
-- If the leads UPDATE policy's WITH CHECK requires the salesperson to still own
-- the row (or has no explicit WITH CHECK, so it defaults to the USING clause's
-- owner_id = auth.uid()), Postgres rejects the new unowned row with:
--   "new row violates row-level security policy for table leads".
--
-- Recreate lead_update with the intended, explicit WITH CHECK (company scope only),
-- so a salesperson who may edit a lead (USING) can also disqualify it. This does
-- NOT change who can SEE or EDIT which leads — only what the saved row may look like.
-- Idempotent (drop policy if exists).

drop policy if exists lead_update on public.leads;
create policy lead_update on public.leads for update
  using (
    company_id = public.auth_company_id()
    and (
      public.auth_role() = 'sales_head'
      or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())
      or (public.auth_role() = 'sales' and (owner_id = auth.uid() or auth.uid() = any(co_owners)))
    )
  )
  with check (company_id = public.auth_company_id());
