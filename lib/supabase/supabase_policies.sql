-- ============================================================================
-- Medical 24 — 0001 FOUNDATION · RLS e policy (P00)
-- Default deny: ogni tabella ha RLS attiva e almeno una policy.
-- anon non scrive mai. service_role solo nelle Edge Functions.
-- ============================================================================

alter table public.profiles   enable row level security;
alter table public.user_roles enable row level security;
alter table public.consents   enable row level security;
alter table public.audit_log  enable row level security;

alter table public.profiles   force row level security;
alter table public.consents   force row level security;

-- ---------------------------------------------------------------------------
-- profiles: solo il proprietario
-- ---------------------------------------------------------------------------
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = auth.uid());

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = auth.uid());

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- nessuna policy di delete: la cancellazione passa da soft_delete_account()

-- ---------------------------------------------------------------------------
-- user_roles: lettura propria; scrittura solo service_role / admin
-- ---------------------------------------------------------------------------
drop policy if exists user_roles_select_own on public.user_roles;
create policy user_roles_select_own on public.user_roles
  for select to authenticated
  using (user_id = auth.uid() or public.has_role('admin'));

drop policy if exists user_roles_admin_write on public.user_roles;
create policy user_roles_admin_write on public.user_roles
  for all to authenticated
  using (public.has_role('admin'))
  with check (public.has_role('admin'));

-- ---------------------------------------------------------------------------
-- consents: append-only del proprietario (insert + select, mai update/delete)
-- ---------------------------------------------------------------------------
drop policy if exists consents_select_own on public.consents;
create policy consents_select_own on public.consents
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists consents_insert_own on public.consents;
create policy consents_insert_own on public.consents
  for insert to authenticated
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- audit_log: insert solo via log_audit() (security definer);
-- select al proprietario del soggetto e agli admin
-- ---------------------------------------------------------------------------
drop policy if exists audit_log_select_own on public.audit_log;
create policy audit_log_select_own on public.audit_log
  for select to authenticated
  using (public.can_access_subject(subject_id) or public.has_role('admin'));

-- nessuna policy di insert/update/delete per authenticated:
-- la scrittura avviene solo attraverso public.log_audit()

-- ---------------------------------------------------------------------------
-- Grants espliciti
-- ---------------------------------------------------------------------------
revoke all on public.profiles, public.user_roles, public.consents, public.audit_log from anon;

grant execute on function public.can_access_subject(uuid) to authenticated;
grant execute on function public.has_role(app_role) to authenticated;
grant execute on function public.log_audit(text, text, uuid, uuid, text) to authenticated;
grant execute on function public.record_consent(consent_type, text, boolean, text) to authenticated;
grant execute on function public.soft_delete_account() to authenticated;
revoke execute on function public.purge_deleted_accounts() from anon, authenticated;
