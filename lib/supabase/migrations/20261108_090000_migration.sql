-- ============================================================================
-- Medical 24 — 0019 TREATMENTS WRITE (P07-A3) — modulo M8 Cure
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- Solo funzioni di SCRITTURA e MODERAZIONE sopra lo schema della 0017 e le
-- letture della 0018, che non vengono toccate. Nessuna tabella nuova, nessun
-- seed di contenuto, nessuna schermata.
--
-- Tutte le funzioni esposte sono SECURITY DEFINER: le tabelle del modulo non
-- hanno policy di scrittura (default deny della 0017), quindi la via di
-- scrittura e' una sola e i controlli stanno dentro la funzione. Ogni funzione
-- e' revocata a public e a anon e concessa a authenticated.
--
-- Funzioni esposte:
--   submit_review(...)        -> uuid     recensione dell'utente, nasce pending
--   moderate_review(...)      -> void     admin: approved | rejected
--   withdraw_review(uuid)     -> void     solo l'autore: withdrawn
--   treatment_upsert(jsonb)   -> uuid     admin: crea o aggiorna una scheda
--   treatment_set_status(...) -> void     admin: transizioni di stato
--   doctor_upsert(jsonb)      -> uuid     admin
--   facility_upsert(jsonb)    -> uuid     admin
--   toggle_favorite(...)      -> boolean  stato finale del preferito
--
-- Funzioni interne (prefisso m24_):
--   m24_require_admin()          42501 se il chiamante non e' admin
--   m24_require_auth()           42501 se non c'e' auth.uid()
--   m24_target_exists(...)       il bersaglio esiste ed e' visibile
--   m24_has_url(text)            riconosce un indirizzo web nel testo
--   m24_valid_sub_ratings(jsonb) sole chiavi ammesse, valori interi 1..5
--   m24_jsonb_text / _int / _bool  letture tipate e tolleranti dal payload
--
-- Idempotente: puo' essere rieseguita senza effetti collaterali.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Guardie e aiutanti
-- ---------------------------------------------------------------------------

create or replace function public.m24_require_auth()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  return v_uid;
end;
$$;

create or replace function public.m24_require_admin()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_uid uuid := auth.uid();
begin
  if coalesce(auth.role(), '') = 'service_role' then
    return v_uid;
  end if;
  if v_uid is null or not public.has_role('admin') then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  return v_uid;
end;
$$;

