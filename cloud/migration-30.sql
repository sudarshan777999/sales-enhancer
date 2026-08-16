-- migration-30: let a Sales Head set a new password for someone on their own team.
--
-- Why this exists
-- ---------------
-- Team logins are created as usernames, mapped to <username>@bnm.local. That domain
-- has no mailbox, so Supabase's "forgot password" email can never be delivered to
-- them. Anyone who forgets their password is locked out with no self-service route.
--
-- The email flow now works properly for accounts with a REAL email address. This
-- function covers the rest: the Sales Head sets a new password directly.
--
-- Why it is a SECURITY DEFINER function and not an admin API call
-- --------------------------------------------------------------
-- Changing another user's password normally needs the service_role key. That key must
-- never be shipped to a browser, so instead the privilege is exposed as one narrow
-- function that can do exactly this and nothing else.
--
-- What it will refuse to do
-- -------------------------
--   * run for anyone whose own role is not sales_head
--   * touch a member of a different company than the caller's
--   * touch a row that is not in members at all (so it can never reach, say, a
--     Supabase dashboard owner or a user from another tenant)
--   * set a password shorter than 8 characters
--   * change the caller's own password (use the normal reset for that)
--
-- Side effect worth knowing: every existing session for that user is revoked, so if
-- they were signed in somewhere they will be asked to sign in again. That is the
-- point — a forgotten password often means someone else may have had a look.
--
-- Idempotent — safe to run more than once.

create extension if not exists pgcrypto with schema extensions;

create or replace function public.admin_set_member_password(
  p_member  uuid,
  p_password text
) returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_caller  uuid := auth.uid();
  v_company uuid;
  v_role    text;
  v_target  uuid;
begin
  if v_caller is null then
    raise exception 'Not signed in.';
  end if;

  select company_id, role into v_company, v_role
    from public.members where id = v_caller;

  if v_role is distinct from 'sales_head' then
    raise exception 'Only a Sales Head can set a team member''s password.';
  end if;

  if p_member = v_caller then
    raise exception 'Use the normal password reset to change your own password.';
  end if;

  if length(coalesce(p_password,'')) < 8 then
    raise exception 'Password must be at least 8 characters.';
  end if;

  -- the target must be a member of the caller's own company
  select id into v_target
    from public.members
   where id = p_member and company_id = v_company;

  if v_target is null then
    raise exception 'That person is not on your team.';
  end if;

  update auth.users
     set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
         updated_at         = now()
   where id = v_target;

  -- Force them to sign in again everywhere. Wrapped because auth.refresh_tokens.user_id
  -- is varchar in current GoTrue but has differed across versions — a type mismatch here
  -- must not roll back the password change above.
  begin
    delete from auth.sessions where user_id = v_target;
    delete from auth.refresh_tokens where user_id = v_target::text;
  exception when others then
    null;   -- old sessions linger until they expire; the new password still applies
  end;
end;
$$;

revoke all on function public.admin_set_member_password(uuid, text) from public, anon;
grant execute on function public.admin_set_member_password(uuid, text) to authenticated;

notify pgrst, 'reload schema';

-- verify — expects fn_exists 1
-- select count(*) as fn_exists
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public' and p.proname = 'admin_set_member_password';
