-- ============================================================================
-- Medical 24 — 0002 ARCHIVE (P01-A) · modulo M2 Archivio documentale
-- Tabelle: documents, document_pages
-- Storage: bucket privato "documents"
-- Nessun dato estratto dall'IA in questa migrazione (ai_tags resta vuoto
-- fino al P02; ocr_text resta null fino al P02).
-- Questa migrazione non modifica nulla del P00: solo aggiunte.
-- ============================================================================

create extension if not exists "pgcrypto";

create or replace function public.immutable_array_to_string(text[], text)
returns text language sql immutable parallel safe
as $$ select array_to_string($1, $2) $$;

create or replace function public.set_updated_at()
returns trigger language plpgsql
as $$ begin new.updated_at = now(); return new; end $$;

-- ---------------------------------------------------------------------------
-- 1. Enum
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'document_category') then
    create type document_category as enum (
      'exams', 'reports', 'prescriptions', 'radiology', 'vaccinations',
      'invoices', 'consents', 'cards', 'other'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'document_source') then
    create type document_source as enum (
      'camera', 'gallery', 'pdf', 'share_sheet', 'email', 'fse'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'document_status') then
    create type document_status as enum (
      'uploading', 'uploaded', 'processing', 'analyzed', 'needs_review', 'failed'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. documents
-- ---------------------------------------------------------------------------
create table if not exists public.documents (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null references auth.users (id) on delete cascade,
  subject_id     uuid not null,
  category       document_category not null default 'other',
  title          text not null default '',
  document_date  date,
  source         document_source not null default 'gallery',
  status         document_status not null default 'uploading',
  failure_reason text,
  storage_path   text not null,
  original_name  text,
  mime_type      text,
  size_bytes     bigint,
  page_count     int not null default 0,
  sha256         text,
  duplicate_of   uuid references public.documents (id) on delete set null,
  tags           text[] not null default '{}',
  ai_tags        text[] not null default '{}',
  doctor_name    text,
  facility_name  text,
  episode        text,
  notes          text,
  search         tsvector generated always as (
    to_tsvector(
      'simple'::regconfig,
      coalesce(title, '') || ' ' ||
      public.immutable_array_to_string(tags, ' ') || ' ' ||
      coalesce(doctor_name, '') || ' ' ||
      coalesce(facility_name, '') || ' ' ||
      coalesce(episode, '')
    )
  ) stored,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

create index if not exists idx_documents_subject_date
  on public.documents (subject_id, document_date desc, id);
create index if not exists idx_documents_subject_category
  on public.documents (subject_id, category);
create index if not exists idx_documents_subject_sha256
  on public.documents (subject_id, sha256);
create index if not exists idx_documents_search
  on public.documents using gin (search);
create index if not exists idx_documents_owner
  on public.documents (owner_id);
create index if not exists idx_documents_status_created
  on public.documents (status, created_at);

-- ---------------------------------------------------------------------------
-- 3. document_pages
-- ---------------------------------------------------------------------------
create table if not exists public.document_pages (
  id          uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents (id) on delete cascade,
  page_number int not null check (page_number >= 1),
  image_path  text,
  thumb_path  text,
  width       int,
  height      int,
  ocr_text    text,
  created_at  timestamptz not null default now(),
  unique (document_id, page_number)
);

create index if not exists idx_document_pages_document
  on public.document_pages (document_id, page_number);

-- ---------------------------------------------------------------------------
-- 4. updated_at su documents (riusa public.set_updated_at() del P00)
-- ---------------------------------------------------------------------------
drop trigger if exists trg_documents_updated_at on public.documents;
create trigger trg_documents_updated_at
  before update on public.documents
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 5. Limite di documenti per utente
--    P01: 30 per tutti. Il P09 collegherà questa funzione a subscriptions
--    e a platform_settings senza toccare il trigger.
-- ---------------------------------------------------------------------------
create or replace function public.document_limit(p_user_id uuid)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select 30;
$$;

create or replace function public.enforce_document_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  current_count int;
  max_allowed   int;
begin
  select count(*) into current_count
  from public.documents d
  where d.subject_id = new.subject_id
    and d.deleted_at is null;

  max_allowed := public.document_limit(coalesce(auth.uid(), new.owner_id));

  if current_count >= max_allowed then
    raise exception 'document_limit_reached'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_documents_limit on public.documents;
create trigger trg_documents_limit
  before insert on public.documents
  for each row execute function public.enforce_document_limit();

-- ---------------------------------------------------------------------------
-- 6. Soft delete -> audit_log (nessuna policy di delete esiste su documents)
-- ---------------------------------------------------------------------------
create or replace function public.audit_document_soft_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.deleted_at is null and new.deleted_at is not null then
    perform public.log_audit(
      'document.deleted', 'documents', new.id, new.subject_id, null
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_documents_audit_soft_delete on public.documents;
create trigger trg_documents_audit_soft_delete
  after update on public.documents
  for each row execute function public.audit_document_soft_delete();

-- ---------------------------------------------------------------------------
-- 7. Helper di accesso: unico punto per le pagine
-- ---------------------------------------------------------------------------
create or replace function public.can_access_document(p_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.documents d
    where d.id = p_document_id
      and d.deleted_at is null
      and public.can_access_subject(d.subject_id)
  );
$$;

-- ---------------------------------------------------------------------------
-- 8. RLS — default deny, force row level security
-- ---------------------------------------------------------------------------
alter table public.documents      enable row level security;
alter table public.document_pages enable row level security;
alter table public.documents      force  row level security;
alter table public.document_pages force  row level security;

-- documents: select / insert / update. Nessun delete: la cancellazione è soft.
drop policy if exists documents_select on public.documents;
create policy documents_select on public.documents
  for select to authenticated
  using (public.can_access_subject(subject_id) and deleted_at is null);

drop policy if exists documents_insert on public.documents;
create policy documents_insert on public.documents
  for insert to authenticated
  with check (public.can_access_subject(subject_id) and owner_id = auth.uid());

drop policy if exists documents_update on public.documents;
create policy documents_update on public.documents
  for update to authenticated
  using (public.can_access_subject(subject_id))
  with check (public.can_access_subject(subject_id));

-- document_pages: passano dall'esistenza di un documento accessibile.
drop policy if exists document_pages_select on public.document_pages;
create policy document_pages_select on public.document_pages
  for select to authenticated
  using (public.can_access_document(document_id));

drop policy if exists document_pages_insert on public.document_pages;
create policy document_pages_insert on public.document_pages
  for insert to authenticated
  with check (public.can_access_document(document_id));

drop policy if exists document_pages_update on public.document_pages;
create policy document_pages_update on public.document_pages
  for update to authenticated
  using (public.can_access_document(document_id))
  with check (public.can_access_document(document_id));

-- ---------------------------------------------------------------------------
-- 9. Grants
-- ---------------------------------------------------------------------------
revoke all on public.documents, public.document_pages from anon;
grant select, insert, update on public.documents to authenticated;
grant select, insert, update on public.document_pages to authenticated;

grant execute on function public.can_access_document(uuid) to authenticated;
grant execute on function public.document_limit(uuid) to authenticated;
revoke execute on function public.document_limit(uuid) from anon;

-- ---------------------------------------------------------------------------
-- 10. Storage: bucket privato "documents"
--     path: subjects/{subject_id}/documents/{document_id}/original.{ext}
--                                                        /page-001.jpg
--                                                        /thumb-001.jpg
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'documents',
  'documents',
  false,
  26214400,
  array['application/pdf', 'image/jpeg', 'image/png', 'image/heic']
)
on conflict (id) do update
  set public             = false,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists documents_storage_select on storage.objects;
create policy documents_storage_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documents'
    and public.can_access_subject(((storage.foldername(name))[2])::uuid)
  );

drop policy if exists documents_storage_insert on storage.objects;
create policy documents_storage_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documents'
    and public.can_access_subject(((storage.foldername(name))[2])::uuid)
  );

