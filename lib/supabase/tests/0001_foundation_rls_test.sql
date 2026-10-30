-- ============================================================================
-- Medical 24 — pgTAP: RLS della migrazione 0001_foundation
-- Criterio: un secondo utente ottiene ZERO righe da profiles, consents
-- e audit_log del primo.
-- Esecuzione: psql -f questo file sul progetto dev (extension pgtap richiesta).
-- ============================================================================

begin;
create extension if not exists pgtap;

select plan(19);

-- ---------------------------------------------------------------------------
-- 1. RLS attiva su tutte le tabelle della migrazione
-- ---------------------------------------------------------------------------
select ok(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  'RLS attiva su profiles');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.user_roles'::regclass),
  'RLS attiva su user_roles');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.consents'::regclass),
  'RLS attiva su consents');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.audit_log'::regclass),
  'RLS attiva su audit_log');

-- ---------------------------------------------------------------------------
-- 2. Almeno una policy per tabella
-- ---------------------------------------------------------------------------
select cmp_ok((select count(*) from pg_policies where tablename = 'profiles'),
  '>', 0::bigint, 'profiles ha almeno una policy');
select cmp_ok((select count(*) from pg_policies where tablename = 'user_roles'),
  '>', 0::bigint, 'user_roles ha almeno una policy');
select cmp_ok((select count(*) from pg_policies where tablename = 'consents'),
  '>', 0::bigint, 'consents ha almeno una policy');
select cmp_ok((select count(*) from pg_policies where tablename = 'audit_log'),
  '>', 0::bigint, 'audit_log ha almeno una policy');

-- ---------------------------------------------------------------------------
-- 3. consents e audit_log sono append-only: nessuna policy update/delete
-- ---------------------------------------------------------------------------
select is((select count(*) from pg_policies
            where tablename = 'consents' and cmd in ('UPDATE', 'DELETE')),
          0::bigint, 'consents non ha policy di update o delete');
select is((select count(*) from pg_policies
            where tablename = 'audit_log' and cmd in ('UPDATE', 'DELETE', 'INSERT')),
          0::bigint, 'audit_log non ha policy di insert, update o delete');

-- ---------------------------------------------------------------------------
-- 4. Due utenti di prova
-- ---------------------------------------------------------------------------
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'alice.test@medical24.invalid', '', now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'bob.test@medical24.invalid', '', now(), now(), now())
on conflict (id) do nothing;

-- Il trigger ha creato profilo e ruolo
select is((select count(*) from public.profiles
            where id = '11111111-1111-1111-1111-111111111111'),
          1::bigint, 'il trigger crea il profilo del nuovo utente');
select is((select count(*) from public.user_roles
            where user_id = '11111111-1111-1111-1111-111111111111' and role = 'user'),
          1::bigint, 'il trigger assegna il ruolo user');

-- Dati di Alice
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select lives_ok(
  $$select public.record_consent('health_data'::consent_type, 'test.1', true, 'it')$$,
  'Alice registra un consenso');

select is((select count(*) from public.consents), 1::bigint,
  'Alice vede il proprio consenso');
select is((select count(*) from public.profiles), 1::bigint,
  'Alice vede solo il proprio profilo');
select ok(public.can_access_subject('11111111-1111-1111-1111-111111111111'),
  'can_access_subject vero sul proprio subject_id');

-- ---------------------------------------------------------------------------
-- 5. Bob (utente estraneo) ottiene ZERO righe
-- ---------------------------------------------------------------------------
set local request.jwt.claims to '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}';

select is((select count(*) from public.profiles
            where id = '11111111-1111-1111-1111-111111111111'),
          0::bigint, 'Bob ottiene zero righe dal profilo di Alice');
select is((select count(*) from public.consents
            where user_id = '11111111-1111-1111-1111-111111111111'),
          0::bigint, 'Bob ottiene zero righe dai consensi di Alice');
select is((select count(*) from public.audit_log
            where subject_id = '11111111-1111-1111-1111-111111111111'),
          0::bigint, 'Bob ottiene zero righe dall''audit log di Alice');

select * from finish();
rollback;
