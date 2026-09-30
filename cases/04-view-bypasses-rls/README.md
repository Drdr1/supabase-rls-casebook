# 04 · The view that ignores RLS

**What the AI wrote:** a plain `create view` joining two tables that both have
correct RLS.

**Why it's wrong:** by default a Postgres view runs with its **owner's**
privileges. On Supabase that's the role that ran the migration, and RLS
doesn't apply to it. The view is in `public`, so PostgREST exposes it.
Any signed-in user can read every tenant's rows through it. Supabase's
database linter flags this as `security_definer_view`, but only if someone
runs it.

**Why review misses it:** there's no policy to review. The tables are
correct, and a view looks like a read-only convenience.

**Fix:** `with (security_invoker = true)` (Postgres 15+), so the view checks
permissions and RLS as the caller. Otherwise, keep views out of exposed
schemas.

**Tests:** Alice sees her project through the view (legit). Mallory sees
nothing from Alice Co (exploit).
