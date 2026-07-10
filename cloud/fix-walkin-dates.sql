-- Set walk-in date = 2026-07-09 (yesterday) for all bulk-imported walk-ins
update public.leads
set created_at = date '2026-07-09'
where id in (
  select distinct lead_id from public.lead_activity where body ilike '%bulk import%'
);
