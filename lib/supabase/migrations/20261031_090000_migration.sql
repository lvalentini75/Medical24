-- Medical 24 - 0009 BODY SEX & STRESS (P04-A2).
-- Adds sex-specific body areas and a deterministic 0..1 deviation index.

alter table public.organs add column if not exists sex text not null default 'all';

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'organs_sex_check'
    and conrelid = 'public.organs'::regclass) then
    alter table public.organs add constraint organs_sex_check
      check (sex in ('all','female','male','neutral'));
  end if;
end $$;

insert into public.organs (
  id, sort_order, name_it, name_en, description_it, description_en,
  icon, anchor_x, anchor_y, version, sex
) values
  ('heart',1,'Cuore e circolazione','Heart and circulation','Lipidi, pressione, frequenza cardiaca e marcatori cardiaci','Lipids, blood pressure, heart rate and cardiac markers','heart-pulse',0.44,0.31,'0.2-draft','all'),
  ('lung',2,'Polmoni e respiro','Lungs and breathing','Saturazione e parametri respiratori','Oxygen saturation and respiratory parameters','wind',0.615,0.30,'0.2-draft','all'),
  ('liver',3,'Fegato','Liver','Transaminasi, gamma GT, bilirubina, proteine','Transaminases, gamma GT, bilirubin, proteins','flask-conical',0.41,0.415,'0.2-draft','all'),
  ('kidney',4,'Reni e vie urinarie','Kidneys and urinary tract','Creatinina, filtrato, azotemia, elettroliti, esame urine, vescica','Creatinine, eGFR, urea, electrolytes, urinalysis','filter',0.60,0.445,'0.2-draft','all'),
  ('metabolism',5,'Metabolismo e pancreas','Metabolism and pancreas','Glicemia, HbA1c, insulina, amilasi, lipasi, peso','Glucose, HbA1c, insulin, amylase, lipase, weight','flame',0.50,0.46,'0.2-draft','all'),
  ('gut',6,'Stomaco e intestino','Stomach and gut','Area in attesa di biomarcatori del board','Area awaiting board biomarkers','utensils-crossed',0.50,0.545,'0.2-draft','all'),
  ('blood',7,'Sangue','Blood','Emocromo, ferro, coagulazione, vitamine','Blood count, iron, coagulation, vitamins','droplet',0.21,0.50,'0.2-draft','all'),
  ('immune',8,'Difese e infiammazione','Immunity and inflammation','Leucociti, PCR, VES, immunoglobuline','White cells, CRP, ESR, immunoglobulins','shield-check',0.79,0.50,'0.2-draft','all'),
  ('thyroid',9,'Tiroide e ormoni','Thyroid and hormones','TSH, FT3, FT4 e altri ormoni','TSH, FT3, FT4 and other hormones','circle-dot',0.50,0.19,'0.2-draft','all'),
  ('brain',10,'Cervello e nervi','Brain and nerves','Area in attesa di biomarcatori del board','Area awaiting board biomarkers','brain',0.50,0.082,'0.2-draft','all'),
  ('musculoskeletal',11,'Ossa e muscoli','Bones and muscles','Calcio, vitamina D, fosfatasi alcalina, CK','Calcium, vitamin D, alkaline phosphatase, CK','bone',0.50,0.80,'0.2-draft','all'),
  ('reproductive',12,'Apparato riproduttivo','Reproductive system','Ormoni sessuali, PSA','Sex hormones, PSA','venus-and-mars',0.50,0.755,'0.2-draft','neutral'),
  ('breast',13,'Seno','Breast','Area di prevenzione: screening e autopalpazione; biomarcatori in attesa del board','Prevention area: screening and self-exam; biomarkers awaiting the board','circle',0.39,0.345,'0.2-draft','female'),
  ('reproductive_f',14,'Utero e ovaie','Uterus and ovaries','Ormoni femminili, ciclo, screening ginecologici','Female hormones, cycle, gynaecological screening','venus',0.50,0.755,'0.2-draft','female'),
  ('prostate',15,'Prostata','Prostate','PSA e controlli urologici','PSA and urological checks','circle-dot',0.50,0.752,'0.2-draft','male'),
  ('reproductive_m',16,'Testicoli e ormoni','Testicles and hormones','Testosterone, FSH, LH','Testosterone, FSH, LH','mars',0.50,0.775,'0.2-draft','male')
