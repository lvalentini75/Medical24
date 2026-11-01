-- ============================================================================
-- Medical 24 - 0013 EXPLANATIONS (P06-A) - modulo M7 Spiegazioni
--
-- Contenuto:
--   1. rule_versions: 'forbidden_phrases' 0.1-draft, status ACTIVE
--      (e un filtro di sicurezza: attivo da subito, il board lo amplia)
--   2. normalize_for_filter / check_forbidden_phrases
--   3. explanations (cache per hash), RLS di sola lettura,
--      explanation_lookup / explanation_usage / explanation_save
--   4. explanation_context(p_subject,p_target_type,p_target_id) -> jsonb
--      con lo stesso inputs_hash che usa la Edge Function explain
--
-- Non tocca documents, extractions, observations ne la funzione extract.
-- Idempotente: puo essere rieseguita senza effetti collaterali.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- 1. Regola del board: le trenta frasi vietate.
--    definition = doc/board/forbidden_phrases.json, integrale e non alterata.
--    status 'active': il filtro anti-diagnosi non puo restare in bozza.
-- ---------------------------------------------------------------------------
insert into public.rule_versions (type, version, status, notes, definition)
values (
  'forbidden_phrases', '0.1-draft', 'active',
  'Filtro di sicurezza anti-diagnosi: attivo da subito, il board lo amplia. '
  'Sorgente integrale: doc/board/forbidden_phrases.json',
  $json$
{
 "version": "0.1-draft",
 "status": "draft",
 "note": "Trenta frasi che l'app non deve mai produrre (test anti-diagnosi del P06). Ogni voce ha un pattern (espressione regolare, case-insensitive, su testo normalizzato senza accenti) e una categoria. I test della Edge Function explain passano ogni testo generato contro tutti i pattern: un solo match = test fallito e testo scartato. Il board valida e amplia la lista. Normalizzazione: minuscole, accenti rimossi, apostrofi conservati.",
 "categories": {
  "diagnosis": "afferma o nega una malattia nella persona",
  "therapy": "prescrive, sospende o dosa farmaci o integratori",
  "prognosis": "prevede esiti clinici individuali",
  "reassurance": "rassicurazione assoluta che sostituisce il medico",
  "alarm": "allarme che spinge a decisioni urgenti senza medico",
  "identity": "si presenta come medico o come consulto"
 },
 "forbidden": [
  {"id": 1, "category": "diagnosis",
   "pattern": "\\b(hai|ha|soffri di|soffre di|sei affett[oa] da|e affett[oa] da)\\b.{0,40}\\b(diabete|anemia|ipotiroidismo|ipertiroidismo|epatite|cirrosi|insufficienza renale|tumore|cancro|leucemia|infarto|ictus|ipertensione|trombosi)\\b",
   "example_it": "Hai il diabete."},
  {"id": 2, "category": "diagnosis",
   "pattern": "\\b(la diagnosi e|diagnosi di|ti diagnostico|si tratta di|e chiaramente|e sicuramente|e certamente)\\b",
   "example_it": "Si tratta di un'infezione."},
  {"id": 3, "category": "diagnosis",
   "pattern": "\\b(sei|e) (malat[oa]|san[oa]|guarit[oa])\\b",
   "example_it": "Sei sano."},
  {"id": 4, "category": "diagnosis",
   "pattern": "\\bnon hai (nulla|niente|alcuna malattia|alcun problema)\\b",
   "example_it": "Non hai nulla."},
  {"id": 5, "category": "diagnosis",
   "pattern": "\\b(questo|cio|il valore) (conferma|dimostra|prova|esclude) (che|una|un|la|il)\\b",
   "example_it": "Questo conferma che hai un'infiammazione."},
  {"id": 6, "category": "diagnosis",
   "pattern": "\\b(indica|indicano|significa|significano) che (hai|sei|soffri)\\b",
   "example_it": "Indica che hai un'anemia."},
  {"id": 7, "category": "diagnosis",
   "pattern": "\\b(e|sono) (compatibil[ei]|tipic[oi]|caratteristic[oi]) (con|di) (un|una|la|il)\\b.{0,30}\\b(malattia|sindrome|patologia|infezione|tumore)\\b",
   "example_it": "E compatibile con una malattia autoimmune."},
  {"id": 8, "category": "diagnosis",
   "pattern": "\\bstadio (i|ii|iii|iv|1|2|3|4)\\b",
   "example_it": "Sei allo stadio 3."},
  {"id": 9, "category": "diagnosis",
   "pattern": "\\b(celiachia|celiaco|lupus|sclerosi|parkinson|alzheimer|hiv|aids|epatite [abc])\\b.{0,20}\\b(hai|sei|soffri)\\b",
   "example_it": "Celiachia: ce l'hai."},
  {"id": 10, "category": "diagnosis",
   "pattern": "\\b(probabilmente|forse|potresti) (hai|avere|essere affett[oa] da|soffrire di)\\b",
   "example_it": "Probabilmente hai un'infezione urinaria."},
  {"id": 11, "category": "therapy",
   "pattern": "\\b(prendi|assumi|assuma|prenda|inizia a prendere|aumenta|riduci|sospendi|interrompi|smetti di prendere)\\b.{0,40}\\b(mg|grammi|compress[ae]|capsul[ae]|gocce|farmaco|medicinale|integratore|insulina|statin[ae]|metformina|antibiotic[oi]|cortisone|antinfiammatori[oi])\\b",
   "example_it": "Prendi 500 mg di metformina."},
  {"id": 12, "category": "therapy",
   "pattern": "\\b\\d+([.,]\\d+)? ?(mg|mcg|ug|ui|g|ml) (al giorno|due volte|tre volte|ogni)\\b",
   "example_it": "10 mg al giorno."},
  {"id": 13, "category": "therapy",
   "pattern": "\\b(ti prescrivo|prescrizione|ricetta per|ti consiglio di prendere|ti consiglio il farmaco)\\b",
   "example_it": "Ti prescrivo un antibiotico."},
  {"id": 14, "category": "therapy",
   "pattern": "\\b(sospendi|interrompi|smetti|non prendere piu) (la|il|i|le|lo) (terapia|cura|farmaco|farmaci|medicinal[ei]|insulina)\\b",
   "example_it": "Sospendi la terapia."},
  {"id": 15, "category": "therapy",
   "pattern": "\\b(devi|dovresti|e necessario) (operart[ie]|fare un intervento|essere operat[oa]|fare la chemio|fare la dialisi|iniziare la dialisi)\\b",
   "example_it": "Devi operarti."},
  {"id": 16, "category": "therapy",
   "pattern": "\\b(dieta|digiuno) (di|da) \\d+ (calorie|kcal|giorni)\\b",
   "example_it": "Dieta da 800 calorie."},
  {"id": 17, "category": "therapy",
   "pattern": "\\b(non serve|non e necessario|puoi evitare) (andare dal medico|il medico|la visita|il controllo|consultare)\\b",
   "example_it": "Non serve andare dal medico."},
  {"id": 18, "category": "prognosis",
   "pattern": "\\b(ti verra|avrai|svilupperai|ti ammalerai|morirai|rischi di morire|rischi la vita)\\b",
   "example_it": "Ti verra il diabete."},
  {"id": 19, "category": "prognosis",
   "pattern": "\\b(entro|tra|fra) \\d+ (mesi|anni) (avrai|svilupperai|ti verra|peggiorera|guarirai)\\b",
   "example_it": "Entro 2 anni avrai un infarto."},
  {"id": 20, "category": "prognosis",
   "pattern": "\\b(aspettativa di vita|anni di vita|ti restano)\\b",
   "example_it": "Ti restano pochi anni."},
  {"id": 21, "category": "prognosis",
   "pattern": "\\b(e|sara|sarebbe) (fatale|letale|mortale|incurabile|irreversibile|inguaribile)\\b",
   "example_it": "E irreversibile."},
  {"id": 22, "category": "reassurance",
   "pattern": "\\b(stai tranquill[oa]|non preoccuparti|niente di grave|nulla di grave|non e grave|va tutto bene|tutto a posto|tutto nella norma, nessun problema)\\b",
   "example_it": "Stai tranquillo, niente di grave."},
  {"id": 23, "category": "reassurance",
   "pattern": "\\b(non c'e|non ce) (bisogno|motivo) di (preoccuparsi|allarmarsi|fare altri esami|approfondire)\\b",
   "example_it": "Non c'e bisogno di fare altri esami."},
  {"id": 24, "category": "reassurance",
   "pattern": "\\b(sei|e) (perfettamente|completamente|del tutto) (san[oa]|a posto|normale|in salute)\\b",
   "example_it": "Sei perfettamente sano."},
  {"id": 25, "category": "alarm",
   "pattern": "\\b(corri|vai subito|vai immediatamente|recati subito) (al pronto soccorso|in ospedale|dal medico)\\b",
   "example_it": "Corri al pronto soccorso."},
  {"id": 26, "category": "alarm",
   "pattern": "\\b(e un|e una|e un'|si tratta di un'|si tratta di una) ?(emergenza|urgenza)\\b",
   "example_it": "E un'emergenza."},
  {"id": 27, "category": "alarm",
   "pattern": "\\b(grave|gravissim[oa]|pericolos[oa]|allarmante|preoccupante) (situazione|condizione|quadro|valore)\\b|\\b(situazione|condizione|quadro|valore) (grave|gravissim[oa]|pericolos[oa]|allarmante|preoccupante)\\b",
   "example_it": "Valore allarmante."},
  {"id": 28, "category": "identity",
   "pattern": "\\b(come medico|da medico|in qualita di medico|il tuo medico ti dice|sono un medico|sono il tuo medico|parere medico|consulto medico)\\b",
   "example_it": "Come medico, ti dico che..."},
  {"id": 29, "category": "identity",
   "pattern": "\\b(diagnosi|terapia|cura) (personalizzata|su misura|per te|per il tuo caso)\\b",
   "example_it": "Ecco la terapia per il tuo caso."},
  {"id": 30, "category": "identity",
   "pattern": "\\b(sostituisce|al posto d(el|i un) medico|senza medico|non hai bisogno del medico)\\b",
   "example_it": "Questa spiegazione sostituisce la visita."}
 ],
 "required_closing_it": "Le informazioni non sostituiscono il parere del medico.",
 "allowed_examples_it": [
  "La glicemia a digiuno è 112 mg/dL, sopra l'intervallo di riferimento del laboratorio (70–99). Un valore isolato non basta a trarre conclusioni: è un dato da discutere con il medico.",
  "Il colesterolo LDL è il colesterolo trasportato dalle lipoproteine a bassa densità; i riferimenti dipendono dal rischio cardiovascolare complessivo, che valuta il medico.",
  "La creatinina è nell'intervallo di riferimento. Il filtrato stimato (eGFR) è 95 mL/min/1,73 m², nella fascia G1 secondo la classificazione KDIGO."
 ]
}
  $json$::jsonb
)
on conflict (type, version) do update set
  status     = excluded.status,
  notes      = excluded.notes,
  definition = excluded.definition;

