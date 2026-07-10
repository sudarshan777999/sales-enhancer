-- One-time backfill: tag existing front-desk (GRE) walk-ins.
-- Front-desk entries are the only walk-ins created with NO activity log
-- (the receptionist screen doesn't write one), so this flags exactly those.
update public.leads l
set via_gre = true
where l.source = 'walkin'
  and coalesce(l.via_gre, false) = false
  and not exists (select 1 from public.lead_activity a where a.lead_id = l.id);