on conflict (id) do update set
  sort_order=excluded.sort_order, name_it=excluded.name_it, name_en=excluded.name_en,
  description_it=excluded.description_it, description_en=excluded.description_en,
  icon=excluded.icon, anchor_x=excluded.anchor_x, anchor_y=excluded.anchor_y,
  version=excluded.version, sex=excluded.sex;

comment on column public.organs.sex is
  'Applicabilita dell area: all, female, male o neutral per genere non dichiarato.';

create or replace function public.subject_sex(p_subject uuid)
returns text
language plpgsql stable security definer set search_path = public
as $$
declare v_gender text;
begin
  if p_subject is null then return 'neutral'; end if;
  if auth.uid() is not null and not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  select p.gender into v_gender from public.profiles p where p.id = p_subject;
  if v_gender = 'female' then return 'female'; end if;
  if v_gender = 'male' then return 'male'; end if;
  return 'neutral';
end;
$$;

-- A catalog key may feed multiple sex-specific areas.
create or replace function public.organ_ids_for_catalog_key(p_key text)
returns setof text language sql immutable set search_path = public
as $$
  select x.organ_id from (values
    ('heart','heart'),('lung','lung'),('liver','liver'),('kidney','kidney'),
    ('metabolism','metabolism'),('pancreas','metabolism'),('gut','gut'),
    ('blood','blood'),('immune','immune'),('thyroid','thyroid'),('brain','brain'),
    ('bone','musculoskeletal'),('muscle','musculoskeletal'),
    ('reproductive','reproductive_f'),('reproductive','reproductive_m'),
    ('reproductive','reproductive'),('prostate','prostate'),
    ('prostate','reproductive')
  ) as x(catalog_key, organ_id)
  where x.catalog_key = lower(btrim(coalesce(p_key,'')));
$$;

create or replace function public.rebuild_organ_biomarker_map()
returns int language plpgsql security definer set search_path = public
as $$
declare v_rows int;
begin
  with pairs as (
    select ids.organ_id, c.code,
      case when c.is_essential then 2 else 1 end::smallint as weight
    from public.biomarker_catalog c
    cross join lateral unnest(c.organs) k
    cross join lateral public.organ_ids_for_catalog_key(k) ids(organ_id)
  ), deduped as (
    select organ_id, code, max(weight)::smallint weight from pairs group by organ_id, code
  ), upserted as (
    insert into public.organ_biomarker_map(organ_id,code,weight)
    select organ_id,code,weight from deduped
    on conflict(organ_id,code) do update set weight=excluded.weight
    returning 1
  ) select count(*)::int into v_rows from upserted;

  delete from public.organ_biomarker_map m where not exists (
    select 1 from public.biomarker_catalog c
    cross join lateral unnest(c.organs) k
    cross join lateral public.organ_ids_for_catalog_key(k) ids(organ_id)
    where c.code=m.code and ids.organ_id=m.organ_id
  );
  return v_rows;
end;
$$;

select public.rebuild_organ_biomarker_map();
drop function if exists public.organ_for_catalog_key(text);

alter table public.organ_states add column if not exists stress_score numeric;
do $$ begin
  if not exists (select 1 from pg_constraint where conname='organ_states_stress_score_check'
    and conrelid='public.organ_states'::regclass) then
    alter table public.organ_states add constraint organ_states_stress_score_check
      check (stress_score is null or stress_score between 0 and 1);
  end if;
end $$;

update public.rule_versions set status='retired'
where type='organ_state' and version='0.1' and status <> 'retired';

insert into public.rule_versions(type,version,status,notes,definition)
values ('organ_state','0.2','active','bozza provvisoria in attesa di validazione del board',
  jsonb_build_object(
    'window_months',24,
    'input','ultima osservazione per codice della vista biomarker_series',
    'states',jsonb_build_array('ok','monitor','attention','missing'),
    'weights',jsonb_build_object('essential',2,'standard',1),
    'thresholds',jsonb_build_object(
      'attention_critical_flags',jsonb_build_array('critical_low','critical_high'),
      'out_of_range_flags',jsonb_build_array('below','above'),
      'attention_out_of_range_weight',2,'monitor_out_of_range_weight',1),
    'confidence',jsonb_build_object(
      'numerator','somma dei pesi dei codici presenti',
      'denominator_essential','somma dei pesi dei codici essenziali dell area',
      'denominator_fallback',3,'cap',1),
    'stress_score',jsonb_build_object(
      'formula','(0.5 * peso below/above + 1 * peso critical) / peso degli input presenti',
      'round_decimals',2,'missing',null),
    'sex_rule','calcola sex=all oppure sex=subject_sex; neutral solo per genere nullo o non riconosciuto',
    'missing_when','nessun input nella finestra'))
