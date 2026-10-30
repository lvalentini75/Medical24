-- Medical 24 - pgTAP 0007 health core. Dev only; leaves no fixture data.
begin;
create extension if not exists pgtap with schema extensions;
create temp table tap_lines (n serial primary key, line text);
grant all on table tap_lines to public;
grant all on sequence tap_lines_n_seq to public;
insert into tap_lines(line) select plan(29);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('11111111-1111-4111-8111-111111111111','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','alice.health@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('22222222-2222-4222-8222-222222222222','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','bob.health@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now())
on conflict(id) do nothing;
update public.profiles set gender='female',birth_date='1980-01-01'
where id='11111111-1111-4111-8111-111111111111';

-- Schema and explicit access model: 8 assertions.
insert into tap_lines(line) select has_table('public','symptoms','symptoms exists');
insert into tap_lines(line) select has_table('public','alerts','alerts exists');
insert into tap_lines(line) select has_table('public','biomarker_watch','biomarker_watch exists');
insert into tap_lines(line) select has_view('public','biomarker_series','biomarker_series exists');
insert into tap_lines(line) select has_function('public','biomarker_stats',
  array['uuid','text','timestamp with time zone','timestamp with time zone']::name[], 'biomarker_stats signature exists');
insert into tap_lines(line) select has_function('public','biomarker_episodes',array['uuid','text']::name[],
  'biomarker_episodes signature exists');
insert into tap_lines(line) select is((select count(*)::int from pg_policies
  where schemaname='public' and tablename='observations' and policyname='observations_manual_insert'),1,
  'manual observation insert policy exists');
insert into tap_lines(line) select is((select count(*)::int from public.app_migrations
  where name='0007_health_core'),1,'0007 is registered');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}',true);

-- Valid/invalid manual values and discard: 6 assertions.
insert into tap_lines(line) select lives_ok($$
  insert into public.observations(id,subject_id,code,value_num,unit,effective_at,origin)
  values('70000000-0000-4000-8000-000000000001','11111111-1111-4111-8111-111111111111',
    '2345-7',5.4,'mmol/L','2026-01-01 08:00+00','manual')
$$,'Alice inserts a valid manual glucose');
insert into tap_lines(line) select is((select round(value_num,3) from public.observations
  where id='70000000-0000-4000-8000-000000000001'),97.286::numeric,
  'manual glucose is normalized to the canonical unit');
insert into tap_lines(line) select throws_ok($$
  insert into public.observations(subject_id,code,value_num,unit,effective_at,origin)
  values('11111111-1111-4111-8111-111111111111','2345-7',2000,'mg/dL',now(),'manual')
$$,'P0001','manual_value_not_plausible','an implausible manual value is rejected');

insert into public.observations(id,subject_id,code,value_num,unit,effective_at,origin)
values('70000000-0000-4000-8000-000000000002','11111111-1111-4111-8111-111111111111',
  '29463-7',70,'kg','2026-01-02 08:00+00','manual');
insert into tap_lines(line) select ok(public.confirm_observation(
  '70000000-0000-4000-8000-000000000002',null,null,null,null,'discarded') is not null,
  'discard creates a replacement row');
insert into tap_lines(line) select is((select count(*)::int from public.observations
  where id='70000000-0000-4000-8000-000000000002' and superseded_at is not null),1,
  'discard supersedes rather than deletes the original');
insert into tap_lines(line) select is((select count(*)::int from public.observations
  where supersedes_id='70000000-0000-4000-8000-000000000002' and review_status='discarded'),1,
  'the replacement has discarded status');
insert into tap_lines(line) select is((select count(*)::int from public.biomarker_series
  where code='29463-7'),0,'discarded and superseded rows are absent from the series');

