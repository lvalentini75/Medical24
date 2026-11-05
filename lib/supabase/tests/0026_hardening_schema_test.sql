-- Medical 24 - pgTAP 0026 Hardening dello schema (P10-A2a).
-- Dev only; rollback finale.
-- Pattern CONTEXT_CORE §6: fixture come postgres, poi set local role + claims JWT.
--
-- Il database dev contiene gia' righe vere: ogni conteggio su tabelle
-- condivise e' relativo a una base salvata prima del cambio di ruolo,
-- mai assoluto.
begin;
create extension if not exists pgtap with schema extensions;
select plan(80);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('d1111111-1111-4111-8111-111111111161','00000000-0000-0000-0000-000000000000','authenticated','authenticated','alice26@example.com','',now(),'{}','{"full_name":"Alice"}',now(),now())
on conflict(id) do nothing;

update public.profiles set full_name='Alice Demo', language='it'
 where id='d1111111-1111-4111-8111-111111111161';

create temp table t26(k text primary key, n int);
grant all on t26 to public;

-- basi di confronto, lette come postgres (nessuna RLS applicata)
insert into t26(k,n) select 'rating_summaries', count(*)::int from public.rating_summaries;
insert into t26(k,n) select 'treatment_tags',   count(*)::int from public.treatment_tags;

-- ---------------------------------------------------------------------------
-- Registro
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.app_migrations where name='0026_hardening_schema'),1,
  '0026 registered');

-- ---------------------------------------------------------------------------
-- 1. RLS forzata
-- ---------------------------------------------------------------------------
select ok((select relforcerowsecurity from pg_class where oid='public.user_roles'::regclass),
  'row level security is forced on user_roles');
select ok((select relforcerowsecurity from pg_class where oid='public.audit_log'::regclass),
  'row level security is forced on audit_log');
select ok((select relforcerowsecurity from pg_class where oid='public.biomarker_catalog'::regclass),
  'row level security is forced on biomarker_catalog');

-- ---------------------------------------------------------------------------
-- 2. search_path fisso, una asserzione per funzione
-- ---------------------------------------------------------------------------
select ok((select proconfig from pg_proc where oid='public.set_updated_at()'::regprocedure)
            @> array['search_path=public'], 'set_updated_at has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.immutable_array_to_string(text[],text)'::regprocedure)
            @> array['search_path=public'], 'immutable_array_to_string has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.observations_append_only()'::regprocedure)
            @> array['search_path=public'], 'observations_append_only has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.organ_states_append_only()'::regprocedure)
            @> array['search_path=public'], 'organ_states_append_only has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.risk_scores_append_only()'::regprocedure)
            @> array['search_path=public'], 'risk_scores_append_only has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_block_mutation()'::regprocedure)
            @> array['search_path=public'], 'm24_block_mutation has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_guard_dossier_snapshot()'::regprocedure)
            @> array['search_path=public'], 'm24_guard_dossier_snapshot has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.score2_risk(int,text,boolean,numeric,numeric,numeric)'::regprocedure)
            @> array['search_path=public'], 'score2_risk has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.findrisc_score(jsonb)'::regprocedure)
            @> array['search_path=public'], 'findrisc_score has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.ckd_epi_2021(numeric,int,text)'::regprocedure)
            @> array['search_path=public'], 'ckd_epi_2021 has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.fracture_checklist_score(jsonb)'::regprocedure)
            @> array['search_path=public'], 'fracture_checklist_score has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.normalize_for_filter(text)'::regprocedure)
            @> array['search_path=public'], 'normalize_for_filter has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_jsonb_keys_subset(jsonb,text[])'::regprocedure)
            @> array['search_path=public'], 'm24_jsonb_keys_subset has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_valid_contraindications(jsonb)'::regprocedure)
            @> array['search_path=public'], 'm24_valid_contraindications has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_valid_media(jsonb)'::regprocedure)
            @> array['search_path=public'], 'm24_valid_media has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_treatment_search_doc(text,text,text,text[],text[],jsonb)'::regprocedure)
            @> array['search_path=public'], 'm24_treatment_search_doc has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_display_name_initial(text)'::regprocedure)
            @> array['search_path=public'], 'm24_display_name_initial has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_treatment_cover_url(jsonb)'::regprocedure)
            @> array['search_path=public'], 'm24_treatment_cover_url has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_max_contraindication(jsonb)'::regprocedure)
            @> array['search_path=public'], 'm24_max_contraindication has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_valid_share_scope(jsonb)'::regprocedure)
            @> array['search_path=public'], 'm24_valid_share_scope has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_valid_emergency_contacts(jsonb)'::regprocedure)
            @> array['search_path=public'], 'm24_valid_emergency_contacts has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_valid_public_fields(jsonb)'::regprocedure)
            @> array['search_path=public'], 'm24_valid_public_fields has a fixed search_path');
