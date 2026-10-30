-- Medical 24 - pgTAP 0008 body & organs (P04-A).
-- Dev only; runs in a transaction and leaves no fixture data.
begin;
create extension if not exists pgtap with schema extensions;
create temp table tap_lines (n serial primary key, line text);
grant all on table tap_lines to public;
grant all on sequence tap_lines_n_seq to public;
insert into tap_lines(line) select plan(29);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('11111111-1111-4111-8111-111111111111','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','alice.body@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('22222222-2222-4222-8222-222222222222','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','bob.body@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now())
on conflict(id) do nothing;
update public.profiles set gender='female',birth_date='1980-01-01'
where id='11111111-1111-4111-8111-111111111111';

-- ---------------------------------------------------------------------------
-- Schema and seed: 9 assertions.
-- ---------------------------------------------------------------------------
insert into tap_lines(line) select has_table('public','organs','organs exists');
insert into tap_lines(line) select has_table('public','organ_biomarker_map','organ_biomarker_map exists');
insert into tap_lines(line) select has_table('public','rule_versions','rule_versions exists');
insert into tap_lines(line) select has_table('public','organ_states','organ_states exists');
insert into tap_lines(line) select has_view('public','latest_organ_states','latest_organ_states exists');
insert into tap_lines(line) select is((select count(*)::int from public.app_migrations
  where name='0008_body_organs'),1,'0008 is registered');
insert into tap_lines(line) select is((select count(*)::int from public.organs),16,
  'the body has exactly 16 areas');
insert into tap_lines(line) select ok((select count(*) from public.organ_biomarker_map) > 0,
  'organ_biomarker_map is not empty');
insert into tap_lines(line) select is((select count(*)::int from public.rule_versions
  where type='organ_state' and version='0.1' and status='retired'),1,
  'the organ_state rule v0.1 is retired');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);

-- ---------------------------------------------------------------------------
-- An ordinary authenticated user writes nothing: 4 assertions.
-- ---------------------------------------------------------------------------
insert into tap_lines(line) select throws_ok($$
  insert into public.organs(id,sort_order,name_it,name_en,icon,anchor_x,anchor_y)
  values('spleen',13,'Milza','Spleen','droplet',0.5,0.5)
$$,'42501',null,'authenticated cannot write organs');
insert into tap_lines(line) select throws_ok($$
  insert into public.organ_biomarker_map(organ_id,code,weight)
  values('liver','2324-2',3)
$$,'42501',null,'authenticated cannot write organ_biomarker_map');
insert into tap_lines(line) select throws_ok($$
  insert into public.rule_versions(type,version,status)
  values('organ_state','9.9','active')
$$,'42501',null,'authenticated cannot write rule_versions');
insert into tap_lines(line) select throws_ok($$
  insert into public.organ_states(subject_id,organ_id,state,confidence)
  values('11111111-1111-4111-8111-111111111111','liver','ok',1)
$$,'42501',null,'authenticated cannot write organ_states');

-- ---------------------------------------------------------------------------
-- First computation with no values: 2 assertions.
-- ---------------------------------------------------------------------------
insert into tap_lines(line) select is(
  public.compute_organ_states('11111111-1111-4111-8111-111111111111'),13,
  'the first computation writes the 13 female-applicable areas');
insert into tap_lines(line) select is((select count(*)::int from public.organ_states
  where state='missing'),13,'without values every applicable area is missing');

-- ---------------------------------------------------------------------------
-- The rule moves the liver and the metabolism: 4 assertions.
-- Document rows are inserted with an explicit flag, outside the client path.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims','',true);

insert into public.observations(subject_id,code,display_name,value_num,unit,effective_at,
  origin,flag,confirmed_at,review_status)
values('11111111-1111-4111-8111-111111111111','2324-2','Gamma GT',20,'U/L',
  now() - interval '20 days','document','within',now(),'confirmed');
insert into tap_lines(line) select is((select state::text from public.latest_organ_states
  where subject_id='11111111-1111-4111-8111-111111111111' and organ_id='liver'),'ok',
  'one value within range makes the liver ok');

insert into public.observations(subject_id,code,display_name,value_num,unit,effective_at,
  origin,flag,confirmed_at,review_status)
