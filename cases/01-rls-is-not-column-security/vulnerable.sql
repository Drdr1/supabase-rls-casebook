-- Prompt given to the model: "profiles table, users can read and edit their own profile"
-- What came back looks textbook. Both policies are correct at the row level.

create table public.profiles (
  id           uuid primary key references auth.users (id),
  display_name text,
  plan         text    not null default 'free' check (plan in ('free', 'pro')),
  is_admin     boolean not null default false
);

alter table public.profiles enable row level security;

create policy "profiles: read own"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));

create policy "profiles: update own"
  on public.profiles for update to authenticated
  using      (id = (select auth.uid()))
  with check (id = (select auth.uid()));