select ok((select proconfig from pg_proc where oid='public.m24_valid_pin(text)'::regprocedure)
            @> array['search_path=public'], 'm24_valid_pin has a fixed search_path');

-- ---------------------------------------------------------------------------
-- 3. Grant di execute
-- ---------------------------------------------------------------------------
select is(has_function_privilege('authenticated','public.set_updated_at()','execute'),false,
  'authenticated cannot execute set_updated_at');
select is(has_function_privilege('authenticated','public.enforce_document_limit()','execute'),false,
  'authenticated cannot execute enforce_document_limit');
select is(has_function_privilege('authenticated','public.audit_document_soft_delete()','execute'),false,
  'authenticated cannot execute audit_document_soft_delete');
select is(has_function_privilege('authenticated','public.handle_new_user()','execute'),false,
  'authenticated cannot execute handle_new_user');

select is(has_function_privilege('anon','public.immutable_array_to_string(text[],text)','execute'),false,
  'anon cannot execute immutable_array_to_string');
select is(has_function_privilege('authenticated','public.immutable_array_to_string(text[],text)','execute'),true,
  'authenticated keeps immutable_array_to_string for the generated column');

select is(has_function_privilege('anon','public.explanation_lookup(uuid,text,text,text,text,text)','execute'),false,
  'anon cannot execute explanation_lookup');
select is(has_function_privilege('authenticated','public.explanation_lookup(uuid,text,text,text,text,text)','execute'),true,
  'authenticated can execute explanation_lookup');

-- ---------------------------------------------------------------------------
-- 4. security_invoker esplicito sulle viste
-- ---------------------------------------------------------------------------
select ok((select reloptions from pg_class where oid='public.biomarker_series'::regclass)
            @> array['security_invoker=true'], 'biomarker_series is security_invoker');
select ok((select reloptions from pg_class where oid='public.latest_organ_states'::regclass)
            @> array['security_invoker=true'], 'latest_organ_states is security_invoker');
select ok((select reloptions from pg_class where oid='public.latest_risk_scores'::regclass)
            @> array['security_invoker=true'], 'latest_risk_scores is security_invoker');
select ok((select reloptions from pg_class where oid='public.ai_usage_daily'::regclass)
            @> array['security_invoker=true'], 'ai_usage_daily is security_invoker');

-- ---------------------------------------------------------------------------
-- 5. Cron con wrapper, purge degli account, bucket (punti 18-23)
--    Tutto come postgres: sono oggetti di sistema, non RLS.
-- ---------------------------------------------------------------------------
select has_function('public','run_expire_stale_document_uploads_logged','{}'::name[],
  'the stale upload job has a logged wrapper');
select has_function('public','run_purge_deleted_accounts_logged','{}'::name[],
  'the account purge has a logged wrapper');
select is(has_function_privilege('authenticated','public.purge_deleted_accounts()','execute'),false,
  'authenticated cannot execute purge_deleted_accounts');

select has_function('public','purge_subject_data',array['uuid'],
  'the subject purge exists');
select is(has_function_privilege('authenticated','public.purge_subject_data(uuid)','execute'),false,
  'authenticated cannot execute purge_subject_data');
select is(has_function_privilege('service_role','public.purge_subject_data(uuid)','execute'),false,
  'not even service_role can execute purge_subject_data directly');

select is((select count(*)::int from cron.job
            where jobname='expire-stale-document-uploads'
              and command like '%run_expire_stale_document_uploads_logged%'),1,
  'the stale upload job runs through the wrapper');
select is((select count(*)::int from cron.job
            where jobname='purge-deleted-accounts'
              and command like '%run_purge_deleted_accounts_logged%'),1,
  'the account purge job runs through the wrapper');

-- fixture: un account cancellato da piu' di trenta giorni, con una riga in
-- ciascuna delle tabelle che la purge deve svuotare; e un account cancellato
-- ieri, che deve restare.
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('d2222222-2222-4222-8222-222222222261','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bruno26@example.com','',now(),'{}','{"full_name":"Bruno"}',now(),now()),
('d3333333-3333-4333-8333-333333333361','00000000-0000-0000-0000-000000000000','authenticated','authenticated','carla26@example.com','',now(),'{}','{"full_name":"Carla"}',now(),now())
on conflict(id) do nothing;

update public.profiles set deleted_at = now() - interval '40 days'
 where id='d2222222-2222-4222-8222-222222222261';
update public.profiles set deleted_at = now() - interval '2 days'
 where id='d3333333-3333-4333-8333-333333333361';

create temp table t26id(k text primary key, v uuid);
grant all on t26id to public;