drop policy if exists documents_storage_update on storage.objects;
create policy documents_storage_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'documents'
    and public.can_access_subject(((storage.foldername(name))[2])::uuid)
  )
  with check (
    bucket_id = 'documents'
    and public.can_access_subject(((storage.foldername(name))[2])::uuid)
  );

drop policy if exists documents_storage_delete on storage.objects;
create policy documents_storage_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'documents'
    and public.can_access_subject(((storage.foldername(name))[2])::uuid)
  );

-- ---------------------------------------------------------------------------
-- 11. pg_cron: upload rimasti appesi oltre 24 ore -> failed
--     (la pulizia dei file orfani nello Storage entra nel P10)
-- ---------------------------------------------------------------------------
create or replace function public.expire_stale_document_uploads()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  touched integer := 0;
begin
  with updated as (
    update public.documents
       set status = 'failed',
           failure_reason = 'upload_incomplete'
     where status = 'uploading'
       and deleted_at is null
       and created_at < now() - interval '24 hours'
    returning 1
  )
  select count(*) into touched from updated;

  return touched;
end;
$$;

revoke execute on function public.expire_stale_document_uploads() from anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('expire-stale-document-uploads')
      where exists (
        select 1 from cron.job where jobname = 'expire-stale-document-uploads'
      );
    perform cron.schedule(
      'expire-stale-document-uploads',
      '15 3 * * *',
      $cron$select public.expire_stale_document_uploads()$cron$
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 12. Registro delle migrazioni applicate
-- ---------------------------------------------------------------------------
create table if not exists public.app_migrations (
  name text primary key,
  applied_at timestamptz not null default now()
);

alter table public.app_migrations enable row level security;

insert into public.app_migrations (name)
values
  ('0000_supabase_tables'),
  ('0001_supabase_policies'),
  ('0002_archive_20261024_104530')
on conflict do nothing;
