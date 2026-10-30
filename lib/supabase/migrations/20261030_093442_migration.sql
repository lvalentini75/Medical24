-- Medical 24 - 0011 RISKS AND PREVENTION (P05-A). Corretta il 30/10/2026:
-- la vista biomarker_series espone canonical_value, non value_num.
-- Deterministic draft board rules, append-only scores, prevention calendar,
-- questionnaires, recommendations and the three-level threshold resolver.

create extension if not exists "pgcrypto";

do $$ begin
  if not exists (select 1 from pg_type where typname='risk_level') then
    create type risk_level as enum ('low','medium','high');
  end if;
  if not exists (select 1 from pg_type where typname='recommendation_status') then
    create type recommendation_status as enum ('open','done','dismissed');
  end if;
  if not exists (select 1 from pg_type where typname='recommendation_origin') then
    create type recommendation_origin as enum ('rule','doctor');
  end if;
end $$;

-- The source files are drafts. They remain visible and executable for internal
-- verification, but are deliberately not marked active before board approval.
insert into public.rule_versions(type,version,status,notes,definition) values
('risk_score2','0.1-draft','draft','Board draft; validate against HeartScore before activation',
 '{"name":"SCORE2","region":"moderate","age_min":40,"age_max":69,"source":"ESC 2021 Eur Heart J 42:2439","app_levels_map":{"low_to_moderate":"low","high":"medium","very_high":"high"}}'),
('risk_findrisc','0.1-draft','draft','Board draft; validate before activation',
 '{"name":"FINDRISC","source":"Lindstrom and Tuomilehto, Diabetes Care 2003","app_levels_map":{"low":"low","slightly_elevated":"low","moderate":"medium","high":"high","very_high":"high"}}'),
('risk_ckd_epi_2021','0.1-draft','draft','Board draft; validate before activation',
 '{"name":"CKD-EPI 2021","source":"Inker et al. NEJM 2021","app_levels_map":{"G1":"low","G2":"low","G3a":"medium","G3b":"high","G4":"high","G5":"high"}}'),
('risk_fracture','0.1-draft','draft','Transparent checklist only; this is not FRAX',
 '{"name":"Fracture risk-factor checklist","external_tool":"https://frax.shef.ac.uk/FRAX/tool.aspx?country=11","levels":{"low":[0,2],"medium":[3,5],"high":[6,null]}}'),
('recommendation_calendar','0-draft','draft','Regional intervals must be confirmed by the board',
 '{"source":"doc/board/prevention_calendar.csv","locale_key":"recommendation_ + id","rows":18}'),
('threshold_safety','0-draft','draft','Safety limits come from biomarker_catalog and cannot be widened by an override',
 '{"source":"biomarker_catalog.safety_low/safety_high","rule":"doctor low cannot be below safety_low and doctor high cannot be above safety_high"}')
on conflict(type,version) do update set status=excluded.status,notes=excluded.notes,
  definition=excluded.definition;

create table if not exists public.risk_scores(
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null,
  family text not null check (family in ('cardiovascular','diabetes','kidney','fracture')),
  level risk_level not null,
  score numeric not null,
  score_unit text not null,
  inputs jsonb not null default '{}'::jsonb,
  factors jsonb not null default '[]'::jsonb,
  projection_12m jsonb,
  rule_version text not null,
  computed_at timestamptz not null default clock_timestamp()
);
create index if not exists idx_risk_scores_subject_family_time
  on public.risk_scores(subject_id,family,computed_at desc);

create or replace function public.risk_scores_append_only() returns trigger
language plpgsql as $$ begin
  raise exception 'risk_scores_append_only' using errcode='42501';
end $$;
drop trigger if exists trg_risk_scores_append_only on public.risk_scores;
create trigger trg_risk_scores_append_only before update or delete on public.risk_scores
  for each row execute function public.risk_scores_append_only();
revoke execute on function public.risk_scores_append_only() from public,anon,authenticated;

create or replace view public.latest_risk_scores with (security_invoker=true) as
select distinct on(subject_id,family) id,subject_id,family,level,score,score_unit,
  inputs,factors,projection_12m,rule_version,computed_at
from public.risk_scores order by subject_id,family,computed_at desc,id desc;

create table if not exists public.questionnaires(
  id text primary key,
  title_key text not null,
  definition jsonb not null default '{}'::jsonb,
  version text not null,
  status rule_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(id,version)
);
create table if not exists public.questionnaire_answers(
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null,
  questionnaire_id text not null references public.questionnaires(id) on delete restrict,
  answers jsonb not null,
  version text not null,
  submitted_at timestamptz not null default clock_timestamp(),
  created_at timestamptz not null default now()
);
create index if not exists idx_questionnaire_answers_subject_time
  on public.questionnaire_answers(subject_id,questionnaire_id,submitted_at desc);

