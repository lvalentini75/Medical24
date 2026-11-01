-- Medical 24 - pgTAP 0013 explanations. Dev only; rolls back fixtures.
-- Copre: tabella e policy di explanations, il filtro anti-diagnosi sui 30
-- esempi del board e sui 3 esempi ammessi, explanation_context fra soggetti
-- diversi e la stabilita dello hash degli input.
begin;
create extension if not exists pgtap with schema extensions;
create temp table tap_lines(n serial primary key,line text);
grant all on table tap_lines to public;
grant all on sequence tap_lines_n_seq to public;
create temp table fix_hash(k text primary key,v text);
grant all on table fix_hash to public;
insert into tap_lines(line) select plan(51);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('81111111-1111-4111-8111-111111111111','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','alice.explain13@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now()),
('82222222-2222-4222-8222-222222222222','00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated','bob.explain13@example.com','',now(),
 '{"provider":"email","providers":["email"]}','{}',now(),now())
on conflict(id) do nothing;
update public.profiles set gender='female',birth_date=current_date-interval '52 years',
 language='it' where id='81111111-1111-4111-8111-111111111111';
update public.profiles set gender='male',birth_date=current_date-interval '52 years',
 language='it' where id='82222222-2222-4222-8222-222222222222';

-- ---------------------------------------------------------------------------
-- 1. Schema, funzioni e regola del board: 11 assertions.
-- ---------------------------------------------------------------------------
insert into tap_lines(line) select has_table('public','explanations','explanations exists');
insert into tap_lines(line) select ok(
 (select relrowsecurity from pg_class where oid='public.explanations'::regclass),
 'RLS is enabled on explanations');
insert into tap_lines(line) select is((select count(*)::int from pg_policies
 where tablename='explanations' and cmd in ('INSERT','UPDATE','DELETE')),0,
 'explanations has no insert, update or delete policy');
insert into tap_lines(line) select has_function('public','check_forbidden_phrases',
 array['text'],'check_forbidden_phrases exists');
insert into tap_lines(line) select has_function('public','explanation_context',
 array['uuid','text','text'],'explanation_context exists');
insert into tap_lines(line) select has_function('public','explanation_lookup',
 array['uuid','text','text','text','text','text'],'explanation_lookup exists');
insert into tap_lines(line) select has_function('public','explanation_usage',
 array['uuid'],'explanation_usage exists');
insert into tap_lines(line) select has_function('public','explanation_save',
 'explanation_save exists');
insert into tap_lines(line) select is((select count(*)::int from public.app_migrations
 where name='0013_explanations'),1,'0013 is registered');
insert into tap_lines(line) select is((select status::text from public.rule_versions
 where type='forbidden_phrases' and version='0.1-draft'),'active',
 'the anti-diagnosis filter rule is active');
insert into tap_lines(line) select is((select jsonb_array_length(definition->'forbidden')
 from public.rule_versions where type='forbidden_phrases' and version='0.1-draft'),30,
 'the board rule carries all 30 patterns');

-- ---------------------------------------------------------------------------
-- 2. Filtro anti-diagnosi: 30 esempi bloccati + 3 ammessi = 33 assertions.
-- ---------------------------------------------------------------------------
insert into tap_lines(line)
select ok((select c.matched from public.check_forbidden_phrases(e->>'example_it') c),
  'pattern '||(e->>'id')||' ('||(e->>'category')||') blocks its own example')
from public.rule_versions r,
     lateral jsonb_array_elements(r.definition->'forbidden') e
where r.type='forbidden_phrases' and r.version='0.1-draft'
order by (e->>'id')::int;

insert into tap_lines(line)
select ok(not (select c.matched from public.check_forbidden_phrases(a.value::text) c),
  'allowed example '||a.ordinality||' passes the filter')
from public.rule_versions r,
     lateral jsonb_array_elements_text(r.definition->'allowed_examples_it')
       with ordinality a(value,ordinality)
where r.type='forbidden_phrases' and r.version='0.1-draft'
order by a.ordinality;

-- ---------------------------------------------------------------------------
-- 3. explanation_context e stabilita dello hash: 3 assertions.
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81111111-1111-4111-8111-111111111111","role":"authenticated"}',true);

insert into fix_hash(k,v) select 'first',
 public.explanation_context('81111111-1111-4111-8111-111111111111','biomarker','2345-7')->>'inputs_hash';
insert into tap_lines(line) select matches((select v from fix_hash where k='first'),
 '^[0-9a-f]{64}$','explanation_context returns a sha256 inputs_hash');
insert into tap_lines(line) select is(
 public.explanation_context('81111111-1111-4111-8111-111111111111','biomarker','2345-7')->>'inputs_hash',
 (select v from fix_hash where k='first'),
 'the hash is stable when nothing changes');

reset role; select set_config('request.jwt.claims','',true);
insert into public.observations(subject_id,code,display_name,value_num,unit,
 lab_low,lab_high,flag,effective_at,origin,confidence,rule_version)
values('81111111-1111-4111-8111-111111111111','2345-7','Glicemia',112,'mg/dL',
 70,99,'above',now(),'document',1,'board-0');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into tap_lines(line) select isnt(
 public.explanation_context('81111111-1111-4111-8111-111111111111','biomarker','2345-7')->>'inputs_hash',
 (select v from fix_hash where k='first'),
 'the hash changes when a value changes');

-- ---------------------------------------------------------------------------
-- 4. Cache: explanation_lookup con e senza lo hash giusto: 2 assertions.
-- ---------------------------------------------------------------------------
reset role; select set_config('request.jwt.claims','',true);
insert into public.explanations(subject_id,target_type,target_id,level,lang,
 inputs_hash,text,model,prompt_version,tokens_in,tokens_out,cost_micro_usd,
 filter_passed,filter_ids)
values('81111111-1111-4111-8111-111111111111','biomarker','2345-7','simple','it',
 repeat('a',64),'Testo di prova del test, non clinico.','claude-sonnet-4-5',
 'explain-2026-10-30',500,120,3300,true,'{}');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"81111111-1111-4111-8111-111111111111","role":"authenticated"}',true);
insert into tap_lines(line) select is((select count(*)::int from public.explanation_lookup(
 '81111111-1111-4111-8111-111111111111','biomarker','2345-7','simple','it',repeat('a',64))),1,
 'the cache returns the row for the matching hash');
insert into tap_lines(line) select is((select count(*)::int from public.explanation_lookup(
 '81111111-1111-4111-8111-111111111111','biomarker','2345-7','simple','it',repeat('b',64))),0,
 'a different hash is a cache miss');

-- ---------------------------------------------------------------------------
-- 5. Un estraneo non legge e non chiede nulla: 2 assertions.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"sub":"82222222-2222-4222-8222-222222222222","role":"authenticated"}',true);
insert into tap_lines(line) select is((select count(*)::int from public.explanations),0,
 'a stranger reads zero explanations');
insert into tap_lines(line) select throws_ok(
 $$select public.explanation_context('81111111-1111-4111-8111-111111111111','biomarker','2345-7')$$,
 '42501','not_allowed','a stranger cannot build another subject context');

reset role; select set_config('request.jwt.claims','',true);
insert into tap_lines(line) select * from finish();
select line from tap_lines order by n;
rollback;
