# 02 · The shadowed column inside `EXISTS`

**What the AI wrote:**

```sql
exists (select 1 from org_members m
        where m.org_id = org_id and m.user_id = auth.uid())
```

**Why it's wrong:** SQL resolves a bare `org_id` to the *nearest* scope, and
that is `org_members`, not the table the policy is on. So the condition becomes
`m.org_id = m.org_id`, which is always true. The policy now asks "is this user
a member of *any* org?" Any tenant can read every other tenant's projects.

**Why review misses it:** it reads correctly in English. It also passes the
usual test, where Alice logs in and sees Alice's projects. It fails only
when you test **across tenants**, and that is the test that gets skipped.

**Fix:** qualify the outer column (`projects.org_id`). Better: put membership
checks in one reviewed helper, e.g. `private.is_org_member(org_id)`, so
every policy doesn't re-type the join.

**Tests:** Alice still sees her project (legit). Mallory, a member of a
different org, sees nothing of Alice Co's (exploit).