-- I ricalcoli restano spenti: la fixture deve essere esattamente quella
-- dichiarata qui, non quella riscritta dal motore.
alter table public.observations disable trigger trg_observations_zz_organ_states;
alter table public.observations disable trigger trg_observations_refresh_risks;

insert into public.observations(subject_id,code,display_name,value_num,unit,
  ref_low,ref_high,flag,effective_at,origin) values
('d2222222-2222-4222-8222-222222222261','2345-7','Glicemia',130,'mg/dL',70,99,
 'above','2026-05-01 08:00+00','document');

insert into public.organ_states(subject_id,organ_id,state,confidence,inputs,rule_version)
values('d2222222-2222-4222-8222-222222222261','heart','ok',0.90,'[]'::jsonb,'organ_state-0.3');

insert into public.risk_scores(subject_id,family,level,score,score_unit,inputs,factors,rule_version)
values('d2222222-2222-4222-8222-222222222261','cardiovascular','medium',6.2,'percent',
 '{}'::jsonb,'[]'::jsonb,'risk_score2-0.1-draft');

with d as (
  insert into public.documents(owner_id,subject_id,category,title,source,status,storage_path)
  values('d2222222-2222-4222-8222-222222222261','d2222222-2222-4222-8222-222222222261',
         'exams','Referto da cancellare','pdf','analyzed',
         'subjects/d2222222-2222-4222-8222-222222222261/documents/x/original.pdf')
  returning id)
insert into t26id select 'doc', id from d;

insert into public.document_pages(document_id,page_number)
select v, 1 from t26id where k='doc';

insert into public.alerts(subject_id,type,source_table,source_id,code,level,message_key)
select 'd2222222-2222-4222-8222-222222222261','warning','documents',v,'2345-7',
       'institutional','alertBiomarkerAboveInstitutional'
  from t26id where k='doc';

insert into public.recommendations(subject_id,title_key,reason_key,category,
  interval_months,due_at,status,origin,rule_version)
values('d2222222-2222-4222-8222-222222222261','recommendation_glicemia',
 'recommendation_level_elevated','Esami',12,'2026-09-01','open','rule',
 'recommendation_risk-0-draft');

insert into public.share_links(id,subject_id,created_by,code,pin_hash) values
('e1111111-1111-4111-8111-111111111161','d2222222-2222-4222-8222-222222222261',
 'd2222222-2222-4222-8222-222222222261','960001',crypt('4719',gen_salt('bf')));
insert into public.share_link_opens(share_link_id,outcome) values
('e1111111-1111-4111-8111-111111111161','ok');
insert into public.dossier_snapshots(subject_id,share_link_id) values
('d2222222-2222-4222-8222-222222222261','e1111111-1111-4111-8111-111111111161');

select lives_ok($$select public.purge_deleted_accounts()$$,
  'the purge goes through the append-only tables of the doctor module');

select is((select count(*)::int from auth.users
            where id='d2222222-2222-4222-8222-222222222261'),0,
  'an account deleted more than thirty days ago is gone');
select is((select count(*)::int from auth.users
            where id='d3333333-3333-4333-8333-333333333361'),1,
  'an account deleted two days ago stays');
select is((select count(*)::int from public.audit_log
            where action='account.purged'
              and subject_id='d2222222-2222-4222-8222-222222222261'
              and actor_id is null),1,
  'the purge writes one account.purged row with no actor');

-- una asserzione per tabella: nessuna riga del soggetto sopravvive
select is((select count(*)::int from public.observations
            where subject_id='d2222222-2222-4222-8222-222222222261'),0,
  'the purge leaves no observation of the subject');
select is((select count(*)::int from public.organ_states
            where subject_id='d2222222-2222-4222-8222-222222222261'),0,
  'the purge leaves no organ state of the subject');
select is((select count(*)::int from public.risk_scores
            where subject_id='d2222222-2222-4222-8222-222222222261'),0,
  'the purge leaves no risk score of the subject');
select is((select count(*)::int from public.documents
            where subject_id='d2222222-2222-4222-8222-222222222261'),0,
  'the purge leaves no document of the subject');
select is((select count(*)::int from public.document_pages
            where document_id=(select v from t26id where k='doc')),0,
  'the purge leaves no document page of the subject');
select is((select count(*)::int from public.alerts
            where subject_id='d2222222-2222-4222-8222-222222222261'),0,
  'the purge leaves no alert of the subject');
select is((select count(*)::int from public.recommendations
            where subject_id='d2222222-2222-4222-8222-222222222261'),0,
  'the purge leaves no recommendation of the subject');
select is((select count(*)::int from public.share_links
            where subject_id='d2222222-2222-4222-8222-222222222261'),0,
  'the purge leaves no share link of the subject');