on conflict(type,version) do update set status=excluded.status, notes=excluded.notes,
  definition=excluded.definition;

create or replace view public.latest_organ_states with (security_invoker=true) as
select distinct on (s.subject_id,s.organ_id)
  s.id,s.subject_id,s.organ_id,s.state,s.confidence,s.inputs,s.rule_version,
  s.computed_at,s.stress_score
from public.organ_states s
order by s.subject_id,s.organ_id,s.computed_at desc,s.id desc;

create or replace function public.compute_organ_states(p_subject uuid)
returns int language plpgsql security definer set search_path = public
as $$
declare
  o record; v_inputs jsonb; v_state organ_state; v_confidence numeric;
  v_stress numeric; v_rule text; v_window interval; v_present_w numeric;
  v_essential_w numeric; v_present_n int; v_out_weight numeric;
  v_critical_weight numeric; v_has_crit boolean; v_last_state organ_state;
  v_last_conf numeric; v_last_stress numeric; v_last_inputs jsonb;
  v_last_rule text; v_written int := 0; v_subject_sex text;
begin
  if p_subject is null then raise exception 'subject_required' using errcode='P0001'; end if;
  if auth.uid() is not null and not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode='42501';
  end if;
  v_subject_sex := public.subject_sex(p_subject);
  select 'organ_state-'||r.version,
    make_interval(months=>coalesce((r.definition->>'window_months')::int,24))
  into v_rule,v_window from public.rule_versions r
  where r.type='organ_state' and r.status='active' order by r.version desc limit 1;
  if v_rule is null then v_rule:='organ_state-0.2'; v_window:=interval '24 months'; end if;

  for o in select id from public.organs
    where sex='all' or sex=v_subject_sex order by sort_order loop
    with mapped as (
      select m.code,m.weight from public.organ_biomarker_map m where m.organ_id=o.id
    ), latest as (
      select mp.code,mp.weight,s.observation_id,s.flag,s.effective_at from mapped mp
      join lateral (select b.observation_id,b.flag,b.effective_at
        from public.biomarker_series b where b.subject_id=p_subject and b.code=mp.code
          and b.effective_at>=now()-v_window and b.effective_at<=now()
        order by b.effective_at desc,b.observation_id desc limit 1) s on true
    ) select coalesce(jsonb_agg(jsonb_build_object('code',l.code,
        'observation_id',l.observation_id,'flag',l.flag,
        'effective_at',(l.effective_at at time zone 'UTC'),'weight',l.weight)
        order by l.code),'[]'::jsonb),
      coalesce(sum(l.weight),0),count(*)::int,
      coalesce(sum(l.weight) filter(where l.flag in ('below','above')),0),
      coalesce(sum(l.weight) filter(where l.flag in ('critical_low','critical_high')),0),
      coalesce(bool_or(l.flag in ('critical_low','critical_high')),false)
    into v_inputs,v_present_w,v_present_n,v_out_weight,v_critical_weight,v_has_crit
    from latest l;

    select coalesce(sum(m.weight),0) into v_essential_w
    from public.organ_biomarker_map m join public.biomarker_catalog c on c.code=m.code
    where m.organ_id=o.id and c.is_essential;

    if v_present_n=0 then v_state:='missing'; v_stress:=null;
    else
      if v_has_crit then v_state:='attention';
      elsif v_out_weight>=2 then v_state:='attention';
      elsif v_out_weight>=1 then v_state:='monitor'; else v_state:='ok'; end if;
      v_stress:=round((0.5*v_out_weight+v_critical_weight)/v_present_w,2);
    end if;
    if v_essential_w>0 then v_confidence:=least(1,v_present_w/v_essential_w);
    else v_confidence:=least(1,v_present_n::numeric/3); end if;

    v_last_state:=null; v_last_conf:=null; v_last_stress:=null;
    v_last_inputs:=null; v_last_rule:=null;
    select s.state,s.confidence,s.stress_score,s.inputs,s.rule_version
    into v_last_state,v_last_conf,v_last_stress,v_last_inputs,v_last_rule
    from public.organ_states s where s.subject_id=p_subject and s.organ_id=o.id
    order by s.computed_at desc,s.id desc limit 1;
    if v_last_state is null or v_last_state is distinct from v_state
      or round(coalesce(v_last_conf,0),2) is distinct from round(v_confidence,2)
      or v_last_stress is distinct from v_stress
      or coalesce(v_last_inputs,'[]'::jsonb) is distinct from v_inputs
      or v_last_rule is distinct from v_rule then
      insert into public.organ_states(subject_id,organ_id,state,confidence,inputs,
        rule_version,stress_score)
      values(p_subject,o.id,v_state,round(v_confidence,2),v_inputs,v_rule,v_stress);
      v_written:=v_written+1;
    end if;
  end loop;
  return v_written;
