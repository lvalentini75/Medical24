-- ============================================================================
-- Medical 24 — test pgTAP della migrazione 0003 (completamento Archivio:
-- duplicate_dismissed_at, document_usage(), registro app_migrations).
-- Solo progetto dev. Si lancia intero nel SQL Editor: tutto in transazione,
-- rollback finale, nessun dato resta. L'ultima istruzione stampa tutte le
-- righe ok / not ok.
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;

create temp table tap_lines (n serial primary key, line text);
grant all on table tap_lines to public;
grant all on sequence tap_lines_n_seq to public;

insert into tap_lines (line) select plan(18);

-- Fixture utenti (come postgres)
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                        raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('11111111-1111-4111-8111-111111111111', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'alice.test@example.com', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('22222222-2222-4222-8222-222222222222', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'bob.test@example.com', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now())
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 1. Schema (come postgres): 5 asserzioni
-- ---------------------------------------------------------------------------
insert into tap_lines (line) select has_column('public', 'documents', 'duplicate_dismissed_at', 'colonna duplicate_dismissed_at presente');
insert into tap_lines (line) select has_function('public', 'document_usage', array[]::name[], 'document_usage() esiste');
insert into tap_lines (line) select has_index('public', 'documents', 'idx_documents_duplicate_open', 'indice parziale sui duplicati aperti presente');
insert into tap_lines (line) select has_table('public', 'app_migrations', 'registro app_migrations presente');
insert into tap_lines (line) select is((select count(*)::int from public.app_migrations where name like '0003_%'), 1, 'la 0003 è registrata in app_migrations');

-- ---------------------------------------------------------------------------
-- 2. Alice: 9 asserzioni
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);

insert into tap_lines (line) select is((select u.max from public.document_usage() u), 30, 'document_usage: massimo 30');
insert into tap_lines (line) select is((select u.used from public.document_usage() u), 0, 'document_usage: zero documenti all''inizio');

insert into tap_lines (line) select lives_ok($$
  insert into public.documents (id, owner_id, subject_id, category, title, source, storage_path)
  values
   ('aaaaaaaa-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111', 'reports', 'Referto uno', 'pdf', 'subjects/11111111-1111-4111-8111-111111111111/documents/aaaaaaaa-0000-4000-8000-000000000001/'),
   ('aaaaaaaa-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111', 'reports', 'Referto due', 'pdf', 'subjects/11111111-1111-4111-8111-111111111111/documents/aaaaaaaa-0000-4000-8000-000000000002/'),
   ('aaaaaaaa-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111', 'reports', 'Referto tre', 'pdf', 'subjects/11111111-1111-4111-8111-111111111111/documents/aaaaaaaa-0000-4000-8000-000000000003/')
$$, 'Alice inserisce tre documenti');

insert into tap_lines (line) select is((select u.used from public.document_usage() u), 3, 'document_usage conta 3 documenti attivi');

insert into tap_lines (line) select lives_ok($$
  select public.soft_delete_document('aaaaaaaa-0000-4000-8000-000000000003')
$$, 'Alice cancella (soft) il terzo documento');

insert into tap_lines (line) select is((select u.used from public.document_usage() u), 2, 'i documenti cancellati non contano');

insert into tap_lines (line) select is((select duplicate_dismissed_at from public.documents where id = 'aaaaaaaa-0000-4000-8000-000000000001'), null::timestamptz, 'duplicate_dismissed_at nasce nulla');

insert into tap_lines (line) select lives_ok($$
  update public.documents set duplicate_dismissed_at = now() where id = 'aaaaaaaa-0000-4000-8000-000000000001'
$$, 'Alice segna "conserva entrambi" sul proprio documento');

insert into tap_lines (line) select ok((select duplicate_dismissed_at is not null from public.documents where id = 'aaaaaaaa-0000-4000-8000-000000000001'), 'duplicate_dismissed_at valorizzata');

-- ---------------------------------------------------------------------------
-- 3. Bob: 3 asserzioni
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}', true);

insert into tap_lines (line) select is((select u.used from public.document_usage() u), 0, 'document_usage di Bob conta zero');
insert into tap_lines (line) select is((select count(*)::int from public.documents where id = 'aaaaaaaa-0000-4000-8000-000000000001'), 0, 'Bob non legge il documento di Alice');
insert into tap_lines (line) select lives_ok($$
  update public.documents set title = 'manomesso' where id = 'aaaaaaaa-0000-4000-8000-000000000001'
$$, 'l''update di Bob non dà errore (zero righe toccate)');

-- ---------------------------------------------------------------------------
-- 4. Verifica fuori RLS (service_role): 1 asserzione
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
set local role service_role;
insert into tap_lines (line) select is((select title from public.documents where id = 'aaaaaaaa-0000-4000-8000-000000000001'), 'Referto uno', 'il titolo di Alice è intatto dopo il tentativo di Bob');
reset role;

-- ---------------------------------------------------------------------------
-- Esito
-- ---------------------------------------------------------------------------
insert into tap_lines (line) select * from finish();
select line from tap_lines order by n;

rollback;