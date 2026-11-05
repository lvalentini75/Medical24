-- Medical 24 - pgTAP 0029 Famiglia e caregiver (P11-A1a).
-- Aggiornato con la 0030: family_member_register richiede la versione della dichiarazione (4o argomento).
-- Dev only; tutto dentro begin ... rollback.
-- Modello: lib/supabase/tests/0014_platform_control_plane_test.sql
--
-- Fixture di auth.users create come postgres prima di qualunque set local
-- role; il trigger on_auth_user_created riempie profiles da solo.
-- Il database dev contiene righe vere: su audit_log si confronta il
-- conteggio prima e dopo l'azione, mai un valore assoluto.
--
-- Personaggi:
--   Alice   il soggetto
--   Bob     invitato come caregiver, accetta
--   Carlo   estraneo che prova ad accettare e a leggere
--   Dario   estraneo puro: deve vedere zero deleghe
begin;
create extension if not exists pgtap with schema extensions;
select plan(85);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('a1111111-1111-4111-8111-111111111129','00000000-0000-0000-0000-000000000000','authenticated','authenticated','alice29@example.com','',now(),'{}','{"full_name":"Alice"}',now(),now()),
('a2222222-2222-4222-8222-222222222229','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bob29@example.com','',now(),'{}','{"full_name":"Bob"}',now(),now()),
('a3333333-3333-4333-8333-333333333329','00000000-0000-0000-0000-000000000000','authenticated','authenticated','carlo29@example.com','',now(),'{}','{"full_name":"Carlo"}',now(),now()),
('a4444444-4444-4444-8444-444444444429','00000000-0000-0000-0000-000000000000','authenticated','authenticated','dario29@example.com','',now(),'{}','{"full_name":"Dario"}',now(),now()),
-- i quattro utenti "ombra": nessuno di loro accede mai, li crea la Edge
-- Function di P11-A2 con il service_role. Qui servono gia' pronti.
('c1111111-1111-4111-8111-111111111129','00000000-0000-0000-0000-000000000000','authenticated','authenticated','managed1.29@example.com','',now(),'{}','{"full_name":"Mia"}',now(),now()),
('c2222222-2222-4222-8222-222222222229','00000000-0000-0000-0000-000000000000','authenticated','authenticated','managed2.29@example.com','',now(),'{}','{"full_name":"Nina"}',now(),now()),
('c3333333-3333-4333-8333-333333333329','00000000-0000-0000-0000-000000000000','authenticated','authenticated','managed3.29@example.com','',now(),'{}','{"full_name":"Oscar"}',now(),now()),
('c4444444-4444-4444-8444-444444444429','00000000-0000-0000-0000-000000000000','authenticated','authenticated','managed4.29@example.com','',now(),'{}','{"full_name":"Piero"}',now(),now())
on conflict(id) do nothing;

insert into public.profiles(id,full_name) values
('a1111111-1111-4111-8111-111111111129','Alice'),
('a2222222-2222-4222-8222-222222222229','Bob'),
('a3333333-3333-4333-8333-333333333329','Carlo'),
('a4444444-4444-4444-8444-444444444429','Dario'),
('c1111111-1111-4111-8111-111111111129','Mia'),
('c2222222-2222-4222-8222-222222222229','Nina'),
('c3333333-3333-4333-8333-333333333329','Oscar'),
('c4444444-4444-4444-8444-444444444429','Piero')
on conflict(id) do nothing;

-- i consensi di Alice: family_member_register li copia sul profilo gestito
insert into public.consents(user_id,type,version,granted,locale) values
('a1111111-1111-4111-8111-111111111129','health_data','1.0',true,'it'),
('a1111111-1111-4111-8111-111111111129','ai_processing','1.0',true,'it'),
('a1111111-1111-4111-8111-111111111129','marketing','1.0',true,'it');

-- un documento di Alice: e' il dato clinico che la delega deve aprire
insert into public.documents(id,owner_id,subject_id,title,storage_path,status)
values ('d1111111-1111-4111-8111-111111111129',
        'a1111111-1111-4111-8111-111111111129',
        'a1111111-1111-4111-8111-111111111129',
        'Emocromo','subjects/a1111111-1111-4111-8111-111111111129/documents/d1111111-1111-4111-8111-111111111129/original.pdf',
        'uploaded');

create temp table t29(k text primary key, u uuid, n int, b boolean, j jsonb);
grant all on t29 to public;

