-- Medical 24 - pgTAP 0014 platform control plane. Dev only; fixtures rollback.
--
-- Revisione Tattica Web (2026-10-30) sul test dell'agente:
--   T1  colonne dei prezzi: price_in_/price_out_micro_usd_per_mtok (non input_/output_)
--   T2  ai_tasks.model_id (non model)
--   T3  costo di ai_log_call: 1000 in + 100 out su Haiku 5.5 = 150 micro-USD (non 150 milioni)
--   T4  conteggio impostazioni: le otto chiavi seed per nome (la fixture ne aggiunge una)
--   T5  plan(N) allineato alle asserzioni (erano 42 su 43 dichiarate)
--   T6  tabella temporanea creata da postgres e concessa a authenticated
--   T7  aggiunte: prezzo cache (R2), soglia auto_confirm (R5), storico
--       impostazioni, vista giornaliera, nessuna scrittura diretta,
--       ai_task_config negata all'utente, test obbligatorio prima
--       dell'attivazione, seconda approvazione non richiesta per extract_values
begin;
create extension if not exists pgtap with schema extensions;
select plan(59);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('91111111-1111-4111-8111-111111111111','00000000-0000-0000-0000-000000000000','authenticated','authenticated','user14@example.com','',now(),'{}','{}',now(),now()),
('92222222-2222-4222-8222-222222222222','00000000-0000-0000-0000-000000000000','authenticated','authenticated','admin14a@example.com','',now(),'{}','{}',now(),now()),
('93333333-3333-4333-8333-333333333333','00000000-0000-0000-0000-000000000000','authenticated','authenticated','admin14b@example.com','',now(),'{}','{}',now(),now())
on conflict(id) do nothing;
insert into public.user_roles(user_id,role) values
('92222222-2222-4222-8222-222222222222','admin'),('93333333-3333-4333-8333-333333333333','admin')
on conflict(user_id,role) do nothing;
insert into public.platform_settings(key,value,is_public,description)
values('private.test','true',false,'test') on conflict(key) do update set is_public=false;
create temp table prompt_ids(id uuid);
grant all on prompt_ids to authenticated;

-- ---------------------------------------------------------------------------
-- Struttura e seed
-- ---------------------------------------------------------------------------
select has_table('public','ai_models','ai_models exists');
select has_table('public','ai_tasks','ai_tasks exists');
select has_table('public','ai_prompts','ai_prompts exists');
select has_table('public','ai_usage_ledger','ledger exists');
select has_table('public','platform_settings','settings exists');
select has_table('public','platform_settings_history','settings history exists');
select has_table('public','platform_events','events exists');
select ok((select bool_and(relrowsecurity and relforcerowsecurity) from pg_class where oid in
 ('public.ai_models'::regclass,'public.ai_tasks'::regclass,'public.ai_prompts'::regclass,
  'public.ai_usage_ledger'::regclass,'public.platform_settings'::regclass,
  'public.platform_settings_history'::regclass,'public.platform_events'::regclass)),
 'all control tables have forced RLS');
select is((select count(*)::int from public.app_migrations where name='0014_platform_control_plane'),1,'0014 registered');
select is((select price_in_micro_usd_per_mtok from public.ai_models where id='claude-haiku-5-5'),100000::bigint,'haiku seed input price');
select is((select price_out_micro_usd_per_mtok from public.ai_models where id='claude-sonnet-5-5'),10000000::bigint,'sonnet seed output price');
select is((select price_cached_in_micro_usd_per_mtok from public.ai_models where id='claude-sonnet-5-5'),200000::bigint,'sonnet seed cached input price');
select is((select model_id from public.ai_tasks where id='extract_values'),'claude-sonnet-5-5','extract task uses revised model');
select is((select model_id from public.ai_tasks where id='extract_classify'),'claude-haiku-5-5','classify task uses small model');
select is((select count(*)::int from public.platform_settings where key in
 ('limits.free_analyses_per_month','limits.explanations_per_day','limits.free_documents','features.explain_enabled',
  'features.body_enabled','platform.maintenance_mode','platform.maintenance_message_key','extraction.auto_confirm_confidence')),
 8,'eight seed settings present');
