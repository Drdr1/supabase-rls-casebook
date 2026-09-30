-- Legit: Mallory creates her own org and becomes its owner.
select tests.login('mallory');
set role authenticated;
select public.create_org('Mallory LLC') as mallory_org \gset
select tests.flag('legit')
  from public.org_members
 where org_id = :'mallory_org' and user_id = auth.uid() and role = 'owner';

-- Exploit: Mallory adds herself to Alice Co, as owner.
-- supabase.from('org_members').insert({ org_id: '<alice co id>', user_id: me, role: 'owner' })
do $$
begin
  insert into public.org_members (org_id, user_id, role)
  values ('00000000-0000-4000-8000-00000000a001', auth.uid(), 'owner');
exception when insufficient_privilege then
  null; -- no insert policy -> "new row violates row-level security policy"
end $$;

select tests.flag('exploited') from public.projects where name = 'Alice roadmap';
