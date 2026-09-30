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

-- FIX: RLS decides WHICH ROWS you can touch, never WHICH COLUMNS.
-- Supabase grants UPDATE on every column by default, so narrow it.
-- plan and is_admin are now writable only by service_role
-- (Stripe webhook, admin tooling), never from the client.
revoke update on public.profiles from anon, authenticated;
grant  update (display_name) on public.profiles to authenticated;
