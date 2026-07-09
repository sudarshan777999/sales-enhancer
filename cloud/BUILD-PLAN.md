# Sales Enhancer — Cloud Build Plan (multi-tenant, Supabase)

This is the migration plan for Claude Code. Goal: take the working single-file prototype
(`../lead-pipeline-local.html`) to a real, multi-tenant, cloud app — **without changing the
UI or business rules**, only the storage/auth layer underneath.

- **Backend:** Supabase (Postgres + Auth + Row Level Security + Edge Functions + pg_cron)
- **Auth:** email + password, password reset via email (Supabase built-in)
- **Tenancy:** multi-tenant from day one — every row carries `company_id`; RLS isolates tenants
- **Region:** create the Supabase project in **Mumbai (ap-south-1)** to keep data in India
- **Plan:** free tier is fine to build; move to **Pro ($25/mo)** before go-live (no auto-pause, backups)

Do **not** break the single-file prototype. Build the cloud app in this `cloud/` folder.

---

## Phase 1 — internal tool on the cloud (your own company as tenant #1)

### Step 1 — Database
1. Create a Supabase project (Mumbai region).
2. Open the SQL editor and run **`schema.sql`** (in this folder). It creates the tables,
   the tenant-isolation RLS policies, the walk-in date/source lock trigger, and the
   onboarding RPCs.
3. Sanity check: RLS is enabled on every table; `create_company_and_owner` and
   `accept_invite` exist.

### Step 2 — Auth (email + password + reset)
1. Authentication → Providers: enable **Email** (password). Keep "Confirm email" on.
2. Password reset works out of the box: the user requests a reset and Supabase emails a
   link. **"Reset via company email"** = the link goes to the user's work email address.
3. Set **Site URL** and **Redirect URLs** to the deployed frontend (Step 5) so the reset
   and confirmation links land back in the app.
4. Optional but recommended for branding/deliverability: configure **custom SMTP** so
   auth emails are sent *from* the company's own domain (e.g. `noreply@bricksandmilestones.com`)
   instead of Supabase's default sender. Customize the email templates too.

### Step 3 — Onboarding flow
- On first sign-up, after the user confirms their email, call the RPC
  `create_company_and_owner(company_name, full_name)`. This creates the company and makes
  that user its **Sales Head**. (For Phase 1 you'll do this once for Bricks & Milestones.)
- Adding teammates: Sales Head creates an `invitations` row (RPC/insert), the app emails the
  invite link, and the invitee signs up + calls `accept_invite(token, full_name)`.
- Seed the first project(s): insert `Earthscape` (and `Solcrest`) into `projects`.

### Step 4 — Swap the storage layer (the main coding task)
Replace the prototype's `localStorage` layer with Supabase calls using `@supabase/supabase-js`.
Keep **all UI, rendering, and business logic**. Map the prototype's data ops one-to-one:

| Prototype (localStorage) | Cloud (Supabase) |
|---|---|
| `loadDB()` (whole `db`) | On login: fetch `members` (self), `projects`, and `leads` (RLS auto-filters), plus `lead_activity` for open leads |
| `saveDB()` after each change | Targeted `insert`/`update` on the specific row (not a whole-blob save) |
| `session` / `showApp` | Supabase Auth session (`supabase.auth.getSession()` / `onAuthStateChange`) |
| `submitPw` / `signOut` | `supabase.auth.signInWithPassword` / `signOut`; reset via `resetPasswordForEmail` |
| `saveLead()` | `insert into leads` (RLS enforces owner/company) |
| `qualify/disqualify/assign/markBooked/markLost/reassignPool/setTemp` | `update leads …` |
| `addNote/logFollowUp/logRevisit` | `insert into lead_activity` (kind note/revisit) + update `leads.next_follow_up` |
| `setWalkinDate/Source/CpName` | `update leads …` (server trigger blocks non-Sales-Head) |
| `scoped()` / `visible()` | **Delete client-side filtering** — RLS already returns only permitted rows |
| `can()` | Keep for UI (hide buttons), but the DB/RLS is the real enforcement |
| `statsHTML/funnelHTML` | Same computations, but over rows fetched from Supabase |
| `assessLikelihood` | Call the Anthropic API from an Edge Function (keeps the key server-side) and store in `assessments` |

Key mindset shift: **trust the database.** RLS returns only the rows a user may see, so the
client no longer filters for security — it just renders what it gets. Keep `can()` only to
show/hide buttons.

### Step 5 — Host the frontend
- Deploy the static app to **Vercel, Netlify, or Cloudflare Pages** (all have free tiers).
- Add a `manifest.json` + service worker to make it a **PWA** so salespeople can install it
  on their phone home screen.
- Point Supabase Auth Site URL/redirects at this domain.

### Step 6 — Notifications (the stale-lead alerts, server-side)
The browser can't alert people who don't have the app open — move the 7-day checks to the server.
1. Write a scheduled **Edge Function** (or SQL function) run daily via **pg_cron** that finds:
   - **Stale qualified:** `stage='qualified'` and no `lead_activity` in the last 7 days.
   - **Decision overdue:** `stage='assigned'`, `qualified is null`, `assigned_at < today-7`.
2. For each hit, look up the company's **Sales Head + the relevant Project Head** and send them
   an alert. Start with **email** (Resend or your SMTP) — trivial and ~free at this volume.
3. Reuse the in-app bell (it already reads these conditions live) for people who are online.

Core query the job runs (per company):
```sql
-- stale qualified leads (no activity in 7 days)
select l.id, l.name, l.project_id, l.owner_id, l.company_id
from leads l
where l.stage = 'qualified'
  and coalesce((select max(a.created_at)::date from lead_activity a where a.lead_id = l.id),
               l.created_at) < current_date - 7;
```

---

## Phase 2 — turn it into a SaaS (when Phase 1 has proven itself)
Everything below is *additive* because the schema is already multi-tenant.
- **Self-serve signup UI:** public sign-up → `create_company_and_owner` → onboarding wizard
  (create projects, invite team). A second developer company is just another `companies` row.
- **Billing:** add **Razorpay** (India-first: UPI, INR, GST) for domestic customers; add **Stripe**
  if/when you sell internationally. Store plan/status on `companies` (columns already exist).
  Don't build this until you have a paying customer.
- **Super-admin:** a platform-owner view across tenants (separate, tightly-scoped access — do
  **not** loosen tenant RLS for this; use a dedicated admin path/service role).
- **WhatsApp alerts:** add a BSP (Wati / Interakt / AiSensy) for utility-template notifications
  in addition to email — high-signal for Indian real estate.
- **Hardening for customers:** enable Supabase daily backups (Pro), add audit logging, review
  every RLS policy, set up staging vs production projects.

---

## Guardrails
- Keep the prototype (`../lead-pipeline-local.html`) working as the reference/demo.
- Never weaken tenant isolation: every new table gets `company_id` + an RLS policy before use.
- Preserve the business rules in `../HANDOVER.md` §9 exactly (roles, both 7-day SLAs, the
  disqualified-pool reassignment, the walk-in date/source lock — the last one is enforced by a
  DB trigger in `schema.sql`).
- Dates: store as `date`/`timestamptz` and format in the user's local zone in the UI (the
  prototype's `toISOString` bug — don't reintroduce it).
