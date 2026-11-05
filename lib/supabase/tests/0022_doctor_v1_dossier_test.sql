-- Medical 24 - pgTAP 0022 Medico v1: costruzione del dossier, ultimo dossier e
-- percorso del PDF. Dev only; rollback finale.
-- Pattern CONTEXT_CORE §6: fixture come postgres, poi set local role + claims JWT.
--
-- I trigger di ricalcolo su observations restano spenti per tutta la prova: il
-- dossier deve leggere esattamente la fixture dichiarata qui sotto, non gli
-- stati ricalcolati dal motore.
begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('a1111111-1111-4111-8111-111111111131','00000000-0000-0000-0000-000000000000','authenticated','authenticated','alice22@example.com','',now(),'{}','{"full_name":"Alice"}',now(),now()),
('a2222222-2222-4222-8222-222222222231','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bob22@example.com','',now(),'{}','{"full_name":"Bob"}',now(),now())
on conflict(id) do nothing;

update public.profiles set full_name='Alice Demo', gender='female',
  birth_date=current_date - interval '52 years', language='it'
 where id='a1111111-1111-4111-8111-111111111131';
update public.profiles set full_name='Bob Demo', gender='male',
  birth_date=current_date - interval '48 years', language='it'
 where id='a2222222-2222-4222-8222-222222222231';

create temp table t22(k text primary key, v uuid);
grant all on t22 to public;

-- ---------------------------------------------------------------------------
-- Firme e registro
-- ---------------------------------------------------------------------------
select has_function('public','dossier_build',array['uuid','jsonb','uuid'],'dossier_build exists');
select has_function('public','dossier_latest',array['uuid'],'dossier_latest exists');
select has_function('public','dossier_snapshot_set_pdf',array['uuid','text'],'dossier_snapshot_set_pdf exists');
select is((select count(*)::int from public.app_migrations where name='0022_doctor_v1_dossier'),1,'0022 registered');

-- ---------------------------------------------------------------------------
-- Fixture di Alice (come postgres, con i ricalcoli spenti)
-- ---------------------------------------------------------------------------
alter table public.observations disable trigger trg_observations_zz_organ_states;
alter table public.observations disable trigger trg_observations_refresh_risks;

-- tre osservazioni confermate: glicemia precedente piu' bassa, glicemia attuale
-- fuori intervallo, pressione sistolica nei limiti
insert into public.observations(subject_id,code,display_name,value_num,unit,ref_low,ref_high,
  flag,effective_at,origin,review_status,confirmed_at) values
('a1111111-1111-4111-8111-111111111131','2345-7','Glicemia',100,'mg/dL',70,99,'within','2026-03-01 08:00+00','document','confirmed',now()),
('a1111111-1111-4111-8111-111111111131','2345-7','Glicemia',130,'mg/dL',70,99,'above','2026-05-01 08:00+00','document','confirmed',now()),
('a1111111-1111-4111-8111-111111111131','8480-6','Pressione sistolica',120,'mm[Hg]',90,129,'within','2026-05-01 08:00+00','document','confirmed',now());

-- due stati d'organo: uno in attenzione (metabolismo), uno a norma (cuore)
insert into public.organ_states(subject_id,organ_id,state,confidence,inputs,rule_version,stress_score,computed_at) values
('a1111111-1111-4111-8111-111111111131','metabolism','attention',0.80,'[]'::jsonb,'organ_state-0.3',0.80,now()),
('a1111111-1111-4111-8111-111111111131','heart','ok',0.90,'[]'::jsonb,'organ_state-0.3',0.00,now());

-- un punteggio di rischio
insert into public.risk_scores(subject_id,family,level,score,score_unit,inputs,factors,rule_version,computed_at)
values('a1111111-1111-4111-8111-111111111131','cardiovascular','medium',6.2,'percent','{}'::jsonb,'[]'::jsonb,'risk_score2-0.1-draft',now());

-- un documento e un esame consigliato aperto
with d as (
  insert into public.documents(owner_id,subject_id,category,title,document_date,source,status,storage_path)
  values('a1111111-1111-4111-8111-111111111131','a1111111-1111-4111-8111-111111111131','exams',
         'Esami del sangue','2026-05-02','pdf','analyzed','subjects/a1111111/doc.pdf')
  returning id)
insert into t22 select 'doc', id from d;
insert into public.recommendations(subject_id,title_key,reason_key,category,interval_months,due_at,status,origin,rule_version)
values('a1111111-1111-4111-8111-111111111131','recommendation_glicemia','recommendation_level_elevated',
       'Esami',12,'2026-09-01','open','rule','recommendation_risk-0-draft');

-- ---------------------------------------------------------------------------
-- Alice costruisce il dossier
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111131","role":"authenticated"}',true);

insert into t22 select 'b1', public.dossier_build('a1111111-1111-4111-8111-111111111131','{"all": true}'::jsonb);

select is((select payload->'health_status'->>'level' from public.dossier_snapshots where id=(select v from t22 where k='b1')),
  'attention','health_status is attention');
