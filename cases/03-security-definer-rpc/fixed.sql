create table public.orgs (
  id   uuid primary key default gen_random_uuid(),
  name text not null
);

create table public.org_members (
  org_id  uuid not null references public.orgs (id),
  user_id uuid not null references auth.users (id),
  primary key (org_id, user_id)
);

create table public.invoices (
  id           uuid primary key default gen_random_uuid(),
  org_id       uuid not null references public.orgs (id),
  amount_cents int  not null
);

-- The policy's membership lookup filters on user_id first.
create index org_members_user_org_idx on public.org_members (user_id, org_id);

alter table public.org_members enable row level security;
alter table public.invoices    enable row level security;

create policy "members: read own memberships"
  on public.org_members for select to authenticated
  using (user_id = (select auth.uid()));

create policy "invoices: org members can read"
  on public.invoices for select to authenticated
  using (exists (select 1 from public.org_members m
                  where m.org_id = invoices.org_id
                    and m.user_id = (select auth.uid())));

-- FIX, in order of preference:
--  1. SECURITY INVOKER: the function runs as the caller, so RLS applies.
--     The slowness was fixed with an index on org_members(user_id, org_id)
--     and the (select auth.uid()) initplan, not by turning RLS off.
--  2. Pinned search_path, so a same-named object in another schema can't
--     be substituted.
--  3. EXECUTE revoked from PUBLIC/anon and granted only to who needs it.
-- If DEFINER is ever truly required, the body must check membership itself
-- against auth.uid(). Never trust a caller-supplied id.
create function public.get_org_invoices(p_org_id uuid)
returns setof public.invoices
language sql
stable
security invoker
set search_path = ''
as $$
  select * from public.invoices where org_id = p_org_id;
$$;

revoke execute on function public.get_org_invoices(uuid) from public, anon;
grant  execute on function public.get_org_invoices(uuid) to authenticated;