insert into t29(k,n) select 'audit_viewed', count(*)::int from public.audit_log
 where action='subject.viewed';

-- ---------------------------------------------------------------------------
-- 1. Struttura, registro, permessi
-- ---------------------------------------------------------------------------
select has_table('public','subject_delegates','subject_delegates exists');
select has_column('public','profiles','managed_by','profiles has managed_by');
select is((select count(*)::int from public.app_migrations where name='0029_family_delegates'),1,
  '0029 registered');
select ok((select relrowsecurity and relforcerowsecurity
             from pg_class where oid='public.subject_delegates'::regclass),
  'subject_delegates has forced RLS');
select is((select count(*)::int from pg_policies
            where schemaname='public' and tablename='subject_delegates'),1,
  'subject_delegates has exactly one policy (select)');
select has_function('public','my_subjects','my_subjects exists');
select has_function('public','delegate_invite',array['uuid','text','jsonb'],'delegate_invite exists');
select has_function('public','delegate_accept',array['uuid'],'delegate_accept exists');
select has_function('public','delegate_revoke',array['uuid'],'delegate_revoke exists');
select has_function('public','subject_view_log',array['uuid'],'subject_view_log exists');
select is(has_function_privilege('anon','public.delegate_invite(uuid,text,jsonb)','execute'),false,
  'anon cannot invite a delegate');
select is(has_function_privilege('authenticated','public.delegate_invite(uuid,text,jsonb)','execute'),true,
  'an authenticated user can invite a delegate');
select is((select proconfig from pg_proc where oid='public.can_access_subject(uuid)'::regprocedure),
  array['search_path=public'],
  'can_access_subject pins its search path');

-- ---------------------------------------------------------------------------
-- 2. L'estraneo puro: zero deleghe, nessun invito
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a4444444-4444-4444-8444-444444444429","role":"authenticated"}',true);
select is((select count(*)::int from public.subject_delegates),0,
  'a stranger reads zero delegate rows');
select throws_ok(
  $$select public.delegate_invite('a1111111-1111-4111-8111-111111111129','dario29@example.com')$$,
  '42501',null,'a stranger cannot invite on someone else''s subject');

-- ---------------------------------------------------------------------------
-- 3. Alice invita Bob
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111129","role":"authenticated"}',true);

select throws_ok(
  $$select public.delegate_invite('a1111111-1111-4111-8111-111111111129','non-un-indirizzo')$$,
  '22023',null,'a malformed address is refused');

insert into t29(k,j) select 'invite',
  public.delegate_invite('a1111111-1111-4111-8111-111111111129','bob29@example.com');

select is((select j->>'status' from t29 where k='invite'),'invited',
  'the invitation is created in state invited');
select is((select count(*)::int from public.subject_delegates
            where subject_id='a1111111-1111-4111-8111-111111111129'),1,
  'the subject sees her own delegate row');

-- ---------------------------------------------------------------------------
-- 4. Prima dell'accettazione l'invito non apre nulla
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a2222222-2222-4222-8222-222222222229","role":"authenticated"}',true);
select is(public.can_access_subject('a1111111-1111-4111-8111-111111111129'),false,
  'an invitation that is not accepted grants nothing');
select is((select count(*)::int from public.documents
            where subject_id='a1111111-1111-4111-8111-111111111129'),0,
  'the invited user reads zero documents before accepting');

-- Carlo non puo' accettare l'invito di Bob
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a3333333-3333-4333-8333-333333333329","role":"authenticated"}',true);
select throws_ok(
  format($$select public.delegate_accept(%L::uuid)$$, (select j->>'id' from t29 where k='invite')),
  '42501',null,'only the invited address can accept');

-- ---------------------------------------------------------------------------
-- 5. Bob accetta e legge i dati di Alice
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a2222222-2222-4222-8222-222222222229","role":"authenticated"}',true);

insert into t29(k,j) select 'accept',
  public.delegate_accept((select j->>'id' from t29 where k='invite')::uuid);

select is((select j->>'status' from t29 where k='accept'),'active',
  'the invitation becomes active');
select is(public.can_access_subject('a1111111-1111-4111-8111-111111111129'),true,
  'the active delegate can access the subject');
select is((select count(*)::int from public.documents
            where subject_id='a1111111-1111-4111-8111-111111111129'),1,
  'the active delegate reads the subject documents');
select is((select count(*)::int from public.profiles
            where id='a1111111-1111-4111-8111-111111111129'),1,
  'the active delegate reads the subject profile');
