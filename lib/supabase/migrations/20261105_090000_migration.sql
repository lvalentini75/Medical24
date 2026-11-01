-- Medical 24 — 0015 AUTO CONFIRM + CATALOGO PERCENTUALI (P09-GOV-A2)
--
-- Regola nuova del board: un valore estratto con confidenza maggiore o uguale
-- alla soglia platform_settings 'extraction.auto_confirm_confidence' nasce
-- confermato dal motore (confirmed_by null); sotto la soglia resta da
-- verificare dall'utente.
--
-- La conferma del motore passa dallo STESSO percorso di confirm_observation:
-- il corpo e' estratto in confirm_observation_internal(p_actor ...), usata sia
-- dall'utente sia dal motore. Nasce quindi una riga nuova che supera la
-- precedente, l'append-only resta rispettato e i trigger di organi
-- (trg_observations_zz_organ_states) e rischi (trg_observations_refresh_risks)
-- scattano come per una conferma dell'utente.
--
-- Idempotente: si puo' rieseguire; il backfill non conferma nulla due volte.

-- ---------------------------------------------------------------------------
-- 1. Corpo comune di confirm_observation, con attore esplicito
--    p_actor null  = conferma del motore (nessun JWT, nessun audit per riga)
--    p_actor <> null = conferma o correzione dell'utente
-- ---------------------------------------------------------------------------
create or replace function public.confirm_observation_internal(
  p_observation_id uuid,
  p_actor          uuid,
  p_value_num      numeric default null,
  p_unit           text default null,
  p_value_text     text default null,
  p_effective_at   timestamptz default null,
  p_outcome        text default 'confirmed'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  o record; n record; r record;
  v_value numeric; v_unit text; v_new_id uuid; v_changed boolean;
begin
  if p_outcome not in ('confirmed', 'discarded') then
    raise exception 'invalid_observation_outcome' using errcode = 'P0001';
  end if;

  select * into o from public.observations where id = p_observation_id;
  if not found then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  -- L'attore umano vede solo i soggetti a cui ha accesso; il motore agisce
  -- gia' dentro una funzione riservata al service_role.
  if p_actor is not null and not public.can_access_subject(o.subject_id) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if o.superseded_at is not null then
    raise exception 'observation_superseded' using errcode = 'P0001';
  end if;

  v_value := coalesce(p_value_num, o.value_raw, o.value_num);
  v_unit  := coalesce(p_unit, o.unit_raw, o.unit);
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
    case when v_changed then 1 else o.confidence end, false, now(), p_actor, o.id,
    coalesce(r.board_version, o.catalog_version), o.rule_version, o.lab_name,
    p_outcome::observation_review_status
  ) returning id into v_new_id;

  -- Il motore scrive una sola riga di audit per estrazione, non per valore.
  if p_actor is not null then
    insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
    values (
      p_actor,
      case when p_outcome = 'discarded' then 'observation.discarded'
           when v_changed then 'observation.corrected'
           else 'observation.confirmed' end,
      'observations', v_new_id, o.subject_id
    );
  end if;

  return v_new_id;
end;
$$;

