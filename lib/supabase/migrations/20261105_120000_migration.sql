-- Medical 24 - 0016 TASK REQUEST OPTIONS + SCRITTURE ADMIN (P09-GOV)
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- 1. ai_tasks.request_options: opzioni fuse nel corpo della richiesta al
--    modello (thinking, output_config.effort, ...). Sonnet 5.5 ragiona per
--    impostazione predefinita e i token di ragionamento contano nel
--    max_tokens: i task decidono quanto ragionare, dal pannello, senza deploy.
--    Seed: explain -> between_tools + effort medium; extract_values ->
--    between_tools + effort high; extract_classify (Haiku 5.5) nessuna
--    opzione finche' il supporto non e' verificato.
-- 2. ai_task_config espone request_options.
-- 3. ai_task_set / ai_model_set: le uniche vie di scrittura per il pannello
--    (admin), con validazione, audit e platform_event 'admin_action'.
-- 4. admin_ai_calls: elenco delle chiamate recenti dal ledger (nessun
--    contenuto clinico: il ledger non ne contiene).
-- Idempotente: puo' essere rieseguita senza effetti collaterali.

-- ---------------------------------------------------------------------------
-- 1. request_options
-- ---------------------------------------------------------------------------
alter table public.ai_tasks
  add column if not exists request_options jsonb not null default '{}'::jsonb;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'ai_tasks_request_options_object') then
    alter table public.ai_tasks add constraint ai_tasks_request_options_object
      check (jsonb_typeof(request_options) = 'object');
  end if;
end $$;

update public.ai_tasks
   set request_options = '{"thinking":{"type":"between_tools"},"output_config":{"effort":"medium"}}'::jsonb,
       updated_at = clock_timestamp()
 where id = 'explain' and request_options = '{}'::jsonb;

update public.ai_tasks
   set request_options = '{"thinking":{"type":"between_tools"},"output_config":{"effort":"high"}}'::jsonb,
       updated_at = clock_timestamp()
 where id = 'extract_values' and request_options = '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- 2. ai_task_config con request_options (stessa guardia della 0014)