select is((select count(*)::int from public.my_subjects()),2,
  'my_subjects returns himself and the subject');

-- nessuna scrittura diretta, nemmeno per il delegato
select throws_ok(
  $$insert into public.subject_delegates(subject_id,invited_email,created_by)
    values ('a1111111-1111-4111-8111-111111111129','x29@example.com','a2222222-2222-4222-8222-222222222229')$$,
  '42501',null,'a delegate cannot insert a delegate row');
select throws_ok(
  $$update public.subject_delegates set status='active' where true$$,
  '42501',null,'a delegate cannot update a delegate row');

-- audit dell'apertura: una sola riga, e nulla sul proprio soggetto
select is(public.subject_view_log('a1111111-1111-4111-8111-111111111129'),true,
  'opening someone else''s profile is logged');
select is(public.subject_view_log('a2222222-2222-4222-8222-222222222229'),false,
  'opening one''s own profile is not logged');

-- ---------------------------------------------------------------------------
-- 6. Carlo resta fuori
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a3333333-3333-4333-8333-333333333329","role":"authenticated"}',true);
select is((select count(*)::int from public.documents
            where subject_id='a1111111-1111-4111-8111-111111111129'),0,
  'an outsider reads zero documents of the subject');
select is((select count(*)::int from public.profiles
            where id='a1111111-1111-4111-8111-111111111129'),0,
  'an outsider reads zero profiles of the subject');

-- ---------------------------------------------------------------------------
-- 7. Conteggio dell'audit (contesto interno)
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
select is((select count(*)::int from public.audit_log where action='subject.viewed')
          - (select n from t29 where k='audit_viewed'),1,
  'subject.viewed is written exactly once');

-- ---------------------------------------------------------------------------
-- 8. Un secondo invito allo stesso indirizzo e' rifiutato
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111129","role":"authenticated"}',true);
select throws_ok(
  $$select public.delegate_invite('a1111111-1111-4111-8111-111111111129','bob29@example.com')$$,
  'P0001','already_invited','the same address is not invited twice');
select throws_ok(
  $$select public.delegate_invite('a1111111-1111-4111-8111-111111111129','alice29@example.com')$$,
  '22023',null,'the subject cannot invite herself');

-- ---------------------------------------------------------------------------
-- 9. Revoca: Bob torna a zero
-- ---------------------------------------------------------------------------
insert into t29(k,j) select 'revoke',
  public.delegate_revoke((select j->>'id' from t29 where k='invite')::uuid);
select is((select (j->>'changed')::boolean from t29 where k='revoke'),true,
  'the delegation is revoked');
insert into t29(k,j) select 'revoke2',
  public.delegate_revoke((select j->>'id' from t29 where k='invite')::uuid);
select is((select (j->>'changed')::boolean from t29 where k='revoke2'),false,
  'revoking twice changes nothing');

reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a2222222-2222-4222-8222-222222222229","role":"authenticated"}',true);
select is((select count(*)::int from public.documents
            where subject_id='a1111111-1111-4111-8111-111111111129'),0,
  'after the revocation the delegate reads zero documents');
select is((select count(*)::int from public.profiles
            where id='a1111111-1111-4111-8111-111111111129'),0,
  'after the revocation the delegate reads zero profiles');
select is((select count(*)::int from public.my_subjects()),1,
  'after the revocation my_subjects returns only himself');

-- ---------------------------------------------------------------------------
-- 10. Massimo cinque deleghe vive per soggetto
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111129","role":"authenticated"}',true);

-- dentro un do $$ … $$ perche' un select nudo stamperebbe righe non TAP
do $$
declare v_mail text;
begin
  foreach v_mail in array array['d29a@example.com','d29b@example.com','d29c@example.com',
                               'd29d@example.com','d29e@example.com'] loop
    perform public.delegate_invite('a1111111-1111-4111-8111-111111111129', v_mail);
  end loop;
end $$;

select is((select count(*)::int from public.subject_delegates
            where subject_id='a1111111-1111-4111-8111-111111111129'
              and status='invited'),5,
  'five live delegations are allowed');
select throws_ok(
  $$select public.delegate_invite('a1111111-1111-4111-8111-111111111129','d29f@example.com')$$,
  'P0001','too_many_delegates','the sixth delegation is refused');

