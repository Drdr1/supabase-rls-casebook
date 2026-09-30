create table public.orgs (
  id   uuid primary key default gen_random_uuid(),
  name text not null
);

create table public.org_members (
  org_id  uuid not null references public.orgs (id),
  user_id uuid not null references auth.users (id),
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

create policy "orgs: members can read"
  on public.orgs for select to authenticated
  using (exists (select 1 from public.org_members m
                  where m.org_id = orgs.id and m.user_id = (select auth.uid())));

create policy "projects: members can read"
  on public.projects for select to authenticated
  using (exists (select 1 from public.org_members m
                  where m.org_id = projects.org_id and m.user_id = (select auth.uid())));

-- FIX: security_invoker (Postgres 15+) makes the view check permissions
-- and RLS as the querying user. On older Postgres, put the view in an
-- unexposed schema or replace it with a SECURITY INVOKER function.
create view public.project_overview
  with (security_invoker = true)
as
  select p.id, p.name as project_name, o.name as org_name
    from public.projects p
    join public.orgs o on o.id = p.org_id;
