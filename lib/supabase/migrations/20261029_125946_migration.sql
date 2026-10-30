-- Medical 24 - 0007 HEALTH CORE (P03-A) - versione corretta 29/10/2026
-- (values -> items in biomarker_episodes; aggiunta soft_delete_symptom;
--  backfill di review_status con l'interruttore dell'append-only)
-- Manual observations, symptoms, alerts, historical series and snapshots.

create extension if not exists "pgcrypto";

do $$ begin
  if not exists (select 1 from pg_type where typname = 'observation_review_status') then
    create type observation_review_status as enum ('pending', 'confirmed', 'discarded');
  end if;
  if not exists (select 1 from pg_type where typname = 'alert_type') then
    create type alert_type as enum ('info', 'warning', 'critical');
  end if;
  if not exists (select 1 from pg_type where typname = 'alert_level') then
    create type alert_level as enum ('lab', 'institutional', 'doctor');
  end if;
end $$;

alter table public.observations
  add column if not exists review_status observation_review_status not null default 'pending';

-- Riallineamento delle righe esistenti: observations è append-only (trigger
-- observations_append_only della 0005), quindi l'update passa dallo stesso
-- interruttore di sessione usato dal trigger di supersede.
do $$
begin
  perform set_config('medical24.allow_observation_write', 'on', true);
  update public.observations
     set review_status = 'confirmed'::observation_review_status
   where confirmed_at is not null and review_status = 'pending';
  perform set_config('medical24.allow_observation_write', 'off', true);
end $$;

alter table public.biomarker_catalog
  add column if not exists is_essential boolean not null default false;

-- Manual parameters missing from the P02 board seed. They remain draft until
-- board validation, consistently with the existing catalog.
insert into public.biomarker_catalog (
  code, name_it, name_en, synonyms_it, synonyms_en, category,
  unit_canonical, unit_alternatives,
  ref_low_m, ref_high_m, ref_low_f, ref_high_f,
  plausible_min, plausible_max, safety_low, safety_high,
  organs, status, board_version, is_essential
) values
  ('8480-6', 'Pressione sistolica', 'Systolic blood pressure',
   array['pressione massima','PAS'], array['systolic pressure','SBP'], 'parametri',
   'mm[Hg]', '{"mmHg":1}'::jsonb, 90, 129, 90, 129, 40, 300, 60, 220,
   array['heart'], 'draft', 0, true),
  ('8462-4', 'Pressione diastolica', 'Diastolic blood pressure',
   array['pressione minima','PAD'], array['diastolic pressure','DBP'], 'parametri',
   'mm[Hg]', '{"mmHg":1}'::jsonb, 60, 84, 60, 84, 20, 200, 40, 140,
   array['heart'], 'draft', 0, true),
  ('29463-7', 'Peso', 'Body weight',
   array['peso corporeo'], array['weight'], 'parametri',
   'kg', '{"g":0.001,"lb":0.45359237}'::jsonb, null, null, null, null,
   1, 500, null, null, array['metabolism'], 'draft', 0, true),
  ('8867-4', 'Frequenza cardiaca', 'Heart rate',
   array['battito','FC'], array['pulse','HR'], 'parametri',
   '/min', '{"bpm":1}'::jsonb, 60, 100, 60, 100, 20, 300, 30, 220,
   array['heart'], 'draft', 0, true),
  ('8310-5', 'Temperatura corporea', 'Body temperature',
   array['temperatura'], array['temperature'], 'parametri',
   'Cel', '{"°C":1,"C":1}'::jsonb, 36.0, 37.5, 36.0, 37.5, 30, 45, 34, 41,
   array['immune'], 'draft', 0, true),
  ('59408-5', 'Saturazione di ossigeno', 'Oxygen saturation',
   array['saturazione','SpO2'], array['oxygen saturation','SpO2'], 'parametri',
   '%', '{}'::jsonb, 95, 100, 95, 100, 50, 100, 88, null,
   array['lung','heart'], 'draft', 0, true)
on conflict (code) do update set is_essential = true;

update public.biomarker_catalog set is_essential = true where code = '2345-7';

-- A manual write is normalized and completed server-side before its RLS check.
create or replace function public.prepare_manual_observation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  n record;
  r record;
  v_input numeric;
  v_unit text;
