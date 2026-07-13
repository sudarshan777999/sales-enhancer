-- migration-20: activity scoreboard (gamified usage leaderboard)
--
-- Part 1: adds leads.created_by — the "who created each walk-in" feature writes
-- this on every new lead/walk-in, and the leaderboard counts it as "added". The
-- leads table never had this column, so this also un-breaks new-walk-in saving.
-- Idempotent (add column if not exists).
alter table public.leads add column if not exists created_by uuid references public.members(id);

-- Part 2: a SECURITY DEFINER function that returns per-member AGGREGATE activity
-- counts for the caller's company. It exposes only counts (no lead names/details),
-- so a salesperson can see teammates' scores for the leaderboard without gaining
-- access to other people's leads. Ranking covers salespeople + project heads.
--
-- p_from: only count activity on/after this date. Pass the 1st of the month for a
-- monthly board, or NULL for all-time.
-- Idempotent: create or replace.

create or replace function public.activity_scoreboard(p_from date default null)
returns table(
  member_id  uuid,
  name       text,
  role       text,
  project    text,
  notes      int,
  followups  int,
  revisits   int,
  added      int,
  qualified  int,
  tasks_done int
)
language sql
security definer
set search_path = public
as $$
  with cc as (select public.auth_company_id() as cid)
  select
    m.id,
    m.name,
    m.role,
    p.name,
    coalesce(na.notes, 0),
    coalesce(na.followups, 0),
    coalesce(na.revisits, 0),
    coalesce(la.added, 0),
    coalesce(qa.qualified, 0),
    coalesce(ta.tasks_done, 0)
  from public.members m
  left join public.projects p on p.id = m.project_id
  left join (
    select a.author_id,
      count(*) filter (where a.kind = 'note')                                    as notes,
      count(*) filter (where a.kind = 'note' and a.next_follow_up is not null)    as followups,
      count(*) filter (where a.kind = 'revisit')                                  as revisits
    from public.lead_activity a
    where a.company_id = (select cid from cc)
      and (p_from is null or a.created_at >= p_from)
    group by a.author_id
  ) na on na.author_id = m.id
  left join (
    select a.author_id, count(*) as qualified
    from public.lead_activity a
    where a.company_id = (select cid from cc)
      and a.kind = 'system'
      and (a.body ilike 'Marked qualified%'
           or a.body ilike 'Moved back to Qualified%'
           or a.body ilike 'Re-qualified%')
      and (p_from is null or a.created_at >= p_from)
    group by a.author_id
  ) qa on qa.author_id = m.id
  left join (
    select l.created_by, count(*) as added
    from public.leads l
    where l.company_id = (select cid from cc)
      and (p_from is null or l.created_at >= p_from)
    group by l.created_by
  ) la on la.created_by = m.id
  left join (
    select t.assigned_to, count(*) as tasks_done
    from public.tasks t
    where t.company_id = (select cid from cc)
      and t.status = 'done'
      and (p_from is null or t.done_at >= p_from)
    group by t.assigned_to
  ) ta on ta.assigned_to = m.id
  where m.company_id = (select cid from cc)
    and m.role in ('sales', 'project_head');
$$;

grant execute on function public.activity_scoreboard(date) to authenticated;
