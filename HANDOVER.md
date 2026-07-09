# Sales Enhancer — Handover Document

**Product:** a lead & walk-in management CRM for a real-estate developer.
**Tenant/instance in build:** Bricks & Milestones · **Project:** Earthscape (Solcrest available as a second project).
**Current form:** one self-contained HTML file (vanilla HTML/CSS/JS, no build, no dependencies except Google Fonts).
**Status:** working prototype / simulation. Not yet production (see "Limitations" and "Cloud roadmap").

---

## 1. Files

| File | Purpose | Storage | AI feature |
|---|---|---|---|
| `lead-pipeline-local.html` | **Canonical.** Runs offline by double-click. | Browser `localStorage` | Disabled |
| `lead-pipeline.html` | Reference only; runs inside Claude. | Claude `window.storage` | Enabled (Anthropic API) |
| `CLAUDE.md` | Instructions Claude Code auto-loads. | — | — |
| `HANDOVER.md` | This document. | — | — |

The two HTML files are logically identical except:
1. **Storage layer** — `localStorage` (local) vs `window.storage` async (Claude).
2. **AI likelihood** — the local file shows a "turned off" note instead of the assess button.
3. Login footer copy.

For all future work, treat `lead-pipeline-local.html` as the source of truth.

---

## 2. Roles & permissions

Four seeded accounts; each sets its own password on first sign-in.

| Role | User(s) | Sees | Can do |
|---|---|---|---|
| Sales Head | You | All leads, all projects | Everything: edit/delete, reassign, **change walk-in date & source**, all analytics |
| Project Head | Sanyog | All leads in **their project** (Earthscape) | Edit, reassign disqualified, delete, analytics |
| Salesperson | Amartya, Savita | **Only their own** leads | Create + edit their own; **cannot delete**; **cannot change walk-in date/source once entered**; cannot reassign |

Permissions are centralised in `can(action, lead)` where `action` ∈ `create | view | edit | delete | assign`. Data visibility is enforced by `scoped()`.

---

## 3. The customer journey (stages)

`new → assigned → qualified → booked (won)` — with branches to `not_qualified` (disqualified pool) and `lost`.

Internal stage keys: `new`, `assigned`, `qualified`, `booked`, `lost`, `not_qualified`.

---

## 4. Feature set (all implemented)

**Capture**
- Source = **digital** (channel: Website, Google Ads, Meta, portal, referral, WhatsApp) or **walk-in**.
- Walk-in extras: **Direct vs CP** (channel partner) with **CP name**, **location**, **company**, and an **editable walk-in date** (defaults to today).
- Salesperson-created leads auto-own to that rep and start at `assigned`.

**Ownership** — heads assign/reassign a salesperson; assigning stamps `assignedAt`.

**Qualify / Disqualify**
- Qualify → `qualified`, sets a default follow-up date, enables temperature.
- Disqualify → records reason + `disqualifiedBy`, **clears owner**, moves lead to the **disqualified pool** (`not_qualified`), out of the rep's bucket. A head can **Reassign for follow-up** to another rep (restarts the 7-day decision clock).

**Temperature** — Hot / Warm / Cold, set once qualified. Shown as a chip on cards.

**AI closing-likelihood** (Claude version only) — reads the rep's follow-up comments and returns a % likelihood, a suggested temperature, a one-line rationale, and signal phrases. Stored on the lead as `assessment`.

**Follow-ups & notes** — two salesperson actions:
- **Add note** — text only → an activity comment.
- **Set follow-up** — text + reminder date → comment plus a `nextFollowUp` reminder.

**History timeline** — chronological (newest first). Notes/follow-ups render as quote cards; revisits as purple markers; stage changes as quiet markers. Each entry carries date + author.

**Revisits** — log a revisit with a date; per-lead counter (Total visits / Revisits); card chip; per-rep revisit stats.

