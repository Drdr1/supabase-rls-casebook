-- Minimal local stand-in for the parts of Supabase that RLS depends on.
--
-- Mirrors what a Supabase project gives you out of the box:
--   * roles anon / authenticated / service_role
--   * auth.uid(), auth.role(), auth.jwt() reading request.jwt.claims
--   * default grants: anon and authenticated get ALL on public tables.
--     This is the important part. On Supabase, table grants are wide open
--     and RLS is the only thing standing between a user and every row.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

grant anon, authenticated, service_role to current_user;

create schema if not exists auth;
grant usage on schema auth to anon, authenticated, service_role;

create table auth.users (
  id    uuid primary key,
  email text unique not null
);

create or replace function auth.jwt() returns jsonb
language sql stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;

create or replace function auth.uid() returns uuid
language sql stable
as $$
  select nullif(auth.jwt() ->> 'sub', '')::uuid
$$;

create or replace function auth.role() returns text
language sql stable
as $$
  select auth.jwt() ->> 'role'
$$;

grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Test helpers
-- ---------------------------------------------------------------------------
create schema tests;
grant usage on schema tests to anon, authenticated;

-- Fixed identities so tests can refer to users by name.
create function tests.uid(name text) returns uuid
language sql immutable
as $$
  select case name
    when 'alice'   then 'aaaaaaaa-0000-4000-8000-000000000001'
    when 'bob'     then 'bbbbbbbb-0000-4000-8000-000000000002'
    when 'mallory' then 'cccccccc-0000-4000-8000-000000000003'
  end::uuid
$$;

-- Act as a signed-in user. Call, then `set role authenticated;`.
-- extra_claims is merged into the JWT, e.g. user_metadata / app_metadata.
create function tests.login(name text, extra_claims jsonb default '{}') returns void
language sql
as $$
  select set_config(
    'request.jwt.claims',
    (jsonb_build_object('sub', tests.uid(name), 'role', 'authenticated') || extra_claims)::text,
    false
  );
$$;

create function tests.logout() returns void
language sql
as $$
  select set_config('request.jwt.claims', '', false);
$$;

-- Record an outcome ('exploited' or 'legit') for the runner to read.
create function tests.flag(what text) returns void
language sql
as $$
  select set_config('casebook.' || what, 'true', false);
$$;

grant execute on all functions in schema tests to anon, authenticated;

insert into auth.users (id, email) values
  (tests.uid('alice'),   'alice@example.com'),
  (tests.uid('bob'),     'bob@example.com'),
  (tests.uid('mallory'), 'mallory@example.com');
