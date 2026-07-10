-- =====================================================================
-- Migration 13 — monthly targets & incentives per salesperson
-- =====================================================================
create table if not exists public.targets (
  id         uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  member_id  uuid not null references public.members(id) on delete cascade,
  month      text not null,            -- 'YYYY-MM'
  target     int default 0,            -- bookings target
  incentive  numeric default 0,        -- potential incentive (INR)
  unique(member_id, month)
);
create index if not exists idx_tg_company on public.targets(company_id);
alter table public.targets enable row level security;

-- Read: Sales Head (all), the salesperson themselves, the Project Head for their project's reps
drop policy if exists tg_select on public.targets;
create policy tg_select on public.targets for select
  using (company_id = public.auth_company_id() and (
    public.auth_role() = 'sales_head'
    or member_id = auth.uid()
    or (public.auth_role() = 'project_head' and exists (
        select 1 from public.members m where m.id = targets.member_id and m.project_id = public.auth_project_id()))));

-- Write: Sales Head, or the Project Head for their project's reps
drop policy if exists tg_write on public.targets;
create policy tg_write on public.targets for all
  using (company_id = public.auth_company_id() and (
    public.auth_role() = 'sales_head'
    or (public.auth_role() = 'project_head' and exists (
        select 1 from public.members m where m.id = targets.member_id and m.project_id = public.auth_project_id()))))
  with check (company_id = public.auth_company_id());

grant select, insert, update, delete on public.targets to authenticated;
