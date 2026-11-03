-- ============================================================================
-- Medical 24 — 0018 TREATMENTS READ (P07-A2) — modulo M8 Cure
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- Solo funzioni di LETTURA. Nessuna scrittura, nessuna tabella nuova, nessuna
-- modifica alla 0017 (schema e RLS), nessun seed, nessuna schermata.
--
-- Tutte le funzioni pubbliche sono SECURITY INVOKER e STABLE: girano con i
-- privilegi del chiamante, quindi la RLS della 0017 resta l'unico guardiano.
-- anon e authenticated possono eseguirle e vedono comunque soltanto le cure
-- published, i medici e le strutture verified o is_demo e le recensioni
-- approved (l'autore vede anche le proprie, ma le funzioni filtrano
-- esplicitamente su 'approved' dove il risultato e' pubblico).
--
-- Funzioni esposte:
--   search_treatments(...)        ricerca con filtri, ordinamenti e total_count
--   facets_for_treatments(...)    conteggi per sfaccettatura sullo stesso filtro
--   treatment_detail(uuid)        scheda completa in jsonb, null se non visibile
--   treatment_compare(uuid[])     da 2 a 4 cure a confronto (22023 altrimenti)
--   reviews_for_target(...)       recensioni approved con autore anonimizzato
--   featured_treatments(int)      cure in evidenza per la home
--
-- Funzioni interne (prefisso m24_):
--   m24_treatments_filtered(...)  corpo unico del filtro, usato da ricerca,
--                                 faccette e confronto: una sola definizione
--                                 di "che cosa e' visibile e che cosa passa
--                                 i filtri" (DRY).
--   m24_display_name_initial()    "Mario Rossi" -> "Mario R."
--   m24_review_author_label()     security definer: legge solo full_name da
--                                 profiles e ne restituisce la forma ridotta.
--   m24_treatment_cover_url()     prima immagine di treatments.media.
--   m24_max_contraindication()    severita' massima delle controindicazioni.
--
-- Idempotente: puo' essere rieseguita senza effetti collaterali.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Aiutanti puri
-- ---------------------------------------------------------------------------

-- "Mario Rossi" -> "Mario R." ; "Mario" -> "Mario" ; vuoto -> "Utente".
create or replace function public.m24_display_name_initial(p_full text)
returns text
language sql
immutable
as $$
  select case
    when nullif(btrim(coalesce(p_full, '')), '') is null then 'Utente'
    when array_length(regexp_split_to_array(btrim(p_full), '\s+'), 1) = 1
      then btrim(p_full)
    else (regexp_split_to_array(btrim(p_full), '\s+'))[1] || ' ' ||
         upper(left((regexp_split_to_array(btrim(p_full), '\s+'))[
           array_length(regexp_split_to_array(btrim(p_full), '\s+'), 1)], 1)) || '.'
  end;
$$;

-- Prima immagine dichiarata in treatments.media (ordine dell'array).
create or replace function public.m24_treatment_cover_url(p_media jsonb)
returns text
language sql
immutable
as $$
  select e.item->>'url'
    from jsonb_array_elements(case when jsonb_typeof(p_media) = 'array'
                                   then p_media else '[]'::jsonb end)
         with ordinality as e(item, ord)
   where e.item->>'type' = 'image'
   order by e.ord
   limit 1;
$$;

-- Severita' massima dichiarata nelle controindicazioni (alta > media > bassa).
create or replace function public.m24_max_contraindication(p_doc jsonb)
returns text
language sql
immutable
as $$
  select case max(case e.item->>'severity'
                    when 'alta' then 3 when 'media' then 2 when 'bassa' then 1
                    else 0 end)
           when 3 then 'alta' when 2 then 'media' when 1 then 'bassa' else null end
    from jsonb_array_elements(case when jsonb_typeof(p_doc) = 'array'
                                   then p_doc else '[]'::jsonb end) as e(item);
$$;

-- Etichetta pubblica dell'autore di una recensione. security definer perche'
-- profiles e' leggibile solo dal proprietario: qui esce esclusivamente il nome
-- gia' ridotto (nome piu' iniziale del cognome), nessun altro campo.
create or replace function public.m24_review_author_label(p_author uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select public.m24_display_name_initial(
    (select p.full_name from public.profiles p where p.id = p_author));
$$;

-- ---------------------------------------------------------------------------
-- 2. Corpo unico del filtro
--    security invoker: la RLS della 0017 decide che cosa esiste.
-- ---------------------------------------------------------------------------
create or replace function public.m24_treatments_filtered(
  p_query            text default null,
  p_scope            text[] default null,
  p_family           text[] default null,
  p_modality         text[] default null,
  p_city             text default null,
  p_min_rating       numeric default null,
  p_max_price_cents  int default null,
  p_duration_bucket  text default null,
  p_conditions       text[] default null,
  p_tags             text[] default null
)
returns table (
  id                   uuid,
  title                text,
  summary              text,
  family               text,
  scope                text,
  evidence_level       text,
  price_from_cents     int,
  price_to_cents       int,
  session_minutes      int,
  sessions_count       int,
  course_weeks         int,
  waiting_days         int,
  modality             text,
  doctor_id            uuid,
  doctor_display_name  text,
  facility_id          uuid,
  facility_name        text,
  facility_city        text,
  cover_url            text,
  rating_avg           numeric,
  rating_count         int,
  is_demo              boolean,
  featured             boolean,
  published_at         timestamptz,
  created_at           timestamptz,
  rank                 real
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare
  v_text   text;
  v_ts     tsquery;
  v_bucket int;
begin
  v_text := nullif(btrim(coalesce(p_query, '')), '');
  if v_text is not null then
    v_ts := websearch_to_tsquery('italian', v_text);
  end if;

  if nullif(btrim(coalesce(p_duration_bucket, '')), '') is not null then
    if p_duration_bucket not in ('30','45','60','90') then
      raise exception 'invalid_duration_bucket' using errcode = '22023';
    end if;
    v_bucket := p_duration_bucket::int;
  end if;

  return query
  select
    t.id,
    t.title,
    t.summary,
    t.family::text,
    t.scope::text,
    t.evidence_level::text,
    t.price_from_cents,
    t.price_to_cents,
    t.session_minutes,
    t.sessions_count,
    t.course_weeks,
    t.waiting_days,
    t.modality::text,
    d.id,
    d.display_name,
    f.id,
    f.name,
    f.city,
    public.m24_treatment_cover_url(t.media),
    rs.rating_avg,
    coalesce(rs.rating_count, 0),
    t.is_demo,
    t.featured,
    t.published_at,
    t.created_at,
    case when v_ts is null then 0::real
         else ts_rank(t.search_vector, v_ts) end
  from public.treatments t
  left join public.doctors d on d.id = t.doctor_id
  left join public.facilities f on f.id = t.facility_id
  left join public.rating_summaries rs
         on rs.target_type = 'treatment' and rs.target_id = t.id
  where t.status = 'published'
    and (
      v_text is null
      or (v_ts is not null and t.search_vector @@ v_ts)
      or (d.display_name is not null and d.display_name ilike '%' || v_text || '%')
      or (f.name is not null and f.name ilike '%' || v_text || '%')
      or similarity(t.title, v_text) > 0.3
    )
    and (p_scope is null or array_length(p_scope, 1) is null
         or t.scope::text = any(p_scope))
    and (p_family is null or array_length(p_family, 1) is null
         or t.family::text = any(p_family))
    and (p_modality is null or array_length(p_modality, 1) is null
         or t.modality::text = any(p_modality))
    and (nullif(btrim(coalesce(p_city, '')), '') is null
         or f.city ilike btrim(p_city))
    and (p_min_rating is null or coalesce(rs.rating_avg, 0) >= p_min_rating)
    and (p_max_price_cents is null
         or (t.price_from_cents is not null and t.price_from_cents <= p_max_price_cents))
    and (v_bucket is null
         or (t.session_minutes is not null and t.session_minutes <= v_bucket))
    and (p_conditions is null or array_length(p_conditions, 1) is null
         or t.conditions && p_conditions)
    and (p_tags is null or array_length(p_tags, 1) is null
         or t.tags && p_tags);
end;
$$;

comment on function public.m24_treatments_filtered(text, text[], text[], text[], text,
  numeric, int, text, text[], text[]) is
  'Corpo unico del filtro delle cure pubblicate: usato da search_treatments, '
  'facets_for_treatments e treatment_compare. security invoker: la RLS decide.';

-- ---------------------------------------------------------------------------
-- 3. search_treatments
-- ---------------------------------------------------------------------------
create or replace function public.search_treatments(
  p_query            text default null,
  p_scope            text[] default null,
  p_family           text[] default null,
  p_modality         text[] default null,
  p_city             text default null,
  p_min_rating       numeric default null,
  p_max_price_cents  int default null,
  p_duration_bucket  text default null,
  p_conditions       text[] default null,
  p_tags             text[] default null,
  p_sort             text default 'pertinenza',
  p_limit            int default 20,
  p_offset           int default 0
)
returns table (
  id                   uuid,
  title                text,
  summary              text,
  family               text,
  scope                text,
  evidence_level       text,
  price_from_cents     int,
  session_minutes      int,
  modality             text,
  doctor_display_name  text,
  facility_name        text,
  facility_city        text,
  cover_url            text,
  rating_avg           numeric,
  rating_count         int,
  is_demo              boolean,
  featured             boolean,
  total_count          bigint
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare
  v_sort   text := lower(coalesce(nullif(btrim(p_sort), ''), 'pertinenza'));
  v_limit  int  := greatest(1, least(50, coalesce(p_limit, 20)));
  v_offset int  := greatest(0, coalesce(p_offset, 0));
begin
  if v_sort not in ('pertinenza','rating','prezzo_asc','prezzo_desc','attesa','recenti') then
    raise exception 'invalid_sort' using errcode = '22023';
  end if;

  return query
  select b.id, b.title, b.summary, b.family, b.scope, b.evidence_level,
         b.price_from_cents, b.session_minutes, b.modality,
         b.doctor_display_name, b.facility_name, b.facility_city,
         b.cover_url, b.rating_avg, b.rating_count, b.is_demo, b.featured,
         count(*) over () as total_count
    from public.m24_treatments_filtered(
           p_query, p_scope, p_family, p_modality, p_city, p_min_rating,
           p_max_price_cents, p_duration_bucket, p_conditions, p_tags) b
   order by
     case when v_sort = 'pertinenza' then b.rank end desc nulls last,
     case when v_sort in ('pertinenza','rating') then b.rating_avg end desc nulls last,
     case when v_sort = 'rating' then b.rating_count end desc nulls last,
     case when v_sort = 'prezzo_asc' then b.price_from_cents end asc nulls last,
     case when v_sort = 'prezzo_desc' then b.price_from_cents end desc nulls last,
     case when v_sort = 'attesa' then b.waiting_days end asc nulls last,
     case when v_sort = 'recenti' then coalesce(b.published_at, b.created_at) end desc nulls last,
     b.title asc, b.id asc
   limit v_limit offset v_offset;
end;
$$;

comment on function public.search_treatments(text, text[], text[], text[], text, numeric,
  int, text, text[], text[], text, int, int) is
  'Ricerca delle cure pubblicate. Testo libero su search_vector (italian), '
  'nome del medico, nome della struttura e similarita'' trigram sul titolo '
  '(soglia 0.3). p_sort: pertinenza, rating, prezzo_asc, prezzo_desc, attesa, '
  'recenti. p_limit tra 1 e 50. total_count e'' il totale prima della paginazione.';

-- ---------------------------------------------------------------------------
-- 4. facets_for_treatments — conteggi sullo stesso insieme filtrato
-- ---------------------------------------------------------------------------
create or replace function public.facets_for_treatments(
  p_query            text default null,
  p_scope            text[] default null,
  p_family           text[] default null,
  p_modality         text[] default null,
  p_city             text default null,
  p_min_rating       numeric default null,
  p_max_price_cents  int default null,
  p_duration_bucket  text default null,
  p_conditions       text[] default null,
  p_tags             text[] default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare v_out jsonb;
begin
  with base as (
    select * from public.m24_treatments_filtered(
      p_query, p_scope, p_family, p_modality, p_city, p_min_rating,
      p_max_price_cents, p_duration_bucket, p_conditions, p_tags)
  )
  select jsonb_build_object(
    'total', (select count(*)::int from base),
    'scope', coalesce((select jsonb_object_agg(k, c) from (
        select b.scope as k, count(*)::int as c from base b
         where b.scope is not null group by b.scope) s), '{}'::jsonb),
    'family', coalesce((select jsonb_object_agg(k, c) from (
        select b.family as k, count(*)::int as c from base b
         where b.family is not null group by b.family) s), '{}'::jsonb),
    'modality', coalesce((select jsonb_object_agg(k, c) from (
        select b.modality as k, count(*)::int as c from base b
         where b.modality is not null group by b.modality) s), '{}'::jsonb),
    'city', coalesce((select jsonb_object_agg(k, c) from (
        select b.facility_city as k, count(*)::int as c from base b
         where b.facility_city is not null group by b.facility_city) s), '{}'::jsonb),
    'evidence_level', coalesce((select jsonb_object_agg(k, c) from (
        select b.evidence_level as k, count(*)::int as c from base b
         where b.evidence_level is not null group by b.evidence_level) s), '{}'::jsonb)
  ) into v_out;

  return coalesce(v_out, '{}'::jsonb);
end;
$$;

comment on function public.facets_for_treatments(text, text[], text[], text[], text,
  numeric, int, text, text[], text[]) is
  'Conteggi per scope, family, modality, city ed evidence_level calcolati sullo '
  'stesso insieme filtrato di search_treatments (senza ordinamento ne paginazione).';

-- ---------------------------------------------------------------------------
-- 5. treatment_detail
-- ---------------------------------------------------------------------------
create or replace function public.treatment_detail(p_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare v_out jsonb;
begin
  if p_id is null then return null; end if;

  select jsonb_build_object(
    'id', t.id,
    'title', t.title,
    'summary', t.summary,
    'description_sections', t.description_sections,
    'family', t.family::text,
    'scope', t.scope::text,
    'category', t.category,
    'conditions', to_jsonb(t.conditions),
    'tags', to_jsonb(t.tags),
    'evidence_level', t.evidence_level::text,
    'contraindications', t.contraindications,
    'max_contraindication_severity', public.m24_max_contraindication(t.contraindications),
    'price_from_cents', t.price_from_cents,
    'price_to_cents', t.price_to_cents,
    'currency', t.currency,
    'price_notes', t.price_notes,
    'ssn_covered', t.ssn_covered,
    'session_minutes', t.session_minutes,
    'sessions_count', t.sessions_count,
    'course_weeks', t.course_weeks,
    'waiting_days', t.waiting_days,
    'modality', t.modality::text,
    'requirements', t.requirements,
    'expected_outcome', t.expected_outcome,
    'media', t.media,
    'cover_url', public.m24_treatment_cover_url(t.media),
    'is_demo', t.is_demo,
    'featured', t.featured,
    'version', t.version,
    'published_at', t.published_at,
    'created_at', t.created_at,
    'updated_at', t.updated_at,
    'doctor', case when d.id is null then null else jsonb_build_object(
        'id', d.id,
        'display_name', d.display_name,
        'role', d.role::text,
        'specialties', to_jsonb(d.specialties),
        'languages', to_jsonb(d.languages),
        'bio', d.bio,
        'photo_url', d.photo_url,
        'verified', d.verified,
        'rating', (select to_jsonb(x) from (
            select rs2.rating_avg, rs2.rating_count, rs2.sub_avgs
              from public.rating_summaries rs2
             where rs2.target_type = 'doctor' and rs2.target_id = d.id) x)
      ) end,
    'facility', case when f.id is null then null else jsonb_build_object(
        'id', f.id,
        'name', f.name,
        'kind', f.kind::text,
        'ssn_accredited', f.ssn_accredited,
        'address', f.address,
        'city', f.city,
        'region', f.region,
        'country', f.country,
        'lat', f.lat,
        'lng', f.lng,
        'phone', f.phone,
        'website', f.website,
        'services', to_jsonb(f.services),
        'opening_hours', f.opening_hours,
        'verified', f.verified,
        'rating', (select to_jsonb(x) from (
            select rs3.rating_avg, rs3.rating_count, rs3.sub_avgs
              from public.rating_summaries rs3
             where rs3.target_type = 'facility' and rs3.target_id = f.id) x)
      ) end,
    'rating', jsonb_build_object(
        'rating_avg', rs.rating_avg,
        'rating_count', coalesce(rs.rating_count, 0),
        'sub_avgs', coalesce(rs.sub_avgs, '{}'::jsonb)),
    'reviews', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'id', r.id,
                 'rating', r.rating,
                 'sub_ratings', r.sub_ratings,
                 'title', r.title,
                 'body', r.body,
                 'verified', r.verified,
                 'helpful_count', r.helpful_count,
                 'created_at', r.created_at,
                 'author_label', public.m24_review_author_label(r.author_id))
               order by r.created_at desc)
          from (
            select r2.* from public.reviews r2
             where r2.target_type = 'treatment' and r2.target_id = t.id
               and r2.status = 'approved'
             order by r2.created_at desc
             limit 5
          ) r), '[]'::jsonb)
  )
  into v_out
  from public.treatments t
  left join public.doctors d on d.id = t.doctor_id
  left join public.facilities f on f.id = t.facility_id
  left join public.rating_summaries rs
         on rs.target_type = 'treatment' and rs.target_id = t.id
  where t.id = p_id;

  return v_out;
end;
$$;

comment on function public.treatment_detail(uuid) is
  'Scheda cura completa in jsonb con medico, struttura, rating_summaries e le '
  'ultime cinque recensioni approved. null se la cura non e'' visibile.';

-- ---------------------------------------------------------------------------
-- 6. treatment_compare — da 2 a 4 cure
-- ---------------------------------------------------------------------------
create or replace function public.treatment_compare(p_ids uuid[])
returns table (
  id                              uuid,
  title                           text,
  session_minutes                 int,
  sessions_count                  int,
  course_weeks                    int,
  price_from_cents                int,
  price_to_cents                  int,
  waiting_days                    int,
  modality                        text,
  evidence_level                  text,
  max_contraindication_severity   text,
  rating_avg                      numeric,
  rating_count                    int,
  doctor_display_name             text,
  facility_name                   text
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare v_n int := coalesce(array_length(p_ids, 1), 0);
begin
  if v_n < 2 or v_n > 4 then
    raise exception 'invalid_compare_size' using errcode = '22023';
  end if;

  return query
  select b.id, b.title, b.session_minutes, b.sessions_count, b.course_weeks,
         b.price_from_cents, b.price_to_cents, b.waiting_days, b.modality,
         b.evidence_level,
         public.m24_max_contraindication(t.contraindications),
         b.rating_avg, b.rating_count,
         b.doctor_display_name, b.facility_name
    from public.m24_treatments_filtered() b
    join public.treatments t on t.id = b.id
   where b.id = any(p_ids)
   order by array_position(p_ids, b.id);
end;
$$;

comment on function public.treatment_compare(uuid[]) is
  'Confronto di due, tre o quattro cure pubblicate. Fuori intervallo: 22023.';

-- ---------------------------------------------------------------------------
-- 7. reviews_for_target
-- ---------------------------------------------------------------------------
create or replace function public.reviews_for_target(
  p_target_type text,
  p_target_id   uuid,
  p_limit       int default 20,
  p_offset      int default 0
)
returns table (
  id            uuid,
  target_type   text,
  target_id     uuid,
  rating        smallint,
  sub_ratings   jsonb,
  title         text,
  body          text,
  verified      boolean,
  helpful_count int,
  created_at    timestamptz,
  author_label  text,
  total_count   bigint
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare
  v_limit  int := greatest(1, least(50, coalesce(p_limit, 20)));
  v_offset int := greatest(0, coalesce(p_offset, 0));
begin
  if p_target_type is null or p_target_type not in ('treatment','doctor','facility') then
    raise exception 'invalid_target_type' using errcode = '22023';
  end if;
  if p_target_id is null then
    raise exception 'invalid_target_id' using errcode = '22023';
  end if;

  return query
  select r.id, r.target_type::text, r.target_id, r.rating, r.sub_ratings,
         r.title, r.body, r.verified, r.helpful_count, r.created_at,
         public.m24_review_author_label(r.author_id),
         count(*) over () as total_count
    from public.reviews r
   where r.target_type = p_target_type::review_target_type
     and r.target_id = p_target_id
     and r.status = 'approved'
   order by r.created_at desc, r.id desc
   limit v_limit offset v_offset;
end;
$$;

comment on function public.reviews_for_target(text, uuid, int, int) is
  'Recensioni approved del bersaglio, dalla piu'' recente, con il nome '
  'dell''autore ridotto a nome piu'' iniziale del cognome e il flag verified.';

-- ---------------------------------------------------------------------------
-- 8. featured_treatments — vetrina della home
-- ---------------------------------------------------------------------------
create or replace function public.featured_treatments(p_limit int default 6)
returns table (
  id                   uuid,
  title                text,
  summary              text,
  family               text,
  scope                text,
  evidence_level       text,
  price_from_cents     int,
  session_minutes      int,
  modality             text,
  doctor_display_name  text,
  facility_name        text,
  facility_city        text,
  cover_url            text,
  rating_avg           numeric,
  rating_count         int,
  is_demo              boolean
)
language plpgsql
stable
security invoker
set search_path = public, extensions
as $$
declare v_limit int := greatest(1, least(50, coalesce(p_limit, 6)));
begin
  return query
  select b.id, b.title, b.summary, b.family, b.scope, b.evidence_level,
         b.price_from_cents, b.session_minutes, b.modality,
         b.doctor_display_name, b.facility_name, b.facility_city,
         b.cover_url, b.rating_avg, b.rating_count, b.is_demo
    from public.m24_treatments_filtered() b
   where b.featured
   order by b.rating_avg desc nulls last,
            coalesce(b.published_at, b.created_at) desc,
            b.title asc
   limit v_limit;
end;
$$;

comment on function public.featured_treatments(int) is
  'Cure published e featured per la home, ordinate per valutazione e data.';

-- ---------------------------------------------------------------------------
-- 9. Grant — esecuzione a anon e authenticated; la RLS fa il resto
-- ---------------------------------------------------------------------------
revoke execute on function
  public.m24_display_name_initial(text),
  public.m24_treatment_cover_url(jsonb),
  public.m24_max_contraindication(jsonb),
  public.m24_review_author_label(uuid),
  public.m24_treatments_filtered(text, text[], text[], text[], text, numeric, int, text, text[], text[]),
  public.search_treatments(text, text[], text[], text[], text, numeric, int, text, text[], text[], text, int, int),
  public.facets_for_treatments(text, text[], text[], text[], text, numeric, int, text, text[], text[]),
  public.treatment_detail(uuid),
  public.treatment_compare(uuid[]),
  public.reviews_for_target(text, uuid, int, int),
  public.featured_treatments(int)
  from public;

grant execute on function
  public.m24_display_name_initial(text),
  public.m24_treatment_cover_url(jsonb),
  public.m24_max_contraindication(jsonb),
  public.m24_review_author_label(uuid),
  public.m24_treatments_filtered(text, text[], text[], text[], text, numeric, int, text, text[], text[]),
  public.search_treatments(text, text[], text[], text[], text, numeric, int, text, text[], text[], text, int, int),
  public.facets_for_treatments(text, text[], text[], text[], text, numeric, int, text, text[], text[]),
  public.treatment_detail(uuid),
  public.treatment_compare(uuid[]),
  public.reviews_for_target(text, uuid, int, int),
  public.featured_treatments(int)
  to anon, authenticated, service_role;

insert into public.app_migrations(name) values ('0018_treatments_read') on conflict do nothing;
