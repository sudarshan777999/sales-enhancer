# Sales Enhancer — Handover Document

_Last updated: 2026-08-02_

**Product:** a lead & walk-in management CRM for a real-estate developer.
**Tenant/instance in build:** Bricks & Milestones · **Projects:** Earthscape (primary), Solcrest, Lagos.
**Status:** **Live cloud app in pilot.** (The original single-file prototype still exists as a reference/demo.)

---

## 1. The short story (what happened so far)

1. **Started as a prototype** — one self-contained HTML file (`lead-pipeline-local.html`), vanilla HTML/CSS/JS, no build, saved only in one browser's `localStorage`. Ran by double-click. This still exists and is untouched.
2. **Went to the cloud** — the app was rebuilt on **Supabase** (Postgres database + real logins + Row Level Security) with the UI kept identical. The storage layer was swapped from `localStorage` to Supabase API calls.
3. **Hosted on Netlify** — the app now runs on the internet, multi-user, and works even with your Mac turned off.
4. **Two environments** — a **sandbox** for testing and **production** for real use. New features land on sandbox first, you review, then they're promoted to production.
5. **Actively growing** — dozens of features have been added since go-live (see §5). Newest is the **Deal Coach** (AI next-best-action suggestions).

---

## 2. Where everything lives (the setup)

| Piece | What it is | Details |
|---|---|---|
| **Production site** | Your real, live app | `https://bnmsales.netlify.app` |
| **Sandbox site** | Safe copy for testing | Netlify site `bnmsales-sandbox` |
| **Production database** | Real customer data | Supabase project ref `xhlgwzpbkovqxuxarcoe` |
| **Sandbox database** | Test data (isolated) | Supabase project ref `tadcupqosvvjndxyyerc` |
| **Source code** | The app itself | `cloud/index.html` (canonical), published from `cloud/web/` |
| **Code backup** | GitHub | `github.com/sudarshan777999/sales-enhancer` (public repo) |
| **Local test server** | For development | `http://localhost:8123/index.html` (serves `cloud/`) |

**How the app knows which database to use:** it checks the web address. If the address contains `sandbox`, `localhost`, or `127.0.0.1` → it uses the **sandbox** database and shows a red SANDBOX banner. Otherwise → **production**.

---

## 3. Files in this project

| File | Purpose |
|---|---|
| `cloud/index.html` | **The canonical cloud app.** All feature work happens here. |
| `cloud/web/index.html` | The published copy (what Netlify serves). Update by copying from `cloud/index.html`. |
| `cloud/*.sql` | Database setup + migrations (see §7). |
| `cloud/manifest.json`, `cloud/icon.svg` | PWA bits (install-to-home-screen). |
| `lead-pipeline-local.html` | **Original offline prototype.** Do NOT modify — kept as the reference/demo. |
| `lead-pipeline.html` | Old reference variant (ran inside Claude). Not used. |
| `CLAUDE.md` | Instructions Claude Code auto-loads. |
| `HANDOVER.md` | This document. |

---

## 4. Roles & permissions