begin
  if new.origin <> 'manual' then return new; end if;
  if auth.uid() is null or not public.can_access_subject(new.subject_id) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  -- A discard is produced only by confirm_observation(); it keeps the copied
  -- value for audit but must not be turned back into a confirmed manual row.
  if new.review_status = 'discarded' then return new; end if;
  if new.code not in ('8480-6','8462-4','29463-7','2345-7','8867-4','8310-5','59408-5') then
    raise exception 'manual_code_not_allowed' using errcode = 'P0001';
  end if;

  select * into c from public.biomarker_catalog where code = new.code;
  if not found then raise exception 'catalog_code_not_found' using errcode = 'P0001'; end if;

  v_input := coalesce(new.value_raw, new.value_num);
  v_unit := coalesce(new.unit_raw, new.unit, c.unit_canonical);
  if v_input is null then raise exception 'manual_numeric_value_required' using errcode = 'P0001'; end if;

  select * into n from public.normalize_unit(new.code, v_input, v_unit);
  if n.unit is distinct from c.unit_canonical then
    raise exception 'manual_unit_not_supported' using errcode = 'P0001';
  end if;
  if (c.plausible_min is not null and n.value_num < c.plausible_min)
     or (c.plausible_max is not null and n.value_num > c.plausible_max) then
    raise exception 'manual_value_not_plausible' using errcode = 'P0001';
  end if;

  if new.supersedes_id is not null and not exists (
    select 1 from public.observations o where o.id = new.supersedes_id
      and o.subject_id = new.subject_id and o.superseded_at is null
  ) then
    raise exception 'invalid_supersedes_id' using errcode = 'P0001';
  end if;

  select * into r from public.resolve_reference(new.subject_id, new.code);
  new.display_name := coalesce(nullif(new.display_name, ''), c.name_it);
  new.value_num := n.value_num;
  new.unit := n.unit;
  new.value_raw := v_input;
  new.unit_raw := v_unit;
  new.value_text := null;
  new.ref_low := r.ref_low;
  new.ref_high := r.ref_high;
  new.flag := public.resolve_flag(new.subject_id, new.code, n.value_num);
  new.confidence := 1;
  new.needs_review := false;
  new.confirmed_at := now();
  new.confirmed_by := auth.uid();
  new.review_status := 'confirmed';
  new.catalog_version := coalesce(r.board_version, c.board_version);
  new.rule_version := 'board-' || coalesce(r.board_version, c.board_version, 0)::text;
  new.document_id := null;
  new.extraction_id := null;
  return new;
end;
$$;

drop trigger if exists trg_observations_prepare_manual on public.observations;
create trigger trg_observations_prepare_manual
  before insert on public.observations
  for each row execute function public.prepare_manual_observation();
revoke execute on function public.prepare_manual_observation() from public, anon, authenticated;

-- Every replacement closes the prior row without deleting it.
create or replace function public.supersede_previous_observation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.supersedes_id is not null then
    perform set_config('medical24.allow_observation_write', 'on', true);
    update public.observations set superseded_at = coalesce(superseded_at, now())
    where id = new.supersedes_id and subject_id = new.subject_id;
    perform set_config('medical24.allow_observation_write', 'off', true);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_observations_supersede_previous on public.observations;
create trigger trg_observations_supersede_previous
  after insert on public.observations
  for each row execute function public.supersede_previous_observation();
revoke execute on function public.supersede_previous_observation() from public, anon, authenticated;

drop policy if exists observations_manual_insert on public.observations;
create policy observations_manual_insert on public.observations
  for insert to authenticated
  with check (
    public.can_access_subject(subject_id)
    and origin = 'manual'
    and code in ('8480-6','8462-4','29463-7','2345-7','8867-4','8310-5','59408-5')
    and confidence = 1 and needs_review = false
    and confirmed_at is not null and confirmed_by = auth.uid()
    and review_status = 'confirmed'
    and document_id is null and extraction_id is null
    and exists (
      select 1 from public.biomarker_catalog c
      where c.code = observations.code
        and c.unit_canonical = observations.unit
        and (c.plausible_min is null or observations.value_num >= c.plausible_min)
        and (c.plausible_max is null or observations.value_num <= c.plausible_max)
    )
  );

grant insert on public.observations to authenticated;

