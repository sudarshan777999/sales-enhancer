-- migration-22: retire the phone/mobile field; add a shared merge code.
--
-- Part 1: match_code — a small shared random code the app stamps on a revisit
-- and its earlier walk-in when you merge them (replaces phone-number matching).
alter table public.leads add column if not exists match_code text;

-- Part 2: wipe every stored phone number. The phone column stays (it is NOT NULL,
-- and new records are written with '' by the app) but is no longer used or shown.
-- IRREVERSIBLE except from your backup — run deliberately.
update public.leads set phone = '' where phone is not null and phone <> '';
