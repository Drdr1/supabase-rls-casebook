# Supabase RLS casebook

Six Row Level Security mistakes that AI coding assistants make, and that pass
ordinary code review. Each one has a runnable exploit, a fix, and a test
proving the fix blocks the attack **without breaking the legitimate use**.

These are the patterns I check for when reviewing Supabase projects. All code
here is written from scratch: no client code, no client names.

```
$ ./run.sh
CASE                               VARIANT     EXPLOITED  LEGIT   RESULT
01-rls-is-not-column-security      vulnerable  yes        works   ok
01-rls-is-not-column-security      fixed       no         works   ok
02-shadowed-column-in-exists       vulnerable  yes        works   ok
02-shadowed-column-in-exists       fixed       no         works   ok
03-security-definer-rpc            vulnerable  yes        works   ok
03-security-definer-rpc            fixed       no         works   ok
04-view-bypasses-rls               vulnerable  yes        works   ok
04-view-bypasses-rls               fixed       no         works   ok
05-user-metadata-authz             vulnerable  yes        works   ok
05-user-metadata-authz             fixed       no         works   ok
06-self-join-any-org               vulnerable  yes        works   ok
06-self-join-any-org               fixed       no         works   ok
```

## The cases

| # | Mistake | What an attacker gets |
|---|---------|-----------------------|
| [01](cases/01-rls-is-not-column-security) | Correct row policy, but every column is writable | Sets their own `plan = 'pro'`, `is_admin = true` |
| [02](cases/02-shadowed-column-in-exists) | Unqualified column inside `EXISTS` binds to the inner table | Any member of any org reads every org's rows |
| [03](cases/03-security-definer-rpc) | `SECURITY DEFINER` RPC trusting a caller-supplied id | Any user, or `anon`, reads any tenant's invoices |
| [04](cases/04-view-bypasses-rls) | Plain view over RLS-protected tables | Every tenant's rows, via PostgREST |
| [05](cases/05-user-metadata-authz) | Authorizing on `user_metadata` in the JWT | Self-granted admin via `auth.updateUser()` |
| [06](cases/06-self-join-any-org) | "Users can only insert themselves" into memberships | Joins any org as owner, then every read policy lets them in |

What they have in common: each policy reads correctly on its own. The bug
sits between two things: the policy and the grants, the outer and inner
query, the table and the function or view in front of it, the read policy
and the write policy it trusts. That's why reviewing one policy at a time,
whether a human or a model does it, misses them.

## How it works

Each case directory has:

- `vulnerable.sql`: the schema as generated, plausible and wrong
- `fixed.sql`: the reviewed version (`diff` the two to see the fix)
- `seed.sql`: Alice (victim), Mallory (attacker), sometimes Bob (admin)
- `test.sql`: signs in as each user through a real `authenticated` role
  and JWT claims, then attempts the legitimate action and the exploit
- `README.md`: why it's wrong, why review misses it, the fix

`run.sh` loads each variant into a fresh database on top of
[`shim/supabase.sql`](shim/supabase.sql). The shim is a minimal stand-in for
Supabase's roles, `auth.uid()` / `auth.jwt()`, and its wide-open default
grants. A case passes only if the vulnerable version **is** exploitable and
the fixed version **is not**, and the legitimate action works in **both**.

The "legit" check matters. A policy of `using (false)` passes every negative
test, so a fix only counts once you've shown the intended user can still do
their job.

## Run it

Needs Postgres 15+ (for `security_invoker` views) and `psql`.

```sh
export PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres
./run.sh            # all cases
./run.sh 03         # one case
```

CI runs the same thing against `postgres:16` on every push.

## How this was built

With Claude, the same way I work on client projects. The model drafts
the schema, policies and tests. I review everything, decide what's actually
wrong, and require a test that proves each claim before it goes in. The
history reflects that: the commits are small and each one is verified.

## Review checklist

The questions I work through on a Supabase codebase:

1. **Grants, not just policies.** What can `anon` / `authenticated` do at the
   column level? Which columns should only a server ever write?
2. **Every column reference in every policy subquery is qualified.**
3. **Every `SECURITY DEFINER` function:** does it need to be definer? Does it
   derive identity from `auth.uid()`, never from arguments? Is `search_path`
   pinned? Is `EXECUTE` revoked from `PUBLIC` and `anon`?
4. **Every view in an exposed schema** is `security_invoker`, or is moved out.
5. **Every authorization claim** comes from something the user can't write:
   `app_metadata`, or a table with no client write path.
6. **Every write policy on a table that other policies trust** (memberships,
   roles, ownership) is treated as a privilege-escalation surface.
7. **Cross-tenant negative tests**, plus a legitimate-use test alongside each.
8. **Performance traps that tempt people to disable RLS:** unwrapped
   `auth.uid()` calls, and missing indexes on policy lookups.
