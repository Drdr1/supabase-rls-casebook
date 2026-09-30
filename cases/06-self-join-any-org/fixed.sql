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

-- FIX: no INSERT policy on orgs or org_members at all, so the client can't
-- write membership rows directly. Membership is created only by reviewed
-- functions that decide the org and the role themselves:
--   create_org()      -> new org, caller becomes owner
--   accept_invite()   -> (not shown) validates a single-use token, adds
--                        the caller as 'member'
create function public.create_org(p_name text) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare v_uid uuid := auth.uid();
        v_id  uuid := gen_random_uuid();
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  insert into public.orgs (id, name) values (v_id, p_name);
  insert into public.org_members (org_id, user_id, role) values (v_id, v_uid, 'owner');
  return v_id;
end $$;

revoke execute on function public.create_org(text) from public, anon;
grant  execute on function public.create_org(text) to authenticated;
