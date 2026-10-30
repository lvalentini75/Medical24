-- ============================================================================
-- Medical 24 — 0010 ORGAN RULE 0.3 (P04-A3) · modulo M5 Corpo e organi
--
-- Lo stato dell'area smette di dipendere dal conteggio grezzo dei valori fuori
-- riferimento e viene derivato dall'indice di scostamento, così colore ed
-- etichetta raccontano la stessa cosa.
--
-- Contenuto:
--   1. rule_versions: organ_state 0.3 active, 0.2 retired, soglie nella
--      definition (ok_below 0.05, attention_from 0.60, critical_floor 0.80)
--   2. compute_organ_states(): indice con pavimento per i critical e stato
--      derivato dalle soglie della regola attiva
--   3. ricalcolo di tutti i soggetti
--
-- Nessuna firma cambia. observations e organ_states restano append-only:
-- qui non si fa nessun update e nessun delete su quelle tabelle.
-- Idempotente: può essere rieseguita senza effetti collaterali.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. rule_versions — la 0.3 prende il posto della 0.2
-- ---------------------------------------------------------------------------
insert into public.rule_versions (type, version, status, notes, definition)
values (
  'organ_state', '0.3', 'active',
  'bozza provvisoria in attesa di validazione del board',
  jsonb_build_object(
    'window_months', 24,
    'input', 'ultima osservazione per codice della vista biomarker_series',
    'states', jsonb_build_array('ok','monitor','attention','missing'),
    'weights', jsonb_build_object('essential', 2, 'standard', 1),
    'thresholds', jsonb_build_object(
      'attention_critical_flags', jsonb_build_array('critical_low','critical_high'),
      'out_of_range_flags', jsonb_build_array('below','above'),
      'ok_below', 0.05,
      'attention_from', 0.60,
      'critical_floor', 0.80
    ),
    'confidence', jsonb_build_object(
      'numerator', 'somma dei pesi dei codici presenti',
      'denominator_essential', 'somma dei pesi dei codici essenziali dell area',
      'denominator_fallback', 3,
      'cap', 1
    ),
    'stress_score', jsonb_build_object(
      'formula', '(0.5 * peso degli input below o above + 1 * peso degli input critical) / peso degli input presenti',
      'critical_floor', 'se esiste almeno un input critical l indice non scende sotto critical_floor',
      'round_decimals', 2,
      'missing', null
    ),
    'state_rule',
      'missing senza input; attention se esiste almeno un input critical oppure '
      'se l indice e maggiore o uguale a attention_from; monitor se l indice e '
      'maggiore o uguale a ok_below; altrimenti ok. Le tre soglie si leggono da '
      'thresholds della regola attiva.',
    'sex_rule', 'calcola sex=all oppure sex=subject_sex; neutral solo per genere nullo o non riconosciuto',
    'missing_when', 'nessun input nella finestra'
  )
)
on conflict (type, version) do update set
  status     = excluded.status,
  notes      = excluded.notes,
  definition = excluded.definition;

update public.rule_versions set status = 'retired'
where type = 'organ_state' and version = '0.2' and status <> 'retired';

