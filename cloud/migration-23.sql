-- migration-23: let Project Heads (not just the Sales Head) save company settings.
-- Needed so Project Heads can merge duplicate Channel Partner name variants, which
-- are stored company-wide in companies.report_data.cpAliases.
-- Idempotent — safe to run more than once.

drop policy if exists company_update on public.companies;
create policy company_update on public.companies for update
  using (id = public.auth_company_id() and public.auth_role() in ('sales_head','project_head'))
  with check (id = public.auth_company_id() and public.auth_role() in ('sales_head','project_head'));