**Two 7-day SLAs**
1. **Decision SLA** — an `assigned` lead must be qualified/disqualified within 7 days of `assignedAt`. Card shows amber "Decide in Nd" → red "Decision overdue Nd".
2. **Stale-qualified alert** — a `qualified` lead with **no follow-up action for 7 days** flags for the heads (bell + alerts panel + card flag + funnel count). Clears when the lead is booked/lost or gets a fresh action. A 60-second timer re-checks.

**Locks** — walk-in **date** and **source** can't be changed by salespeople after entry; only the **Sales Head** sees the edit controls.

**Analytics**
- **Follow-up stats** tab (role-scoped): totals, due now, avg follow-ups per qualified, win rate, follow-ups by salesperson, temperature mix, outcomes; plus **Direct vs CP** and **by-channel-partner** tables and **Visits & revisits** stats (heads only).
- **Funnel** tab (heads only): time window (**This month / 60 / 90 / Custom** date range), walk-in funnel (Walk-ins → Qualified → Booked), "where the walk-ins are sitting", qualification by salesperson (qualified vs disqualified — spot over-disqualifiers), Hot/Warm/Cold, revisits by salesperson, and SLA counters (awaiting decision / overdue / stalled).

---

## 5. Data model

`db = { instance: string, users: User[], leads: Lead[] }`, persisted whole under one storage key.

**User**
```
id, name, role ('sales_head'|'project_head'|'sales'), title,
project (string|null), pass (hash|null)
```

**Lead**
```
id, name, phone, email,
source ('digital'|'walkin'), srcDetail,
walkinSource ('Direct'|'CP'|''), cpName, location, company,
project, budget, notes,
stage ('new'|'assigned'|'qualified'|'booked'|'lost'|'not_qualified'),
ownerId (User.id|null), assignedAt (YYYY-MM-DD|null),
qualified (null|true|false), nqReason, disqualifiedBy, lostReason,
temp ('Hot'|'Warm'|'Cold'|null),
assessment ({likelihood, temperature, rationale, signals[], at}|null),
nextFollowUp (YYYY-MM-DD|null),
revisits ([{date, by}]),
createdAt (YYYY-MM-DD)   // == the walk-in date for walk-ins
log ([{ t, d (YYYY-MM-DD), kind ('note'|'revisit'|'system'), by, next? }])
```

Storage keys: `bm_db_v1`, `bm_session_v1`.

---

## 6. Code map (single-file JS)

- **Storage:** `loadDB / saveDB / loadSession / saveSession / clearSession`, `boot`
- **Auth:** `showLogin / showApp / renderLogin / pickUser / submitPw / signOut`, `hash`
- **Permissions/scope:** `can`, `scoped`, `visible`, `currentUser`, `userName`, `salespeople`
- **Render:** `render`, `renderTabs`, `renderKPIs`, `cardHTML`, `boardHTML`, `followupsHTML`, `tableHTML`, `statsHTML`, `funnelHTML`
- **Drawer:** `openDrawer / closeDrawer / renderDrawer`, `visitsBlock`, `editWalkinBlock`, `followBlock`, `timelineHTML`, `likelihoodBlock`
- **Mutations:** `push`, `addNote`, `logFollowUp`, `setTemp`, `qualify`, `disqualify`, `assign`, `reassignPool`, `markBooked`, `markLost`, `reopen`, `logRevisit`, `setWalkinDate / setWalkinSource / setCpName`, `assessLikelihood`
- **Modal:** `openModal / closeModal / setSrc / toggleCP / saveLead`
- **Alerts:** `staleQualified`, `notifyItems`, `refreshNotifyBadge`, `toggleNotify / renderNotify / closeNotify`
- **Time window / SLA:** `rangeStart / rangeEnd / inRange / setRange / setRangeCustom`, `slaState`
- **Helpers:** `uid`, `today`, `parseD`, `iso`, `addDays`, `initials`, `fmtDate`, `dueState`

**Date rule:** `iso()` formats from **local** components. Never use `toISOString()` (it caused an IST off-by-one — dates showed a day early).

