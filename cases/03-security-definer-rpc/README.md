# 03 · The `SECURITY DEFINER` escape hatch

**What the AI wrote:** a `SECURITY DEFINER` RPC that takes an `org_id` and
returns that org's invoices. The model's reason: "to avoid RLS overhead".

**Why it's wrong:**

- A `SECURITY DEFINER` function runs as its owner, and the owner isn't
  subject to the table's RLS. The table's careful policy never runs.
- The caller chooses `p_org_id`. Nothing checks that they belong to it.
- Postgres grants `EXECUTE` to `PUBLIC` by default, and Supabase exposes
  `public` functions over PostgREST, so `anon` can call it with only the
  project's public key.
- There's no pinned `search_path` either.

**Why review misses it:** people review the policy on `invoices`, see it's
right, and move on. The hole is in a function, often in a different
migration file.

**Fix:** make it `SECURITY INVOKER` so RLS applies, pin `search_path = ''`,
revoke `EXECUTE` from `PUBLIC`/`anon`. Fix the performance issue the
right way: index the membership lookup and wrap `auth.uid()` in `(select ...)`
so it's evaluated once. If a definer function is really needed, it must
check membership against `auth.uid()` itself.

**Tests:** Alice gets her invoices through the RPC (legit). Mallory passing
Alice Co's id gets nothing. `anon` can't execute it at all (exploits).
