-- Medical 24 - pgTAP 0016 task request options + scritture admin. Dev only; rollback finale.
begin;
create extension if not exists pgtap with schema extensions;
select plan(25);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('91111111-1111-4111-8111-111111111116','00000000-0000-0000-0000-000000000000','authenticated','authenticated','user16@example.com','',now(),'{}','{}',now(),now()),
('92222222-2222-4222-8222-222222222226','00000000-0000-0000-0000-000000000000','authenticated','authenticated','admin16@example.com','',now(),'{}','{}',now(),now())
on conflict(id) do nothing;
insert into public.user_roles(user_id,role) values ('92222222-2222-4222-8222-222222222226','admin')
on conflict(user_id,role) do nothing;

-- ---------------------------------------------------------------------------
-- Struttura e seed
-- ---------------------------------------------------------------------------
select has_column('public','ai_tasks','request_options','ai_tasks.request_options exists');
select is((select count(*)::int from pg_constraint where conname='ai_tasks_request_options_object'),1,'request_options must be an object (constraint)');
select is((select request_options#>>'{thinking,type}' from public.ai_tasks where id='explain'),'between_tools','explain: no up-front thinking');
select is((select request_options#>>'{output_config,effort}' from public.ai_tasks where id='explain'),'medium','explain: effort medium');
select is((select request_options#>>'{output_config,effort}' from public.ai_tasks where id='extract_values'),'high','extract_values: effort high');
select is((select request_options from public.ai_tasks where id='extract_classify'),'{}'::jsonb,'extract_classify: no options yet');
select is((select count(*)::int from public.app_migrations where name='0016_task_request_options'),1,'0016 registered');

-- ai_task_config espone request_options (contesto interno)
select set_config('request.jwt.claims','',true);
select is(public.ai_task_config('explain')->'request_options'->'thinking'->>'type','between_tools','ai_task_config exposes request_options');
select is(public.ai_task_config('extract_classify')->'request_options','{}'::jsonb,'ai_task_config exposes empty options');
select is((public.ai_task_config('extract_classify')->>'paused')::boolean,false,'paused is a real boolean, never null');

-- ---------------------------------------------------------------------------
-- Utente normale: nessuna scrittura
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91111111-1111-4111-8111-111111111116","role":"authenticated"}',true);
select throws_ok($$select public.ai_task_set('explain','{"enabled":false}'::jsonb)$$,'42501','not_allowed','normal user cannot change tasks');
select throws_ok($$select public.ai_model_set('claude-sonnet-5-5','{"notes":"x"}'::jsonb)$$,'42501','not_allowed','normal user cannot change models');
select throws_ok($$select * from public.admin_ai_calls(now()-interval '1 day',now())$$,'42501','not_allowed','normal user cannot list calls');

-- ---------------------------------------------------------------------------
-- Admin: ai_task_set
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"92222222-2222-4222-8222-222222222226","role":"authenticated"}',true);
select is((public.ai_task_set('explain','{"daily_budget_micro_usd":2000000,"budget_action":"pause","max_output_tokens":1500}'::jsonb)->>'max_output_tokens')::int,1500,'admin changes task and gets the row back');
select is((select daily_budget_micro_usd from public.ai_tasks where id='explain'),2000000::bigint,'budget persisted');
select throws_ok($$select public.ai_task_set('explain','{"colour":"blue"}'::jsonb)$$,'22023',null,'unknown key is refused');
select throws_ok($$select public.ai_task_set('explain','{"model_id":"gpt-nope"}'::jsonb)$$,'22023','unknown_model','unknown model is refused');
select throws_ok($$select public.ai_task_set('explain','{"max_output_tokens":0}'::jsonb)$$,'22023','invalid_max_output_tokens','zero max tokens is refused');
select lives_ok($$select public.ai_task_set('explain','{"paused_until":null,"request_options":{"thinking":{"type":"between_tools"},"output_config":{"effort":"low"}}}'::jsonb)$$,'resume and change options');
select is((select request_options#>>'{output_config,effort}' from public.ai_tasks where id='explain'),'low','request_options updated');
select is((select count(*)::int from public.platform_events where kind='admin_action' and source='explain' and status='ai_task.set'),2,'admin actions recorded as events');

-- ---------------------------------------------------------------------------
-- Admin: ai_model_set e admin_ai_calls
-- ---------------------------------------------------------------------------
select is((public.ai_model_set('claude-sonnet-5-5','{"price_cached_in_micro_usd_per_mtok":100000}'::jsonb)->>'price_cached_in_micro_usd_per_mtok')::bigint,100000::bigint,'admin updates a price');
select throws_ok($$select public.ai_model_set('claude-sonnet-5-5','{"status":"deprecated"}'::jsonb)$$,'P0001','model_in_use','a model used by a task cannot be deprecated');
select lives_ok($$select public.ai_model_set('claude-test-model','{"provider":"anthropic","display_name":"Test","price_in_micro_usd_per_mtok":1,"price_out_micro_usd_per_mtok":2}'::jsonb)$$,'admin creates a model');
reset role; select set_config('request.jwt.claims','',true);
select * from public.ai_log_call('explain','claude-sonnet-5-5','v',null,'explain','ok',null,100,10,0,5,'calls1');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"92222222-2222-4222-8222-222222222226","role":"authenticated"}',true);
select ok((select count(*) from public.admin_ai_calls(now()-interval '1 day',clock_timestamp()+interval '1 minute','explain','ok',10,0))>=1,'admin lists recent calls');

select * from finish();
rollback;