---

## 7. Known limitations (why this isn't production)

- **Per-browser storage.** Data lives in one browser's `localStorage`. Nothing is shared between people or devices; the Amartya-vs-Savita isolation is simulated by logging in/out in one browser.
- **Auth not secure.** Passwords are hashed client-side for show only; a real system hashes server-side (bcrypt/argon2).
- **Permissions are browser-side.** `can()`/`scoped()` run in the client, so they're bypassable — not real security.
- **Notifications are in-app only.** The bell works only while a head has the app open; there's no email/WhatsApp push.
- **AI likelihood needs Claude/an API key** — off in the offline file.

---

## 8. Cloud roadmap (the next milestone)

Goal: real multi-user, secure, shared, with server-enforced permissions and real notifications. Keep the current UI; replace the storage layer with API calls.

**Recommended stack:** Supabase (Postgres + Auth + Row Level Security) + a scheduled Edge Function for notifications. (Firebase is a viable alternative.)

### Suggested schema
```
companies(id, name)                                  -- tenant, e.g. "Bricks & Milestones"
projects(id, company_id, name)                       -- "Earthscape", "Solcrest"
profiles(id -> auth.users, company_id, name,
         role 'sales_head'|'project_head'|'sales',
         project_id nullable)                         -- project scoping for heads/reps
leads(id, company_id, project_id, owner_id,
      name, phone, email, source, src_detail,
      walkin_source, cp_name, location, company_name,
      budget, notes, stage,
      qualified, nq_reason, disqualified_by, lost_reason,
      temp, next_follow_up, assigned_at, created_at)   -- created_at doubles as walk-in date
lead_activity(id, lead_id, kind 'note'|'revisit'|'system',
      body, author_id, next_follow_up, created_at)     -- the timeline/log
revisits(id, lead_id, visited_on, logged_by)           -- or fold into lead_activity(kind='revisit')
assessments(id, lead_id, likelihood, temperature,
      rationale, signals jsonb, created_at)            -- AI likelihood history
```

### Row Level Security (the rules that enforce the buckets on the server)
- **sales_head:** full read/write on all rows within their `company_id`.
- **project_head:** read/write on rows where `leads.project_id = profile.project_id`.
- **sales:** read/write only where `leads.owner_id = auth.uid()`. On disqualify, `owner_id` is set null → the row leaves the rep's view automatically; heads reassign it.
- Field-level: only `sales_head` may update `leads.created_at` (walk-in date) and `walkin_source`/`cp_name`.

### Server jobs (what the browser can't do)
- **Stale-qualified sweep:** a scheduled function that finds `qualified` leads with no `lead_activity` in 7 days and notifies the Project Head + Sales Head by email/WhatsApp.
- **Decision-SLA sweep:** `assigned` leads with no qualify/disqualify within 7 days of `assigned_at`.

### Migration steps (suggested for Claude Code)
1. Stand up Supabase; create the schema + RLS above; seed the four demo users.
2. Build a small API/client module that mirrors the current `db` operations (get leads, create, update stage, add activity, etc.).
3. Swap the single-file app's storage calls (`saveDB`/`loadDB`) for that client; keep all UI and business logic.
4. Wire real auth (Supabase Auth) in place of the local password/session code.
5. Add the two scheduled notification functions.
6. Keep the single-file prototype untouched as the reference/demo (e.g. move cloud work into a `cloud/` subfolder).

---

## 9. Business rules to preserve (do not regress)
1. Salespeople see only their own leads; heads see project/all.
2. Salespeople can create + edit but **not delete**.
3. Disqualifying a walk-in **removes it from the rep's bucket** into the disqualified pool; heads reassign.
4. **Walk-in date & source are locked** after entry for everyone except the Sales Head.
5. **Decision SLA:** qualify/disqualify within 7 days of assignment.
6. **Stale-qualified alert:** qualified + no follow-up for 7 days → notify heads until booked/lost.
7. Dates are local (`iso()`), never UTC.
