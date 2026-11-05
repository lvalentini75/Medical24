-- Medical 24 - pgTAP 0030 Famiglia, hardening dello schema (P11-A5a).
-- Dev only; tutto dentro begin ... rollback.
-- Modello: lib/supabase/tests/0029_family_delegates_test.sql
--
-- Fixture di auth.users create come postgres prima di qualunque set local
-- role; il trigger on_auth_user_created riempie profiles da solo.
-- Il database dev contiene righe vere: su audit_log si confronta il
-- conteggio prima e dopo l'azione, mai un valore assoluto.
--
-- Personaggi (suffisso 30, nessuno in comune con il test della 0029):
--   Elena  il soggetto; a meta' prova il suo profilo viene chiuso
--   Bruno  caregiver con email confermata: accetta e legge
--   Carla  stesso indirizzo invitato, ma email MAI confermata
--   Dino   owner dei profili gestiti
--   Mia    utente ombra, profilo gestito di Dino
begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('a1111111-1111-4111-8111-111111111130','00000000-0000-0000-0000-000000000000','authenticated','authenticated','elena30@example.com','',now(),'{}','{"full_name":"Elena"}',now(),now()),
('a2222222-2222-4222-8222-222222222230','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bruno30@example.com','',now(),'{}','{"full_name":"Bruno"}',now(),now()),
-- Carla non ha mai confermato l'indirizzo: email_confirmed_at resta nullo.
('a3333333-3333-4333-8333-333333333330','00000000-0000-0000-0000-000000000000','authenticated','authenticated','carla30@example.com','',null,'{}','{"full_name":"Carla"}',now(),now()),
('a4444444-4444-4444-8444-444444444430','00000000-0000-0000-0000-000000000000','authenticated','authenticated','dino30@example.com','',now(),'{}','{"full_name":"Dino"}',now(),now()),
-- l'utente ombra: lo crea la Edge Function con il service_role, qui serve pronto
('c1111111-1111-4111-8111-111111111130','00000000-0000-0000-0000-000000000000','authenticated','authenticated','managed1.30@example.com','',now(),'{}','{"full_name":"Mia"}',now(),now())
on conflict(id) do nothing;

insert into public.profiles(id,full_name) values
('a1111111-1111-4111-8111-111111111130','Elena'),
('a2222222-2222-4222-8222-222222222230','Bruno'),
('a3333333-3333-4333-8333-333333333330','Carla'),
('a4444444-4444-4444-8444-444444444430','Dino'),
('c1111111-1111-4111-8111-111111111130','Mia')
on conflict(id) do nothing;

-- un documento di Elena: e' il dato clinico che la delega apre e che il
-- profilo chiuso deve tornare a nascondere
insert into public.documents(id,owner_id,subject_id,title,storage_path,status)
values ('d1111111-1111-4111-8111-111111111130',
        'a1111111-1111-4111-8111-111111111130',
        'a1111111-1111-4111-8111-111111111130',
        'Emocromo','subjects/a1111111-1111-4111-8111-111111111130/documents/d1111111-1111-4111-8111-111111111130/original.pdf',
        'uploaded');

create temp table t30(k text primary key, u uuid, n int, b boolean, j jsonb);
grant all on t30 to public;

insert into t30(k,n) select 'audit_decl', count(*)::int from public.audit_log
 where action='family.guardian_declaration';

-- ---------------------------------------------------------------------------
-- 1. Registro e firma di family_member_register
-- ---------------------------------------------------------------------------
select is((select count(*)::int from public.app_migrations where name='0030_family_hardening'),1,
  '0030 registered');
select has_function('public','family_member_register',
  array['uuid','uuid','text','text','date','text','text'],
  'family_member_register takes the declaration version');
select is((select count(*)::int from pg_proc p
            join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.proname='family_member_register'
             and p.pronargs=6),0,
  'the old six argument signature is gone');
select is(has_function_privilege('service_role',
  'public.family_member_register(uuid,uuid,text,text,date,text,text)','execute'),true,
  'service_role can register a managed profile');
select is(has_function_privilege('authenticated',
  'public.family_member_register(uuid,uuid,text,text,date,text,text)','execute'),false,
  'an authenticated user cannot register a managed profile');

-- ---------------------------------------------------------------------------
-- 2. Lo scope parziale non si promette: solo {"all": true}
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111130","role":"authenticated"}',true);

select throws_ok(
  $$select public.delegate_invite('a1111111-1111-4111-8111-111111111130','x30@example.com',
      '{"organs": ["liver"]}'::jsonb)$$,
  '22023',null,'a partial scope is refused while it is not applied to reads');

-- ---------------------------------------------------------------------------
-- 3. Un indirizzo non confermato non accetta nulla e non vede nulla
-- ---------------------------------------------------------------------------
insert into t30(k,j) select 'inv_carla',
  public.delegate_invite('a1111111-1111-4111-8111-111111111130','carla30@example.com');
select is((select j->>'status' from t30 where k='inv_carla'),'invited',
  'the invitation to the unconfirmed address is created');

reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a3333333-3333-4333-8333-333333333330","role":"authenticated"}',true);
select is((select count(*)::int from public.my_pending_invitations()),0,
  'a user whose email is not confirmed sees no pending invitation');
select throws_ok(
  format($$select public.delegate_accept(%L::uuid)$$, (select j->>'id' from t30 where k='inv_carla')),
  'P0001','email_not_confirmed',
  'a user whose email is not confirmed cannot accept');

-- ---------------------------------------------------------------------------
-- 4. Un profilo chiuso non si legge piu', nemmeno da se stessi
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111130","role":"authenticated"}',true);
insert into t30(k,j) select 'inv_bruno',
  public.delegate_invite('a1111111-1111-4111-8111-111111111130','bruno30@example.com');

reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a2222222-2222-4222-8222-222222222230","role":"authenticated"}',true);
insert into t30(k,j) select 'acc_bruno',
  public.delegate_accept((select j->>'id' from t30 where k='inv_bruno')::uuid);
select is(public.can_access_subject('a1111111-1111-4111-8111-111111111130'),true,
  'the active delegate reads the subject while the profile is alive');

-- il profilo di Elena viene chiuso (come fa soft_delete_account)
reset role; select set_config('request.jwt.claims','',true);
update public.profiles set deleted_at = now()
 where id='a1111111-1111-4111-8111-111111111130';

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a2222222-2222-4222-8222-222222222230","role":"authenticated"}',true);
select is(public.can_access_subject('a1111111-1111-4111-8111-111111111130'),false,
  'a deleted profile is closed to its delegate');

reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111130","role":"authenticated"}',true);
select is(public.can_access_subject('a1111111-1111-4111-8111-111111111130'),false,
  'a deleted profile is closed to the subject itself');

-- ---------------------------------------------------------------------------
-- 5. La dichiarazione di responsabilita' e' obbligatoria e finisce in audit
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);

select throws_ok(
  $$select public.family_member_register('c1111111-1111-4111-8111-111111111130',
      'a4444444-4444-4444-8444-444444444430','Mia','')$$,
  '22023',null,'an empty declaration version is refused');
select throws_ok(
  $$select public.family_member_register('c1111111-1111-4111-8111-111111111130',
      'a4444444-4444-4444-8444-444444444430','Mia',null::text)$$,
  '22023',null,'a missing declaration version is refused');

insert into t30(k,j) select 'reg_mia', public.family_member_register(
  'c1111111-1111-4111-8111-111111111130','a4444444-4444-4444-8444-444444444430',
  'Mia','guardian-1.0','2015-04-02','female','figlia');

select is((select j->>'declaration_version' from t30 where k='reg_mia'),'guardian-1.0',
  'the call reports the accepted declaration version');
select is((select count(*)::int from public.audit_log where action='family.guardian_declaration')
          - (select n from t30 where k='audit_decl'),1,
  'the guardian declaration is written exactly once');
select is((select count(*)::int from public.audit_log
            where action='family.guardian_declaration'
              and actor_id='a4444444-4444-4444-8444-444444444430'
              and target_table='consents'
              and target_id='c1111111-1111-4111-8111-111111111130'
              and subject_id='c1111111-1111-4111-8111-111111111130'
              and device='guardian-1.0'),1,
  'the audit row carries actor, subject and version');

-- ---------------------------------------------------------------------------
-- 6. Un caregiver attivo legge, e basta
--
--    Dino invita Bruno come caregiver sul profilo gestito Mia; Bruno accetta.
--    Da quel momento Bruno vede i dati di Mia ma non puo' invitare altri, non
--    puo' cambiarne l'anagrafica e non puo' chiudere il profilo.
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a4444444-4444-4444-8444-444444444430","role":"authenticated"}',true);
insert into t30(k,j) select 'inv_mia',
  public.delegate_invite('c1111111-1111-4111-8111-111111111130','bruno30@example.com');

reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a2222222-2222-4222-8222-222222222230","role":"authenticated"}',true);
insert into t30(k,j) select 'acc_mia',
  public.delegate_accept((select j->>'id' from t30 where k='inv_mia')::uuid);
select is((select j->>'status' from t30 where k='acc_mia'),'active',
  'the caregiver of the managed profile is active');

select throws_ok(
  $$select public.delegate_invite('c1111111-1111-4111-8111-111111111130','altro30@example.com')$$,
  '42501',null,'an active caregiver cannot invite another caregiver');
select throws_ok(
  $$select public.family_member_update('c1111111-1111-4111-8111-111111111130','Nome cambiato')$$,
  '42501',null,'an active caregiver cannot update the managed profile');
select throws_ok(
  $$select public.family_member_remove('c1111111-1111-4111-8111-111111111130')$$,
  '42501',null,'an active caregiver cannot remove the managed profile');

-- ---------------------------------------------------------------------------
-- 7. La rimozione chiude le domande aperte e fa scadere gli export pronti
--
--    Fixture come postgres: una domanda in bozza e un export pronto di Mia.
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
insert into public.questions(id,subject_id,title,body,status)
values ('b1111111-1111-4111-8111-111111111130','c1111111-1111-4111-8111-111111111130',
        'Domanda aperta','Testo della domanda al medico.','draft');
insert into public.data_exports(id,subject_id,requested_by,status,storage_path,ready_at,expires_at)
values ('e1111111-1111-4111-8111-111111111130','c1111111-1111-4111-8111-111111111130',
        'a4444444-4444-4444-8444-444444444430','ready',
        'subjects/c1111111-1111-4111-8111-111111111130/exports/e1111111-1111-4111-8111-111111111130.zip',
        now(), now()+interval '7 days');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a4444444-4444-4444-8444-444444444430","role":"authenticated"}',true);
insert into t30(k,j) select 'remove_mia',
  public.family_member_remove('c1111111-1111-4111-8111-111111111130');

select is((select (j->>'questions_closed')::int from t30 where k='remove_mia'),1,
  'the removal reports the closed question');
select is((select (j->>'exports_expired')::int from t30 where k='remove_mia'),1,
  'the removal reports the expired export');

reset role; select set_config('request.jwt.claims','',true);
select is((select status::text from public.questions
            where id='b1111111-1111-4111-8111-111111111130'),'closed',
  'the open question of the removed profile is closed');
select is((select status::text from public.data_exports
            where id='e1111111-1111-4111-8111-111111111130'),'expired',
  'the ready export of the removed profile is expired');

select * from finish();
rollback;
