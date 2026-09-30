-- Legit: Alice sees her org's project.
select tests.login('alice');
set role authenticated;
select tests.flag('legit') from public.projects where name = 'Alice roadmap';
reset role;

-- Exploit: Mallory is a member of her own org only.
-- She should not see Alice Co's projects.
select tests.login('mallory');
set role authenticated;
select tests.flag('exploited') from public.projects where name = 'Alice roadmap';
