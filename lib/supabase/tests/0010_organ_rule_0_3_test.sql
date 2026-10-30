-- Medical 24 - pgTAP 0010 organ_state rule 0.3: state derived from the index.
-- Dev only; runs in a transaction and leaves no fixture data.
begin;
create extension if not exists pgtap with schema extensions;
create temp table tap_lines(n serial primary key,line text);
grant all on table tap_lines to public;
grant all on sequence tap_lines_n_seq to public;
insert into tap_lines(line) select plan(18);

-- ---------------------------------------------------------------------------
-- Fixtures: four subjects, fourteen standard-weight codes and two test areas.
-- Synthetic codes keep the arithmetic independent from the board seed.
-- ---------------------------------------------------------------------------
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('51111111-1111-4111-8111-111111111111','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','a.rule10@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('52222222-2222-4222-8222-222222222222','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','b.rule10@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('53333333-3333-4333-8333-333333333333','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','c.rule10@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('54444444-4444-4444-8444-444444444444','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','e.rule10@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now())
on conflict(id) do nothing;

insert into public.biomarker_catalog(code,name_it,name_en,category,unit_canonical,
  organs,status,is_essential)
select 'T0010-'||lpad(i::text,2,'0'),'Test '||i,'Test '||i,'test','1',
  '{}'::text[],'draft',false
from generate_series(1,15) i
on conflict(code) do nothing;

insert into public.organs(id,sort_order,name_it,name_en,icon,anchor_x,anchor_y,sex)
values
  ('t_area14',901,'Area di prova 14','Test area 14','circle',0.5,0.5,'all'),
  ('t_area1',902,'Area di prova 1','Test area 1','circle',0.5,0.5,'all')
on conflict(id) do nothing;

insert into public.organ_biomarker_map(organ_id,code,weight)
select 't_area14','T0010-'||lpad(i::text,2,'0'),1 from generate_series(1,14) i
on conflict do nothing;
insert into public.organ_biomarker_map(organ_id,code,weight)
values('t_area1','T0010-15',1) on conflict do nothing;

-- ---------------------------------------------------------------------------
-- The rule itself: 7 assertions.
-- ---------------------------------------------------------------------------
insert into tap_lines(line) select is((select count(*)::int from public.app_migrations
  where name='0010_organ_rule_0_3'),1,'0010 is registered');
insert into tap_lines(line) select is((select count(*)::int from public.rule_versions
  where type='organ_state' and version='0.3' and status='active'),1,'rule 0.3 is active');
insert into tap_lines(line) select is((select count(*)::int from public.rule_versions
  where type='organ_state' and version='0.2' and status='retired'),1,'rule 0.2 is retired');
insert into tap_lines(line) select is((select count(*)::int from public.rule_versions
  where type='organ_state' and status='active'),1,'exactly one organ_state rule is active');
insert into tap_lines(line) select is((select (definition->'thresholds'->>'ok_below')::numeric
  from public.rule_versions where type='organ_state' and version='0.3'),0.05::numeric,
  'ok_below is 0.05');
insert into tap_lines(line) select is((select (definition->'thresholds'->>'attention_from')::numeric
  from public.rule_versions where type='organ_state' and version='0.3'),0.60::numeric,
  'attention_from is 0.60');
insert into tap_lines(line) select is((select (definition->'thresholds'->>'critical_floor')::numeric
  from public.rule_versions where type='organ_state' and version='0.3'),0.80::numeric,
  'critical_floor is 0.80');

-- ---------------------------------------------------------------------------
-- A: fourteen present values of weight 1, two of them below, plus a single
-- out-of-range value in the one-code area: 5 assertions.
-- ---------------------------------------------------------------------------
insert into public.observations(subject_id,code,display_name,value_num,unit,effective_at,
  origin,flag,confirmed_at,review_status)
select '51111111-1111-4111-8111-111111111111','T0010-'||lpad(i::text,2,'0'),'Test '||i,
  1,'1',now()-interval '1 day',
  'document',(case when i <= 2 then 'below' else 'within' end)::observation_flag,
  now(),'confirmed'
from generate_series(1,14) i;
insert into public.observations(subject_id,code,display_name,value_num,unit,effective_at,
  origin,flag,confirmed_at,review_status)
values('51111111-1111-4111-8111-111111111111','T0010-15','Test 15',1,'1',
  now()-interval '1 day','document','above',now(),'confirmed');

insert into tap_lines(line) select is((select stress_score from public.latest_organ_states
  where subject_id='51111111-1111-4111-8111-111111111111' and organ_id='t_area14'),0.07::numeric,
  'two below out of fourteen produce an index of 0.07');
insert into tap_lines(line) select is((select state::text from public.latest_organ_states
  where subject_id='51111111-1111-4111-8111-111111111111' and organ_id='t_area14'),'monitor',
  'an index of 0.07 is monitor, not attention');
insert into tap_lines(line) select is((select stress_score from public.latest_organ_states
  where subject_id='51111111-1111-4111-8111-111111111111' and organ_id='t_area1'),0.5::numeric,
  'one out-of-range value out of one produces an index of 0.5');
insert into tap_lines(line) select is((select state::text from public.latest_organ_states
  where subject_id='51111111-1111-4111-8111-111111111111' and organ_id='t_area1'),'monitor',
  'an index of 0.5 is still monitor');
insert into tap_lines(line) select is((select rule_version from public.latest_organ_states
  where subject_id='51111111-1111-4111-8111-111111111111' and organ_id='t_area14'),
  'organ_state-0.3','new states carry rule 0.3');

-- ---------------------------------------------------------------------------
-- B: one critical value out of fourteen: 2 assertions.
-- ---------------------------------------------------------------------------
insert into public.observations(subject_id,code,display_name,value_num,unit,effective_at,
  origin,flag,confirmed_at,review_status)
select '52222222-2222-4222-8222-222222222222','T0010-'||lpad(i::text,2,'0'),'Test '||i,
  1,'1',now()-interval '1 day',
  'document',(case when i = 1 then 'critical_high' else 'within' end)::observation_flag,
  now(),'confirmed'
from generate_series(1,14) i;

insert into tap_lines(line) select is((select stress_score from public.latest_organ_states
  where subject_id='52222222-2222-4222-8222-222222222222' and organ_id='t_area14'),0.80::numeric,
  'a single critical value lifts the index to the critical floor');
insert into tap_lines(line) select is((select state::text from public.latest_organ_states
  where subject_id='52222222-2222-4222-8222-222222222222' and organ_id='t_area14'),'attention',
  'a critical value is always attention');

-- ---------------------------------------------------------------------------
-- C: fourteen values within range: 2 assertions.
-- ---------------------------------------------------------------------------
insert into public.observations(subject_id,code,display_name,value_num,unit,effective_at,
  origin,flag,confirmed_at,review_status)
select '53333333-3333-4333-8333-333333333333','T0010-'||lpad(i::text,2,'0'),'Test '||i,
  1,'1',now()-interval '1 day','document','within',now(),'confirmed'
from generate_series(1,14) i;

insert into tap_lines(line) select is((select stress_score from public.latest_organ_states
  where subject_id='53333333-3333-4333-8333-333333333333' and organ_id='t_area14'),0::numeric,
  'fourteen values within range produce an index of 0');
insert into tap_lines(line) select is((select state::text from public.latest_organ_states
  where subject_id='53333333-3333-4333-8333-333333333333' and organ_id='t_area14'),'ok',
  'an index of 0 is ok');

-- ---------------------------------------------------------------------------
-- E: the version change appends exactly one row per applicable area and the
-- recomputation right after writes nothing: 2 assertions.
-- ---------------------------------------------------------------------------
update public.rule_versions set status='retired'
where type='organ_state' and version='0.3';
update public.rule_versions set status='active'
where type='organ_state' and version='0.2';
select public.compute_organ_states('54444444-4444-4444-8444-444444444444');
update public.rule_versions set status='retired'
where type='organ_state' and version='0.2';
update public.rule_versions set status='active'
where type='organ_state' and version='0.3';

insert into tap_lines(line) select is(
  public.compute_organ_states('54444444-4444-4444-8444-444444444444'),
  (select count(*)::int from public.organs where sex in ('all','neutral')),
  'the version change appends one row per applicable area');
insert into tap_lines(line) select is(
  public.compute_organ_states('54444444-4444-4444-8444-444444444444'),0,
  'a second recomputation with no change writes no row');

insert into tap_lines(line) select * from finish();
select line from tap_lines order by n;
rollback;
