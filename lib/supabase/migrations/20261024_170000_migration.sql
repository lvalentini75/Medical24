-- ============================================================================
-- Medical 24 — 0004 SOFT DELETE DEI DOCUMENTI VIA FUNZIONE
-- Motivo: con la policy di select che nasconde deleted_at non nullo,
-- PostgreSQL rifiuta l'update diretto che imposta deleted_at ("new row
-- violates row-level security policy"), perché il nuovo stato della riga
-- non sarebbe più visibile a chi la aggiorna. La cancellazione passa quindi
-- da una funzione security definer che verifica l'accesso e aggiorna.
-- ============================================================================

create or replace function public.soft_delete_document(p_document_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subject uuid;
begin
  select d.subject_id into v_subject
    from public.documents d
   where d.id = p_document_id
     and d.deleted_at is null;

  if v_subject is null or not public.can_access_subject(v_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  update public.documents
     set deleted_at = now()
   where id = p_document_id
     and deleted_at is null;
end;
$$;

revoke execute on function public.soft_delete_document(uuid) from public, anon;
grant execute on function public.soft_delete_document(uuid) to authenticated;

insert into public.app_migrations (name) values ('0004_soft_delete_document')
on conflict do nothing;