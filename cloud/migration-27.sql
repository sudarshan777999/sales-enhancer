-- migration-27: let the front desk (reception) confirm that a planned visit happened.
--
-- Two parts:
--   1. A NARROW read window so reception can see the visits they need to greet —
--      only leads with a planned visit within a week either side of today.
--      Reception still cannot see the pipeline, analytics, or any other lead.
--   2. A SECURITY DEFINER function to mark a visit as happened. Reception is NOT
--      given UPDATE rights on leads; the function is the only way they can write,
--      and it can only touch visit_plans / planned_visit and add a revisit entry.
--
-- Idempotent — safe to run more than once.

-- ---------------------------------------------------------------------------
-- 1. SELECT: existing rules preserved exactly, reception clause appended.
-- ---------------------------------------------------------------------------
drop policy if exists lead_select on public.leads;
create policy lead_select on public.leads for select
  using (
    company_id = public.auth_company_id()
    and (
      public.auth_role() = 'sales_head'
      or (public.auth_role() = 'project_head' and project_id = public.auth_project_id())
      or (public.auth_role() = 'sales' and (owner_id = auth.uid() or auth.uid() = any(co_owners)))
      or (public.auth_role() = 'reception'
          and planned_visit is not null
          and planned_visit between current_date - 7 and current_date + 7)
    )
  );

-- ---------------------------------------------------------------------------
-- 2. Confirm a visit happened. Fulfils the EARLIEST pending plan, re-derives
--    planned_visit, and logs a revisit so it flows into the calendar, the
--    kept-rate scorecard and the monthly report exactly like the app's own path.
-- ---------------------------------------------------------------------------
create or replace function public.mark_visit_done(p_lead uuid, p_on date default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company uuid;
  v_plans   jsonb;
  v_idx     int;
  v_on      date := coalesce(p_on, current_date);
  v_next    date;
  v_scalar  date;
begin
  -- the caller must be a member; everything is scoped to their company
  select company_id into v_company from public.members where id = auth.uid();
  if v_company is null then
    raise exception 'Not a team member.';
  end if;

  select visit_plans, planned_visit into v_plans, v_scalar
    from public.leads
   where id = p_lead and company_id = v_company;
  if not found then
    raise exception 'Walk-in not found.';
  end if;

  v_plans := coalesce(v_plans, '[]'::jsonb);

  -- leads planned before visit_plans existed carry only the scalar date
  if not exists (select 1 from jsonb_array_elements(v_plans) e where e->>'done' is null)
     and v_scalar is not null then
    v_plans := v_plans || jsonb_build_array(jsonb_build_object(
      'd', to_char(v_scalar,'YYYY-MM-DD'), 'by', null,
      'at', to_char(v_scalar,'YYYY-MM-DD'), 'done', null));
  end if;

  -- index of the earliest still-pending plan
  select idx into v_idx from (
    select (ord - 1) as idx
      from jsonb_array_elements(v_plans) with ordinality t(e, ord)
     where e->>'done' is null
     order by e->>'d'
     limit 1
  ) s;

  if v_idx is null then
    raise exception 'That walk-in has no visit waiting to be confirmed.';
  end if;

  v_plans := jsonb_set(v_plans, array[v_idx::text, 'done'],
                       to_jsonb(to_char(v_on,'YYYY-MM-DD')));

  select min((e->>'d')::date) into v_next
    from jsonb_array_elements(v_plans) e
   where e->>'done' is null;

  update public.leads
     set visit_plans   = v_plans,
         planned_visit = v_next
   where id = p_lead and company_id = v_company;

  insert into public.lead_activity (company_id, lead_id, kind, body, author_id, created_at)
  values (v_company, p_lead, 'revisit', 'Revisit confirmed at the front desk',
          auth.uid(), (v_on::timestamp + interval '12 hours'));
end;
$$;

revoke all on function public.mark_visit_done(uuid, date) from public;
grant execute on function public.mark_visit_done(uuid, date) to authenticated;

-- verify:
-- select proname from pg_proc where proname = 'mark_visit_done';
