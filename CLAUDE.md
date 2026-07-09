# CLAUDE.md — Sales Enhancer

> This file is read automatically by Claude Code when it starts in this folder.
> Keep it short and current. Deeper detail lives in `HANDOVER.md`.

## What this project is
**Sales Enhancer** is a lead & walk-in management CRM for a real-estate developer.
Tenant/instance in the current build: **Bricks & Milestones**. Primary project: **Earthscape** (Solcrest also exists as a project option).

It tracks a customer's journey: **capture → assign owner → qualify/disqualify → follow-up (with reminders) → booked (won) or lost**, plus walk-in revisits, temperature (Hot/Warm/Cold), SLAs, alerts, and analytics funnels for the sales leadership.

## Current state (prototype)
The whole app is **one self-contained HTML file** — vanilla HTML/CSS/JS, no framework, no build step, no npm. The only external dependency is Google Fonts (Space Grotesk + Inter) loaded via `<link>`.

There are two variants of the same app:

- **`lead-pipeline-local.html`** ← the canonical file to work on. Persists to the browser's `localStorage`; runs by double-clicking; the AI "closing-likelihood" feature is disabled (no API key locally).
- **`lead-pipeline.html`** — identical UI but persists to Claude's artifact storage (`window.storage`) and enables the AI likelihood call to the Anthropic API. Kept only for reference; **don't** target this one for the cloud work.

If you change app logic, change `lead-pipeline-local.html`. The two files historically shared identical logic except the storage layer and the AI block — see `HANDOVER.md` for the exact diffs.

## How to run
Just open `lead-pipeline-local.html` in a browser (double-click, or `open`/`xdg-clip`/`start`). No server needed. Data lives in that browser's `localStorage` under keys `bm_db_v1` and `bm_session_v1`. To reset: clear site data, or `localStorage.clear()` in the console.

Demo accounts (each sets its own password on first sign-in): **You** (Sales Head), **Sanyog** (Project Head · Earthscape), **Amartya** & **Savita** (Salespeople · Earthscape).

## Conventions
- Single file, no build. Keep it dependency-free unless we deliberately migrate.
- State lives in a global `db` object (`{instance, users, leads}`) and a `session` (current user id). All reads go through `scoped()` (permission-filtered) then `visible()` (adds the search filter).
- Every data change calls `saveDB()` then `render()`.
- Dates are stored as local `YYYY-MM-DD` strings via `iso()`. **Do not** reintroduce `toISOString()` — it caused an IST off-by-one bug (fixed).
- Permissions are centralised in `can(action, lead)`. Respect it for any new action.
- See the "Code map" in `HANDOVER.md` before editing — functions are terse and interdependent.

## Current priority: make it real (cloud)
The prototype is a faithful simulation but is **not** production: storage is per-browser, auth/passwords are not secure, and permissions are enforced only in the browser. The next milestone is a real multi-user cloud app.

Recommended path (details + schema + row-level-security rules in `HANDOVER.md`): **Supabase** (Postgres + Auth + Row Level Security), keeping the existing UI and swapping the storage layer for API calls. Also needs a scheduled server function for the stale-lead notifications (email/WhatsApp), which the browser can't do.

When starting cloud work, do **not** break the working single-file prototype — build the new app alongside it (e.g. in a `cloud/` subfolder) so the demo keeps running.

## Ground rules for Claude Code
- Work inside this project folder only.
- Preserve the business rules exactly as documented in `HANDOVER.md` (roles, the two 7-day SLAs, the disqualified-pool reassignment, walk-in date/source locks). These were carefully specified by the product owner.
- Ask before adding heavy dependencies or a framework.
