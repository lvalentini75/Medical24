-- ============================================================================
-- Medical 24 — 0029 FAMIGLIA E CAREGIVER (P11-A1a) — modulo M5 Famiglia
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- Decisione di progetto (vale per tutto P11-A):
--   un profilo gestito (un figlio, un genitore anziano) NON e' una riga di una
--   tabella a parte: e' un utente auth "ombra", senza accesso, creato dalla
--   Edge Function del passo A2 con il service_role. La family_members del
--   DATA_MODEL si realizza quindi come
--       profiles.managed_by  +  subject_delegates
--   cosi' subject_id resta sempre un auth.users.id e nessuna chiave esterna
--   gia' scritta cambia: documents, observations, organ_states, risk_scores,
--   share_links, emergency_cards continuano a puntare ad auth.users.
--
-- Che cosa crea questa migrazione:
--   1. profiles.managed_by      chi gestisce questo profilo (null = se stesso)
--   2. subject_delegates        le deleghe: invitata, attiva, revocata
--   3. can_access_subject       estesa alla delega attiva (punto unico)
--   4. my_subjects, delegate_invite, delegate_accept, delegate_revoke,
--      subject_view_log
--   5. my_pending_invitations   gli inviti che aspettano il chiamante
--   6. family_managed_limit     platform_settings 'family.max_managed_profiles'
--   7. family_member_register   (solo service_role), family_member_update e
--      family_member_remove     il ciclo di vita del profilo gestito
--   8. m24_family_member_remove_internal  il corpo della chiusura, senza
--      controllo del chiamante: lo usano family_member_remove e
--      soft_delete_account
--   9. soft_delete_account e account_close estese: chi chiude l'account si
--      porta dietro i profili che amministra e smette di essere caregiver
--  10. purge_subject_data estesa a subject_delegates
--
-- Niente schermate, niente Edge Function, niente seed. Idempotente: enum
-- dentro do $$ … $$, create table if not exists, create or replace,
-- drop policy if exists prima di create policy.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. profiles.managed_by
--
--    Non e' "il proprietario del dato": il soggetto dei dati resta profiles.id.
--    managed_by dice soltanto chi ha creato e amministra quell'utente ombra,
--    e serve a una cosa sola: stabilire chi puo' essere 'owner' della delega.
--    on delete cascade perche' un profilo gestito senza chi lo gestisce non ha
--    ragione di esistere.
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists managed_by uuid references auth.users(id) on delete cascade;

create index if not exists idx_profiles_managed_by
  on public.profiles (managed_by) where managed_by is not null;

comment on column public.profiles.managed_by is
  'Utente che amministra questo profilo gestito (figlio, anziano). Null per un '
  'profilo normale. L''utente ombra non ha accesso: la sua delega ''owner'' in '
  'subject_delegates e'' l''unico modo per leggerne i dati.';

-- ---------------------------------------------------------------------------
-- 2. Enum del modulo
--
--    'owner'     chi amministra un profilo gestito (un solo caso ammesso:
--                profiles.managed_by = user_id, garantito dal trigger)
--    'caregiver' familiare o badante invitato a leggere
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_type where typname = 'delegate_role') then
    create type delegate_role as enum ('owner', 'caregiver');
  end if;
  if not exists (select 1 from pg_type where typname = 'delegate_status') then
    create type delegate_status as enum ('invited', 'active', 'revoked');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. subject_delegates — chi puo' vedere i dati di chi
--
--    user_id resta nullo finche' l'invito non e' accettato: si invita un
--    indirizzo, non un account, e l'indirizzo puo' non essere ancora iscritto.
--    invited_email e' sempre in minuscolo (vincolo, non buona volonta').
--    scope e' gia' validato da m24_valid_share_scope della 0021: una forma
--    sola per i link del medico e per le deleghe familiari.
-- ---------------------------------------------------------------------------
create table if not exists public.subject_delegates (
  id            uuid primary key default gen_random_uuid(),
  subject_id    uuid not null references auth.users(id) on delete cascade,
  user_id       uuid references auth.users(id) on delete cascade,
  invited_email text not null
                  check (invited_email = lower(invited_email))
                  check (char_length(invited_email) between 3 and 320)
                  check (invited_email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  role          delegate_role not null default 'caregiver',
  relationship  text check (relationship is null or char_length(relationship) between 1 and 60),
  scope         jsonb not null default '{"all": true}'::jsonb
                  check (public.m24_valid_share_scope(scope)),
  status        delegate_status not null default 'invited',
  created_by    uuid not null references auth.users(id) on delete cascade,
  accepted_at   timestamptz,
  revoked_at    timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint subject_delegates_not_self check (user_id is null or user_id <> subject_id),
  constraint subject_delegates_active_has_user
    check (status <> 'active' or user_id is not null),
  -- un invito non accettato non ha data di accettazione; una delega attiva ce
  -- l'ha per forza. Una revocata conserva la data che aveva (o nessuna, se e'
  -- stato revocato un invito mai accettato).
  constraint subject_delegates_accepted_at
    check ((status = 'invited' and accepted_at is null)
        or (status = 'active'  and accepted_at is not null)
        or  status = 'revoked'),
  constraint subject_delegates_revoked_at
    check ((status = 'revoked') = (revoked_at is not null))
);

comment on table public.subject_delegates is
  'Deleghe familiari: chi (user_id, nullo finche'' non accetta) puo'' leggere i '
  'dati di chi (subject_id). Stato invited → active → revoked. Lettura delle '
  'sole righe che riguardano il chiamante; nessuna scrittura diretta: si passa '
  'da delegate_invite, delegate_accept e delegate_revoke.';
