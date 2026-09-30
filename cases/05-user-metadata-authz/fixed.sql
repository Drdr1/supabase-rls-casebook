create table public.documents (
  id       uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  title    text not null
);

alter table public.documents enable row level security;

-- FIX: authorize on app_metadata, which only the service role can write
-- (auth.admin.updateUserById). user_metadata is writable by the user
-- through supabase.auth.updateUser({ data: ... }), and the change shows
-- up in their next JWT.
--
-- Even better when roles change often: a roles table checked in the policy,
-- because JWT claims stay stale until the token refreshes and revoking
-- admin should take effect now, not in up to an hour.
create policy "documents: owner or admin can read"
  on public.documents for select to authenticated
  using (
    owner_id = (select auth.uid())
    or (select auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
  );
