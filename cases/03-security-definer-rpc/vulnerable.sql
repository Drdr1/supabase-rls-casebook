-- Prompt: "the invoices query is slow and RLS keeps getting in the way,
--          give me an RPC the dashboard can call"

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

alter table public.org_members enable row level security;
alter table public.invoices    enable row level security;

create policy "members: read own memberships"
  on public.org_members for select to authenticated
  using (user_id = (select auth.uid()));

-- The table itself is locked down correctly...
create policy "invoices: org members can read"
  on public.invoices for select to authenticated
  using (exists (select 1 from public.org_members m
                  where m.org_id = invoices.org_id
                    and m.user_id = (select auth.uid())));

-- ...and this walks straight around it. SECURITY DEFINER runs as the
-- function owner, who is not subject to RLS. The caller picks the org id.
-- EXECUTE is granted to PUBLIC by default, so anon can call it too.
create function public.get_org_invoices(p_org_id uuid)
returns setof public.invoices
language sql
security definer
as $$
  select * from public.invoices where org_id = p_org_id;
$$;
