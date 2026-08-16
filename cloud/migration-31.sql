-- migration-31: let the front desk find a returning customer and log the revisit
-- directly on their existing record.
--
-- The problem this removes
-- -----------------------
-- Today the GRE ticks "this customer has visited before", which creates a SECOND
-- walk-in record flagged pending_revisit. Someone else must later open that
-- duplicate, find the earlier walk-in in a dropdown of every walk-in in the company,
-- and press Merge. Until they do there are two records for one customer. That merge
-- step is the part everyone finds hard, and it is only needed because the front desk
-- had no way to reach the original record in the first place.
--
-- Why two SECURITY DEFINER functions
-- ----------------------------------
-- Reception's row-level policy deliberately only exposes leads with a planned visit
-- inside a week (migration-27), so a plain search from the browser would find almost
-- nobody. Rather than widen that policy — which would hand the front desk every lead
-- in the company, with budgets, competitors and comments — these two functions expose
-- exactly two capabilities and nothing else:
--
--   reception_search_customers  read-only, minimal columns, needs a real search term
--   reception_log_revisit       append one revisit line, nothing else on the record
--
-- The search returns no budget, no deal status, no competitor, no comments — only
-- what is needed to recognise a person at the desk and route them.
--
-- Idempotent — safe to run more than once.

-- ------------------------------------------------------------------ search
drop function if exists public.reception_search_customers(text);

create function public.reception_search_customers(p_q text)
returns table (
  id            uuid,
  name          text,
  phone         text,
  project       text,
  stage         text,
  owner_name    text,
  captured_on   date,
  last_visit    date,
  revisit_count int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company uuid;
  v_role    text;
  v_q       text := btrim(coalesce(p_q,''));
begin
  select m.company_id, m.role into v_company, v_role
    from public.members m where m.id = auth.uid();

  if v_company is null then
    raise exception 'Not signed in.';
  end if;
  if v_role not in ('reception','sales_head','project_head') then
    raise exception 'Not allowed.';
  end if;
  -- never let this be used to enumerate the whole customer list
  if length(v_q) < 2 then
    return;
  end if;

  return query
  select l.id,
         l.name,
         l.phone,
         p.name                                        as project,
         l.stage,
         coalesce(o.name,'Unassigned')                 as owner_name,
         l.created_at::date                            as captured_on,
         greatest(
           l.created_at::date,
           coalesce((select max(a.created_at::date)
                       from public.lead_activity a
                      where a.lead_id = l.id and a.kind = 'revisit'), l.created_at::date)
         )                                             as last_visit,
         (select count(*)::int from public.lead_activity a
           where a.lead_id = l.id and a.kind = 'revisit') as revisit_count
    from public.leads l
    left join public.members  o on o.id = l.owner_id
    left join public.projects p on p.id = l.project_id
   where l.company_id = v_company
     and l.merged_into is null
     and (l.name ilike '%'||v_q||'%' or coalesce(l.phone,'') ilike '%'||v_q||'%')
   order by last_visit desc, l.name
   limit 25;
end;
$$;

-- --------------------------------------------------------------- log revisit
drop function if exists public.reception_log_revisit(uuid, date, text);

create function public.reception_log_revisit(
  p_lead uuid,
  p_on   date,
  p_note text
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_company uuid;
  v_role    text;
  v_ok      uuid;
begin
  select m.company_id, m.role into v_company, v_role
    from public.members m where m.id = auth.uid();

  if v_company is null then
    raise exception 'Not signed in.';
  end if;
  if v_role not in ('reception','sales_head','project_head') then
    raise exception 'Not allowed.';
  end if;

  -- the lead must belong to the caller's own company
  select l.id into v_ok
    from public.leads l
   where l.id = p_lead and l.company_id = v_company and l.merged_into is null;

  if v_ok is null then
    raise exception 'That customer is not on your list.';
  end if;

  -- a revisit is just an activity line; the app derives the count and dates from these
  insert into public.lead_activity (company_id, lead_id, kind, body, author_id, created_at)
  values (v_company, p_lead, 'revisit',
          coalesce(nullif(btrim(p_note),''), 'Revisit logged at the front desk'),
          auth.uid(),
          coalesce(p_on, current_date)::timestamptz + interval '12 hours');
end;
$$;

revoke all on function public.reception_search_customers(text) from public, anon;
revoke all on function public.reception_log_revisit(uuid, date, text) from public, anon;
grant execute on function public.reception_search_customers(text)       to authenticated;
grant execute on function public.reception_log_revisit(uuid, date, text) to authenticated;

notify pgrst, 'reload schema';

-- verify — expects 2
-- select count(*) as fns
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public'
--    and p.proname in ('reception_search_customers','reception_log_revisit');
