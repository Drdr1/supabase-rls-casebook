-- Prompt: "users can create an org and become its owner"
-- The model added insert policies so the client can do it in two inserts.

create table public.orgs (
  id   uuid primary key default gen_random_uuid(),
  name text not null
);

create table public.org_members (
  org_id  uuid not null references public.orgs (id),
  user_id uuid not null references auth.users (id),
  role    text not null default 'member' check (role in ('owner', 'member')),
  primary key (org_id, user_id)
);

create table public.projects (
  id     uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.orgs (id),
  name   text not null
);

alter table public.orgs        enable row level security;
alter table public.org_members enable row level security;
alter table public.projects    enable row level security;

create policy "members: read own memberships"
  on public.org_members for select to authenticated
  using (user_id = (select auth.uid()));

create policy "projects: members can read"
  on public.projects for select to authenticated
  using (exists (select 1 from public.org_members m
                  where m.org_id = projects.org_id and m.user_id = (select auth.uid())));

create policy "orgs: anyone signed in can create"
  on public.orgs for insert to authenticated
  with check (true);

-- "You can only add yourself." True, but it never asks to WHICH org,
-- or with WHICH role.
create policy "members: users can add themselves"
  on public.org_members for insert to authenticated
  with check (user_id = (select auth.uid()));

-- Client-side flow the model generated, wrapped as a function for the test.
-- SECURITY INVOKER: it runs with the caller's rights, under the policies above.
create function public.create_org(p_name text) returns uuid
language plpgsql
security invoker
as $$
declare v_id uuid := gen_random_uuid();
begin
  insert into public.orgs (id, name) values (v_id, p_name);
  insert into public.org_members (org_id, user_id, role) values (v_id, auth.uid(), 'owner');
  return v_id;
end $$;
