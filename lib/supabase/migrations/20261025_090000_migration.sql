-- ============================================================================
-- Medical 24 — 0005 ENGINE SCHEMA (P02-A) · modulo M3 Motore di estrazione
--
-- Contenuto:
--   1. enum: extraction_status, observation_origin, observation_flag,
--            catalog_status
--   2. biomarker_catalog (riferimento istituzionale del board)
--   3. extractions (output IA grezzo, append di righe per documento)
--   4. observations (append-only, un valore clinico per riga)
--   5. funzioni: normalize_unit, resolve_reference, resolve_flag,
--                confirm_observation, analysis_usage, start_extraction,
--                document_needs_extraction
--   6. RLS forzata, policy, grants
--   7. pg_cron notturno: coda dei documenti da estrarre
--
-- Nessuna riga di catalogo viene inserita qui: il seed sta nella 0006.
-- Nessuna policy del P00/P01 viene modificata.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- 1. Enum
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'extraction_status') then
    create type extraction_status as enum (
      'queued', 'classifying', 'extracting', 'normalizing',
      'done', 'needs_review', 'failed'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'observation_origin') then
    create type observation_origin as enum (
      'document', 'manual', 'device'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'observation_flag') then
    create type observation_flag as enum (
      'below', 'within', 'above', 'critical_low', 'critical_high', 'unknown'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'catalog_status') then
    create type catalog_status as enum ('draft', 'validated', 'retired');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. biomarker_catalog
