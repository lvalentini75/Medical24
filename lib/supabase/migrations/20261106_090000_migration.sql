-- ============================================================================
-- Medical 24 — 0017 TREATMENTS SCHEMA (P07-A1) — modulo M8 Cure
--
-- Solo schema, vincoli, indici, trigger e RLS. Nessuna funzione applicativa
-- (arrivano con P07-A2 e P07-A3), nessuna schermata, nessun seed di contenuto.
--
-- Tabelle create (sette, tutte con RLS forzata e default deny):
--   facilities        strutture sanitarie
--   doctors           profili dei professionisti
--   treatment_tags    vocabolario controllato dei tag delle cure
--   treatments        schede cura, con search_vector 'italian' generata
--   reviews           recensioni su cura, medico o struttura, moderate
--   favorites         preferiti dell'utente (unica tabella con scrittura diretta)
--   rating_summaries  medie e conteggi, mantenute da un trigger su reviews
--
-- Regole di accesso in breve:
--   lettura pubblica solo di cio' che e' pubblicato, verificato o dimostrativo;
--   l'autore vede sempre le proprie recensioni, in qualunque stato;
--   admin legge tutto; nessuno scrive direttamente, tranne il proprietario
--   sui propri preferiti.
--
-- Idempotente: puo' essere rieseguita senza effetti collaterali.
-- ============================================================================

create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";

-- ---------------------------------------------------------------------------
-- 1. Enum del modulo
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_type where typname = 'facility_kind') then
    create type facility_kind as enum (
      'ospedale','clinica','poliambulatorio','studio',
      'centro_riabilitazione','farmacia','altro');
  end if;
  if not exists (select 1 from pg_type where typname = 'doctor_role') then
    create type doctor_role as enum (
      'medico','medico_dietologo','dietista','biologo_nutrizionista',
      'fisioterapista','altro');
  end if;
  if not exists (select 1 from pg_type where typname = 'treatment_tag_kind') then
    create type treatment_tag_kind as enum ('categoria','patologia','obiettivo','modalita');
  end if;
  if not exists (select 1 from pg_type where typname = 'treatment_family') then
    create type treatment_family as enum ('tradizionale','sperimentale','naturale','altro');
  end if;
  if not exists (select 1 from pg_type where typname = 'treatment_scope') then
    create type treatment_scope as enum (
      'riabilitazione','prevenzione','benessere','diagnostica','terapia');
  end if;
  if not exists (select 1 from pg_type where typname = 'treatment_evidence_level') then
    create type treatment_evidence_level as enum (
      'linee_guida','studi_clinici','osservazionale','esperienziale','non_valutato');
  end if;
  if not exists (select 1 from pg_type where typname = 'treatment_modality') then
    create type treatment_modality as enum ('presenza','online','ibrido','domicilio');
  end if;
  if not exists (select 1 from pg_type where typname = 'treatment_status') then
    create type treatment_status as enum ('draft','verified','published','retired');
  end if;
  -- Un solo enum di bersaglio per reviews, favorites e rating_summaries:
  -- le tre tabelle devono sempre parlare la stessa lingua.
  if not exists (select 1 from pg_type where typname = 'review_target_type') then
    create type review_target_type as enum ('treatment','doctor','facility');
  end if;
  if not exists (select 1 from pg_type where typname = 'review_status') then
    create type review_status as enum ('pending','approved','rejected','withdrawn');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Funzioni di validazione (immutabili: servono in check e generated)
-- ---------------------------------------------------------------------------

-- Oggetto JSON le cui chiavi sono tutte nell'elenco consentito.
create or replace function public.m24_jsonb_keys_subset(p_doc jsonb, p_allowed text[])
returns boolean
language sql
immutable
as $$
  select p_doc is null
      or (jsonb_typeof(p_doc) = 'object'
          and not exists (
            select 1 from jsonb_object_keys(p_doc) as k(key)
            where not (k.key = any(p_allowed))));
