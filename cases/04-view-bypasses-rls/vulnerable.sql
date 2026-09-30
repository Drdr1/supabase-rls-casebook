-- Prompt: "add a project_overview view joining projects to their org name
--          for the dashboard"

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

-- Views run with the privileges of the view OWNER by default. The owner
-- here is the migration role, which bypasses RLS on these tables.
-- Every row of every tenant is now readable through the view.
create view public.project_overview as
  select p.id, p.name as project_name, o.name as org_name
    from public.projects p
    join public.orgs o on o.id = p.org_id;
