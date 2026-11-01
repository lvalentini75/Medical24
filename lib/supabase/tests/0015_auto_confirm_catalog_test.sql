-- Medical 24 — pgTAP 0015 auto confirm + catalogo percentuali.
-- Solo progetto dev: tutto in transazione, rollback finale, nessun dato resta.
--
-- Copre: la conferma dal motore sopra soglia (confirmed_by null, riga
-- precedente superata, valore e unita' invariati), i valori sotto soglia e
-- quelli marcati needs_review che restano pending, l'idempotenza della
-- seconda chiamata, i valori scartati mai toccati, il divieto per
-- authenticated, i cinque codici della formula leucocitaria con unita' '%'
-- e la loro presenza nella mappa dell'area immune, la lettura di
-- platform.maintenance_mode da anon e il rifiuto di una impostazione non
-- pubblica, il registro della migrazione.

begin;
create extension if not exists pgtap with schema extensions;
create temp table tap_lines(n serial primary key, line text);
grant all on table tap_lines to public;
grant all on sequence tap_lines_n_seq to public;
create temp table fix_counts(k text primary key, v int);
grant all on table fix_counts to public;
insert into tap_lines(line) select plan(19);

-- ---------------------------------------------------------------------------
-- Fixture: Alice, un documento, una estrazione, quattro valori letti.
-- ---------------------------------------------------------------------------
insert into auth.users(id, instance_id, aud, role, email, encrypted_password,
 email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('11111111-1111-4111-8111-111111111111',
 '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
 'alice.autoconfirm15@example.com', '', now(),
 '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict(id) do nothing;
update public.profiles set gender='female', birth_date=current_date-interval '45 years',
 language='it' where id='11111111-1111-4111-8111-111111111111';

insert into public.documents(id, owner_id, subject_id, category, title, source, status, storage_path)
values ('d5000000-0000-4000-8000-000000000015',
 '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111',
 'exams', 'Referto 0015', 'pdf', 'uploaded',
 'subjects/11111111-1111-4111-8111-111111111111/documents/d5000000-0000-4000-8000-000000000015/')
on conflict(id) do nothing;

insert into public.extractions(id, document_id, subject_id, status, attempt)
values ('e5000000-0000-4000-8000-000000000015', 'd5000000-0000-4000-8000-000000000015',
 '11111111-1111-4111-8111-111111111111', 'normalizing', 1)
on conflict(id) do nothing;

insert into public.observations(
 id, subject_id, code, display_name, value_num, unit, value_raw, unit_raw,
 flag, effective_at, origin, document_id, extraction_id, confidence,
 needs_review, review_status, rule_version)
values
 -- alta confidenza: il motore la conferma
 ('05000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
  '2345-7', 'Glicemia', 92, 'mg/dL', 92, 'mg/dL', 'within', now(), 'document',
  'd5000000-0000-4000-8000-000000000015', 'e5000000-0000-4000-8000-000000000015',
  0.90, false, 'pending', 'board-0'),
 -- sotto soglia: resta da verificare dall'utente
 ('05000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111',
  '718-7', 'Emoglobina', 13.1, 'g/dL', 13.1, 'g/dL', 'within', now(), 'document',
  'd5000000-0000-4000-8000-000000000015', 'e5000000-0000-4000-8000-000000000015',
  0.70, false, 'pending', 'board-0'),
 -- alta confidenza ma marcata dal motore: resta da verificare
 ('05000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111',
  '777-3', 'Piastrine', 230, '10*3/uL', 230, '10*3/uL', 'within', now(), 'document',
  'd5000000-0000-4000-8000-000000000015', 'e5000000-0000-4000-8000-000000000015',
  0.95, true, 'pending', 'board-0'),
 -- gia' scartata: il motore non la tocca mai
 ('05000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111',
  '4544-3', 'Ematocrito', 41, '%', 41, '%', 'within', now(), 'document',
  'd5000000-0000-4000-8000-000000000015', 'e5000000-0000-4000-8000-000000000015',
  0.99, false, 'discarded', 'board-0');

-- ---------------------------------------------------------------------------
-- 1. Schema e registro: 3 asserzioni
-- ---------------------------------------------------------------------------
insert into tap_lines(line) select has_function('public', 'auto_confirm_extraction',
 array['uuid'], 'auto_confirm_extraction exists');
insert into tap_lines(line) select has_function('public', 'confirm_observation_internal',
 'confirm_observation_internal exists');
insert into tap_lines(line) select is((select count(*)::int from public.app_migrations
 where name='0015_auto_confirm_catalog'), 1, '0015 is registered');

-- ---------------------------------------------------------------------------
-- 2. Conferma dal motore: 10 asserzioni
-- ---------------------------------------------------------------------------
insert into fix_counts(k, v)
select 'first', public.auto_confirm_extraction('e5000000-0000-4000-8000-000000000015');

insert into tap_lines(line) select is((select v from fix_counts where k='first'), 1,
 'the engine confirms exactly the value above the threshold');
insert into tap_lines(line) select ok((select superseded_at is not null from public.observations
 where id='05000000-0000-4000-8000-000000000001'),
 'the confirmed source row is superseded, not deleted');
insert into tap_lines(line) select is((select review_status::text from public.observations
 where supersedes_id='05000000-0000-4000-8000-000000000001'), 'confirmed',
 'the replacement row is confirmed');
insert into tap_lines(line) select ok((select confirmed_by is null and confirmed_at is not null
 from public.observations where supersedes_id='05000000-0000-4000-8000-000000000001'),
 'confirmed_by is null: the confirmation comes from the engine');
insert into tap_lines(line) select is((select value_num from public.observations
 where supersedes_id='05000000-0000-4000-8000-000000000001'), 92::numeric,
 'the value is unchanged');
insert into tap_lines(line) select is((select unit from public.observations
 where supersedes_id='05000000-0000-4000-8000-000000000001'), 'mg/dL',
 'the unit is unchanged');
insert into tap_lines(line) select is((select review_status::text from public.observations
 where id='05000000-0000-4000-8000-000000000002'), 'pending',
 'a value below the threshold stays pending');
insert into tap_lines(line) select is((select review_status::text from public.observations
 where id='05000000-0000-4000-8000-000000000003'), 'pending',
 'a high confidence value flagged needs_review stays pending');
insert into tap_lines(line) select ok((select review_status='discarded' and superseded_at is null
 from public.observations where id='05000000-0000-4000-8000-000000000004'),
 'a discarded value is never touched');
insert into tap_lines(line) select is(
 public.auto_confirm_extraction('e5000000-0000-4000-8000-000000000015'), 0,
 'a second run confirms nothing');

-- ---------------------------------------------------------------------------
-- 3. Audit e permessi: 2 asserzioni
-- ---------------------------------------------------------------------------
insert into tap_lines(line) select is((select count(*)::int from public.audit_log
 where action='observation.auto_confirmed'
   and target_table='extractions'
   and target_id='e5000000-0000-4000-8000-000000000015'
   and actor_id is null
   and subject_id='11111111-1111-4111-8111-111111111111'), 1,
 'one audit row per extraction, written by the engine');

set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
insert into tap_lines(line) select throws_ok(
 $$select public.auto_confirm_extraction('e5000000-0000-4000-8000-000000000015')$$,
 '42501', null, 'authenticated cannot run the engine confirmation');

-- ---------------------------------------------------------------------------
-- 4. Catalogo delle percentuali: 2 asserzioni
-- ---------------------------------------------------------------------------
insert into tap_lines(line) select is((select count(*)::int from public.biomarker_catalog
 where code in ('26511-6','26478-8','26485-3','26450-7','30180-4')
   and unit_canonical='%' and status='draft' and board_version=0
   and plausible_min=0 and plausible_max=100), 5,
 'the five differential percentages are seeded with the canonical unit');
insert into tap_lines(line) select is((select count(*)::int from public.organ_biomarker_map
 where organ_id='immune' and code in ('26511-6','26478-8','26485-3','26450-7','30180-4')), 5,
 'the five percentages are mapped on the immune area');

-- ---------------------------------------------------------------------------
-- 5. platform_setting per anon: 2 asserzioni
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims', '', true);
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
insert into tap_lines(line) select ok(
 public.platform_setting('platform.maintenance_mode') is not null,
 'anon reads platform.maintenance_mode before signing in');
insert into tap_lines(line) select throws_ok(
 $$select public.platform_setting('extraction.auto_confirm_confidence')$$,
 '42501', 'not_allowed', 'anon is refused a non public setting');

reset role; select set_config('request.jwt.claims', '', true);
insert into tap_lines(line) select * from finish();
select line from tap_lines order by n;
rollback;