-- ---------------------------------------------------------------------------
-- 11. Il ruolo owner vale solo su un profilo gestito
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
select throws_ok(
  $$insert into public.subject_delegates(subject_id,user_id,invited_email,role,status,accepted_at,created_by)
    values ('a1111111-1111-4111-8111-111111111129','a3333333-3333-4333-8333-333333333329',
            'carlo29@example.com','owner','active',now(),'a3333333-3333-4333-8333-333333333329')$$,
  '23514','owner_requires_managed_profile',
  'the owner role requires profiles.managed_by');

-- ---------------------------------------------------------------------------
-- 12. Dopo una revoca la stessa persona puo' essere invitata di nuovo
--
--     Prima si liberano i cinque posti occupati dal punto 10, altrimenti il
--     nuovo invito cadrebbe su too_many_delegates e non proverebbe nulla.
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111129","role":"authenticated"}',true);

do $$
declare v_id uuid;
begin
  for v_id in select id from public.subject_delegates
               where subject_id='a1111111-1111-4111-8111-111111111129'
                 and status='invited' loop
    perform public.delegate_revoke(v_id);
  end loop;
end $$;

insert into t29(k,j) select 'invite2',
  public.delegate_invite('a1111111-1111-4111-8111-111111111129','bob29@example.com');
select is((select j->>'status' from t29 where k='invite2'),'invited',
  'after a revocation the same address can be invited again');

reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a2222222-2222-4222-8222-222222222229","role":"authenticated"}',true);
select is((select count(*)::int from public.my_pending_invitations()),1,
  'the invited user sees exactly one pending invitation');
select is((select subject_id from public.my_pending_invitations()),
  'a1111111-1111-4111-8111-111111111129'::uuid,
  'the pending invitation points to the subject');
select is((select subject_name from public.my_pending_invitations()),'Alice',
  'the pending invitation carries the name of the subject');

insert into t29(k,j) select 'accept2',
  public.delegate_accept((select j->>'id' from t29 where k='invite2')::uuid);
select is((select j->>'status' from t29 where k='accept2'),'active',
  'the second invitation is accepted and becomes active');
select is((select count(*)::int from public.my_pending_invitations()),0,
  'once accepted nothing stays pending');
select is(public.can_access_subject('a1111111-1111-4111-8111-111111111129'),true,
  'the delegate reads the subject again after being invited back');

reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a3333333-3333-4333-8333-333333333329","role":"authenticated"}',true);
select is((select count(*)::int from public.my_pending_invitations()),0,
  'a user with no invitation sees nothing pending');

-- ---------------------------------------------------------------------------
-- 13. Profili gestiti: solo il servizio li registra, e non oltre il limite
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111129","role":"authenticated"}',true);
select throws_ok(
  $$select public.family_member_register('c1111111-1111-4111-8111-111111111129',
      'a1111111-1111-4111-8111-111111111129','Mia','guardian-1.0')$$,
  '42501',null,'an authenticated user cannot register a managed profile');

reset role; select set_config('request.jwt.claims','',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);

insert into t29(k,j) select 'reg1', public.family_member_register(
  'c1111111-1111-4111-8111-111111111129','a1111111-1111-4111-8111-111111111129',
  'Mia','guardian-1.0','2015-04-02','female','figlia');

select is((select managed_by from public.profiles where id='c1111111-1111-4111-8111-111111111129'),
  'a1111111-1111-4111-8111-111111111129'::uuid,
  'the managed profile points to its owner');
select is((select full_name from public.profiles where id='c1111111-1111-4111-8111-111111111129'),'Mia',
  'the managed profile carries the name given at registration');
select is((select onboarded_at is not null from public.profiles
            where id='c1111111-1111-4111-8111-111111111129'),true,
  'a managed profile is onboarded from the start');
select is((select language from public.profiles where id='c1111111-1111-4111-8111-111111111129'),
          (select language from public.profiles where id='a1111111-1111-4111-8111-111111111129'),
  'language is copied from the owner');
select is((select count(*)::int from public.subject_delegates
            where subject_id='c1111111-1111-4111-8111-111111111129'
              and role='owner' and status='active'),1,
  'the owner delegation is created active');
select is((select count(*)::int from public.consents
            where user_id='c1111111-1111-4111-8111-111111111129'),2,
  'the two clinical consents are copied on the managed profile');
select is((select (j->>'consents_copied')::int from t29 where k='reg1'),2,
  'the call reports the two copied consents');
select is((select count(*)::int from public.consents
            where user_id='c1111111-1111-4111-8111-111111111129' and type='marketing'),0,
  'marketing is not copied');
