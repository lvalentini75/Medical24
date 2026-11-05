-- ============================================================================
-- Medical 24 — 0027 DATA EXPORTS (P10-A3-1)
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- Portabilita' dei dati (art. 20 GDPR): la richiesta di export, il suo esito e
-- il file prodotto. Lo schema e le funzioni; nessuna Edge Function, nessuna
-- schermata. Il pacchetto .zip lo costruisce una funzione di servizio che
-- chiama data_export_finish con il service_role, e la URL firmata la produce
-- la Edge Function: qui dentro non esce mai un indirizzo.
--
--   data_export_status            enum pending/ready/failed/expired
--   data_exports                  una riga per richiesta, RLS forzata
--   data_export_request(uuid)     authenticated, una richiesta ogni 24 ore
--   data_export_finish(...)       solo service_role, chiude la riga
--   data_export_latest(uuid)      authenticated, l'ultima richiesta
--   bucket privato 'exports'      500 MB, solo application/zip
--   purge_subject_data            + data_exports, threshold_overrides corretta
--
-- Idempotente: enum dentro do $$ … $$, create table if not exists,
-- create or replace, drop policy if exists prima di create policy.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Enum degli stati
--
--    'expired' non viene mai scritto da data_export_finish: lo assegnera' la
--    pulizia notturna quando il file scade. Nasce qui perche' l'enum non si
--    estende senza una migrazione.
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_type where typname = 'data_export_status') then
    create type data_export_status as enum ('pending', 'ready', 'failed', 'expired');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. data_exports — una riga per richiesta
--
--    storage_path e' l'unico riferimento al file e resta dentro il database:
--    il client riceve la path soltanto da data_export_latest, e soltanto
--    finche' l'export e' pronto e non scaduto. error_code e' un codice, mai
--    un messaggio: non deve portare nomi di file o dati del soggetto.
-- ---------------------------------------------------------------------------
create table if not exists public.data_exports (
  id            uuid primary key default gen_random_uuid(),
  subject_id    uuid not null references auth.users(id) on delete cascade,
  requested_by  uuid references auth.users(id) on delete set null,
  requested_at  timestamptz not null default now(),
  status        data_export_status not null default 'pending',
  storage_path  text check (storage_path is null or char_length(storage_path) <= 400),
  bytes         bigint check (bytes is null or bytes >= 0),
  file_count    int check (file_count is null or file_count >= 0),
  truncated     boolean not null default false,
  error_code    text check (error_code is null or char_length(error_code) <= 80),
  ready_at      timestamptz,
  expires_at    timestamptz,
  created_at    timestamptz not null default now()
);

comment on table public.data_exports is
  'Richieste di export dei propri dati (art. 20 GDPR): stato, file prodotto '
  'nel bucket privato ''exports'', scadenza a sette giorni. Lettura del solo '
  'proprietario; nessuna scrittura diretta, si passa da data_export_request '
  '(authenticated) e data_export_finish (service_role).';
comment on column public.data_exports.storage_path is
  'subjects/{subject_id}/exports/{id}.zip nel bucket privato ''exports''. '
  'Esce dal database solo con data_export_latest, e solo se pronto e non '
  'scaduto; la URL firmata la produce la Edge Function.';
comment on column public.data_exports.truncated is
  'Vero quando il pacchetto non contiene tutto (tetto di dimensione o di '
  'numero di file): la schermata deve dirlo.';
comment on column public.data_exports.error_code is
  'Codice dell''errore, mai un messaggio: nessun nome di file, nessun dato '
  'del soggetto.';

create index if not exists idx_data_exports_subject_requested
  on public.data_exports (subject_id, requested_at desc);

-- ---------------------------------------------------------------------------
-- 3. RLS: forzata, una sola policy di lettura
--
--    Nessuna policy di insert, update o delete: anche con un grant sbagliato
--    authenticated non scrive. Le due funzioni sono security definer e
--    appartengono a postgres, che ha bypassrls.
-- ---------------------------------------------------------------------------
alter table public.data_exports enable row level security;
alter table public.data_exports force  row level security;

