# 01 · RLS is not column security

**What the AI wrote:** a correct "users can update their own profile" policy.

**Why it's wrong:** the policy decides *which rows* a user can update. It says
nothing about *which columns*. Supabase grants `UPDATE` on every column to
`authenticated` by default, so any signed-in user can call
`update({ plan: 'pro', is_admin: true })` on their own row from the browser.
Every policy check passes, because it really is their row.

**Why review misses it:** the policy is correct, so reading the policy won't
catch it. You have to read the table *and* the grants together.

**Fix:** revoke table-wide `UPDATE` and grant it back per column. Fields like
billing, roles and flags get written only by `service_role` (webhooks,
admin tools). A trigger that rejects changes to protected columns works
too. Column grants are simpler and fail closed.

**Tests:** Mallory can still rename herself (legit). She can no longer grant
herself `pro` or `is_admin` (exploit).