select is(public.family_managed_limit(),3,
  'the managed limit comes from platform_settings');

do $$
begin
  perform public.family_member_register('c2222222-2222-4222-8222-222222222229',
    'a1111111-1111-4111-8111-111111111129','Nina','guardian-1.0',null,null,'figlia');
  perform public.family_member_register('c3333333-3333-4333-8333-333333333329',
    'a1111111-1111-4111-8111-111111111129','Oscar','guardian-1.0',null,null,'padre');
end $$;

select is((select count(*)::int from public.profiles
            where managed_by='a1111111-1111-4111-8111-111111111129'
              and deleted_at is null),3,
  'three managed profiles are allowed');
select throws_ok(
  $$select public.family_member_register('c4444444-4444-4444-8444-444444444429',
      'a1111111-1111-4111-8111-111111111129','Piero','guardian-1.0')$$,
  'P0001','managed_limit','the fourth managed profile is refused');

-- ---------------------------------------------------------------------------
-- 14. La delega owner non si revoca
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111129","role":"authenticated"}',true);

select is(public.can_access_subject('c1111111-1111-4111-8111-111111111129'),true,
  'the owner reads the managed subject');
select throws_ok(
  $$select public.delegate_revoke((select id from public.subject_delegates
      where subject_id='c1111111-1111-4111-8111-111111111129' and role='owner'))$$,
  'P0001','owner_not_revocable','an owner delegation cannot be revoked');

-- ---------------------------------------------------------------------------
-- 15. L'anagrafica di un profilo gestito la cambia solo il suo owner
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a3333333-3333-4333-8333-333333333329","role":"authenticated"}',true);
select throws_ok(
  $$select public.family_member_update('c1111111-1111-4111-8111-111111111129','Nome cambiato')$$,
  '42501',null,'a non owner cannot update a managed profile');

reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111129","role":"authenticated"}',true);
insert into t29(k,j) select 'update', public.family_member_update(
  'c1111111-1111-4111-8111-111111111129','Mia Rossi',null,null,'figlia maggiore');
select is((select full_name from public.profiles where id='c1111111-1111-4111-8111-111111111129'),
  'Mia Rossi','the owner updates the name of the managed profile');
select is((select relationship from public.subject_delegates
            where subject_id='c1111111-1111-4111-8111-111111111129' and role='owner'),
  'figlia maggiore','the relationship of the owner delegation is updated');

-- ---------------------------------------------------------------------------
-- 16. family_member_remove spegne tutto cio' che resta aperto
--
--     Fixture come postgres: un link di condivisione e una scheda di
--     emergenza del profilo gestito, creati prima della rimozione.
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
insert into public.share_links(id,subject_id,created_by,code,pin_hash,expires_at)
values ('ac111111-1111-4111-8111-111111111129','c1111111-1111-4111-8111-111111111129',
  'a1111111-1111-4111-8111-111111111129','981279','$2a$10$abcdefghijklmnopqrstuv',
  now()+interval '7 days');
insert into public.emergency_cards(subject_id,blood_group)
values ('c1111111-1111-4111-8111-111111111129','O+')
on conflict (subject_id) do nothing;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111129","role":"authenticated"}',true);
insert into t29(k,j) select 'remove',
  public.family_member_remove('c1111111-1111-4111-8111-111111111129');
select is(public.can_access_subject('c1111111-1111-4111-8111-111111111129'),false,
  'after the removal not even the owner reads the managed subject');

reset role; select set_config('request.jwt.claims','',true);
select is((select deleted_at is not null from public.profiles
            where id='c1111111-1111-4111-8111-111111111129'),true,
  'the managed profile is soft deleted');
select is((select count(*)::int from public.subject_delegates
            where subject_id='c1111111-1111-4111-8111-111111111129'
              and status<>'revoked'),0,
  'every delegation of the subject is revoked, the owner one included');
select is((select count(*)::int from public.share_links
            where subject_id='c1111111-1111-4111-8111-111111111129'
              and revoked_at is null),0,
  'the active share link of the managed subject is revoked');
select is((select (j->>'links_revoked')::int from t29 where k='remove'),1,
  'the call reports the revoked link');
select is((select (j->>'emergency_card_removed')::int from t29 where k='remove'),1,
  'the emergency card of the managed subject is removed');