$$;

-- contraindications: array di {text, severity in (bassa, media, alta)}.
create or replace function public.m24_valid_contraindications(p_doc jsonb)
returns boolean
language sql
immutable
as $$
  select p_doc is null
      or (jsonb_typeof(p_doc) = 'array'
          and not exists (
            select 1 from jsonb_array_elements(p_doc) as e(item)
            where jsonb_typeof(e.item) <> 'object'
               or coalesce(jsonb_typeof(e.item->'text'), 'missing') <> 'string'
               or coalesce(e.item->>'severity', '') not in ('bassa','media','alta')));
$$;

-- media: array di {type in (image, video), url, caption opzionale}.
create or replace function public.m24_valid_media(p_doc jsonb)
returns boolean
language sql
immutable
as $$
  select p_doc is null
      or (jsonb_typeof(p_doc) = 'array'
          and not exists (
            select 1 from jsonb_array_elements(p_doc) as e(item)
            where jsonb_typeof(e.item) <> 'object'
               or coalesce(e.item->>'type', '') not in ('image','video')
               or coalesce(jsonb_typeof(e.item->'url'), 'missing') <> 'string'
               or (e.item ? 'caption' and jsonb_typeof(e.item->'caption') <> 'string')));
$$;

-- Documento di ricerca della scheda cura, configurazione 'italian'.
-- Dichiarata immutable: usa solo to_tsvector a configurazione fissa,
-- array_to_string su text[] e accessi jsonb ->> .
create or replace function public.m24_treatment_search_doc(
  p_title      text,
  p_summary    text,
  p_category   text,
  p_conditions text[],
  p_tags       text[],
  p_sections   jsonb
)
returns tsvector
language sql
immutable
as $$
  select to_tsvector('italian',
    coalesce(p_title, '') || ' ' ||
    coalesce(p_summary, '') || ' ' ||
    coalesce(p_category, '') || ' ' ||
    coalesce(array_to_string(p_conditions, ' '), '') || ' ' ||
    coalesce(array_to_string(p_tags, ' '), '') || ' ' ||
    coalesce(p_sections->>'per_chi', '') || ' ' ||
    coalesce(p_sections->>'come_funziona', '') || ' ' ||
    coalesce(p_sections->>'durata', '') || ' ' ||
    coalesce(p_sections->>'rischi_e_controindicazioni', '') || ' ' ||
    coalesce(p_sections->>'evidenze_e_limiti', ''));
$$;

