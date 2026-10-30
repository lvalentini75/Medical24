-- Medical 24 - pgTAP 0012 risk recommendations. Dev only; rolls back fixtures.
-- Copre dismiss/reopen, le raccomandazioni derivate dai punteggi e le soglie
-- del medico risolte lato per lato.
begin;
create extension if not exists pgtap with schema extensions;
create temp table tap_lines(n serial primary key,line text);
grant all on table tap_lines to public;
grant all on sequence tap_lines_n_seq to public;
create temp table fix_ids(k text primary key,v uuid);
grant all on table fix_ids to public;
insert into tap_lines(line) select plan(21);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('71111111-1111-4111-8111-111111111111','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','alice.risk12@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('72222222-2222-4222-8222-222222222222','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','bob.risk12@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('73333333-3333-4333-8333-333333333333','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','doctor.risk12@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()) on conflict(id) do nothing;
update public.profiles set gender='female',birth_date=current_date-interval '60 years'
 where id='71111111-1111-4111-8111-111111111111';
update public.profiles set gender='male',birth_date=current_date-interval '60 years'
 where id='72222222-2222-4222-8222-222222222222';

-- Schema e regole: 5 assertions.
insert into tap_lines(line) select has_function('public','dismiss_recommendation',
 array['uuid','text'],'dismiss_recommendation exists');
insert into tap_lines(line) select has_function('public','reopen_recommendation',
 array['uuid'],'reopen_recommendation exists');
insert into tap_lines(line) select is((select count(*)::int from public.app_migrations
 where name='0012_risk_recommendations'),1,'0012 is registered');
insert into tap_lines(line) select is((select (definition->>'rows')::int from public.rule_versions
 where type='recommendation_calendar' and version='0-draft'),19,
 'calendar rule definition reports 19 rows');
insert into tap_lines(line) select is((select status::text from public.rule_versions
 where type='recommendation_risk' and version='0-draft'),'draft',
 'score-derived recommendation rule stays draft');

-- Dismiss, refresh e reopen: 7 assertions.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into tap_lines(line) select ok(public.refresh_recommendations(
 '71111111-1111-4111-8111-111111111111')>0,'calendar creates applicable recommendations');
insert into fix_ids(k,v) select 'pressione',id from public.recommendations
 where subject_id='71111111-1111-4111-8111-111111111111' and calendar_id='pressione' limit 1;
insert into tap_lines(line) select lives_ok(
 $$select public.dismiss_recommendation((select v from fix_ids where k='pressione'),'non ora')$$,
 'owner can dismiss an open recommendation');
insert into tap_lines(line) select is((select status::text from public.recommendations
 where id=(select v from fix_ids where k='pressione')),'dismissed','recommendation is dismissed');
insert into tap_lines(line) select is((select count(*)::int from public.audit_log
 where target_id=(select v from fix_ids where k='pressione')
  and action='recommendation_dismissed'),1,'dismiss writes one audit row');
select public.refresh_recommendations('71111111-1111-4111-8111-111111111111');
insert into tap_lines(line) select is((select count(*)::int from public.recommendations
 where subject_id='71111111-1111-4111-8111-111111111111' and calendar_id='pressione'
  and status='open'),0,
 'a dismissed calendar recommendation is not recreated within its interval');
insert into tap_lines(line) select lives_ok(
 $$select public.reopen_recommendation((select v from fix_ids where k='pressione'))$$,
 'owner can reopen a dismissed recommendation');
insert into tap_lines(line) select is((select status::text from public.recommendations
 where id=(select v from fix_ids where k='pressione')),'open','reopened recommendation is open');

select set_config('request.jwt.claims','{"sub":"72222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
insert into tap_lines(line) select throws_ok(
 $$select public.dismiss_recommendation((select v from fix_ids where k='pressione'))$$,
 '42501','not_allowed','a stranger cannot dismiss another subject recommendation');

-- Raccomandazioni derivate dai punteggi: 5 assertions.
reset role;select set_config('request.jwt.claims','',true);
insert into public.risk_scores(subject_id,family,level,score,score_unit,inputs,factors,
 rule_version,computed_at) values
('71111111-1111-4111-8111-111111111111','diabetes','medium',13,'points','{}','[]',
 'risk_findrisc-0.1-draft',now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
select public.refresh_recommendations('71111111-1111-4111-8111-111111111111');
insert into tap_lines(line) select is((select count(*)::int from public.recommendations
 where subject_id='71111111-1111-4111-8111-111111111111' and code='glicemia_findrisc'
  and status='open' and origin='rule' and calendar_id is null),1,
 'a medium diabetes score creates glicemia_findrisc');
insert into tap_lines(line) select is((select title_key from public.recommendations
 where subject_id='71111111-1111-4111-8111-111111111111' and code='glicemia_findrisc'
  and status='open'),'recommendation_glicemia_findrisc','derived i18n key is recommendation_ plus code');
select public.refresh_recommendations('71111111-1111-4111-8111-111111111111');
insert into tap_lines(line) select is((select count(*)::int from public.recommendations
 where subject_id='71111111-1111-4111-8111-111111111111' and code='glicemia_findrisc'
  and status='open'),1,'a second refresh does not duplicate the derived recommendation');
reset role;select set_config('request.jwt.claims','',true);
insert into public.risk_scores(subject_id,family,level,score,score_unit,inputs,factors,
 rule_version,computed_at) values
('71111111-1111-4111-8111-111111111111','diabetes','low',6,'points','{}','[]',
 'risk_findrisc-0.1-draft',now()+interval '1 minute');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
select public.refresh_recommendations('71111111-1111-4111-8111-111111111111');
insert into tap_lines(line) select is((select count(*)::int from public.recommendations
 where subject_id='71111111-1111-4111-8111-111111111111' and code='glicemia_findrisc'
  and status='open'),0,'the derived recommendation is closed when the level improves');
insert into tap_lines(line) select is((select reason_key from public.recommendations
 where subject_id='71111111-1111-4111-8111-111111111111' and code='glicemia_findrisc'
  and status='dismissed'),'recommendation_level_improved',
 'the closed derived recommendation carries the improvement reason key');

-- Soglia del medico su un solo lato: 3 assertions.
reset role;select set_config('request.jwt.claims','',true);
insert into public.threshold_overrides(doctor_id,subject_id,code,low,high,unit,reason)
values('73333333-3333-4333-8333-333333333333','71111111-1111-4111-8111-111111111111',
 '2345-7',null,150,'mg/dL','Solo il limite alto');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"71111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into tap_lines(line) select is(public.resolve_flag(
 '71111111-1111-4111-8111-111111111111','2345-7',65)::text,'below',
 'with a high-only override the low side falls back to the institutional reference');
insert into tap_lines(line) select is(public.resolve_flag(
 '71111111-1111-4111-8111-111111111111','2345-7',120)::text,'within',
 'the doctor high limit still applies');

select set_config('request.jwt.claims','{"sub":"72222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
insert into tap_lines(line) select is((select count(*)::int from public.recommendations),0,
 'stranger reads zero recommendations');

reset role;select set_config('request.jwt.claims','',true);
insert into tap_lines(line) select * from finish();
select line from tap_lines order by n;
rollback;
