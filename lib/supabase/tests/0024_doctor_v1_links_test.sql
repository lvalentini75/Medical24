-- Medical 24 - pgTAP 0024 Medico v1: link di condivisione del dossier.
-- Dev only; rollback finale.
-- Pattern CONTEXT_CORE §6: fixture come postgres, poi set local role + claims JWT.
--
-- Il "contesto interno" delle funzioni riservate (share_link_open,
-- share_open_rate_check) e' postgres con il claim role = service_role: e' cosi'
-- che la Edge Function dossier-open le chiama.
begin;
create extension if not exists pgtap with schema extensions;
select plan(37);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('c1111111-1111-4111-8111-111111111151','00000000-0000-0000-0000-000000000000','authenticated','authenticated','alice24@example.com','',now(),'{}','{"full_name":"Alice"}',now(),now()),
('c2222222-2222-4222-8222-222222222251','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bob24@example.com','',now(),'{}','{"full_name":"Bob"}',now(),now())
on conflict(id) do nothing;

update public.profiles set full_name='Alice Demo', gender='female',
  birth_date=current_date - interval '50 years', language='it'
 where id='c1111111-1111-4111-8111-111111111151';
update public.profiles set full_name='Bob Demo', gender='male',
  birth_date=current_date - interval '45 years', language='it'
 where id='c2222222-2222-4222-8222-222222222251';

-- un organo in attenzione: cosi' il dossier congelato non e' vuoto
insert into public.organ_states(subject_id,organ_id,state,confidence,inputs,rule_version,stress_score,computed_at)
values('c1111111-1111-4111-8111-111111111151','metabolism','attention',0.80,'[]'::jsonb,'organ_state-0.3',0.80,now());

create temp table t24(k text primary key, u uuid, s text, j jsonb);
grant all on t24 to public;

-- ---------------------------------------------------------------------------
-- Firme e registro
-- ---------------------------------------------------------------------------
select has_function('public','share_link_create',array['uuid','text','jsonb','interval','integer'],'share_link_create exists');
select has_function('public','share_link_revoke',array['uuid'],'share_link_revoke exists');
select has_function('public','share_links_for_subject',array['uuid'],'share_links_for_subject exists');
select has_function('public','share_link_open',array['text','text','text','text'],'share_link_open exists');
select has_function('public','share_open_rate_check',array['text'],'share_open_rate_check exists');
select is((select count(*)::int from public.app_migrations where name='0024_doctor_v1_links'),1,'0024 registered');

-- ---------------------------------------------------------------------------
-- Alice crea il suo link
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"c1111111-1111-4111-8111-111111111151","role":"authenticated"}',true);

insert into t24(k,j) select 'main', public.share_link_create('c1111111-1111-4111-8111-111111111151','4719');
insert into t24(k,u,s) select 'main_id', (j->>'id')::uuid, j->>'code' from t24 where k='main';

select ok((select s ~ '^[0-9]{6}$' from t24 where k='main_id'),'the link carries a six digit code');
select ok((select pin_hash ~ '^\$2[aby]?\$' from public.share_links
            where id=(select u from t24 where k='main_id')),
  'the pin is stored only as a bcrypt hash');
select is((select count(*)::int from public.dossier_snapshots
            where share_link_id=(select u from t24 where k='main_id')),1,
  'creating a link freezes one dossier snapshot bound to it');
select is((select count(*)::int from public.audit_log
            where action='share_link.created'
              and target_id=(select u from t24 where k='main_id')),1,
  'audit: share_link.created is written once');

select throws_ok(
  $$select public.share_link_create('c1111111-1111-4111-8111-111111111151','1111')$$,
  '22023',null,'a pin made of equal digits is refused');
select throws_ok(
  $$select public.share_link_create('c1111111-1111-4111-8111-111111111151','1234')$$,
  '22023',null,'a pin in sequence is refused');