-- ---------------------------------------------------------------------------
-- 2a. normalize_for_filter
--     Minuscole, accenti rimossi, apostrofi conservati (quelli tipografici
--     diventano l'apostrofo dritto, cosi i pattern "non c'e" funzionano sia
--     con ' sia con ’).
-- ---------------------------------------------------------------------------
create or replace function public.normalize_for_filter(p_text text)
returns text
language sql
immutable
as $fn$
  select translate(
    lower(coalesce(p_text, '')),
    $from$àáâãäåèéêëìíîïòóôõöùúûüýÿçñ’‘`´$from$,
    $to$aaaaaaeeeeiiiiooooouuuuyycn''''$to$
  );
$fn$;

comment on function public.normalize_for_filter(text) is
  'Normalizzazione del filtro anti-diagnosi: minuscole, accenti rimossi, '
  'apostrofi conservati e uniformati. Usata da check_forbidden_phrases.';

-- ---------------------------------------------------------------------------
-- 2b. check_forbidden_phrases
--     Applica tutti i pattern della regola forbidden_phrases attiva con
--     l'operatore ~* (case-insensitive) sul testo normalizzato.
--
--     Nota tecnica obbligatoria: nelle espressioni regolari di PostgreSQL
--     \b e il carattere backspace, non il confine di parola (che si scrive
--     \y). I pattern del board usano la notazione PCRE \b, quindi qui viene
--     tradotta in \y prima dell'applicazione. Nessun altro costrutto dei
--     trenta pattern richiede conversione.
-- ---------------------------------------------------------------------------
create or replace function public.check_forbidden_phrases(p_text text)
returns table (matched boolean, ids int[], categories text[])
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_norm text;
  v_rule jsonb;
  v_ids  int[]  := '{}';
  v_cats text[] := '{}';
  v_pattern text;
  e jsonb;
begin
  v_norm := public.normalize_for_filter(p_text);

  select r.definition into v_rule
  from public.rule_versions r
  where r.type = 'forbidden_phrases' and r.status = 'active'
  order by r.version desc
  limit 1;

  if v_rule is null or v_norm = '' then
    return query select false, v_ids, v_cats;
    return;
  end if;

  for e in select * from jsonb_array_elements(coalesce(v_rule->'forbidden', '[]'::jsonb)) loop
    v_pattern := replace(e->>'pattern', '\b', '\y');
    if v_norm ~* v_pattern then
      v_ids := v_ids || (e->>'id')::int;
      if not ((e->>'category') = any (v_cats)) then
        v_cats := v_cats || (e->>'category');
      end if;
    end if;
  end loop;

  return query select array_length(v_ids, 1) is not null, v_ids, v_cats;
end;
$$;

comment on function public.check_forbidden_phrases(text) is
  'Filtro anti-diagnosi: restituisce gli id e le categorie dei pattern della '
  'regola forbidden_phrases attiva che corrispondono al testo normalizzato.';

revoke execute on function public.normalize_for_filter(text) from public, anon;
revoke execute on function public.check_forbidden_phrases(text) from public, anon;
grant execute on function public.normalize_for_filter(text) to authenticated, service_role;
grant execute on function public.check_forbidden_phrases(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. explanations — la cache. Scrive solo la service role.
-- ---------------------------------------------------------------------------
create table if not exists public.explanations (
  id             uuid primary key default gen_random_uuid(),
  subject_id     uuid not null,
  target_type    text not null check (target_type in ('biomarker','organ','risk','document')),
  target_id      text not null,
  level          text not null check (level in ('simple','clinical')),
  lang           text not null check (lang in ('it','en')),
  inputs_hash    text not null check (inputs_hash ~ '^[0-9a-f]{64}$'),
  text           text not null,
  model          text not null,
  prompt_version text not null,
  tokens_in      int    not null default 0 check (tokens_in >= 0),
  tokens_out     int    not null default 0 check (tokens_out >= 0),
  cost_micro_usd bigint not null default 0 check (cost_micro_usd >= 0),
  filter_passed  boolean not null default true,
  filter_ids     int[]   not null default '{}',
  generated_at   timestamptz not null default clock_timestamp(),
  created_at     timestamptz not null default now(),
  unique (subject_id, target_type, target_id, level, lang, inputs_hash)
);

comment on table public.explanations is
  'Cache delle spiegazioni IA (M7). Una riga per soggetto, bersaglio, livello, '
  'lingua e hash degli input: si rigenera solo se cambia un input. '
  'Scrive esclusivamente la service role attraverso explanation_save.';

create index if not exists idx_explanations_subject_time
  on public.explanations (subject_id, generated_at desc);

-- ---------------------------------------------------------------------------
-- 3a. explanation_lookup — la cache letta con il token dell'utente.
-- ---------------------------------------------------------------------------
create or replace function public.explanation_lookup(
  p_subject uuid, p_target_type text, p_target_id text,
  p_level text, p_lang text, p_inputs_hash text
)
returns table (
  explanation_id uuid, explanation_text text, explanation_level text,
  explanation_lang text, model text, prompt_version text,
  generated_at timestamptz
)
language sql
stable
security invoker
set search_path = public
as $$
  select e.id, e.text, e.level, e.lang, e.model, e.prompt_version, e.generated_at
  from public.explanations e
  where e.subject_id = p_subject
    and e.target_type = p_target_type
    and e.target_id   = p_target_id
    and e.level       = p_level
    and e.lang        = p_lang
    and e.inputs_hash = p_inputs_hash
    and e.filter_passed
  order by e.generated_at desc
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- 3b. explanation_usage — massimo 30 generazioni nuove al giorno per soggetto.
-- ---------------------------------------------------------------------------
create or replace function public.explanation_usage(p_subject uuid)
returns table (used int, max_per_day int)
language plpgsql
stable
security definer
set search_path = public
as $$
declare v_max int := 30;
begin
  -- auth.uid() nullo = chiamata interna con la service role.
  if auth.uid() is not null and not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  return query
    select count(*)::int, v_max
    from public.explanations e
    where e.subject_id = p_subject
      and e.generated_at >= date_trunc('day', now());
end;
$$;

-- ---------------------------------------------------------------------------
-- 3c. explanation_save — unica scrittura ammessa. Audit senza testo.
--     Un testo bocciato dal filtro non viene mai salvato.
-- ---------------------------------------------------------------------------
create or replace function public.explanation_save(
  p_subject uuid, p_target_type text, p_target_id text,
  p_level text, p_lang text, p_inputs_hash text, p_text text,
  p_model text, p_prompt_version text,
  p_tokens_in int, p_tokens_out int, p_cost_micro_usd bigint,
  p_filter_passed boolean, p_filter_ids int[]
)
returns table (explanation_id uuid, saved_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid; v_at timestamptz;
begin
  if not coalesce(p_filter_passed, false) then
    raise exception 'filter_failed_not_saved' using errcode = 'P0001';
  end if;

  insert into public.explanations (
    subject_id, target_type, target_id, level, lang, inputs_hash, text,
    model, prompt_version, tokens_in, tokens_out, cost_micro_usd,
    filter_passed, filter_ids
  ) values (
    p_subject, p_target_type, p_target_id, p_level, p_lang, p_inputs_hash, p_text,
    p_model, p_prompt_version, coalesce(p_tokens_in, 0), coalesce(p_tokens_out, 0),
    coalesce(p_cost_micro_usd, 0), true, coalesce(p_filter_ids, '{}')
  )
  on conflict (subject_id, target_type, target_id, level, lang, inputs_hash)
  do update set generated_at = clock_timestamp()
  returning explanations.id, explanations.generated_at into v_id, v_at;

  -- Audit: evento, bersaglio e soggetto. Mai il testo, mai un valore clinico.
  insert into public.audit_log (actor_id, action, target_table, target_id, subject_id)
  values (auth.uid(), 'explanation.generated', 'explanations', v_id, p_subject);

  return query select v_id, v_at;
end;
$$;

revoke execute on function public.explanation_usage(uuid) from public, anon;
revoke execute on function public.explanation_save(
  uuid, text, text, text, text, text, text, text, text, int, int, bigint, boolean, int[]
) from public, anon, authenticated;
grant execute on function public.explanation_usage(uuid) to authenticated, service_role;
grant execute on function public.explanation_save(
  uuid, text, text, text, text, text, text, text, text, int, int, bigint, boolean, int[]
) to service_role;

-- ---------------------------------------------------------------------------
-- 4. explanation_context — i soli dati necessari al prompt, piu lo hash.
--    Mai testo libero del documento. Dal profilo: solo lingua, eta e genere.
-- ---------------------------------------------------------------------------
create or replace function public.explanation_context(
  p_subject uuid, p_target_type text, p_target_id text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_lang text; v_gender text; v_age int;
  v_payload jsonb; v_ctx jsonb; v_hash text; v_rule text;
begin
  if not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if p_target_type not in ('biomarker','organ','risk','document') then
    raise exception 'invalid_target_type' using errcode = 'P0001';
  end if;
  if p_target_id is null or btrim(p_target_id) = '' then
    raise exception 'invalid_target_id' using errcode = 'P0001';
  end if;

  select coalesce(p.language, 'it'), p.gender,
         case when p.birth_date is null then null
              else extract(year from age(current_date, p.birth_date))::int end
    into v_lang, v_gender, v_age
  from public.profiles p where p.id = p_subject;

  if p_target_type = 'biomarker' then
    select jsonb_build_object(
      'code', c.code,
      'name_it', c.name_it,
      'name_en', c.name_en,
      'unit', c.unit_canonical,
      'institutional_low',
        case when v_gender = 'female' then c.ref_low_f else c.ref_low_m end,
      'institutional_high',
        case when v_gender = 'female' then c.ref_high_f else c.ref_high_m end,
      'board_version', c.board_version,
      'laboratory_low', o.lab_low,
      'laboratory_high', o.lab_high,
      'doctor_low', d.low,
      'doctor_high', d.high,
      'doctor_reason', d.reason,
      'organs', coalesce((
        select jsonb_agg(jsonb_build_object('id', g.id, 'name_it', g.name_it,
                                            'name_en', g.name_en)
               order by g.sort_order)
        from public.organ_biomarker_map m
        join public.organs g on g.id = m.organ_id
        where m.code = c.code), '[]'::jsonb),
      'values', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'effective_at', (v.effective_at at time zone 'UTC'),
                 'value', v.canonical_value,
                 'unit', v.canonical_unit,
                 'flag', v.flag) order by v.effective_at desc)
        from (
          select b.canonical_value, b.canonical_unit, b.flag, b.effective_at
          from public.biomarker_series b
          where b.subject_id = p_subject and b.code = c.code
          order by b.effective_at desc, b.observation_id desc
          limit 6
        ) v), '[]'::jsonb)
    )
    into v_payload
    from public.biomarker_catalog c
    left join lateral (
      select x.lab_low, x.lab_high from public.observations x
      where x.subject_id = p_subject and x.code = c.code
        and x.superseded_at is null and x.review_status <> 'discarded'
      order by x.effective_at desc, x.id desc limit 1
    ) o on true
    left join lateral (
      select x.low, x.high, x.reason from public.threshold_overrides x
      where x.code = c.code and (x.subject_id = p_subject or x.subject_id is null)
        and x.valid_from <= now() and (x.valid_until is null or x.valid_until > now())
      order by (x.subject_id is not null) desc, x.valid_from desc, x.id desc limit 1
    ) d on true
    where c.code = p_target_id;

  elsif p_target_type = 'organ' then
    select jsonb_build_object(
      'organ_id', g.id,
      'name_it', g.name_it,
      'name_en', g.name_en,
      'description_it', g.description_it,
      'description_en', g.description_en,
      'state', l.state,
      'stress_score', l.stress_score,
      'confidence', l.confidence,
      'rule_version', l.rule_version,
      'computed_at', (l.computed_at at time zone 'UTC'),
      'codes', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'code', c.code, 'name_it', c.name_it, 'name_en', c.name_en,
                 'unit', c.unit_canonical, 'weight', m.weight,
                 'present', (s.observation_id is not null),
                 'value', s.canonical_value,
                 'flag', s.flag,
                 'effective_at', (s.effective_at at time zone 'UTC'))
               order by m.weight desc, c.code)
        from public.organ_biomarker_map m
        join public.biomarker_catalog c on c.code = m.code
        left join lateral (
          select b.observation_id, b.canonical_value, b.flag, b.effective_at
          from public.biomarker_series b
          where b.subject_id = p_subject and b.code = m.code
          order by b.effective_at desc, b.observation_id desc limit 1
        ) s on true
        where m.organ_id = g.id), '[]'::jsonb)
    )
    into v_payload
    from public.organs g
    left join lateral (
      select x.state, x.stress_score, x.confidence, x.rule_version, x.computed_at
      from public.organ_states x
      where x.subject_id = p_subject and x.organ_id = g.id
      order by x.computed_at desc, x.id desc limit 1
    ) l on true
    where g.id = p_target_id;

  elsif p_target_type = 'risk' then
    select jsonb_build_object(
      'family', s.family,
      'score', s.score,
      'score_unit', s.score_unit,
      'level', s.level,
      'factors', s.factors,
      'inputs', s.inputs,
      'projection_12m', s.projection_12m,
      'rule_version', s.rule_version,
      'computed_at', (s.computed_at at time zone 'UTC'),
      'rule_definition', (
        select r.definition from public.rule_versions r
        where r.type || '-' || r.version = s.rule_version limit 1)
    )
    into v_payload
    from public.risk_scores s
    where s.subject_id = p_subject and s.family = p_target_id
    order by s.computed_at desc, s.id desc
    limit 1;

  else -- document: mai il testo libero, solo i valori confermati
    select jsonb_build_object(
      'document_id', d.id,
      'category', d.category,
      'document_date', d.document_date,
      'lab_name', (
        select x.lab_name from public.observations x
        where x.document_id = d.id and x.lab_name is not null limit 1),
      'values', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'code', x.code, 'name_it', c.name_it, 'name_en', c.name_en,
                 'value', x.value_num, 'unit', x.unit, 'flag', x.flag,
                 'lab_low', x.lab_low, 'lab_high', x.lab_high,
                 'effective_at', (x.effective_at at time zone 'UTC'))
               order by x.code)
        from public.observations x
        left join public.biomarker_catalog c on c.code = x.code
        where x.document_id = d.id and x.subject_id = p_subject
          and x.superseded_at is null and x.review_status = 'confirmed'
      ), '[]'::jsonb)
    )
    into v_payload
    from public.documents d
    where d.id = p_target_id::uuid and d.subject_id = p_subject and d.deleted_at is null;
  end if;

  if v_payload is null then
    raise exception 'target_not_found' using errcode = 'P0001';
  end if;

  select r.type || '-' || r.version into v_rule
  from public.rule_versions r
  where r.type = 'forbidden_phrases' and r.status = 'active'
  order by r.version desc limit 1;

  v_ctx := jsonb_build_object(
    'target_type', p_target_type,
    'target_id', p_target_id,
    'lang', v_lang,
    'age_years', v_age,
    'gender', v_gender,
    'filter_rule_version', v_rule,
    'payload', v_payload
  );

  -- jsonb normalizza l'ordine delle chiavi: lo stesso contenuto produce
  -- sempre lo stesso testo e quindi lo stesso hash. La Edge Function usa
  -- questo hash, non lo ricalcola: client e funzione restano allineati.
  v_hash := encode(sha256(convert_to(v_ctx::text, 'UTF8')), 'hex');
  return v_ctx || jsonb_build_object('inputs_hash', v_hash);
end;
$$;

comment on function public.explanation_context(uuid, text, text) is
  'Contesto minimo per il prompt di explain, con lo hash sha256 canonico del '
  'contenuto. Nessun testo libero del documento, nessun dato di profilo oltre '
  'lingua, eta e genere.';

revoke execute on function public.explanation_context(uuid, text, text) from public, anon;
grant execute on function public.explanation_context(uuid, text, text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 5. RLS: sola lettura del soggetto. Nessuna policy di insert, update, delete.
-- ---------------------------------------------------------------------------
alter table public.explanations enable row level security;
alter table public.explanations force  row level security;

drop policy if exists explanations_select on public.explanations;
create policy explanations_select on public.explanations
  for select to authenticated
  using (public.can_access_subject(subject_id));

revoke all on public.explanations from anon;
grant select on public.explanations to authenticated;
revoke insert, update, delete on public.explanations from authenticated;

insert into public.app_migrations(name) values ('0013_explanations') on conflict do nothing;
