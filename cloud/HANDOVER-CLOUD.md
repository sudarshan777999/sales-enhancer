SALES ENHANCER — CLOUD BUILD HANDOVER
Bricks & Milestones · Project: Earthscape (also Solcrest, Lagos)
Last updated: 2026-07-11 (supersedes the 2026-07-10 version)

=====================================================================
1. WHAT THIS IS (plain English)
=====================================================================
Sales Enhancer is a lead & walk-in management CRM for a real-estate
developer. It follows a customer from first contact to booked or lost:

  capture -> assign owner -> qualify/disqualify -> follow-up (reminders)
  -> booked (won) or lost, plus walk-in revisits, deal status, tasks,
  SLAs, alerts, and analytics for the sales leadership.

It began as a single offline HTML file (the "prototype") and is now a
REAL multi-user cloud app the whole team logs into from any device, with
data stored securely in the cloud.

=====================================================================
2. THE THREE PLACES YOUR APP LIVES
=====================================================================
A) LIVE TEAM SITE (production) — what the team uses
   URL:  https://bnmsales.netlify.app
   Data: Supabase project "xhlgwzpbkovqxuxarcoe"

B) SANDBOX (private testing copy) — where changes are reviewed
   URL:  https://bnmsales-sandbox.netlify.app
   Data: Supabase project "tadcupqosvvjndxyyerc" (separate data)

C) OLD OFFLINE PROTOTYPE — never delete, kept for reference
   File: lead-pipeline-local.html (double-click to run; per-browser data)

The app detects its environment from the web address: contains
"sandbox"/"localhost" -> sandbox database + red SANDBOX banner; else
production.

=====================================================================
3. HOW CHANGES REACH YOU (deploy rhythm)
=====================================================================
1. Edit the source (cloud/index.html) and copy to cloud/web/index.html.
2. Commit + push to GitHub.
3. Sandbox auto-updates from GitHub (branch `main`) in ~1 minute.
4. Review the sandbox (hard-refresh: Cmd+Shift+R).
5. Say "promote" -> the same build goes live on the team site
   (merge main -> `production` branch, which the prod Netlify deploys).
   If a change added a database migration, that SQL is run on the
   production Supabase FIRST, then the code is deployed.

=====================================================================
4. TECH STACK (for a developer / future Claude)
=====================================================================
- Front end: ONE file, cloud/index.html — vanilla HTML/CSS/JS, no
  framework, no build step. Publish copy: cloud/web/index.html.
  External deps: @supabase/supabase-js@2 (CDN) + Google Fonts.
- Back end: Supabase (Postgres + Auth + Row Level Security + RPCs).
  Two projects: production (xhlgwzpbkovqxuxarcoe) & sandbox
  (tadcupqosvvjndxyyerc). Anon public keys are baked into index.html
  (safe — every table is RLS-protected). service_role key is NEVER in
  the code or shared anywhere.
- Hosting: Netlify. Sandbox auto-deploys from `main` (publish cloud/web);
  production deploys from the `production` branch at promote time.
- Source backup: PUBLIC GitHub repo github.com/sudarshan777999/sales-enhancer
  (public so Netlify free-tier auto-deploy works; contains no secrets).

KEY CODE CONVENTIONS (preserve):
- Global `db` = {instance, users, leads, tasks, ...}; `session` = user id.
- Reads: scoped() (permission filter) then visible() (search/filters).
- Every change: targeted Supabase write, then refresh() (reload+render).
- Dates: local YYYY-MM-DD via iso(). NEVER toISOString() for stored
  dates (caused an IST off-by-one; fixed).
- Permissions centralised in can(action, lead); mirrors the DB RLS.
- leadFromRow(r) maps DB snake_case -> app camelCase.
- Env config at top of index.html: ENV_PROD / ENV_SANDBOX / IS_SANDBOX.

=====================================================================
5. ROLES & VISIBILITY (confirmed by owner — keep exact)
=====================================================================
- Sales Head: sees everything across all projects; full access.
- Project Head: full rights but ONLY their own project (Earthscape PH
  cannot see Solcrest). Enforced in DB (RLS) + client.
