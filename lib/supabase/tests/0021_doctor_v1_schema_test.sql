-- Medical 24 - pgTAP 0021 Medico v1: schema e RLS di share_links, share_link_opens,
-- dossier_snapshots, questions, emergency_cards. Dev only; rollback finale.
-- Pattern CONTEXT_CORE §6: fixture come postgres, poi set local role + claims JWT.
begin;
create extension if not exists pgtap with schema extensions;
select plan(48);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('91111111-1111-4111-8111-111111111121','00000000-0000-0000-0000-000000000000','authenticated','authenticated','alice21@example.com','',now(),'{}','{"full_name":"Alice"}',now(),now()),
('92222222-2222-4222-8222-222222222221','00000000-0000-0000-0000-000000000000','authenticated','authenticated','bob21@example.com','',now(),'{}','{"full_name":"Bob"}',now(),now())
on conflict(id) do nothing;

-- ---------------------------------------------------------------------------
-- Struttura
-- ---------------------------------------------------------------------------
select has_table('public','share_links','share_links exists');
select has_table('public','share_link_opens','share_link_opens exists');
select has_table('public','dossier_snapshots','dossier_snapshots exists');
select has_table('public','questions','questions exists');
select has_table('public','emergency_cards','emergency_cards exists');
select is((select count(*)::int from pg_class c join pg_namespace n on n.oid=c.relnamespace
            where n.nspname='public' and c.relname in ('share_links','share_link_opens','dossier_snapshots','questions','emergency_cards')
              and c.relrowsecurity and c.relforcerowsecurity),5,'RLS enabled and forced on all five');
select is((select count(*)::int from pg_policy where polrelid in ('public.share_links'::regclass,'public.share_link_opens'::regclass,
            'public.dossier_snapshots'::regclass,'public.questions'::regclass,'public.emergency_cards'::regclass) and polcmd='r'),5,'five select policies, nothing else');
select is((select count(*)::int from pg_constraint where conname='share_links_code_active_excl' and contype='x'),1,'exclusion constraint on active codes');
select is((select count(*)::int from public.app_migrations where name='0021_doctor_v1_schema'),1,'0021 registered');

