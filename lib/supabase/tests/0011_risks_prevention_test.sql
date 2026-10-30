-- Medical 24 - pgTAP 0011 risks and prevention. Dev only; rolls back fixtures.
-- Corretto il 30/10/2026: 19 righe di calendario, plan(59).
begin;
create extension if not exists pgtap with schema extensions;
create temp table tap_lines(n serial primary key,line text);
grant all on table tap_lines to public;
grant all on sequence tap_lines_n_seq to public;
insert into tap_lines(line) select plan(59);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('61111111-1111-4111-8111-111111111111','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','alice.risk11@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('62222222-2222-4222-8222-222222222222','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','bob.risk11@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('63333333-3333-4333-8333-333333333333','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','doctor.risk11@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()) on conflict(id) do nothing;
update public.profiles set gender='female',birth_date=current_date-interval '60 years'
 where id='61111111-1111-4111-8111-111111111111';
update public.profiles set gender='male',birth_date=current_date-interval '60 years'
 where id='62222222-2222-4222-8222-222222222222';

-- Schema, seed and draft gate: 13 assertions.
insert into tap_lines(line) select has_table('public','risk_scores','risk_scores exists');
insert into tap_lines(line) select has_view('public','latest_risk_scores','latest_risk_scores exists');
insert into tap_lines(line) select has_table('public','questionnaires','questionnaires exists');
insert into tap_lines(line) select has_table('public','questionnaire_answers','questionnaire_answers exists');
insert into tap_lines(line) select has_table('public','prevention_calendar','prevention_calendar exists');
insert into tap_lines(line) select has_table('public','recommendations','recommendations exists');
insert into tap_lines(line) select has_table('public','threshold_overrides','threshold_overrides exists');
insert into tap_lines(line) select is((select count(*)::int from public.prevention_calendar),19,
 'all 19 CSV rows are seeded');
insert into tap_lines(line) select is((select count(*)::int from public.rule_versions
 where type like 'risk_%' and status='draft'),4,'all four clinical rules remain draft');
insert into tap_lines(line) select is((select count(*)::int from public.rule_versions
 where type like 'risk_%' and status='active'),0,'no unvalidated risk rule is active');
insert into tap_lines(line) select is((select count(*)::int from public.app_migrations
 where name='0011_risks_prevention'),1,'0011 is registered');
insert into tap_lines(line) select is((select title_key from public.questionnaires
 where id='risk_baseline'),'riskQuestionnaireTitle','baseline questionnaire is seeded');
insert into tap_lines(line) select is((select count(*)::int from public.prevention_calendar
 where id='screening_mammografia' and sex='female' and interval_months=24),1,
 'CSV sex and interval are preserved');

-- SCORE2 internal cases from score2.json: 8 assertions.
insert into tap_lines(line)
select is((select score from public.score2_risk(age,sex,smoker,sbp,tc,hdl)),expected,
 'SCORE2 internal case '||n)
from (values
 (1,50,'male',false,120::numeric,5.0::numeric,1.3::numeric,3.01::numeric),
 (2,50,'male',true,140,6.5,1.0,10.38),(3,60,'female',false,130,5.5,1.6,3.65),
 (4,65,'male',true,160,7.0,0.9,22.56),(5,45,'female',true,125,6.0,1.2,3.50),
 (6,69,'female',false,150,6.8,1.1,10.35),(7,40,'male',false,110,4.5,1.5,1.07),
 (8,55,'male',false,135,5.8,1.2,5.76))x(n,age,sex,smoker,sbp,tc,hdl,expected);

-- FINDRISC source cases: 4 assertions.
insert into tap_lines(line) select is((select score from public.findrisc_score(payload)),expected,
 'FINDRISC case '||n) from (values
 (1,'{"age":40,"bmi":23,"waist_cm":85,"sex":"male","physical_activity_30min_daily":true,"vegetables_fruit_daily":true,"antihypertensive_medication":false,"history_high_glucose":false,"family_diabetes":"none"}'::jsonb,0::numeric),
 (2,'{"age":58,"bmi":31,"waist_cm":104,"sex":"male","physical_activity_30min_daily":false,"vegetables_fruit_daily":false,"antihypertensive_medication":true,"history_high_glucose":false,"family_diabetes":"first_degree"}',20),
 (3,'{"age":50,"bmi":27,"waist_cm":86,"sex":"female","physical_activity_30min_daily":true,"vegetables_fruit_daily":false,"antihypertensive_medication":false,"history_high_glucose":true,"family_diabetes":"second_degree"}',15),
 (4,'{"age":66,"bmi":26,"waist_cm":90,"sex":"female","physical_activity_30min_daily":false,"vegetables_fruit_daily":true,"antihypertensive_medication":false,"history_high_glucose":false,"family_diabetes":"none"}',11))x(n,payload,expected);

-- CKD-EPI source cases: 5 assertions (the source values are rounded to 0.1).
insert into tap_lines(line) select is((select score from public.ckd_epi_2021(scr,age,sex)),expected,
 'CKD-EPI case '||n) from (values
 (1,0.9::numeric,50,'male',104.0::numeric),(2,0.7,50,'female',105.3),
 (3,1.5,65,'male',51.3),(4,2.2,70,'female',23.5),(5,0.6,30,'male',133.2)
 )x(n,scr,age,sex,expected);

-- Fracture checklist source cases: 6 assertions.
insert into tap_lines(line) select is((select score from public.fracture_checklist_score(payload)),expected,
 'fracture checklist case '||n) from (values
 (1,'{"age":45,"sex":"male","bmi":24,"previous_fracture":false,"parent_hip_fracture":false,"current_smoker":false,"glucocorticoids":false,"rheumatoid_arthritis":false,"secondary_osteoporosis":false,"alcohol_3_units_daily":false,"bmd_t_score":null}'::jsonb,0::numeric),
 (2,'{"age":68,"sex":"female","bmi":22,"previous_fracture":false,"parent_hip_fracture":false,"current_smoker":false,"glucocorticoids":false,"rheumatoid_arthritis":false,"secondary_osteoporosis":false,"alcohol_3_units_daily":false,"bmd_t_score":null}',3),
 (3,'{"age":72,"sex":"female","bmi":18.5,"previous_fracture":true,"parent_hip_fracture":false,"current_smoker":false,"glucocorticoids":false,"rheumatoid_arthritis":false,"secondary_osteoporosis":false,"alcohol_3_units_daily":false,"bmd_t_score":null}',6),
 (4,'{"age":80,"sex":"male","bmi":23,"previous_fracture":false,"parent_hip_fracture":true,"current_smoker":true,"glucocorticoids":false,"rheumatoid_arthritis":false,"secondary_osteoporosis":false,"alcohol_3_units_daily":false,"bmd_t_score":-2.7}',8),
 (5,'{"age":58,"sex":"female","bmi":26,"previous_fracture":false,"parent_hip_fracture":false,"current_smoker":false,"glucocorticoids":true,"rheumatoid_arthritis":true,"secondary_osteoporosis":false,"alcohol_3_units_daily":false,"bmd_t_score":-1.8}',4),
 (6,'{"age":66,"sex":"male","bmi":27,"previous_fracture":false,"parent_hip_fracture":false,"current_smoker":false,"glucocorticoids":false,"rheumatoid_arthritis":false,"secondary_osteoporosis":true,"alcohol_3_units_daily":true,"bmd_t_score":null}',4))x(n,payload,expected);

-- Answers, score history and prevention generation: 7 assertions.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"61111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into tap_lines(line) select lives_ok($$
 insert into public.questionnaire_answers(subject_id,questionnaire_id,version,answers)
 values('61111111-1111-4111-8111-111111111111','risk_baseline','0.1-draft',
 '{"smoker":false,"bmi":26,"waist_cm":82,"physical_activity_30min_daily":true,"vegetables_fruit_daily":true,"antihypertensive_medication":false,"history_high_glucose":false,"family_diabetes":"none","previous_fracture":false}'::jsonb)
$$,'owner can submit questionnaire answers');
reset role;select set_config('request.jwt.claims','',true);
insert into public.observations(subject_id,code,display_name,value_num,unit,effective_at,origin,flag,confirmed_at,review_status) values
('61111111-1111-4111-8111-111111111111','8480-6','SBP',120,'mm[Hg]',now(),'document','within',now(),'confirmed'),
('61111111-1111-4111-8111-111111111111','2093-3','TC',193.35,'mg/dL',now(),'document','within',now(),'confirmed'),
('61111111-1111-4111-8111-111111111111','2085-9','HDL',50.271,'mg/dL',now(),'document','within',now(),'confirmed'),
('61111111-1111-4111-8111-111111111111','2160-0','Creatinine',0.8,'mg/dL',now(),'document','within',now(),'confirmed');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"61111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into tap_lines(line) select is((select count(*)::int from public.risk_scores),4,
 'input triggers append all four available risk families');
