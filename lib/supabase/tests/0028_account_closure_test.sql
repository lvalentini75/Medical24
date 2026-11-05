-- Medical 24 - pgTAP 0028 Chiusura dell'account (P10-A4).
-- Dev only; rollback finale.
-- Pattern CONTEXT_CORE §6: fixture come postgres, poi set local role + claims JWT.
--
-- Il "contesto interno" di account_close e' postgres con il claim
-- role = service_role: e' cosi' che la chiama la Edge Function delete-account.
--
-- Il database dev contiene gia' righe vere: il conteggio su audit_log e'
-- relativo a una base salvata prima dell'azione, mai assoluto.
begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('e1111111-1111-4111-8111-111111111128','00000000-0000-0000-0000-000000000000','authenticated','authenticated','alice28@example.com','',now(),'{}','{"full_name":"Alice"}',now(),now()),
('e2222222-2222-4222-8222-222222222228','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bruno28@example.com','',now(),'{}','{"full_name":"Bruno"}',now(),now())
on conflict(id) do nothing;

create temp table t28(k text primary key, u uuid, s text, n int, j jsonb);
grant all on t28 to public;

insert into t28(k,n) select 'audit_closed', count(*)::int from public.audit_log
 where action='account.closed';

-- ---------------------------------------------------------------------------
-- Fixture: due link attivi (uno gia' revocato fa da controllo), una scheda,
-- una domanda inviata, un export pronto. Tutto come postgres, che ha
-- bypassrls: qui non si esercita la RLS, si esercita account_close.
-- ---------------------------------------------------------------------------
insert into public.share_links(id,subject_id,created_by,code,pin_hash,expires_at)
values
 ('aa111111-1111-4111-8111-111111111128','e1111111-1111-4111-8111-111111111128',
  'e1111111-1111-4111-8111-111111111128','981271','$2a$10$abcdefghijklmnopqrstuv',now()+interval '7 days'),
 ('aa222222-2222-4222-8222-222222222228','e1111111-1111-4111-8111-111111111128',
  'e1111111-1111-4111-8111-111111111128','981272','$2a$10$abcdefghijklmnopqrstuv',now()+interval '7 days');

-- link gia' revocato: non deve essere contato una seconda volta
insert into public.share_links(id,subject_id,created_by,code,pin_hash,expires_at,revoked_at)
values ('aa333333-3333-4333-8333-333333333328','e1111111-1111-4111-8111-111111111128',
  'e1111111-1111-4111-8111-111111111128','981273','$2a$10$abcdefghijklmnopqrstuv',
  now()+interval '7 days', now());

-- link di un altro soggetto: account_close non lo tocca
insert into public.share_links(id,subject_id,created_by,code,pin_hash,expires_at)
values ('aa444444-4444-4444-8444-444444444428','e2222222-2222-4222-8222-222222222228',
  'e2222222-2222-4222-8222-222222222228','981274','$2a$10$abcdefghijklmnopqrstuv',
  now()+interval '7 days');

insert into public.emergency_cards(subject_id,blood_group)
values ('e1111111-1111-4111-8111-111111111128','A+')
on conflict (subject_id) do nothing;

insert into t28(k,s) select 'token', public_token from public.emergency_cards
 where subject_id='e1111111-1111-4111-8111-111111111128';

insert into public.questions(id,subject_id,title,body,status)
values
 ('bb111111-1111-4111-8111-111111111128','e1111111-1111-4111-8111-111111111128',
  'Domanda inviata','Testo della domanda inviata al medico.','sent'),
 ('bb222222-2222-4222-8222-222222222228','e1111111-1111-4111-8111-111111111128',
  'Domanda chiusa','Testo della domanda gia'' chiusa.','closed');

insert into public.data_exports(id,subject_id,requested_by,status,storage_path,bytes,file_count,
  ready_at,expires_at)
values ('cc111111-1111-4111-8111-111111111128','e1111111-1111-4111-8111-111111111128',
  'e1111111-1111-4111-8111-111111111128','ready',
  'subjects/e1111111-1111-4111-8111-111111111128/exports/cc111111-1111-4111-8111-111111111128.zip',
  2048,7,now(),now()+interval '7 days');

-- ---------------------------------------------------------------------------
-- 1. Firma, registro, permessi
-- ---------------------------------------------------------------------------
select has_function('public','account_close',array['uuid'],'account_close exists');
select is((select count(*)::int from public.app_migrations where name='0028_account_closure'),1,
  '0028 registered');
select is(has_function_privilege('anon','public.account_close(uuid)','execute'),false,
  'anon cannot close an account');
select is(has_function_privilege('authenticated','public.account_close(uuid)','execute'),false,
  'authenticated cannot close an account');
select is(has_function_privilege('service_role','public.account_close(uuid)','execute'),true,
  'the service role can close an account');
select is((select prosecdef from pg_proc where oid='public.account_close(uuid)'::regprocedure),true,
  'account_close is security definer');
select is((select proconfig from pg_proc where oid='public.account_close(uuid)'::regprocedure),
  array['search_path=public'],
  'account_close pins its search path');

-- ---------------------------------------------------------------------------
-- 2. Un utente autenticato non la chiama
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"e1111111-1111-4111-8111-111111111128","role":"authenticated"}',true);
select throws_ok(
  $$select public.account_close('e1111111-1111-4111-8111-111111111128')$$,
  '42501',null,'authenticated cannot close an account');

