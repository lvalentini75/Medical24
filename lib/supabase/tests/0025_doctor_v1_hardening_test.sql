-- Medical 24 - pgTAP 0025 Medico v1: irrobustimento dei link di condivisione.
-- Dev only; rollback finale.
-- Pattern CONTEXT_CORE §6: fixture come postgres, poi set local role + claims JWT.
--
-- Il "contesto interno" delle funzioni riservate (share_link_open,
-- share_open_rate_check, share_link_is_active) e' postgres con il claim
-- role = service_role: e' cosi' che la Edge Function dossier-open le chiama.
begin;
create extension if not exists pgtap with schema extensions;
select plan(23);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
('d1111111-1111-4111-8111-111111111125','00000000-0000-0000-0000-000000000000','authenticated','authenticated','alice25@example.com','',now(),'{}','{"full_name":"Alice"}',now(),now())
on conflict(id) do nothing;

create temp table t25(k text primary key, u uuid, s text, j jsonb);
grant all on t25 to public;

-- ---------------------------------------------------------------------------
-- 1. Tabella, RLS, indice, append-only
-- ---------------------------------------------------------------------------
select has_table('public','share_open_attempts','share_open_attempts exists');
select is((select relrowsecurity and relforcerowsecurity
             from pg_class where oid='public.share_open_attempts'::regclass),
  true,'share_open_attempts has forced row level security');
select is((select count(*)::int from pg_policies
            where schemaname='public' and tablename='share_open_attempts'),0,
  'share_open_attempts has no policy at all');
select has_index('public','share_open_attempts','idx_share_open_attempts_ip_time',
  'share_open_attempts is indexed by ip hash and time');

insert into public.share_open_attempts(ip_hash,outcome) values ('ip-seed','wrong_pin');
select throws_ok(
  $$update public.share_open_attempts set outcome='ok' where ip_hash='ip-seed'$$,
  '42501',null,'share_open_attempts refuses update');
select throws_ok(
  $$delete from public.share_open_attempts where ip_hash='ip-seed'$$,
  '42501',null,'share_open_attempts refuses delete');

-- ---------------------------------------------------------------------------
-- 2. Firme e registro
-- ---------------------------------------------------------------------------
select has_function('public','share_open_rate_check',array['text'],'share_open_rate_check exists');
select has_function('public','share_link_is_active',array['uuid'],'share_link_is_active exists');
select has_function('public','purge_share_open_attempts',array[]::text[],'purge_share_open_attempts exists');
select has_function('public','run_purge_share_open_attempts_logged',array[]::text[],'the logged purge wrapper exists');
select is((select count(*)::int from public.app_migrations where name='0025_doctor_v1_hardening'),1,'0025 registered');

-- ---------------------------------------------------------------------------
-- 3. Il codice inesistente lascia un tentativo
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claims','{"role":"service_role"}',true);

-- 999999 non puo' essere generato da share_link_create (cifre tutte uguali)
-- Il registro puo' gia' contenere righe vere (il test gira sul database dev):
-- si confronta il conteggio prima e dopo, non con zero.
insert into t25(k,s) select 'opens_before', count(*)::text from public.share_link_opens;
insert into t25(k,j) select 'nf', public.share_link_open('999999','4719','ip-nf');
select is((select j->>'outcome' from t25 where k='nf'),'not_found','an unknown code is not found');
select is((select count(*)::int from public.share_open_attempts
            where ip_hash='ip-nf' and outcome='not_found'),1,
  'an unknown code still records one attempt for the ip hash');
select is((select count(*)::int from public.share_link_opens),
  (select s::int from t25 where k='opens_before'),
  'an unknown code leaves no new row in the link register');

-- ---------------------------------------------------------------------------
-- 4. Freno: venti tentativi falliti in quindici minuti
-- ---------------------------------------------------------------------------
reset role;
insert into public.share_open_attempts(ip_hash,outcome)
select 'ip-20','wrong_pin' from generate_series(1,20);
insert into public.share_open_attempts(ip_hash,outcome)
select 'ip-19','not_found' from generate_series(1,19);
-- gli esiti ok non contano, nemmeno in mezzo agli altri
insert into public.share_open_attempts(ip_hash,outcome)
select 'ip-19','ok' from generate_series(1,5);
select set_config('request.jwt.claims','{"role":"service_role"}',true);

select is(public.share_open_rate_check('ip-20'),false,'twenty failed attempts brake the ip hash');
select is(public.share_open_rate_check('ip-19'),true,'nineteen failed attempts still pass');
select is(public.share_open_rate_check(null),true,'a null ip hash is counted as unknown and passes');

-- ---------------------------------------------------------------------------
-- 5. share_link_is_active nei cinque casi
-- ---------------------------------------------------------------------------
reset role;
insert into public.share_links(subject_id,created_by,code,pin_hash) values
('d1111111-1111-4111-8111-111111111125','d1111111-1111-4111-8111-111111111125','650001',crypt('4719',gen_salt('bf')));
insert into public.share_links(subject_id,created_by,code,pin_hash,revoked_at) values
('d1111111-1111-4111-8111-111111111125','d1111111-1111-4111-8111-111111111125','650002',crypt('4719',gen_salt('bf')),now());
insert into public.share_links(subject_id,created_by,code,pin_hash,created_at,expires_at) values
('d1111111-1111-4111-8111-111111111125','d1111111-1111-4111-8111-111111111125','650003',crypt('4719',gen_salt('bf')),
 now() - interval '10 days', now() - interval '1 day');
insert into public.share_links(subject_id,created_by,code,pin_hash,locked_until) values
('d1111111-1111-4111-8111-111111111125','d1111111-1111-4111-8111-111111111125','650004',crypt('4719',gen_salt('bf')),now() + interval '15 minutes');
insert into public.share_links(subject_id,created_by,code,pin_hash,max_opens,opens_count) values
('d1111111-1111-4111-8111-111111111125','d1111111-1111-4111-8111-111111111125','650005',crypt('4719',gen_salt('bf')),1,1);

insert into t25(k,u,s) select 'active', id, code from public.share_links where code='650001';
insert into t25(k,u,s) select 'revoked', id, code from public.share_links where code='650002';
insert into t25(k,u,s) select 'expired', id, code from public.share_links where code='650003';
insert into t25(k,u,s) select 'locked', id, code from public.share_links where code='650004';
insert into t25(k,u,s) select 'exhausted', id, code from public.share_links where code='650005';

select set_config('request.jwt.claims','{"role":"service_role"}',true);

select is(public.share_link_is_active((select u from t25 where k='active')),true,
  'a fresh link is active');
select is(public.share_link_is_active((select u from t25 where k='revoked')),false,
  'a revoked link is not active');
select is(public.share_link_is_active((select u from t25 where k='expired')),false,
  'an expired link is not active');
select is(public.share_link_is_active((select u from t25 where k='locked')),false,
  'a locked link is not active');
select is(public.share_link_is_active((select u from t25 where k='exhausted')),false,
  'an exhausted link is not active');

-- ---------------------------------------------------------------------------
-- 6. authenticated non chiama le funzioni interne
-- ---------------------------------------------------------------------------
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"d1111111-1111-4111-8111-111111111125","role":"authenticated"}',true);
select throws_ok(
  format($f$select public.share_link_is_active(%L::uuid)$f$,(select u from t25 where k='active')),
  '42501',null,'authenticated cannot call share_link_is_active');

reset role;
select * from finish();
rollback;