end;
$$;

-- Return types changed, so these functions must be dropped before recreation.
drop function if exists public.organ_overview(uuid);
create function public.organ_overview(p_subject uuid)
returns table(organ_id text,sort_order int,name_it text,name_en text,
  description_it text,description_en text,icon text,anchor_x numeric,anchor_y numeric,
  sex text,state organ_state,confidence numeric,stress_score numeric,
  computed_at timestamptz,present_codes int,mapped_codes int)
language sql stable security invoker set search_path=public as $$
  select o.id,o.sort_order,o.name_it,o.name_en,o.description_it,o.description_en,
    o.icon,o.anchor_x,o.anchor_y,o.sex,l.state,l.confidence,l.stress_score,l.computed_at,
    coalesce(jsonb_array_length(l.inputs),0)::int,coalesce(m.mapped_codes,0)::int
  from public.organs o
  left join public.latest_organ_states l on l.organ_id=o.id and l.subject_id=p_subject
  left join lateral (select count(*)::int mapped_codes from public.organ_biomarker_map bm
    where bm.organ_id=o.id) m on true
  where o.sex='all' or o.sex=public.subject_sex(p_subject)
  order by o.sort_order;
$$;

drop function if exists public.organ_history(uuid,text);
create function public.organ_history(p_subject uuid,p_organ text)
returns table(id uuid,state organ_state,confidence numeric,stress_score numeric,
  inputs jsonb,rule_version text,computed_at timestamptz)
language sql stable security invoker set search_path=public as $$
  select s.id,s.state,s.confidence,s.stress_score,s.inputs,s.rule_version,s.computed_at
  from public.organ_states s where s.subject_id=p_subject and s.organ_id=p_organ
  order by s.computed_at,s.id;
$$;

drop function if exists public.organ_comparison(uuid,text);
create function public.organ_comparison(p_subject uuid,p_organ text)
returns table(current_state organ_state,current_stress_score numeric,current_at timestamptz,
  state_6m organ_state,stress_score_6m numeric,at_6m timestamptz,
  state_12m organ_state,stress_score_12m numeric,at_12m timestamptz)
language sql stable security invoker set search_path=public as $$
  select cur.state,cur.stress_score,cur.computed_at,
    m6.state,m6.stress_score,m6.computed_at,m12.state,m12.stress_score,m12.computed_at
  from (select 1) one
  left join lateral (select s.state,s.stress_score,s.computed_at from public.organ_states s
    where s.subject_id=p_subject and s.organ_id=p_organ
    order by s.computed_at desc,s.id desc limit 1) cur on true
  left join lateral (select s.state,s.stress_score,s.computed_at from public.organ_states s
    where s.subject_id=p_subject and s.organ_id=p_organ
      and s.computed_at<=now()-interval '6 months'
    order by s.computed_at desc,s.id desc limit 1) m6 on true
  left join lateral (select s.state,s.stress_score,s.computed_at from public.organ_states s
    where s.subject_id=p_subject and s.organ_id=p_organ
      and s.computed_at<=now()-interval '12 months'
    order by s.computed_at desc,s.id desc limit 1) m12 on true;
$$;

revoke execute on function public.subject_sex(uuid) from public,anon;
grant execute on function public.subject_sex(uuid) to authenticated;
revoke execute on function public.organ_ids_for_catalog_key(text) from public,anon,authenticated;
revoke execute on function public.rebuild_organ_biomarker_map() from public,anon,authenticated;
revoke execute on function public.organ_overview(uuid) from public,anon;
revoke execute on function public.organ_history(uuid,text) from public,anon;
revoke execute on function public.organ_comparison(uuid,text) from public,anon;
grant execute on function public.organ_overview(uuid) to authenticated;
grant execute on function public.organ_history(uuid,text) to authenticated;
grant execute on function public.organ_comparison(uuid,text) to authenticated;

-- Re-evaluate existing subjects without mutating observations or prior states.
select public.compute_organ_states_all();

do $$ begin
  if (select count(*) from public.organs) <> 16 then
    raise exception 'organs seed incompleto: attese 16 righe';
  end if;
end $$;

insert into public.app_migrations(name) values('0009_body_sex_stress')
on conflict do nothing;