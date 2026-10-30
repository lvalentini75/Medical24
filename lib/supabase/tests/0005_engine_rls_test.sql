-- ============================================================================
-- Medical 24 — test pgTAP delle migrazioni 0005 (schema del motore) e 0006
-- (seed del catalogo biomarcatori).
--
-- Solo progetto dev. Si lancia intero nel SQL Editor: tutto in transazione,
-- rollback finale, nessun dato resta. L'ultima istruzione stampa tutte le
-- righe ok / not ok.
--
-- Copertura:
--  - schema: tabelle, colonne, indici, funzioni, registro migrazioni;
--  - seed: 73 righe, tutte draft con board_version 0;
--  - normalize_unit: fattore moltiplicativo e formula IFCC;
--  - resolve_flag: within / below / above, limiti di sicurezza,
--    unione degli intervalli con genere non dichiarato;
--  - RLS: un utente estraneo ottiene zero righe da extractions e
--    observations; nessun authenticated può scrivere in observations;
--  - start_extraction e confirm_observation.
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;

create temp table tap_lines (n serial primary key, line text);
grant all on table tap_lines to public;
grant all on sequence tap_lines_n_seq to public;

insert into tap_lines (line) select plan(40);

-- Fixture utenti (come postgres, prima di qualunque cambio di ruolo)
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'alice.test@example.com', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'bob.test@example.com', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('33333333-3333-4333-8333-333333333333', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'cleo.test@example.com', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

-- Alice donna, Bob uomo, Cleo genere non dichiarato.
update public.profiles set gender = 'female'
  where id = '11111111-1111-4111-8111-111111111111';
update public.profiles set gender = 'male'
  where id = '22222222-2222-4222-8222-222222222222';
update public.profiles set gender = 'undisclosed'
  where id = '33333333-3333-4333-8333-333333333333';

-- Documento di Alice su cui lavorano le estrazioni.
insert into public.documents (id, owner_id, subject_id, category, title, source, status, storage_path)
values ('dddddddd-0000-4000-8000-000000000001',
        '11111111-1111-4111-8111-111111111111',
        '11111111-1111-4111-8111-111111111111',
        'exams', 'Esami del sangue', 'pdf', 'uploaded',
        'subjects/11111111-1111-4111-8111-111111111111/documents/dddddddd-0000-4000-8000-000000000001/')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 1. Schema: 10 asserzioni
-- ---------------------------------------------------------------------------
insert into tap_lines (line) select has_table('public', 'biomarker_catalog', 'biomarker_catalog presente');
insert into tap_lines (line) select has_table('public', 'extractions', 'extractions presente');
insert into tap_lines (line) select has_table('public', 'observations', 'observations presente');
insert into tap_lines (line) select has_column('public', 'observations', 'supersedes_id', 'observations.supersedes_id presente');
insert into tap_lines (line) select has_column('public', 'extractions', 'cost_micro_usd', 'extractions.cost_micro_usd presente');
insert into tap_lines (line) select has_function('public', 'normalize_unit', array['text','numeric','text']::name[], 'normalize_unit() esiste');
insert into tap_lines (line) select has_function('public', 'resolve_reference', array['uuid','text']::name[], 'resolve_reference() esiste');
insert into tap_lines (line) select has_function('public', 'resolve_flag', array['uuid','text','numeric']::name[], 'resolve_flag() esiste');
insert into tap_lines (line) select has_function('public', 'start_extraction', array['uuid']::name[], 'start_extraction() esiste');
insert into tap_lines (line) select is((select count(*)::int from public.app_migrations where name like '0005_%' or name like '0006_%'), 2, 'le migrazioni 0005 e 0006 sono registrate');

-- ---------------------------------------------------------------------------
-- 2. Seed del catalogo: 4 asserzioni
-- ---------------------------------------------------------------------------
insert into tap_lines (line) select ok((select count(*) from public.biomarker_catalog) >= 73, 'il catalogo ha almeno le 73 righe del CSV del board');
insert into tap_lines (line) select is((select count(*)::int from public.biomarker_catalog where status <> 'draft'), 0, 'nessuna riga è validata: restano tutte draft');
insert into tap_lines (line) select is((select count(*)::int from public.biomarker_catalog where board_version <> 0), 0, 'board_version è 0 ovunque');
insert into tap_lines (line) select is((select unit_canonical from public.biomarker_catalog where code = '2345-7'), 'mg/dL', 'la glicemia è conservata in mg/dL');

-- ---------------------------------------------------------------------------
-- 3. normalize_unit: 3 asserzioni
-- ---------------------------------------------------------------------------
insert into tap_lines (line) select is(
  (select round(n.value_num, 3) from public.normalize_unit('2345-7', 5.5, 'mmol/L') n),
  99.088::numeric, 'glicemia: 5.5 mmol/L diventano 99.088 mg/dL');

insert into tap_lines (line) select is(
  (select n.unit from public.normalize_unit('2345-7', 92, 'mg/dL') n),
  'mg/dL', 'unità già canonica: nessuna conversione');

insert into tap_lines (line) select is(
  (select round(n.value_num, 2) from public.normalize_unit('4548-4', 42, 'mmol/mol') n),
  5.90::numeric, 'HbA1c: 42 mmol/mol diventano 5.90 % con la formula IFCC');

-- ---------------------------------------------------------------------------
-- 4. resolve_flag: 6 asserzioni
-- ---------------------------------------------------------------------------
-- Emoglobina: donne 12.0-16.0, uomini 13.5-17.5, sicurezza 7-20.
insert into tap_lines (line) select is(
  public.resolve_flag('11111111-1111-4111-8111-111111111111', '718-7', 13.0)::text,
  'within', 'Alice (donna): 13.0 g/dL è dentro l''intervallo femminile');

insert into tap_lines (line) select is(
  public.resolve_flag('22222222-2222-4222-8222-222222222222', '718-7', 13.0)::text,
  'below', 'Bob (uomo): 13.0 g/dL è sotto l''intervallo maschile');

insert into tap_lines (line) select is(
  public.resolve_flag('11111111-1111-4111-8111-111111111111', '718-7', 6.0)::text,
  'critical_low', 'sotto il limite di sicurezza del board il flag è critical_low');

insert into tap_lines (line) select is(
  public.resolve_flag('11111111-1111-4111-8111-111111111111', '718-7', 21.0)::text,
  'critical_high', 'sopra il limite di sicurezza del board il flag è critical_high');

-- Cleo, genere non dichiarato: unione 12.0-17.5.
insert into tap_lines (line) select is(
  public.resolve_flag('33333333-3333-4333-8333-333333333333', '718-7', 17.0)::text,
  'unknown', 'genere non dichiarato: dentro l''intervallo M e fuori dall''F -> unknown');

insert into tap_lines (line) select is(
  public.resolve_flag('33333333-3333-4333-8333-333333333333', '718-7', 11.0)::text,
  'below', 'genere non dichiarato: sotto entrambi gli intervalli -> below');

-- ---------------------------------------------------------------------------
-- 5. Alice: start_extraction e observations: 6 asserzioni
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);

