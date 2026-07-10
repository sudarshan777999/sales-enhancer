SALES ENHANCER — CLOUD BUILD HANDOVER
Bricks & Milestones · Project: Earthscape (also Solcrest, Lagos)
Last updated: 2026-07-10

=====================================================================
1. WHAT THIS IS (plain English)
=====================================================================
Sales Enhancer is a lead & walk-in management CRM for a real-estate
developer. It follows a customer from first contact to booked or lost:

  capture -> assign owner -> qualify/disqualify -> follow-up (reminders)
  -> booked (won) or lost, plus walk-in revisits, deal status, SLAs,
  alerts, and analytics funnels for leadership.

It started as a single offline HTML file (the "prototype"). It is now a
REAL multi-user cloud app that your whole team can log into from any
device, with data stored securely in the cloud.

=====================================================================
2. THE THREE PLACES YOUR APP LIVES
=====================================================================
A) YOUR LIVE TEAM SITE (production) — what the team uses
   URL:  https://bnmsales.netlify.app
   Data: Supabase project "xhlgwzpbkovqxuxarcoe"

B) THE SANDBOX (your private testing copy) — where you review changes
   URL:  https://bnmsales-sandbox.netlify.app
   Data: Supabase project "tadcupqosvvjndxyyerc" (separate data, safe to
         experiment; nothing here touches the live team data)

C) THE OLD OFFLINE PROTOTYPE — never delete, kept for reference
   File: lead-pipeline-local.html (runs by double-clicking, stores data
         only in that one browser). We do NOT edit this anymore.

The app knows which environment it is in by looking at the web address:
if the address contains "sandbox" / "localhost" it uses the sandbox
database and shows a red SANDBOX banner; otherwise it uses production.

=====================================================================
3. HOW CHANGES REACH YOU (the deploy rhythm)
=====================================================================
1. I make a change to the app source (cloud/index.html) and copy it into
   the publish folder (cloud/web/index.html).
2. I commit + push to GitHub.
3. Because the sandbox site is linked to GitHub, it AUTO-UPDATES within
   ~1 minute. No manual "drag the folder to Netlify" anymore.
4. You hard-refresh the sandbox (Cmd+Shift+R) and review.
5. When you're happy you say "promote", and the same build goes live to
   the team site. (See section 7 for what promote involves.)

=====================================================================
4. THE TECH STACK (for a future developer / Claude)
=====================================================================
- Front end: ONE self-contained file, cloud/index.html — vanilla
  HTML/CSS/JS, no framework, no build step. Publish copy in cloud/web/.
  Only external dep: @supabase/supabase-js@2 UMD from CDN + Google Fonts.
- Back end: Supabase (Postgres + Auth + Row Level Security + RPCs). Two
  projects: production (xhlgwzpbkovqxuxarcoe) and sandbox
  (tadcupqosvvjndxyyerc). Anon public keys are baked into index.html
  (safe — every table is protected by RLS). service_role key is NEVER
  in the code or anywhere shared.
- Hosting: Netlify. Sandbox site auto-deploys from GitHub branch `main`,
  publish dir `cloud/web`, no build command. Production deploys at
  promote time.
- Source backup: GitHub repo github.com/sudarshan777999/sales-enhancer
  (PUBLIC — made public so Netlify free-tier auto-deploy works; scanned
  first, contains no secrets, only the public anon key).

KEY CODE CONVENTIONS (preserve these):
- Global `db` = {instance, users, leads}; `session` = current user id.
- Reads go through scoped() (permission filter) then visible() (search).
- Every data change: targeted Supabase write, then refresh() (reload +
  render). refresh() wraps busyStart()/busyEnd() (top progress bar).
- Dates: local YYYY-MM-DD via iso(). NEVER use toISOString() (caused an
  IST off-by-one bug — do not reintroduce).
- Permissions centralised in can(action, lead); mirrors the DB RLS.
- leadFromRow(r) maps DB snake_case -> app camelCase.
- Env config at top of index.html: ENV_PROD / ENV_SANDBOX / IS_SANDBOX.

=====================================================================
5. PERMISSIONS / VISIBILITY RULES (confirmed by the owner — keep exact)
=====================================================================
- Sales Head: sees everything across all projects.
- Project Head: FULL rights but ONLY their own project (e.g. Earthscape
  PH cannot see Solcrest data). Enforced in DB (RLS) + client.
- Salesperson: their own leads (plus any lead where they are a co-owner).
- Two 7-day SLAs, disqualified-pool reassignment, and walk-in date/source
  locks are business rules from the prototype — preserve them.
- Met-Project-Head flag: a Project Head CANNOT change it (DB trigger
  enforce_ph_meeting_lock) — it's an accountability check.

=====================================================================
6. FEATURES BUILT (in the cloud app today)
=====================================================================
Core:
- Real email+password login; first real login creates the company.
- Team invites: Sales Head "Team" button -> invite link -> teammate
  signs up and joins with the right role/project.