-- ---------------------------------------------------------------------------
-- 3. Il servizio chiude l'account
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);

select throws_ok(
  $$select public.account_close(null)$$,
  '22023',null,'a null subject is refused');

insert into t28(k,j) select 'first', public.account_close('e1111111-1111-4111-8111-111111111128');

select is((select (j->>'links_revoked')::int from t28 where k='first'),2,
  'the two active links are revoked');
select is((select (j->>'emergency_card_removed')::int from t28 where k='first'),1,
  'the emergency card is removed');
select is((select (j->>'questions_closed')::int from t28 where k='first'),1,
  'the only open question is closed');
select is((select (j->>'exports_expired')::int from t28 where k='first'),1,
  'the ready export is expired');

select is((select count(*)::int from public.share_links
            where subject_id='e1111111-1111-4111-8111-111111111128'
              and revoked_at is null),0,
  'no link of the subject stays active');
select is((select count(*)::int from public.share_links
            where subject_id='e2222222-2222-4222-8222-222222222228'
              and revoked_at is null),1,
  'the link of another subject is untouched');
select is((select count(*)::int from public.emergency_cards
            where subject_id='e1111111-1111-4111-8111-111111111128'),0,
  'the emergency card row is gone, so the public token is gone with it');
select is((select count(*)::int from public.emergency_cards
            where public_token=(select s from t28 where k='token')),0,
  'the public token of the card no longer resolves');
select is((select count(*)::int from public.questions
            where subject_id='e1111111-1111-4111-8111-111111111128'
              and status <> 'closed'),0,
  'no question of the subject stays open');
select is((select status::text from public.data_exports
            where id='cc111111-1111-4111-8111-111111111128'),'expired',
  'the ready export is marked expired');
select ok((select expires_at from public.data_exports
             where id='cc111111-1111-4111-8111-111111111128') <= clock_timestamp(),
  'the expired export cannot be downloaded again');

select is((select count(*)::int from public.audit_log where action='account.closed'),
          (select n from t28 where k='audit_closed') + 1,
  'closing the account writes one account.closed row');
select is((select count(*)::int from public.audit_log
            where action='account.closed'
              and subject_id='e1111111-1111-4111-8111-111111111128'
              and target_id='e1111111-1111-4111-8111-111111111128'
              and actor_id is null),1,
  'the account.closed row points at the subject and has no actor when the service calls');

-- ---------------------------------------------------------------------------
-- 4. Idempotenza: la seconda chiamata non trova piu' niente da chiudere
-- ---------------------------------------------------------------------------
insert into t28(k,j) select 'second', public.account_close('e1111111-1111-4111-8111-111111111128');

select is((select j from t28 where k='second'),
  jsonb_build_object('links_revoked',0,'questions_closed',0,
                     'emergency_card_removed',0,'exports_expired',0),
  'the second call returns all zeros');

select * from finish();
rollback;
