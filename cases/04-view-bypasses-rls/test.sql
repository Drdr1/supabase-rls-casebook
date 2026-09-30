-- Legit: Alice sees her project with its org name through the view.
select tests.login('alice');
set role authenticated;
select tests.flag('legit')
  from public.project_overview
 where project_name = 'Alice roadmap' and org_name = 'Alice Co';
reset role;

-- Exploit: Mallory queries the view.
-- supabase.from('project_overview').select('*')
select tests.login('mallory');
set role authenticated;
select tests.flag('exploited')
  from public.project_overview
 where org_name = 'Alice Co';
