-- Medical 24 - pgTAP 0009 body areas by sex and stress score.
-- Dev only; runs in a transaction and leaves no fixture data.
begin;
create extension if not exists pgtap with schema extensions;
create temp table tap_lines(n serial primary key,line text);
grant all on table tap_lines to public;
grant all on sequence tap_lines_n_seq to public;
insert into tap_lines(line) select plan(23);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('41111111-1111-4111-8111-111111111111','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','alice.body9@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('42222222-2222-4222-8222-222222222222','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','bob.body9@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('43333333-3333-4333-8333-333333333333','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','neutral.body9@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now())
on conflict(id) do nothing;
update public.profiles set gender='female' where id='41111111-1111-4111-8111-111111111111';
update public.profiles set gender='male' where id='42222222-2222-4222-8222-222222222222';
update public.profiles set gender=null where id='43333333-3333-4333-8333-333333333333';

insert into tap_lines(line) select is((select count(*)::int from public.organs),16,'organs has 16 areas');
insert into tap_lines(line) select has_column('public','organs','sex','organs.sex exists');
insert into tap_lines(line) select has_column('public','organ_states','stress_score','organ_states.stress_score exists');
insert into tap_lines(line) select is((select count(*)::int from public.app_migrations
  where name='0009_body_sex_stress'),1,'0009 is registered');
-- Since migration 0010 the active rule is 0.3 and 0.2 is retired.
insert into tap_lines(line) select is((select count(*)::int from public.rule_versions
  where type='organ_state' and version='0.2' and status='retired'),1,'rule 0.2 is retired');
insert into tap_lines(line) select is((select count(*)::int from public.rule_versions
  where type='organ_state' and version='0.1' and status='retired'),1,'rule 0.1 is retired');
insert into tap_lines(line) select is(public.subject_sex('41111111-1111-4111-8111-111111111111'),'female','Alice is female');
insert into tap_lines(line) select is(public.subject_sex('42222222-2222-4222-8222-222222222222'),'male','Bob is male');
insert into tap_lines(line) select is(public.subject_sex('43333333-3333-4333-8333-333333333333'),'neutral','missing gender is neutral');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"41111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into tap_lines(line) select is((select count(*)::int from public.organ_overview(
  '41111111-1111-4111-8111-111111111111')),13,'Alice sees 11 common and 2 female areas');
insert into tap_lines(line) select is((select count(*)::int from public.organ_overview(
  '41111111-1111-4111-8111-111111111111') where organ_id in ('breast','reproductive_f')),2,
  'Alice sees female areas');
insert into tap_lines(line) select is((select count(*)::int from public.organ_overview(
  '41111111-1111-4111-8111-111111111111') where organ_id='prostate'),0,'Alice does not see prostate');

select set_config('request.jwt.claims','{"sub":"42222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
insert into tap_lines(line) select is((select count(*)::int from public.organ_overview(
  '42222222-2222-4222-8222-222222222222') where organ_id in ('prostate','reproductive_m')),2,
  'Bob sees prostate and reproductive_m');
select set_config('request.jwt.claims','{"sub":"43333333-3333-4333-8333-333333333333","role":"authenticated"}',true);
insert into tap_lines(line) select is((select count(*)::int from public.organ_overview(
  '43333333-3333-4333-8333-333333333333') where organ_id='reproductive'),1,
  'neutral profile sees neutral reproductive area');

reset role;
select set_config('request.jwt.claims','',true);
-- Use three single-input areas so each denominator is exactly the present weight.
insert into public.observations(subject_id,code,display_name,value_num,unit,effective_at,origin,flag,confirmed_at,review_status)
values
('41111111-1111-4111-8111-111111111111','59408-5','SpO2',98,'%',now(),'document','within',now(),'confirmed'),
('41111111-1111-4111-8111-111111111111','3016-3','TSH',8,'m[IU]/L',now(),'document','above',now(),'confirmed'),
('41111111-1111-4111-8111-111111111111','2345-7','Glucose',450,'mg/dL',now(),'document','critical_high',now(),'confirmed');

insert into tap_lines(line) select is((select stress_score from public.latest_organ_states
  where subject_id='41111111-1111-4111-8111-111111111111' and organ_id='lung'),0::numeric,
  'within produces stress 0');
insert into tap_lines(line) select is((select stress_score from public.latest_organ_states
  where subject_id='41111111-1111-4111-8111-111111111111' and organ_id='thyroid'),0.5::numeric,
  'above weight 1 over present weight 1 produces stress 0.5');
insert into tap_lines(line) select is((select stress_score from public.latest_organ_states
  where subject_id='41111111-1111-4111-8111-111111111111' and organ_id='metabolism'),1::numeric,
  'critical produces stress 1');
insert into tap_lines(line) select is((select stress_score from public.latest_organ_states
  where subject_id='41111111-1111-4111-8111-111111111111' and organ_id='brain'),null::numeric,
  'missing area has null stress');
insert into tap_lines(line) select is((select rule_version from public.latest_organ_states
  where subject_id='41111111-1111-4111-8111-111111111111' and organ_id='thyroid'),'organ_state-0.3',
  'new states use rule 0.3');
insert into tap_lines(line) select ok((select count(*) from public.organ_biomarker_map
  where code='2986-8' and organ_id in ('reproductive','reproductive_f','reproductive_m'))=3,
  'reproductive catalog keys fan out to three areas');
insert into tap_lines(line) select ok((select count(*) from public.organ_biomarker_map
  where code='2857-1' and organ_id in ('prostate','reproductive'))=2,
  'prostate catalog key fans out to prostate and neutral reproductive');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"42222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
insert into tap_lines(line) select is((select count(*)::int from public.organ_states),0,
  'Bob reads zero Alice organ states');
insert into tap_lines(line) select throws_ok($$select * from public.organ_overview(
  '41111111-1111-4111-8111-111111111111')$$,'42501','not_allowed','Bob cannot request Alice overview');

reset role;
select set_config('request.jwt.claims','',true);
insert into tap_lines(line) select * from finish();
select line from tap_lines order by n;
rollback;