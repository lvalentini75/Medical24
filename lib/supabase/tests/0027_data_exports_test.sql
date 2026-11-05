-- Medical 24 - pgTAP 0027 Export dei dati (P10-A3-1).
-- Dev only; rollback finale.
-- Pattern CONTEXT_CORE §6: fixture come postgres, poi set local role + claims JWT.
--
-- Il "contesto interno" di data_export_finish e' postgres con il claim
-- role = service_role: e' cosi' che lo chiamera' la funzione di servizio.
--
-- Il database dev contiene gia' righe vere: i conteggi su audit_log sono
-- relativi a una base salvata prima dell'azione, mai assoluti.
begin;
create extension if not exists pgtap with schema extensions;
select plan(40);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('d1111111-1111-4111-8111-111111111127','00000000-0000-0000-0000-000000000000','authenticated','authenticated','alice27@example.com','',now(),'{}','{"full_name":"Alice"}',now(),now()),
('d2222222-2222-4222-8222-222222222227','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bruno27@example.com','',now(),'{}','{"full_name":"Bruno"}',now(),now())
on conflict(id) do nothing;

create temp table t27(k text primary key, u uuid, s text, n int, j jsonb);
grant all on t27 to public;

insert into t27(k,n) select 'audit_ready', count(*)::int from public.audit_log
 where action='data_export.ready';

-- ---------------------------------------------------------------------------
-- 1. Tabella, RLS, policy, indice, enum, firme, registro
-- ---------------------------------------------------------------------------
select has_table('public','data_exports','data_exports exists');
select is((select relrowsecurity and relforcerowsecurity
             from pg_class where oid='public.data_exports'::regclass),
  true,'data_exports has forced row level security');
select is((select count(*)::int from pg_policies
            where schemaname='public' and tablename='data_exports'),1,
  'data_exports has exactly one policy');
select is((select cmd from pg_policies
            where schemaname='public' and tablename='data_exports'),'SELECT',
  'the only policy of data_exports is a select');
select has_index('public','data_exports','idx_data_exports_subject_requested',
  'data_exports is indexed by subject and request time');
select is((select count(*)::int from pg_enum e
            join pg_type t on t.oid=e.enumtypid
           where t.typname='data_export_status'),4,
  'data_export_status has four labels');

select has_function('public','data_export_request',array['uuid'],
  'data_export_request exists');
select has_function('public','data_export_finish',
  array['uuid','data_export_status','text','bigint','int','boolean','text'],
  'data_export_finish exists');
select has_function('public','data_export_latest',array['uuid'],
  'data_export_latest exists');
select is((select count(*)::int from public.app_migrations where name='0027_data_exports'),1,
  '0027 registered');

select is(has_function_privilege('anon','public.data_export_request(uuid)','execute'),false,
  'anon cannot request an export');
select is(has_function_privilege('authenticated',
  'public.data_export_finish(uuid,data_export_status,text,bigint,int,boolean,text)','execute'),false,
  'authenticated cannot close an export');

-- ---------------------------------------------------------------------------
-- 2. Alice richiede il proprio export
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d1111111-1111-4111-8111-111111111127","role":"authenticated"}',true);

select lives_ok(
  $$insert into t27(k,u) select 'exp', public.data_export_request('d1111111-1111-4111-8111-111111111127')$$,
  'alice requests her own export');
select is((select status::text from public.data_exports
            where id=(select u from t27 where k='exp')),'pending',
  'the new request is pending');
select is((select requested_by from public.data_exports
            where id=(select u from t27 where k='exp')),
          'd1111111-1111-4111-8111-111111111127'::uuid,
  'the request records who asked for it');

select throws_ok(
  $$select public.data_export_request('d1111111-1111-4111-8111-111111111127')$$,
  'P0001',null,'a second request within twenty-four hours is refused');

-- ---------------------------------------------------------------------------
-- 3. Bruno sul soggetto di Alice
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"d2222222-2222-4222-8222-222222222227","role":"authenticated"}',true);
select throws_ok(
  $$select public.data_export_request('d1111111-1111-4111-8111-111111111127')$$,
  '42501',null,'a stranger cannot request the export of someone else');
select is((select count(*)::int from public.data_exports),0,
  'a stranger reads no export row');

