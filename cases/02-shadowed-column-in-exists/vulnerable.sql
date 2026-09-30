-- Prompt: "multi-tenant projects, members of an org can see its projects"

create table public.orgs (
  id   uuid primary key default gen_random_uuid(),
  name text not null
);

create table public.org_members (
  org_id  uuid not null references public.orgs (id),
  user_id uuid not null references auth.users (id),
  role    text not null default 'member',
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

-- Reads fine, and it passes a happy-path test where every user
-- belongs to exactly one org and only ever looks at their own projects.
create policy "projects: org members can read"
  on public.projects for select to authenticated
  using (
    exists (
      select 1
        from public.org_members m
       where m.org_id = org_id          -- <-- which org_id?
         and m.user_id = (select auth.uid())
    )
  );
