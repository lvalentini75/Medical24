-- ============================================================================
-- Medical 24 — 0001 FOUNDATION (P00)
-- Tabelle: profiles, user_roles, consents, audit_log
-- Nessun dato clinico in questa migrazione.
-- ============================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enum
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type app_role as enum (
      'user', 'caregiver', 'doctor', 'facility_admin', 'facility_staff', 'board', 'admin'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'consent_type') then
    create type consent_type as enum (
      'health_data', 'ai_processing', 'marketing', 'sharing', 'research', 'nutrition_diary', 'authored_content'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'data_region') then
    create type data_region as enum ('eu', 'us');
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'unit_system') then
    create type unit_system as enum ('mg_dl', 'mmol_l');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  full_name     text,
  avatar_url    text,
  birth_date    date,
  gender        text check (gender in ('female', 'male', 'other', 'undisclosed')),
  language      text not null default 'it' check (language in ('it', 'en')),
  units         unit_system not null default 'mg_dl',
  country       text,
  data_region   data_region not null default 'eu',
  timezone      text not null default 'Europe/Rome',
  onboarded_at  timestamptz,
  deleted_at    timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- user_roles
-- ---------------------------------------------------------------------------
create table if not exists public.user_roles (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  role       app_role not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, role)
);

create index if not exists idx_user_roles_user_id on public.user_roles (user_id);

-- ---------------------------------------------------------------------------
-- consents (append-only)
-- ---------------------------------------------------------------------------
create table if not exists public.consents (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  type        consent_type not null,
  version     text not null,
  granted     boolean not null default true,
  granted_at  timestamptz not null default now(),
  revoked_at  timestamptz,
  locale      text not null default 'it',
  created_at  timestamptz not null default now()
);

create index if not exists idx_consents_user_type on public.consents (user_id, type, granted_at desc);

-- ---------------------------------------------------------------------------
-- audit_log (append-only, scrittura solo via funzione security definer)
-- ---------------------------------------------------------------------------
create table if not exists public.audit_log (
  id           uuid primary key default gen_random_uuid(),
  actor_id     uuid references auth.users (id) on delete set null,
  action       text not null,
  target_table text,
  target_id    uuid,
  subject_id   uuid,
  device       text,
  created_at   timestamptz not null default now()
);

create index if not exists idx_audit_log_subject on public.audit_log (subject_id, created_at desc);
create index if not exists idx_audit_log_actor on public.audit_log (actor_id, created_at desc);

-- ---------------------------------------------------------------------------
-- updated_at trigger
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_user_roles_updated_at on public.user_roles;
create trigger trg_user_roles_updated_at
  before update on public.user_roles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Nuovo utente -> profiles + user_roles(role = user)
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do nothing;

  insert into public.user_roles (user_id, role)
  values (new.id, 'user')
  on conflict (user_id, role) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- can_access_subject: unico punto di controllo per i dati clinici.
-- In P00 vale solo per se stessi; i prompt successivi la estendono
-- (deleghe familiari, doctor_patient_links).
-- ---------------------------------------------------------------------------
create or replace function public.can_access_subject(subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select subject_id is not null and subject_id = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- has_role / is_admin
-- ---------------------------------------------------------------------------
create or replace function public.has_role(check_role app_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid() and ur.role = check_role
  );
$$;

-- ---------------------------------------------------------------------------
-- log_audit: unico modo per scrivere in audit_log dal client
-- ---------------------------------------------------------------------------
create or replace function public.log_audit(
  action text,
  target_table text default null,
  target_id uuid default null,
  subject_id uuid default null,
  device text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  insert into public.audit_log (actor_id, action, target_table, target_id, subject_id, device)
  values (auth.uid(), action, target_table, target_id, coalesce(subject_id, auth.uid()), device)
  returning id into new_id;

  return new_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- record_consent: scrive una riga append-only in consents
-- ---------------------------------------------------------------------------
create or replace function public.record_consent(
  consent_type consent_type,
  consent_version text,
  is_granted boolean,
  consent_locale text default 'it'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  insert into public.consents (user_id, type, version, granted, granted_at, revoked_at, locale)
  values (
    auth.uid(),
    consent_type,
    consent_version,
    is_granted,
    now(),
    case when is_granted then null else now() end,
    consent_locale
  )
  returning id into new_id;

  perform public.log_audit(
    case when is_granted then 'consent_granted' else 'consent_revoked' end,
    'consents',
    new_id,
    auth.uid(),
    null
  );

  return new_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Auth hook: ruoli nel JWT come claim app_roles
-- (da attivare in Supabase: Auth > Hooks > Custom Access Token)
-- ---------------------------------------------------------------------------
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  claims jsonb;
  roles  jsonb;
begin
  select coalesce(jsonb_agg(ur.role::text), '["user"]'::jsonb)
    into roles
  from public.user_roles ur
  where ur.user_id = (event ->> 'user_id')::uuid;

  claims := coalesce(event -> 'claims', '{}'::jsonb);
  claims := jsonb_set(claims, '{app_roles}', roles);

  return jsonb_set(event, '{claims}', claims);
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook(jsonb) from authenticated, anon, public;
grant select on table public.user_roles to supabase_auth_admin;

-- ---------------------------------------------------------------------------
-- soft delete + purge a 30 giorni
-- ---------------------------------------------------------------------------
create or replace function public.soft_delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'unauthenticated';
  end if;

  update public.profiles
     set deleted_at = now()
   where id = auth.uid();

  perform public.log_audit('account_soft_deleted', 'profiles', auth.uid(), auth.uid(), null);
end;
$$;

create or replace function public.purge_deleted_accounts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  purged integer := 0;
  r record;
begin
  for r in
    select id from public.profiles
    where deleted_at is not null and deleted_at < now() - interval '30 days'
  loop
    insert into public.audit_log (actor_id, action, target_table, target_id, subject_id)
    values (null, 'account_purged', 'profiles', r.id, r.id);

    delete from auth.users where id = r.id;
    purged := purged + 1;
  end loop;

  return purged;
end;
$$;

-- pg_cron: purge notturna (eseguire una volta sul progetto)
-- select cron.schedule('purge-deleted-accounts', '30 3 * * *', $$select public.purge_deleted_accounts()$$);
