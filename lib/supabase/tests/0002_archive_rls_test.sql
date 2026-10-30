-- ============================================================================
-- Medical 24 — test pgTAP delle migrazioni 0002 e 0004 (Archivio: documents,
-- document_pages, Storage, limite, soft delete via funzione, cron).
-- Solo progetto dev. Si lancia intero nel SQL Editor: tutto in transazione,
-- rollback finale, nessun dato resta. L'ultima istruzione stampa tutte le
-- righe ok / not ok.
-- Utenti simulati: Alice 11111111-1111-4111-8111-111111111111,
--                  Bob   22222222-2222-4222-8222-222222222222
-- ============================================================================

begin;

create extension if not exists pgtap with schema extensions;

-- Raccoglitore dei risultati (stesso meccanismo di pgTAP: temp table visibile
-- a tutti i ruoli della sessione).
create temp table tap_lines (n serial primary key, line text);
grant all on table tap_lines to public;
grant all on sequence tap_lines_n_seq to public;

insert into tap_lines (line) select plan(52);

-- ---------------------------------------------------------------------------
-- Fixture: utenti di prova (come postgres, prima di ogni set role).
-- I profili e i ruoli nascono dal trigger handle_new_user.
-- ---------------------------------------------------------------------------
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
-- 1. Schema (come postgres): 20 asserzioni
-- ---------------------------------------------------------------------------
insert into tap_lines (line) select has_table('public', 'documents', 'documents esiste');
insert into tap_lines (line) select has_table('public', 'document_pages', 'document_pages esiste');
insert into tap_lines (line) select ok((select relrowsecurity from pg_class where oid = 'public.documents'::regclass), 'RLS attiva su documents');
insert into tap_lines (line) select ok((select relforcerowsecurity from pg_class where oid = 'public.documents'::regclass), 'RLS forzata su documents');
insert into tap_lines (line) select ok((select relrowsecurity from pg_class where oid = 'public.document_pages'::regclass), 'RLS attiva su document_pages');
insert into tap_lines (line) select ok((select relforcerowsecurity from pg_class where oid = 'public.document_pages'::regclass), 'RLS forzata su document_pages');
insert into tap_lines (line) select is((select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'documents' and cmd = 'DELETE'), 0, 'nessuna policy di delete su documents');
insert into tap_lines (line) select is((select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'document_pages' and cmd = 'DELETE'), 0, 'nessuna policy di delete su document_pages');
insert into tap_lines (line) select is((select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'documents'), 3, 'tre policy su documents (select, insert, update)');
insert into tap_lines (line) select is((select count(*)::int from pg_policies where schemaname = 'public' and tablename = 'document_pages'), 3, 'tre policy su document_pages');
insert into tap_lines (line) select is((select count(*)::int from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'documents_storage_%'), 4, 'quattro policy documents_storage_* su storage.objects');
insert into tap_lines (line) select ok((select not public from storage.buckets where id = 'documents'), 'bucket documents privato');
insert into tap_lines (line) select is((select file_size_limit from storage.buckets where id = 'documents'), 26214400::bigint, 'bucket documents con limite 25 MB');
insert into tap_lines (line) select has_function('public', 'document_limit', array['uuid'], 'document_limit(uuid) esiste');
insert into tap_lines (line) select has_function('public', 'can_access_document', array['uuid'], 'can_access_document(uuid) esiste');
insert into tap_lines (line) select has_function('public', 'expire_stale_document_uploads', array[]::name[], 'expire_stale_document_uploads() esiste');
insert into tap_lines (line) select has_function('public', 'soft_delete_document', array['uuid'], 'soft_delete_document(uuid) esiste');
insert into tap_lines (line) select is(public.document_limit('11111111-1111-4111-8111-111111111111'::uuid), 30, 'limite 30 documenti per tutti');
insert into tap_lines (line) select has_trigger('public', 'documents', 'trg_documents_limit', 'trigger del limite presente');
insert into tap_lines (line) select has_trigger('public', 'documents', 'trg_documents_audit_soft_delete', 'trigger di audit del soft delete presente');

-- ---------------------------------------------------------------------------
-- 2. Alice (utente simulato): 8 asserzioni
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);

insert into tap_lines (line) select lives_ok($$
  insert into public.documents (id, owner_id, subject_id, category, title, source, storage_path)
  values ('aaaaaaaa-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
          '11111111-1111-4111-8111-111111111111', 'reports', 'Referto di prova', 'pdf',
          'subjects/11111111-1111-4111-8111-111111111111/documents/aaaaaaaa-0000-4000-8000-000000000001/')
$$, 'Alice inserisce un proprio documento');