| Role | Sees | Can do |
|---|---|---|
| **Sales Head** (You) | All leads, all projects | Everything: edit/delete, reassign, change walk-in date & source, all analytics, team management, bulk import, targets, reports |
| **Project Head** | All leads in **their own project** only (an Earthscape head can't see Solcrest) | Full rights within their project |
| **Salesperson** | **Only their own** leads (plus leads they co-own) | Create + edit their own; cannot delete; cannot change walk-in date/source once entered |
| **Reception** (front desk) | A single walk-in entry form only — no pipeline, no analytics | Enter new walk-ins and assign them to a salesperson |

Permissions are enforced two ways: in the browser via `can(action, lead)` and `scoped()`, **and** on the server via Supabase Row Level Security (so they can't be bypassed).

---

## 5. Features (all live)

**Capture & pipeline**
- Digital leads and walk-ins. Walk-in extras: Direct vs Channel Partner (with CP name), location, company, budget, editable walk-in date, **Phase 1 / Phase 2**.
- Phone is now **optional** for walk-ins (leads merge by name + a shared random code).
- **Bulk walk-in import** — CSV upload or paste box; template provided; unmatched agents held unassigned and attached later.
- **Reception / front-desk** login for entering walk-ins.
- Pipeline board (drag-friendly, full-width), quick period filters (This month / Last month), bulk assign (Migrate or Share).

**The customer journey**
- Stages: `new → assigned → qualified → booked (won)`, with branches to `not_qualified` (disqualified pool) and `lost`.
- Deal status: Prospect / Negotiation / Closed Won / Closed Lost.
- Qualify / disqualify (salespeople can disqualify their own leads in any state); disqualified pool reassignment by heads.
- **Met Project Head** tracking (with a lock so project heads can't edit their own meeting record).

**Follow-ups, notes & reminders**
- Combined update block: add a note, set a follow-up, and/or log a revisit in one place.
- Walk-in updates by salespeople require a follow-up (defaults to +48h).
- History timeline; revisits with notes and a per-lead counter.
- Two 7-day SLAs: Decision SLA (qualify/disqualify within 7 days) and Stale-qualified alert (no action for 7 days → notify heads).
- **Attention colours** — cards go amber (>5 days untouched) then red (>7 days).

**Sales workflow extras**
- **Salesperson → salesperson handoff** (ownership moves only on accept).
- **Cross-project interest** (notify another project's head).
- **Co-ownership** (shared owners with equal access).
- **Price offered / blocks (A–F) / competitors** capture.
- **Pricing-approval requests** — rep sends 3 unit options → heads set pre-final/final price → in-app notifications.
- **Last quote** capture; **Referral** walk-in source with referrer link.
- **Wonderwall** tracking (proposed → visited → booked).
- **Booking capture** — unit, agreement value, size, realization (auto-calc), payment scheme, applicant details.
- **Lost-to-competitor** reason capture.

**Team & productivity**
- **Team invites** (email + role + project) via invite link.
- **Assignable tasks** — now multi-owner; a "Tasks" dashboard tab (assigned to me / by me / recently completed).
- **Shared team labels** (create once, everyone sees; per-user delete).
- **Team group chat** (one company-wide chat).
- **Targets & incentives** — per-rep monthly targets; earned incentive auto-computed from bookings.
- **Floating toast notifications** for incoming leads, pricing, handoffs, tasks.
- **Deal Coach + Today's Plays + Escalation** — AI next-best-action: every open lead always shows a suggested next step; a "Today's plays" tab; heads get escalation alerts for salespeople with neglected leads.

**Analytics & reporting**
- Follow-up stats, Funnel (with drill-downs — every number is clickable), Ageing analysis (role-scoped tree), Deal-status distributions.
- **Report builder** — nested AND/OR conditions, saved named reports (column picker / group-by / CSV export are a planned Stage 2).
- **Natural-language "ask" box** — type a plain-English question, get matching leads.
- **Monthly Sales Review report** — brand-styled, print/save-as-PDF, auto-computed from live data + editable historical figures.
- **Comment insights** (blocker/signal buckets), **word cloud** with click-to-filter.
- **Saved filters** and **custom labels**.
- Sales-Head one-click **full-data JSON backup**.

---

## 6. Data model (cloud / Supabase)

Core tables (all scoped by `company_id`, protected by Row Level Security):

- `companies` — the tenant (Bricks & Milestones). Holds `report_data`.
- `projects` — Earthscape, Solcrest, Lagos (auto-created on Sales Head login).
- `members` — users: `role` (`sales_head` | `project_head` | `sales` | `reception`), `project_id`, `prefs` (saved filters, labels, panel order, saved reports, targets).
- `leads` — the main record: name, phone (optional), source, walk-in details, stage, deal_status, owner_id + `co_owners[]`, qualified/nq_reason, temp/deal fields, next_follow_up, `booking` (jsonb), `walkin_phase`, `labels`, price_offered, `blocks`, competitors, lost_to, `last_quote`, `wonderwall_*`, met_project_head + ph_meeting_date.
- `lead_activity` — the timeline (notes, revisits, system events).
- `tasks` — assignable tasks (multi-assignee).
- `invitations` — pending team invites (with accept token).
- `transfer_requests` + `cross_interest` — handoffs & cross-project interest.
- `pricing_requests` — pricing-approval flow.
- `promotions` — payment-scheme catalog.
- `messages` — team group chat.
- `targets` — per-member monthly target + incentive.

**Date rule (important):** dates are stored as local `YYYY-MM-DD`. Never use `toISOString()` — it caused an IST off-by-one bug (dates showed a day early).

---

## 7. Database migrations

The database was built up through a numbered series of SQL migrations (`cloud/migration-2.sql` … `migration-21.sql`, plus `schema.sql`, `sandbox-setup.sql`, and `promote-to-prod.sql`). Highlights: booking, walk-in phase, handoffs/cross-project, deal status + met-PH lock, saved filters/labels, tasks, targets/incentives, promotions/schemes, reception role, referral source, pricing requests, wonderwall, lost-to, chat, co-ownership/blocks/competitors, and RLS fixes for disqualify.

**Both databases are currently caught up** through the latest promoted migrations. `promote-to-prod.sql` bundles the set that production needs.

---

## 8. Deploy / promote flow

**For code-only changes (no new database columns):**
1. Edit `cloud/index.html`.
2. Copy it to the published folder: `cp cloud/index.html cloud/web/index.html`.
3. `git push` on `main` → Netlify **auto-deploys to sandbox**.
4. You review on the sandbox site.
5. Promote to production: `git checkout production && git merge main && git push origin production` → Netlify auto-deploys `bnmsales`. Then `git checkout main`.

**For changes that need a new database column/table:**
- Run the migration SQL on the **sandbox** Supabase first, review, then run it on **production** Supabase **before** the code that uses it goes live. (Database change first, then code.)

**Branch note:** `main` deploys sandbox; `production` deploys prod. As of the last clean reset, `origin/main == origin/production` for the app code — the old "Channelforce" commits were cleared off `main` (they live in a separate private repo). Keep them separate so promotes stay clean.

---

## 9. Business rules to preserve (do not regress)

1. Salespeople see only their own (or co-owned) leads; project heads see their project; sales head sees all.
2. Salespeople can create + edit but **not delete**.
3. Disqualifying moves a lead to the disqualified pool for heads to reassign (owner is kept, not nulled — a recent fix).
4. Walk-in date & source are locked after entry for everyone except the Sales Head.
5. Decision SLA: qualify/disqualify within 7 days of assignment.
6. Stale-qualified alert: qualified + no follow-up for 7 days → notify heads until booked/lost.
7. Dates are local (`iso()`), never UTC.
8. Strict per-project isolation for project heads.

---

## 10. Still to do (before wider rollout)

- **Re-enable "Confirm email"** in BOTH Supabase projects (turned OFF for easy testing during the build).
- **Server-side stale-lead alerts** — scheduled Supabase function to email/WhatsApp reminders (the browser can't do this on its own).
- **Turn the AI closing-likelihood feature back on** (needs an API key server-side).
- **Report builder Stage 2** — column picker, group-by/aggregations, CSV export, maybe charts.
- Add a service worker before go-live (deliberately omitted during active dev to avoid stale caches).

---

## 11. Scope note

This document covers **Sales Enhancer only** (the Bricks & Milestones app).

**Channelforce** — the separate broker product — is a different codebase in its own private repo and has its **own handover document**. Do not mix the two. (There is also a longer-term "Sales Enhancer as SaaS" direction for licensing this app to other real-estate companies; that remains a future idea, not part of the current build.)
