-- ============================================================================
-- Medical 24 — 0026 HARDENING SCHEMA (P10-A2a)
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- Chiude i punti 4-17 e 34 di lib/supabase/AUDIT_P10.md. Nessuna funzione
-- nuova, nessuna tabella nuova, nessuna Edge Function: solo irrigidimento
-- dell'esistente.
--
--   1. force row level security su user_roles, audit_log, biomarker_catalog
--   2. set search_path = public su ventitre funzioni che ne erano prive
--   3. revoke/grant di execute sulle funzioni di trigger e su explanation_lookup
--   4. security_invoker = true dichiarato esplicitamente sulle quattro viste
--   5. commento che dichiara il deny-all di app_migrations
--
-- Tutto idempotente: alter function, alter table e alter view si possono
-- rieseguire senza effetti collaterali.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. RLS forzata (punti 4, 5, 6 dell'audit)
--
--    enable row level security non basta: il proprietario della tabella
--    (postgres, e quindi ogni funzione security definer che gli appartiene)
--    continua ad aggirare le policy finche' la RLS non e' forzata.
-- ---------------------------------------------------------------------------
alter table public.user_roles        force row level security;
alter table public.audit_log         force row level security;
alter table public.biomarker_catalog force row level security;

-- ---------------------------------------------------------------------------
-- 2. search_path fisso (punti 8, 9, 10, 11, 15, 16 dell'audit)
--
--    Senza "set search_path" una funzione risolve i nomi con il search_path
--    di chi la chiama: uno schema temporaneo in testa basta a dirottare una
--    chiamata. Vale per le funzioni di trigger, per i calcolatori di rischio
--    e per le funzioni immutable usate dentro check e colonne generate.
--    pg_catalog resta implicitamente in testa, quindi btrim, jsonb_typeof e
--    simili continuano a risolversi.
-- ---------------------------------------------------------------------------

-- trigger generici
alter function public.set_updated_at()                        set search_path = public;
alter function public.immutable_array_to_string(text[], text) set search_path = public;

-- guardie append-only
alter function public.observations_append_only()  set search_path = public;
alter function public.organ_states_append_only()  set search_path = public;
alter function public.risk_scores_append_only()   set search_path = public;
alter function public.m24_block_mutation()        set search_path = public;
alter function public.m24_guard_dossier_snapshot() set search_path = public;

-- calcolatori di rischio
alter function public.score2_risk(int, text, boolean, numeric, numeric, numeric)
  set search_path = public;
alter function public.findrisc_score(jsonb)                  set search_path = public;
alter function public.ckd_epi_2021(numeric, int, text)       set search_path = public;
alter function public.fracture_checklist_score(jsonb)        set search_path = public;

-- filtro anti-diagnosi
alter function public.normalize_for_filter(text)             set search_path = public;

-- validatori e helper immutable usati in check e colonne generate
alter function public.m24_jsonb_keys_subset(jsonb, text[])   set search_path = public;
alter function public.m24_valid_contraindications(jsonb)     set search_path = public;
alter function public.m24_valid_media(jsonb)                 set search_path = public;
alter function public.m24_treatment_search_doc(text, text, text, text[], text[], jsonb)
  set search_path = public;
alter function public.m24_display_name_initial(text)         set search_path = public;
alter function public.m24_treatment_cover_url(jsonb)         set search_path = public;
alter function public.m24_max_contraindication(jsonb)        set search_path = public;
alter function public.m24_valid_share_scope(jsonb)           set search_path = public;
alter function public.m24_valid_emergency_contacts(jsonb)    set search_path = public;
alter function public.m24_valid_public_fields(jsonb)         set search_path = public;
alter function public.m24_valid_pin(text)                    set search_path = public;

-- ---------------------------------------------------------------------------
-- 3. Grant di execute (punti 12, 13, 14 dell'audit)
--
--    Le funzioni di trigger non vanno mai invocate a mano: il trigger le
--    esegue per conto del proprietario, non del chiamante.
-- ---------------------------------------------------------------------------
revoke execute on function public.set_updated_at()            from public, anon, authenticated;
revoke execute on function public.enforce_document_limit()    from public, anon, authenticated;
revoke execute on function public.audit_document_soft_delete() from public, anon, authenticated;
revoke execute on function public.handle_new_user()           from public, anon, authenticated;

-- immutable_array_to_string e' valutata dentro la colonna generata
-- documents.search: la valuta chi inserisce, quindi authenticated deve
-- poterla eseguire. anon no: non inserisce documenti.
revoke execute on function public.immutable_array_to_string(text[], text) from public, anon;
grant  execute on function public.immutable_array_to_string(text[], text) to authenticated, service_role;

-- explanation_lookup e' security invoker (la RLS di explanations resta in
-- vigore), ma non c'e' ragione perche' anon possa chiamarla.
revoke execute on function public.explanation_lookup(uuid, text, text, text, text, text)
  from public, anon;
grant  execute on function public.explanation_lookup(uuid, text, text, text, text, text)
  to authenticated, service_role;

-- Le m24_valid_* e m24_jsonb_keys_subset mantengono i grant attuali: sono
-- valutate dentro i vincoli check delle tabelle del modulo Medico e delle cure.

-- ---------------------------------------------------------------------------
-- 4. security_invoker esplicito sulle viste (punto 17 dell'audit)
--
--    Una vista senza security_invoker gira con i diritti del proprietario e
--    scavalca la RLS delle tabelle sottostanti. Qui lo dichiariamo di nuovo,
--    in forma idempotente, anche dove una migrazione successiva lo aveva gia'
--    corretto: un ambiente fermo a meta' sequenza resterebbe esposto.
-- ---------------------------------------------------------------------------
alter view public.biomarker_series    set (security_invoker = true);
alter view public.latest_organ_states set (security_invoker = true);
alter view public.latest_risk_scores  set (security_invoker = true);
alter view public.ai_usage_daily      set (security_invoker = true);

-- ---------------------------------------------------------------------------
-- 5. app_migrations: deny-all dichiarato (punto 7 dell'audit)
-- ---------------------------------------------------------------------------
comment on table public.app_migrations is
  'Registro delle migrazioni applicate. RLS attiva e nessuna policy: deny-all '
  'voluto. Nessun ruolo applicativo (anon, authenticated) legge o scrive; si '
  'consulta dal SQL Editor o dalle Edge Functions con il service_role, che '
  'mantiene il bypass di Supabase. Ogni migrazione aggiunge qui la propria riga.';

-- ---------------------------------------------------------------------------
-- 6. Cron con wrapper: upload appesi (punto 18 dell'audit)
--
--    Il job della 0002 chiamava direttamente expire_stale_document_uploads():
--    un errore notturno non lasciava traccia. Qui il job passa dal wrapper
--    che scrive cron_run (started, ok) o cron_error in platform_events,
--    come i wrapper della 0014.
-- ---------------------------------------------------------------------------
create or replace function public.run_expire_stale_document_uploads_logged()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  started timestamptz := clock_timestamp();
  n int;
begin
  perform public.platform_event('cron_run', 'expire_stale_document_uploads', 'started', '{}');
  n := public.expire_stale_document_uploads();
  perform public.platform_event('cron_run', 'expire_stale_document_uploads', 'ok',
    jsonb_build_object('rows', n,
      'duration_ms', extract(milliseconds from clock_timestamp() - started)::int));
  return n;
exception when others then
  perform public.platform_event('cron_error', 'expire_stale_document_uploads', 'error',
    jsonb_build_object('code', sqlstate,
      'duration_ms', extract(milliseconds from clock_timestamp() - started)::int));
  raise;
end;
$$;

revoke execute on function public.run_expire_stale_document_uploads_logged()
  from public, anon, authenticated;
grant execute on function public.run_expire_stale_document_uploads_logged() to service_role;

comment on function public.run_expire_stale_document_uploads_logged() is
  'Wrapper del job delle 03:15: segna in platform_events l''inizio, l''esito e '
  'l''eventuale errore della chiusura degli upload rimasti appesi.';

-- ---------------------------------------------------------------------------
-- 7. Purge degli account cancellati (punti 19 e 20 dell'audit)
--
--    Due difetti insieme: la funzione non era schedulata (art. 17 GDPR
--    disatteso) e la cancellazione da auth.users sbatteva contro le guardie
--    append-only del modulo Medico. Peggio: moltissime tabelle del dominio
--    clinico (observations, organ_states, risk_scores, alerts, symptoms,
--    extractions, documents, consents...) portano subject_id o owner_id
--    senza una chiave esterna in cascata da auth.users, oppure con una
--    cascata "restrict": la riga sopravviveva all'account. Il diritto
--    all'oblio si esercita quindi con una cancellazione esplicita, tabella
--    per tabella, dentro purge_subject_data.
-- ---------------------------------------------------------------------------

-- 7a. Le tre guardie append-only ammettono il DELETE sotto l'interruttore di
--     purge, oltre ai loro interruttori attuali. risk_scores non ne aveva
--     nessuno: medical24.allow_purge e' il suo unico varco, e si apre solo
--     dentro purge_subject_data. Il "set search_path" va ripetuto qui: un
--     "create or replace" azzera la configurazione della funzione.
create or replace function public.observations_append_only()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('medical24.allow_observation_write', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE'
     and coalesce(current_setting('medical24.allow_purge', true), 'off') = 'on' then
    return old;
  end if;
  raise exception 'observations_append_only' using errcode = '42501';
end;
$$;
revoke execute on function public.observations_append_only() from public, anon, authenticated;

create or replace function public.organ_states_append_only()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if current_setting('medical24.allow_organ_state_write', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE'
     and coalesce(current_setting('medical24.allow_purge', true), 'off') = 'on' then
    return old;
  end if;
  raise exception 'organ_states_append_only' using errcode = '42501';
end;
$$;
revoke execute on function public.organ_states_append_only() from public, anon, authenticated;

create or replace function public.risk_scores_append_only()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'DELETE'
     and coalesce(current_setting('medical24.allow_purge', true), 'off') = 'on' then
    return old;
  end if;
  raise exception 'risk_scores_append_only' using errcode = '42501';
end;
$$;
revoke execute on function public.risk_scores_append_only() from public, anon, authenticated;

-- 7b. purge_subject_data: la cancellazione completa dei dati di un soggetto.
--
--     L'ordine conta. Si parte dalle foglie del modulo Medico e si risale:
--     le osservazioni vanno rimosse prima dei documenti e delle estrazioni,
--     perche' le loro chiavi sono "on delete set null" e un aggiornamento
--     sarebbe respinto dalla guardia append-only. Lo stesso vale per
--     dossier_snapshots rispetto a share_links.
--
--     audit_log non compare in elenco: il registro degli accessi sopravvive
--     all'account, e' la prova che la cancellazione e' avvenuta. Non porta
--     ne' dati clinici ne' dati di contatto.
create or replace function public.purge_subject_data(p_subject uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result  jsonb := '{}'::jsonb;
  v_targets text[] := array[
    -- modulo Medico (M9): prima lo snapshot, poi il registro, poi i link
    'dossier_snapshots',      'subject_id = $1',
    'questions',              'subject_id = $1',
    'share_link_opens',       'share_link_id in (select id from public.share_links where subject_id = $1)',
    'share_links',            'subject_id = $1',
    'emergency_cards',        'subject_id = $1',
    -- spiegazioni e consumi dell'IA
    'explanations',           'subject_id = $1',
    'explanation_usage',      'subject_id = $1',
    'analysis_usage',         'subject_id = $1',
    -- motore: avvisi, esami consigliati, questionari, punteggi, organi
    'alerts',                 'subject_id = $1',
    'recommendations',        'subject_id = $1',
    'questionnaire_answers',  'subject_id = $1',
    'risk_scores',            'subject_id = $1',
    'organ_states',           'subject_id = $1',
    -- valori clinici: prima delle estrazioni e dei documenti
    'observations',           'subject_id = $1',
    'biomarker_watch',        'subject_id = $1',
    'symptoms',               'subject_id = $1',
    'extractions',            'subject_id = $1',
    -- archivio
    'document_pages',         'document_id in (select id from public.documents where subject_id = $1)',
    'documents',              'subject_id = $1 or owner_id = $1',
    -- soglie personali del medico su questo soggetto e consensi
    'threshold_overrides',    'subject_id = $1',
    'consents',               'user_id = $1'
  ];
  v_table text;
  v_where text;
  v_rows  bigint;
  i       int;
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;

  perform set_config('medical24.allow_purge', 'on', true);

  i := 1;
  while i < array_length(v_targets, 1) loop
    v_table := v_targets[i];
    v_where := v_targets[i + 1];
    i := i + 2;

    -- Tabelle previste dal piano ma non ancora presenti nello schema
    -- (explanation_usage, analysis_usage) vengono semplicemente saltate.
    if to_regclass('public.' || quote_ident(v_table)) is null then
      continue;
    end if;

    execute format('delete from public.%I where %s', v_table, v_where) using p_subject;
    get diagnostics v_rows = row_count;
    v_result := v_result || jsonb_build_object(v_table, v_rows);
  end loop;

  perform set_config('medical24.allow_purge', 'off', true);
  return v_result;
exception when others then
  -- L'interruttore non resta mai aperto: nemmeno quando la purge fallisce a
  -- meta' strada e il resto della transazione prosegue.
  perform set_config('medical24.allow_purge', 'off', true);
  raise;
end;
$$;

revoke execute on function public.purge_subject_data(uuid)
  from public, anon, authenticated, service_role;

comment on function public.purge_subject_data(uuid) is
  'Diritto all''oblio: cancella tutte le righe del soggetto dalle tabelle che '
  'portano subject_id o owner_id senza cascata utile da auth.users, '
  'nell''ordine imposto dalle chiavi esterne e dalle guardie append-only. '
  'Alza medical24.allow_purge per il tempo della sola cancellazione e lo '
  'rimette a ''off'' anche in caso di errore. Restituisce {tabella: righe}. '
  'audit_log non viene toccato. Nessun ruolo applicativo puo'' eseguirla: la '
  'chiama soltanto purge_deleted_accounts, che le appartiene.';

create or replace function public.purge_deleted_accounts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  purged integer := 0;
  r record;
  v_summary jsonb;
  v_details_col text;
begin
  -- audit_log oggi non ha una colonna di dettagli: se un domani ne avra' una
  -- (details, metadata o payload) il riepilogo per tabella ci finisce dentro,
  -- altrimenti resta la sola riga.
  select column_name into v_details_col
    from information_schema.columns
   where table_schema = 'public'
     and table_name = 'audit_log'
     and column_name in ('details', 'metadata', 'payload')
   order by array_position(array['details', 'metadata', 'payload'], column_name)
   limit 1;

  for r in
    select id from public.profiles
     where deleted_at is not null
       and deleted_at < now() - interval '30 days'
  loop
    v_summary := public.purge_subject_data(r.id);

    -- La riga di audit precede la cancellazione dell'utente: l'attore e'
    -- nullo (nessun JWT, e' il cron), il soggetto e' l'account che sparisce.
    -- audit_log non ha vincoli verso auth.users su subject_id, quindi la
    -- riga sopravvive.
    if v_details_col is not null then
      execute format(
        'insert into public.audit_log (actor_id, action, target_table, target_id, subject_id, %I) '
        'values (null, ''account.purged'', ''profiles'', $1, $1, $2)', v_details_col)
        using r.id, v_summary;
    else
      insert into public.audit_log (actor_id, action, target_table, target_id, subject_id)
      values (null, 'account.purged', 'profiles', r.id, r.id);
    end if;

    perform set_config('medical24.allow_purge', 'on', true);
    delete from auth.users where id = r.id;
    perform set_config('medical24.allow_purge', 'off', true);

    purged := purged + 1;
  end loop;

  return purged;
exception when others then
  perform set_config('medical24.allow_purge', 'off', true);
  raise;
end;
$$;

revoke execute on function public.purge_deleted_accounts()
  from public, anon, authenticated;
grant execute on function public.purge_deleted_accounts() to service_role;

comment on function public.purge_deleted_accounts() is
  'Cancella gli account con profiles.deleted_at piu'' vecchio di trenta giorni. '
  'Per ciascuno chiama purge_subject_data (cancellazione esplicita di tutte le '
  'tabelle del soggetto), scrive una riga di audit ''account.purged'' con il '
  'riepilogo quando audit_log ha una colonna di dettagli, infine rimuove la '
  'riga da auth.users con medical24.allow_purge alzato per il tempo della sola '
  'delete. Restituisce il numero di account cancellati. Solo service_role.';

create or replace function public.run_purge_deleted_accounts_logged()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  started timestamptz := clock_timestamp();
  n int;
begin
  perform public.platform_event('cron_run', 'purge_deleted_accounts', 'started', '{}');
  n := public.purge_deleted_accounts();
  perform public.platform_event('cron_run', 'purge_deleted_accounts', 'ok',
    jsonb_build_object('rows', n,
      'duration_ms', extract(milliseconds from clock_timestamp() - started)::int));
  return n;
exception when others then
  perform public.platform_event('cron_error', 'purge_deleted_accounts', 'error',
    jsonb_build_object('code', sqlstate,
      'duration_ms', extract(milliseconds from clock_timestamp() - started)::int));
  raise;
end;
$$;

revoke execute on function public.run_purge_deleted_accounts_logged()
  from public, anon, authenticated;
grant execute on function public.run_purge_deleted_accounts_logged() to service_role;

comment on function public.run_purge_deleted_accounts_logged() is
  'Wrapper del job delle 04:40: registra in platform_events quanti account '
  'sono stati cancellati, oppure l''errore con il suo sqlstate.';

-- ---------------------------------------------------------------------------
-- 8. Rischedulazione dei due job sui wrapper
-- ---------------------------------------------------------------------------
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job
     where jobname in ('expire-stale-document-uploads', 'purge-deleted-accounts');
    perform cron.schedule('expire-stale-document-uploads', '15 3 * * *',
      'select public.run_expire_stale_document_uploads_logged();');
    perform cron.schedule('purge-deleted-accounts', '40 4 * * *',
      'select public.run_purge_deleted_accounts_logged();');
  end if;
exception when undefined_table or invalid_schema_name then null;
end $$;

-- ---------------------------------------------------------------------------
-- 9. Bucket dichiarati in migrazione (punti 22 e 23 dell'audit)
--
--    'dossiers' nasceva a runtime dentro la Edge Function dossier-pdf: un
--    bucket creato dal codice non ha storia e non ha policy. Qui e' dichiarato
--    privato, con tetto di 10 MB e un solo MIME ammesso; nessuna policy per
--    anon o authenticated, perche' i PDF si raggiungono soltanto con il
--    service_role o con un URL firmato a tempo.
--    'brand' e' l'opposto: pubblico e di sola lettura, contiene il logo.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('dossiers', 'dossiers', false, 10485760, array['application/pdf'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public)
values ('brand', 'brand', true)
on conflict (id) do update
  set public = excluded.public;

-- Nessuna policy su 'dossiers': senza policy, anon e authenticated non vedono
-- nulla. Il service_role mantiene il bypass di Supabase.
drop policy if exists dossiers_storage_select on storage.objects;
drop policy if exists dossiers_storage_insert on storage.objects;

-- 'brand': sola lettura, per chiunque, limitata al bucket.
drop policy if exists brand_storage_select on storage.objects;
create policy brand_storage_select on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'brand');

insert into public.app_migrations(name) values ('0026_hardening_schema')
  on conflict do nothing;
