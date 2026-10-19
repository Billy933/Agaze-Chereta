# Agaze Chereta

P0 foundation for the six-week Ethiopian marketing and media tender pilot, based on PRD Part 4 (v1.3). Next.js App Router, React, TypeScript and Supabase Auth/PostgreSQL.

## Local development

1. `npm install`
2. Copy `.env.example` to `.env.local` and configure the two public Supabase variables. The existing workspace configuration has already been copied locally; it is ignored by Git.
3. For an empty database, open the project's Supabase SQL Editor, paste all of `supabase/bootstrap.sql`, and click Run once. This applies all three initial migrations in one transaction and requests a schema-cache reload. Alternatively, apply `supabase/migrations/*.sql` in filename order through an authenticated Supabase CLI session. Use only one method; do not run the bootstrap on an already initialized database. Public keys cannot administer the database.
4. Configure Supabase Auth Site URL and redirect allowlist for the local and deployment origins. Enable email OTP/magic links and confirm mail delivery configuration.
5. `npm run dev`, then open http://localhost:3000.

Checks: `npm test`, `npm run typecheck`, `npm run build`.

### Company profile editing migration

After the three foundation migrations (or `bootstrap.sql`), apply `supabase/migrations/202610190004_profile_editing.sql` once through the Supabase SQL Editor or authenticated migration tooling. The bootstrap still contains only the original three migrations. This incremental migration adds owner-only profile editing, optimistic version checks, tenant-scoped immutable declaration history, and audit events. Existing profiles receive a starting snapshot; new companies receive their initial snapshot automatically. Every edited profile invalidates earlier assessments through their existing profile-version comparison. No database credentials or remote schema changes are performed by the application build.

Before enabling editing for customers, validate with separate owner, bid-officer and unrelated-company sessions: only the active owner can save; revoked members cannot read history or save; saving from an old tab fails rather than overwriting a newer version; an unchanged save creates no extra version; old assessments require acknowledgement after an edit. These database acceptance checks require an initialized test database and have not yet been executed in this workspace.

## Implemented foundation

- Email-link sign-in, company creation with structured service/region declarations, published notice search and filtering, original source evidence, deadline display in Africa/Addis_Ababa, assessment matrix, and saved-bid decisions.
- Database membership enforcement on every tenant read, immediate revoked-seat denial, serialized five-active-bid limit, required decline reasons, assessment ownership checks, and immutable client-facing decision audit history.
- Manual draft entry and independent second-review publication functions. Distinct lot/rebid identities are protected by a database unique constraint. Duplicate notices are rejected pending analyst reconciliation; provenance merge UI is not implemented.
- Conservative eligibility aggregation, including historical gaps, stale cross-lot evidence, unknown applicability and incomplete coverage, with executable acceptance fixtures.
- Durable outbox schema with the PRD semantic event/occurrence/channel uniqueness key. Dispatch is disabled; this schema is not a complete notification system.

No synthetic live notices, invented assessments, enabled messaging or recorded payments are included.

## Operations setup

An administrator must assign staff rows using verified Auth user IDs. Staff privilege cannot be self-assigned. Draft entry requires staff; publication requires a different reviewer or operations user. An administrator must approve the source and replace its provisional monitoring schedule before publication. Inspect drafts in the SQL editor until the review queue UI is built. Assessments also require administrator-managed insertion for now; customers have read-only access to analyst findings.

Never use a service-role key in the browser. No staff role receives tenant-wide customer profile access through these policies. Scoped analyst assistance remains to be implemented.

## Remaining P0 work and release gates

- Structured company facts and evidence references beyond services/regions; two-seat owner invitation/revocation UI and server limits; pilot enrollment limit. Basic owner profile editing and version history are implemented in migration 004, pending database acceptance checks.
- Source registry management, review queue, provenance reconciliation, corrections/retractions and transactional amendment-to-outbox writes.
- Assessment authoring, requirement version and dependency tables, conditional/compound requirements, relevance feedback, and selected-lot assessment UI.
- Approved versioned service/holiday calendar, monitoring rounds and overdue escalation, deterministic reminder/catch-up planner.
- Verified email/phone, separate recipient consents, quiet hours, quota ledger, durable worker leasing, callback authentication, timeout reconciliation, suppression and delivery logs. **No providers are configured and no sends occur.**
- Verified manual billing, final pilot terms, source capacity trials and accepted staffing.
- Weekly decision metric query and assessment-version/brief-view attribution. Current audit rows are the groundwork; no KPI is claimed.
- Database migration execution, adversarial RLS/revoked-seat tests against a disposable database, browser/keyboard checks, and backup/restore exercise. The migration has not been executed or validated by PostgreSQL in this workspace.
- Production deployment and operational monitoring.

The pilot is not ready to enroll paying customers. These remaining checks are required before production data or launch.