values('11111111-1111-4111-8111-111111111111','1742-6','ALT (GPT)',200,'U/L',
  now() - interval '10 days','document','above',now(),'confirmed');
insert into tap_lines(line) select is((select state::text from public.latest_organ_states
  where subject_id='11111111-1111-4111-8111-111111111111' and organ_id='liver'),'monitor',
  'one out-of-range value of weight 1 makes the liver monitor');
insert into tap_lines(line) select is((select confidence from public.latest_organ_states
  where subject_id='11111111-1111-4111-8111-111111111111' and organ_id='liver'),0.67::numeric,
  'with no essential codes the confidence is two codes out of three');

insert into public.observations(subject_id,code,display_name,value_num,unit,effective_at,
  origin,flag,confirmed_at,review_status)
values('11111111-1111-4111-8111-111111111111','2345-7','Glicemia',450,'mg/dL',
  now() - interval '5 days','document','critical_high',now(),'confirmed');
insert into tap_lines(line) select is((select state::text from public.latest_organ_states
  where subject_id='11111111-1111-4111-8111-111111111111' and organ_id='metabolism'),'attention',
  'a critical value puts the metabolism in attention');

-- ---------------------------------------------------------------------------
-- Idempotence and isolation: 3 assertions.
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into tap_lines(line) select is(
  public.compute_organ_states('11111111-1111-4111-8111-111111111111'),0,
  'a second computation with no change writes no row');

select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
insert into tap_lines(line) select is((select count(*)::int from public.organ_states),0,
  'Bob reads zero Alice organ states');
insert into tap_lines(line) select is((select count(*)::int from public.latest_organ_states),0,
  'Bob reads zero Alice rows through the latest view');

-- ---------------------------------------------------------------------------
-- History, comparison and episodes on a three-state sequence: 5 assertions.
-- The brain has no mapped code, so the sequence stays synthetic.
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims','',true);
insert into public.organ_states(subject_id,organ_id,state,confidence,inputs,rule_version,computed_at)
values
('11111111-1111-4111-8111-111111111111','brain','ok',0,'[]'::jsonb,'organ_state-0.1',
  now() - interval '14 months'),
('11111111-1111-4111-8111-111111111111','brain','attention',0,'[]'::jsonb,'organ_state-0.1',
  now() - interval '8 months'),
('11111111-1111-4111-8111-111111111111','brain','ok',0,'[]'::jsonb,'organ_state-0.1',
  now() - interval '2 months');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into tap_lines(line) select is((select current_state::text from public.organ_comparison(
  '11111111-1111-4111-8111-111111111111','brain')),'missing',
  'the comparison reports the state of today');
insert into tap_lines(line) select is((select state_6m::text from public.organ_comparison(
  '11111111-1111-4111-8111-111111111111','brain')),'attention',
  'the comparison reports the state in force six months ago');
insert into tap_lines(line) select is((select state_12m::text from public.organ_comparison(
  '11111111-1111-4111-8111-111111111111','brain')),'ok',
  'the comparison reports the state in force twelve months ago');
insert into tap_lines(line) select is((select count(*)::int from public.organ_episodes(
  '11111111-1111-4111-8111-111111111111','brain')),1,
  'the sequence contains one attention episode');
insert into tap_lines(line) select is((select episode_end from public.organ_episodes(
  '11111111-1111-4111-8111-111111111111','brain')),(now() - interval '2 months')::timestamptz,
  'the episode closes on the first non-attention state');

-- ---------------------------------------------------------------------------
-- The trigger recomputes on a confirmed observation: 2 assertions.
-- ---------------------------------------------------------------------------
insert into public.observations(subject_id,code,value_num,unit,effective_at,origin)
values('11111111-1111-4111-8111-111111111111','8867-4',72,'/min',now(),'manual');
insert into tap_lines(line) select is((select state::text from public.latest_organ_states
  where subject_id='11111111-1111-4111-8111-111111111111' and organ_id='heart'),'ok',
  'a confirmed manual value moves the heart out of missing');
insert into tap_lines(line) select is((select count(*)::int from public.organ_states
  where subject_id='11111111-1111-4111-8111-111111111111' and organ_id='heart'),2,
  'the trigger appends exactly one heart row');

reset role;
select set_config('request.jwt.claims','',true);
insert into tap_lines(line) select * from finish();
select line from tap_lines order by n;
rollback;