select is((select count(*)::int from public.profiles
            where managed_by='a1111111-1111-4111-8111-111111111129'
              and deleted_at is null),2,
  'the removal frees one of the three managed slots');

-- ---------------------------------------------------------------------------
-- 17. Il corpo interno della rimozione non e' una porta aperta
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
select has_function('public','m24_family_member_remove_internal',array['uuid','uuid'],
  'm24_family_member_remove_internal exists');
select is(has_function_privilege('authenticated',
  'public.m24_family_member_remove_internal(uuid,uuid)','execute'),false,
  'an authenticated user cannot call the internal removal');

-- ---------------------------------------------------------------------------
-- 18. family_member_register rifiuta chi non e' un utente ombra nuovo
--
--     Due casi: il soggetto coincide con l'owner, e il soggetto e' gia' un
--     profilo gestito (Nina, registrata al punto 13). Il secondo e' quello
--     che conta: senza il controllo, chiunque abbia il service_role potrebbe
--     trasformare un account vero in un profilo che amministra.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select throws_ok(
  $$select public.family_member_register('a1111111-1111-4111-8111-111111111129',
      'a1111111-1111-4111-8111-111111111129','Alice','guardian-1.0')$$,
  '22023',null,'a subject cannot be registered as a managed profile of itself');
select throws_ok(
  $$select public.family_member_register('c2222222-2222-4222-8222-222222222229',
      'a2222222-2222-4222-8222-222222222229','Nina','guardian-1.0')$$,
  '22023',null,'an already managed profile cannot be registered again');

-- ---------------------------------------------------------------------------
-- 19. Alice chiude il proprio account: si porta dietro i profili gestiti
--
--     Fixture come postgres: un link di condivisione ancora valido di Nina,
--     profilo gestito e vivo. Alla chiusura deve sparire insieme al resto.
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
insert into public.share_links(id,subject_id,created_by,code,pin_hash,expires_at)
values ('ac222222-2222-4222-8222-222222222229','c2222222-2222-4222-8222-222222222229',
  'a1111111-1111-4111-8111-111111111129','981280','$2a$10$abcdefghijklmnopqrstuv',
  now()+interval '7 days');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1111111-1111-4111-8111-111111111129","role":"authenticated"}',true);
select lives_ok($$select public.soft_delete_account()$$,
  'the owner closes her own account');

reset role; select set_config('request.jwt.claims','',true);
select is((select count(*)::int from public.profiles
            where managed_by='a1111111-1111-4111-8111-111111111129'
              and deleted_at is null),0,
  'closing the account soft deletes every managed profile');
select is((select count(*)::int from public.subject_delegates
            where (subject_id='a1111111-1111-4111-8111-111111111129'
                or user_id='a1111111-1111-4111-8111-111111111129')
              and status<>'revoked'),0,
  'a closed account is neither a subject nor a caregiver of anyone');
select is((select count(*)::int from public.share_links
            where subject_id='c2222222-2222-4222-8222-222222222229'
              and revoked_at is null),0,
  'the share link of a managed profile is revoked with the account');

-- ---------------------------------------------------------------------------
-- 20. account_close revoca anche le deleghe in cui il soggetto e' il delegato
--
--     Carlo assiste Dario. Quando il servizio chiude l'account di Carlo, la
--     delega deve cadere: Carlo compare come user_id, non come subject_id.
-- ---------------------------------------------------------------------------
insert into public.subject_delegates(subject_id,user_id,invited_email,role,status,
  accepted_at,created_by)
values ('a4444444-4444-4444-8444-444444444429','a3333333-3333-4333-8333-333333333329',
        'carlo29@example.com','caregiver','active',now(),
        'a4444444-4444-4444-8444-444444444429');

select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into t29(k,j) select 'close_carlo',
  public.account_close('a3333333-3333-4333-8333-333333333329');
select is((select (j->>'delegates_revoked')::int from t29 where k='close_carlo'),1,
  'account_close revokes the delegation where the subject is the delegate');

-- ---------------------------------------------------------------------------
-- 21. La purga di un profilo gestito svuota anche le sue deleghe
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
insert into t29(k,j) select 'purge_nina',
  public.purge_subject_data('c2222222-2222-4222-8222-222222222229');
select is((select count(*)::int from public.subject_delegates
            where subject_id='c2222222-2222-4222-8222-222222222229'
               or user_id='c2222222-2222-4222-8222-222222222229'),0,
  'purge_subject_data empties subject_delegates for the purged subject');

select * from finish();
rollback;