-- Il bersaglio di una recensione o di un preferito esiste ed e' visibile al
-- pubblico: cura published, medico o struttura verified oppure is_demo.
-- security definer: il controllo non dipende dalle policy del chiamante, ma
-- applica le stesse condizioni delle policy pubbliche della 0017.
create or replace function public.m24_target_exists(p_type text, p_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case p_type
    when 'treatment' then exists (
      select 1 from public.treatments t where t.id = p_id and t.status = 'published')
    when 'doctor' then exists (
      select 1 from public.doctors d where d.id = p_id and (d.verified or d.is_demo))
    when 'facility' then exists (
      select 1 from public.facilities f where f.id = p_id and (f.verified or f.is_demo))
    else false
  end;
$$;

-- Riconosce un indirizzo web: http/https, www., oppure un dominio con una
-- estensione di primo livello di due o piu' lettere.
create or replace function public.m24_has_url(p_text text)
returns boolean
language sql
immutable
as $$
  select coalesce(p_text, '') ~* '(https?://|www\.|\y[a-z0-9][a-z0-9-]*\.(com|net|org|it|eu|io|co|info|biz|me|shop|clinic|health)\y)';
$$;

-- sub_ratings: oggetto con sole chiavi efficacia, costo, esperienza, chiarezza
-- e valori numerici interi tra 1 e 5.
create or replace function public.m24_valid_sub_ratings(p_doc jsonb)
returns boolean
language sql
immutable
as $$
  select p_doc is null
      or (jsonb_typeof(p_doc) = 'object'
          and public.m24_jsonb_keys_subset(p_doc,
                array['efficacia','costo','esperienza','chiarezza'])
          and not exists (
            select 1 from jsonb_each(p_doc) as e(key, value)
            where jsonb_typeof(e.value) <> 'number'
               or (e.value #>> '{}')::numeric <> trunc((e.value #>> '{}')::numeric)
               or (e.value #>> '{}')::numeric < 1
               or (e.value #>> '{}')::numeric > 5));
$$;

-- Letture tipate dal payload: assenti o null -> null, mai eccezione di cast
-- involontaria sul percorso felice.
create or replace function public.m24_jsonb_text(p_doc jsonb, p_key text)
returns text
language sql
immutable
as $$
  select nullif(btrim(coalesce(p_doc->>p_key, '')), '');
$$;

create or replace function public.m24_jsonb_int(p_doc jsonb, p_key text)
returns int
language plpgsql
immutable
as $$
declare v text := nullif(btrim(coalesce(p_doc->>p_key, '')), '');
begin
  if v is null then return null; end if;
  if v !~ '^-?\d+$' then
    raise exception 'invalid_number: %', p_key using errcode = '22023';
  end if;
  return v::int;
end;
$$;

create or replace function public.m24_jsonb_bool(p_doc jsonb, p_key text, p_default boolean)
returns boolean
language sql
immutable
as $$
  select case
    when p_doc is null or not (p_doc ? p_key) or jsonb_typeof(p_doc->p_key) = 'null'
      then p_default
    else coalesce((p_doc->>p_key)::boolean, p_default)
  end;
$$;

-- Array di testo dal payload: accetta un array jsonb, rifiuta il resto.
create or replace function public.m24_jsonb_text_array(p_doc jsonb, p_key text)
returns text[]
language plpgsql
immutable
as $$
begin
  if p_doc is null or not (p_doc ? p_key) or jsonb_typeof(p_doc->p_key) = 'null' then
    return null;
  end if;
  if jsonb_typeof(p_doc->p_key) <> 'array' then
    raise exception 'invalid_array: %', p_key using errcode = '22023';
  end if;
  return array(select jsonb_array_elements_text(p_doc->p_key));
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. submit_review — l'unica scrittura del cittadino sulle recensioni
--    Controlli, nell'ordine: autenticazione, bersaglio, voto, sub_ratings,
--    corpo (lunghezza, URL, filtro anti-diagnosi), tetto giornaliero, unicita'.
-- ---------------------------------------------------------------------------
create or replace function public.submit_review(
  p_target_type text,
  p_target_id   uuid,
  p_rating      int,
  p_sub_ratings jsonb default '{}'::jsonb,
  p_title       text default null,
  p_body        text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := public.m24_require_auth();
  v_body  text := btrim(coalesce(p_body, ''));
  v_title text := nullif(btrim(coalesce(p_title, '')), '');
  v_sub   jsonb := coalesce(p_sub_ratings, '{}'::jsonb);
  v_today int;
  v_hit   boolean;
  v_id    uuid;
begin
  if p_target_type is null or p_target_type not in ('treatment','doctor','facility') then
    raise exception 'invalid_target_type' using errcode = '22023';
  end if;
  if p_target_id is null or not public.m24_target_exists(p_target_type, p_target_id) then
    raise exception 'target_not_found' using errcode = '22023';
  end if;
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'invalid_rating' using errcode = '22023';
  end if;
  if not public.m24_valid_sub_ratings(v_sub) then
    raise exception 'invalid_sub_ratings' using errcode = '22023';
  end if;
  if v_title is not null and char_length(v_title) > 80 then
    raise exception 'title_too_long' using errcode = '22023';
  end if;
  if char_length(v_body) < 20 or char_length(v_body) > 2000 then
    raise exception 'invalid_body_length' using errcode = '22023';
  end if;
  if public.m24_has_url(v_body) or public.m24_has_url(coalesce(v_title, '')) then
    raise exception 'url_not_allowed' using errcode = '22023';
  end if;

  -- Una recensione non e' il posto per diagnosi o terapie rivolte ad altri:
  -- stesso filtro del board usato dalle spiegazioni (regola forbidden_phrases).
  select c.matched into v_hit
    from public.check_forbidden_phrases(coalesce(v_title, '') || ' ' || v_body) c;
  if coalesce(v_hit, false) then
    raise exception 'forbidden_content' using errcode = '22023';
  end if;

  -- Tetto: cinque recensioni al giorno per autore.
  select count(*)::int into v_today
    from public.reviews r
   where r.author_id = v_uid
     and r.created_at >= date_trunc('day', now());
  if v_today >= 5 then
    raise exception 'daily_limit_reached' using errcode = 'P0001';
  end if;

  begin
    insert into public.reviews(author_id, target_type, target_id, rating,
      sub_ratings, title, body, status)
    values (v_uid, p_target_type::review_target_type, p_target_id, p_rating::smallint,
      v_sub, v_title, v_body, 'pending')
    returning id into v_id;
  exception when unique_violation then
    raise exception 'review_exists' using errcode = '23505';
  end;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'review.submitted', 'reviews', v_id, v_uid);

  return v_id;
end;
$$;

comment on function public.submit_review(text, uuid, int, jsonb, text, text) is
  'Recensione dell''utente su una cura, un medico o una struttura visibile. '
  'Nasce pending. Corpo 20-2000 caratteri, senza URL e senza i pattern della '
  'regola forbidden_phrases; massimo cinque al giorno per autore; una sola per '
  'autore e bersaglio (altrimenti review_exists, 23505).';

-- ---------------------------------------------------------------------------
-- 3. moderate_review — admin
-- ---------------------------------------------------------------------------
create or replace function public.moderate_review(
  p_id     uuid,
  p_status text,
  p_note   text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.m24_require_admin();
  r     public.reviews%rowtype;
begin
  if p_status is null or p_status not in ('approved','rejected') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;

  select * into r from public.reviews where id = p_id for update;
  if not found then
    raise exception 'review_not_found' using errcode = '22023';
  end if;
  if r.status = 'withdrawn' then
    raise exception 'review_withdrawn' using errcode = 'P0001';
  end if;

  update public.reviews
     set status = p_status::review_status,
         moderation_note = nullif(btrim(coalesce(p_note, '')), ''),
         moderated_by = v_uid,
         moderated_at = clock_timestamp()
   where id = p_id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'review.moderated', 'reviews', p_id, r.author_id);

  insert into public.platform_events(kind, source, status, details)
  values ('admin_action', 'reviews', 'review.moderated',
          jsonb_build_object('actor', v_uid, 'review', p_id, 'status', p_status));
end;
$$;

comment on function public.moderate_review(uuid, text, text) is
  'Moderazione admin di una recensione: approved o rejected, con nota, '
  'moderated_by e moderated_at. Scrive audit_log e platform_events admin_action.';

-- ---------------------------------------------------------------------------
-- 4. withdraw_review — solo l'autore
-- ---------------------------------------------------------------------------
create or replace function public.withdraw_review(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.m24_require_auth();
  r     public.reviews%rowtype;
begin
  select * into r from public.reviews where id = p_id for update;
  if not found then
    raise exception 'review_not_found' using errcode = '22023';
  end if;
  if r.author_id <> v_uid then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if r.status = 'withdrawn' then
    return;
  end if;

  update public.reviews set status = 'withdrawn' where id = p_id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'review.withdrawn', 'reviews', p_id, v_uid);
end;
$$;

comment on function public.withdraw_review(uuid) is
  'Ritiro della propria recensione: stato withdrawn. Solo l''autore (42501); '
  'il trigger della 0017 aggiorna rating_summaries.';

-- ---------------------------------------------------------------------------
-- 5. treatment_upsert — admin
--    Il payload e' un oggetto jsonb con le sole chiavi ammesse. Senza "id"
--    crea una bozza, con "id" aggiorna. Una modifica a una cura published
--    incrementa version: la scheda pubblicata non cambia in silenzio.
-- ---------------------------------------------------------------------------
create or replace function public.treatment_upsert(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.m24_require_admin();
  v_allowed text[] := array['id','title','summary','description_sections','family','scope',
    'category','conditions','tags','evidence_level','contraindications','price_from_cents',
    'price_to_cents','currency','price_notes','ssn_covered','session_minutes','sessions_count',
    'course_weeks','waiting_days','modality','requirements','expected_outcome','media',
    'doctor_id','facility_id','is_demo','featured'];
  t public.treatments%rowtype;
  v_id uuid;
  v_new boolean;
  v_missing text;
  k text;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_payload = '{}'::jsonb then
    raise exception 'invalid_payload' using errcode = '22023';
  end if;
  for k in select jsonb_object_keys(p_payload) loop
    if not (k = any(v_allowed)) then
      raise exception 'invalid_payload_key: %', k using errcode = '22023';
    end if;
  end loop;

  v_id := nullif(p_payload->>'id', '')::uuid;
  v_new := v_id is null;

  if not v_new then
    select * into t from public.treatments where id = v_id for update;
    if not found then
      raise exception 'treatment_not_found' using errcode = '22023';
    end if;
  else
    t.id := gen_random_uuid();
    t.family := 'tradizionale';
    t.scope := 'terapia';
    t.evidence_level := 'non_valutato';
    t.modality := 'presenza';
    t.description_sections := '{}'::jsonb;
    t.conditions := '{}';
    t.tags := '{}';
    t.contraindications := '[]'::jsonb;
    t.media := '[]'::jsonb;
    t.currency := 'EUR';
    t.ssn_covered := false;
    t.is_demo := false;
    t.featured := false;
    t.status := 'draft';
    t.version := 1;
  end if;

  if p_payload ? 'title' then
    t.title := public.m24_jsonb_text(p_payload, 'title');
    if t.title is null then raise exception 'invalid_title' using errcode = '22023'; end if;
  end if;
  if v_new and t.title is null then
    raise exception 'invalid_title' using errcode = '22023';
  end if;

  if p_payload ? 'summary' then
    t.summary := public.m24_jsonb_text(p_payload, 'summary');
    if t.summary is not null and char_length(t.summary) > 240 then
      raise exception 'summary_too_long' using errcode = '22023';
    end if;
  end if;

  if p_payload ? 'description_sections' then
    t.description_sections := coalesce(p_payload->'description_sections', '{}'::jsonb);
    if jsonb_typeof(t.description_sections) <> 'object'
       or not public.m24_jsonb_keys_subset(t.description_sections,
            array['per_chi','come_funziona','durata','rischi_e_controindicazioni','evidenze_e_limiti']) then
      raise exception 'invalid_description_sections' using errcode = '22023';
    end if;
  end if;

  if p_payload ? 'family' then
    t.family := public.m24_jsonb_text(p_payload, 'family')::treatment_family;
  end if;
  if p_payload ? 'scope' then
    t.scope := public.m24_jsonb_text(p_payload, 'scope')::treatment_scope;
  end if;
  if p_payload ? 'evidence_level' then
    t.evidence_level := public.m24_jsonb_text(p_payload, 'evidence_level')::treatment_evidence_level;
  end if;
  if p_payload ? 'modality' then
    t.modality := public.m24_jsonb_text(p_payload, 'modality')::treatment_modality;
  end if;

  if p_payload ? 'category' then t.category := public.m24_jsonb_text(p_payload, 'category'); end if;
  if p_payload ? 'price_notes' then t.price_notes := public.m24_jsonb_text(p_payload, 'price_notes'); end if;
  if p_payload ? 'requirements' then t.requirements := public.m24_jsonb_text(p_payload, 'requirements'); end if;
  if p_payload ? 'expected_outcome' then t.expected_outcome := public.m24_jsonb_text(p_payload, 'expected_outcome'); end if;

  if p_payload ? 'conditions' then
    t.conditions := coalesce(public.m24_jsonb_text_array(p_payload, 'conditions'), '{}');
  end if;
  if p_payload ? 'tags' then
    t.tags := coalesce(public.m24_jsonb_text_array(p_payload, 'tags'), '{}');
    select u.tag into v_missing
      from unnest(t.tags) as u(tag)
     where not exists (select 1 from public.treatment_tags g where g.tag = u.tag)
     limit 1;
    if v_missing is not null then
      raise exception 'unknown_treatment_tag: %', v_missing using errcode = '22023';
    end if;
  end if;

  if p_payload ? 'contraindications' then
    t.contraindications := coalesce(p_payload->'contraindications', '[]'::jsonb);
    if not public.m24_valid_contraindications(t.contraindications) then
      raise exception 'invalid_contraindications' using errcode = '22023';
    end if;
  end if;
  if p_payload ? 'media' then
    t.media := coalesce(p_payload->'media', '[]'::jsonb);
    if not public.m24_valid_media(t.media) then
      raise exception 'invalid_media' using errcode = '22023';
    end if;
  end if;

  if p_payload ? 'price_from_cents' then t.price_from_cents := public.m24_jsonb_int(p_payload, 'price_from_cents'); end if;
  if p_payload ? 'price_to_cents' then t.price_to_cents := public.m24_jsonb_int(p_payload, 'price_to_cents'); end if;
  if coalesce(t.price_from_cents, 0) < 0 or coalesce(t.price_to_cents, 0) < 0 then
    raise exception 'invalid_price' using errcode = '22023';
  end if;
  if t.price_from_cents is not null and t.price_to_cents is not null
     and t.price_from_cents > t.price_to_cents then
    raise exception 'invalid_price_range' using errcode = '22023';
  end if;
  if p_payload ? 'currency' then
    t.currency := upper(coalesce(public.m24_jsonb_text(p_payload, 'currency'), 'EUR'));
    if char_length(t.currency) <> 3 then
      raise exception 'invalid_currency' using errcode = '22023';
    end if;
  end if;

  if p_payload ? 'session_minutes' then t.session_minutes := public.m24_jsonb_int(p_payload, 'session_minutes'); end if;
  if p_payload ? 'sessions_count' then t.sessions_count := public.m24_jsonb_int(p_payload, 'sessions_count'); end if;
  if p_payload ? 'course_weeks' then t.course_weeks := public.m24_jsonb_int(p_payload, 'course_weeks'); end if;
  if p_payload ? 'waiting_days' then t.waiting_days := public.m24_jsonb_int(p_payload, 'waiting_days'); end if;
  if coalesce(t.session_minutes, 1) <= 0 or coalesce(t.sessions_count, 1) <= 0
     or coalesce(t.course_weeks, 1) <= 0 or coalesce(t.waiting_days, 0) < 0 then
    raise exception 'invalid_duration' using errcode = '22023';
  end if;

  if p_payload ? 'doctor_id' then
    t.doctor_id := nullif(p_payload->>'doctor_id', '')::uuid;
    if t.doctor_id is not null and not exists (select 1 from public.doctors d where d.id = t.doctor_id) then
      raise exception 'unknown_doctor' using errcode = '22023';
    end if;
  end if;
  if p_payload ? 'facility_id' then
    t.facility_id := nullif(p_payload->>'facility_id', '')::uuid;
    if t.facility_id is not null and not exists (select 1 from public.facilities f where f.id = t.facility_id) then
      raise exception 'unknown_facility' using errcode = '22023';
    end if;
  end if;

  if p_payload ? 'is_demo' then t.is_demo := public.m24_jsonb_bool(p_payload, 'is_demo', t.is_demo); end if;
  if p_payload ? 'featured' then t.featured := public.m24_jsonb_bool(p_payload, 'featured', t.featured); end if;

  if v_new then
    insert into public.treatments(id, title, summary, description_sections, family, scope,
      category, conditions, tags, evidence_level, contraindications, price_from_cents,
      price_to_cents, currency, price_notes, ssn_covered, session_minutes, sessions_count,
      course_weeks, waiting_days, modality, requirements, expected_outcome, media,
      doctor_id, facility_id, status, version, is_demo, featured, created_by)
    values (t.id, t.title, t.summary, t.description_sections, t.family, t.scope,
      t.category, t.conditions, t.tags, t.evidence_level, t.contraindications, t.price_from_cents,
      t.price_to_cents, t.currency, t.price_notes,
      public.m24_jsonb_bool(p_payload, 'ssn_covered', false),
      t.session_minutes, t.sessions_count, t.course_weeks, t.waiting_days, t.modality,
      t.requirements, t.expected_outcome, t.media, t.doctor_id, t.facility_id,
      'draft', 1, t.is_demo, t.featured, v_uid)
    returning id into v_id;
  else
    update public.treatments set
      title = t.title, summary = t.summary, description_sections = t.description_sections,
      family = t.family, scope = t.scope, category = t.category, conditions = t.conditions,
      tags = t.tags, evidence_level = t.evidence_level, contraindications = t.contraindications,
      price_from_cents = t.price_from_cents, price_to_cents = t.price_to_cents,
      currency = t.currency, price_notes = t.price_notes,
      ssn_covered = public.m24_jsonb_bool(p_payload, 'ssn_covered', t.ssn_covered),
      session_minutes = t.session_minutes, sessions_count = t.sessions_count,
      course_weeks = t.course_weeks, waiting_days = t.waiting_days, modality = t.modality,
      requirements = t.requirements, expected_outcome = t.expected_outcome, media = t.media,
      doctor_id = t.doctor_id, facility_id = t.facility_id,
      is_demo = t.is_demo, featured = t.featured,
      -- Una cura gia' pubblicata che cambia e' una nuova versione della scheda.
      version = case when t.status = 'published' then t.version + 1 else t.version end
    where id = t.id
    returning id into v_id;
  end if;

  insert into public.audit_log(actor_id, action, target_table, target_id)
  values (v_uid, 'treatment.upsert', 'treatments', v_id);

  return v_id;
end;
$$;

comment on function public.treatment_upsert(jsonb) is
  'Creazione o aggiornamento admin di una scheda cura. Senza id nasce draft; '
  'un aggiornamento di una cura published incrementa version. Valida enum, '
  'prezzi, tempi, chiavi delle sezioni, tag del vocabolario e media.';

-- ---------------------------------------------------------------------------
-- 6. treatment_set_status — admin
--    Transizioni ammesse: draft -> verified -> published -> retired e
--    published -> verified (rientro in revisione).
-- ---------------------------------------------------------------------------
create or replace function public.treatment_set_status(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.m24_require_admin();
  t     public.treatments%rowtype;
  v_ok  boolean;
begin
  if p_status is null or p_status not in ('draft','verified','published','retired') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;

  select * into t from public.treatments where id = p_id for update;
  if not found then
    raise exception 'treatment_not_found' using errcode = '22023';
  end if;
  if t.status::text = p_status then
    return;
  end if;

  v_ok := (t.status = 'draft'     and p_status = 'verified')
       or (t.status = 'verified'  and p_status = 'published')
       or (t.status = 'published' and p_status in ('retired','verified'));
  if not v_ok then
    raise exception 'invalid_transition' using errcode = '22023';
  end if;

  if p_status = 'published' then
    if t.doctor_id is null and t.facility_id is null then
      raise exception 'publish_requires_provider' using errcode = '22023';
    end if;
    if nullif(btrim(coalesce(t.description_sections->>'evidenze_e_limiti', '')), '') is null then
      raise exception 'publish_requires_evidence' using errcode = '22023';
    end if;
  end if;

  update public.treatments
     set status = p_status::treatment_status,
         published_at = case
           when p_status = 'published' and t.published_at is null then clock_timestamp()
           else t.published_at end
   where id = p_id;

  insert into public.audit_log(actor_id, action, target_table, target_id)
  values (v_uid, 'treatment.status', 'treatments', p_id);

  insert into public.platform_events(kind, source, status, details)
  values ('admin_action', 'treatments', 'treatment.status',
          jsonb_build_object('actor', v_uid, 'treatment', p_id,
                             'from', t.status::text, 'to', p_status));
end;
$$;

comment on function public.treatment_set_status(uuid, text) is
  'Transizioni di stato di una cura: draft->verified->published->retired e '
  'published->verified. published richiede un medico o una struttura e la '
  'sezione evidenze_e_limiti non vuota; published_at e'' valorizzato alla prima '
  'pubblicazione e non viene piu'' riscritto.';

-- ---------------------------------------------------------------------------
-- 7. doctor_upsert e facility_upsert — admin
-- ---------------------------------------------------------------------------
create or replace function public.doctor_upsert(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.m24_require_admin();
  v_allowed text[] := array['id','user_id','display_name','role','specialties','registry_body',
    'registry_number','verified','languages','bio','photo_url','facility_id','is_demo'];
  d public.doctors%rowtype;
  v_id uuid;
  v_new boolean;
  k text;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_payload = '{}'::jsonb then
    raise exception 'invalid_payload' using errcode = '22023';
  end if;
  for k in select jsonb_object_keys(p_payload) loop
    if not (k = any(v_allowed)) then
      raise exception 'invalid_payload_key: %', k using errcode = '22023';
    end if;
  end loop;

  v_id := nullif(p_payload->>'id', '')::uuid;
  v_new := v_id is null;

  if not v_new then
    select * into d from public.doctors where id = v_id for update;
    if not found then raise exception 'doctor_not_found' using errcode = '22023'; end if;
  else
    d.id := gen_random_uuid();
    d.role := 'medico';
    d.specialties := '{}';
    d.languages := '{}';
    d.verified := false;
    d.is_demo := false;
  end if;

  if p_payload ? 'display_name' then
    d.display_name := public.m24_jsonb_text(p_payload, 'display_name');
  end if;
  if d.display_name is null then
    raise exception 'invalid_display_name' using errcode = '22023';
  end if;
  if p_payload ? 'role' then
    d.role := public.m24_jsonb_text(p_payload, 'role')::doctor_role;
  end if;
  if p_payload ? 'specialties' then
    d.specialties := coalesce(public.m24_jsonb_text_array(p_payload, 'specialties'), '{}');
  end if;
  if p_payload ? 'languages' then
    d.languages := coalesce(public.m24_jsonb_text_array(p_payload, 'languages'), '{}');
  end if;
  if p_payload ? 'registry_body' then d.registry_body := public.m24_jsonb_text(p_payload, 'registry_body'); end if;
  if p_payload ? 'registry_number' then d.registry_number := public.m24_jsonb_text(p_payload, 'registry_number'); end if;
  if p_payload ? 'bio' then d.bio := public.m24_jsonb_text(p_payload, 'bio'); end if;
  if p_payload ? 'photo_url' then d.photo_url := public.m24_jsonb_text(p_payload, 'photo_url'); end if;
  if p_payload ? 'verified' then d.verified := public.m24_jsonb_bool(p_payload, 'verified', d.verified); end if;
  if p_payload ? 'is_demo' then d.is_demo := public.m24_jsonb_bool(p_payload, 'is_demo', d.is_demo); end if;
  if p_payload ? 'user_id' then d.user_id := nullif(p_payload->>'user_id', '')::uuid; end if;
  if p_payload ? 'facility_id' then
    d.facility_id := nullif(p_payload->>'facility_id', '')::uuid;
    if d.facility_id is not null and not exists (select 1 from public.facilities f where f.id = d.facility_id) then
      raise exception 'unknown_facility' using errcode = '22023';
    end if;
  end if;

  -- Un professionista verificato ha un albo e un numero: la verifica non e'
  -- una spunta decorativa.
  if d.verified and (d.registry_body is null or d.registry_number is null) then
    raise exception 'verified_requires_registry' using errcode = '22023';
  end if;

  if v_new then
    insert into public.doctors(id, user_id, display_name, role, specialties, registry_body,
      registry_number, verified, languages, bio, photo_url, facility_id, is_demo, created_by)
    values (d.id, d.user_id, d.display_name, d.role, d.specialties, d.registry_body,
      d.registry_number, d.verified, d.languages, d.bio, d.photo_url, d.facility_id, d.is_demo, v_uid)
    returning id into v_id;
  else
    update public.doctors set
      user_id = d.user_id, display_name = d.display_name, role = d.role,
      specialties = d.specialties, registry_body = d.registry_body,
      registry_number = d.registry_number, verified = d.verified, languages = d.languages,
      bio = d.bio, photo_url = d.photo_url, facility_id = d.facility_id, is_demo = d.is_demo
    where id = d.id
    returning id into v_id;
  end if;

  insert into public.audit_log(actor_id, action, target_table, target_id)
  values (v_uid, 'doctor.upsert', 'doctors', v_id);

  return v_id;
end;
$$;

comment on function public.doctor_upsert(jsonb) is
  'Creazione o aggiornamento admin di un profilo professionale. verified '
  'richiede albo e numero di iscrizione.';

create or replace function public.facility_upsert(p_payload jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.m24_require_admin();
  v_allowed text[] := array['id','name','kind','ssn_accredited','address','city','region',
    'country','lat','lng','phone','email','website','services','opening_hours','photos',
    'verified','is_demo'];
  f public.facilities%rowtype;
  v_id uuid;
  v_new boolean;
  k text;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or p_payload = '{}'::jsonb then
    raise exception 'invalid_payload' using errcode = '22023';
  end if;
  for k in select jsonb_object_keys(p_payload) loop
    if not (k = any(v_allowed)) then
      raise exception 'invalid_payload_key: %', k using errcode = '22023';
    end if;
  end loop;

  v_id := nullif(p_payload->>'id', '')::uuid;
  v_new := v_id is null;

  if not v_new then
    select * into f from public.facilities where id = v_id for update;
    if not found then raise exception 'facility_not_found' using errcode = '22023'; end if;
  else
    f.id := gen_random_uuid();
    f.kind := 'altro';
    f.ssn_accredited := false;
    f.country := 'IT';
    f.services := '{}';
    f.photos := '{}';
    f.opening_hours := '{}'::jsonb;
    f.verified := false;
    f.is_demo := false;
  end if;

  if p_payload ? 'name' then f.name := public.m24_jsonb_text(p_payload, 'name'); end if;
  if f.name is null then raise exception 'invalid_name' using errcode = '22023'; end if;
  if p_payload ? 'kind' then f.kind := public.m24_jsonb_text(p_payload, 'kind')::facility_kind; end if;
  if p_payload ? 'ssn_accredited' then f.ssn_accredited := public.m24_jsonb_bool(p_payload, 'ssn_accredited', f.ssn_accredited); end if;
  if p_payload ? 'address' then f.address := public.m24_jsonb_text(p_payload, 'address'); end if;
  if p_payload ? 'city' then f.city := public.m24_jsonb_text(p_payload, 'city'); end if;
  if p_payload ? 'region' then f.region := public.m24_jsonb_text(p_payload, 'region'); end if;
  if p_payload ? 'country' then
    f.country := upper(coalesce(public.m24_jsonb_text(p_payload, 'country'), 'IT'));
    if char_length(f.country) <> 2 then raise exception 'invalid_country' using errcode = '22023'; end if;
  end if;
  if p_payload ? 'lat' then
    f.lat := nullif(btrim(coalesce(p_payload->>'lat', '')), '')::numeric;
    if f.lat is not null and (f.lat < -90 or f.lat > 90) then
      raise exception 'invalid_lat' using errcode = '22023';
    end if;
  end if;
  if p_payload ? 'lng' then
    f.lng := nullif(btrim(coalesce(p_payload->>'lng', '')), '')::numeric;
    if f.lng is not null and (f.lng < -180 or f.lng > 180) then
      raise exception 'invalid_lng' using errcode = '22023';
    end if;
  end if;
  if p_payload ? 'phone' then f.phone := public.m24_jsonb_text(p_payload, 'phone'); end if;
  if p_payload ? 'email' then f.email := public.m24_jsonb_text(p_payload, 'email'); end if;
  if p_payload ? 'website' then f.website := public.m24_jsonb_text(p_payload, 'website'); end if;
  if p_payload ? 'services' then f.services := coalesce(public.m24_jsonb_text_array(p_payload, 'services'), '{}'); end if;
  if p_payload ? 'photos' then f.photos := coalesce(public.m24_jsonb_text_array(p_payload, 'photos'), '{}'); end if;
  if p_payload ? 'opening_hours' then
    f.opening_hours := coalesce(p_payload->'opening_hours', '{}'::jsonb);
    if jsonb_typeof(f.opening_hours) <> 'object' then
      raise exception 'invalid_opening_hours' using errcode = '22023';
    end if;
  end if;
  if p_payload ? 'verified' then f.verified := public.m24_jsonb_bool(p_payload, 'verified', f.verified); end if;
  if p_payload ? 'is_demo' then f.is_demo := public.m24_jsonb_bool(p_payload, 'is_demo', f.is_demo); end if;

  if v_new then
    insert into public.facilities(id, name, kind, ssn_accredited, address, city, region,
      country, lat, lng, phone, email, website, services, opening_hours, photos,
      verified, is_demo, created_by)
    values (f.id, f.name, f.kind, f.ssn_accredited, f.address, f.city, f.region,
      f.country, f.lat, f.lng, f.phone, f.email, f.website, f.services, f.opening_hours,
      f.photos, f.verified, f.is_demo, v_uid)
    returning id into v_id;
  else
    update public.facilities set
      name = f.name, kind = f.kind, ssn_accredited = f.ssn_accredited, address = f.address,
      city = f.city, region = f.region, country = f.country, lat = f.lat, lng = f.lng,
      phone = f.phone, email = f.email, website = f.website, services = f.services,
      opening_hours = f.opening_hours, photos = f.photos, verified = f.verified,
      is_demo = f.is_demo
    where id = f.id
    returning id into v_id;
  end if;

  insert into public.audit_log(actor_id, action, target_table, target_id)
  values (v_uid, 'facility.upsert', 'facilities', v_id);

  return v_id;
end;
$$;

comment on function public.facility_upsert(jsonb) is
  'Creazione o aggiornamento admin di una struttura sanitaria, con '
  'validazione di enum, coordinate, orari e array.';

-- ---------------------------------------------------------------------------
-- 8. toggle_favorite — aggiunge o toglie, ritorna lo stato finale
-- ---------------------------------------------------------------------------
create or replace function public.toggle_favorite(p_target_type text, p_target_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := public.m24_require_auth();
  v_del int;
begin
  if p_target_type is null or p_target_type not in ('treatment','doctor','facility') then
    raise exception 'invalid_target_type' using errcode = '22023';
  end if;
  if p_target_id is null then
    raise exception 'invalid_target_id' using errcode = '22023';
  end if;

  delete from public.favorites
   where user_id = v_uid
     and target_type = p_target_type::review_target_type
     and target_id = p_target_id;
  get diagnostics v_del = row_count;

  if v_del > 0 then
    return false;
  end if;

  if not public.m24_target_exists(p_target_type, p_target_id) then
    raise exception 'target_not_found' using errcode = '22023';
  end if;

  insert into public.favorites(user_id, target_type, target_id)
  values (v_uid, p_target_type::review_target_type, p_target_id)
  on conflict do nothing;

  return true;
end;
$$;

comment on function public.toggle_favorite(text, uuid) is
  'Aggiunge o rimuove il preferito dell''utente corrente e restituisce lo stato '
  'finale: true se adesso e'' tra i preferiti, false se e'' stato tolto.';

-- ---------------------------------------------------------------------------
-- 9. Permessi — nulla a public e anon, tutto il resto a authenticated
-- ---------------------------------------------------------------------------
revoke execute on function
  public.m24_require_auth(),
  public.m24_require_admin(),
  public.m24_target_exists(text, uuid),
  public.m24_has_url(text),
  public.m24_valid_sub_ratings(jsonb),
  public.m24_jsonb_text(jsonb, text),
  public.m24_jsonb_int(jsonb, text),
  public.m24_jsonb_bool(jsonb, text, boolean),
  public.m24_jsonb_text_array(jsonb, text),
  public.submit_review(text, uuid, int, jsonb, text, text),
  public.moderate_review(uuid, text, text),
  public.withdraw_review(uuid),
  public.treatment_upsert(jsonb),
  public.treatment_set_status(uuid, text),
  public.doctor_upsert(jsonb),
  public.facility_upsert(jsonb),
  public.toggle_favorite(text, uuid)
  from public, anon;

grant execute on function
  public.m24_require_auth(),
  public.m24_require_admin(),
  public.m24_target_exists(text, uuid),
  public.m24_has_url(text),
  public.m24_valid_sub_ratings(jsonb),
  public.m24_jsonb_text(jsonb, text),
  public.m24_jsonb_int(jsonb, text),
  public.m24_jsonb_bool(jsonb, text, boolean),
  public.m24_jsonb_text_array(jsonb, text),
  public.submit_review(text, uuid, int, jsonb, text, text),
  public.moderate_review(uuid, text, text),
  public.withdraw_review(uuid),
  public.treatment_upsert(jsonb),
  public.treatment_set_status(uuid, text),
  public.doctor_upsert(jsonb),
  public.facility_upsert(jsonb),
  public.toggle_favorite(text, uuid)
  to authenticated, service_role;

insert into public.app_migrations(name) values ('0019_treatments_write') on conflict do nothing;