-- Nemmeno chiudendola a mano: data_export_finish e' del solo service_role.
select throws_ok(
  $$select public.data_export_finish(
      (select u from t27 where k='exp'),'ready',
      'subjects/d1111111-1111-4111-8111-111111111127/exports/x.zip',10,1,false,null)$$,
  '42501',null,'authenticated cannot close an export');

-- ---------------------------------------------------------------------------
-- 4. Contesto interno: la path e' imposta
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);

select throws_ok(
  $$select public.data_export_finish(
      (select u from t27 where k='exp'),'ready','exports/sbagliata.zip',10,1,false,null)$$,
  '22023',null,'a path outside subjects/{subject}/exports/{id}.zip is refused');

insert into t27(k,s) select 'path',
  'subjects/d1111111-1111-4111-8111-111111111127/exports/'||u::text||'.zip'
  from t27 where k='exp';

select lives_ok(
  $$select public.data_export_finish(
      (select u from t27 where k='exp'),'ready',
      (select s from t27 where k='path'),2048,7,false,null)$$,
  'the service closes the export with the expected path');

select is((select status::text from public.data_exports
            where id=(select u from t27 where k='exp')),'ready',
  'the closed export is ready');
select is((select storage_path from public.data_exports
            where id=(select u from t27 where k='exp')),
          (select s from t27 where k='path'),
  'the export keeps the expected storage path');
select is((select bytes from public.data_exports
            where id=(select u from t27 where k='exp')),2048::bigint,
  'the export keeps its size');
select is((select file_count from public.data_exports
            where id=(select u from t27 where k='exp')),7,
  'the export keeps its file count');
select ok((select expires_at from public.data_exports
             where id=(select u from t27 where k='exp'))
          between clock_timestamp() + interval '6 days 23 hours'
              and clock_timestamp() + interval '7 days 1 hour',
  'a ready export expires seven days later');
select is((select count(*)::int from public.audit_log where action='data_export.ready'),
          (select n from t27 where k='audit_ready') + 1,
  'closing the export writes one data_export.ready row');
select is((select count(*)::int from public.audit_log
            where action='data_export.ready'
              and target_id=(select u from t27 where k='exp')
              and subject_id='d1111111-1111-4111-8111-111111111127'
              and actor_id is null),1,
  'the data_export.ready row has no actor and points at the subject');

-- ---------------------------------------------------------------------------
-- 5. Che cosa vede il proprietario
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d1111111-1111-4111-8111-111111111127","role":"authenticated"}',true);

insert into t27(k,j) select 'latest',
  public.data_export_latest('d1111111-1111-4111-8111-111111111127');

select is((select j->>'status' from t27 where k='latest'),'ready',
  'data_export_latest returns the ready export');
select is((select j->>'storage_path' from t27 where k='latest'),
          (select s from t27 where k='path'),
  'a ready and unexpired export shows its storage path');
select is((select (j->>'truncated')::boolean from t27 where k='latest'),false,
  'the export is not truncated');
select is((select (j->>'file_count')::int from t27 where k='latest'),7,
  'data_export_latest reports the file count');

select set_config('request.jwt.claims','{"sub":"d2222222-2222-4222-8222-222222222227","role":"authenticated"}',true);
select is(public.data_export_latest('d2222222-2222-4222-8222-222222222227'),
          null::jsonb,
  'a subject with no request gets null');
select throws_ok(
  $$select public.data_export_latest('d1111111-1111-4111-8111-111111111127')$$,
  '42501',null,'a stranger cannot read the export of someone else');

-- ---------------------------------------------------------------------------
-- 6. Bucket e purge
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims','',true);

select is((select public from storage.buckets where id='exports'),false,
  'the exports bucket exists and stays private');
select is((select file_size_limit from storage.buckets where id='exports'),524288000::bigint,
  'the exports bucket stops at five hundred megabytes');
select is((select allowed_mime_types from storage.buckets where id='exports'),
          array['application/zip'],
  'the exports bucket accepts zip only');
select is((select count(*)::int from pg_policies
            where schemaname='storage' and tablename='objects'
              and qual like '%exports%'),0,
  'no storage policy opens the exports bucket to the applicative roles');

select ok((select prosrc from pg_proc where oid='public.purge_subject_data(uuid)'::regprocedure)
            like '%''data_exports''%',
  'the subject purge removes the export rows too');
select ok((select prosrc from pg_proc where oid='public.purge_subject_data(uuid)'::regprocedure)
            like '%doctor_id = $1%',
  'the subject purge removes the thresholds written as a doctor');

select * from finish();
rollback;
