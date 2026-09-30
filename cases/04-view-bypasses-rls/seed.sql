insert into public.orgs (id, name) values
  ('00000000-0000-4000-8000-00000000a001', 'Alice Co'),
  ('00000000-0000-4000-8000-00000000c001', 'Mallory LLC');

insert into public.org_members (org_id, user_id) values
  ('00000000-0000-4000-8000-00000000a001', tests.uid('alice')),
  ('00000000-0000-4000-8000-00000000c001', tests.uid('mallory'));

insert into public.projects (org_id, name) values
  ('00000000-0000-4000-8000-00000000a001', 'Alice roadmap'),
  ('00000000-0000-4000-8000-00000000c001', 'Mallory side project');