revoke execute on function public.confirm_observation_internal(uuid,uuid,numeric,text,text,timestamptz,text)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. confirm_observation: stessa firma, stesso comportamento, un solo corpo
-- ---------------------------------------------------------------------------
create or replace function public.confirm_observation(
  p_observation_id uuid,
  p_value_num      numeric default null,
  p_unit           text default null,
  p_value_text     text default null,
  p_effective_at   timestamptz default null,
  p_outcome        text default 'confirmed'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;
  return public.confirm_observation_internal(
    p_observation_id, auth.uid(), p_value_num, p_unit, p_value_text,
    p_effective_at, p_outcome);
end;
$$;

revoke execute on function public.confirm_observation(uuid,numeric,text,text,timestamptz,text) from public, anon;
grant execute on function public.confirm_observation(uuid,numeric,text,text,timestamptz,text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. auto_confirm_extraction: la conferma del motore
--    Stessa guardia di ai_log_call: service_role oppure contesto interno
--    senza JWT (cron, migrazione, trigger). Mai anon o authenticated.
-- ---------------------------------------------------------------------------
create or replace function public.auto_confirm_extraction(p_extraction_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_threshold numeric;
  v_subject   uuid;
  v_ids       uuid[];
  v_id        uuid;
  v_count     int := 0;
begin
  if auth.role() <> 'service_role' and auth.uid() is not null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if p_extraction_id is null then return 0; end if;

  select e.subject_id into v_subject from public.extractions e where e.id = p_extraction_id;
  if not found then return 0; end if;

  begin
    v_threshold := (public.platform_setting('extraction.auto_confirm_confidence') #>> '{}')::numeric;
  exception when others then
    v_threshold := null;
  end;
  v_threshold := coalesce(v_threshold, 0.85);

  -- Fotografia iniziale: le righe nuove create dalla conferma nascono
  -- gia' 'confirmed' e non rientrano mai in questo elenco.
  select coalesce(array_agg(o.id order by o.created_at), '{}')
    into v_ids
  from public.observations o
  where o.extraction_id = p_extraction_id
    and o.superseded_at is null
    and o.review_status = 'pending'
    and o.needs_review = false
    and o.confidence is not null
    and o.confidence >= v_threshold;

  foreach v_id in array v_ids loop
    perform public.confirm_observation_internal(v_id, null, null, null, null, null, 'confirmed');
    v_count := v_count + 1;
  end loop;

  if v_count > 0 then
    insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
    values (null, 'observation.auto_confirmed', 'extractions', p_extraction_id, v_subject);
  end if;

  return v_count;
end;
$$;

revoke execute on function public.auto_confirm_extraction(uuid) from public, anon, authenticated;
grant execute on function public.auto_confirm_extraction(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 4. Backfill: i valori gia' estratti e mai confermati da nessuno
-- ---------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select distinct o.extraction_id as id
    from public.observations o
    where o.extraction_id is not null
      and o.superseded_at is null
      and o.review_status = 'pending'
      and o.needs_review = false
      and o.confidence is not null
  loop
    perform public.auto_confirm_extraction(r.id);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Catalogo: le cinque percentuali della formula leucocitaria
--    Il prompt extract_values contiene gia' la regola sulle percentuali;
--    qui arrivano i codici su cui agganciarle.
-- ---------------------------------------------------------------------------
insert into public.biomarker_catalog (
  code, name_it, name_en, synonyms_it, synonyms_en, category,
  unit_canonical, unit_alternatives,
  ref_low_m, ref_high_m, ref_low_f, ref_high_f, age_note,
  plausible_min, plausible_max, safety_low, safety_high,
  organs, notes, status, board_version
) values
  ('26511-6', 'Neutrofili %', 'Neutrophils %',
   array['Neutrofili (%)','NEU%','granulociti neutrofili %','formula leucocitaria neutrofili'],
   array['Neutrophils (%)','NEU%','segmented neutrophils %'], 'ematologia',
   '%', '{}'::jsonb, 40, 75, 40, 75, null, 0, 100, null, null,
   array['immune'], 'percentuale della formula leucocitaria, non conta assoluta', 'draft', 0),
  ('26478-8', 'Linfociti %', 'Lymphocytes %',
   array['Linfociti (%)','LYM%','formula leucocitaria linfociti'],
   array['Lymphocytes (%)','LYM%'], 'ematologia',
   '%', '{}'::jsonb, 20, 45, 20, 45, null, 0, 100, null, null,
   array['immune'], 'percentuale della formula leucocitaria, non conta assoluta', 'draft', 0),
  ('26485-3', 'Monociti %', 'Monocytes %',
   array['Monociti (%)','MON%','MONO%','formula leucocitaria monociti'],
   array['Monocytes (%)','MON%','MONO%'], 'ematologia',
   '%', '{}'::jsonb, 2, 10, 2, 10, null, 0, 100, null, null,
   array['immune'], 'percentuale della formula leucocitaria, non conta assoluta', 'draft', 0),
  ('26450-7', 'Eosinofili %', 'Eosinophils %',
   array['Eosinofili (%)','EOS%','formula leucocitaria eosinofili'],
   array['Eosinophils (%)','EOS%'], 'ematologia',
   '%', '{}'::jsonb, 1, 6, 1, 6, null, 0, 100, null, null,
   array['immune'], 'percentuale della formula leucocitaria, non conta assoluta', 'draft', 0),
  ('30180-4', 'Basofili %', 'Basophils %',
   array['Basofili (%)','BAS%','BASO%','formula leucocitaria basofili'],
   array['Basophils (%)','BAS%','BASO%'], 'ematologia',
   '%', '{}'::jsonb, 0, 2, 0, 2, null, 0, 100, null, null,
   array['immune'], 'percentuale della formula leucocitaria, non conta assoluta', 'draft', 0)
on conflict (code) do update set
  name_it = excluded.name_it,
  name_en = excluded.name_en,
  synonyms_it = excluded.synonyms_it,
  synonyms_en = excluded.synonyms_en,
  category = excluded.category,
  unit_canonical = excluded.unit_canonical,
  ref_low_m = excluded.ref_low_m, ref_high_m = excluded.ref_high_m,
  ref_low_f = excluded.ref_low_f, ref_high_f = excluded.ref_high_f,
  plausible_min = excluded.plausible_min, plausible_max = excluded.plausible_max,
  organs = excluded.organs, notes = excluded.notes;

select public.rebuild_organ_biomarker_map();

-- ---------------------------------------------------------------------------
-- 6. platform_setting leggibile anche da anon: la schermata di accesso deve
--    poter leggere platform.maintenance_mode prima del login. La funzione
--    nega da sola tutte le impostazioni non pubbliche.
-- ---------------------------------------------------------------------------
grant execute on function public.platform_setting(text) to anon;

insert into public.app_migrations(name) values('0015_auto_confirm_catalog') on conflict do nothing;