-- Confirmation/correction/discard always appends a replacement row.
drop function if exists public.confirm_observation(uuid, numeric, text, text, timestamptz);
create or replace function public.confirm_observation(
  p_observation_id uuid,
  p_value_num numeric default null,
  p_unit text default null,
  p_value_text text default null,
  p_effective_at timestamptz default null,
  p_outcome text default 'confirmed'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  o record; n record; r record; v_value numeric; v_unit text; v_new_id uuid; v_changed boolean;
begin
  if auth.uid() is null then raise exception 'unauthenticated' using errcode = '42501'; end if;
  if p_outcome not in ('confirmed', 'discarded') then
    raise exception 'invalid_observation_outcome' using errcode = 'P0001';
  end if;
  select * into o from public.observations where id = p_observation_id;
  if not found or not public.can_access_subject(o.subject_id) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if o.superseded_at is not null then
    raise exception 'observation_superseded' using errcode = 'P0001';
  end if;

  v_value := coalesce(p_value_num, o.value_raw, o.value_num);
  v_unit := coalesce(p_unit, o.unit_raw, o.unit);
  select * into n from public.normalize_unit(o.code, v_value, v_unit);
  select * into r from public.resolve_reference(o.subject_id, o.code);
  v_changed := p_value_num is not null or p_unit is not null
    or p_value_text is not null or p_effective_at is not null;

  insert into public.observations (
    subject_id, code, display_name, value_num, value_text, unit, value_raw, unit_raw,
    lab_low, lab_high, ref_low, ref_high, flag, effective_at, origin, document_id,
    extraction_id, confidence, needs_review, confirmed_at, confirmed_by,
    supersedes_id, catalog_version, rule_version, lab_name, review_status
  ) values (
    o.subject_id, o.code, o.display_name, n.value_num, coalesce(p_value_text, o.value_text),
    n.unit, v_value, v_unit, o.lab_low, o.lab_high, r.ref_low, r.ref_high,
    public.resolve_flag(o.subject_id, o.code, n.value_num),
    coalesce(p_effective_at, o.effective_at), o.origin, o.document_id, o.extraction_id,
    case when v_changed then 1 else o.confidence end, false, now(), auth.uid(), o.id,
    coalesce(r.board_version, o.catalog_version), o.rule_version, o.lab_name,
    p_outcome::observation_review_status
  ) returning id into v_new_id;

  perform public.log_audit(
    case when p_outcome = 'discarded' then 'observation.discarded'
         when v_changed then 'observation.corrected' else 'observation.confirmed' end,
    'observations', v_new_id, o.subject_id, null
  );
  return v_new_id;
end;
$$;

revoke execute on function public.confirm_observation(uuid,numeric,text,text,timestamptz,text) from public, anon;
grant execute on function public.confirm_observation(uuid,numeric,text,text,timestamptz,text) to authenticated;

-- Symptoms are soft-deleted and editable only by their creator for 24 hours.
create table if not exists public.symptoms (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null,
  code text,
  free_text text,
  severity smallint not null check (severity between 1 and 5),
  notes text,
  storage_path text,
  occurred_at timestamptz not null,
  created_by uuid not null references auth.users(id) on delete restrict default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint symptoms_has_description check (nullif(btrim(coalesce(code,'')), '') is not null
    or nullif(btrim(coalesce(free_text,'')), '') is not null),
  constraint symptoms_storage_subject_path check (storage_path is null
    or storage_path like 'subjects/' || subject_id::text || '/%')
);

create index if not exists idx_symptoms_subject_occurred
  on public.symptoms(subject_id, occurred_at desc) where deleted_at is null;
drop trigger if exists trg_symptoms_updated_at on public.symptoms;
create trigger trg_symptoms_updated_at before update on public.symptoms
  for each row execute function public.set_updated_at();

create or replace function public.protect_symptom_identity()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.subject_id is distinct from old.subject_id
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at then
    raise exception 'symptom_identity_immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_symptoms_protect_identity on public.symptoms;
create trigger trg_symptoms_protect_identity before update on public.symptoms
  for each row execute function public.protect_symptom_identity();
revoke execute on function public.protect_symptom_identity() from public, anon, authenticated;

alter table public.symptoms enable row level security;
alter table public.symptoms force row level security;
drop policy if exists symptoms_select on public.symptoms;
create policy symptoms_select on public.symptoms for select to authenticated
  using (public.can_access_subject(subject_id) and deleted_at is null);
drop policy if exists symptoms_insert on public.symptoms;
create policy symptoms_insert on public.symptoms for insert to authenticated
  with check (public.can_access_subject(subject_id) and created_by = auth.uid());
drop policy if exists symptoms_update_24h on public.symptoms;
create policy symptoms_update_24h on public.symptoms for update to authenticated
  using (public.can_access_subject(subject_id) and created_by = auth.uid()
    and created_at > now() - interval '24 hours')
  with check (public.can_access_subject(subject_id) and created_by = auth.uid()
    and created_at > now() - interval '24 hours');
revoke all on public.symptoms from anon;
grant select, insert, update on public.symptoms to authenticated;

-- Alerts contain only i18n keys, never clinical values.
create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null,
  type alert_type not null,
  source_table text not null,
  source_id uuid not null,
  code text not null,
  level alert_level not null,
  message_key text not null check (message_key ~ '^[A-Za-z][A-Za-z0-9_]*$'),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  unique(source_table, source_id, code, level)
);

