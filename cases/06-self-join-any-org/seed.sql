insert into public.orgs (id, name) values
  ('00000000-0000-4000-8000-00000000a001', 'Alice Co');

insert into public.org_members (org_id, user_id, role) values
  ('00000000-0000-4000-8000-00000000a001', tests.uid('alice'), 'owner');

insert into public.projects (org_id, name) values
  ('00000000-0000-4000-8000-00000000a001', 'Alice roadmap');
