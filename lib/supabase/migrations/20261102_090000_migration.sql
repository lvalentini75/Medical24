-- Medical 24 - 0012 RISK RECOMMENDATIONS (P05-A2).
-- Completa la 0011: ignora/riapri una raccomandazione, raccomandazioni derivate
-- dai punteggi di rischio, soglie del medico risolte lato per lato.
-- Idempotente: puo essere rieseguita senza effetti collaterali.

-- 1. Colonne nuove su recommendations ---------------------------------------
alter table public.recommendations add column if not exists code text;
alter table public.recommendations add column if not exists dismissed_at timestamptz;
alter table public.recommendations add column if not exists dismiss_reason text;

-- Una sola raccomandazione aperta per codice derivato (origine punteggi).
create unique index if not exists idx_recommendations_one_open_code
  on public.recommendations(subject_id,code)
  where status='open' and calendar_id is null and code is not null;

-- 2. Regole versionate -------------------------------------------------------
update public.rule_versions
   set definition=jsonb_set(definition,'{rows}','19'::jsonb)
 where type='recommendation_calendar' and version='0-draft';

insert into public.rule_versions(type,version,status,notes,definition) values
('recommendation_risk','0-draft','draft',
 'Raccomandazioni derivate dai punteggi; intervalli da confermare dal board',
 '{"source":"latest_risk_scores","locale_key":"recommendation_ + code","dismiss_cooldown_months_when_interval_zero":12,
   "map":[
    {"family":"diabetes","levels":["medium","high"],"code":"glicemia_findrisc","category":"Esami","organ_id":"metabolism","interval_months":12},
    {"family":"cardiovascular","levels":["high"],"code":"lipidi_score2","category":"Esami","organ_id":"heart","interval_months":12},
    {"family":"cardiovascular","levels":["high"],"code":"visita_cardiologica_score2","category":"Visite","organ_id":"heart","interval_months":0},
    {"family":"kidney","levels":["high"],"code":"visita_nefrologica_egfr","category":"Visite","organ_id":"kidney","interval_months":0},
    {"family":"kidney","levels":["medium"],"code":"creatinina_egfr","category":"Esami","organ_id":"kidney","interval_months":6},
    {"family":"fracture","levels":["high"],"code":"densitometria_frattura","category":"Esami","organ_id":"musculoskeletal","interval_months":0}],
   "closed_when_level_improves":"recommendation_level_improved"}')
on conflict(type,version) do update set status=excluded.status,notes=excluded.notes,
  definition=excluded.definition;

-- 3. Override del medico: un solo lato e ammesso -----------------------------
-- I limiti di sicurezza del catalogo restano assoluti, ma vengono verificati
-- solo sul lato effettivamente impostato: l'altro lato torna al riferimento
-- istituzionale in resolve_flag e in resolve_thresholds.
create or replace function public.validate_threshold_override() returns trigger
language plpgsql security definer set search_path=public as $$
declare c record;
begin
  select * into c from public.biomarker_catalog where code=new.code;
  if not found then raise exception 'catalog_code_not_found' using errcode='P0001'; end if;
  if new.unit<>c.unit_canonical then raise exception 'override_unit_mismatch' using errcode='P0001'; end if;
  if new.low is not null and c.safety_low is not null and new.low<c.safety_low then
    raise exception 'override_exceeds_safety_low' using errcode='P0001';
  end if;
  if new.high is not null and c.safety_high is not null and new.high>c.safety_high then
    raise exception 'override_exceeds_safety_high' using errcode='P0001';
  end if;
  return new;
end $$;
revoke execute on function public.validate_threshold_override() from public,anon,authenticated;

create or replace function public.resolve_flag(p_subject_id uuid,p_code text,p_value numeric)
returns observation_flag language plpgsql stable security definer set search_path=public as $$
declare c record;v_gender text;lo numeric;hi numeric;lo_m numeric;hi_m numeric;
  lo_f numeric;hi_f numeric;in_m boolean;in_f boolean;below_m boolean;below_f boolean;
  above_m boolean;above_f boolean;ov_lo numeric;ov_hi numeric;inst_lo numeric;inst_hi numeric;