create index if not exists idx_alerts_subject_unread
  on public.alerts(subject_id, created_at desc) where read_at is null;
alter table public.alerts enable row level security;
alter table public.alerts force row level security;
drop policy if exists alerts_select on public.alerts;
create policy alerts_select on public.alerts for select to authenticated
  using (public.can_access_subject(subject_id));
drop policy if exists alerts_mark_read on public.alerts;
create policy alerts_mark_read on public.alerts for update to authenticated
  using (public.can_access_subject(subject_id))
  with check (public.can_access_subject(subject_id));
revoke all on public.alerts from anon, authenticated;
grant select on public.alerts to authenticated;
grant update(read_at) on public.alerts to authenticated;

create or replace function public.create_observation_alert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_type alert_type; v_key text;
begin
  if new.confirmed_at is null or new.review_status = 'discarded'
     or new.superseded_at is not null or new.value_num is null
     or new.flag in ('within','unknown') then return new; end if;

  if new.flag = 'critical_low' then v_type := 'critical'; v_key := 'alertBiomarkerCriticalLow';
  elsif new.flag = 'critical_high' then v_type := 'critical'; v_key := 'alertBiomarkerCriticalHigh';
  elsif new.flag = 'below' then v_type := 'warning'; v_key := 'alertBiomarkerBelowInstitutional';
  else v_type := 'warning'; v_key := 'alertBiomarkerAboveInstitutional'; end if;

  -- The same subject/code/value/time creates one alert even if saved twice.
  if exists (
    select 1 from public.alerts a
    join public.observations o on o.id = a.source_id
    where a.source_table = 'observations' and a.subject_id = new.subject_id
      and a.code = new.code and a.level = 'institutional'
      and o.value_num = new.value_num and o.effective_at = new.effective_at
  ) then return new; end if;

  insert into public.alerts(subject_id,type,source_table,source_id,code,level,message_key)
  values(new.subject_id,v_type,'observations',new.id,new.code,'institutional',v_key)
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists trg_observations_alert on public.observations;
create trigger trg_observations_alert after insert on public.observations
  for each row execute function public.create_observation_alert();
revoke execute on function public.create_observation_alert() from public, anon, authenticated;

-- Watch list for favorites, essential defaults and explicit tracking.
create table if not exists public.biomarker_watch (
  subject_id uuid not null,
  code text not null references public.biomarker_catalog(code) on delete restrict,
  favorite boolean not null default false,
  tracked boolean not null default false,
  created_at timestamptz not null default now(),
  primary key(subject_id, code)
);
alter table public.biomarker_watch enable row level security;
alter table public.biomarker_watch force row level security;
drop policy if exists biomarker_watch_select on public.biomarker_watch;
create policy biomarker_watch_select on public.biomarker_watch for select to authenticated
  using (public.can_access_subject(subject_id));
drop policy if exists biomarker_watch_insert on public.biomarker_watch;
create policy biomarker_watch_insert on public.biomarker_watch for insert to authenticated
  with check (public.can_access_subject(subject_id));
