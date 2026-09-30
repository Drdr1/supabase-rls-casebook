-- Prompt: "admins can read all documents, store the role on the user"
-- The model put the role in user_metadata and read it from the JWT.

create table public.documents (
  id       uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id),
  title    text not null
);

alter table public.documents enable row level security;

create policy "documents: owner or admin can read"
  on public.documents for select to authenticated
  using (
    owner_id = (select auth.uid())
    or (select auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
  );