insert into tap_lines(line) select is(public.compute_risk_scores('61111111-1111-4111-8111-111111111111'),0,
 'unchanged inputs do not duplicate append-only scores');
insert into tap_lines(line) select is((select count(*)::int from public.latest_risk_scores),4,
 'latest view has one row per family');
insert into tap_lines(line) select ok((select bool_and(projection_12m is not null) from public.risk_scores),
 'computed scores carry a 12-month projection');
insert into tap_lines(line) select ok(public.refresh_recommendations('61111111-1111-4111-8111-111111111111')>0,
 'calendar creates applicable recommendations');
insert into tap_lines(line) select is((select count(*)::int from public.recommendations r
 join public.prevention_calendar c on c.id=r.calendar_id where c.sex='male'),0,
 'female profile gets no male-only recommendation');
insert into tap_lines(line) select is((select title_key from public.recommendations limit 1),
 'recommendation_'||(select calendar_id from public.recommendations limit 1),
 'recommendation i18n key is recommendation_ plus CSV id');

-- Three threshold levels, safety guard and RLS isolation: 16 assertions.
reset role;select set_config('request.jwt.claims','',true);
insert into public.threshold_overrides(id,doctor_id,subject_id,code,low,high,unit,reason)
values('65000000-0000-4000-8000-000000000001','63333333-3333-4333-8333-333333333333',
 '61111111-1111-4111-8111-111111111111','2345-7',60,200,'mg/dL','Test threshold');