-- ---------------------------------------------------------------------------
create or replace function public.ai_task_config(p_task text) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare r record; maintenance boolean;
begin
  if auth.role()<>'service_role' and auth.uid() is not null then raise exception 'not_allowed' using errcode='42501'; end if;
  select coalesce((value#>>'{}')::boolean,false) into maintenance from public.platform_settings where key='platform.maintenance_mode';
  select t.*,p.version,p.system_prompt,p.tool_schema,p.user_template,
    m.price_in_micro_usd_per_mtok,m.price_out_micro_usd_per_mtok,m.price_cached_in_micro_usd_per_mtok
  into r from public.ai_tasks t join public.ai_models m on m.id=t.model_id
    left join public.ai_prompts p on p.id=t.active_prompt_id where t.id=p_task;
  if not found then return null; end if;
  return jsonb_build_object('task',r.id,'model',r.model_id,'fallback_model',case when r.enabled_fallback then r.fallback_model_id end,
   'max_output_tokens',r.max_output_tokens,'enabled',r.enabled,
   'paused',coalesce(not r.enabled or maintenance or r.paused_until>now(),false),
   'maintenance',maintenance,'per_user_daily_limit',r.per_user_daily_limit,
   'request_options',coalesce(r.request_options,'{}'::jsonb),
   'prompt',jsonb_build_object(
   'id',r.active_prompt_id,'version',r.version,'system',r.system_prompt,'tool_schema',r.tool_schema,'user_template',r.user_template),
   'prices',jsonb_build_object('input',r.price_in_micro_usd_per_mtok,'output',r.price_out_micro_usd_per_mtok,'cached_input',r.price_cached_in_micro_usd_per_mtok));
end $$;

-- ---------------------------------------------------------------------------
-- 3a. ai_task_set: modifica controllata di un task (admin)
-- ---------------------------------------------------------------------------
create or replace function public.ai_task_set(p_task text, p_patch jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  t public.ai_tasks%rowtype;
  k text;
  v_allowed text[] := array['model_id','fallback_model_id','enabled_fallback','max_output_tokens','enabled',
    'daily_budget_micro_usd','budget_action','paused_until','per_user_daily_limit','requires_second_approval','request_options'];
begin
  if not public.has_role('admin') then raise exception 'not_allowed' using errcode='42501'; end if;
  if p_patch is null or jsonb_typeof(p_patch)<>'object' or p_patch='{}'::jsonb then
    raise exception 'invalid_patch' using errcode='22023';
  end if;
  for k in select jsonb_object_keys(p_patch) loop
    if not (k = any(v_allowed)) then
      raise exception 'invalid_patch_key: %', k using errcode='22023';
    end if;
  end loop;

  select * into t from public.ai_tasks where id=p_task for update;
  if not found then raise exception 'unknown_task' using errcode='22023'; end if;

  if p_patch ? 'model_id' then
    t.model_id := p_patch->>'model_id';
    if t.model_id is null or not exists(select 1 from public.ai_models m where m.id=t.model_id and m.status='active') then
      raise exception 'unknown_model' using errcode='22023';
    end if;
  end if;
  if p_patch ? 'fallback_model_id' then
    t.fallback_model_id := p_patch->>'fallback_model_id';
    if t.fallback_model_id is not null and not exists(select 1 from public.ai_models m where m.id=t.fallback_model_id and m.status='active') then
      raise exception 'unknown_model' using errcode='22023';
    end if;
  end if;
  if p_patch ? 'enabled_fallback' then t.enabled_fallback := coalesce((p_patch->>'enabled_fallback')::boolean,false); end if;
  if p_patch ? 'max_output_tokens' then
    t.max_output_tokens := (p_patch->>'max_output_tokens')::int;
    if t.max_output_tokens is null or t.max_output_tokens<=0 then raise exception 'invalid_max_output_tokens' using errcode='22023'; end if;
  end if;
  if p_patch ? 'enabled' then t.enabled := coalesce((p_patch->>'enabled')::boolean,true); end if;
  if p_patch ? 'daily_budget_micro_usd' then
    t.daily_budget_micro_usd := (p_patch->>'daily_budget_micro_usd')::bigint;
    if t.daily_budget_micro_usd<0 then raise exception 'invalid_budget' using errcode='22023'; end if;
  end if;
  if p_patch ? 'budget_action' then
    t.budget_action := p_patch->>'budget_action';
    if t.budget_action not in ('alert','pause') then raise exception 'invalid_budget_action' using errcode='22023'; end if;
  end if;
  if p_patch ? 'paused_until' then t.paused_until := (p_patch->>'paused_until')::timestamptz; end if;
  if p_patch ? 'per_user_daily_limit' then
    t.per_user_daily_limit := (p_patch->>'per_user_daily_limit')::int;
    if t.per_user_daily_limit<=0 then raise exception 'invalid_limit' using errcode='22023'; end if;
  end if;
  if p_patch ? 'requires_second_approval' then t.requires_second_approval := coalesce((p_patch->>'requires_second_approval')::boolean,false); end if;
  if p_patch ? 'request_options' then
    t.request_options := coalesce(p_patch->'request_options','{}'::jsonb);
    if jsonb_typeof(t.request_options)<>'object' then raise exception 'invalid_request_options' using errcode='22023'; end if;
  end if;

  update public.ai_tasks set
    model_id=t.model_id, fallback_model_id=t.fallback_model_id, enabled_fallback=t.enabled_fallback,
    max_output_tokens=t.max_output_tokens, enabled=t.enabled, daily_budget_micro_usd=t.daily_budget_micro_usd,
    budget_action=t.budget_action, paused_until=t.paused_until, per_user_daily_limit=t.per_user_daily_limit,
    requires_second_approval=t.requires_second_approval, request_options=t.request_options,
    updated_by=auth.uid(), updated_at=clock_timestamp()
  where id=p_task;

  insert into public.audit_log(actor_id,action,target_table) values(auth.uid(),'ai_task.set','ai_tasks');
  insert into public.platform_events(kind,source,status,details)
    values('admin_action',left(p_task,120),'ai_task.set',jsonb_build_object('actor',auth.uid(),'patch',p_patch));

  select * into t from public.ai_tasks where id=p_task;
  return to_jsonb(t);
end $$;

-- ---------------------------------------------------------------------------
-- 3b. ai_model_set: listino e stato dei modelli (admin). Crea se manca.
-- ---------------------------------------------------------------------------
create or replace function public.ai_model_set(p_id text, p_patch jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare
  m public.ai_models%rowtype;
  k text;
  v_allowed text[] := array['provider','display_name','price_in_micro_usd_per_mtok','price_out_micro_usd_per_mtok',
    'price_cached_in_micro_usd_per_mtok','context_window','status','notes'];
  v_new boolean := false;
begin
  if not public.has_role('admin') then raise exception 'not_allowed' using errcode='42501'; end if;
  if p_id is null or btrim(p_id)='' or p_patch is null or jsonb_typeof(p_patch)<>'object' or p_patch='{}'::jsonb then
    raise exception 'invalid_patch' using errcode='22023';
  end if;
  for k in select jsonb_object_keys(p_patch) loop
    if not (k = any(v_allowed)) then
      raise exception 'invalid_patch_key: %', k using errcode='22023';
    end if;
  end loop;

  select * into m from public.ai_models where id=p_id for update;
  if not found then
    v_new := true;
    m.id := p_id; m.status := 'active';
    if not (p_patch ? 'provider') or not (p_patch ? 'display_name') then
      raise exception 'provider_and_display_name_required' using errcode='22023';
    end if;
  end if;

  if p_patch ? 'provider' then m.provider := p_patch->>'provider'; end if;
  if p_patch ? 'display_name' then m.display_name := p_patch->>'display_name'; end if;
  if p_patch ? 'price_in_micro_usd_per_mtok' then m.price_in_micro_usd_per_mtok := (p_patch->>'price_in_micro_usd_per_mtok')::bigint; end if;
  if p_patch ? 'price_out_micro_usd_per_mtok' then m.price_out_micro_usd_per_mtok := (p_patch->>'price_out_micro_usd_per_mtok')::bigint; end if;
  if p_patch ? 'price_cached_in_micro_usd_per_mtok' then m.price_cached_in_micro_usd_per_mtok := (p_patch->>'price_cached_in_micro_usd_per_mtok')::bigint; end if;
  if p_patch ? 'context_window' then m.context_window := (p_patch->>'context_window')::int; end if;
  if p_patch ? 'status' then
    m.status := p_patch->>'status';
    if m.status not in ('active','deprecated') then raise exception 'invalid_status' using errcode='22023'; end if;
  end if;
  if p_patch ? 'notes' then m.notes := p_patch->>'notes'; end if;
  if m.price_in_micro_usd_per_mtok<0 or m.price_out_micro_usd_per_mtok<0 or m.price_cached_in_micro_usd_per_mtok<0 then
    raise exception 'invalid_price' using errcode='22023';
  end if;
  -- Un modello usato da un task non si puo' ritirare: prima si cambia il task.
  if m.status='deprecated' and exists(select 1 from public.ai_tasks t where t.model_id=m.id
       or (t.enabled_fallback and t.fallback_model_id=m.id)) then
    raise exception 'model_in_use' using errcode='P0001';
  end if;

  if v_new then
    insert into public.ai_models(id,provider,display_name,price_in_micro_usd_per_mtok,price_out_micro_usd_per_mtok,
      price_cached_in_micro_usd_per_mtok,context_window,status,notes,updated_by,updated_at)
    values(m.id,m.provider,m.display_name,m.price_in_micro_usd_per_mtok,m.price_out_micro_usd_per_mtok,
      m.price_cached_in_micro_usd_per_mtok,m.context_window,m.status,m.notes,auth.uid(),clock_timestamp());
  else
    update public.ai_models set provider=m.provider, display_name=m.display_name,
      price_in_micro_usd_per_mtok=m.price_in_micro_usd_per_mtok, price_out_micro_usd_per_mtok=m.price_out_micro_usd_per_mtok,
      price_cached_in_micro_usd_per_mtok=m.price_cached_in_micro_usd_per_mtok, context_window=m.context_window,
      status=m.status, notes=m.notes, updated_by=auth.uid(), updated_at=clock_timestamp()
    where id=p_id;
  end if;

  insert into public.audit_log(actor_id,action,target_table)
    values(auth.uid(),case when v_new then 'ai_model.create' else 'ai_model.set' end,'ai_models');
  insert into public.platform_events(kind,source,status,details)
    values('admin_action',left(p_id,120),case when v_new then 'ai_model.create' else 'ai_model.set' end,
           jsonb_build_object('actor',auth.uid(),'patch',p_patch));

  select * into m from public.ai_models where id=p_id;
  return to_jsonb(m);
end $$;

-- ---------------------------------------------------------------------------
-- 4. admin_ai_calls: chiamate recenti dal ledger
-- ---------------------------------------------------------------------------
create or replace function public.admin_ai_calls(p_from timestamptz,p_to timestamptz,p_task text default null,
  p_status text default null,p_limit int default 100,p_offset int default 0) returns setof jsonb
language plpgsql volatile security definer set search_path=public as $$
begin
  perform public.admin_read_audit('admin_ai_calls');
  return query select to_jsonb(l) from public.ai_usage_ledger l
   where l.called_at between p_from and p_to
     and (p_task is null or l.task_id=p_task)
     and (p_status is null or l.status=p_status)
   order by l.called_at desc limit least(greatest(p_limit,1),500) offset greatest(p_offset,0);
end $$;

-- ---------------------------------------------------------------------------
-- 5. Permessi
-- ---------------------------------------------------------------------------
revoke execute on function public.ai_task_set(text,jsonb), public.ai_model_set(text,jsonb),
  public.admin_ai_calls(timestamptz,timestamptz,text,text,int,int) from public, anon;
grant execute on function public.ai_task_set(text,jsonb), public.ai_model_set(text,jsonb),
  public.admin_ai_calls(timestamptz,timestamptz,text,text,int,int) to authenticated;

insert into public.app_migrations(name) values('0016_task_request_options') on conflict do nothing;