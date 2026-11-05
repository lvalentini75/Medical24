-- Medical 24 - pgTAP 0023 Medico v1: domande al medico e scheda di emergenza.
-- Dev only; rollback finale.
-- Pattern CONTEXT_CORE §6: fixture come postgres, poi set local role + claims JWT.
--
-- Il "contesto interno" delle funzioni riservate (questions_for_link,
-- question_answer_via_link) e' postgres con il claim role = service_role:
-- e' cosi' che la Edge Function dossier-open le chiama.
begin;
create extension if not exists pgtap with schema extensions;
select plan(39);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('b1111111-1111-4111-8111-111111111141','00000000-0000-0000-0000-000000000000','authenticated','authenticated','alice23@example.com','',now(),'{}','{"full_name":"Alice"}',now(),now()),
('b2222222-2222-4222-8222-222222222241','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bob23@example.com','',now(),'{}','{"full_name":"Bob"}',now(),now())
on conflict(id) do nothing;

update public.profiles set full_name='Alice Demo', language='it'
 where id='b1111111-1111-4111-8111-111111111141';
update public.profiles set full_name='Bob Demo', language='it'
 where id='b2222222-2222-4222-8222-222222222241';

create temp table t23(k text primary key, u uuid, s text, j jsonb);
grant all on t23 to public;

-- un link attivo per Alice e uno per Bob (serve per il caso del link estraneo)
with l as (
  insert into public.share_links(subject_id, created_by, code, pin_hash)
  values ('b1111111-1111-4111-8111-111111111141','b1111111-1111-4111-8111-111111111141',
          '314159', crypt('4711', gen_salt('bf')))
  returning id)
insert into t23(k,u) select 'link_alice', id from l;
with l as (
  insert into public.share_links(subject_id, created_by, code, pin_hash)
  values ('b2222222-2222-4222-8222-222222222241','b2222222-2222-4222-8222-222222222241',
          '271828', crypt('0000', gen_salt('bf')))
  returning id)
insert into t23(k,u) select 'link_bob', id from l;

-- ---------------------------------------------------------------------------
-- Firme e registro
-- ---------------------------------------------------------------------------
select has_function('public','question_create',array['uuid','text','text','uuid','text'],'question_create exists');
select has_function('public','question_answer_via_link',array['uuid','uuid','text'],'question_answer_via_link exists');
select has_function('public','emergency_card_upsert',array['uuid','jsonb'],'emergency_card_upsert exists');
select has_function('public','emergency_card_regenerate_token',array['uuid'],'emergency_card_regenerate_token exists');
select has_function('public','emergency_card_public',array['text'],'emergency_card_public exists');
select is((select count(*)::int from public.app_migrations where name='0023_doctor_v1_questions_ice'),1,'0023 registered');

-- ---------------------------------------------------------------------------
-- Alice: ciclo di vita di una domanda
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1111111-1111-4111-8111-111111111141","role":"authenticated"}',true);

insert into t23(k,u) select 'q1', public.question_create(
  'b1111111-1111-4111-8111-111111111141','Colesterolo','Il valore LDL e'' alto da due anni.',
  (select u from t23 where k='link_alice'), 'dr@example.org');
select is((select status::text from public.questions where id=(select u from t23 where k='q1')),
  'draft','a new question is born draft');

select public.question_update((select u from t23 where k='q1'),'Colesterolo LDL','Il valore LDL e'' alto da tre anni.');
select is((select title from public.questions where id=(select u from t23 where k='q1')),
  'Colesterolo LDL','a draft can be updated');

select public.question_send((select u from t23 where k='q1'));
select is((select status::text from public.questions where id=(select u from t23 where k='q1')),
  'sent','send moves draft to sent');

select throws_ok(
  format($f$select public.question_update(%L::uuid,'Altro titolo','Altro testo')$f$,
    (select u from t23 where k='q1')),
  'P0001',null,'a sent question cannot be updated');