-- ---------------------------------------------------------------------------
-- 2. compute_organ_states — regola organ_state 0.3
--    Firma invariata: compute_organ_states(uuid) returns int.
-- ---------------------------------------------------------------------------
create or replace function public.compute_organ_states(p_subject uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  o record;
  v_inputs jsonb;
  v_state organ_state;
  v_confidence numeric;
  v_stress numeric;
  v_rule text;
  v_def jsonb;
  v_window interval;
  v_ok_below numeric;
  v_attention_from numeric;
  v_critical_floor numeric;
  v_present_w numeric;
  v_essential_w numeric;
  v_present_n int;
  v_out_weight numeric;
  v_critical_weight numeric;
  v_has_crit boolean;
  v_last_state organ_state;
  v_last_conf numeric;
  v_last_stress numeric;
  v_last_inputs jsonb;
  v_last_rule text;
  v_written int := 0;
  v_subject_sex text;
begin
  if p_subject is null then
    raise exception 'subject_required' using errcode = 'P0001';
  end if;
  -- Dal trigger e dal cron auth.uid() è null: il controllo vale solo
  -- quando la chiamata arriva da un utente.
  if auth.uid() is not null and not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  v_subject_sex := public.subject_sex(p_subject);

  select 'organ_state-' || r.version, r.definition
    into v_rule, v_def
  from public.rule_versions r
  where r.type = 'organ_state' and r.status = 'active'
  order by r.version desc
  limit 1;

  if v_rule is null then
    v_rule := 'organ_state-0.3';
    v_def := '{}'::jsonb;
  end if;

  v_window := make_interval(months => coalesce((v_def ->> 'window_months')::int, 24));
  -- Le soglie stanno nella definition della regola: qui solo il valore di scorta.
  v_ok_below       := coalesce((v_def -> 'thresholds' ->> 'ok_below')::numeric, 0.05);
  v_attention_from := coalesce((v_def -> 'thresholds' ->> 'attention_from')::numeric, 0.60);
  v_critical_floor := coalesce((v_def -> 'thresholds' ->> 'critical_floor')::numeric, 0.80);

  for o in select id from public.organs
    where sex = 'all' or sex = v_subject_sex order by sort_order loop
    -- Un input per codice mappato: l'ultima osservazione nella finestra.
    with mapped as (
      select m.code, m.weight from public.organ_biomarker_map m where m.organ_id = o.id
    ), latest as (
      select mp.code, mp.weight, s.observation_id, s.flag, s.effective_at
      from mapped mp
      join lateral (
        select b.observation_id, b.flag, b.effective_at
        from public.biomarker_series b
        where b.subject_id = p_subject and b.code = mp.code
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
      coalesce(sum(l.weight) filter (where l.flag in ('critical_low','critical_high')), 0),
      coalesce(bool_or(l.flag in ('critical_low','critical_high')), false)
      into v_inputs, v_present_w, v_present_n, v_out_weight, v_critical_weight, v_has_crit
    from latest l;

    select coalesce(sum(m.weight), 0) into v_essential_w
    from public.organ_biomarker_map m
    join public.biomarker_catalog c on c.code = m.code
    where m.organ_id = o.id and c.is_essential;

    if v_present_n = 0 then
      v_state := 'missing';
      v_stress := null;
    else
      v_stress := (0.5 * v_out_weight + v_critical_weight) / v_present_w;
      -- Un valore critico non può restare un indice basso.
      if v_has_crit and v_stress < v_critical_floor then
        v_stress := v_critical_floor;
      end if;
      v_stress := round(v_stress, 2);
      if v_has_crit or v_stress >= v_attention_from then
        v_state := 'attention';
      elsif v_stress >= v_ok_below then
        v_state := 'monitor';
      else
        v_state := 'ok';
      end if;
    end if;

    if v_essential_w > 0 then
      v_confidence := least(1, v_present_w / v_essential_w);
    else
      v_confidence := least(1, v_present_n::numeric / 3);
    end if;

    v_last_state := null; v_last_conf := null; v_last_stress := null;
    v_last_inputs := null; v_last_rule := null;
    select s.state, s.confidence, s.stress_score, s.inputs, s.rule_version
      into v_last_state, v_last_conf, v_last_stress, v_last_inputs, v_last_rule
    from public.organ_states s
    where s.subject_id = p_subject and s.organ_id = o.id
    order by s.computed_at desc, s.id desc
    limit 1;

    if v_last_state is null
       or v_last_state is distinct from v_state
       or round(coalesce(v_last_conf, 0), 2) is distinct from round(v_confidence, 2)
       or v_last_stress is distinct from v_stress
       or coalesce(v_last_inputs, '[]'::jsonb) is distinct from v_inputs
       or v_last_rule is distinct from v_rule then
      insert into public.organ_states (
        subject_id, organ_id, state, confidence, inputs, rule_version, stress_score
      ) values (
        p_subject, o.id, v_state, round(v_confidence, 2), v_inputs, v_rule, v_stress
      );
      v_written := v_written + 1;
    end if;
  end loop;

  return v_written;
end;
$$;

comment on function public.compute_organ_states(uuid) is
  'Regola organ_state 0.3: indice = (0.5 * peso below/above + peso critical) / '
  'peso degli input presenti, con pavimento critical_floor quando esiste un '
  'valore critico; lo stato deriva dalle soglie della regola attiva.';

revoke execute on function public.compute_organ_states(uuid) from public, anon;
grant execute on function public.compute_organ_states(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Ricalcolo di tutti i soggetti
--    Append-only: le righe esistenti restano, ne nasce una nuova solo dove
--    stato, indice, confidenza, input o versione della regola cambiano.
-- ---------------------------------------------------------------------------
select public.compute_organ_states_all();

-- ---------------------------------------------------------------------------
-- 4. Controllo
-- ---------------------------------------------------------------------------
do $$
begin
  if (select count(*) from public.rule_versions
      where type = 'organ_state' and status = 'active') <> 1 then
    raise exception 'organ_state: deve esistere una sola regola attiva';
  end if;
  if not exists (select 1 from public.rule_versions
      where type = 'organ_state' and version = '0.3' and status = 'active') then
    raise exception 'organ_state 0.3 non attiva';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Registro
-- ---------------------------------------------------------------------------
insert into public.app_migrations (name)
values ('0010_organ_rule_0_3')
on conflict do nothing;