select is((select count(*)::int from public.share_link_opens
            where share_link_id='e1111111-1111-4111-8111-111111111161'),0,
  'the purge empties the link register');
select is((select count(*)::int from public.dossier_snapshots
            where subject_id='d2222222-2222-4222-8222-222222222261'),0,
  'the purge removes the frozen dossier');

select is(coalesce(current_setting('medical24.allow_purge',true),'off'),'off',
  'the purge switch is back off');

alter table public.observations enable trigger trg_observations_zz_organ_states;
alter table public.observations enable trigger trg_observations_refresh_risks;

-- ---------------------------------------------------------------------------
-- 5b. I due wrapper girano davvero e lasciano un cron_run 'ok' ciascuno.
--     platform_events contiene gia' righe vere: il conteggio e' relativo.
-- ---------------------------------------------------------------------------
insert into t26(k,n) select 'cron_ok_expire', count(*)::int from public.platform_events
 where kind='cron_run' and source='expire_stale_document_uploads' and status='ok';
insert into t26(k,n) select 'cron_ok_purge', count(*)::int from public.platform_events
 where kind='cron_run' and source='purge_deleted_accounts' and status='ok';

select lives_ok($$select public.run_expire_stale_document_uploads_logged()$$,
  'the stale upload wrapper runs');
select lives_ok($$select public.run_purge_deleted_accounts_logged()$$,
  'the account purge wrapper runs');

select is((select count(*)::int from public.platform_events
            where kind='cron_run' and source='expire_stale_document_uploads' and status='ok'),
          (select n from t26 where k='cron_ok_expire') + 1,
  'the stale upload wrapper adds one cron_run ok event');
select is((select count(*)::int from public.platform_events
            where kind='cron_run' and source='purge_deleted_accounts' and status='ok'),
          (select n from t26 where k='cron_ok_purge') + 1,
  'the account purge wrapper adds one cron_run ok event');

-- bucket dichiarati in migrazione
select is((select public from storage.buckets where id='dossiers'),false,
  'the dossiers bucket exists and stays private');
select is((select public from storage.buckets where id='brand'),true,
  'the brand bucket exists and is public');
select is((select count(*)::int from pg_policies
            where schemaname='storage' and tablename='objects'
              and qual like '%dossiers%'),0,
  'no storage policy opens the dossiers bucket to the applicative roles');

-- righe finte, inserite come postgres, per misurare che cosa vede anon
insert into storage.objects(bucket_id,name) values
 ('brand','logo-test-0026.png'),
 ('dossiers','subjects/d1111111-1111-4111-8111-111111111161/dossier/test-0026.pdf')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 6. Un utente estraneo: che cosa legge davvero (punto 34 dell'audit)
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d1111111-1111-4111-8111-111111111161","role":"authenticated"}',true);

select is((select count(*)::int from public.app_migrations),0,
  'a stranger reads no row of app_migrations');
select is((select count(*)::int from public.alerts),0,
  'a stranger reads no alert');
select is((select count(*)::int from public.favorites),0,
  'a stranger reads no favorite');
select is((select count(*)::int from public.platform_settings_history),0,
  'a stranger reads no platform settings history');
select is((select count(*)::int from public.platform_events),0,
  'a stranger reads no platform event');
select is((select count(*)::int from public.ai_usage_ledger),0,
  'a stranger reads no ai usage row');

-- rating_summaries e treatment_tags sono pubbliche per scelta: il confronto e'
-- con la base salvata, mai con zero.
select is((select count(*)::int from public.rating_summaries),
          (select n from t26 where k='rating_summaries'),
  'rating summaries stay public and complete for a stranger');
select is((select count(*)::int from public.treatment_tags),
          (select n from t26 where k='treatment_tags'),
  'the treatment tag vocabulary stays public for a stranger');

-- ---------------------------------------------------------------------------
-- 7. La colonna generata di documents continua a funzionare
-- ---------------------------------------------------------------------------
select lives_ok($$
  insert into public.documents(owner_id, subject_id, title, tags, storage_path)
  values ('d1111111-1111-4111-8111-111111111161','d1111111-1111-4111-8111-111111111161',
          'Referto di prova', array['cuore','controllo'],
          'subjects/d1111111-1111-4111-8111-111111111161/documents/x/original.pdf')
$$, 'an authenticated insert on documents still evaluates the generated column');

-- ---------------------------------------------------------------------------
-- 8. Storage visto da anon: solo il bucket brand
-- ---------------------------------------------------------------------------
reset role;
set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);

select is((select count(*)::int from storage.objects where name='logo-test-0026.png'),1,
  'anon reads the brand bucket');
select is((select count(*)::int from storage.objects where bucket_id='dossiers'),0,
  'anon reads nothing of the dossiers bucket');

reset role;
select * from finish();
rollback;
