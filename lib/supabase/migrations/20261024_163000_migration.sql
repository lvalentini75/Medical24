-- ============================================================================
-- Medical 24 — 0003 ARCHIVE COMPLETION (P01-D) · modulo M2 Archivio
--
-- Contenuto, nient'altro:
--  1. colonna documents.duplicate_dismissed_at
--  2. funzione document_usage() returns table (used int, max int)
--  3. grant execute ad authenticated
--
-- Nessuna policy RLS esistente viene modificata: documents ha già
-- documents_select / documents_insert / documents_update dal 0002_archive,
-- e la nuova colonna ricade sotto documents_update (can_access_subject).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Duplicati: l'utente può archiviare l'avviso "Sembra già in archivio".
--    Finché resta null la lista mostra l'etichetta "Possibile duplicato".
-- ---------------------------------------------------------------------------
alter table public.documents
  add column if not exists duplicate_dismissed_at timestamptz;

comment on column public.documents.duplicate_dismissed_at is
  'Momento in cui il proprietario ha chiuso l''avviso di possibile duplicato.';

create index if not exists idx_documents_duplicate_open
  on public.documents (subject_id)
  where duplicate_of is not null
    and duplicate_dismissed_at is null
    and deleted_at is null;

-- ---------------------------------------------------------------------------
-- 2. Uso del piano: quanti documenti attivi ha il soggetto auth.uid()
--    e qual è il massimo consentito. security invoker: la select passa
--    dalle policy di documents, quindi nessun utente conta righe altrui.
-- ---------------------------------------------------------------------------
create or replace function public.document_usage()
returns table (used int, max int)
language sql
stable
security invoker
set search_path = public
as $$
  select
    (
      select count(*)::int
      from public.documents d
      where d.subject_id = auth.uid()
        and d.deleted_at is null
    ) as used,
    public.document_limit(auth.uid()) as max;
$$;

comment on function public.document_usage() is
  'Documenti attivi del soggetto corrente e limite del piano (P01: 30).';

-- ---------------------------------------------------------------------------
-- 3. Grants
-- ---------------------------------------------------------------------------
grant execute on function public.document_usage() to authenticated;
revoke execute on function public.document_usage() from anon;

insert into public.app_migrations (name)
values ('0003_archive_completion_20261024_163000')
on conflict do nothing;
