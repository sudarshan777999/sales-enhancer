-- =====================================================================
-- Migration 19 — anyone can assign a task (e.g. salesperson → head)
-- =====================================================================
-- Previously only heads could create tasks. Allow any company member to
-- assign a task on a lead they can see (assigned_by must be themselves).
drop policy if exists tasks_insert on public.tasks;
create policy tasks_insert on public.tasks for insert with check (
  company_id = public.auth_company_id()
  and assigned_by = auth.uid()
  and public.can_see_lead(lead_id));
