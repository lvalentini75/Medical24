-- ============================================================================
-- Medical 24 — 0022 DOCTOR V1 DOSSIER (P08-A2a-1 + P08-A2a-2) — modulo M9
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- Funzioni applicative del dossier, sopra lo schema della 0021 che non viene
-- toccata. Nessuna tabella nuova, nessuna Edge Function, nessuna schermata,
-- nessun seed.
--
--   dossier_build(p_subject uuid,
--                 p_scope jsonb default '{"all": true}'::jsonb,
--                 p_share_link_id uuid default null) returns uuid
--   dossier_latest(p_subject uuid) returns jsonb
--   dossier_snapshot_set_pdf(p_snapshot uuid, p_path text) returns void
--
-- Regole trasversali:
--   security definer con set search_path = public, extensions;
--   execute revocato a public e anon, concesso solo ad authenticated e
--   service_role;
--   errori con errcode: 22023 input non valido, 42501 not_allowed;
--   nessun testo IA (explanations), nessun storage_path e nessun testo dei
--   documenti nel payload; in audit_log solo attore, azione, id e soggetto.
--
-- Idempotente: puo' essere rieseguita senza effetti collaterali.
-- ============================================================================

create or replace function public.dossier_build(
  p_subject       uuid,
  p_scope         jsonb default '{"all": true}'::jsonb,
  p_share_link_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid        uuid := auth.uid();
  v_service    boolean := coalesce(auth.role(), '') = 'service_role';
  v_scope      jsonb := p_scope;
  v_organs     text[];
  v_categories text[];
  v_from       date;
  v_to         date;
  v_lang       text;
  v_subject    jsonb;
  v_health     jsonb;
  v_organs_js  jsonb;
  v_risks      jsonb;
  v_values     jsonb;
  v_exams      jsonb;
  v_documents  jsonb;
  v_counts     jsonb;
  v_rules      jsonb;
  v_payload    jsonb;
  v_total      int;
  v_ok         int;
  v_monitor    int;
  v_attention  int;
  v_missing    int;
  v_level      text;
  v_obs_count  int;
  v_doc_count  int;
  v_id         uuid;
begin
  -- 1. Chi puo' costruire il dossier ----------------------------------------
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if not v_service and (v_uid is null or not public.can_access_subject(p_subject)) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  -- 2. Validazione dello scope e del link ------------------------------------
  if v_scope is null or coalesce(public.m24_valid_share_scope(v_scope), false) = false then
    raise exception 'invalid_scope' using errcode = '22023';
  end if;

  if p_share_link_id is not null
     and not exists (select 1 from public.share_links l
                      where l.id = p_share_link_id and l.subject_id = p_subject) then
    raise exception 'invalid_share_link' using errcode = '22023';
  end if;

  if not (v_scope ? 'all') then
    if v_scope ? 'organs' then
      v_organs := array(select jsonb_array_elements_text(v_scope->'organs'));
    end if;
    if v_scope ? 'categories' then
      v_categories := array(select jsonb_array_elements_text(v_scope->'categories'));
    end if;
    v_from := nullif(v_scope->>'from', '')::date;
    v_to   := nullif(v_scope->>'to', '')::date;
  end if;

  -- 3. Soggetto: solo i tre campi dichiarati, nient'altro ---------------------
  select p.language,
         jsonb_build_object('full_name', p.full_name,
                            'birth_date', p.birth_date,
                            'gender', p.gender)
    into v_lang, v_subject
  from public.profiles p
  where p.id = p_subject;

  v_lang := coalesce(v_lang, 'it');
  v_subject := coalesce(v_subject,
    jsonb_build_object('full_name', null, 'birth_date', null, 'gender', null));

  -- 4. Stato di salute --------------------------------------------------------
  select count(*)::int,
         count(*) filter (where s.state = 'ok')::int,
         count(*) filter (where s.state = 'monitor')::int,
         count(*) filter (where s.state = 'attention')::int,
         count(*) filter (where s.state = 'missing')::int
    into v_total, v_ok, v_monitor, v_attention, v_missing
  from public.latest_organ_states s
  where s.subject_id = p_subject;

  v_level := case
    when coalesce(v_attention, 0) > 0 then 'attention'
    when coalesce(v_monitor, 0) > 0 then 'monitor'
    when coalesce(v_total, 0) = 0 or coalesce(v_ok, 0) = 0 then 'missing'
    else 'ok'
  end;

  v_health := jsonb_build_object(
    'level', v_level,
    'organs_ok', coalesce(v_ok, 0),
    'organs_monitor', coalesce(v_monitor, 0),
    'organs_attention', coalesce(v_attention, 0),
    'organs_missing', coalesce(v_missing, 0));

  -- 5. Organi da seguire ------------------------------------------------------
  select coalesce(jsonb_agg(jsonb_build_object(
           'organ_id', s.organ_id,
           'state', s.state,
           'computed_at', to_char(s.computed_at at time zone 'UTC',
                                  'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'rule_version', s.rule_version)
           -- prima gli organi in attenzione, poi quelli da monitorare,
           -- a parita' di stato in ordine di organ_id.
           order by case s.state::text when 'attention' then 0 else 1 end,
                    s.organ_id), '[]'::jsonb)
    into v_organs_js
  from public.latest_organ_states s
  where s.subject_id = p_subject
    and s.state in ('monitor', 'attention')
    and (v_organs is null or s.organ_id = any(v_organs));

  -- 6. Rischi -----------------------------------------------------------------
  select coalesce(jsonb_agg(jsonb_build_object(
           'family', r.family,
           'level', r.level,
           'score', r.score,
           'computed_at', to_char(r.computed_at at time zone 'UTC',
                                  'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'rule_version', r.rule_version) order by r.family), '[]'::jsonb)
    into v_risks
  from public.latest_risk_scores r
  where r.subject_id = p_subject;

  -- 7. Ultimi valori fuori intervallo, con tendenza ---------------------------
  --    Tendenza rispetto al valore confermato precedente dello stesso codice:
  --    stabile entro il 5%, nulla se non c'e' un precedente.
  with conf as (
    select o.id, o.code, o.value_num, o.unit, o.ref_low, o.ref_high, o.flag,
           o.effective_at, o.document_id, o.display_name
    from public.observations o
    where o.subject_id = p_subject
      and o.review_status = 'confirmed'
      and o.superseded_at is null
      and o.value_num is not null
  ), last_per_code as (
    select distinct on (c.code) c.*
    from conf c
    order by c.code, c.effective_at desc, c.id desc
  ), picked as (
    select l.*
    from last_per_code l
    where l.flag in ('below', 'above', 'critical_low', 'critical_high')
      and (v_organs is null or exists (
            select 1 from public.organ_biomarker_map m
             where m.code = l.code and m.organ_id = any(v_organs)))
      and (v_from is null or l.effective_at >= v_from::timestamptz)
      and (v_to is null or l.effective_at < (v_to + 1)::timestamptz)
    order by l.effective_at desc, l.id desc
    limit 40
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', x.code,
           'name', coalesce(
             case when v_lang = 'en' then c.name_en else c.name_it end,
             nullif(btrim(x.display_name), ''), x.code),
           'value', x.value_num,
           'unit', x.unit,
           'ref_low', x.ref_low,
           'ref_high', x.ref_high,
           'flag', x.flag,
           'effective_at', to_char(x.effective_at at time zone 'UTC',
                                   'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'document_id', x.document_id,
           'trend', case
             when pv.value_num is null then null
             when pv.value_num = 0 then
               case when x.value_num = 0 then 'stable'
                    when x.value_num > 0 then 'up' else 'down' end
             when abs(x.value_num - pv.value_num) <= 0.05 * abs(pv.value_num) then 'stable'
             when x.value_num > pv.value_num then 'up'
             else 'down' end,
           'previous_value', pv.value_num,
           'previous_at', case when pv.effective_at is null then null
             else to_char(pv.effective_at at time zone 'UTC',
                          'YYYY-MM-DD"T"HH24:MI:SS"Z"') end)
           order by x.effective_at desc), '[]'::jsonb)
    into v_values
  from picked x
  left join public.biomarker_catalog c on c.code = x.code
  left join lateral (
    select o.value_num, o.effective_at
    from public.observations o
    where o.subject_id = p_subject
      and o.code = x.code
      and o.review_status = 'confirmed'
      and o.superseded_at is null
      and o.value_num is not null
      and (o.effective_at, o.id) < (x.effective_at, x.id)
    order by o.effective_at desc, o.id desc
    limit 1
  ) pv on true;

  -- 8. Esami consigliati ------------------------------------------------------
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id,
           'kind', x.kind,
           'title', x.title,
           'reason', x.reason,
           'due_at', x.due_at,
           'origin', x.origin) order by x.due_at nulls last, x.id), '[]'::jsonb)
    into v_exams
  from (
    select r.id, r.category as kind, r.due_at, r.origin,
           coalesce(cal.name_it, r.title_key) as title,
           r.reason_key as reason
    from public.recommendations r
    left join public.prevention_calendar cal on cal.id = r.calendar_id
    where r.subject_id = p_subject and r.status = 'open'
    order by r.due_at nulls last, r.id
    limit 20
  ) x;

  -- 9. Documenti nello scope: mai storage_path, mai testo ---------------------
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id,
           'title', x.title,
           'category', x.category,
           'document_date', x.document_date)
           order by x.document_date desc nulls last, x.id), '[]'::jsonb)
    into v_documents
  from (
    select d.id, d.title, d.category, d.document_date
    from public.documents d
    where d.subject_id = p_subject
      and d.deleted_at is null
      and (v_categories is null or d.category::text = any(v_categories))
      and (v_from is null or (d.document_date is not null and d.document_date >= v_from))
      and (v_to is null or (d.document_date is not null and d.document_date <= v_to))
    order by d.document_date desc nulls last, d.id
    limit 100
  ) x;

  -- 10. Conteggi: gli stessi filtri dello scope -------------------------------
  select count(*)::int into v_obs_count
  from public.observations o
  where o.subject_id = p_subject
    and o.review_status = 'confirmed'
    and o.superseded_at is null
    and (v_organs is null or exists (
          select 1 from public.organ_biomarker_map m
           where m.code = o.code and m.organ_id = any(v_organs)))
    and (v_from is null or o.effective_at >= v_from::timestamptz)
    and (v_to is null or o.effective_at < (v_to + 1)::timestamptz);

  select count(*)::int into v_doc_count
  from public.documents d
  where d.subject_id = p_subject
    and d.deleted_at is null
    and (v_categories is null or d.category::text = any(v_categories))
    and (v_from is null or (d.document_date is not null and d.document_date >= v_from))
    and (v_to is null or (d.document_date is not null and d.document_date <= v_to));

  v_counts := jsonb_build_object(
    'observations_confirmed', coalesce(v_obs_count, 0),
    'documents_total', coalesce(v_doc_count, 0));

  -- 11. Versioni distinte delle regole usate ----------------------------------
  v_rules := jsonb_build_object(
    'organ_rules', coalesce((
      select jsonb_agg(distinct s.rule_version)
      from public.latest_organ_states s
      where s.subject_id = p_subject and s.rule_version is not null), '[]'::jsonb),
    'risk_rules', coalesce((
      select jsonb_agg(distinct r.rule_version)
      from public.latest_risk_scores r
      where r.subject_id = p_subject and r.rule_version is not null), '[]'::jsonb));

  -- 12. Payload congelato, versione 1 -----------------------------------------
  v_payload := jsonb_build_object(
    'version', 1,
    'subject', v_subject,
    'scope', v_scope,
    'health_status', v_health,
    'organs', v_organs_js,
    'risks', v_risks,
    'out_of_range', v_values,
    'recommended_exams', v_exams,
    'documents', v_documents,
    'counts', v_counts,
    'disclaimer_key', 'dossier.disclaimer');

  -- clock_timestamp(): due dossier costruiti nella stessa transazione restano
  -- ordinabili, come per organ_states e risk_scores.
  insert into public.dossier_snapshots(subject_id, share_link_id, payload,
                                       rule_versions, generated_at)
  values (p_subject, p_share_link_id, v_payload, v_rules, clock_timestamp())
  returning id into v_id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'dossier.built', 'dossier_snapshots', v_id, p_subject);

  return v_id;