insert into tap_lines (line) select lives_ok($$
  insert into public.document_pages (document_id, page_number, image_path)
  values ('aaaaaaaa-0000-4000-8000-000000000001', 1,
          'subjects/11111111-1111-4111-8111-111111111111/documents/aaaaaaaa-0000-4000-8000-000000000001/page-001.jpg')
$$, 'Alice inserisce una pagina del proprio documento');

insert into tap_lines (line) select is((select count(*)::int from public.documents), 1, 'Alice vede il proprio documento');
insert into tap_lines (line) select is((select count(*)::int from public.document_pages), 1, 'Alice vede la propria pagina');

insert into tap_lines (line) select throws_ok($$
  insert into public.documents (owner_id, subject_id, category, title, source, storage_path)
  values ('11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222',
          'reports', 'altrui', 'pdf', 'subjects/22222222-2222-4222-8222-222222222222/documents/x/')
$$, '42501', null, 'Alice non inserisce su un subject_id altrui');

insert into tap_lines (line) select throws_ok($$
  insert into public.documents (owner_id, subject_id, category, title, source, storage_path)
  values ('22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111',
          'reports', 'owner falso', 'pdf', 'subjects/11111111-1111-4111-8111-111111111111/documents/y/')
$$, '42501', null, 'owner_id deve essere auth.uid()');

insert into tap_lines (line) select lives_ok($$
  insert into storage.objects (bucket_id, name, owner, owner_id)
  values ('documents', 'subjects/11111111-1111-4111-8111-111111111111/documents/aaaaaaaa-0000-4000-8000-000000000001/original.pdf',
          '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111')
$$, 'Alice scrive nel proprio path dello Storage');

insert into tap_lines (line) select ok(public.can_access_document('aaaaaaaa-0000-4000-8000-000000000001'), 'can_access_document vero per Alice sul proprio documento');

-- ---------------------------------------------------------------------------
-- 3. Bob (utente estraneo): 11 asserzioni
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated"}', true);

insert into tap_lines (line) select is((select count(*)::int from public.documents), 0, 'Bob ottiene zero righe da documents');
insert into tap_lines (line) select is((select count(*)::int from public.document_pages), 0, 'Bob ottiene zero righe da document_pages');
insert into tap_lines (line) select is((select count(*)::int from storage.objects where bucket_id = 'documents'), 0, 'Bob non vede gli oggetti di Alice nello Storage');

insert into tap_lines (line) select throws_ok($$
  insert into public.documents (owner_id, subject_id, category, title, source, storage_path)
  values ('22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111',
          'reports', 'intruso', 'pdf', 'subjects/11111111-1111-4111-8111-111111111111/documents/z/')
$$, '42501', null, 'Bob non inserisce documenti su Alice');

insert into tap_lines (line) select throws_ok($$
  insert into public.document_pages (document_id, page_number, image_path)
  values ('aaaaaaaa-0000-4000-8000-000000000001', 2, 'subjects/11111111-1111-4111-8111-111111111111/documents/aaaaaaaa-0000-4000-8000-000000000001/page-002.jpg')
$$, '42501', null, 'Bob non inserisce pagine sul documento di Alice');

insert into tap_lines (line) select throws_ok($$
  insert into storage.objects (bucket_id, name, owner, owner_id)
  values ('documents', 'subjects/11111111-1111-4111-8111-111111111111/documents/aaaaaaaa-0000-4000-8000-000000000001/intruso.pdf',
          '22222222-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222')
$$, '42501', null, 'Bob non scrive nello Storage di Alice');

insert into tap_lines (line) select lives_ok($$
  update public.documents set title = 'manomesso' where id = 'aaaaaaaa-0000-4000-8000-000000000001'
$$, 'l''update di Bob sul documento di Alice non dà errore (zero righe toccate)');

insert into tap_lines (line) select throws_ok($$
  select public.soft_delete_document('aaaaaaaa-0000-4000-8000-000000000001')
$$, '42501', 'not_allowed', 'Bob non cancella il documento di Alice');

insert into tap_lines (line) select lives_ok($$
  insert into public.documents (id, owner_id, subject_id, category, title, source, storage_path)
  values ('bbbbbbbb-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222',
          '22222222-2222-4222-8222-222222222222', 'exams', 'Esame di Bob', 'camera',
          'subjects/22222222-2222-4222-8222-222222222222/documents/bbbbbbbb-0000-4000-8000-000000000001/')
$$, 'Bob inserisce un proprio documento');

