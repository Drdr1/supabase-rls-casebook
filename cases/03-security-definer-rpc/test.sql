-- Legit: Alice pulls her own org's invoices through the RPC.
select tests.login('alice');
set role authenticated;
select tests.flag('legit')
  from public.get_org_invoices('00000000-0000-4000-8000-00000000a001')
 limit 1;
reset role;

-- Exploit 1: Mallory passes Alice Co's id.
-- supabase.rpc('get_org_invoices', { p_org_id: '<alice co id>' })
select tests.login('mallory');
set role authenticated;
select tests.flag('exploited')
  from public.get_org_invoices('00000000-0000-4000-8000-00000000a001')
 limit 1;
reset role;

-- Exploit 2: not even signed in.
select tests.logout();
set role anon;
do $$
begin
  perform tests.flag('exploited')
     from public.get_org_invoices('00000000-0000-4000-8000-00000000a001')
    limit 1;
exception when insufficient_privilege then
  null; -- EXECUTE revoked from anon
end $$;