begin
  if p_value is null then return 'unknown'; end if;
  select * into c from public.biomarker_catalog where code=p_code;
  if not found then return 'unknown'; end if;
  if c.safety_low is not null and p_value<c.safety_low then return 'critical_low'; end if;
  if c.safety_high is not null and p_value>c.safety_high then return 'critical_high'; end if;
  select gender into v_gender from public.profiles where id=p_subject_id;
  select x.low,x.high into ov_lo,ov_hi from public.threshold_overrides x
   where x.code=p_code and (x.subject_id=p_subject_id or x.subject_id is null)
    and x.valid_from<=now() and (x.valid_until is null or x.valid_until>now())
   order by (x.subject_id is not null) desc,x.valid_from desc,x.id desc limit 1;
  if found then
    if v_gender='male' then inst_lo:=c.ref_low_m;inst_hi:=c.ref_high_m;
    elsif v_gender='female' then inst_lo:=c.ref_low_f;inst_hi:=c.ref_high_f;
    else inst_lo:=least(c.ref_low_m,c.ref_low_f);inst_hi:=greatest(c.ref_high_m,c.ref_high_f);
    end if;
    lo:=coalesce(ov_lo,inst_lo);hi:=coalesce(ov_hi,inst_hi);
    if lo is null and hi is null then return 'unknown'; end if;
    if lo is not null and p_value<lo then return 'below'; end if;
    if hi is not null and p_value>hi then return 'above'; end if;
    return 'within';
  end if;
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

-- 4. Ignora e riapri una raccomandazione -------------------------------------
create or replace function public.dismiss_recommendation(p_id uuid,p_reason text default null)
returns void language plpgsql security definer set search_path=public as $$
declare s uuid;
begin
  select subject_id into s from public.recommendations where id=p_id and status='open';
  if s is null or not public.can_access_subject(s) then
    raise exception 'not_allowed' using errcode='42501';
  end if;
  update public.recommendations
     set status='dismissed',dismissed_at=now(),
         dismiss_reason=nullif(btrim(coalesce(p_reason,'')),''),updated_at=now()
   where id=p_id;
  insert into public.audit_log(actor_id,action,target_table,target_id,subject_id)
  values(auth.uid(),'recommendation_dismissed','recommendations',p_id,s);
end $$;