-- ---------------------------------------------------------------------------
-- Il tetto dei cinque link attivi
-- ---------------------------------------------------------------------------
reset role;
insert into public.share_links(subject_id,created_by,code,pin_hash) values
('c1111111-1111-4111-8111-111111111151','c1111111-1111-4111-8111-111111111151','600001',crypt('4719',gen_salt('bf'))),
('c1111111-1111-4111-8111-111111111151','c1111111-1111-4111-8111-111111111151','600002',crypt('4719',gen_salt('bf'))),
('c1111111-1111-4111-8111-111111111151','c1111111-1111-4111-8111-111111111151','600003',crypt('4719',gen_salt('bf'))),
('c1111111-1111-4111-8111-111111111151','c1111111-1111-4111-8111-111111111151','600004',crypt('4719',gen_salt('bf')));
insert into t24(k,u,s) select 'revoked_link', id, code from public.share_links where code='600001';

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"c1111111-1111-4111-8111-111111111151","role":"authenticated"}',true);
select throws_ok(
  $$select public.share_link_create('c1111111-1111-4111-8111-111111111151','4719')$$,
  'P0001',null,'the sixth active link is refused');

-- Bob sul soggetto di Alice
select set_config('request.jwt.claims','{"sub":"c2222222-2222-4222-8222-222222222251","role":"authenticated"}',true);
select throws_ok(
  $$select public.share_link_create('c1111111-1111-4111-8111-111111111151','4719')$$,
  '42501',null,'bob cannot create a link on the subject of alice');

-- ---------------------------------------------------------------------------
-- Elenco e revoca
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"c1111111-1111-4111-8111-111111111151","role":"authenticated"}',true);
insert into t24(k,j) select 'list1', public.share_links_for_subject('c1111111-1111-4111-8111-111111111151');
select is((select e->>'status' from t24, jsonb_array_elements(j) as e
            where k='list1' and (e->>'id')::uuid=(select u from t24 where k='main_id')),
  'active','a fresh link is listed as active');
select ok((select not exists (select 1 from jsonb_array_elements(j) as e
                               where e ? 'pin_hash')
             from t24 where k='list1'),
  'the list never carries the pin hash');

select public.share_link_revoke((select u from t24 where k='revoked_link'));
insert into t24(k,j) select 'list2', public.share_links_for_subject('c1111111-1111-4111-8111-111111111151');
select is((select e->>'status' from t24, jsonb_array_elements(j) as e
            where k='list2' and (e->>'id')::uuid=(select u from t24 where k='revoked_link')),
  'revoked','a revoked link is listed as revoked');

-- ---------------------------------------------------------------------------
-- Contesto interno (service_role): l'apertura del link
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);

-- 999999 non puo' essere generato da share_link_create (cifre tutte uguali)
insert into t24(k,j) select 'nf', public.share_link_open('999999','4719');
select is((select j->>'outcome' from t24 where k='nf'),'not_found','an unknown code is not found');
select is((select count(*)::int from public.share_link_opens),0,
  'an unknown code leaves no row in the register');

-- quattro PIN sbagliati di fila
insert into t24(k,j) select 'w1', public.share_link_open((select s from t24 where k='main_id'),'9999');
select is((select (j->>'attempts_left')::int from t24 where k='w1'),4,'first wrong pin leaves four attempts');
insert into t24(k,j) select 'w2', public.share_link_open((select s from t24 where k='main_id'),'9999');
select is((select (j->>'attempts_left')::int from t24 where k='w2'),3,'second wrong pin leaves three attempts');
insert into t24(k,j) select 'w3', public.share_link_open((select s from t24 where k='main_id'),'9999');
select is((select (j->>'attempts_left')::int from t24 where k='w3'),2,'third wrong pin leaves two attempts');
insert into t24(k,j) select 'w4', public.share_link_open((select s from t24 where k='main_id'),'9999');
select is((select (j->>'attempts_left')::int from t24 where k='w4'),1,'fourth wrong pin leaves one attempt');