-- ---------------------------------------------------------------------------
-- Fixture come postgres (le funzioni di A2 scriveranno cosi', da security definer)
-- ---------------------------------------------------------------------------
create temp table t_ids(k text primary key, v uuid);
grant all on t_ids to public;
with l as (
  insert into public.share_links(subject_id, created_by, code, pin_hash, scope)
  values ('91111111-1111-4111-8111-111111111121','91111111-1111-4111-8111-111111111121','123456', crypt('4711', gen_salt('bf')), '{"all": true}')
  returning id)
insert into t_ids select 'link_alice', id from l;
with l as (
  insert into public.share_links(subject_id, created_by, code, pin_hash, scope, created_at, expires_at)
  values ('92222222-2222-4222-8222-222222222221','92222222-2222-4222-8222-222222222221','654321', crypt('0000', gen_salt('bf')),
          '{"organs": ["liver"], "from": "2026-01-01", "to": "2026-10-31", "categories": ["lab"]}', now() - interval '20 days', now() - interval '13 days')
  returning id)
insert into t_ids select 'link_bob_expired', id from l;
insert into public.share_link_opens(share_link_id, outcome, ip_hash) values ((select v from t_ids where k='link_alice'), 'wrong_pin', repeat('a',64));
insert into public.share_link_opens(share_link_id, outcome, ip_hash) values ((select v from t_ids where k='link_alice'), 'ok', repeat('a',64));
with s as (
  insert into public.dossier_snapshots(subject_id, share_link_id, payload, rule_versions)
  values ('91111111-1111-4111-8111-111111111121', (select v from t_ids where k='link_alice'), '{"health_status":"ok"}', '{"organ_rules":"1.0"}')
  returning id)
insert into t_ids select 'snap_alice', id from s;
with q as (
  insert into public.questions(subject_id, share_link_id, doctor_email, title, body)
  values ('91111111-1111-4111-8111-111111111121', (select v from t_ids where k='link_alice'), 'dr@example.org', 'Colesterolo', 'Il valore LDL e'' alto da due anni.')
  returning id)
insert into t_ids select 'q_alice', id from q;
insert into public.emergency_cards(subject_id, blood_group, allergies, contacts)
values ('91111111-1111-4111-8111-111111111121', 'A+', array['penicillina'], '[{"name":"Marco","phone":"+39 333 1234567","relation":"marito"}]');

-- PIN: solo hash bcrypt, verificabile con crypt
select ok((select crypt('4711', pin_hash) = pin_hash and crypt('4712', pin_hash) <> pin_hash from public.share_links where id=(select v from t_ids where k='link_alice')),'pin stored as bcrypt hash, verified with crypt');
select throws_ok($$insert into public.share_links(subject_id, created_by, code, pin_hash) values ('91111111-1111-4111-8111-111111111121','91111111-1111-4111-8111-111111111121','111111','4711')$$,'23514',null,'plain pin is refused');
select throws_ok($$insert into public.share_links(subject_id, created_by, code, pin_hash) values ('91111111-1111-4111-8111-111111111121','91111111-1111-4111-8111-111111111121','12345',crypt('1',gen_salt('bf')))$$,'23514',null,'code must be 6 digits');
-- scope
select throws_ok($$insert into public.share_links(subject_id, created_by, code, pin_hash, scope) values ('91111111-1111-4111-8111-111111111121','91111111-1111-4111-8111-111111111121','111111',crypt('1',gen_salt('bf')),'{"foo": 1}')$$,'23514',null,'unknown scope key is refused');
select throws_ok($$insert into public.share_links(subject_id, created_by, code, pin_hash, scope) values ('91111111-1111-4111-8111-111111111121','91111111-1111-4111-8111-111111111121','111111',crypt('1',gen_salt('bf')),'{"all": true, "organs": ["liver"]}')$$,'23514',null,'all plus organs is refused');
select throws_ok($$insert into public.share_links(subject_id, created_by, code, pin_hash, scope) values ('91111111-1111-4111-8111-111111111121','91111111-1111-4111-8111-111111111121','111111',crypt('1',gen_salt('bf')),'{"from": "2026-05-01", "to": "2026-01-01"}')$$,'23514',null,'from after to is refused');
select lives_ok($$insert into public.share_links(subject_id, created_by, code, pin_hash, scope) values ('91111111-1111-4111-8111-111111111121','91111111-1111-4111-8111-111111111121','222222',crypt('1',gen_salt('bf')),'{"categories": ["lab"]}')$$,'scope with categories only is valid');
-- codice: univoco tra link attivi, riutilizzabile dopo la scadenza o la revoca
select throws_ok($$insert into public.share_links(subject_id, created_by, code, pin_hash) values ('92222222-2222-4222-8222-222222222221','92222222-2222-4222-8222-222222222221','123456',crypt('1',gen_salt('bf')))$$,'23P01',null,'same code on two active links is refused');
select lives_ok($$insert into public.share_links(subject_id, created_by, code, pin_hash) values ('91111111-1111-4111-8111-111111111121','91111111-1111-4111-8111-111111111121','654321',crypt('1',gen_salt('bf')))$$,'code of an expired link can be reused');
update public.share_links set revoked_at = now() where code = '222222';
select lives_ok($$insert into public.share_links(subject_id, created_by, code, pin_hash) values ('92222222-2222-4222-8222-222222222221','92222222-2222-4222-8222-222222222221','222222',crypt('1',gen_salt('bf')))$$,'code of a revoked link can be reused');
-- append-only
select throws_ok($$update public.share_link_opens set outcome='ok' where outcome='wrong_pin'$$,'42501',null,'opens: update blocked by trigger');
select throws_ok($$delete from public.share_link_opens$$,'42501',null,'opens: delete blocked by trigger');
select throws_ok($$update public.dossier_snapshots set payload='{}'$$,'42501',null,'snapshots: payload update blocked');
select lives_ok($$update public.dossier_snapshots set pdf_path='subjects/a/dossier/s.pdf' where pdf_path is null$$,'snapshots: pdf_path can be set once');
select throws_ok($$update public.dossier_snapshots set pdf_path='other.pdf'$$,'42501',null,'snapshots: pdf_path cannot change again');
select throws_ok($$delete from public.dossier_snapshots$$,'42501',null,'snapshots: delete blocked');
-- questions
select throws_ok($$update public.questions set status='answered' where id=(select v from t_ids where k='q_alice')$$,'23514',null,'answered without answer is refused');
select lives_ok($$update public.questions set status='answered', answer='Ne parliamo in visita.', answered_at=now(), answered_via='link' where id=(select v from t_ids where k='q_alice')$$,'answered with answer, time and channel');
select lives_ok($$update public.questions set status='closed' where id=(select v from t_ids where k='q_alice')$$,'closed keeps the answer');
select throws_ok($$insert into public.questions(subject_id, doctor_email, title, body) values ('91111111-1111-4111-8111-111111111121','non-email','t','b')$$,'23514',null,'doctor_email format is checked');
-- emergency card
select throws_ok($$update public.emergency_cards set blood_group='XY+' where subject_id='91111111-1111-4111-8111-111111111121'$$,'23514',null,'invalid blood group is refused');
select throws_ok($$update public.emergency_cards set contacts='[{"name":"X"}]' where subject_id='91111111-1111-4111-8111-111111111121'$$,'23514',null,'contact without phone is refused');
select throws_ok($$update public.emergency_cards set fields_public='{"notes":"yes"}' where subject_id='91111111-1111-4111-8111-111111111121'$$,'23514',null,'fields_public must be booleans');
select ok((select public_token ~ '^[0-9a-f]{32}$' from public.emergency_cards where subject_id='91111111-1111-4111-8111-111111111121'),'public_token is 32 hex chars');
-- audit
select is((select count(*)::int from public.audit_log where action='share_link.created' and target_id=(select v from t_ids where k='link_alice') and actor_id='91111111-1111-4111-8111-111111111121'),1,'audit: link created by the patient');
select is((select count(*)::int from public.audit_log where action='share_link.opened' and target_id=(select v from t_ids where k='link_alice') and actor_id is null),1,'audit: only the ok open is logged, actor null');
select is((select count(*)::int from public.audit_log where action='share_link.revoked' and target_table='share_links'),1,'audit: revoke logged');

-- ---------------------------------------------------------------------------
-- Alice: legge il proprio, non scrive
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91111111-1111-4111-8111-111111111121","role":"authenticated"}',true);
select is((select count(*)::int from public.share_links),3,'alice reads her own links');
select is((select count(*)::int from public.share_link_opens),2,'alice reads the opens of her link');
select is((select count(*)::int from public.dossier_snapshots) + (select count(*)::int from public.questions) + (select count(*)::int from public.emergency_cards),3,'alice reads snapshot, question, card');
select throws_ok($$insert into public.share_links(subject_id, created_by, code, pin_hash) values ('91111111-1111-4111-8111-111111111121','91111111-1111-4111-8111-111111111121','999999','$2a$x')$$,'42501',null,'direct insert on share_links denied');
select throws_ok($$insert into public.share_link_opens(share_link_id, outcome) values ((select v from t_ids where k='link_alice'),'ok')$$,'42501',null,'direct insert on share_link_opens denied');
select throws_ok($$insert into public.dossier_snapshots(subject_id) values ('91111111-1111-4111-8111-111111111121')$$,'42501',null,'direct insert on dossier_snapshots denied');
select throws_ok($$insert into public.questions(subject_id, title, body) values ('91111111-1111-4111-8111-111111111121','t','b')$$,'42501',null,'direct insert on questions denied');
select throws_ok($$insert into public.emergency_cards(subject_id) values ('92222222-2222-4222-8222-222222222221')$$,'42501',null,'direct insert on emergency_cards denied');
select throws_ok($$update public.share_links set revoked_at=now()$$,'42501',null,'direct update on share_links denied');

-- ---------------------------------------------------------------------------
-- Bob: zero righe di Alice; anon: niente
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"92222222-2222-4222-8222-222222222221","role":"authenticated"}',true);
select is((select count(*)::int from public.share_links where subject_id='91111111-1111-4111-8111-111111111121'),0,'bob sees none of alice links');
select is((select count(*)::int from public.share_link_opens) + (select count(*)::int from public.dossier_snapshots) + (select count(*)::int from public.questions) + (select count(*)::int from public.emergency_cards),0,'bob sees no opens, snapshots, questions, cards of alice');
reset role; select set_config('request.jwt.claims','',true);
set local role anon;
select throws_ok($$select count(*) from public.emergency_cards$$,'42501',null,'anon cannot read emergency_cards');
reset role;

select * from finish();
rollback;