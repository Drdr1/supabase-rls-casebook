# 06 · "Users can only add themselves", to any org, as owner

**What the AI wrote:** an `INSERT` policy on `org_members` of
`with check (user_id = auth.uid())`, so the client can create an org and then
insert its own owner row.

**Why it's wrong:** the check pins *who* is inserted but not *where* or *as
what*. Any user can insert `{ org_id: <any org>, user_id: me, role: 'owner' }`.
From then on, every other correctly written policy grants them that org's
data, because they're now a legitimate member. One loose write policy
undoes all the correct read policies.

**Why review misses it:** it looks restrictive. Reviewers check policies
one table at a time. The damage only shows when you follow the write
policy into what the read policies trust.

**Fix:** no client-side `INSERT` on membership tables. Membership comes from
narrow, reviewed functions (`create_org`, `accept_invite`) that decide the org
and role themselves, run with a pinned `search_path`, refuse `anon`, and
derive identity from `auth.uid()`, never from arguments.

**Tests:** Mallory can still create her own org and becomes its owner
(legit). She can't join Alice Co or read its projects (exploit).