insert into tap_lines(line) select throws_ok($$
 insert into public.threshold_overrides(doctor_id,subject_id,code,low,high,unit,reason)
 values('63333333-3333-4333-8333-333333333333','61111111-1111-4111-8111-111111111111',
 '2345-7',40,500,'mg/dL','Unsafe threshold')
$$,'P0001','override_exceeds_safety_low','override cannot cross the board low safety limit');
insert into tap_lines(line) select is((select count(*)::int from public.audit_log
 where target_id='65000000-0000-4000-8000-000000000001'),1,'override creation is audited');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"61111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into tap_lines(line) select is((select doctor_low from public.resolve_thresholds(
 '61111111-1111-4111-8111-111111111111','2345-7')),60::numeric,'subject sees doctor low');
insert into tap_lines(line) select is((select doctor_high from public.resolve_thresholds(
 '61111111-1111-4111-8111-111111111111','2345-7')),200::numeric,'subject sees doctor high');
insert into tap_lines(line) select is((select institutional_low from public.resolve_thresholds(
 '61111111-1111-4111-8111-111111111111','2345-7')),70::numeric,'institutional low remains visible');
insert into tap_lines(line) select is((select institutional_high from public.resolve_thresholds(
 '61111111-1111-4111-8111-111111111111','2345-7')),99::numeric,'institutional high remains visible');
insert into tap_lines(line) select is((select count(*)::int from public.threshold_overrides),1,
 'subject can read its override');
insert into tap_lines(line) select is(public.resolve_flag(
 '61111111-1111-4111-8111-111111111111','2345-7',150)::text,'within',
 'subject-specific doctor threshold changes the resolved flag');

select set_config('request.jwt.claims','{"sub":"62222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
insert into tap_lines(line) select is(public.resolve_flag(
 '62222222-2222-4222-8222-222222222222','2345-7',150)::text,'above',
 'the same value keeps the institutional flag for another subject');
insert into tap_lines(line) select is((select count(*)::int from public.risk_scores),0,'stranger reads zero risk scores');
insert into tap_lines(line) select is((select count(*)::int from public.latest_risk_scores),0,'stranger reads zero latest scores');
insert into tap_lines(line) select is((select count(*)::int from public.questionnaire_answers),0,'stranger reads zero answers');
insert into tap_lines(line) select is((select count(*)::int from public.recommendations),0,'stranger reads zero recommendations');
insert into tap_lines(line) select is((select count(*)::int from public.threshold_overrides),0,'stranger reads zero overrides');
insert into tap_lines(line) select throws_ok($$select public.resolve_thresholds(
 '61111111-1111-4111-8111-111111111111','2345-7')$$,'42501','not_allowed',
 'stranger cannot resolve Alice thresholds');

reset role;select set_config('request.jwt.claims','',true);
insert into tap_lines(line) select * from finish();
select line from tap_lines order by n;
rollback;