select is((select jsonb_array_length(payload->'organs')::int from public.dossier_snapshots where id=(select v from t22 where k='b1')),
  1,'one organ to follow');
select is((select jsonb_array_length(payload->'risks')::int from public.dossier_snapshots where id=(select v from t22 where k='b1')),
  1,'one risk score');
select is((select jsonb_array_length(payload->'out_of_range')::int from public.dossier_snapshots where id=(select v from t22 where k='b1')),
  1,'one value out of range');
select is((select payload->'out_of_range'->0->>'trend' from public.dossier_snapshots where id=(select v from t22 where k='b1')),
  'up','the out of range value trends up over the lower previous one');
select is((select jsonb_array_length(payload->'documents')::int from public.dossier_snapshots where id=(select v from t22 where k='b1')),
  1,'one document in scope');
select is((select jsonb_array_length(payload->'recommended_exams')::int from public.dossier_snapshots where id=(select v from t22 where k='b1')),
  1,'one recommended exam');
select ok((select jsonb_array_length(rule_versions->'organ_rules') > 0
             and jsonb_array_length(rule_versions->'risk_rules') > 0
           from public.dossier_snapshots where id=(select v from t22 where k='b1')),
  'rule_versions carries organ and risk rules');

-- scope che esclude l'organo del valore fuori intervallo
insert into t22 select 'b2', public.dossier_build('a1111111-1111-4111-8111-111111111131','{"organs": ["heart"]}'::jsonb);
select is((select jsonb_array_length(payload->'out_of_range')::int from public.dossier_snapshots where id=(select v from t22 where k='b2')),
  0,'organ scope without metabolism leaves out_of_range empty');

-- scope che esclude il documento
insert into t22 select 'b3', public.dossier_build('a1111111-1111-4111-8111-111111111131','{"from": "2026-01-01", "to": "2026-04-30"}'::jsonb);
select is((select jsonb_array_length(payload->'documents')::int from public.dossier_snapshots where id=(select v from t22 where k='b3')),
  0,'from/to scope before the document date leaves documents empty');

select throws_ok($$select public.dossier_build('a1111111-1111-4111-8111-111111111131','{"foo": 1}'::jsonb)$$,
  '22023',null,'an invalid scope is refused');

-- ---------------------------------------------------------------------------
-- Bob non costruisce il dossier di Alice
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"a2222222-2222-4222-8222-222222222231","role":"authenticated"}',true);
select throws_ok($$select public.dossier_build('a1111111-1111-4111-8111-111111111131')$$,
  '42501',null,'bob cannot build the dossier of alice');
select ok(public.dossier_latest('a2222222-2222-4222-8222-222222222231') is null,'bob has no dossier yet');

select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111131","role":"authenticated"}',true);
select is((public.dossier_latest('a1111111-1111-4111-8111-111111111131')->>'id')::uuid,
  (select v from t22 where k='b3'),'dossier_latest returns the last personal snapshot');

-- ---------------------------------------------------------------------------
-- pdf_path: solo dal contesto interno, una volta sola, con il percorso atteso
-- ---------------------------------------------------------------------------
select throws_ok(
  format($f$select public.dossier_snapshot_set_pdf(%L::uuid, %L)$f$,
    (select v from t22 where k='b1'),
    'subjects/a1111111-1111-4111-8111-111111111131/dossier/'||(select v from t22 where k='b1')::text||'.pdf'),
  '42501',null,'authenticated cannot set pdf_path');

reset role; select set_config('request.jwt.claims','',true);
select lives_ok(
  format($f$select public.dossier_snapshot_set_pdf(%L::uuid, %L)$f$,
    (select v from t22 where k='b1'),
    'subjects/a1111111-1111-4111-8111-111111111131/dossier/'||(select v from t22 where k='b1')::text||'.pdf'),
  'the internal context sets pdf_path once');
select is((select pdf_path from public.dossier_snapshots where id=(select v from t22 where k='b1')),
  'subjects/a1111111-1111-4111-8111-111111111131/dossier/'||(select v from t22 where k='b1')::text||'.pdf',
  'pdf_path follows subjects/{subject_id}/dossier/{snapshot_id}.pdf');
select throws_ok(
  format($f$select public.dossier_snapshot_set_pdf(%L::uuid, %L)$f$,
    (select v from t22 where k='b1'),
    'subjects/a1111111-1111-4111-8111-111111111131/dossier/'||(select v from t22 where k='b1')::text||'.pdf'),
  '42501',null,'pdf_path cannot be written a second time');
select throws_ok(
  format($f$select public.dossier_snapshot_set_pdf(%L::uuid, %L)$f$,
    (select v from t22 where k='b2'), 'dossier/elsewhere.pdf'),
  '22023',null,'a path outside the storage layout is refused');

alter table public.observations enable trigger trg_observations_zz_organ_states;
alter table public.observations enable trigger trg_observations_refresh_risks;

select * from finish();
rollback;