insert into tap_lines (line) select ok(
  public.start_extraction('dddddddd-0000-4000-8000-000000000001') is not null,
  'Alice mette il proprio documento in coda');

insert into tap_lines (line) select is(
  (select status::text from public.documents where id = 'dddddddd-0000-4000-8000-000000000001'),
  'processing', 'il documento passa in processing');

insert into tap_lines (line) select is(
  (select count(*)::int from public.extractions where document_id = 'dddddddd-0000-4000-8000-000000000001'),
  1, 'Alice vede la propria estrazione');

insert into tap_lines (line) select is(
  public.start_extraction('dddddddd-0000-4000-8000-000000000001'),
  (select id from public.extractions where document_id = 'dddddddd-0000-4000-8000-000000000001'),
  'una seconda chiamata non duplica la coda');

insert into tap_lines (line) select throws_ok($$
  insert into public.observations (subject_id, code, value_num, unit, effective_at)
  values ('11111111-1111-4111-8111-111111111111', '2345-7', 92, 'mg/dL', now())
$$, '42501', null, 'authenticated non può inserire a mano in observations (policy del P03)');

insert into tap_lines (line) select is(
  (select count(*)::int from public.analysis_usage() u where u.max = 30),
  1, 'analysis_usage: massimo 30 letture al mese');