drop policy if exists data_exports_owner_select on public.data_exports;
create policy data_exports_owner_select on public.data_exports
  for select to authenticated
  using (public.can_access_subject(subject_id));

revoke all on public.data_exports from public, anon, authenticated;
grant select on public.data_exports to authenticated;

-- ---------------------------------------------------------------------------
-- 4. data_export_request — una richiesta ogni ventiquattro ore
--
--    Il freno guarda pending e ready: una richiesta fallita non consuma il
--    diritto di riprovare, una scaduta nemmeno.
-- ---------------------------------------------------------------------------
create or replace function public.data_export_request(p_subject uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_recent int;
  v_id     uuid;
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if v_uid is null or not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select count(*)::int into v_recent
    from public.data_exports e
   where e.subject_id = p_subject
     and e.status in ('pending', 'ready')
     and e.requested_at > now() - interval '24 hours';

  if coalesce(v_recent, 0) > 0 then
    raise exception 'daily_limit' using errcode = 'P0001';
  end if;

  insert into public.data_exports(subject_id, requested_by, status)
  values (p_subject, v_uid, 'pending')
  returning id into v_id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'data_export.requested', 'data_exports', v_id, p_subject);

  return v_id;
end;
$$;

revoke execute on function public.data_export_request(uuid) from public, anon;
grant execute on function public.data_export_request(uuid) to authenticated;

comment on function public.data_export_request(uuid) is
  'Crea una richiesta di export in stato pending per il soggetto indicato. '
  'Richiede can_access_subject(p_subject) (42501); p_subject nullo e'' 22023. '
  'Una sola richiesta ogni ventiquattro ore per soggetto, contando quelle '
  'pending e ready (daily_limit, P0001). Audit data_export.requested.';