select is((select value from public.platform_settings where key='extraction.auto_confirm_confidence'),'0.85'::jsonb,'auto_confirm threshold seeded at 0.85');
select is((select is_public from public.platform_settings where key='extraction.auto_confirm_confidence'),false,'auto_confirm threshold is not public');
select is((select count(*)::int from public.ai_prompts where status='active'),3,'one active prompt per task');

-- ---------------------------------------------------------------------------
-- Utente normale: niente letture dirette, solo impostazioni pubbliche
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
select is((select count(*)::int from public.ai_models),0,'normal user reads zero models');
select is((select count(*)::int from public.ai_tasks),0,'normal user reads zero tasks');
select is((select count(*)::int from public.ai_prompts),0,'normal user reads zero prompts');
select is((select count(*)::int from public.ai_usage_ledger),0,'normal user reads zero ledger rows');
select is((select count(*)::int from public.ai_usage_daily),0,'normal user reads zero daily usage rows');
select is((select count(*)::int from public.platform_settings),0,'normal user reads zero settings rows');
select is((select count(*)::int from public.platform_settings_history),0,'normal user reads zero setting history');
select is((select count(*)::int from public.platform_events),0,'normal user reads zero events');
select throws_ok($$select public.admin_overview()$$,'42501','not_allowed','normal user cannot call admin reads');
select throws_ok($$select public.ai_task_config('explain')$$,'42501',null,'normal user cannot call ai_task_config (execute revoked)');
select throws_ok($$select public.platform_setting_set('x.y','1'::jsonb)$$,'42501','not_allowed','normal user cannot change settings');
select is(public.platform_setting('limits.free_documents'),'30'::jsonb,'normal user reads public setting');
select throws_ok($$select public.platform_setting('private.test')$$,'42501','not_allowed','normal user cannot read private setting');

-- Nota: anon non ha ancora execute su platform_setting (lo concede la 0015,
-- insieme al test "anon legge solo le impostazioni pubbliche").

-- ---------------------------------------------------------------------------
-- Admin: letture, impostazioni, nessuna scrittura diretta
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"92222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
select ok((select count(*) from public.ai_models)>0,'admin reads models');
select ok((select count(*) from public.ai_tasks)=3,'admin reads seeded tasks');
select is(public.platform_setting('private.test'),'true'::jsonb,'admin reads private setting');
select is(public.analysis_limit(auth.uid()),30,'analysis_limit reads the setting');
select lives_ok($$select public.platform_setting_set('limits.free_analyses_per_month','31','test')$$,'admin changes setting');
select is(public.analysis_limit(auth.uid()),31,'analysis_limit sees changed setting');
select is((select count(*)::int from public.platform_settings_history where key='limits.free_analyses_per_month'),2,'setting change is kept in history');
select throws_ok($$insert into public.ai_models(id,provider,display_name) values('x','y','z')$$,'42501',null,'admin cannot write ai_models directly');
select throws_ok($$update public.ai_tasks set enabled=false where id='explain'$$,'42501',null,'admin cannot write ai_tasks directly');

-- ---------------------------------------------------------------------------
-- Ledger, costi e budget (contesto interno: nessun JWT)
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
select is((select cost_micro_usd from public.ai_log_call('extract_classify','claude-haiku-5-5','test',null,'test','ok',null,1000,100,0,10,'r1')),
  150::bigint,'ai_log_call calculates cost from model price list (1000 in + 100 out on haiku = 150 micro-USD)');
select is((select cost_micro_usd from public.ai_log_call('extract_values','claude-sonnet-5-5','test',null,'test','ok',null,10000,500,8000,10,'r2')),
  10600::bigint,'ai_log_call bills cached input tokens at the cached price');
