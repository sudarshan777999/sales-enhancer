-- =====================================================================
-- Migration 8 — shared owners (co-ownership) + price offered + block(s) + competitors
-- =====================================================================
alter table public.leads add column if not exists co_owners     uuid[];   -- extra salespeople with equal access
alter table public.leads add column if not exists price_offered text;     -- price quoted to the customer
alter table public.leads add column if not exists blocks        jsonb;    -- blocks of interest, e.g. ["A","C"]
alter table public.leads add column if not exists competitors   text;     -- other projects/competitors in play

-- Let a salesperson also reach leads shared with them (co_owners), with equal access.
drop policy if exists lead_select on public.leads;
create policy lead_select on public.leads for select
  using (
    company_id = public.auth_company_id()
    and (
      public.auth_role() = 'sales_head'
      or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())
      or (public.auth_role() = 'sales' and (owner_id = auth.uid() or auth.uid() = any(co_owners)))
    )
  );

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

-- Activity/assessment visibility follows the same rule.
create or replace function public.can_see_lead(p_lead uuid) returns boolean
  language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.leads l
    where l.id = p_lead
      and l.company_id = public.auth_company_id()
      and (
        public.auth_role() = 'sales_head'
        or (public.auth_role() = 'project_head' and l.project_id = public.auth_project_id())
        or (public.auth_role() = 'sales' and (l.owner_id = auth.uid() or auth.uid() = any(l.co_owners)))
      )
  )
$$;
