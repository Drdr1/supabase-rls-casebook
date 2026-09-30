# 05 · Authorizing on `user_metadata`

**What the AI wrote:** `auth.jwt() -> 'user_metadata' ->> 'role' = 'admin'`.

**Why it's wrong:** in Supabase, `user_metadata` (`raw_user_meta_data`) is
**user-writable**. Any signed-in user can call
`supabase.auth.updateUser({ data: { role: 'admin' } })`, refresh the session,
and the claim appears in their JWT. The policy trusts a value the attacker
controls.

**Why review misses it:** "check the role in the JWT" sounds like the right
pattern, and in principle it is. The problem is *which* metadata bag.
`user_metadata` and `app_metadata` are one word apart.

**Fix:** authorize only on `app_metadata`, which only the service role can
write, or on a roles table the client can't write to. A table has one more
advantage: revoking access takes effect immediately, while JWT claims live
until the token expires.

**Tests:** Bob, a real admin set server-side, can still read everything.
Alice reads her own (legit). Mallory with a self-assigned
`user_metadata.role = admin` can't read Alice's document (exploit).