drop policy if exists biomarker_watch_update on public.biomarker_watch;
create policy biomarker_watch_update on public.biomarker_watch for update to authenticated
  using (public.can_access_subject(subject_id)) with check (public.can_access_subject(subject_id));
drop policy if exists biomarker_watch_delete on public.biomarker_watch;
create policy biomarker_watch_delete on public.biomarker_watch for delete to authenticated
  using (public.can_access_subject(subject_id));
revoke all on public.biomarker_watch from anon;
grant select, insert, update, delete on public.biomarker_watch to authenticated;

-- Historical series. Doctor thresholds intentionally stay null until P05.
create or replace view public.biomarker_series
with (security_invoker = true)
as
select o.id as observation_id, o.subject_id, o.code, o.effective_at,
  o.value_num as canonical_value, o.unit as canonical_unit,
  o.lab_low, o.lab_high,
  r.ref_low as institutional_low, r.ref_high as institutional_high,
  null::numeric as doctor_low, null::numeric as doctor_high,
  o.flag, o.origin, o.document_id, o.extraction_id, o.lab_name
from public.observations o
left join lateral public.resolve_reference(o.subject_id, o.code) r on true
where o.superseded_at is null and o.review_status <> 'discarded';

grant select on public.biomarker_series to authenticated;
revoke all on public.biomarker_series from anon;

create or replace function public.biomarker_stats(
  p_subject uuid, p_code text, p_from timestamptz default null, p_to timestamptz default null
)
returns table(minimum numeric, maximum numeric, average numeric, latest_value numeric,
  latest_at timestamptz, change_from_previous numeric, value_count bigint)
language sql stable security invoker set search_path = public
as $$
  with s as (
    select canonical_value, effective_at,
      row_number() over(order by effective_at desc, observation_id desc) rn
    from public.biomarker_series
    where subject_id = p_subject and code = p_code and canonical_value is not null
      and (p_from is null or effective_at >= p_from) and (p_to is null or effective_at <= p_to)
  )
  select min(canonical_value), max(canonical_value), avg(canonical_value),
    max(canonical_value) filter(where rn=1), max(effective_at) filter(where rn=1),
    max(canonical_value) filter(where rn=1) - max(canonical_value) filter(where rn=2), count(*)
  from s;
$$;

create or replace function public.biomarker_episodes(p_subject uuid, p_code text)
returns table(episode_start timestamptz, episode_end timestamptz, level text, items jsonb)
language sql stable security invoker set search_path = public
as $$
  with ordered as (
    select *, flag not in ('within','unknown') as is_out,
      lag(flag not in ('within','unknown'), 1, false) over(order by effective_at, observation_id) as was_out
    from public.biomarker_series where subject_id = p_subject and code = p_code
  ), marked as (
    select *, sum(case when is_out and not was_out then 1 else 0 end)
      over(order by effective_at, observation_id) as grp
    from ordered
  ), grouped as (
    select grp, min(effective_at) episode_start, max(effective_at) last_out,
      bool_or(flag in ('critical_low','critical_high')) critical,
      jsonb_agg(jsonb_build_object('id',observation_id,'at',effective_at,
        'value',canonical_value,'unit',canonical_unit,'flag',flag) order by effective_at) items
    from marked where is_out group by grp
  )
  select g.episode_start,
    case when exists(select 1 from ordered o where o.effective_at > g.last_out and not o.is_out)
         then g.last_out else null end,
    'institutional'::text, g.items
  from grouped g order by g.episode_start;
$$;

create or replace function public.biomarker_catalog_for_subject(p_subject uuid)
returns table(code text, name_it text, name_en text, unit_canonical text,
  latest_value numeric, latest_at timestamptz, flag observation_flag,
  value_count bigint, essential boolean, favorite boolean, tracked boolean)
language sql stable security invoker set search_path = public
as $$
  select c.code,c.name_it,c.name_en,c.unit_canonical,l.canonical_value,l.effective_at,l.flag,
    coalesce(n.value_count,0),c.is_essential,coalesce(w.favorite,false),coalesce(w.tracked,false)
  from public.biomarker_catalog c
  left join lateral (select s.canonical_value,s.effective_at,s.flag from public.biomarker_series s
    where s.subject_id=p_subject and s.code=c.code order by s.effective_at desc limit 1) l on true
  left join lateral (select count(*) value_count from public.biomarker_series s
    where s.subject_id=p_subject and s.code=c.code) n on true
  left join public.biomarker_watch w on w.subject_id=p_subject and w.code=c.code
  order by c.name_it;