select public.question_record_answer((select u from t23 where k='q1'),'Ne parliamo alla prossima visita.');
select is((select status::text from public.questions where id=(select u from t23 where k='q1')),
  'answered','record_answer moves sent to answered');
select is((select answered_via::text from public.questions where id=(select u from t23 where k='q1')),
  'app','an answer recorded by the patient has channel app');

select public.question_close((select u from t23 where k='q1'));
select is((select status::text from public.questions where id=(select u from t23 where k='q1')),
  'closed','close moves the question to closed');
select is((select answer from public.questions where id=(select u from t23 where k='q1')),
  'Ne parliamo alla prossima visita.','closing keeps the answer');

-- link di un altro soggetto
select throws_ok(
  format($f$select public.question_create('b1111111-1111-4111-8111-111111111141','Tiroide','Domanda sulla tiroide.',%L::uuid)$f$,
    (select u from t23 where k='link_bob')),
  '22023',null,'a link of another subject is refused');

-- seconda domanda, inviata: resta sent per la pagina pubblica
insert into t23(k,u) select 'q2', public.question_create(
  'b1111111-1111-4111-8111-111111111141','Tiroide','Devo ripetere il TSH?',
  (select u from t23 where k='link_alice'), null);
select public.question_send((select u from t23 where k='q2'));

select throws_ok(format($f$select public.question_delete(%L::uuid)$f$,(select u from t23 where k='q2')),
  'P0001',null,'a sent question cannot be deleted');

-- funzioni riservate: authenticated non le esegue
select throws_ok(format($f$select public.questions_for_link(%L::uuid)$f$,(select u from t23 where k='link_alice')),
  '42501',null,'authenticated cannot call questions_for_link');
select throws_ok(
  format($f$select public.question_answer_via_link(%L::uuid,%L::uuid,'Risposta')$f$,
    (select u from t23 where k='link_alice'),(select u from t23 where k='q2')),
  '42501',null,'authenticated cannot call question_answer_via_link');

-- ---------------------------------------------------------------------------
-- Bob: estraneo alle domande di Alice, e il tetto giornaliero sul suo soggetto
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"b2222222-2222-4222-8222-222222222241","role":"authenticated"}',true);
select throws_ok(
  format($f$select public.question_update(%L::uuid,'Titolo di Bob','Testo di Bob')$f$,
    (select u from t23 where k='q2')),
  '42501',null,'bob cannot touch a question of alice');

-- Venti domande una per volta: ogni chiamata deve vedere le precedenti.
do $do$
declare g int;
begin
  for g in 1..20 loop
    perform public.question_create('b2222222-2222-4222-8222-222222222241',
      'Domanda ' || g::text, 'Testo della domanda.');
  end loop;
end
$do$;
select throws_ok(
  $$select public.question_create('b2222222-2222-4222-8222-222222222241','Ventunesima','Testo della domanda.')$$,
  'P0001',null,'the twenty-first question of the day is refused');

-- ---------------------------------------------------------------------------
-- Contesto interno (service_role): la pagina pubblica del dossier
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);

insert into t23(k,j) select 'link_list', public.questions_for_link((select u from t23 where k='link_alice'));
select is((select jsonb_array_length(j) from t23 where k='link_list'),1,'only the sent question is exposed on the link');
select is((select (j->0->>'id')::uuid from t23 where k='link_list'),(select u from t23 where k='q2'),'the exposed question is the sent one');
select ok((select not (j->0 ? 'doctor_email') and not (j->0 ? 'subject_id') from t23 where k='link_list'),
  'the link payload carries no subject_id and no doctor_email');

select public.question_answer_via_link((select u from t23 where k='link_alice'),(select u from t23 where k='q2'),
  'Ripeta il TSH tra tre mesi.');
select is((select status::text from public.questions where id=(select u from t23 where k='q2')),
  'answered','the doctor answers from the link');