-- ---------------------------------------------------------------------------
-- 5. data_export_finish — la chiude il servizio, mai il client
--
--    La path e' imposta, non suggerita: subjects/{subject_id}/exports/{id}.zip.
--    Un file scritto altrove non entra nel database.
-- ---------------------------------------------------------------------------
create or replace function public.data_export_finish(
  p_id         uuid,
  p_status     data_export_status,
  p_path       text default null,
  p_bytes      bigint default null,
  p_file_count int default null,
  p_truncated  boolean default false,
  p_error      text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  e        public.data_exports%rowtype;
  v_expect text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if p_id is null then
    raise exception 'invalid_export' using errcode = '22023';
  end if;
  if p_status is null or p_status not in ('ready', 'failed') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;

  select * into e from public.data_exports where id = p_id for update;
  if not found then
    raise exception 'invalid_export' using errcode = '22023';
  end if;

  if p_status = 'ready' then
    v_expect := 'subjects/' || e.subject_id::text || '/exports/' || e.id::text || '.zip';
    if coalesce(btrim(coalesce(p_path, '')), '') <> v_expect then
      raise exception 'invalid_path' using errcode = '22023';
    end if;

    update public.data_exports
       set status       = 'ready',
           storage_path = v_expect,
           bytes        = p_bytes,
           file_count   = p_file_count,
           truncated    = coalesce(p_truncated, false),
           error_code   = null,
           ready_at     = now(),
           expires_at   = now() + interval '7 days'
     where id = e.id;

    insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
    values (null, 'data_export.ready', 'data_exports', e.id, e.subject_id);
  else
    update public.data_exports
       set status       = 'failed',
           storage_path = null,
           bytes        = null,
           file_count   = null,
           truncated    = coalesce(p_truncated, false),
           error_code   = nullif(btrim(coalesce(p_error, '')), ''),
           ready_at     = now(),
           expires_at   = null
     where id = e.id;

    insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
    values (null, 'data_export.failed', 'data_exports', e.id, e.subject_id);
  end if;
end;
$$;

revoke execute on function
  public.data_export_finish(uuid, data_export_status, text, bigint, int, boolean, text)
  from public, anon, authenticated;
grant execute on function
  public.data_export_finish(uuid, data_export_status, text, bigint, int, boolean, text)
  to service_role;

comment on function
  public.data_export_finish(uuid, data_export_status, text, bigint, int, boolean, text) is
  'Chiude una richiesta di export: ready con expires_at a sette giorni, oppure '
  'failed con error_code. Solo service_role (42501); id sconosciuto, stato '
  'diverso da ready/failed e path diversa da '
  'subjects/{subject_id}/exports/{id}.zip sono 22023. Audit '
  'data_export.ready oppure data_export.failed, senza attore.';

-- ---------------------------------------------------------------------------
-- 6. data_export_latest — che cosa vede il proprietario
--
--    La path esce solo se l'export e' pronto e non scaduto. La URL firmata
--    non si costruisce qui: la fa la Edge Function, a tempo.
-- ---------------------------------------------------------------------------
create or replace function public.data_export_latest(p_subject uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  e public.data_exports%rowtype;
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select * into e
    from public.data_exports
   where subject_id = p_subject
   order by requested_at desc
   limit 1;

  if not found then
    return null;
  end if;

  return jsonb_build_object(
    'id',           e.id,
    'status',       e.status,
    'requested_at', e.requested_at,
    'ready_at',     e.ready_at,
    'expires_at',   e.expires_at,
    'bytes',        e.bytes,
    'file_count',   e.file_count,
    'truncated',    e.truncated,
    'error_code',   e.error_code,
    'storage_path',
      case when e.status = 'ready'
            and e.expires_at is not null
            and e.expires_at > now()
           then e.storage_path
           else null end
  );
end;
$$;

revoke execute on function public.data_export_latest(uuid) from public, anon;
grant execute on function public.data_export_latest(uuid) to authenticated, service_role;

comment on function public.data_export_latest(uuid) is
  'Ultima richiesta di export del soggetto: stato, date, byte, numero di file '
  'e truncated; la storage_path solo se l''export e'' ready e non scaduto. '
  'null se non ce n''e'' nessuna. Richiede can_access_subject (42501).';

-- ---------------------------------------------------------------------------
-- 7. Bucket privato 'exports'
--
--    Dichiarato qui come 'dossiers' nella 0026: privato, 500 MB, un solo MIME.
--    Nessuna policy per anon o authenticated: il file si raggiunge soltanto
--    con il service_role o con una URL firmata a tempo.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('exports', 'exports', false, 524288000, array['application/zip'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists exports_storage_select on storage.objects;
drop policy if exists exports_storage_insert on storage.objects;

-- ---------------------------------------------------------------------------
-- 8. purge_subject_data: due correzioni
--
--    a) data_exports entra nell'elenco. La cascata da auth.users la
--       svuoterebbe comunque, ma la purge deve restare l'elenco completo e
--       leggibile di che cosa sparisce, e deve funzionare anche quando la si
--       chiama su un soggetto il cui account resta.
--    b) threshold_overrides: il filtro guardava il solo subject_id, mentre la
--       tabella porta anche doctor_id (la soglia personale che un medico ha
--       scritto). Cancellando l'account del medico quelle righe restavano.
--
--    Per il resto la funzione e' identica alla 0026: stesso ordine, stesso
--    interruttore, stesso valore di ritorno.
-- ---------------------------------------------------------------------------
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
    -- export dei dati, soglie personali del medico e consensi
    'data_exports',           'subject_id = $1',
    'threshold_overrides',    'subject_id = $1 or doctor_id = $1',
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
  'portano subject_id, owner_id o doctor_id senza cascata utile da auth.users, '
  'nell''ordine imposto dalle chiavi esterne e dalle guardie append-only. '
  'Comprende data_exports; per threshold_overrides cancella anche le soglie '
  'scritte dal soggetto come medico. Alza medical24.allow_purge per il tempo '
  'della sola cancellazione e lo rimette a ''off'' anche in caso di errore. '
  'Restituisce {tabella: righe}. audit_log non viene toccato. Nessun ruolo '
  'applicativo puo'' eseguirla: la chiama soltanto purge_deleted_accounts.';

insert into public.app_migrations(name) values ('0027_data_exports')
  on conflict do nothing;