update public.ai_tasks set daily_budget_micro_usd=1,budget_action='pause',paused_until=null where id='extract_classify';
do $$ begin perform public.ai_log_call('extract_classify','claude-haiku-5-5','test',null,'test','ok',null,1,0,0,1,'pause'); end $$;
select ok((public.ai_task_config('extract_classify')->>'paused')::boolean,'budget action pause pauses task config');
select is((select count(*)::int from public.platform_events where source='extract_classify' and kind='ai_task_paused'),1,'pause event emitted');
update public.ai_tasks set daily_budget_micro_usd=1,budget_action='alert',paused_until=null where id='extract_classify';
delete from public.platform_events where source='extract_classify' and kind='ai_budget_alert';
do $$ begin
  perform public.ai_log_call('extract_classify','claude-haiku-5-5','test',null,'test','ok',null,1,0,0,1,'a1');
  perform public.ai_log_call('extract_classify','claude-haiku-5-5','test',null,'test','ok',null,1,0,0,1,'a2');
end $$;
select is((select count(*)::int from public.platform_events where source='extract_classify' and kind='ai_budget_alert'),1,'budget alert is emitted once per day');
select ok((select count(*) from public.ai_usage_daily where task_id='extract_classify')>0,'daily usage view aggregates the ledger');

-- ---------------------------------------------------------------------------
-- Prompt: creazione, seconda approvazione, test, attivazione, rollback
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"92222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
insert into prompt_ids select public.ai_prompt_create('explain','test system','{}','test {{subject_data}}','test');
select throws_ok(format('select public.ai_prompt_activate(%L)',(select id from prompt_ids limit 1)),'42501','approval_required','unapproved prompt cannot activate');
select throws_ok(format('select public.ai_prompt_approve(%L)',(select id from prompt_ids limit 1)),'42501','second_approver_required','creator cannot self-approve explain prompt');
reset role;
select set_config('request.jwt.claims','{"sub":"93333333-3333-4333-8333-333333333333","role":"authenticated"}',true);
set local role authenticated;
select lives_ok(format('select public.ai_prompt_approve(%L)',(select id from prompt_ids limit 1)),'second admin approves');
select throws_ok(format('select public.ai_prompt_activate(%L)',(select id from prompt_ids limit 1)),'P0001','passing_test_required','approved prompt without passing test cannot activate');
reset role; select set_config('request.jwt.claims','',true);
select public.ai_prompt_record_test((select id from prompt_ids limit 1),'{"passed":true,"cases":3}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"93333333-3333-4333-8333-333333333333","role":"authenticated"}',true);
select lives_ok(format('select public.ai_prompt_activate(%L)',(select id from prompt_ids limit 1)),'approved and tested prompt activates');
select is((select status from public.ai_prompts where id=(select id from prompt_ids limit 1)),'active','new prompt is active');
select is((select status from public.ai_prompts where task_id='explain' and version='explain-2026-10-30'),'retired','previous prompt is retired');

-- Rollback uses the most recently retired prompt for the task.
select lives_ok($$select public.ai_prompt_rollback('explain')$$,'prompt rollback works');
select is((select version from public.ai_prompts where id=(select active_prompt_id from public.ai_tasks where id='explain')),
 'explain-2026-10-30','rollback restores previous active prompt');

-- extract_values non richiede seconda approvazione: l'autore attiva da solo.
delete from prompt_ids;
insert into prompt_ids select public.ai_prompt_create('extract_values','test system','{}','test {{document}}','test');
select lives_ok(format('select public.ai_prompt_activate(%L)',(select id from prompt_ids limit 1)),'single-approval task activates without second approver');

-- ---------------------------------------------------------------------------
-- Cron registrati
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
select lives_ok($$select public.run_enqueue_pending_extractions_logged(1)$$,'logged enqueue wrapper runs');
select ok((select count(*) from public.platform_events where source='enqueue_pending_extractions' and status='started')>0,'wrapper writes start');
select ok((select count(*) from public.platform_events where source='enqueue_pending_extractions' and status='ok')>0,'wrapper writes finish');

select * from finish();
rollback;