- Salesperson: their own leads (plus any lead where they're a co-owner).
- Receptionist (front desk / "GRE"): a stripped-down role that ONLY
  enters walk-ins and assigns them to a salesperson (see section 6).
- Two 7-day SLAs, disqualified-pool reassignment, and walk-in
  date/source locks are business rules from the prototype — preserve.
- Met-Project-Head flag: a Project Head CANNOT change it (DB trigger).

Login note: users sign in with an EMAIL or a USERNAME. Usernames with
no "@" are mapped to a hidden internal address (`<user>@bnm.local`), so
front-desk logins like "gre_earthscape" work as plain usernames.

=====================================================================
6. FEATURES BUILT (everything currently live)
=====================================================================
CAPTURE & TEAM
- Real email/username + password login; first login creates the company.
- Team invites (Sales Head) + a "Create front-desk login" tool that
  mints a Receptionist account with a username+password in one click.
- Bulk walk-in import (CSV or paste box; phone optional; mark-qualified).
- RECEPTIONIST front desk: a single clean "New walk-in" screen — name,
  phone (optional), walk-in date (defaults today), Source (Direct ->
  Hoarding/Digital/Referral, or Channel Partner -> CP name), location,
  "This is a revisit" checkbox, and Assign-to-salesperson. Every walk-in
  they add gets a green "GRE" badge everywhere it appears.
- Front-desk REVISIT merge: GRE marks a walk-in as a revisit -> the
  salesperson matches it to the customer's earlier walk-in by phone and
  clicks Merge (logs a revisit on the earlier one, tucks the duplicate).

PIPELINE & DEAL FLOW
- Board (Kanban) + List view toggle; List shows recent comments + many
  columns; capture/walk-in date shown on every surface.
- Full-width board (no cut-off columns) + "attention" colours: cards not
  touched for 5+ days go amber, 7+ days red, with an "Untouched Xd" chip.
- Deal status: Prospect / Negotiation / Closed Won / Closed Lost.
- Booking form (unit, AV, size, auto realization, payment structure,
  applicant/co-applicant); shared co-ownership; price offered; last
  price quoted (3 units); block interest A-F; competitor tracking;
  "lost to which competitor".
- Pricing-approval requests (3 unit options + payment scheme -> heads
  reply with pre-final/final price; in-app notifications).
- Payment schemes / promo codes: a Sales-Head-only "Schemes" manager
  (Pre EMI, CLP, add more) that feeds the pricing-request dropdown.
- Cross-project interest; salesperson<->salesperson handoff; referral
  source; Wonderwall tracking (Proposed->Visited->Booked).
- Owner can be a salesperson OR (for the Sales Head) a Project Head.
- Custom colour labels; named saved filters; quick views (Last 15/30
  days walk-ins); "Captured between" date-range filter.

TASKS
- Anyone can assign a task to anyone (e.g. salesperson -> Sales Head or
  Project Head) via an "Assign to" picker on each walk-in.
- Assignee answers in a text box + marks Done; the answer lands in the
  walk-in history. Floating labels both ways (assigned / completed).
- FLOATING Tasks dock (left by default, drag to reposition, collapses
  but cannot be closed): To me / By me / Recently completed.
  (A separate Tasks *tab* existed briefly but was removed as redundant.)

NOTIFICATIONS
- Floating labels (toasts) that persist until clicked; a bell panel with
  per-item dismiss (x) + "Clear all"; the bell count adjusts and
  dismissals are remembered per user.

TEAM CHAT
- One company-wide group chat (the 💬 button).

ANALYTICS
- Funnel (heads): SLA stats, targets & incentives, stage & deal-status
  breakdowns, revisits-without-PH-meeting, lost-to-competitors,
  Wonderwall funnel — and nearly every number is CLICKABLE, opening a
  popup of those exact walk-ins (recent comments + quick assign-task).
- "Ask" box (all users): plain-English queries like "revisited and
  project head didn't meet and lost" -> matching walk-ins; save queries
  as chips.
- Ageing analysis tab: an intuitive expand/collapse TREE of open
  qualified walk-ins by days-since-qualified, >7 days in red. Role-
  scoped: salesperson (own), Project Head (their project), Sales Head
  (project-wise, auto-includes new projects).
- Comment "themes" (Stats tab): auto-grouped Competitors / Locations &
  projects / Unit types / Other — clickable to the walk-ins.
- Drag-to-reorder panels in Funnel / Stats / Ageing (order saved).
- REPORT BUILDER (Builder tab, all users): tap a field (Owner, Stage,
  Project, Deal status, Captured-between, …) -> pick its values as chips
  (one or many), combine with ALL/ANY. Filtered fields auto-become
  result columns; pick more columns; Group-by counts with % share;
  export CSV; save & reload named reports (remembers filters + columns).
- Monthly Sales Review report (Sales-Head only), brand-styled, print/PDF.

=====================================================================
7. DATABASE MIGRATIONS & PROMOTE (developer detail)
=====================================================================
cloud/ holds schema.sql + migration-2.sql … migration-19.sql, applied
incrementally. What each recent one adds:
  8  co-ownership, price offered, blocks, competitors
  9  referral source + pricing_requests
  10 Wonderwall flags
  11 lost_to + messages (team chat)
  12 last_quote
  13 targets (targets & incentives)
  14 promotions (payment schemes) + scheme on pricing_requests
  15 tasks
  16 reception role
  17 pending_revisit + merged_into (front-desk revisit merge)
  18 via_gre (GRE badge)  [+ backfill-gre.sql for old rows]
  19 relaxed task-insert RLS so anyone (not just heads) can assign tasks
All migrations are idempotent (add-if-not-exists / drop-policy-if-exists).

** STATUS: production Supabase is CAUGHT UP through migration-19 and
   every feature above is LIVE on bnmsales.netlify.app. **

Promote flow (for a new change with a migration):
  1. Run the migration SQL on the PRODUCTION Supabase (xhlgwzpbkovqxuxarcoe).
  2. git checkout production && git merge main && git push origin production
     (prod Netlify auto-deploys). Then back to main.
Code-only changes skip step 1.

Sandbox note: the sandbox database may be a few migrations behind (it's
been used mainly to build; production is the source of truth). Run the
relevant migrations on sandbox before testing DB-dependent features there.

=====================================================================
8. STILL TO DO before a wider public rollout
=====================================================================
- Re-enable "Confirm email" in BOTH Supabase projects (turned OFF during
  building — MUST be ON before opening beyond the pilot team).
- Server-side stale-lead alerts (email/WhatsApp) — a scheduled function
  (Supabase Edge Function); the browser can't do this. (Build-plan Step 6.)
- WhatsApp customer chat: researched, deferred. Only real path is the
  WhatsApp Business Platform via a BSP (AiSensy/WATI/Interakt/360dialog);
  needs a dedicated number, Meta business verification, per-message cost.
  A free "click-to-WhatsApp" button is a quick interim option.
- AI "closing-likelihood" is OFF in the cloud app.
- Deferred capture the owner postponed: cancellation flow, BHK/unit-size.

=====================================================================
9. TEAM / DEMO ACCOUNTS
=====================================================================
Pilot salespeople: Amartya, Savitha, Akshay. ~100 imported customers
attached to agents. Roles: Sales Head, Project Head (per project),
Salesperson, Receptionist (front desk / GRE).

=====================================================================
10. IF YOU'RE A DEVELOPER PICKING THIS UP
=====================================================================
- Edit ONLY cloud/index.html; then cp cloud/index.html cloud/web/index.html;
  commit + push (sandbox auto-deploys). Never edit lead-pipeline-local.html.
- Local test server: python http.server on port 8123 serving cloud/
  (see .claude/launch.json) -> http://localhost:8123/index.html (uses
  the sandbox DB because "localhost" triggers sandbox env).
- Some features are kept but currently unused/dormant in the tab bar
  (they can be re-enabled in one line) — don't hard-delete on a whim.
- Deeper context: HANDOVER.md and CLAUDE.md in the repo root; the build
  plan is cloud/BUILD-PLAN.md.