select is((select answered_via::text from public.questions where id=(select u from t23 where k='q2')),
  'link','an answer from the link has channel link');

-- ---------------------------------------------------------------------------
-- Scheda di emergenza: Alice la scrive
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1111111-1111-4111-8111-111111111141","role":"authenticated"}',true);

select throws_ok(
  $$select public.emergency_card_upsert('b1111111-1111-4111-8111-111111111141','{"blood_group":"A+","weight":80}'::jsonb)$$,
  '22023',null,'an unknown key is refused');
select throws_ok(
  $$select public.emergency_card_upsert('b1111111-1111-4111-8111-111111111141','{"blood_group":"XY+"}'::jsonb)$$,
  '23514',null,'an invalid blood group is refused');

insert into t23(k,j) select 'card1', public.emergency_card_upsert(
  'b1111111-1111-4111-8111-111111111141',
  '{"blood_group":"A+","allergies":["  penicillina ","","lattice"],
    "notes":"Porta sempre l''inalatore.",
    "contacts":[{"name":"Marco","phone":"+39 333 1234567","relation":"marito"}]}'::jsonb);
select ok((select (j->>'public_token') ~ '^[0-9a-f]{32}$' from t23 where k='card1'),
  'the card is created with a 32 hex public_token');
select is((select allergies from public.emergency_cards where subject_id='b1111111-1111-4111-8111-111111111141'),
  array['penicillina','lattice'],'text arrays arrive trimmed and without empties');

-- upsert parziale: non cancella i campi assenti
select public.emergency_card_upsert('b1111111-1111-4111-8111-111111111141',
  '{"medications":["Metformina 500"]}'::jsonb);
select is((select blood_group from public.emergency_cards where subject_id='b1111111-1111-4111-8111-111111111141'),
  'A+','a partial upsert keeps the blood group');
select is((select allergies from public.emergency_cards where subject_id='b1111111-1111-4111-8111-111111111141'),
  array['penicillina','lattice'],'a partial upsert keeps the allergies');
select is((select medications from public.emergency_cards where subject_id='b1111111-1111-4111-8111-111111111141'),
  array['Metformina 500'],'a partial upsert writes the key it carries');

insert into t23(k,s) select 'token2', public.emergency_card_regenerate_token('b1111111-1111-4111-8111-111111111141');
select isnt((select s from t23 where k='token2'),(select j->>'public_token' from t23 where k='card1'),
  'regenerate_token replaces the public token');

-- ---------------------------------------------------------------------------
-- Pagina pubblica: chi soccorre non ha un account
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role anon;

insert into t23(k,j) select 'pub1', public.emergency_card_public((select s from t23 where k='token2'));
select is((select j->>'blood_group' from t23 where k='pub1'),'A+','anon reads the blood group with the right token');
select ok((select not (j ? 'notes') from t23 where k='pub1'),'notes stay private by default');
select is((select j->>'display_name' from t23 where k='pub1'),'Alice Demo','the public page carries only the display name');
select ok(public.emergency_card_public(repeat('0',32)) is null,'an unknown token returns null');

reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1111111-1111-4111-8111-111111111141","role":"authenticated"}',true);
select public.emergency_card_upsert('b1111111-1111-4111-8111-111111111141',
  '{"fields_public":{"notes":true}}'::jsonb);

reset role; select set_config('request.jwt.claims','',true);
set local role anon;
insert into t23(k,j) select 'pub2', public.emergency_card_public((select s from t23 where k='token2'));
select is((select j->>'notes' from t23 where k='pub2'),'Porta sempre l''inalatore.',
  'with fields_public.notes true the note is shown');
reset role;

select is((select count(*)::int from public.audit_log
            where action='emergency_card.viewed'
              and subject_id='b1111111-1111-4111-8111-111111111141'
              and actor_id is null),2,'audit: every view of the public page is logged with a null actor');

select * from finish();
rollback;