comment on column public.subject_delegates.invited_email is
  'Indirizzo invitato, sempre in minuscolo. Finche'' l''invito non e'' '
  'accettato e'' l''unico riferimento alla persona invitata.';
comment on column public.subject_delegates.scope is
  'Stessa forma dello scope dei link del medico, validata da '
  'm24_valid_share_scope: {"all": true} oppure organi, periodo e categorie.';

-- Una sola delega VIVA per coppia (soggetto, utente). Gli inviti non ancora
-- accettati non hanno user_id e non partecipano al vincolo; le righe revocate
-- nemmeno, altrimenti una revoca sarebbe definitiva: dopo un ripensamento la
-- stessa persona deve poter essere invitata di nuovo e accettare.
drop index if exists public.uq_subject_delegates_subject_user;
create unique index if not exists uq_subject_delegates_subject_user
  on public.subject_delegates (subject_id, user_id)
  where user_id is not null and status <> 'revoked';

create index if not exists idx_subject_delegates_user_status
  on public.subject_delegates (user_id, status) where user_id is not null;
create index if not exists idx_subject_delegates_subject_status
  on public.subject_delegates (subject_id, status);
create index if not exists idx_subject_delegates_email_status
  on public.subject_delegates (invited_email, status);

drop trigger if exists trg_subject_delegates_updated_at on public.subject_delegates;
create trigger trg_subject_delegates_updated_at
  before update on public.subject_delegates
  for each row execute function public.set_updated_at();

-- Il ruolo 'owner' non si assegna: lo si e'. Vale solo per chi amministra
-- quel profilo gestito (profiles.managed_by = user_id). Un check non basta,
-- la condizione sta su un'altra tabella.
create or replace function public.m24_subject_delegate_owner_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.role = 'owner' then
    if new.user_id is null
       or not exists (select 1 from public.profiles p
                       where p.id = new.subject_id
                         and p.managed_by = new.user_id) then
      raise exception 'owner_requires_managed_profile' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
revoke execute on function public.m24_subject_delegate_owner_guard()
  from public, anon, authenticated;

drop trigger if exists trg_subject_delegates_owner_guard on public.subject_delegates;
create trigger trg_subject_delegates_owner_guard
  before insert or update on public.subject_delegates
  for each row execute function public.m24_subject_delegate_owner_guard();

-- ---------------------------------------------------------------------------
-- 4. RLS: forzata, una sola policy di lettura
--
--    Si vede la riga se riguarda il chiamante: perche' e' il delegato, perche'
--    e' il soggetto, o perche' ha mandato lui l'invito (il caso dell'owner che
--    invita un caregiver sul profilo del figlio).
--    Nessuna policy di insert, update o delete: le tre funzioni sono
--    security definer e appartengono a postgres, che ha bypassrls.
-- ---------------------------------------------------------------------------
alter table public.subject_delegates enable row level security;
alter table public.subject_delegates force  row level security;

drop policy if exists subject_delegates_select on public.subject_delegates;
create policy subject_delegates_select on public.subject_delegates
  for select to authenticated
  using (user_id = auth.uid() or subject_id = auth.uid() or created_by = auth.uid());

revoke all on public.subject_delegates from public, anon, authenticated;
grant select on public.subject_delegates to authenticated;