- Bulk walk-in import: CSV template OR paste box (Name/Agent two-column),
  phone optional, "mark all Qualified", unmatched agents held then
  attached once they have a login.

Pipeline & capture:
- Deal status: Prospect / Negotiation / Closed Won / Closed Lost
  (replaced Hot/Warm/Cold). Closed Won opens the booking form; Closed
  Lost captures reason + "lost to which competitor".
- Walk-in Phase 1 / Phase 2 selector.
- Booking form: unit booked, location, company, Agreement Value, size,
  auto Realization (AV/size), payment structure, applicant/co-applicant.
- Shared/co-ownership: two owners with equal access to a walk-in.
- Price offered per lead; last-price-quoted (3 units + price).
- Block interest A-F; competitor tracking during follow-ups.
- Pricing-approval request: salesperson sends 3 unit options -> both
  heads see it in the bell -> set pre-final/final price -> requester sees
  result. (In-app notifications only; email later.)
- Cross-project interest: flag a customer interested in another B&M
  project -> notifies that project's head + shows in Sales Head bucket.
- Salesperson<->salesperson handoff (ownership moves only on Accept).
- Referral walk-in source (referrer name + optional link to existing lead).
- Wonderwall tracking: Proposed -> Visited -> Booked funnel (independent
  of revisits).
- Custom labels (colored chips) salespeople attach to walk-ins.
- Named saved filters (multi-filter builder, save & one-click recall).
- Team group chat (one company-wide chat, 💬 in header).
- Targets & incentives: auto from bookings. Salesperson sees a My-month
  bar (Target/Actual/Potential/Earned); heads set targets in Funnel.

Analytics:
- Funnel with global filters, deal-status breakdowns by salesperson &
  project, revisits-without-PH-meeting panel, lost-to-competitors panel,
  Wonderwall funnel, comment keyword search + word cloud.
- Monthly Sales Review report (Sales-Head only), brand-styled, print/PDF.

UX polish:
- Lead panel widened; two-column layout; Personal details collapsed into
  a small bar on top (fill once, tuck away); Comments & History top-right.
- Merged "Add note + Set follow-up + Log revisit" into one non-forcing box.
- Button press feedback; top progress bar during saves; drawer no longer
  jumps to top on each change; ESC closes popups; Edit-details modal.

=====================================================================
7. DATABASE MIGRATIONS & PROMOTE PROCESS (developer detail)
=====================================================================
Schema + incremental migrations live in cloud/:
  schema.sql, migration-2.sql ... migration-13.sql
Helper bundles:
  sandbox-setup.sql   — full schema + migrations, to build a fresh sandbox
  sandbox-catchup.sql — recent migrations to bring sandbox up to date
  promote-to-prod.sql — migrations 8..13 to bring PRODUCTION up to date
  fix-walkin-dates.sql— backfills imported walk-in created_at to 2026-07-09
All migrations are idempotent (add column if not exists / drop policy if
exists) so they're safe to re-run.

** IMPORTANT — production is BEHIND. ** To fully promote:
  1. In the PRODUCTION Supabase (xhlgwzpbkovqxuxarcoe) SQL editor, run
     cloud/promote-to-prod.sql (migrations 8..13). Sandbox already has these.
  2. Deploy the latest cloud/web build to the production Netlify site
     (bnmsales). If prod is linked to a `production` branch, merge
     main -> production and it auto-deploys; otherwise drag cloud/web.
  3. (One-time data) run fix-walkin-dates.sql on production if imported
     walk-in dates still look wrong.
Code-only changes (no new migration) don't need step 1.

=====================================================================
8. STILL TO DO before a wider public rollout
=====================================================================
- Finish the production promote (run promote-to-prod.sql — migs 8..13 —
  on production Supabase; get prod on the latest build). Sandbox has all
  the newest features; production is a few features behind.
- Re-enable "Confirm email" in BOTH Supabase projects (turned OFF during
  building for convenience — MUST be ON before real go-live).
- Server-side stale-lead alerts (email/WhatsApp) — a scheduled function;
  the browser can't do this. (Build-plan Step 6.)
- AI "closing-likelihood" is currently OFF in the cloud app.
- Deferred capture the owner postponed: cancellation flow, BHK/unit-size.

=====================================================================
9. DEMO / TEAM ACCOUNTS
=====================================================================
Pilot salespeople created: Amartya, Savitha, Akshay. ~100 imported
customers attached to their agents. Roles in the system: Sales Head,
Project Head (per project), Salesperson.

=====================================================================
10. IF YOU'RE A DEVELOPER PICKING THIS UP
=====================================================================
- Edit ONLY cloud/index.html; then `cp cloud/index.html cloud/web/index.html`;
  commit + push (sandbox auto-deploys).
- Never edit lead-pipeline-local.html.
- Local test server: python http.server on port 8123 serving cloud/
  (see .claude/launch.json) -> http://localhost:8123/index.html (uses
  sandbox DB because "localhost" triggers sandbox env).
- Full deeper context: HANDOVER.md and CLAUDE.md in the repo root; the
  build plan is cloud/BUILD-PLAN.md.