end;
$$;

revoke execute on function public.dossier_build(uuid, jsonb, uuid) from public, anon;
grant execute on function public.dossier_build(uuid, jsonb, uuid) to authenticated, service_role;

comment on function public.dossier_build(uuid, jsonb, uuid) is
  'Costruisce il dossier del soggetto nello scope indicato e ne congela una '
  'riga in dossier_snapshots, restituendone l''id. Richiede '
  'can_access_subject(p_subject) oppure service_role. Nessun testo IA, '
  'nessun storage_path, nessun dato clinico in audit_log.';

-- ============================================================================
-- 2. dossier_latest — l'ultimo dossier personale del soggetto
--    Personale significa senza share_link_id: i dossier congelati per un link
--    di condivisione appartengono a quel link, non alla schermata del paziente.
-- ============================================================================
create or replace function public.dossier_latest(p_subject uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_uid     uuid := auth.uid();
  v_service boolean := coalesce(auth.role(), '') = 'service_role';
  v_row     jsonb;
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if not v_service and (v_uid is null or not public.can_access_subject(p_subject)) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select jsonb_build_object(
           'id', s.id,
           'generated_at', to_char(s.generated_at at time zone 'UTC',
                                   'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'payload', s.payload,
           'pdf_path', s.pdf_path)
    into v_row
  from public.dossier_snapshots s
  where s.subject_id = p_subject
    and s.share_link_id is null
  order by s.generated_at desc, s.id desc
  limit 1;

  return v_row;
end;
$$;

revoke execute on function public.dossier_latest(uuid) from public, anon;
grant execute on function public.dossier_latest(uuid) to authenticated, service_role;

comment on function public.dossier_latest(uuid) is
  'Ultimo dossier personale del soggetto (senza share_link_id): id, '
  'generated_at, payload e pdf_path; null se non ce n''e'' nessuno. Richiede '
  'can_access_subject(p_subject) oppure service_role.';

-- ============================================================================
-- 3. dossier_snapshot_set_pdf — il percorso del PDF, scritto una volta sola
--    La scrive soltanto la Edge Function dossier-pdf, che agisce da
--    service_role: execute e' concesso esclusivamente a service_role, quindi
--    una chiamata da authenticated fallisce con 42501 prima di entrare nel
--    corpo. Il percorso e' vincolato allo schema dello storage; il trigger
--    della 0021 impedisce qualunque seconda scrittura.
-- ============================================================================
create or replace function public.dossier_snapshot_set_pdf(
  p_snapshot uuid,
  p_path     text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_subject  uuid;
  v_expected text;
begin
  if p_snapshot is null or nullif(btrim(coalesce(p_path, '')), '') is null then
    raise exception 'invalid_pdf_path' using errcode = '22023';
  end if;

  select s.subject_id into v_subject
  from public.dossier_snapshots s
  where s.id = p_snapshot;

  if v_subject is null then
    raise exception 'snapshot_not_found' using errcode = '22023';
  end if;

  v_expected := 'subjects/' || v_subject::text || '/dossier/' || p_snapshot::text || '.pdf';
  if p_path <> v_expected then
    raise exception 'invalid_pdf_path' using errcode = '22023';
  end if;

  update public.dossier_snapshots
     set pdf_path = p_path
   where id = p_snapshot;
end;
$$;

revoke execute on function public.dossier_snapshot_set_pdf(uuid, text) from public, anon, authenticated;
grant execute on function public.dossier_snapshot_set_pdf(uuid, text) to service_role;

comment on function public.dossier_snapshot_set_pdf(uuid, text) is
  'Scrive pdf_path dello snapshot una sola volta. Percorso atteso '
  'subjects/{subject_id}/dossier/{snapshot_id}.pdf, altrimenti 22023; la '
  'seconda scrittura e'' bloccata dal trigger della 0021 con 42501. Eseguibile '
  'soltanto dal service_role.';

insert into public.app_migrations(name) values ('0022_doctor_v1_dossier') on conflict do nothing;