-- il quinto errore blocca il link
insert into t24(k,j) select 'w5', public.share_link_open((select s from t24 where k='main_id'),'9999');
select is((select j->>'outcome' from t24 where k='w5'),'locked','the fifth wrong pin locks the link');
select ok((select j ? 'locked_until' and j->>'locked_until' is not null from t24 where k='w5'),
  'the locked answer carries locked_until');

-- da bloccato, nemmeno il PIN giusto apre
insert into t24(k,j) select 'lk', public.share_link_open((select s from t24 where k='main_id'),'4719');
select is((select j->>'outcome' from t24 where k='lk'),'locked','while locked even the right pin is refused');

-- sblocco e apertura riuscita
reset role;
update public.share_links set locked_until=null where id=(select u from t24 where k='main_id');
select set_config('request.jwt.claims','{"role":"service_role"}',true);

insert into t24(k,j) select 'ok1', public.share_link_open((select s from t24 where k='main_id'),'4719');
select is((select j->>'outcome' from t24 where k='ok1'),'ok','the right pin opens the link');
select is((select jsonb_typeof(j->'snapshot'->'payload') from t24 where k='ok1'),'object',
  'the open answer carries the frozen dossier payload');
select is((select jsonb_typeof(j->'questions') from t24 where k='ok1'),'array',
  'the open answer carries the questions array');
select is((select opens_count from public.share_links where id=(select u from t24 where k='main_id')),1,
  'a successful open counts one');
select is((select count(*)::int from public.audit_log
            where action='share_link.opened'
              and target_id=(select u from t24 where k='main_id')),1,
  'audit: share_link.opened is written once');

-- ---------------------------------------------------------------------------
-- Esaurito, revocato, scaduto
-- ---------------------------------------------------------------------------
reset role;
insert into public.share_links(subject_id,created_by,code,pin_hash,max_opens) values
('c1111111-1111-4111-8111-111111111151','c1111111-1111-4111-8111-111111111151','600005',crypt('4719',gen_salt('bf')),1);
insert into public.share_links(subject_id,created_by,code,pin_hash,created_at,expires_at) values
('c1111111-1111-4111-8111-111111111151','c1111111-1111-4111-8111-111111111151','600006',crypt('4719',gen_salt('bf')),
 now() - interval '10 days', now() - interval '1 day');
select set_config('request.jwt.claims','{"role":"service_role"}',true);

select public.share_link_open('600005','4719');
insert into t24(k,j) select 'ex', public.share_link_open('600005','4719');
select is((select j->>'outcome' from t24 where k='ex'),'exhausted','a link with max_opens one is exhausted after one open');

insert into t24(k,j) select 'rv', public.share_link_open('600001','4719');
select is((select j->>'outcome' from t24 where k='rv'),'revoked','a revoked link answers revoked');

insert into t24(k,j) select 'xp', public.share_link_open('600006','4719');
select is((select j->>'outcome' from t24 where k='xp'),'expired','an expired link answers expired');

-- ---------------------------------------------------------------------------
-- Freno per indirizzo IP
-- ---------------------------------------------------------------------------
reset role;
insert into public.share_link_opens(share_link_id,outcome,ip_hash)
select (select u from t24 where k='main_id'), 'wrong_pin', 'ip-flood'
from generate_series(1,21);
select set_config('request.jwt.claims','{"role":"service_role"}',true);

select is(public.share_open_rate_check('ip-flood'),false,'more than twenty wrong pins from one ip hash are braked');
select is(public.share_open_rate_check('ip-other'),true,'another ip hash is free to try');

-- ---------------------------------------------------------------------------
-- authenticated non apre i link
-- ---------------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"c1111111-1111-4111-8111-111111111151","role":"authenticated"}',true);
select throws_ok(
  format($f$select public.share_link_open(%L,'4719')$f$,(select s from t24 where k='main_id')),
  '42501',null,'authenticated cannot call share_link_open');

reset role;
select * from finish();
rollback;