--    Lettura pubblica (anche anon: è contenuto istituzionale, non clinico
--    personale); scrittura solo al ruolo board e al service_role.
-- ---------------------------------------------------------------------------
create table if not exists public.biomarker_catalog (
  code              text primary key,
  name_it           text not null,
  name_en           text not null,
  synonyms_it       text[] not null default '{}',
  synonyms_en       text[] not null default '{}',
  category          text not null,
  unit_canonical    text not null,
  unit_alternatives jsonb not null default '{}'::jsonb,
  ref_low_m         numeric,
  ref_high_m        numeric,
  ref_low_f         numeric,
  ref_high_f        numeric,
  age_note          text,
  plausible_min     numeric,
  plausible_max     numeric,
  safety_low        numeric,
  safety_high       numeric,
  organs            text[] not null default '{}',
  notes             text,
  status            catalog_status not null default 'draft',
  board_version     int not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on table public.biomarker_catalog is
  'Catalogo biomarcatori del board: codice LOINC, sinonimi, unità UCUM, '
  'conversioni, intervalli istituzionali e limiti di sicurezza. '
  'status = draft finché il board non valida la riga.';

comment on column public.biomarker_catalog.unit_alternatives is
  'Mappa "unità letta" -> fattore moltiplicativo verso unit_canonical. '
  'Il valore speciale "IFCC" indica la formula HbA1c % = (mmol/mol + 23.5) / 10.93.';

create index if not exists idx_biomarker_catalog_category
  on public.biomarker_catalog (category);
create index if not exists idx_biomarker_catalog_status
  on public.biomarker_catalog (status, board_version);
create index if not exists idx_biomarker_catalog_synonyms_it
  on public.biomarker_catalog using gin (synonyms_it);
create index if not exists idx_biomarker_catalog_synonyms_en
  on public.biomarker_catalog using gin (synonyms_en);
create index if not exists idx_biomarker_catalog_organs
  on public.biomarker_catalog using gin (organs);

drop trigger if exists trg_biomarker_catalog_updated_at on public.biomarker_catalog;
create trigger trg_biomarker_catalog_updated_at
  before update on public.biomarker_catalog
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. extractions
--    Una riga per tentativo di lettura di un documento. Il client non
--    scrive mai qui: l'inserimento passa da start_extraction(), gli
--    aggiornamenti dalla Edge Function con service_role.
-- ---------------------------------------------------------------------------
create table if not exists public.extractions (
  id               uuid primary key default gen_random_uuid(),
  document_id      uuid not null references public.documents (id) on delete cascade,
  subject_id       uuid not null,
  status           extraction_status not null default 'queued',
  attempt          int not null default 1 check (attempt >= 1),
  model            text,
  prompt_version   text,
  raw              jsonb,
  detected_category document_category,
  detected_date    date,
  lab_name         text,
  mean_confidence  numeric check (mean_confidence is null
                                  or (mean_confidence >= 0 and mean_confidence <= 1)),
  tokens_in        int,
  tokens_out       int,
  cost_micro_usd   bigint,
  values_total     int not null default 0,
  values_saved     int not null default 0,
  values_to_review int not null default 0,
  failure_reason   text,
  started_at       timestamptz,
  finished_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

comment on table public.extractions is
  'Output IA grezzo per documento: modello, versione del prompt, confidenza '
  'media, token e costo. Nessun contenuto clinico viene loggato altrove.';

create index if not exists idx_extractions_document
  on public.extractions (document_id, created_at desc);
create index if not exists idx_extractions_subject
  on public.extractions (subject_id, created_at desc);
create index if not exists idx_extractions_status
  on public.extractions (status, created_at);

drop trigger if exists trg_extractions_updated_at on public.extractions;
create trigger trg_extractions_updated_at
  before update on public.extractions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4. observations — append-only
--    Nessun update, nessun delete: una correzione è una nuova riga che
--    sostituisce la precedente con supersedes_id (scritta da
--    confirm_observation).
-- ---------------------------------------------------------------------------
create table if not exists public.observations (
  id              uuid primary key default gen_random_uuid(),
  subject_id      uuid not null,
  code            text not null,
  display_name    text not null default '',
  value_num       numeric,
  value_text      text,
  unit            text,
  value_raw       numeric,
  unit_raw        text,
  lab_low         numeric,
  lab_high        numeric,
  ref_low         numeric,
  ref_high        numeric,
  flag            observation_flag not null default 'unknown',
  effective_at    timestamptz not null,
  origin          observation_origin not null default 'document',
  document_id     uuid references public.documents (id) on delete set null,
  extraction_id   uuid references public.extractions (id) on delete set null,
  confidence      numeric check (confidence is null
                                 or (confidence >= 0 and confidence <= 1)),
  needs_review    boolean not null default false,
  confirmed_at    timestamptz,
  confirmed_by    uuid references auth.users (id) on delete set null,
  supersedes_id   uuid references public.observations (id) on delete set null,
  superseded_at   timestamptz,
  catalog_version int not null default 0,
  rule_version    text not null default 'board-0',
  lab_name        text,
  created_at      timestamptz not null default now(),
  constraint observations_has_value
    check (value_num is not null or nullif(btrim(coalesce(value_text, '')), '') is not null)
);

comment on table public.observations is
  'Un valore clinico per riga, append-only. Nessun valore si sovrascrive: '
  'una correzione crea una riga nuova con supersedes_id.';

create index if not exists idx_observations_subject_code_time
  on public.observations (subject_id, code, effective_at desc);
create index if not exists idx_observations_document
  on public.observations (document_id);
create index if not exists idx_observations_extraction
  on public.observations (extraction_id);
create index if not exists idx_observations_review
  on public.observations (subject_id)
  where needs_review and superseded_at is null;

-- Append-only: il database rifiuta update e delete da qualunque ruolo
-- diverso da quelli che passano dalle funzioni security definer.
create or replace function public.observations_append_only()
returns trigger
language plpgsql
as $$
begin
  if current_setting('medical24.allow_observation_write', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception 'observations_append_only' using errcode = '42501';
end;
$$;

drop trigger if exists trg_observations_append_only on public.observations;
create trigger trg_observations_append_only
  before update or delete on public.observations
  for each row execute function public.observations_append_only();

-- ---------------------------------------------------------------------------
-- 5a. normalize_unit: valore letto + unità letta -> unità canonica
-- ---------------------------------------------------------------------------
create or replace function public.normalize_unit(
  p_code  text,
  p_value numeric,
  p_unit  text
)
returns table (value_num numeric, unit text, converted boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_canonical text;
  v_alts      jsonb;
  v_factor    text;
  v_read      text;
begin
  if p_value is null then
    return query select null::numeric, p_unit, false;
    return;
  end if;

  select c.unit_canonical, c.unit_alternatives
    into v_canonical, v_alts
  from public.biomarker_catalog c
  where c.code = p_code;

  if v_canonical is null then
    return query select p_value, p_unit, false;
    return;
  end if;

  v_read := btrim(coalesce(p_unit, ''));

  -- Unità assente o già canonica: nessuna conversione.
  if v_read = '' or lower(v_read) = lower(v_canonical) then
    return query select p_value, v_canonical, false;
    return;
  end if;

  -- Ricerca case-insensitive della chiave nelle alternative.
  select key into v_read
  from jsonb_object_keys(coalesce(v_alts, '{}'::jsonb)) as key
  where lower(key) = lower(btrim(coalesce(p_unit, '')))
  limit 1;

  if v_read is null then
    -- Unità sconosciuta: il valore resta grezzo e andrà verificato.
    return query select p_value, btrim(coalesce(p_unit, '')), false;
    return;
  end if;

  v_factor := v_alts ->> v_read;

  if v_factor = 'IFCC' then
    -- HbA1c: % = (mmol/mol + 23.5) / 10.93
    return query select round((p_value + 23.5) / 10.93, 4), v_canonical, true;
    return;
  end if;

  return query
    select round(p_value * (v_factor)::numeric, 6), v_canonical, true;
end;
$$;

comment on function public.normalize_unit(text, numeric, text) is
  'Converte un valore letto nell''unità canonica del catalogo. '
  'Se il codice o l''unità non sono noti il valore resta invariato.';

-- ---------------------------------------------------------------------------
-- 5b. resolve_reference: intervallo istituzionale per soggetto e codice
--     Livello istituzionale (board). Il livello laboratorio arriva dal
--     referto, il livello medico dal P12 (threshold_overrides).
-- ---------------------------------------------------------------------------
create or replace function public.resolve_reference(
  p_subject_id uuid,
  p_code       text
)
returns table (ref_low numeric, ref_high numeric, safety_low numeric,
               safety_high numeric, board_version int)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_gender text;
  c        record;
begin
  select c2.* into c
  from public.biomarker_catalog c2
  where c2.code = p_code;

  if not found then
    return;
  end if;

  select p.gender into v_gender
  from public.profiles p
  where p.id = p_subject_id;

  if v_gender = 'male' then
    return query select c.ref_low_m, c.ref_high_m, c.safety_low, c.safety_high, c.board_version;
  elsif v_gender = 'female' then
    return query select c.ref_low_f, c.ref_high_f, c.safety_low, c.safety_high, c.board_version;
  else
    -- Genere other / undisclosed / assente: unione dei due intervalli.
    return query select
      least(coalesce(c.ref_low_m, c.ref_low_f), coalesce(c.ref_low_f, c.ref_low_m)),
      greatest(coalesce(c.ref_high_m, c.ref_high_f), coalesce(c.ref_high_f, c.ref_high_m)),
      c.safety_low, c.safety_high, c.board_version;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5c. resolve_flag: posizione del valore rispetto alle soglie
--
-- SCELTA PROVVISORIA DA FAR VALIDARE AL BOARD (24/10/2026).
-- Genere 'other', 'undisclosed' o mancante, oppure età mancante: si usa
-- l'UNIONE dei due intervalli maschile e femminile.
--   - dentro entrambi            -> within
--   - fuori da entrambi, stesso lato -> below oppure above
--   - dentro uno e fuori dall'altro  -> unknown
-- I limiti di sicurezza del board (safety_low / safety_high) prevalgono
-- sempre: oltre quelli il flag è critical_low o critical_high e nessuna
-- soglia del medico potrà spegnerlo (P12).
-- ---------------------------------------------------------------------------
create or replace function public.resolve_flag(
  p_subject_id uuid,
  p_code       text,
  p_value      numeric
)
returns observation_flag
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_gender text;
  c        record;
  lo_m numeric; hi_m numeric; lo_f numeric; hi_f numeric;
  in_m boolean; in_f boolean;
  below_m boolean; below_f boolean;
  above_m boolean; above_f boolean;
  lo numeric; hi numeric;
begin
  if p_value is null then
    return 'unknown';
  end if;

  select c2.* into c from public.biomarker_catalog c2 where c2.code = p_code;
  if not found then
    return 'unknown';
  end if;

  -- 1. Limiti di sicurezza: hanno sempre la precedenza.
  if c.safety_low is not null and p_value < c.safety_low then
    return 'critical_low';
  end if;
  if c.safety_high is not null and p_value > c.safety_high then
    return 'critical_high';
  end if;

  select p.gender into v_gender from public.profiles p where p.id = p_subject_id;

  if v_gender in ('male', 'female') then
    if v_gender = 'male' then
      lo := c.ref_low_m; hi := c.ref_high_m;
    else
      lo := c.ref_low_f; hi := c.ref_high_f;
    end if;
    if lo is null and hi is null then
      return 'unknown';
    end if;
    if lo is not null and p_value < lo then return 'below'; end if;
    if hi is not null and p_value > hi then return 'above'; end if;
    return 'within';
  end if;

  -- 2. Genere non dichiarato: unione dei due intervalli.
  lo_m := c.ref_low_m; hi_m := c.ref_high_m;
  lo_f := c.ref_low_f; hi_f := c.ref_high_f;

  if lo_m is null and hi_m is null and lo_f is null and hi_f is null then
    return 'unknown';
  end if;

  below_m := lo_m is not null and p_value < lo_m;
  above_m := hi_m is not null and p_value > hi_m;
  below_f := lo_f is not null and p_value < lo_f;
  above_f := hi_f is not null and p_value > hi_f;

  in_m := (lo_m is not null or hi_m is not null) and not below_m and not above_m;
  in_f := (lo_f is not null or hi_f is not null) and not below_f and not above_f;

  if in_m and in_f then return 'within'; end if;
  if below_m and below_f then return 'below'; end if;
  if above_m and above_f then return 'above'; end if;

  -- Un solo intervallo definito: vale quello.
  if (lo_m is null and hi_m is null) then
    if below_f then return 'below'; end if;
    if above_f then return 'above'; end if;
    return 'within';
  end if;
  if (lo_f is null and hi_f is null) then
    if below_m then return 'below'; end if;
    if above_m then return 'above'; end if;
    return 'within';
  end if;

  -- Dentro uno e fuori dall'altro.
  return 'unknown';
end;
$$;

-- ---------------------------------------------------------------------------
-- 5d. start_extraction: unico modo in cui il client mette un documento
--     in coda. Rifiuta se il documento non è accessibile o non è
--     nello stato giusto, ed evita code doppie.
-- ---------------------------------------------------------------------------
create or replace function public.start_extraction(p_document_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subject uuid;
  v_status  document_status;
  v_open    uuid;
  v_attempt int;
  v_id      uuid;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  select d.subject_id, d.status into v_subject, v_status
  from public.documents d
  where d.id = p_document_id and d.deleted_at is null;

  if v_subject is null or not public.can_access_subject(v_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if v_status = 'uploading' then
    raise exception 'document_not_ready' using errcode = 'P0001';
  end if;

  select e.id into v_open
  from public.extractions e
  where e.document_id = p_document_id
    and e.status in ('queued', 'classifying', 'extracting', 'normalizing')
  order by e.created_at desc
  limit 1;

  if v_open is not null then
    return v_open;
  end if;

  select coalesce(max(e.attempt), 0) + 1 into v_attempt
  from public.extractions e
  where e.document_id = p_document_id;

  insert into public.extractions (document_id, subject_id, status, attempt)
  values (p_document_id, v_subject, 'queued', v_attempt)
  returning id into v_id;

  update public.documents
     set status = 'processing', failure_reason = null
   where id = p_document_id;

  perform public.log_audit(
    'extraction.queued', 'extractions', v_id, v_subject, null
  );

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5e. confirm_observation: passo 5 della pipeline. L'utente conferma il
--     valore letto o lo corregge; in entrambi i casi nasce una riga nuova
--     e la precedente resta nello storico, marcata superseded_at.
-- ---------------------------------------------------------------------------
create or replace function public.confirm_observation(
  p_observation_id uuid,
  p_value_num      numeric default null,
  p_unit           text    default null,
  p_value_text     text    default null,
  p_effective_at   timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  o          record;
  v_value    numeric;
  v_unit     text;
  v_norm     record;
  v_ref      record;
  v_new_id   uuid;
  v_changed  boolean;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  select * into o from public.observations where id = p_observation_id;
  if not found or not public.can_access_subject(o.subject_id) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if o.superseded_at is not null then
    raise exception 'observation_superseded' using errcode = 'P0001';
  end if;

  v_value := coalesce(p_value_num, o.value_raw, o.value_num);
  v_unit  := coalesce(p_unit, o.unit_raw, o.unit);

  select n.value_num, n.unit into v_norm
  from public.normalize_unit(o.code, v_value, v_unit) n;

  select r.ref_low, r.ref_high, r.board_version into v_ref
  from public.resolve_reference(o.subject_id, o.code) r;

  v_changed := p_value_num is distinct from null
            or p_unit is distinct from null
            or p_value_text is distinct from null
            or p_effective_at is distinct from null;

  insert into public.observations (
    subject_id, code, display_name, value_num, value_text, unit,
    value_raw, unit_raw, lab_low, lab_high, ref_low, ref_high, flag,
    effective_at, origin, document_id, extraction_id, confidence,
    needs_review, confirmed_at, confirmed_by, supersedes_id,
    catalog_version, rule_version, lab_name
  )
  values (
    o.subject_id, o.code, o.display_name,
    v_norm.value_num,
    coalesce(p_value_text, o.value_text),
    v_norm.unit,
    v_value, v_unit, o.lab_low, o.lab_high,
    v_ref.ref_low, v_ref.ref_high,
    public.resolve_flag(o.subject_id, o.code, v_norm.value_num),
    coalesce(p_effective_at, o.effective_at),
    o.origin, o.document_id, o.extraction_id,
    case when v_changed then 1.0 else o.confidence end,
    false, now(), auth.uid(), o.id,
    coalesce(v_ref.board_version, o.catalog_version), o.rule_version, o.lab_name
  )
  returning id into v_new_id;

  perform set_config('medical24.allow_observation_write', 'on', true);
  update public.observations
     set superseded_at = now()
   where id = o.id;
  perform set_config('medical24.allow_observation_write', 'off', true);

  perform public.log_audit(
    case when v_changed then 'observation.corrected' else 'observation.confirmed' end,
    'observations', v_new_id, o.subject_id, null
  );

  -- Se non restano valori da verificare, il documento è analizzato.
  if not exists (
    select 1 from public.observations ob
    where ob.document_id = o.document_id
      and ob.needs_review
      and ob.superseded_at is null
  ) and o.document_id is not null then
    update public.documents set status = 'analyzed'
     where id = o.document_id and status = 'needs_review';
  end if;

  return v_new_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5f. analysis_usage: quante analisi ha consumato il soggetto nel mese
--     corrente e qual è il massimo del piano. P02: 30 per tutti; il P09
--     collegherà il limite a platform_settings e subscriptions.
-- ---------------------------------------------------------------------------
create or replace function public.analysis_limit(p_user_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select 30;
$$;

create or replace function public.analysis_usage()
returns table (used int, max int)
language sql
stable
security invoker
set search_path = public
as $$
  select
    (
      select count(*)::int
      from public.extractions e
      where e.subject_id = auth.uid()
        and e.created_at >= date_trunc('month', now())
        and e.status <> 'failed'
    ) as used,
    public.analysis_limit(auth.uid()) as max;
$$;

-- ---------------------------------------------------------------------------
-- 5g. document_needs_extraction: documenti pronti e mai letti.
--     Usata dal batch notturno (service_role) e dai test.
-- ---------------------------------------------------------------------------
create or replace function public.documents_pending_extraction(p_limit int default 50)
returns table (document_id uuid, subject_id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select d.id, d.subject_id
  from public.documents d
  where d.deleted_at is null
    and d.status = 'uploaded'
    and not exists (
      select 1 from public.extractions e
      where e.document_id = d.id
        and e.status in ('queued', 'classifying', 'extracting', 'normalizing', 'done', 'needs_review')
    )
  order by d.created_at
  limit greatest(coalesce(p_limit, 50), 1);
$$;

revoke execute on function public.documents_pending_extraction(int) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5h. enqueue_pending_extractions: il batch notturno mette in coda i
--     documenti arretrati. Nessuna chiamata IA qui: la Edge Function
--     extract-batch-poll preleva le righe queued.
-- ---------------------------------------------------------------------------
create or replace function public.enqueue_pending_extractions(p_limit int default 50)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  r       record;
  queued  int := 0;
begin
  for r in select * from public.documents_pending_extraction(p_limit) loop
    insert into public.extractions (document_id, subject_id, status, attempt)
    values (r.document_id, r.subject_id, 'queued', 1);

    update public.documents set status = 'processing'
     where id = r.document_id and status = 'uploaded';

    queued := queued + 1;
  end loop;
  return queued;
end;
$$;

revoke execute on function public.enqueue_pending_extractions(int) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. RLS
-- ---------------------------------------------------------------------------
alter table public.biomarker_catalog enable row level security;
alter table public.extractions       enable row level security;
alter table public.observations      enable row level security;
alter table public.extractions       force  row level security;
alter table public.observations      force  row level security;

-- biomarker_catalog: lettura a chiunque, scrittura solo al board.
drop policy if exists biomarker_catalog_select on public.biomarker_catalog;
create policy biomarker_catalog_select on public.biomarker_catalog
  for select to anon, authenticated
  using (true);

drop policy if exists biomarker_catalog_write on public.biomarker_catalog;
create policy biomarker_catalog_write on public.biomarker_catalog
  for all to authenticated
  using (public.has_role('board'))
  with check (public.has_role('board'));

-- extractions: lettura di chi può accedere al soggetto. Nessun insert,
-- update o delete per authenticated: si passa da start_extraction() e
-- dalle Edge Functions con service_role.
drop policy if exists extractions_select on public.extractions;
create policy extractions_select on public.extractions
  for select to authenticated
  using (public.can_access_subject(subject_id));

-- observations: sola lettura per authenticated. L'inserimento manuale
-- arriva nel P03 con la sua policy; oggi si scrive solo dalle funzioni
-- security definer e dalle Edge Functions.
drop policy if exists observations_select on public.observations;
create policy observations_select on public.observations
  for select to authenticated
  using (public.can_access_subject(subject_id));

-- ---------------------------------------------------------------------------
-- 7. Grants
-- ---------------------------------------------------------------------------
revoke all on public.extractions, public.observations from anon;
revoke all on public.biomarker_catalog from anon;
grant select on public.biomarker_catalog to anon, authenticated;
grant select on public.extractions  to authenticated;
grant select on public.observations to authenticated;
grant insert, update, delete on public.biomarker_catalog to authenticated;

-- Supabase concede ALL su public a authenticated con le default privileges:
-- qui si toglie tutto ciò che non deve passare dal client. L'inserimento
-- manuale di observations arriva nel P03 con la sua policy.
revoke insert, update, delete on public.observations from authenticated;
revoke insert, update, delete on public.extractions  from authenticated;

grant execute on function public.normalize_unit(text, numeric, text) to authenticated;
grant execute on function public.resolve_reference(uuid, text) to authenticated;
grant execute on function public.resolve_flag(uuid, text, numeric) to authenticated;
grant execute on function public.start_extraction(uuid) to authenticated;
grant execute on function public.confirm_observation(uuid, numeric, text, text, timestamptz) to authenticated;
grant execute on function public.analysis_usage() to authenticated;
grant execute on function public.analysis_limit(uuid) to authenticated;

revoke execute on function public.normalize_unit(text, numeric, text) from anon;
revoke execute on function public.resolve_reference(uuid, text) from anon;
revoke execute on function public.resolve_flag(uuid, text, numeric) from anon;
revoke execute on function public.start_extraction(uuid) from anon;
revoke execute on function public.confirm_observation(uuid, numeric, text, text, timestamptz) from anon;
revoke execute on function public.analysis_usage() from anon;
revoke execute on function public.analysis_limit(uuid) from anon;
revoke execute on function public.observations_append_only() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8. Realtime: la schermata segue lo stato dell'estrazione.
--    Le righe restano filtrate dalla RLS.
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'extractions'
    ) then
      alter publication supabase_realtime add table public.extractions;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'observations'
    ) then
      alter publication supabase_realtime add table public.observations;
    end if;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9. pg_cron: coda notturna dei documenti arretrati (03:45)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('enqueue-pending-extractions')
      where exists (
        select 1 from cron.job where jobname = 'enqueue-pending-extractions'
      );
    perform cron.schedule(
      'enqueue-pending-extractions',
      '45 3 * * *',
      $cron$select public.enqueue_pending_extractions(200)$cron$
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 10. Registro
-- ---------------------------------------------------------------------------
insert into public.app_migrations (name)
values ('0005_engine_schema_20261025_090000')
on conflict do nothing;