-- ---------------------------------------------------------------------------
-- 5. can_access_subject — il punto unico, esteso alla delega
--
--    Il nome del parametro non si puo' cambiare con create or replace: resta
--    subject_id. Dentro la sottoquery la colonna omonima di subject_delegates
--    avrebbe la precedenza, quindi il parametro si riferisce come $1.
--    Lo scope non entra ancora nel filtro: una delega attiva vede tutto il
--    soggetto. Il filtro per scope arriva con le schermate di P11-A2/A3.
-- ---------------------------------------------------------------------------
create or replace function public.can_access_subject(subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select subject_id is not null
     and (
       subject_id = auth.uid()
       or exists (
         select 1
           from public.subject_delegates d
          where d.subject_id = $1
            and d.user_id    = auth.uid()
            and d.status     = 'active')
     );
$$;

comment on function public.can_access_subject(uuid) is
  'Unico punto di controllo dell''accesso clinico: vero per il soggetto stesso '
  'e per chi ha una delega attiva in subject_delegates. security definer, '
  'stable, search_path fisso. I legami medico-paziente entreranno qui, non '
  'nelle policy.';

-- ---------------------------------------------------------------------------
-- 6. profiles: lettura con can_access_subject, scrittura solo propria
--
--    Un caregiver deve poter leggere il nome, la data di nascita e il sesso di
--    chi assiste (servono a tutte le schermate cliniche), ma non modificarli:
--    l'anagrafica di un profilo gestito la cambia il suo owner dalle funzioni
--    di P11-A2, non con un update diretto.
-- ---------------------------------------------------------------------------
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using (public.can_access_subject(id));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- 7. my_subjects — l'elenco del selettore di soggetto
--
--    Se stesso per primo, poi i soggetti con delega attiva. 'managed' dice
--    all'interfaccia se e' un profilo gestito (figlio, anziano) o una persona
--    che ha concesso la delega.
-- ---------------------------------------------------------------------------
create or replace function public.my_subjects()
returns table (
  subject_id   uuid,
  full_name    text,
  role         delegate_role,
  relationship text,
  managed      boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.full_name, 'owner'::delegate_role, null::text, (p.managed_by is not null)
    from public.profiles p
   where p.id = auth.uid()
     and p.deleted_at is null
  union all
  select p.id, p.full_name, d.role, d.relationship, (p.managed_by is not null)
    from public.subject_delegates d
    join public.profiles p on p.id = d.subject_id
   where d.user_id = auth.uid()
     and d.status  = 'active'
     and p.deleted_at is null
   order by 3, 2 nulls last;
$$;

revoke execute on function public.my_subjects() from public, anon;
grant execute on function public.my_subjects() to authenticated;

comment on function public.my_subjects() is
  'I soggetti che il chiamante puo'' aprire: se stesso piu'' quelli con delega '
  'attiva. Colonne subject_id, full_name, role, relationship, managed '
  '(vero per un profilo gestito). Solo authenticated.';

-- ---------------------------------------------------------------------------
-- 8. delegate_invite — invita un indirizzo
--
--    Puo' invitare il soggetto stesso oppure il suo owner (il caso del figlio:
--    il bambino non invita nessuno, lo fa il genitore). Massimo cinque deleghe
--    vive per soggetto, contando invitate e attive: la delega e' una chiave di
--    casa, non una lista di distribuzione.
-- ---------------------------------------------------------------------------
create or replace function public.delegate_invite(
  p_subject uuid,
  p_email   text,
  p_scope   jsonb default '{"all": true}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_live  int;
  v_id    uuid;
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if v_uid is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  -- Soggetto stesso oppure owner del profilo gestito. can_access_subject non
  -- basta: un caregiver non invita altri caregiver.
  if v_uid <> p_subject
     and not exists (select 1 from public.subject_delegates d
                      where d.subject_id = p_subject
                        and d.user_id    = v_uid
                        and d.role       = 'owner'
                        and d.status     = 'active') then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if v_email = '' or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'invalid_email' using errcode = '22023';
  end if;
  if coalesce(public.m24_valid_share_scope(coalesce(p_scope, '{"all": true}'::jsonb)), false) = false then
    raise exception 'invalid_scope' using errcode = '22023';
  end if;
  if exists (select 1 from auth.users u
              where u.id = p_subject and lower(u.email) = v_email) then
    raise exception 'invalid_email' using errcode = '22023';
  end if;

  select count(*)::int into v_live
    from public.subject_delegates d
   where d.subject_id = p_subject
     and d.status in ('invited', 'active');

  if coalesce(v_live, 0) >= 5 then
    raise exception 'too_many_delegates' using errcode = 'P0001';
  end if;

  if exists (select 1 from public.subject_delegates d
              where d.subject_id    = p_subject
                and d.invited_email = v_email
                and d.status in ('invited', 'active')) then
    raise exception 'already_invited' using errcode = 'P0001';
  end if;

  insert into public.subject_delegates(subject_id, invited_email, role, scope, status, created_by)
  values (p_subject, v_email, 'caregiver',
          coalesce(p_scope, '{"all": true}'::jsonb), 'invited', v_uid)
  returning id into v_id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'delegate.invited', 'subject_delegates', v_id, p_subject);

  return jsonb_build_object('id', v_id, 'status', 'invited', 'role', 'caregiver');
end;
$$;

revoke execute on function public.delegate_invite(uuid, text, jsonb) from public, anon;
grant execute on function public.delegate_invite(uuid, text, jsonb) to authenticated;

comment on function public.delegate_invite(uuid, text, jsonb) is
  'Invita un indirizzo come caregiver di un soggetto. Solo il soggetto stesso '
  'o il suo owner (42501); p_subject nullo, indirizzo malformato, indirizzo del '
  'soggetto stesso e scope non valido sono 22023; oltre cinque deleghe vive '
  '(invitate o attive) too_many_delegates e indirizzo gia'' invitato '
  'already_invited (P0001). Audit delegate.invited. Non manda email: lo fa la '
  'Edge Function di P11-A2.';

-- ---------------------------------------------------------------------------
-- 9. delegate_accept — accetta chi ha quell'indirizzo, e nessun altro
--
--    Il confronto e' con l'email dell'account in auth.users, non con un dato
--    che il client possa dichiarare. Un invito non accettato non da' nulla.
-- ---------------------------------------------------------------------------
create or replace function public.delegate_accept(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := auth.uid();
  v_email text;
  d       public.subject_delegates%rowtype;
begin
  if p_id is null then
    raise exception 'invalid_delegate' using errcode = '22023';
  end if;
  if v_uid is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select lower(u.email) into v_email from auth.users u where u.id = v_uid;

  select * into d from public.subject_delegates where id = p_id for update;
  if not found then
    raise exception 'invalid_delegate' using errcode = '22023';
  end if;

  if d.status <> 'invited' then
    raise exception 'not_invited' using errcode = 'P0001';
  end if;
  if v_email is null or v_email <> d.invited_email then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if d.subject_id = v_uid then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  update public.subject_delegates
     set user_id     = v_uid,
         status      = 'active',
         accepted_at = now()
   where id = p_id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'delegate.accepted', 'subject_delegates', p_id, d.subject_id);

  return jsonb_build_object('id', p_id, 'subject_id', d.subject_id, 'status', 'active');
end;
$$;

revoke execute on function public.delegate_accept(uuid) from public, anon;
grant execute on function public.delegate_accept(uuid) to authenticated;

comment on function public.delegate_accept(uuid) is
  'Accetta un invito: solo l''utente la cui email in auth.users coincide con '
  'invited_email (42501); invito inesistente 22023, invito gia'' accettato o '
  'revocato not_invited (P0001). Valorizza user_id, status active e '
  'accepted_at. Audit delegate.accepted.';

-- ---------------------------------------------------------------------------
-- 10. delegate_revoke — la revoca la puo' fare chiunque sia coinvolto
--
--     Il soggetto, il suo owner e il delegato stesso. Idempotente: una riga
--     gia' revocata non produce un secondo audit.
-- ---------------------------------------------------------------------------
create or replace function public.delegate_revoke(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  d     public.subject_delegates%rowtype;
begin
  if p_id is null then
    raise exception 'invalid_delegate' using errcode = '22023';
  end if;
  if v_uid is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select * into d from public.subject_delegates where id = p_id for update;
  if not found then
    raise exception 'invalid_delegate' using errcode = '22023';
  end if;

  if v_uid <> d.subject_id
     and v_uid is distinct from d.user_id
     and not exists (select 1 from public.subject_delegates o
                      where o.subject_id = d.subject_id
                        and o.user_id    = v_uid
                        and o.role       = 'owner'
                        and o.status     = 'active') then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  -- La delega 'owner' non si revoca: e' l'unico modo di raggiungere un profilo
  -- gestito, e toglierla lascerebbe un utente ombra senza nessuno che possa
  -- aprirlo. Il profilo gestito si chiude con family_member_remove.
  if d.role = 'owner' then
    raise exception 'owner_not_revocable' using errcode = 'P0001';
  end if;

  if d.status = 'revoked' then
    return jsonb_build_object('id', p_id, 'status', 'revoked', 'changed', false);
  end if;

  update public.subject_delegates
     set status     = 'revoked',
         revoked_at = now()
   where id = p_id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'delegate.revoked', 'subject_delegates', p_id, d.subject_id);

  return jsonb_build_object('id', p_id, 'status', 'revoked', 'changed', true);
end;
$$;

revoke execute on function public.delegate_revoke(uuid) from public, anon;
grant execute on function public.delegate_revoke(uuid) to authenticated;

comment on function public.delegate_revoke(uuid) is
  'Revoca una delega: il soggetto, il suo owner o il delegato stesso (42501); '
  'delega inesistente 22023; una delega ''owner'' non si revoca '
  '(owner_not_revocable, P0001): si usa family_member_remove. Idempotente: su '
  'una riga gia'' revocata non scrive nulla e restituisce changed = false. '
  'Audit delegate.revoked.';

-- ---------------------------------------------------------------------------
-- 11. subject_view_log — chi apre il profilo di un altro lascia una traccia
--
--     Sul proprio soggetto non si scrive nulla: l'audit servirebbe a dire che
--     una persona ha guardato i propri dati. Scrive solo quando l'attore e'
--     diverso dal soggetto, ed e' la schermata a chiamarla all'apertura.
-- ---------------------------------------------------------------------------
create or replace function public.subject_view_log(p_subject uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if v_uid is null or not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if v_uid = p_subject then
    return false;
  end if;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'subject.viewed', 'profiles', p_subject, p_subject);

  return true;
end;
$$;

revoke execute on function public.subject_view_log(uuid) from public, anon;
grant execute on function public.subject_view_log(uuid) to authenticated;

comment on function public.subject_view_log(uuid) is
  'Registra in audit_log l''apertura del profilo di un altro soggetto '
  '(''subject.viewed''). Richiede can_access_subject (42501); p_subject nullo '
  'e'' 22023. Sul proprio soggetto non scrive nulla e restituisce false.';

-- ---------------------------------------------------------------------------
-- 12. my_pending_invitations — gli inviti che aspettano il chiamante
--
--     Il confronto e' con l'email dell'account in auth.users, mai con un dato
--     dichiarato dal client: e' la stessa regola di delegate_accept. Serve la
--     security definer perche' auth.users non e' leggibile da authenticated e
--     perche' la policy di subject_delegates non mostra le righe di un invito
--     che il chiamante non ha ancora accettato.
-- ---------------------------------------------------------------------------
create or replace function public.my_pending_invitations()
returns table (
  id            uuid,
  subject_id    uuid,
  subject_name  text,
  relationship  text,
  created_at    timestamptz,
  invited_by    text
)
language sql
stable
security definer
set search_path = public
as $$
  select d.id, d.subject_id, s.full_name, d.relationship, d.created_at, c.full_name
    from public.subject_delegates d
    join auth.users u on u.id = auth.uid()
    left join public.profiles s on s.id = d.subject_id
    left join public.profiles c on c.id = d.created_by
   where d.status = 'invited'
     and d.invited_email = lower(u.email)
   order by d.created_at desc;
$$;

revoke execute on function public.my_pending_invitations() from public, anon;
grant execute on function public.my_pending_invitations() to authenticated;

comment on function public.my_pending_invitations() is
  'Gli inviti in stato invited il cui invited_email coincide con l''email del '
  'chiamante in auth.users. Colonne id, subject_id, subject_name, '
  'relationship, created_at, invited_by (nome di chi ha invitato). Solo '
  'authenticated; si accetta con delegate_accept(id).';

-- ---------------------------------------------------------------------------
-- 13. family.max_managed_profiles — quanti profili gestiti per utente
--
--     Stesso modo della 0015: il valore sta in platform_settings, is_public
--     perche' l'interfaccia deve poter dire "hai esaurito i posti" prima di
--     tentare; la lettura e' protetta da un fallback, cosi' una impostazione
--     cancellata non blocca la registrazione.
-- ---------------------------------------------------------------------------
insert into public.platform_settings(key, value, is_public, description) values
 ('family.max_managed_profiles','3',true,
  'Quanti profili gestiti (figli, anziani) un utente puo'' amministrare.')
on conflict(key) do nothing;

insert into public.platform_settings_history(key, value, version, changed_by)
select key, value, version, updated_by from public.platform_settings
 where key = 'family.max_managed_profiles'
on conflict(key, version) do nothing;

create or replace function public.family_managed_limit()
returns int
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit int;
begin
  begin
    v_limit := (public.platform_setting('family.max_managed_profiles') #>> '{}')::int;
  exception when others then
    v_limit := null;
  end;
  return greatest(coalesce(v_limit, 3), 0);
end;
$$;

revoke execute on function public.family_managed_limit() from public, anon;
grant execute on function public.family_managed_limit() to authenticated, service_role;

comment on function public.family_managed_limit() is
  'Quanti profili gestiti puo'' avere un utente: platform_settings '
  '''family.max_managed_profiles'', seminata a 3 e is_public. Se '
  'l''impostazione manca restituisce 3.';

-- ---------------------------------------------------------------------------
-- 14. family_member_register — chiude la creazione di un profilo gestito
--
--     L'utente ombra lo crea la Edge Function con il service_role (A2): qui
--     si chiude il giro lato dati, in una transazione sola. Stesso controllo
--     di data_export_finish: solo il service_role, perche' il chiamante non
--     dimostra nulla sull'utente appena creato.
--
--     I consensi non si ereditano per comodita': un profilo gestito senza
--     health_data e ai_processing non potrebbe ricevere nessun documento, e
--     chi ha la potesta' genitoriale li ha gia' prestati per se'. Si copia la
--     stessa version e lo stesso locale, cosi' il registro resta leggibile.
-- ---------------------------------------------------------------------------
create or replace function public.family_member_register(
  p_subject      uuid,
  p_owner        uuid,
  p_full_name    text,
  p_birth_date   date default null,
  p_gender       text default null,
  p_relationship text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count int;
  v_limit int;
  v_name  text := nullif(btrim(coalesce(p_full_name, '')), '');
  v_rel   text := nullif(btrim(coalesce(p_relationship, '')), '');
  v_email text;
  v_id    uuid;
  v_cons  int := 0;
  v_managed   uuid;
  v_onboarded timestamptz;
  v_exists    boolean := false;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if p_subject is null or p_owner is null or p_subject = p_owner then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if v_name is null or char_length(v_name) > 120 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if p_gender is not null
     and p_gender not in ('female', 'male', 'other', 'undisclosed') then
    raise exception 'invalid_gender' using errcode = '22023';
  end if;
  if v_rel is not null and char_length(v_rel) > 60 then
    raise exception 'invalid_relationship' using errcode = '22023';
  end if;

  select lower(u.email) into v_email from auth.users u where u.id = p_owner;
  if v_email is null then
    raise exception 'invalid_owner' using errcode = '22023';
  end if;

  -- (R3) Il soggetto deve essere un utente ombra appena creato e mai usato.
  -- Un profilo gia' gestito da qualcuno, oppure gia' passato dall'onboarding
  -- (quindi un account vero, con una persona dietro), non si puo' trasformare
  -- in profilo gestito: sarebbe un modo per appropriarsi di un account.
  select true, p.managed_by, p.onboarded_at
    into v_exists, v_managed, v_onboarded
    from public.profiles p
   where p.id = p_subject;
  if not coalesce(v_exists, false)
     or v_managed is not null
     or v_onboarded is not null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;

  v_limit := public.family_managed_limit();
  select count(*)::int into v_count
    from public.profiles p
   where p.managed_by = p_owner
     and p.deleted_at is null;
  if coalesce(v_count, 0) >= v_limit then
    raise exception 'managed_limit' using errcode = 'P0001';
  end if;

  -- Il profilo esiste gia': lo ha creato il trigger on_auth_user_created
  -- quando la Edge Function ha inserito l'utente ombra. Lingua e fuso orario
  -- si copiano dall'owner: le notifiche e le date le legge lui.
  update public.profiles p
     set managed_by   = p_owner,
         full_name    = v_name,
         birth_date   = coalesce(p_birth_date, p.birth_date),
         gender       = coalesce(p_gender, p.gender),
         language     = o.language,
         timezone     = o.timezone,
         onboarded_at = coalesce(p.onboarded_at, now())
    from public.profiles o
   where p.id = p_subject
     and o.id = p_owner;
  if not found then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;

  -- La delega 'owner' nasce gia' attiva: non c'e' nessuno da invitare, il
  -- profilo gestito non ha una casella di posta.
  insert into public.subject_delegates(
    subject_id, user_id, invited_email, role, relationship, status,
    created_by, accepted_at)
  values (p_subject, p_owner, v_email, 'owner', v_rel, 'active', p_owner, now())
  returning id into v_id;

  insert into public.consents(user_id, type, version, granted, granted_at, locale)
  select p_subject, c.type, c.version, true, now(), c.locale
    from (select distinct on (x.type) x.type, x.version, x.locale, x.granted
            from public.consents x
           where x.user_id = p_owner
             and x.type in ('health_data', 'ai_processing')
           order by x.type, x.granted_at desc) c
   where c.granted;
  get diagnostics v_cons = row_count;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (p_owner, 'family.member_registered', 'profiles', p_subject, p_subject);

  return jsonb_build_object(
    'subject_id', p_subject,
    'delegate_id', v_id,
    'consents_copied', v_cons,
    'managed_count', coalesce(v_count, 0) + 1,
    'managed_limit', v_limit
  );
end;
$$;

revoke execute on function
  public.family_member_register(uuid, uuid, text, date, text, text)
  from public, anon, authenticated;
grant execute on function
  public.family_member_register(uuid, uuid, text, date, text, text)
  to service_role;

comment on function public.family_member_register(uuid, uuid, text, date, text, text) is
  'Chiude la creazione di un profilo gestito: profiles.managed_by, anagrafica, '
  'lingua e fuso orario copiati dall''owner, onboarded_at, delega ''owner'' '
  'attiva e copia dei consensi health_data e ai_processing dell''owner. Solo '
  'service_role (42501); parametri non validi 22023, e cosi'' pure p_subject '
  'uguale a p_owner, un profilo gia'' gestito (managed_by valorizzato) e un '
  'profilo gia'' passato dall''onboarding (onboarded_at non nullo): un account '
  'vero non diventa un profilo gestito. Oltre '
  'family_managed_limit() profili gestivi vivi managed_limit (P0001). Audit '
  '''family.member_registered'' con attore l''owner.';

-- ---------------------------------------------------------------------------
-- 15. family_member_update — l'anagrafica la cambia solo l'owner
--
--     Un caregiver legge, non scrive: la policy profiles_update_own gli nega
--     gia' l'update diretto, qui si nega anche la via della funzione.
-- ---------------------------------------------------------------------------
create or replace function public.family_member_update(
  p_subject      uuid,
  p_full_name    text default null,
  p_birth_date   date default null,
  p_gender       text default null,
  p_relationship text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_name text := nullif(btrim(coalesce(p_full_name, '')), '');
  v_rel  text := nullif(btrim(coalesce(p_relationship, '')), '');
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if v_uid is null
     or not exists (select 1 from public.subject_delegates d
                     where d.subject_id = p_subject
                       and d.user_id    = v_uid
                       and d.role       = 'owner'
                       and d.status     = 'active') then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if v_name is not null and char_length(v_name) > 120 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if p_gender is not null
     and p_gender not in ('female', 'male', 'other', 'undisclosed') then
    raise exception 'invalid_gender' using errcode = '22023';
  end if;
  if v_rel is not null and char_length(v_rel) > 60 then
    raise exception 'invalid_relationship' using errcode = '22023';
  end if;

  update public.profiles
     set full_name  = coalesce(v_name, full_name),
         birth_date = coalesce(p_birth_date, birth_date),
         gender     = coalesce(p_gender, gender)
   where id = p_subject
     and deleted_at is null;
  if not found then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;

  if v_rel is not null then
    update public.subject_delegates
       set relationship = v_rel
     where subject_id = p_subject
       and user_id    = v_uid
       and role       = 'owner'
       and status     = 'active';
  end if;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'family.member_updated', 'profiles', p_subject, p_subject);

  return jsonb_build_object('subject_id', p_subject, 'updated', true);
end;
$$;

revoke execute on function
  public.family_member_update(uuid, text, date, text, text)
  from public, anon;
grant execute on function
  public.family_member_update(uuid, text, date, text, text)
  to authenticated;

comment on function public.family_member_update(uuid, text, date, text, text) is
  'Aggiorna nome, data di nascita, sesso e relazione di un profilo gestito. '
  'Solo l''owner con delega attiva (42501); soggetto nullo, inesistente o gia'' '
  'cancellato 22023, parametri fuori misura 22023. I parametri nulli non '
  'cambiano nulla. Audit ''family.member_updated''.';

-- ---------------------------------------------------------------------------
-- 16. family_member_remove — il profilo gestito si chiude, non si cancella
--
--     Stessa forma di account_close: si spengono le porte verso l'esterno e
--     si marca deleted_at. La cancellazione vera dei dati clinici la fa
--     purge_deleted_accounts a trenta giorni, che legge proprio deleted_at.
--     Anche la delega 'owner' passa a revoked: da questo momento
--     can_access_subject e' falsa per tutti, compreso chi ha chiesto la
--     rimozione.
-- ---------------------------------------------------------------------------
-- 16a. Il corpo vero, senza controllo di chi chiama. Lo usano due strade:
--      family_member_remove (l'owner che chiude il profilo a mano) e
--      soft_delete_account (l'owner che chiude il proprio account e si porta
--      dietro i profili che amministrava). Nessun ruolo applicativo puo'
--      eseguirla: il controllo di accesso sta nelle due funzioni chiamanti.
create or replace function public.m24_family_member_remove_internal(
  p_subject uuid,
  p_actor   uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delegates int := 0;
  v_links     int := 0;
  v_card      int := 0;
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;

  update public.profiles
     set deleted_at = now()
   where id = p_subject
     and deleted_at is null;

  update public.subject_delegates
     set status     = 'revoked',
         revoked_at = now()
   where subject_id = p_subject
     and status <> 'revoked';
  get diagnostics v_delegates = row_count;

  update public.share_links
     set revoked_at = now()
   where subject_id = p_subject
     and revoked_at is null;
  get diagnostics v_links = row_count;

  delete from public.emergency_cards where subject_id = p_subject;
  get diagnostics v_card = row_count;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (p_actor, 'family.member_removed', 'profiles', p_subject, p_subject);

  return jsonb_build_object(
    'subject_id',             p_subject,
    'delegates_revoked',      v_delegates,
    'links_revoked',          v_links,
    'emergency_card_removed', v_card
  );
end;
$$;

revoke execute on function public.m24_family_member_remove_internal(uuid, uuid)
  from public, anon, authenticated;

comment on function public.m24_family_member_remove_internal(uuid, uuid) is
  'Corpo della chiusura di un profilo gestito, senza controllo del chiamante: '
  'deleted_at, deleghe revocate, link revocati, scheda di emergenza '
  'cancellata, audit ''family.member_removed'' con attore p_actor. Interna: la '
  'chiamano family_member_remove e soft_delete_account.';

-- 16b. La porta d'ingresso: l'owner, e nessun altro.
create or replace function public.family_member_remove(p_subject uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if v_uid is null
     or not exists (select 1 from public.subject_delegates d
                     where d.subject_id = p_subject
                       and d.user_id    = v_uid
                       and d.role       = 'owner'
                       and d.status     = 'active') then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  return public.m24_family_member_remove_internal(p_subject, v_uid);
end;
$$;

revoke execute on function public.family_member_remove(uuid) from public, anon;
grant execute on function public.family_member_remove(uuid) to authenticated;

comment on function public.family_member_remove(uuid) is
  'Chiude un profilo gestito: profiles.deleted_at, tutte le deleghe del '
  'soggetto (owner compresa) a revoked, link di condivisione attivi revocati e '
  'scheda di emergenza cancellata. Solo l''owner con delega attiva (42501); '
  'p_subject nullo 22023. Audit ''family.member_removed''. La cancellazione '
  'dei dati clinici resta a purge_deleted_accounts, trenta giorni dopo.';

-- ---------------------------------------------------------------------------
-- 17. soft_delete_account — chi chiude il proprio account si porta dietro i
--     profili che amministrava e smette di essere caregiver di chiunque
--
--     Senza questo, chiudere l'account di un genitore lascerebbe i figli come
--     utenti ombra vivi e irraggiungibili (la delega 'owner' e' l'unica porta,
--     e nessuno puo' piu' aprirla), e lascerebbe l'uscente in grado di leggere
--     i dati dei soggetti che lo avevano delegato finche' la sua riga di
--     auth.users esiste, cioe' per altri trenta giorni.
--
--     Il corpo precedente (soft delete del proprio profilo + log_audit) resta
--     identico: qui si aggiungono soltanto i due passi finali.
-- ---------------------------------------------------------------------------
create or replace function public.soft_delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  r     record;
begin
  if v_uid is null then
    raise exception 'unauthenticated';
  end if;

  update public.profiles
     set deleted_at = now()
   where id = v_uid;

  perform public.log_audit('account_soft_deleted', 'profiles', v_uid, v_uid, null);

  -- 1. I profili gestiti si chiudono come se l'owner avesse premuto "rimuovi"
  --    su ciascuno: stessa cascata, stesso audit, stesso conto alla rovescia.
  for r in
    select p.id from public.profiles p
     where p.managed_by = v_uid
       and p.deleted_at is null
  loop
    perform public.m24_family_member_remove_internal(r.id, v_uid);
  end loop;

  -- 2. Un account chiuso non resta caregiver di nessuno, ne' lascia caregiver
  --    attivi su di se': tutte le deleghe vive che lo riguardano, da una parte
  --    o dall'altra, passano a revoked.
  update public.subject_delegates
     set status     = 'revoked',
         revoked_at = now()
   where (subject_id = v_uid or user_id = v_uid)
     and status <> 'revoked';
end;
$$;

revoke execute on function public.soft_delete_account() from public, anon;
grant execute on function public.soft_delete_account() to authenticated;

comment on function public.soft_delete_account() is
  'Chiusura dell''account da parte dell''utente: profiles.deleted_at, audit '
  '''account_soft_deleted'', chiusura di tutti i profili gestiti '
  '(m24_family_member_remove_internal) e revoca di tutte le deleghe vive in '
  'cui compare come soggetto o come delegato. La cancellazione dei dati resta '
  'a purge_deleted_accounts, trenta giorni dopo.';

-- ---------------------------------------------------------------------------
-- 18. account_close (0028) — stessa revoca, dal lato del servizio
--
--     Corpo identico alla 0028 nei quattro passi; in coda la revoca delle
--     deleghe del soggetto, perche' la Edge Function chiama questa e non
--     soft_delete_account per la parte di service_role, e il risultato deve
--     essere lo stesso anche quando la chiusura nasce da un processo interno.
-- ---------------------------------------------------------------------------
create or replace function public.account_close(p_subject uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_links     int := 0;
  v_questions int := 0;
  v_card      int := 0;
  v_exports   int := 0;
  v_delegates int := 0;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;

  update public.share_links
     set revoked_at = now()
   where subject_id = p_subject
     and revoked_at is null;
  get diagnostics v_links = row_count;

  delete from public.emergency_cards where subject_id = p_subject;
  get diagnostics v_card = row_count;

  update public.questions
     set status = 'closed'
   where subject_id = p_subject
     and status <> 'closed';
  get diagnostics v_questions = row_count;

  update public.data_exports
     set status     = 'expired',
         expires_at = least(coalesce(expires_at, now()), now())
   where subject_id = p_subject
     and status = 'ready';
  get diagnostics v_exports = row_count;

  -- Nuovo in 0029: le deleghe familiari sono una porta come le altre, e
  -- valgono nei due sensi (chi entrava dal soggetto, e il soggetto che
  -- entrava da altri).
  update public.subject_delegates
     set status     = 'revoked',
         revoked_at = now()
   where (subject_id = p_subject or user_id = p_subject)
     and status <> 'revoked';
  get diagnostics v_delegates = row_count;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (auth.uid(), 'account.closed', 'profiles', p_subject, p_subject);

  return jsonb_build_object(
    'links_revoked',          v_links,
    'questions_closed',       v_questions,
    'emergency_card_removed', v_card,
    'exports_expired',        v_exports,
    'delegates_revoked',      v_delegates
  );
end;
$$;

revoke execute on function public.account_close(uuid)
  from public, anon, authenticated;
grant execute on function public.account_close(uuid) to service_role;

comment on function public.account_close(uuid) is
  'Chiusura dell''account: revoca tutti i link di condivisione attivi, cancella '
  'la scheda di emergenza (il QR pubblico smette di funzionare subito), chiude '
  'le domande al medico non chiuse, segna scaduti gli export pronti e revoca '
  'tutte le deleghe familiari vive in cui il soggetto compare come subject_id '
  'o come user_id. Audit ''account.closed'' con attore auth.uid() se la '
  'chiamata nasce da una sessione, altrimenti nullo. Solo service_role '
  '(42501); p_subject nullo e'' 22023. Restituisce {links_revoked, '
  'questions_closed, emergency_card_removed, exports_expired, '
  'delegates_revoked}; idempotente, la seconda chiamata restituisce zeri. Non '
  'cancella dati clinici: quelli sono di purge_subject_data a trenta giorni.';

-- ---------------------------------------------------------------------------
-- 19. purge_subject_data (0026/0027) — subject_delegates nell'elenco
--
--     La cascata da auth.users svuoterebbe comunque le righe, ma la purge e'
--     l'elenco esplicito e leggibile di che cosa sparisce, e deve funzionare
--     anche su un soggetto il cui account auth resta (un profilo gestito
--     chiuso prima dell'owner). La condizione vale nei due sensi: le deleghe
--     ricevute e quelle concesse.
--
--     Per il resto la funzione e' identica alla 0027: stesso ordine, stesso
--     interruttore, stesso valore di ritorno.
-- ---------------------------------------------------------------------------
create or replace function public.purge_subject_data(p_subject uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result  jsonb := '{}'::jsonb;
  v_targets text[] := array[
    -- modulo Medico (M9): prima lo snapshot, poi il registro, poi i link
    'dossier_snapshots',      'subject_id = $1',
    'questions',              'subject_id = $1',
    'share_link_opens',       'share_link_id in (select id from public.share_links where subject_id = $1)',
    'share_links',            'subject_id = $1',
    'emergency_cards',        'subject_id = $1',
    -- spiegazioni e consumi dell'IA
    'explanations',           'subject_id = $1',
    'explanation_usage',      'subject_id = $1',
    'analysis_usage',         'subject_id = $1',
    -- motore: avvisi, esami consigliati, questionari, punteggi, organi
    'alerts',                 'subject_id = $1',
    'recommendations',        'subject_id = $1',
    'questionnaire_answers',  'subject_id = $1',
    'risk_scores',            'subject_id = $1',
    'organ_states',           'subject_id = $1',
    -- valori clinici: prima delle estrazioni e dei documenti
    'observations',           'subject_id = $1',
    'biomarker_watch',        'subject_id = $1',
    'symptoms',               'subject_id = $1',
    'extractions',            'subject_id = $1',
    -- archivio
    'document_pages',         'document_id in (select id from public.documents where subject_id = $1)',
    'documents',              'subject_id = $1 or owner_id = $1',
    -- famiglia: le deleghe ricevute e quelle concesse
    'subject_delegates',      'subject_id = $1 or user_id = $1',
    -- export dei dati, soglie personali del medico e consensi
    'data_exports',           'subject_id = $1',
    'threshold_overrides',    'subject_id = $1 or doctor_id = $1',
    'consents',               'user_id = $1'
  ];
  v_table text;
  v_where text;
  v_rows  bigint;
  i       int;
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;

  perform set_config('medical24.allow_purge', 'on', true);

  i := 1;
  while i < array_length(v_targets, 1) loop
    v_table := v_targets[i];
    v_where := v_targets[i + 1];
    i := i + 2;

    -- Tabelle previste dal piano ma non ancora presenti nello schema
    -- (explanation_usage, analysis_usage) vengono semplicemente saltate.
    if to_regclass('public.' || quote_ident(v_table)) is null then
      continue;
    end if;

    execute format('delete from public.%I where %s', v_table, v_where) using p_subject;
    get diagnostics v_rows = row_count;
    v_result := v_result || jsonb_build_object(v_table, v_rows);
  end loop;

  perform set_config('medical24.allow_purge', 'off', true);
  return v_result;
exception when others then
  -- L'interruttore non resta mai aperto: nemmeno quando la purge fallisce a
  -- meta' strada e il resto della transazione prosegue.
  perform set_config('medical24.allow_purge', 'off', true);
  raise;
end;
$$;

revoke execute on function public.purge_subject_data(uuid)
  from public, anon, authenticated, service_role;

comment on function public.purge_subject_data(uuid) is
  'Diritto all''oblio: cancella tutte le righe del soggetto dalle tabelle che '
  'portano subject_id, owner_id, user_id o doctor_id senza cascata utile da '
  'auth.users, nell''ordine imposto dalle chiavi esterne e dalle guardie '
  'append-only. Comprende data_exports e subject_delegates (sia le deleghe '
  'ricevute sia quelle concesse); per threshold_overrides cancella anche le '
  'soglie scritte dal soggetto come medico. Alza medical24.allow_purge per il '
  'tempo della sola cancellazione e lo rimette a ''off'' anche in caso di '
  'errore. Restituisce {tabella: righe}. audit_log non viene toccato. Nessun '
  'ruolo applicativo puo'' eseguirla: la chiama soltanto '
  'purge_deleted_accounts.';

-- purge_deleted_accounts (0026) non cambia: il suo ciclo e'
--   select id from public.profiles where deleted_at < now() - interval '30 days'
-- e un profilo gestito e' una riga di profiles come le altre, con deleted_at
-- scritto da m24_family_member_remove_internal. Viene quindi purgato e il suo
-- utente ombra rimosso da auth.users allo scadere dei trenta giorni, senza
-- dipendere dalla cascata di profiles.managed_by.

insert into public.app_migrations(name) values ('0029_family_delegates')
  on conflict do nothing;