-- ---------------------------------------------------------------------------
-- 3. facilities
-- ---------------------------------------------------------------------------
create table if not exists public.facilities (
  id              uuid primary key default gen_random_uuid(),
  name            text not null check (char_length(btrim(name)) > 0),
  kind            facility_kind not null default 'altro',
  ssn_accredited  boolean not null default false,
  address         text,
  city            text,
  region          text,
  country         text not null default 'IT' check (char_length(country) = 2),
  lat             numeric(9,6) check (lat is null or (lat >= -90 and lat <= 90)),
  lng             numeric(9,6) check (lng is null or (lng >= -180 and lng <= 180)),
  phone           text,
  email           text,
  website         text,
  services        text[] not null default '{}',
  opening_hours   jsonb not null default '{}'::jsonb
                    check (jsonb_typeof(opening_hours) = 'object'),
  photos          text[] not null default '{}',
  verified        boolean not null default false,
  is_demo         boolean not null default false,
  created_by      uuid references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.facilities is
  'Strutture sanitarie del modulo Cure. Lettura pubblica solo se verified '
  'oppure is_demo; nessuna scrittura diretta (P07-A2/A3).';

create index if not exists idx_facilities_city on public.facilities (city);
create index if not exists idx_facilities_kind_verified on public.facilities (kind, verified);
create index if not exists idx_facilities_name_trgm on public.facilities using gin (name gin_trgm_ops);

drop trigger if exists trg_facilities_updated_at on public.facilities;
create trigger trg_facilities_updated_at before update on public.facilities
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4. doctors
-- ---------------------------------------------------------------------------
create table if not exists public.doctors (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references auth.users(id) on delete set null,
  display_name    text not null check (char_length(btrim(display_name)) > 0),
  role            doctor_role not null default 'medico',
  specialties     text[] not null default '{}',
  registry_body   text,
  registry_number text,
  verified        boolean not null default false,
  languages       text[] not null default '{}',
  bio             text,
  photo_url       text,
  facility_id     uuid references public.facilities(id) on delete set null,
  is_demo         boolean not null default false,
  created_by      uuid references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.doctors is
  'Profili dei professionisti. Lettura pubblica solo se verified oppure '
  'is_demo; nessuna scrittura diretta (P07-A2/A3).';

create unique index if not exists idx_doctors_user on public.doctors (user_id)
  where user_id is not null;
create index if not exists idx_doctors_facility on public.doctors (facility_id);
create index if not exists idx_doctors_role_verified on public.doctors (role, verified);
create index if not exists idx_doctors_name_trgm on public.doctors using gin (display_name gin_trgm_ops);

drop trigger if exists trg_doctors_updated_at on public.doctors;
create trigger trg_doctors_updated_at before update on public.doctors
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 5. treatment_tags — vocabolario controllato
-- ---------------------------------------------------------------------------
create table if not exists public.treatment_tags (
  tag        text primary key check (tag = lower(btrim(tag)) and char_length(tag) > 0),
  label_it   text not null,
  label_en   text not null,
  kind       treatment_tag_kind not null,
  sort_order int not null default 100
);

comment on table public.treatment_tags is
  'Vocabolario dei tag delle cure. Lettura pubblica; nessuna scrittura diretta. '
  'Il seed dei tag arriva con P07-A2.';

create index if not exists idx_treatment_tags_kind_sort on public.treatment_tags (kind, sort_order);

-- ---------------------------------------------------------------------------
-- 6. treatments
-- ---------------------------------------------------------------------------
create table if not exists public.treatments (
  id                   uuid primary key default gen_random_uuid(),
  title                text not null check (char_length(btrim(title)) > 0),
  summary              text check (summary is null or char_length(summary) <= 240),
  description_sections jsonb not null default '{}'::jsonb
                         check (jsonb_typeof(description_sections) = 'object'
                                and public.m24_jsonb_keys_subset(description_sections,
                                  array['per_chi','come_funziona','durata',
                                        'rischi_e_controindicazioni','evidenze_e_limiti'])),
  family               treatment_family not null default 'tradizionale',
  scope                treatment_scope not null default 'terapia',
  category             text,
  conditions           text[] not null default '{}',
  tags                 text[] not null default '{}',
  evidence_level       treatment_evidence_level not null default 'non_valutato',
  contraindications    jsonb not null default '[]'::jsonb
                         check (public.m24_valid_contraindications(contraindications)),
  price_from_cents     int check (price_from_cents is null or price_from_cents >= 0),
  price_to_cents       int check (price_to_cents is null or price_to_cents >= 0),
  currency             text not null default 'EUR' check (char_length(currency) = 3),
  price_notes          text,
  ssn_covered          boolean not null default false,
  session_minutes      int check (session_minutes is null or session_minutes > 0),
  sessions_count       int check (sessions_count is null or sessions_count > 0),
  course_weeks         int check (course_weeks is null or course_weeks > 0),
  waiting_days         int check (waiting_days is null or waiting_days >= 0),
  modality             treatment_modality not null default 'presenza',
  requirements         text,
  expected_outcome     text,
  media                jsonb not null default '[]'::jsonb
                         check (public.m24_valid_media(media)),
  doctor_id            uuid references public.doctors(id) on delete set null,
  facility_id          uuid references public.facilities(id) on delete set null,
  status               treatment_status not null default 'draft',
  version              int not null default 1 check (version > 0),
  is_demo              boolean not null default false,
  featured             boolean not null default false,
  created_by           uuid references auth.users(id) on delete set null,
  published_at         timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  search_vector        tsvector generated always as (
                         public.m24_treatment_search_doc(
                           title, summary, category, conditions, tags, description_sections)
                       ) stored,
  constraint treatments_price_range check (
    price_from_cents is null or price_to_cents is null or price_from_cents <= price_to_cents)
);

comment on table public.treatments is
  'Schede cura del modulo M8. Lettura pubblica solo con status = published; '
  'nessuna scrittura diretta: la redazione passa dalle funzioni di P07-A2/A3.';
comment on column public.treatments.search_vector is
  'tsvector generato con configurazione italian su titolo, sommario, categoria, '
  'patologie, tag e testo delle cinque sezioni.';

create index if not exists idx_treatments_search on public.treatments using gin (search_vector);
create index if not exists idx_treatments_status_scope on public.treatments (status, scope);
create index if not exists idx_treatments_status_family on public.treatments (status, family);
create index if not exists idx_treatments_facility on public.treatments (facility_id);
create index if not exists idx_treatments_doctor on public.treatments (doctor_id);
create index if not exists idx_treatments_title_trgm on public.treatments using gin (title gin_trgm_ops);

drop trigger if exists trg_treatments_updated_at on public.treatments;
create trigger trg_treatments_updated_at before update on public.treatments
  for each row execute function public.set_updated_at();

-- Ogni tag di una cura deve esistere nel vocabolario: il controllo e' in
-- database, non nel client. security definer: treatment_tags resta leggibile
-- anche se il chiamante non ha la policy.
create or replace function public.m24_treatments_check_tags()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_missing text;
begin
  if new.tags is null or array_length(new.tags, 1) is null then
    return new;
  end if;
  select u.tag into v_missing
    from unnest(new.tags) as u(tag)
   where not exists (select 1 from public.treatment_tags g where g.tag = u.tag)
   limit 1;
  if v_missing is not null then
    raise exception 'unknown_treatment_tag: %', v_missing using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_treatments_check_tags on public.treatments;
create trigger trg_treatments_check_tags
  before insert or update of tags on public.treatments
  for each row execute function public.m24_treatments_check_tags();

-- ---------------------------------------------------------------------------
-- 7. reviews
-- ---------------------------------------------------------------------------
create table if not exists public.reviews (
  id              uuid primary key default gen_random_uuid(),
  author_id       uuid not null references auth.users(id) on delete cascade,
  target_type     review_target_type not null,
  target_id       uuid not null,
  rating          smallint not null check (rating between 1 and 5),
  sub_ratings     jsonb not null default '{}'::jsonb
                    check (jsonb_typeof(sub_ratings) = 'object'),
  title           text check (title is null or char_length(title) <= 80),
  body            text not null check (char_length(body) between 20 and 2000),
  status          review_status not null default 'pending',
  moderation_note text,
  moderated_by    uuid references auth.users(id) on delete set null,
  moderated_at    timestamptz,
  verified        boolean not null default false,
  helpful_count   int not null default 0 check (helpful_count >= 0),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (author_id, target_type, target_id)
);

comment on table public.reviews is
  'Recensioni moderate su cure, medici e strutture. Pubbliche solo se '
  'approved; l''autore vede sempre le proprie; nessuna scrittura diretta.';

create index if not exists idx_reviews_target on public.reviews (target_type, target_id, status);
create index if not exists idx_reviews_author on public.reviews (author_id, created_at desc);
create index if not exists idx_reviews_status_created on public.reviews (status, created_at desc);

drop trigger if exists trg_reviews_updated_at on public.reviews;
create trigger trg_reviews_updated_at before update on public.reviews
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 8. favorites — unica tabella del modulo con scrittura diretta
-- ---------------------------------------------------------------------------
create table if not exists public.favorites (
  user_id     uuid not null references auth.users(id) on delete cascade,
  target_type review_target_type not null,
  target_id   uuid not null,
  created_at  timestamptz not null default now(),
  primary key (user_id, target_type, target_id)
);

comment on table public.favorites is
  'Preferiti dell''utente. Select, insert e delete del solo proprietario.';

create index if not exists idx_favorites_target on public.favorites (target_type, target_id);

-- ---------------------------------------------------------------------------
-- 9. rating_summaries — medie e conteggi, mantenute dal trigger su reviews
-- ---------------------------------------------------------------------------
create table if not exists public.rating_summaries (
  target_type  review_target_type not null,
  target_id    uuid not null,
  rating_avg   numeric(3,2) check (rating_avg is null or (rating_avg >= 0 and rating_avg <= 5)),
  rating_count int not null default 0 check (rating_count >= 0),
  sub_avgs     jsonb not null default '{}'::jsonb check (jsonb_typeof(sub_avgs) = 'object'),
  updated_at   timestamptz not null default now(),
  primary key (target_type, target_id)
);

comment on table public.rating_summaries is
  'Medie e conteggi calcolati sulle sole recensioni approved. Lettura '
  'pubblica; scrittura esclusivamente dal trigger su reviews.';

create or replace function public.m24_refresh_rating_summary(
  p_type review_target_type,
  p_id   uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avg   numeric(3,2);
  v_count int;
  v_sub   jsonb;
begin
  if p_id is null then return; end if;

  select round(avg(r.rating)::numeric, 2), count(*)::int
    into v_avg, v_count
    from public.reviews r
   where r.target_type = p_type and r.target_id = p_id and r.status = 'approved';

  with vals as (
    select e.key as k, (e.value #>> '{}')::numeric as v
      from public.reviews r
      cross join lateral jsonb_each(r.sub_ratings) as e
     where r.target_type = p_type and r.target_id = p_id and r.status = 'approved'
       and jsonb_typeof(r.sub_ratings) = 'object'
       and jsonb_typeof(e.value) = 'number'
  ), agg as (
    select k, round(avg(v), 2) as a from vals group by k
  )
  select coalesce(jsonb_object_agg(k, a), '{}'::jsonb) into v_sub from agg;

  insert into public.rating_summaries(target_type, target_id, rating_avg, rating_count, sub_avgs, updated_at)
  values (p_type, p_id, v_avg, coalesce(v_count, 0), coalesce(v_sub, '{}'::jsonb), clock_timestamp())
  on conflict (target_type, target_id) do update
    set rating_avg = excluded.rating_avg,
        rating_count = excluded.rating_count,
        sub_avgs = excluded.sub_avgs,
        updated_at = clock_timestamp();
end;
$$;

create or replace function public.m24_reviews_refresh_summary()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('UPDATE','DELETE') then
    perform public.m24_refresh_rating_summary(old.target_type, old.target_id);
  end if;
  if tg_op in ('INSERT','UPDATE') then
    perform public.m24_refresh_rating_summary(new.target_type, new.target_id);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_reviews_rating_summary on public.reviews;
create trigger trg_reviews_rating_summary
  after insert or update or delete on public.reviews
  for each row execute function public.m24_reviews_refresh_summary();

-- ---------------------------------------------------------------------------
-- 10. RLS — default deny su tutte e sette, RLS forzata
-- ---------------------------------------------------------------------------
alter table public.facilities        enable row level security;
alter table public.doctors           enable row level security;
alter table public.treatment_tags    enable row level security;
alter table public.treatments        enable row level security;
alter table public.reviews           enable row level security;
alter table public.favorites         enable row level security;
alter table public.rating_summaries  enable row level security;

alter table public.facilities        force row level security;
alter table public.doctors           force row level security;
alter table public.treatment_tags    force row level security;
alter table public.treatments        force row level security;
alter table public.reviews           force row level security;
alter table public.favorites         force row level security;
alter table public.rating_summaries  force row level security;

-- facilities: pubbliche se verificate o dimostrative; admin tutto.
drop policy if exists facilities_public_select on public.facilities;
create policy facilities_public_select on public.facilities for select to anon, authenticated
  using (verified or is_demo);
drop policy if exists facilities_admin_select on public.facilities;
create policy facilities_admin_select on public.facilities for select to authenticated
  using (public.has_role('admin'));

-- doctors: stesse regole delle strutture.
drop policy if exists doctors_public_select on public.doctors;
create policy doctors_public_select on public.doctors for select to anon, authenticated
  using (verified or is_demo);
drop policy if exists doctors_admin_select on public.doctors;
create policy doctors_admin_select on public.doctors for select to authenticated
  using (public.has_role('admin'));

-- treatment_tags: vocabolario pubblico.
drop policy if exists treatment_tags_public_select on public.treatment_tags;
create policy treatment_tags_public_select on public.treatment_tags for select to anon, authenticated
  using (true);

-- treatments: pubblica solo la scheda published; admin tutto.
drop policy if exists treatments_public_select on public.treatments;
create policy treatments_public_select on public.treatments for select to anon, authenticated
  using (status = 'published');
drop policy if exists treatments_admin_select on public.treatments;
create policy treatments_admin_select on public.treatments for select to authenticated
  using (public.has_role('admin'));

-- reviews: approved a tutti, le proprie all'autore in ogni stato, admin tutto.
drop policy if exists reviews_public_select on public.reviews;
create policy reviews_public_select on public.reviews for select to anon, authenticated
  using (status = 'approved');
drop policy if exists reviews_author_select on public.reviews;
create policy reviews_author_select on public.reviews for select to authenticated
  using (author_id = auth.uid());
drop policy if exists reviews_admin_select on public.reviews;
create policy reviews_admin_select on public.reviews for select to authenticated
  using (public.has_role('admin'));

-- favorites: il proprietario legge, aggiunge e toglie i propri.
drop policy if exists favorites_owner_select on public.favorites;
create policy favorites_owner_select on public.favorites for select to authenticated
  using (user_id = auth.uid());
drop policy if exists favorites_owner_insert on public.favorites;
create policy favorites_owner_insert on public.favorites for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists favorites_owner_delete on public.favorites;
create policy favorites_owner_delete on public.favorites for delete to authenticated
  using (user_id = auth.uid());

-- rating_summaries: lettura pubblica, scrittura solo dal trigger.
drop policy if exists rating_summaries_public_select on public.rating_summaries;
create policy rating_summaries_public_select on public.rating_summaries for select to anon, authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- 11. Grant — lettura dove serve, scrittura solo sui preferiti
-- ---------------------------------------------------------------------------
revoke all on public.facilities, public.doctors, public.treatment_tags,
  public.treatments, public.reviews, public.favorites, public.rating_summaries
  from anon, authenticated;

grant select on public.facilities, public.doctors, public.treatment_tags,
  public.treatments, public.reviews, public.rating_summaries to anon, authenticated;
grant select, insert, delete on public.favorites to authenticated;

revoke execute on function
  public.m24_refresh_rating_summary(review_target_type, uuid),
  public.m24_treatments_check_tags(),
  public.m24_reviews_refresh_summary()
  from public, anon, authenticated;

grant execute on function
  public.m24_jsonb_keys_subset(jsonb, text[]),
  public.m24_valid_contraindications(jsonb),
  public.m24_valid_media(jsonb),
  public.m24_treatment_search_doc(text, text, text, text[], text[], jsonb)
  to anon, authenticated, service_role;

insert into public.app_migrations(name) values ('0017_treatments_schema') on conflict do nothing;