$$;

create or replace function public.observations_export(p_subject uuid)
returns table(code text, effective_at timestamptz, value numeric, unit text,
  lab_low numeric, lab_high numeric, institutional_low numeric,
  institutional_high numeric, doctor_low numeric, doctor_high numeric,
  flag observation_flag, origin observation_origin, document_id uuid, lab_name text)
language sql stable security invoker set search_path = public
as $$
  select s.code,s.effective_at,s.canonical_value,s.canonical_unit,s.lab_low,s.lab_high,
    s.institutional_low,s.institutional_high,s.doctor_low,s.doctor_high,s.flag,s.origin,
    s.document_id,s.lab_name
  from public.biomarker_series s where s.subject_id=p_subject order by s.effective_at,s.code;
$$;

create index if not exists idx_observations_subject_time
  on public.observations(subject_id, effective_at desc);

create or replace function public.home_snapshot(p_subject uuid)
returns jsonb
language sql stable security invoker set search_path = public
as $$
  select jsonb_build_object(
    'values', coalesce((select jsonb_agg(to_jsonb(v) order by v.effective_at desc) from (
      select * from (select distinct on (code) code,canonical_value as value,
        canonical_unit as unit,effective_at,flag
        from public.biomarker_series where subject_id=p_subject
        order by code,effective_at desc) latest
      order by effective_at desc limit 6) v), '[]'::jsonb),
    'unread_alerts', coalesce((select jsonb_agg(to_jsonb(a) order by a.created_at desc)
      from (select id,type,code,level,message_key,created_at from public.alerts
            where subject_id=p_subject and read_at is null order by created_at desc limit 20) a), '[]'::jsonb),
    'documents_to_review', coalesce((select jsonb_agg(to_jsonb(d)) from (
      select id,title,document_date,status from public.documents
      where subject_id=p_subject and status='needs_review' and deleted_at is null
      order by created_at desc limit 10) d), '[]'::jsonb),
    'latest_document', (select to_jsonb(d) from (select id,title,document_date,status,created_at
      from public.documents where subject_id=p_subject and deleted_at is null
      order by coalesce(document_date,created_at::date) desc,created_at desc limit 1) d),
    'counts', jsonb_build_object(
      'observations',(select count(*) from public.biomarker_series where subject_id=p_subject),
      'unread_alerts',(select count(*) from public.alerts where subject_id=p_subject and read_at is null),
      'documents',(select count(*) from public.documents where subject_id=p_subject and deleted_at is null),
      'symptoms',(select count(*) from public.symptoms where subject_id=p_subject and deleted_at is null)
    )
  );
$$;

grant execute on function public.biomarker_stats(uuid,text,timestamptz,timestamptz) to authenticated;
grant execute on function public.biomarker_episodes(uuid,text) to authenticated;
grant execute on function public.biomarker_catalog_for_subject(uuid) to authenticated;
grant execute on function public.observations_export(uuid) to authenticated;
grant execute on function public.home_snapshot(uuid) to authenticated;
revoke execute on function public.biomarker_stats(uuid,text,timestamptz,timestamptz) from public, anon;
revoke execute on function public.biomarker_episodes(uuid,text) from public, anon;
revoke execute on function public.biomarker_catalog_for_subject(uuid) from public, anon;
revoke execute on function public.observations_export(uuid) from public, anon;
revoke execute on function public.home_snapshot(uuid) from public, anon;

-- Soft delete dei sintomi in qualunque momento, con controllo del soggetto
-- (la policy di update vale 24 ore, la cancellazione deve valere sempre).
create or replace function public.soft_delete_symptom(p_symptom_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_subject uuid;
begin
  select subject_id into v_subject from public.symptoms
   where id = p_symptom_id and deleted_at is null;
  if v_subject is null or not public.can_access_subject(v_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  update public.symptoms set deleted_at = now()
   where id = p_symptom_id and deleted_at is null;
end;
$$;
revoke execute on function public.soft_delete_symptom(uuid) from public, anon;
grant execute on function public.soft_delete_symptom(uuid) to authenticated;

insert into public.app_migrations(name) values ('0007_health_core') on conflict do nothing;