insert into public.questionnaires(id,title_key,version,status,definition) values
('risk_baseline','riskQuestionnaireTitle','0.1-draft','draft',
 '{"questions":["smoker","waist_cm","physical_activity_30min_daily","vegetables_fruit_daily","antihypertensive_medication","history_high_glucose","family_diabetes","bmi","previous_fracture","parent_hip_fracture","glucocorticoids","rheumatoid_arthritis","secondary_osteoporosis","alcohol_3_units_daily","bmd_t_score"]}')
on conflict(id) do update set title_key=excluded.title_key,version=excluded.version,
  status=excluded.status,definition=excluded.definition;

create table if not exists public.prevention_calendar(
  id text primary key,
  name_it text not null,
  sex text not null check(sex in ('all','female','male')),
  age_min int not null check(age_min>=0),
  age_max int check(age_max is null or age_max>=age_min),
  interval_months int not null check(interval_months>=0),
  notes text,
  category text not null,
  organ_id text references public.organs(id) on delete restrict,
  status catalog_status not null default 'draft',
  board_version int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.prevention_calendar(id,name_it,sex,age_min,age_max,interval_months,notes,category,organ_id,status,board_version) values
('screening_mammografia','Mammografia','female',50,69,24,'Programma di screening organizzato del SSN (alcune Regioni 45-74). Fonte: Ministero della Salute, screening oncologici.','Esami','breast','draft',0),
('screening_cervice_pap','Pap test','female',25,29,36,'Programma di screening organizzato del SSN.','Esami','reproductive_f','draft',0),
('screening_cervice_hpv','Test HPV','female',30,64,60,'Programma di screening organizzato del SSN.','Esami','reproductive_f','draft',0),
('screening_colon','Ricerca del sangue occulto nelle feci','all',50,69,24,'Programma di screening organizzato del SSN (alcune Regioni 50-74).','Esami','gut','draft',0),
('pressione','Misurazione della pressione arteriosa','all',18,null,24,'Dai 40 anni ogni 12 mesi; con valori elevati come indicato dal medico. Fonte: linee guida ESC/ESH.','Controlli','heart','draft',0),
('lipidi','Profilo lipidico','all',20,null,60,'Piu spesso con fattori di rischio o terapia, secondo il medico. Fonte: ESC 2021.','Esami','heart','draft',0),
('glicemia','Glicemia a digiuno','all',45,null,36,'Prima e piu spesso con FINDRISC >= 12 o fattori di rischio. Fonte: SID/AMD, ADA.','Esami','metabolism','draft',0),
('peso_bmi','Peso e indice di massa corporea','all',18,null,12,null,'Controlli','metabolism','draft',0),
('vista','Visita oculistica','all',40,null,24,'Dai 65 anni ogni 12 mesi.','Visite','brain','draft',0),
('udito','Controllo dell''udito','all',65,null,24,null,'Visite','brain','draft',0),
('dentista','Visita odontoiatrica','all',18,null,12,null,'Visite','gut','draft',0),
('dermatologo','Controllo dei nei','all',18,null,12,'Piu spesso con familiarita o molti nei.','Visite','immune','draft',0),
('vaccino_influenza','Vaccino antinfluenzale','all',60,null,12,'Ogni autunno dai 60 anni e per le categorie a rischio. Fonte: Ministero della Salute.','Vaccini','immune','draft',0),
('vaccino_pneumococco','Vaccino antipneumococcico','all',65,null,0,'Una volta, secondo il calendario vaccinale nazionale.','Vaccini','lung','draft',0),
('vaccino_zoster','Vaccino contro l''herpes zoster','all',65,null,0,'Secondo il calendario vaccinale nazionale.','Vaccini','immune','draft',0),
('vaccino_tetano','Richiamo difterite-tetano-pertosse','all',18,null,120,'Ogni 10 anni.','Vaccini','immune','draft',0),
('psa','Valutazione del rischio prostatico con il medico','male',50,69,24,'Non e uno screening di popolazione: decisione condivisa con il medico.','Visite','prostate','draft',0),
('densitometria','Densitometria ossea (MOC)','female',65,null,24,'Prima in presenza di fattori di rischio; uomini dai 70 anni. Fonte: LEA, nota 79 AIFA.','Esami','musculoskeletal','draft',0),
('aaa','Ecografia dell''aorta addominale','male',65,75,0,'Una volta, se fumatore o ex fumatore; in Italia non e screening organizzato.','Esami','heart','draft',0)
on conflict(id) do update set name_it=excluded.name_it,sex=excluded.sex,
 age_min=excluded.age_min,age_max=excluded.age_max,interval_months=excluded.interval_months,
 notes=excluded.notes,category=excluded.category,organ_id=excluded.organ_id,
 status=excluded.status,board_version=excluded.board_version;

create table if not exists public.recommendations(
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null,
  calendar_id text references public.prevention_calendar(id) on delete restrict,
  title_key text not null,
  reason_key text,
  category text not null,
  organ_id text references public.organs(id) on delete restrict,
  interval_months int not null default 0,
  due_at date,
  status recommendation_status not null default 'open',
  origin recommendation_origin not null default 'rule',
  completed_at timestamptz,
  document_id uuid references public.documents(id) on delete set null,
  rule_version text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check((status='done' and completed_at is not null) or status<>'done')
);
create index if not exists idx_recommendations_subject_due
  on public.recommendations(subject_id,status,due_at);
create unique index if not exists idx_recommendations_one_open_calendar
  on public.recommendations(subject_id,calendar_id) where status='open' and calendar_id is not null;

create table if not exists public.threshold_overrides(
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references auth.users(id) on delete restrict,
  subject_id uuid,
  code text not null references public.biomarker_catalog(code) on delete restrict,
  low numeric,
  high numeric,
  unit text not null,
  reason text not null check(length(btrim(reason))>=3),
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  version int not null default 1 check(version>0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(low is not null or high is not null),
  check(low is null or high is null or low<high),
  check(valid_until is null or valid_until>valid_from)
);
create index if not exists idx_threshold_overrides_resolve
  on public.threshold_overrides(subject_id,code,valid_from desc);

create or replace function public.validate_threshold_override() returns trigger
language plpgsql security definer set search_path=public as $$
declare c record;
begin
  select * into c from public.biomarker_catalog where code=new.code;
  if not found then raise exception 'catalog_code_not_found' using errcode='P0001'; end if;
  if new.unit<>c.unit_canonical then raise exception 'override_unit_mismatch' using errcode='P0001'; end if;
  if c.safety_low is not null and (new.low is null or new.low<c.safety_low) then
    raise exception 'override_exceeds_safety_low' using errcode='P0001';
  end if;
  if c.safety_high is not null and (new.high is null or new.high>c.safety_high) then
    raise exception 'override_exceeds_safety_high' using errcode='P0001';
  end if;
  return new;
end $$;
drop trigger if exists trg_threshold_overrides_validate on public.threshold_overrides;
create trigger trg_threshold_overrides_validate before insert or update on public.threshold_overrides
  for each row execute function public.validate_threshold_override();
revoke execute on function public.validate_threshold_override() from public,anon,authenticated;

-- From 0011 onward future observations use the most specific valid doctor
-- interval, while immutable board safety limits keep absolute precedence.
create or replace function public.resolve_flag(p_subject_id uuid,p_code text,p_value numeric)
returns observation_flag language plpgsql stable security definer set search_path=public as $$
declare c record;v_gender text;lo numeric;hi numeric;lo_m numeric;hi_m numeric;
  lo_f numeric;hi_f numeric;in_m boolean;in_f boolean;below_m boolean;below_f boolean;
  above_m boolean;above_f boolean;
begin
  if p_value is null then return 'unknown'; end if;
  select * into c from public.biomarker_catalog where code=p_code;
  if not found then return 'unknown'; end if;
  if c.safety_low is not null and p_value<c.safety_low then return 'critical_low'; end if;
  if c.safety_high is not null and p_value>c.safety_high then return 'critical_high'; end if;
  select x.low,x.high into lo,hi from public.threshold_overrides x
   where x.code=p_code and (x.subject_id=p_subject_id or x.subject_id is null)
    and x.valid_from<=now() and (x.valid_until is null or x.valid_until>now())
   order by (x.subject_id is not null) desc,x.valid_from desc,x.id desc limit 1;
  if found then
    if lo is not null and p_value<lo then return 'below'; end if;
    if hi is not null and p_value>hi then return 'above'; end if;
    return 'within';
  end if;
  select gender into v_gender from public.profiles where id=p_subject_id;
  if v_gender in ('male','female') then
    if v_gender='male' then lo:=c.ref_low_m;hi:=c.ref_high_m;
    else lo:=c.ref_low_f;hi:=c.ref_high_f;end if;
    if lo is null and hi is null then return 'unknown'; end if;
    if lo is not null and p_value<lo then return 'below'; end if;
    if hi is not null and p_value>hi then return 'above'; end if;
    return 'within';
  end if;
  lo_m:=c.ref_low_m;hi_m:=c.ref_high_m;lo_f:=c.ref_low_f;hi_f:=c.ref_high_f;
  if lo_m is null and hi_m is null and lo_f is null and hi_f is null then return 'unknown'; end if;
  below_m:=lo_m is not null and p_value<lo_m;above_m:=hi_m is not null and p_value>hi_m;
  below_f:=lo_f is not null and p_value<lo_f;above_f:=hi_f is not null and p_value>hi_f;
  in_m:=(lo_m is not null or hi_m is not null) and not below_m and not above_m;
  in_f:=(lo_f is not null or hi_f is not null) and not below_f and not above_f;
  if in_m and in_f then return 'within'; end if;
  if below_m and below_f then return 'below'; end if;
  if above_m and above_f then return 'above'; end if;
  if lo_m is null and hi_m is null then
    if below_f then return 'below'; elsif above_f then return 'above'; else return 'within'; end if;
  end if;
  if lo_f is null and hi_f is null then
    if below_m then return 'below'; elsif above_m then return 'above'; else return 'within'; end if;
  end if;
  return 'unknown';
end $$;

-- SCORE2 moderate-risk region. Result is percent risk at ten years.
create or replace function public.score2_risk(p_age int,p_sex text,p_smoker boolean,
  p_sbp numeric,p_tc_mmol numeric,p_hdl_mmol numeric)
returns table(score numeric,level risk_level) language plpgsql immutable as $$
declare cage numeric;csbp numeric;ctc numeric;chdl numeric;x numeric;s0 numeric;
  scale1 numeric;scale2 numeric;u double precision;r numeric;raw text;
begin
  if p_age not between 40 and 69 or p_sex not in ('male','female') or
     p_smoker is null or p_sbp is null or p_tc_mmol is null or p_hdl_mmol is null then return; end if;
  cage:=(p_age-60.0)/5; csbp:=(p_sbp-120)/20; ctc:=p_tc_mmol-6; chdl:=(p_hdl_mmol-1.3)/0.5;
  if p_sex='male' then
    x:=0.3742*cage+0.6012*(p_smoker::int)+0.2777*csbp+0.1458*ctc-0.2698*chdl
      -0.0755*(p_smoker::int)*cage-0.0255*csbp*cage-0.0281*ctc*cage+0.0426*chdl*cage;
    s0:=0.9605;scale1:=-0.1565;scale2:=0.8009;
  else
    x:=0.4648*cage+0.7744*(p_smoker::int)+0.3131*csbp+0.1002*ctc-0.2606*chdl
      -0.1088*(p_smoker::int)*cage-0.0277*csbp*cage-0.0226*ctc*cage+0.0613*chdl*cage;
    s0:=0.9776;scale1:=-0.3143;scale2:=0.7761;
  end if;
  u:=1-power(s0::double precision,exp(x::double precision));
  r:=round((100*(1-exp(-exp(scale1::double precision+scale2::double precision*ln(-ln(1-u))))))::numeric,2);
  raw:=case when p_age<50 then case when r<2.5 then 'low' when r<7.5 then 'medium' else 'high' end
            else case when r<5 then 'low' when r<10 then 'medium' else 'high' end end;
  return query select r,raw::risk_level;
end $$;

create or replace function public.findrisc_score(p jsonb)
returns table(score numeric,level risk_level) language plpgsql immutable as $$
declare n int:=0;a int;b numeric;w numeric;s text;raw text;
begin
  a:=(p->>'age')::int;b:=(p->>'bmi')::numeric;w:=(p->>'waist_cm')::numeric;s:=p->>'sex';
  n:=n+case when a<45 then 0 when a<=54 then 2 when a<=64 then 3 else 4 end;
  n:=n+case when b<25 then 0 when b<=30 then 1 else 3 end;
  n:=n+case when s='male' then case when w<94 then 0 when w<=102 then 3 else 4 end
            else case when w<80 then 0 when w<=88 then 3 else 4 end end;
  if not coalesce((p->>'physical_activity_30min_daily')::boolean,false) then n:=n+2; end if;
  if not coalesce((p->>'vegetables_fruit_daily')::boolean,false) then n:=n+1; end if;
  if coalesce((p->>'antihypertensive_medication')::boolean,false) then n:=n+2; end if;
  if coalesce((p->>'history_high_glucose')::boolean,false) then n:=n+5; end if;
  n:=n+case p->>'family_diabetes' when 'second_degree' then 3 when 'first_degree' then 5 else 0 end;
  raw:=case when n<=11 then 'low' when n<=14 then 'medium' else 'high' end;
  return query select n::numeric,raw::risk_level;
exception when others then return;
end $$;

create or replace function public.ckd_epi_2021(p_scr numeric,p_age int,p_sex text)
returns table(score numeric,level risk_level) language plpgsql immutable as $$
declare k numeric;alpha numeric;r numeric;raw text;
begin
  if p_scr<=0 or p_age<=0 or p_sex not in ('male','female') then return; end if;
  if p_sex='female' then k:=0.7;alpha:=-0.241; else k:=0.9;alpha:=-0.302; end if;
  r:=round((142*power(least(p_scr/k,1)::double precision,alpha::double precision)
    *power(greatest(p_scr/k,1)::double precision,-1.2)*power(0.9938,p_age)
    *(case when p_sex='female' then 1.012 else 1 end))::numeric,1);
  raw:=case when r>=60 then 'low' when r>=45 then 'medium' else 'high' end;
  return query select r,raw::risk_level;
end $$;

create or replace function public.fracture_checklist_score(p jsonb)
returns table(score numeric,level risk_level) language plpgsql immutable as $$
declare n int:=0;a int;b numeric;t numeric;raw text;
begin
  a:=(p->>'age')::int;b:=(p->>'bmi')::numeric;t:=nullif(p->>'bmd_t_score','')::numeric;
  n:=n+case when a>=75 then 3 when a>=65 then 2 else 0 end;
  if p->>'sex'='female' then n:=n+1; end if;
  if b<19 then n:=n+1; end if;
  if coalesce((p->>'previous_fracture')::boolean,false) then n:=n+2; end if;
  if coalesce((p->>'parent_hip_fracture')::boolean,false) then n:=n+1; end if;
  if coalesce((p->>'current_smoker')::boolean,false) then n:=n+1; end if;
  if coalesce((p->>'glucocorticoids')::boolean,false) then n:=n+1; end if;
  if coalesce((p->>'rheumatoid_arthritis')::boolean,false) then n:=n+1; end if;
  if coalesce((p->>'secondary_osteoporosis')::boolean,false) then n:=n+1; end if;
  if coalesce((p->>'alcohol_3_units_daily')::boolean,false) then n:=n+1; end if;
  if t<=-2.5 then n:=n+3; elsif t<=-1 then n:=n+1; end if;
  raw:=case when n<=2 then 'low' when n<=5 then 'medium' else 'high' end;
  return query select n::numeric,raw::risk_level;
exception when others then return;
end $$;

create or replace function public.compute_risk_scores(p_subject uuid) returns int
language plpgsql security definer set search_path=public as $$
declare pr record;q jsonb:='{}';v_age int;v_sex text;v_score numeric;v_level risk_level;
  v_sbp numeric;v_tc numeric;v_hdl numeric;v_scr numeric;v_egfr numeric;v_written int:=0;
  v_inputs jsonb;v_projection jsonb;v_family text;v_unit text;v_version text;
begin
  if auth.uid() is not null and not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode='42501';
  end if;
  select gender,extract(year from age(current_date,birth_date))::int age into pr
    from public.profiles where id=p_subject and birth_date is not null;
  if not found or pr.gender not in ('male','female') then return 0; end if;
  v_age:=pr.age;v_sex:=pr.gender;
  select a.answers into q from public.questionnaire_answers a
    where a.subject_id=p_subject and a.questionnaire_id='risk_baseline'
    order by a.submitted_at desc,a.id desc limit 1;
  q:=coalesce(q,'{}'::jsonb)||jsonb_build_object('age',v_age,'sex',v_sex);

  select canonical_value into v_sbp from public.biomarker_series where subject_id=p_subject and code='8480-6'
    order by effective_at desc,observation_id desc limit 1;
  select canonical_value/38.67 into v_tc from public.biomarker_series where subject_id=p_subject and code='2093-3'
    order by effective_at desc,observation_id desc limit 1;
  select canonical_value/38.67 into v_hdl from public.biomarker_series where subject_id=p_subject and code='2085-9'
    order by effective_at desc,observation_id desc limit 1;
  if q ? 'smoker' and v_sbp is not null and v_tc is not null and v_hdl is not null then
    select * into v_score,v_level from public.score2_risk(v_age,v_sex,(q->>'smoker')::boolean,v_sbp,v_tc,v_hdl);
    if v_score is not null then
      select jsonb_build_object('score',x.score,'level',x.level) into v_projection
        from public.score2_risk(v_age+1,v_sex,(q->>'smoker')::boolean,v_sbp,v_tc,v_hdl)x;
      v_family:='cardiovascular';v_unit:='percent_10y';v_version:='risk_score2-0.1-draft';
      v_inputs:=jsonb_build_object('age',v_age,'sex',v_sex,'smoker',q->'smoker',
        'sbp',v_sbp,'tc_mmol',round(v_tc,3),'hdl_mmol',round(v_hdl,3));
      if not exists(select 1 from public.latest_risk_scores x where x.subject_id=p_subject
        and x.family=v_family and x.score=v_score and x.level=v_level and x.inputs=v_inputs
        and x.rule_version=v_version) then
        insert into public.risk_scores(subject_id,family,level,score,score_unit,inputs,factors,
          projection_12m,rule_version) values(p_subject,v_family,v_level,v_score,v_unit,v_inputs,
          '["age","sex","smoker","sbp","total_cholesterol","hdl"]',v_projection,v_version);
        v_written:=v_written+1;
      end if;
    end if;
  end if;

  if q ?& array['bmi','waist_cm','physical_activity_30min_daily','vegetables_fruit_daily',
    'antihypertensive_medication','history_high_glucose','family_diabetes'] then
    select * into v_score,v_level from public.findrisc_score(q);
    select jsonb_build_object('score',x.score,'level',x.level) into v_projection
      from public.findrisc_score(jsonb_set(q,'{age}',to_jsonb(v_age+1)))x;
    v_family:='diabetes';v_version:='risk_findrisc-0.1-draft';
    if v_score is not null and not exists(select 1 from public.latest_risk_scores x
      where x.subject_id=p_subject and x.family=v_family and x.score=v_score
      and x.level=v_level and x.inputs=q and x.rule_version=v_version) then
      insert into public.risk_scores(subject_id,family,level,score,score_unit,inputs,factors,
        projection_12m,rule_version) values(p_subject,v_family,v_level,v_score,'points',q,
        '["age","bmi","waist","activity","diet","blood_pressure_treatment","glucose_history","family_history"]',
        v_projection,v_version);v_written:=v_written+1;
    end if;
  end if;

  select canonical_value into v_egfr from public.biomarker_series where subject_id=p_subject and code='98979-8'
    order by effective_at desc,observation_id desc limit 1;
  select canonical_value into v_scr from public.biomarker_series where subject_id=p_subject and code='2160-0'
    order by effective_at desc,observation_id desc limit 1;
  if v_egfr is not null or v_scr is not null then
    if v_egfr is not null then
      v_score:=round(v_egfr,1);v_level:=case when v_score>=60 then 'low' when v_score>=45 then 'medium' else 'high' end;
      v_inputs:=jsonb_build_object('egfr_observed',v_score,'age',v_age,'sex',v_sex);
      v_projection:=null;
    else
      select * into v_score,v_level from public.ckd_epi_2021(v_scr,v_age,v_sex);
      select jsonb_build_object('score',x.score,'level',x.level) into v_projection
        from public.ckd_epi_2021(v_scr,v_age+1,v_sex)x;
      v_inputs:=jsonb_build_object('scr',v_scr,'age',v_age,'sex',v_sex);
    end if;
    v_family:='kidney';v_version:='risk_ckd_epi_2021-0.1-draft';
    if not exists(select 1 from public.latest_risk_scores x where x.subject_id=p_subject
      and x.family=v_family and x.score=v_score and x.level=v_level and x.inputs=v_inputs
      and x.rule_version=v_version) then
      insert into public.risk_scores(subject_id,family,level,score,score_unit,inputs,factors,
        projection_12m,rule_version) values(p_subject,v_family,v_level,v_score,'mL/min/{1.73_m2}',
        v_inputs,'["kidney_function","age","sex"]',v_projection,v_version);v_written:=v_written+1;
    end if;
  end if;

  if q ? 'bmi' then
    select * into v_score,v_level from public.fracture_checklist_score(q);
    select jsonb_build_object('score',x.score,'level',x.level) into v_projection
      from public.fracture_checklist_score(jsonb_set(q,'{age}',to_jsonb(v_age+1)))x;
    v_family:='fracture';v_version:='risk_fracture-0.1-draft';
    if v_score is not null and not exists(select 1 from public.latest_risk_scores x
      where x.subject_id=p_subject and x.family=v_family and x.score=v_score
      and x.level=v_level and x.inputs=q and x.rule_version=v_version) then
      insert into public.risk_scores(subject_id,family,level,score,score_unit,inputs,factors,
        projection_12m,rule_version) values(p_subject,v_family,v_level,v_score,'checklist_points',q,
        '["age","sex","bmi","fracture_factors","bmd"]',v_projection,v_version);v_written:=v_written+1;
    end if;
  end if;
  return v_written;
end $$;

create or replace function public.refresh_risk_scores_from_input() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if tg_table_name='questionnaire_answers' then perform public.compute_risk_scores(new.subject_id);
  elsif new.confirmed_at is not null and new.superseded_at is null then
    perform public.compute_risk_scores(new.subject_id);
  end if;
  return new;
end $$;
drop trigger if exists trg_questionnaire_answers_refresh_risks on public.questionnaire_answers;
create trigger trg_questionnaire_answers_refresh_risks after insert on public.questionnaire_answers
 for each row execute function public.refresh_risk_scores_from_input();
drop trigger if exists trg_observations_refresh_risks on public.observations;
create trigger trg_observations_refresh_risks after insert on public.observations
 for each row execute function public.refresh_risk_scores_from_input();
revoke execute on function public.refresh_risk_scores_from_input() from public,anon,authenticated;

create or replace function public.compute_risk_scores_all() returns int
language plpgsql security definer set search_path=public as $$
declare s record;n int:=0;
begin
  for s in select id from public.profiles where deleted_at is null loop
    n:=n+public.compute_risk_scores(s.id);
  end loop;
  return n;
end $$;
revoke execute on function public.compute_risk_scores_all() from public,anon,authenticated;

create or replace function public.resolve_thresholds(p_subject uuid,p_code text)
returns table(laboratory_low numeric,laboratory_high numeric,institutional_low numeric,
 institutional_high numeric,doctor_low numeric,doctor_high numeric,unit text,
 doctor_id uuid,doctor_reason text,board_version int)
language plpgsql stable security definer set search_path=public as $$
declare g text;
begin
  if not public.can_access_subject(p_subject) then raise exception 'not_allowed' using errcode='42501'; end if;
  select gender into g from public.profiles where id=p_subject;
  return query
  select o.lab_low,o.lab_high,
    case when g='female' then c.ref_low_f else c.ref_low_m end,
    case when g='female' then c.ref_high_f else c.ref_high_m end,
    d.low,d.high,c.unit_canonical,d.doctor_id,d.reason,c.board_version
  from public.biomarker_catalog c
  left join lateral(select x.lab_low,x.lab_high from public.observations x
    where x.subject_id=p_subject and x.code=p_code and x.superseded_at is null
    order by x.effective_at desc,x.id desc limit 1)o on true
  left join lateral(select x.low,x.high,x.doctor_id,x.reason from public.threshold_overrides x
    where x.code=p_code and (x.subject_id=p_subject or x.subject_id is null)
      and x.valid_from<=now() and (x.valid_until is null or x.valid_until>now())
    order by (x.subject_id is not null) desc,x.valid_from desc,x.id desc limit 1)d on true
  where c.code=p_code;
end $$;

create or replace function public.refresh_recommendations(p_subject uuid) returns int
language plpgsql security definer set search_path=public as $$
declare p record;c record;last_done timestamptz;v_due date;v_n int:=0;
begin
  if not public.can_access_subject(p_subject) then raise exception 'not_allowed' using errcode='42501'; end if;
  select gender,extract(year from age(current_date,birth_date))::int age into p
    from public.profiles where id=p_subject and birth_date is not null;
  if not found then return 0; end if;
  for c in select * from public.prevention_calendar x where x.status='draft'
    and (x.sex='all' or x.sex=p.gender) and p.age>=x.age_min
    and (x.age_max is null or p.age<=x.age_max) loop
    select max(completed_at) into last_done from public.recommendations r
      where r.subject_id=p_subject and r.calendar_id=c.id and r.status='done';
    if last_done is not null and c.interval_months=0 then continue; end if;
    v_due:=case when last_done is null then current_date
      else (last_done+make_interval(months=>c.interval_months))::date end;
    if not exists(select 1 from public.recommendations r where r.subject_id=p_subject
      and r.calendar_id=c.id and r.status='open') then
      insert into public.recommendations(subject_id,calendar_id,title_key,reason_key,category,
        organ_id,interval_months,due_at,rule_version)
      values(p_subject,c.id,'recommendation_'||c.id,'recommendation_'||c.id||'_reason',
        c.category,c.organ_id,c.interval_months,v_due,'recommendation_calendar-0-draft');
      v_n:=v_n+1;
    end if;
  end loop;
  return v_n;
end $$;

create or replace function public.complete_recommendation(p_id uuid,p_document uuid default null)
returns void language plpgsql security definer set search_path=public as $$
declare s uuid;
begin
  select subject_id into s from public.recommendations where id=p_id and status='open';
  if s is null or not public.can_access_subject(s) then raise exception 'not_allowed' using errcode='42501'; end if;
  if p_document is not null and not exists(select 1 from public.documents d
    where d.id=p_document and d.subject_id=s and d.deleted_at is null) then
    raise exception 'invalid_document' using errcode='P0001';
  end if;
  update public.recommendations set status='done',completed_at=now(),document_id=p_document where id=p_id;
  perform public.refresh_recommendations(s);
end $$;

create or replace function public.audit_threshold_override() returns trigger
language plpgsql security definer set search_path=public as $$
declare r public.threshold_overrides%rowtype;
begin
  r:=case when tg_op='DELETE' then old else new end;
  insert into public.audit_log(actor_id,action,target_table,target_id,subject_id)
  values(auth.uid(),'threshold_override_'||lower(tg_op),'threshold_overrides',r.id,r.subject_id);
  return case when tg_op='DELETE' then old else new end;
end $$;
drop trigger if exists trg_threshold_overrides_audit on public.threshold_overrides;
create trigger trg_threshold_overrides_audit after insert or update or delete on public.threshold_overrides
  for each row execute function public.audit_threshold_override();
revoke execute on function public.audit_threshold_override() from public,anon,authenticated;

-- RLS: global board content is read-only; clinical rows always use the single
-- subject access helper. Doctor writes remain closed until P12 creates links.
alter table public.risk_scores enable row level security;
alter table public.questionnaires enable row level security;
alter table public.questionnaire_answers enable row level security;
alter table public.prevention_calendar enable row level security;
alter table public.recommendations enable row level security;
alter table public.threshold_overrides enable row level security;
alter table public.risk_scores force row level security;
alter table public.questionnaires force row level security;
alter table public.questionnaire_answers force row level security;
alter table public.prevention_calendar force row level security;
alter table public.recommendations force row level security;
alter table public.threshold_overrides force row level security;

drop policy if exists risk_scores_select on public.risk_scores;
create policy risk_scores_select on public.risk_scores for select to authenticated
 using(public.can_access_subject(subject_id));
drop policy if exists questionnaires_select on public.questionnaires;
create policy questionnaires_select on public.questionnaires for select to authenticated using(true);
drop policy if exists questionnaires_write on public.questionnaires;
create policy questionnaires_write on public.questionnaires for all to authenticated
 using(public.has_role('board') or public.has_role('admin'))
 with check(public.has_role('board') or public.has_role('admin'));
drop policy if exists questionnaire_answers_select on public.questionnaire_answers;
create policy questionnaire_answers_select on public.questionnaire_answers for select to authenticated
 using(public.can_access_subject(subject_id));
drop policy if exists questionnaire_answers_insert on public.questionnaire_answers;
create policy questionnaire_answers_insert on public.questionnaire_answers for insert to authenticated
 with check(public.can_access_subject(subject_id));
drop policy if exists prevention_calendar_select on public.prevention_calendar;
create policy prevention_calendar_select on public.prevention_calendar for select to authenticated using(true);
drop policy if exists prevention_calendar_write on public.prevention_calendar;
create policy prevention_calendar_write on public.prevention_calendar for all to authenticated
 using(public.has_role('board') or public.has_role('admin'))
 with check(public.has_role('board') or public.has_role('admin'));
drop policy if exists recommendations_select on public.recommendations;
create policy recommendations_select on public.recommendations for select to authenticated
 using(public.can_access_subject(subject_id));
drop policy if exists threshold_overrides_select on public.threshold_overrides;
create policy threshold_overrides_select on public.threshold_overrides for select to authenticated
 using((subject_id is not null and public.can_access_subject(subject_id)) or doctor_id=auth.uid());
drop policy if exists threshold_overrides_board_write on public.threshold_overrides;
create policy threshold_overrides_board_write on public.threshold_overrides for all to authenticated
 using(public.has_role('board') or public.has_role('admin'))
 with check(public.has_role('board') or public.has_role('admin'));

revoke all on public.risk_scores,public.questionnaires,public.questionnaire_answers,
 public.prevention_calendar,public.recommendations,public.threshold_overrides from anon;
grant select on public.risk_scores,public.latest_risk_scores,public.questionnaires,
 public.questionnaire_answers,public.prevention_calendar,public.recommendations,
 public.threshold_overrides to authenticated;
grant insert on public.questionnaire_answers to authenticated;
grant insert,update,delete on public.questionnaires,public.prevention_calendar,
 public.threshold_overrides to authenticated;
revoke insert,update,delete on public.risk_scores,public.recommendations from authenticated;

revoke execute on function public.score2_risk(int,text,boolean,numeric,numeric,numeric),
 public.findrisc_score(jsonb),public.ckd_epi_2021(numeric,int,text),
 public.fracture_checklist_score(jsonb),public.compute_risk_scores(uuid),public.resolve_thresholds(uuid,text),
 public.refresh_recommendations(uuid),public.complete_recommendation(uuid,uuid) from public,anon;
grant execute on function public.score2_risk(int,text,boolean,numeric,numeric,numeric),
 public.findrisc_score(jsonb),public.ckd_epi_2021(numeric,int,text),
 public.fracture_checklist_score(jsonb),public.compute_risk_scores(uuid),public.resolve_thresholds(uuid,text),
 public.refresh_recommendations(uuid),public.complete_recommendation(uuid,uuid) to authenticated;

do $$ begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    perform cron.unschedule(jobid) from cron.job where jobname='medical24-risk-scores-nightly';
    perform cron.schedule('medical24-risk-scores-nightly','35 4 * * *',
      'select public.compute_risk_scores_all();');
  end if;
exception when undefined_table or invalid_schema_name then null;
end $$;

insert into public.app_migrations(name) values('0011_risks_prevention') on conflict do nothing;