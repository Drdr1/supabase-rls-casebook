-- Legit: Bob is a real admin. His role was assigned by the backend, in
-- whichever bag each design reads (user_metadata in the vulnerable one,
-- app_metadata in the fixed one). Alice reads her own document.
select tests.login('bob', '{"app_metadata": {"role": "admin"}, "user_metadata": {"role": "admin"}}');
set role authenticated;
select tests.flag('bob_ok') from public.documents where title = 'Alice contract';
reset role;

select tests.login('alice');
set role authenticated;
select tests.flag('legit')
  from public.documents
 where title = 'Alice contract'
   and current_setting('casebook.bob_ok', true) = 'true';
reset role;

-- Exploit: Mallory ran supabase.auth.updateUser({ data: { role: 'admin' } }),
-- refreshed her session, and her JWT now carries it.
select tests.login('mallory', '{"user_metadata": {"role": "admin"}}');
set role authenticated;
select tests.flag('exploited') from public.documents where title = 'Alice contract';
