select tests.login('mallory');
set role authenticated;

-- Legit: Mallory renames herself.
do $$
declare n int;
begin
  update public.profiles set display_name = 'Mal' where id = auth.uid();
  get diagnostics n = row_count;
  if n = 1 then perform tests.flag('legit'); end if;
end $$;

-- Exploit: same row, same policy, different columns.
-- supabase.from('profiles').update({ plan: 'pro', is_admin: true }).eq('id', user.id)
do $$
begin
  update public.profiles set plan = 'pro', is_admin = true where id = auth.uid();
exception when insufficient_privilege then
  null; -- blocked by column grants
end $$;

reset role;
select tests.flag('exploited')
  from public.profiles
 where id = tests.uid('mallory') and (is_admin or plan = 'pro');