create or replace function public.reopen_recommendation(p_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare s uuid;
begin
  select subject_id into s from public.recommendations where id=p_id and status='dismissed';
  if s is null or not public.can_access_subject(s) then
    raise exception 'not_allowed' using errcode='42501';
  end if;
  update public.recommendations
     set status='open',dismissed_at=null,dismiss_reason=null,completed_at=null,updated_at=now()
   where id=p_id;
  insert into public.audit_log(actor_id,action,target_table,target_id,subject_id)
  values(auth.uid(),'recommendation_reopened','recommendations',p_id,s);
end $$;

-- 5. refresh_recommendations: calendario + punteggi --------------------------
-- Una raccomandazione ignorata dall'utente non torna prima della sua cadenza
-- (12 mesi quando interval_months = 0). Le raccomandazioni derivate dai
-- punteggi si chiudono da sole quando il livello migliora.
create or replace function public.refresh_recommendations(p_subject uuid) returns int
language plpgsql security definer set search_path=public as $$
declare p record;c record;d record;last_done timestamptz;last_dismissed timestamptz;
  v_due date;v_n int:=0;v_codes text[];
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
    select max(dismissed_at) into last_dismissed from public.recommendations r
      where r.subject_id=p_subject and r.calendar_id=c.id and r.status='dismissed'
        and r.dismissed_at is not null;
    if last_dismissed is not null and now() < last_dismissed
       + make_interval(months=>case when c.interval_months=0 then 12 else c.interval_months end) then
      continue;
    end if;
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

  select coalesce(array_agg(distinct m.code),'{}'::text[]) into v_codes
  from public.latest_risk_scores s
  join (values
    ('diabetes','medium','glicemia_findrisc','Esami','metabolism',12),
    ('diabetes','high','glicemia_findrisc','Esami','metabolism',12),
    ('cardiovascular','high','lipidi_score2','Esami','heart',12),
    ('cardiovascular','high','visita_cardiologica_score2','Visite','heart',0),
    ('kidney','high','visita_nefrologica_egfr','Visite','kidney',0),
    ('kidney','medium','creatinina_egfr','Esami','kidney',6),
    ('fracture','high','densitometria_frattura','Esami','musculoskeletal',0)
  ) m(family,level,code,category,organ_id,interval_months)
    on m.family=s.family and m.level=s.level::text
  where s.subject_id=p_subject;

  -- il livello e migliorato: la raccomandazione aperta derivata si chiude
  update public.recommendations r
     set status='dismissed',reason_key='recommendation_level_improved',updated_at=now()
   where r.subject_id=p_subject and r.status='open' and r.calendar_id is null
     and r.origin='rule' and r.code is not null and not (r.code = any(v_codes));

  for d in
    select distinct m.code,m.category,m.organ_id,m.interval_months
    from public.latest_risk_scores s
    join (values
      ('diabetes','medium','glicemia_findrisc','Esami','metabolism',12),
      ('diabetes','high','glicemia_findrisc','Esami','metabolism',12),
      ('cardiovascular','high','lipidi_score2','Esami','heart',12),
      ('cardiovascular','high','visita_cardiologica_score2','Visite','heart',0),
      ('kidney','high','visita_nefrologica_egfr','Visite','kidney',0),
      ('kidney','medium','creatinina_egfr','Esami','kidney',6),
      ('fracture','high','densitometria_frattura','Esami','musculoskeletal',0)
    ) m(family,level,code,category,organ_id,interval_months)
      on m.family=s.family and m.level=s.level::text
    where s.subject_id=p_subject
  loop
    if exists(select 1 from public.recommendations r where r.subject_id=p_subject
      and r.calendar_id is null and r.code=d.code and r.status='open') then continue; end if;
    select max(dismissed_at) into last_dismissed from public.recommendations r
      where r.subject_id=p_subject and r.calendar_id is null and r.code=d.code
        and r.status='dismissed' and r.dismissed_at is not null;
    if last_dismissed is not null and now() < last_dismissed
       + make_interval(months=>case when d.interval_months=0 then 12 else d.interval_months end) then
      continue;
    end if;
    select max(completed_at) into last_done from public.recommendations r
      where r.subject_id=p_subject and r.calendar_id is null and r.code=d.code and r.status='done';
    if last_done is not null and d.interval_months=0 then continue; end if;
    v_due:=case when last_done is null then current_date
      else (last_done+make_interval(months=>d.interval_months))::date end;
    insert into public.recommendations(subject_id,calendar_id,code,title_key,reason_key,category,
      organ_id,interval_months,due_at,origin,rule_version)
    values(p_subject,null,d.code,'recommendation_'||d.code,'recommendation_'||d.code,
      d.category,d.organ_id,d.interval_months,v_due,'rule','recommendation_risk-0-draft');
    v_n:=v_n+1;
  end loop;

  return v_n;
end $$;

-- 6. Permessi ----------------------------------------------------------------
revoke execute on function public.dismiss_recommendation(uuid,text),
 public.reopen_recommendation(uuid),public.refresh_recommendations(uuid) from public,anon;
grant execute on function public.dismiss_recommendation(uuid,text),
 public.reopen_recommendation(uuid),public.refresh_recommendations(uuid) to authenticated;

insert into public.app_migrations(name) values('0012_risk_recommendations') on conflict do nothing;