-- ---------------------------------------------------------------------------
-- 6. Scrittura come service_role e conferma del valore: 3 asserzioni
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
set local role service_role;

insert into public.observations (
  id, subject_id, code, display_name, value_num, unit, value_raw, unit_raw,
  flag, effective_at, origin, document_id, confidence, needs_review
) values (
  '0b000000-0000-4000-8000-000000000001',
  '11111111-1111-4111-8111-111111111111', '2345-7', 'Glicemia',
  92, 'mg/dL', 92, 'mg/dL', 'within', now(), 'document',
  'dddddddd-0000-4000-8000-000000000001', 0.55, true
);

insert into tap_lines (line) select throws_ok($$
  update public.observations set value_num = 300
   where id = '0b000000-0000-4000-8000-000000000001'
$$, '42501', null, 'observations è append-only anche per service_role');

reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);

insert into tap_lines (line) select ok(
  public.confirm_observation('0b000000-0000-4000-8000-000000000001', 95, 'mg/dL') is not null,
  'Alice corregge il valore: nasce una riga nuova');

insert into tap_lines (line) select is(
  (select count(*)::int from public.observations
    where document_id = 'dddddddd-0000-4000-8000-000000000001'
      and superseded_at is null),
  1, 'resta un solo valore corrente: la riga precedente è superata, non cancellata');

-- ---------------------------------------------------------------------------
-- 7. Bob, utente estraneo: 3 asserzioni
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}', true);

insert into tap_lines (line) select is(
  (select count(*)::int from public.extractions),
  0, 'Bob non vede nessuna estrazione di Alice');

insert into tap_lines (line) select is(
  (select count(*)::int from public.observations),
  0, 'Bob non vede nessun valore di Alice');

insert into tap_lines (line) select throws_ok($$
  select public.start_extraction('dddddddd-0000-4000-8000-000000000001')
$$, '42501', null, 'Bob non può mettere in coda il documento di Alice');

-- ---------------------------------------------------------------------------
-- 8. Policy esplicite del motore: 4 asserzioni
insert into tap_lines (line) select is((select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'biomarker_catalog' and policyname = 'biomarker_catalog_select'), 1, 'policy di lettura del catalogo presente');
insert into tap_lines (line) select is((select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'biomarker_catalog' and policyname = 'biomarker_catalog_write'), 1, 'policy di scrittura del catalogo presente');
insert into tap_lines (line) select is((select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'extractions' and policyname = 'extractions_select'), 1, 'policy di lettura delle estrazioni presente');
insert into tap_lines (line) select is((select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'observations' and policyname = 'observations_select'), 1, 'policy di lettura delle osservazioni presente');

-- 9. Catalogo pubblico in lettura, non in scrittura: 1 asserzione
-- ---------------------------------------------------------------------------
insert into tap_lines (line) select is(
  (select count(*)::int from public.biomarker_catalog where code = '718-7'),
  1, 'il catalogo del board resta leggibile da ogni utente autenticato');

reset role;
select set_config('request.jwt.claims', '', true);

-- ---------------------------------------------------------------------------
-- Esito
-- ---------------------------------------------------------------------------
insert into tap_lines (line) select * from finish();
select line from tap_lines order by n;

rollback;