insert into tap_lines (line) select is((select count(*)::int from public.documents), 1, 'Bob vede solo il proprio documento');
insert into tap_lines (line) select ok(not public.can_access_document('aaaaaaaa-0000-4000-8000-000000000001'), 'can_access_document falso per Bob sul documento di Alice');

-- ---------------------------------------------------------------------------
-- 4. Alice: limite di 30, soft delete, upload appeso: 9 asserzioni
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);

insert into tap_lines (line) select lives_ok($$
  insert into public.documents (owner_id, subject_id, category, title, source, storage_path)
  select '11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111',
         'other', 'documento ' || g, 'pdf',
         'subjects/11111111-1111-4111-8111-111111111111/documents/' || gen_random_uuid() || '/'
  from generate_series(1, 29) as g
$$, 'Alice arriva a 30 documenti');

insert into tap_lines (line) select is((select count(*)::int from public.documents), 30, 'Alice ha 30 documenti attivi');

insert into tap_lines (line) select throws_ok($$
  insert into public.documents (owner_id, subject_id, category, title, source, storage_path)
  values ('11111111-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111',
          'other', 'trentunesimo', 'pdf', 'subjects/11111111-1111-4111-8111-111111111111/documents/w/')
$$, 'P0001', 'document_limit_reached', 'il 31° documento viene rifiutato con document_limit_reached');

insert into tap_lines (line) select throws_ok($$
  update public.documents set deleted_at = now() where id = 'aaaaaaaa-0000-4000-8000-000000000001'
$$, '42501', null, 'l''update diretto di deleted_at è rifiutato dalla RLS: si passa dalla funzione');

insert into tap_lines (line) select lives_ok($$
  select public.soft_delete_document('aaaaaaaa-0000-4000-8000-000000000001')
$$, 'Alice cancella (soft) il proprio documento con soft_delete_document');

insert into tap_lines (line) select is((select count(*)::int from public.documents where id = 'aaaaaaaa-0000-4000-8000-000000000001'), 0, 'il documento cancellato sparisce dalla select');
insert into tap_lines (line) select is((select count(*)::int from public.document_pages where document_id = 'aaaaaaaa-0000-4000-8000-000000000001'), 0, 'le pagine del documento cancellato spariscono');
insert into tap_lines (line) select is((select count(*)::int from public.documents), 29, 'Alice vede 29 documenti attivi');

insert into tap_lines (line) select lives_ok($$
  insert into public.documents (id, owner_id, subject_id, category, title, source, storage_path, created_at)
  values ('cccccccc-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
          '11111111-1111-4111-8111-111111111111', 'other', 'upload appeso', 'camera',
          'subjects/11111111-1111-4111-8111-111111111111/documents/cccccccc-0000-4000-8000-000000000001/',
          now() - interval '2 days')
$$, 'Alice ha un upload rimasto in uploading da due giorni');

-- ---------------------------------------------------------------------------
-- 5. Controlli fuori RLS (service_role) e cron (postgres): 3 asserzioni
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);

set local role service_role;
insert into tap_lines (line) select is((select title from public.documents where id = 'aaaaaaaa-0000-4000-8000-000000000001'), 'Referto di prova', 'il titolo di Alice è intatto dopo il tentativo di Bob');
insert into tap_lines (line) select is((select count(*)::int from public.audit_log where action = 'document.deleted' and target_id::text = 'aaaaaaaa-0000-4000-8000-000000000001'), 1, 'il soft delete è registrato in audit_log');
reset role;

insert into tap_lines (line) select is(public.expire_stale_document_uploads(), 1, 'expire_stale_document_uploads chiude un solo upload appeso');

-- ---------------------------------------------------------------------------
-- 6. Alice vede l'esito: 1 asserzione
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated"}', true);
insert into tap_lines (line) select is((select status::text || '|' || coalesce(failure_reason, '') from public.documents where id = 'cccccccc-0000-4000-8000-000000000001'), 'failed|upload_incomplete', 'l''upload appeso è passato a failed / upload_incomplete');

-- ---------------------------------------------------------------------------
-- Esito
-- ---------------------------------------------------------------------------
reset role;
insert into tap_lines (line) select * from finish();
select line from tap_lines order by n;

rollback;