-- Six glucose values form exactly two dated institutional episodes: 3 assertions.
insert into public.observations(subject_id,code,value_num,unit,effective_at,origin)
select '11111111-1111-4111-8111-111111111111','2345-7',v,'mg/dL',d,'manual'
from (values
  (80::numeric,'2026-02-01 08:00+00'::timestamptz),
  (120,'2026-02-02 08:00+00'),(130,'2026-02-03 08:00+00'),
  (90,'2026-02-04 08:00+00'),(140,'2026-02-05 08:00+00'),
  (95,'2026-02-06 08:00+00')) x(v,d);
insert into tap_lines(line) select is((select count(*)::int from public.biomarker_episodes(
  '11111111-1111-4111-8111-111111111111','2345-7')),2,'the glucose sequence has two episodes');
insert into tap_lines(line) select is((select min(episode_start) from public.biomarker_episodes(
  '11111111-1111-4111-8111-111111111111','2345-7')),'2026-02-02 08:00+00'::timestamptz,
  'the first episode starts on the expected date');
insert into tap_lines(line) select is((select max(episode_start) from public.biomarker_episodes(
  '11111111-1111-4111-8111-111111111111','2345-7')),'2026-02-05 08:00+00'::timestamptz,
  'the second episode starts on the expected date');

-- Critical alert and semantic deduplication: 2 assertions.
insert into public.observations(subject_id,code,value_num,unit,effective_at,origin)
values
('11111111-1111-4111-8111-111111111111','2345-7',450,'mg/dL','2026-03-01 08:00+00','manual'),
('11111111-1111-4111-8111-111111111111','2345-7',450,'mg/dL','2026-03-01 08:00+00','manual');
insert into tap_lines(line) select is((select count(*)::int from public.alerts a
  join public.observations o on o.id=a.source_id where o.code='2345-7'
  and o.value_num=450 and o.effective_at='2026-03-01 08:00+00'),1,
  'saving the same critical value twice creates one alert');
insert into tap_lines(line) select is((select type::text from public.alerts a
  join public.observations o on o.id=a.source_id where o.value_num=450 limit 1),'critical',
  'a value beyond the safety limit creates a critical alert');

insert into public.symptoms(subject_id,free_text,severity,occurred_at)
values('11111111-1111-4111-8111-111111111111','fixture',2,now());
insert into public.biomarker_watch(subject_id,code,favorite,tracked)
values('11111111-1111-4111-8111-111111111111','2345-7',true,true);

-- Bob sees no Alice clinical rows, including through the invoker view: 5 assertions.
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
insert into tap_lines(line) select is((select count(*)::int from public.symptoms),0,
  'Bob reads zero Alice symptoms');
insert into tap_lines(line) select is((select count(*)::int from public.alerts),0,
  'Bob reads zero Alice alerts');
insert into tap_lines(line) select is((select count(*)::int from public.biomarker_series),0,
  'Bob reads zero Alice series rows');
insert into tap_lines(line) select is((select count(*)::int from public.biomarker_watch),0,
  'Bob reads zero Alice watch rows');
insert into tap_lines(line) select is(jsonb_array_length(public.home_snapshot(
  '11111111-1111-4111-8111-111111111111')->'values'),0,
  'Bob snapshot contains no Alice values');

-- Policy shape and append-only guarantees: 4 assertions.
reset role;
select set_config('request.jwt.claims','',true);
insert into tap_lines(line) select is((select count(*)::int from pg_policies
  where schemaname='public' and tablename='symptoms'),3,'symptoms has select/insert/update policies');
insert into tap_lines(line) select is((select count(*)::int from pg_policies
  where schemaname='public' and tablename='alerts'),2,'alerts has select/read-at policies only');
insert into tap_lines(line) select is((select count(*)::int from pg_policies
  where schemaname='public' and tablename='biomarker_watch'),4,'watch has four subject policies');
insert into tap_lines(line) select is((select count(*)::int from pg_policies
  where schemaname='public' and tablename in ('observations','symptoms') and cmd='DELETE'),0,
  'observations and symptoms expose no delete policy');

insert into tap_lines(line) select * from finish();
select line from tap_lines order by n;
rollback;