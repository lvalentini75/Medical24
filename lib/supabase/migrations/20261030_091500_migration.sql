-- ============================================================================
-- Medical 24 — 0008 BODY & ORGANS (P04-A) · modulo M5 Corpo e organi
--
-- Contenuto:
--   1. organs                 (le 12 aree di doc/body/organs.json)
--   2. organ_biomarker_map    (area <-> codice, con peso)
--   3. rule_versions          (regole versionate del board)
--   4. organ_states           (append-only) + vista latest_organ_states
--   5. compute_organ_states() (regola organ_state v0.1)
--   6. trigger su observations + pg_cron 04:15
--   7. letture per le schermate: organ_overview, organ_biomarkers,
--      organ_history, organ_comparison, organ_episodes
--
-- Non tocca documents, extractions, la funzione extract né le schermate.
-- observations resta append-only: nessun update viene fatto qui.
-- Idempotente: può essere rieseguita senza effetti collaterali.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- 0. Enum
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'organ_state') then
    create type organ_state as enum ('ok', 'monitor', 'attention', 'missing');
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'rule_status') then
    create type rule_status as enum ('draft', 'active', 'retired');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1. organs — le 12 aree del corpo (contenuto istituzionale, non clinico)
-- ---------------------------------------------------------------------------
create table if not exists public.organs (
  id             text primary key,
  sort_order     int  not null,
  name_it        text not null,
  name_en        text not null,
  description_it text not null default '',
  description_en text not null default '',
  icon           text not null default '',
  anchor_x       numeric not null check (anchor_x >= 0 and anchor_x <= 1),
  anchor_y       numeric not null check (anchor_y >= 0 and anchor_y <= 1),
  version        text not null default '0.1-draft',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

comment on table public.organs is
  'Le 12 aree del corpo del modulo M5. anchor_x/anchor_y = posizione del punto '
  'sulla silhouette in frazioni di larghezza e altezza. '
  'Sorgente: doc/body/organs.json v0.1-draft, da validare dal board.';

create unique index if not exists idx_organs_sort_order on public.organs (sort_order);

drop trigger if exists trg_organs_updated_at on public.organs;
create trigger trg_organs_updated_at before update on public.organs
  for each row execute function public.set_updated_at();

insert into public.organs (
  id, sort_order, name_it, name_en, description_it, description_en,
  icon, anchor_x, anchor_y, version
) values
  ('heart', 1, 'Cuore e circolazione', 'Heart and circulation',
   'Lipidi, pressione, frequenza cardiaca e marcatori cardiaci',
   'Lipids, blood pressure, heart rate and cardiac markers',
   'heart-pulse', 0.44, 0.31, '0.1-draft'),
  ('lung', 2, 'Polmoni e respiro', 'Lungs and breathing',
   'Saturazione e parametri respiratori',
   'Oxygen saturation and respiratory parameters',
   'wind', 0.615, 0.30, '0.1-draft'),
  ('liver', 3, 'Fegato', 'Liver',
   'Transaminasi, gamma GT, bilirubina, proteine',
   'Transaminases, gamma GT, bilirubin, proteins',
   'flask-conical', 0.41, 0.415, '0.1-draft'),
  ('kidney', 4, 'Reni e vie urinarie', 'Kidneys and urinary tract',
   'Creatinina, filtrato, azotemia, elettroliti, esame urine',
   'Creatinine, eGFR, urea, electrolytes, urinalysis',
   'filter', 0.60, 0.445, '0.1-draft'),
  ('metabolism', 5, 'Metabolismo e pancreas', 'Metabolism and pancreas',
   'Glicemia, HbA1c, insulina, amilasi, lipasi, peso',
   'Glucose, HbA1c, insulin, amylase, lipase, weight',
   'flame', 0.50, 0.46, '0.1-draft'),
  ('gut', 6, 'Stomaco e intestino', 'Stomach and gut',
   'Area in attesa di biomarcatori del board',
   'Area awaiting board biomarkers',
   'utensils-crossed', 0.50, 0.545, '0.1-draft'),
  ('blood', 7, 'Sangue', 'Blood',
   'Emocromo, ferro, coagulazione, vitamine',
   'Blood count, iron, coagulation, vitamins',
   'droplet', 0.21, 0.50, '0.1-draft'),
  ('immune', 8, 'Difese e infiammazione', 'Immunity and inflammation',
   'Leucociti, PCR, VES, immunoglobuline',
   'White cells, CRP, ESR, immunoglobulins',
   'shield-check', 0.79, 0.50, '0.1-draft'),
  ('thyroid', 9, 'Tiroide e ormoni', 'Thyroid and hormones',
   'TSH, FT3, FT4 e altri ormoni', 'TSH, FT3, FT4 and other hormones',
   'circle-dot', 0.50, 0.19, '0.1-draft'),
  ('brain', 10, 'Cervello e nervi', 'Brain and nerves',
   'Area in attesa di biomarcatori del board',
   'Area awaiting board biomarkers',
   'brain', 0.50, 0.082, '0.1-draft'),
  ('musculoskeletal', 11, 'Ossa e muscoli', 'Bones and muscles',
   'Calcio, vitamina D, fosfatasi alcalina, CK',
   'Calcium, vitamin D, alkaline phosphatase, CK',
   'bone', 0.50, 0.80, '0.1-draft'),
  ('reproductive', 12, 'Apparato riproduttivo', 'Reproductive system',
   'Ormoni sessuali, PSA', 'Sex hormones, PSA',
   'venus-and-mars', 0.50, 0.63, '0.1-draft')
on conflict (id) do update set
  sort_order     = excluded.sort_order,
  name_it        = excluded.name_it,
  name_en        = excluded.name_en,
  description_it = excluded.description_it,
  description_en = excluded.description_en,
  icon           = excluded.icon,
  anchor_x       = excluded.anchor_x,
  anchor_y       = excluded.anchor_y,
  version        = excluded.version;

-- ---------------------------------------------------------------------------
-- 2. organ_biomarker_map
--    Generata dalla colonna organs del catalogo con la fusione dichiarata
--    in organs.json (catalog_keys -> id area):
--      heart <- heart | lung <- lung | liver <- liver | kidney <- kidney
--      metabolism <- metabolism, pancreas | gut <- gut | blood <- blood
--      immune <- immune | thyroid <- thyroid | brain <- brain
--      musculoskeletal <- bone, muscle | reproductive <- reproductive, prostate
--    weight = 2 se is_essential, altrimenti 1.
-- ---------------------------------------------------------------------------
create table if not exists public.organ_biomarker_map (
  organ_id   text not null references public.organs (id) on delete cascade,
  code       text not null references public.biomarker_catalog (code) on delete cascade,
  weight     smallint not null default 1 check (weight between 1 and 3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (organ_id, code)
);

comment on table public.organ_biomarker_map is
  'Area del corpo <-> biomarcatore con peso. Rigenerata dalla colonna organs '
  'del catalogo: peso 2 per i biomarcatori essenziali, 1 per gli altri.';

create index if not exists idx_organ_biomarker_map_code
  on public.organ_biomarker_map (code);

drop trigger if exists trg_organ_biomarker_map_updated_at on public.organ_biomarker_map;
create trigger trg_organ_biomarker_map_updated_at before update on public.organ_biomarker_map
  for each row execute function public.set_updated_at();

-- La fusione catalog_key -> area è una funzione sola, così il giorno in cui
-- il board aggiunge un biomarcatore basta rieseguire rebuild_organ_biomarker_map().
create or replace function public.organ_for_catalog_key(p_key text)
returns text
language sql
immutable
as $$
  select case lower(btrim(coalesce(p_key, '')))
    when 'heart'        then 'heart'
    when 'lung'         then 'lung'
    when 'liver'        then 'liver'
    when 'kidney'       then 'kidney'
    when 'metabolism'   then 'metabolism'
    when 'pancreas'     then 'metabolism'
    when 'gut'          then 'gut'
    when 'blood'        then 'blood'
    when 'immune'       then 'immune'
    when 'thyroid'      then 'thyroid'
    when 'brain'        then 'brain'
    when 'bone'         then 'musculoskeletal'
    when 'muscle'       then 'musculoskeletal'
    when 'reproductive' then 'reproductive'
    when 'prostate'     then 'reproductive'
    else null
  end;
$$;

create or replace function public.rebuild_organ_biomarker_map()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows int;
begin
  -- Codici manuali della 0007 mappati esplicitamente sulle aree giuste:
  -- pressione sistolica/diastolica e frequenza -> heart, peso e glicemia ->
  -- metabolism, saturazione -> lung + heart, temperatura -> immune.
  -- Sono già i valori della colonna organs del catalogo, quindi la mappa
  -- esplicita e quella generata coincidono: qui si garantisce la presenza.
  with pairs as (
    select public.organ_for_catalog_key(k) as organ_id,
           c.code,
           case when c.is_essential then 2 else 1 end::smallint as weight
    from public.biomarker_catalog c
    cross join lateral unnest(c.organs) as k
    where public.organ_for_catalog_key(k) is not null
    union
    select v.organ_id, v.code,
           case when c.is_essential then 2 else 1 end::smallint as weight
    from (values
      ('heart',      '8480-6'),  -- pressione sistolica
      ('heart',      '8462-4'),  -- pressione diastolica
      ('heart',      '8867-4'),  -- frequenza cardiaca
      ('metabolism', '29463-7'), -- peso
      ('metabolism', '2345-7'),  -- glicemia
      ('lung',       '59408-5'), -- saturazione
      ('heart',      '59408-5'),
      ('immune',     '8310-5')   -- temperatura
    ) as v(organ_id, code)
    join public.biomarker_catalog c on c.code = v.code
  ), deduped as (
    select organ_id, code, max(weight)::smallint as weight
    from pairs group by organ_id, code
  ), upserted as (
    insert into public.organ_biomarker_map (organ_id, code, weight)
    select organ_id, code, weight from deduped
    on conflict (organ_id, code) do update set weight = excluded.weight
    returning 1
  )
  select count(*)::int into v_rows from upserted;

  -- Righe non più previste dal catalogo escono dalla mappa.
  delete from public.organ_biomarker_map m
  where not exists (
    select 1 from public.biomarker_catalog c
    cross join lateral unnest(c.organs) as k
    where c.code = m.code and public.organ_for_catalog_key(k) = m.organ_id
  );

  return v_rows;
end;
$$;

revoke execute on function public.rebuild_organ_biomarker_map() from public, anon, authenticated;

select public.rebuild_organ_biomarker_map();

-- ---------------------------------------------------------------------------
-- 3. rule_versions — le regole versionate del board
-- ---------------------------------------------------------------------------
create table if not exists public.rule_versions (
  id          uuid primary key default gen_random_uuid(),
  type        text not null,
  version     text not null,
  definition  jsonb not null default '{}'::jsonb,
  status      rule_status not null default 'draft',
  approved_by uuid references auth.users (id) on delete set null,
  approved_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  notes       text,
  unique (type, version)
);

comment on table public.rule_versions is
  'Regole deterministiche del board con la loro definizione JSON. '
  'Ogni dato clinico calcolato porta il riferimento type/version.';

create index if not exists idx_rule_versions_type_status
  on public.rule_versions (type, status);

drop trigger if exists trg_rule_versions_updated_at on public.rule_versions;
create trigger trg_rule_versions_updated_at before update on public.rule_versions
  for each row execute function public.set_updated_at();

insert into public.rule_versions (type, version, status, notes, definition)
values (
  'organ_state', '0.1', 'active',
  'bozza provvisoria in attesa di validazione del board',
  jsonb_build_object(
    'window_months', 24,
    'input', 'ultima osservazione per codice della vista biomarker_series',
    'states', jsonb_build_array('ok','monitor','attention','missing'),
    'weights', jsonb_build_object('essential', 2, 'standard', 1),
    'thresholds', jsonb_build_object(
      'attention_critical_flags', jsonb_build_array('critical_low','critical_high'),
      'out_of_range_flags', jsonb_build_array('below','above'),
      'attention_out_of_range_weight', 2,
      'monitor_out_of_range_weight', 1
    ),
    'confidence', jsonb_build_object(
      'numerator', 'somma dei pesi dei codici presenti',
      'denominator_essential', 'somma dei pesi dei codici essenziali dell area',
      'denominator_fallback', 3,
      'cap', 1
    ),
    'missing_when', 'nessun input nella finestra'
  )
)
on conflict (type, version) do update set
  status     = excluded.status,
  notes      = excluded.notes,
  definition = excluded.definition;

-- ---------------------------------------------------------------------------
-- 4. organ_states — append-only, una riga per calcolo che cambia qualcosa
--    inputs: solo codici, id e flag. Nessun valore e nessun testo libero.
-- ---------------------------------------------------------------------------
create table if not exists public.organ_states (
  id           uuid primary key default gen_random_uuid(),
  subject_id   uuid not null,
  organ_id     text not null references public.organs (id) on delete restrict,
  state        organ_state not null,
  confidence   numeric not null default 0 check (confidence >= 0 and confidence <= 1),
  inputs       jsonb not null default '[]'::jsonb,
  rule_version text not null default 'organ_state-0.1',
  -- clock_timestamp(): due calcoli nella stessa transazione restano ordinabili.
  computed_at  timestamptz not null default clock_timestamp()
);

comment on table public.organ_states is
  'Stato per area del corpo, append-only: una riga per ogni calcolo che '
  'cambia stato, confidenza o insieme degli input. inputs contiene solo '
  'codice, id osservazione, flag, data e peso: nessun valore clinico.';

create index if not exists idx_organ_states_subject_organ_time
  on public.organ_states (subject_id, organ_id, computed_at desc);

-- Stesso meccanismo append-only delle observations.
create or replace function public.organ_states_append_only()
returns trigger
language plpgsql
as $$
begin
  if current_setting('medical24.allow_organ_state_write', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception 'organ_states_append_only' using errcode = '42501';
end;
$$;

drop trigger if exists trg_organ_states_append_only on public.organ_states;
create trigger trg_organ_states_append_only
  before update or delete on public.organ_states
  for each row execute function public.organ_states_append_only();

revoke execute on function public.organ_states_append_only() from public, anon, authenticated;

create or replace view public.latest_organ_states
with (security_invoker = true)
as
select distinct on (s.subject_id, s.organ_id)
  s.id, s.subject_id, s.organ_id, s.state, s.confidence, s.inputs,
  s.rule_version, s.computed_at
from public.organ_states s
order by s.subject_id, s.organ_id, s.computed_at desc, s.id desc;

comment on view public.latest_organ_states is
  'Stato di oggi per soggetto e area: ultima riga di organ_states.';

-- ---------------------------------------------------------------------------
-- 5. compute_organ_states — regola organ_state v0.1
-- ---------------------------------------------------------------------------
create or replace function public.compute_organ_states(p_subject uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  o            record;
  v_inputs     jsonb;
  v_state      organ_state;
  v_confidence numeric;
  v_rule       text;
  v_window     interval;
  v_present_w  numeric;
  v_essential_w numeric;
  v_present_n  int;
  v_out_weight numeric;
  v_has_crit   boolean;
  v_last_state  organ_state;
  v_last_conf   numeric;
  v_last_inputs jsonb;
  v_written    int := 0;
begin
  if p_subject is null then
    raise exception 'subject_required' using errcode = 'P0001';
  end if;
  -- Dal trigger e dal cron auth.uid() è null: il controllo vale solo
  -- quando la chiamata arriva da un utente.
  if auth.uid() is not null and not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select 'organ_state-' || r.version,
         make_interval(months => coalesce((r.definition ->> 'window_months')::int, 24))
    into v_rule, v_window
  from public.rule_versions r
  where r.type = 'organ_state' and r.status = 'active'
  order by r.version desc
  limit 1;

  if v_rule is null then
    v_rule := 'organ_state-0.1';
    v_window := interval '24 months';
  end if;

  for o in select id from public.organs order by sort_order loop
    -- Un input per codice mappato: l'ultima osservazione nella finestra.
    with mapped as (
      select m.code, m.weight
      from public.organ_biomarker_map m
      where m.organ_id = o.id
    ), latest as (
      select mp.code, mp.weight, s.observation_id, s.flag, s.effective_at
      from mapped mp
      join lateral (
        select b.observation_id, b.flag, b.effective_at
        from public.biomarker_series b
        where b.subject_id = p_subject
          and b.code = mp.code
          and b.effective_at >= now() - v_window
          and b.effective_at <= now()
        order by b.effective_at desc, b.observation_id desc
        limit 1
      ) s on true
    )
    select
      coalesce(jsonb_agg(jsonb_build_object(
        'code', l.code,
        'observation_id', l.observation_id,
        'flag', l.flag,
        -- UTC esplicito: l'uguaglianza fra inputs non deve dipendere dal
        -- fuso orario della sessione che esegue il calcolo.
        'effective_at', (l.effective_at at time zone 'UTC'),
        'weight', l.weight
      ) order by l.code), '[]'::jsonb),
      coalesce(sum(l.weight), 0),
      count(*)::int,
      coalesce(sum(l.weight) filter (where l.flag in ('below','above')), 0),
      coalesce(bool_or(l.flag in ('critical_low','critical_high')), false)
      into v_inputs, v_present_w, v_present_n, v_out_weight, v_has_crit
    from latest l;

    select coalesce(sum(m.weight), 0) into v_essential_w
    from public.organ_biomarker_map m
    join public.biomarker_catalog c on c.code = m.code
    where m.organ_id = o.id and c.is_essential;

    if v_present_n = 0 then
      v_state := 'missing';
    elsif v_has_crit then
      v_state := 'attention';
    elsif v_out_weight >= 2 then
      v_state := 'attention';
    elsif v_out_weight >= 1 then
      v_state := 'monitor';
    else
      v_state := 'ok';
    end if;

    if v_essential_w > 0 then
      v_confidence := least(1, v_present_w / v_essential_w);
    else
      v_confidence := least(1, v_present_n::numeric / 3);
    end if;

    v_last_state := null; v_last_conf := null; v_last_inputs := null;
    select s.state, s.confidence, s.inputs
      into v_last_state, v_last_conf, v_last_inputs
    from public.organ_states s
    where s.subject_id = p_subject and s.organ_id = o.id
    order by s.computed_at desc, s.id desc
    limit 1;

    if v_last_state is null
       or v_last_state is distinct from v_state
       or round(coalesce(v_last_conf, 0), 2) is distinct from round(v_confidence, 2)
       or coalesce(v_last_inputs, '[]'::jsonb) is distinct from v_inputs then
      insert into public.organ_states (
        subject_id, organ_id, state, confidence, inputs, rule_version
      ) values (
        p_subject, o.id, v_state, round(v_confidence, 2), v_inputs, v_rule
      );
      v_written := v_written + 1;
    end if;
  end loop;

  return v_written;
end;
$$;

revoke execute on function public.compute_organ_states(uuid) from public, anon;
grant execute on function public.compute_organ_states(uuid) to authenticated;

create or replace function public.compute_organ_states_all()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  s record;
  total int := 0;
begin
  for s in select distinct subject_id from public.observations loop
    total := total + public.compute_organ_states(s.subject_id);
  end loop;
  return total;
end;
$$;

revoke execute on function public.compute_organ_states_all() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. Trigger su observations + cron notturno
-- ---------------------------------------------------------------------------
create or replace function public.refresh_organ_states_from_observation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.confirmed_at is null
     or new.review_status = 'discarded'
     or new.superseded_at is not null then
    return new;
  end if;
  perform public.compute_organ_states(new.subject_id);
  return new;
end;
$$;

-- Il nome mette il trigger in coda all'ordine alfabetico, dopo
-- trg_observations_supersede_previous: così il calcolo vede già la riga
-- precedente marcata superseded_at e non la conta come input.
drop trigger if exists trg_observations_organ_states on public.observations;
drop trigger if exists trg_observations_zz_organ_states on public.observations;
create trigger trg_observations_zz_organ_states
  after insert on public.observations
  for each row execute function public.refresh_organ_states_from_observation();

revoke execute on function public.refresh_organ_states_from_observation() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('compute-organ-states')
      where exists (select 1 from cron.job where jobname = 'compute-organ-states');
    perform cron.schedule(
      'compute-organ-states',
      '15 4 * * *',
      $cron$select public.compute_organ_states_all()$cron$
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 7. Letture per le schermate — tutte security invoker
-- ---------------------------------------------------------------------------
create or replace function public.organ_overview(p_subject uuid)
returns table (
  organ_id text, sort_order int, name_it text, name_en text,
  description_it text, description_en text, icon text,
  anchor_x numeric, anchor_y numeric,
  state organ_state, confidence numeric, computed_at timestamptz,
  present_codes int, mapped_codes int
)
language sql
stable
security invoker
set search_path = public
as $$
  select o.id, o.sort_order, o.name_it, o.name_en,
         o.description_it, o.description_en, o.icon, o.anchor_x, o.anchor_y,
         l.state, l.confidence, l.computed_at,
         coalesce(jsonb_array_length(l.inputs), 0)::int as present_codes,
         coalesce(m.mapped_codes, 0)::int as mapped_codes
  from public.organs o
  left join public.latest_organ_states l
    on l.organ_id = o.id and l.subject_id = p_subject
  left join lateral (
    select count(*)::int as mapped_codes
    from public.organ_biomarker_map bm where bm.organ_id = o.id
  ) m on true
  order by o.sort_order;
$$;

create or replace function public.organ_biomarkers(p_subject uuid, p_organ text)
returns table (
  code text, name_it text, name_en text, unit_canonical text,
  latest_value numeric, latest_at timestamptz, flag observation_flag,
  weight smallint, is_present boolean
)
language sql
stable
security invoker
set search_path = public
as $$
  select c.code, c.name_it, c.name_en, c.unit_canonical,
         l.canonical_value, l.effective_at, l.flag,
         m.weight, (l.observation_id is not null) as is_present
  from public.organ_biomarker_map m
  join public.biomarker_catalog c on c.code = m.code
  left join lateral (
    select b.observation_id, b.canonical_value, b.effective_at, b.flag
    from public.biomarker_series b
    where b.subject_id = p_subject and b.code = m.code
    order by b.effective_at desc, b.observation_id desc
    limit 1
  ) l on true
  where m.organ_id = p_organ
  order by m.weight desc, c.name_it;
$$;

create or replace function public.organ_history(p_subject uuid, p_organ text)
returns table (
  id uuid, state organ_state, confidence numeric,
  inputs jsonb, rule_version text, computed_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select s.id, s.state, s.confidence, s.inputs, s.rule_version, s.computed_at
  from public.organ_states s
  where s.subject_id = p_subject and s.organ_id = p_organ
  order by s.computed_at, s.id;
$$;

create or replace function public.organ_comparison(p_subject uuid, p_organ text)
returns table (
  current_state organ_state, current_at timestamptz,
  state_6m organ_state, at_6m timestamptz,
  state_12m organ_state, at_12m timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    cur.state, cur.computed_at,
    m6.state, m6.computed_at,
    m12.state, m12.computed_at
  from (select 1) one
  left join lateral (
    select s.state, s.computed_at from public.organ_states s
    where s.subject_id = p_subject and s.organ_id = p_organ
    order by s.computed_at desc, s.id desc limit 1
  ) cur on true
  left join lateral (
    select s.state, s.computed_at from public.organ_states s
    where s.subject_id = p_subject and s.organ_id = p_organ
      and s.computed_at <= now() - interval '6 months'
    order by s.computed_at desc, s.id desc limit 1
  ) m6 on true
  left join lateral (
    select s.state, s.computed_at from public.organ_states s
    where s.subject_id = p_subject and s.organ_id = p_organ
      and s.computed_at <= now() - interval '12 months'
    order by s.computed_at desc, s.id desc limit 1
  ) m12 on true;
$$;

create or replace function public.organ_episodes(p_subject uuid, p_organ text)
returns table (episode_start timestamptz, episode_end timestamptz)
language sql
stable
security invoker
set search_path = public
as $$
  with ordered as (
    select s.computed_at, s.id, s.state = 'attention' as is_att,
           lag(s.state = 'attention', 1, false)
             over (order by s.computed_at, s.id) as was_att
    from public.organ_states s
    where s.subject_id = p_subject and s.organ_id = p_organ
  ), marked as (
    select *, sum(case when is_att and not was_att then 1 else 0 end)
      over (order by computed_at, id) as grp
    from ordered
  ), grouped as (
    select grp, min(computed_at) as episode_start, max(computed_at) as last_att
    from marked where is_att group by grp
  )
  select g.episode_start,
    (select min(o.computed_at) from ordered o
      where not o.is_att and o.computed_at > g.last_att) as episode_end
  from grouped g
  order by g.episode_start;
$$;

-- ---------------------------------------------------------------------------
-- 8. RLS
-- ---------------------------------------------------------------------------
alter table public.organs               enable row level security;
alter table public.organ_biomarker_map  enable row level security;
alter table public.rule_versions        enable row level security;
alter table public.organ_states         enable row level security;
alter table public.organs               force  row level security;
alter table public.organ_biomarker_map  force  row level security;
alter table public.rule_versions        force  row level security;
alter table public.organ_states         force  row level security;

-- organs: lettura per authenticated, scrittura board e admin.
drop policy if exists organs_select on public.organs;
create policy organs_select on public.organs
  for select to authenticated using (true);

drop policy if exists organs_write on public.organs;
create policy organs_write on public.organs
  for all to authenticated
  using (public.has_role('board') or public.has_role('admin'))
  with check (public.has_role('board') or public.has_role('admin'));

drop policy if exists organ_biomarker_map_select on public.organ_biomarker_map;
create policy organ_biomarker_map_select on public.organ_biomarker_map
  for select to authenticated using (true);

drop policy if exists organ_biomarker_map_write on public.organ_biomarker_map;
create policy organ_biomarker_map_write on public.organ_biomarker_map
  for all to authenticated
  using (public.has_role('board') or public.has_role('admin'))
  with check (public.has_role('board') or public.has_role('admin'));

-- rule_versions: lettura delle righe active e draft, scrittura board e admin.
drop policy if exists rule_versions_select on public.rule_versions;
create policy rule_versions_select on public.rule_versions
  for select to authenticated
  using (status in ('active', 'draft'));

drop policy if exists rule_versions_write on public.rule_versions;
create policy rule_versions_write on public.rule_versions
  for all to authenticated
  using (public.has_role('board') or public.has_role('admin'))
  with check (public.has_role('board') or public.has_role('admin'));

-- organ_states: sola lettura del soggetto. Nessuna policy di insert, update
-- o delete: scrive solo compute_organ_states (security definer).
drop policy if exists organ_states_select on public.organ_states;
create policy organ_states_select on public.organ_states
  for select to authenticated
  using (public.can_access_subject(subject_id));

-- ---------------------------------------------------------------------------
-- 9. Grants
-- ---------------------------------------------------------------------------
revoke all on public.organs, public.organ_biomarker_map,
               public.rule_versions, public.organ_states from anon;
revoke all on public.latest_organ_states from anon;

grant select on public.organs              to authenticated;
grant select on public.organ_biomarker_map to authenticated;
grant select on public.rule_versions       to authenticated;
grant select on public.organ_states        to authenticated;
grant select on public.latest_organ_states to authenticated;

grant insert, update, delete on public.organs              to authenticated;
grant insert, update, delete on public.organ_biomarker_map to authenticated;
grant insert, update, delete on public.rule_versions       to authenticated;
revoke insert, update, delete on public.organ_states from authenticated;

grant execute on function public.organ_overview(uuid)          to authenticated;
grant execute on function public.organ_biomarkers(uuid, text)  to authenticated;
grant execute on function public.organ_history(uuid, text)     to authenticated;
grant execute on function public.organ_comparison(uuid, text)  to authenticated;
grant execute on function public.organ_episodes(uuid, text)    to authenticated;

revoke execute on function public.organ_overview(uuid)         from public, anon;
revoke execute on function public.organ_biomarkers(uuid, text) from public, anon;
revoke execute on function public.organ_history(uuid, text)    from public, anon;
revoke execute on function public.organ_comparison(uuid, text) from public, anon;
revoke execute on function public.organ_episodes(uuid, text)   from public, anon;
revoke execute on function public.organ_for_catalog_key(text)  from public, anon;

-- ---------------------------------------------------------------------------
-- 10. Controllo del seed
-- ---------------------------------------------------------------------------
do $$
declare
  n_organs int;
  n_map    int;
begin
  select count(*) into n_organs from public.organs;
  select count(*) into n_map    from public.organ_biomarker_map;
  raise notice 'organs: % righe (attese 12); organ_biomarker_map: % righe',
    n_organs, n_map;
  if n_organs <> 12 then
    raise exception 'organs seed incompleto: % righe', n_organs;
  end if;
  if n_map = 0 then
    raise exception 'organ_biomarker_map vuota';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 11. Registro
-- ---------------------------------------------------------------------------
insert into public.app_migrations (name)
values ('0008_body_organs')
on conflict do nothing;
