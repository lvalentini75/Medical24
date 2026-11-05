-- ============================================================================
-- Medical 24 — 0030 FAMIGLIA, HARDENING DELLO SCHEMA (P11-A5a) — modulo M5
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- Nasce dalla revisione di sicurezza del modulo Famiglia (P11-A-SEC). Non
-- aggiunge tabelle ne' colonne: ridefinisce sei funzioni della 0029 copiandone
-- il corpo e cambiando soltanto cio' che segue.
--
--   1. can_access_subject            un profilo con deleted_at non apre piu'
--                                    nulla, nemmeno a se stesso
--   2. delegate_invite               finche' lo scope non filtra le letture,
--                                    l'unico scope ammesso e' {"all": true}
--   3. delegate_accept               l'email dell'account deve essere
--      my_pending_invitations        confermata
--   4. family_member_register        lock per owner prima del conteggio e
--                                    dichiarazione di responsabilita'
--                                    genitoriale o di delega, obbligatoria
--   5. m24_family_member_remove_internal
--                                    chiude anche le domande al medico e fa
--                                    scadere gli export pronti, come
--                                    account_close
--
-- Niente schermate, niente Edge Function. Idempotente: create or replace,
-- drop function if exists sulla firma vecchia di family_member_register.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. can_access_subject — un profilo chiuso e' una porta chiusa
--
--    La 0029 lasciava passare il soggetto stesso e il suo delegato attivo
--    senza guardare profiles.deleted_at: un account in attesa di purga (trenta
--    giorni) continuava a leggere e, peggio, un profilo gestito "rimosso"
--    restava leggibile attraverso una delega sopravvissuta. Da qui in poi la
--    vita del profilo e' la prima condizione, e vale anche per se stessi: chi
--    ha chiesto la chiusura non vede piu' i dati clinici, li recupera solo
--    annullando la chiusura prima dei trenta giorni.
--
--    Il nome del parametro non si puo' cambiare con create or replace: resta
--    subject_id, e dentro le sottoquery si riferisce come $1 perche' la
--    colonna omonima di subject_delegates avrebbe la precedenza.
-- ---------------------------------------------------------------------------
create or replace function public.can_access_subject(subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select subject_id is not null
     and exists (select 1 from public.profiles p
                  where p.id = $1 and p.deleted_at is null)
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
  'e per chi ha una delega attiva in subject_delegates, e solo se il profilo '
  'del soggetto e'' vivo (profiles.deleted_at nullo) — un profilo chiuso non '
  'si legge nemmeno da se stessi. security definer, stable, search_path '
  'fisso. I legami medico-paziente entreranno qui, non nelle policy.';

-- ---------------------------------------------------------------------------
-- 2. delegate_invite — un solo scope ammesso, finche' lo scope non filtra
--
--    La colonna scope esiste ed e' validata, ma nessuna lettura la applica:
--    una delega "solo fegato" darebbe accesso a tutto il soggetto, cioe'
--    esattamente il contrario di quello che l'interfaccia promette. Meglio
--    rifiutare la promessa che tradirla: finche' P11-A5b non porta lo scope
--    dentro can_access_subject e dentro le query, l'unico valore accettato e'
--    {"all": true}. Il resto del corpo e' quello della 0029.
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
  v_scope jsonb := coalesce(p_scope, '{"all": true}'::jsonb);
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

  -- (0030) Nessuno scope parziale: una delega o apre tutto o non si crea.
  if v_scope <> '{"all": true}'::jsonb then
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
  values (p_subject, v_email, 'caregiver', v_scope, 'invited', v_uid)
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
  'soggetto stesso e scope diverso da {"all": true} sono 22023 (lo scope '
  'parziale non e'' ancora applicato alle letture: si rifiuta invece di '
  'prometterlo); oltre cinque deleghe vive (invitate o attive) '
  'too_many_delegates e indirizzo gia'' invitato already_invited (P0001). '
  'Audit delegate.invited. Non manda email: lo fa la Edge Function.';

-- ---------------------------------------------------------------------------
-- 3a. delegate_accept — l'email dell'account dev'essere confermata
--
--     invited_email e' il solo riferimento alla persona invitata: se
--     l'indirizzo dell'account che accetta non e' mai stato verificato,
--     chiunque puo' registrarsi con l'indirizzo di un altro e prendersi la
--     delega. Il confronto resta con auth.users, mai con un dato dichiarato
--     dal client; in piu' si pretende email_confirmed_at.
-- ---------------------------------------------------------------------------
create or replace function public.delegate_accept(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid       uuid := auth.uid();
  v_email     text;
  v_confirmed timestamptz;
  d           public.subject_delegates%rowtype;
begin
  if p_id is null then
    raise exception 'invalid_delegate' using errcode = '22023';
  end if;
  if v_uid is null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select lower(u.email), u.email_confirmed_at
    into v_email, v_confirmed
    from auth.users u where u.id = v_uid;

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
  -- (0030) Un indirizzo non verificato non prova nulla su chi lo possiede.
  if v_confirmed is null then
    raise exception 'email_not_confirmed' using errcode = 'P0001';
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
  'invited_email (42501) e che l''ha confermata (email_not_confirmed, P0001); '
  'invito inesistente 22023, invito gia'' accettato o revocato not_invited '
  '(P0001). Valorizza user_id, status active e accepted_at. Audit '
  'delegate.accepted.';

-- 3b. my_pending_invitations — e chi non l'ha confermata non vede l'elenco
--
--     Stessa regola, dall'altro lato: un account con indirizzo non verificato
--     non deve nemmeno sapere che esiste un invito per quell'indirizzo, che e'
--     gia' un'informazione su un'altra persona (nome del soggetto, nome di chi
--     invita). Il resto della query e' quello della 0029.
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
    join auth.users u on u.id = auth.uid() and u.email_confirmed_at is not null
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
  'chiamante in auth.users, e solo se quell''email e'' confermata: senza '
  'conferma l''elenco e'' vuoto, come delegate_accept rifiuta. Colonne id, '
  'subject_id, subject_name, relationship, created_at, invited_by (nome di chi '
  'ha invitato). Solo authenticated; si accetta con delegate_accept(id).';

-- ---------------------------------------------------------------------------
-- 4. family_member_register — lock per owner e dichiarazione di responsabilita'
--
--    a) Il conteggio dei profili gestiti e l'inserimento stavano in due
--       istruzioni separate: due chiamate in parallelo dello stesso owner
--       leggevano entrambe "2 su 3" e creavano entrambe il terzo e il quarto
--       profilo. pg_advisory_xact_lock(hashtext(owner)) serializza le
--       registrazioni di un singolo owner per il tempo della transazione; non
--       tocca gli altri owner e si rilascia da solo, anche in caso di errore.
--    b) Creare un profilo gestito significa dichiarare di avere la potesta'
--       genitoriale o una delega: e' il presupposto giuridico del trattamento
--       di dati sanitari altrui (art. 9 GDPR). La versione del testo accettato
--       si registra in audit_log come 'family.guardian_declaration' — attore
--       l'owner, target_table 'consents', target_id il soggetto, la versione
--       nel campo device. Non e' una riga di consents: il consenso e' del
--       soggetto, la dichiarazione e' di chi lo rappresenta.
--
--    La firma cambia: p_declaration_version e' obbligatorio e in Postgres un
--    parametro senza default non puo' seguire quelli con default, quindi sta
--    in quarta posizione. La firma a sei argomenti della 0029 si elimina, cosi'
--    non resta una porta vecchia senza dichiarazione.
-- ---------------------------------------------------------------------------
drop function if exists public.family_member_register(uuid, uuid, text, date, text, text);

create or replace function public.family_member_register(
  p_subject             uuid,
  p_owner               uuid,
  p_full_name           text,
  p_declaration_version text,
  p_birth_date          date default null,
  p_gender              text default null,
  p_relationship        text default null
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
  v_decl  text := nullif(btrim(coalesce(p_declaration_version, '')), '');
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
  -- (0030) Senza la versione del testo accettato non si registra nessuno.
  if v_decl is null or char_length(v_decl) > 40 then
    raise exception 'invalid_declaration' using errcode = '22023';
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

  -- (0030) Una registrazione per volta per ciascun owner: il limite si conta
  -- e si consuma dentro la stessa finestra.
  perform pg_advisory_xact_lock(hashtext(p_owner::text));

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

  -- (0030) La dichiarazione di responsabilita' genitoriale o di delega: chi
  -- l'ha accettata, per chi, e quale versione del testo.
  insert into public.audit_log(actor_id, action, target_table, target_id,
                               subject_id, device)
  values (p_owner, 'family.guardian_declaration', 'consents', p_subject,
          p_subject, v_decl);

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (p_owner, 'family.member_registered', 'profiles', p_subject, p_subject);

  return jsonb_build_object(
    'subject_id', p_subject,
    'delegate_id', v_id,
    'consents_copied', v_cons,
    'declaration_version', v_decl,
    'managed_count', coalesce(v_count, 0) + 1,
    'managed_limit', v_limit
  );
end;
$$;

revoke execute on function
  public.family_member_register(uuid, uuid, text, text, date, text, text)
  from public, anon, authenticated;
grant execute on function
  public.family_member_register(uuid, uuid, text, text, date, text, text)
  to service_role;

comment on function public.family_member_register(uuid, uuid, text, text, date, text, text) is
  'Chiude la creazione di un profilo gestito: profiles.managed_by, anagrafica, '
  'lingua e fuso orario copiati dall''owner, onboarded_at, delega ''owner'' '
  'attiva e copia dei consensi health_data e ai_processing dell''owner. '
  'p_declaration_version e'' la versione del testo di responsabilita'' '
  'genitoriale o di delega accettato dall''owner: obbligatoria, non vuota, '
  'fino a 40 caratteri (invalid_declaration, 22023), registrata in audit come '
  '''family.guardian_declaration'' (target_table ''consents'', target_id il '
  'soggetto, versione nel campo device). Solo service_role (42501); parametri '
  'non validi 22023, e cosi'' pure p_subject uguale a p_owner, un profilo gia'' '
  'gestito (managed_by valorizzato) e un profilo gia'' passato dall''onboarding '
  '(onboarded_at non nullo): un account vero non diventa un profilo gestito. '
  'Il conteggio dei profili gestiti e'' protetto da '
  'pg_advisory_xact_lock(hashtext(owner)), quindi due chiamate in parallelo '
  'dello stesso owner non superano family_managed_limit() (managed_limit, '
  'P0001). Audit ''family.member_registered'' con attore l''owner.';

-- ---------------------------------------------------------------------------
-- 5. m24_family_member_remove_internal — la cascata completa
--
--    Mancavano due porte che account_close chiudeva gia': le domande al medico
--    (restavano aperte, e un medico avrebbe potuto rispondere a un profilo
--    rimosso) e gli export pronti (un file zip con tutta la storia clinica
--    scaricabile per altri sette giorni). Il resto del corpo e' quello della
--    0029; il valore di ritorno guadagna due chiavi.
-- ---------------------------------------------------------------------------
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
  v_questions int := 0;
  v_exports   int := 0;
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

  -- (0030) Stesse due chiusure di account_close: nessuna domanda resta aperta
  -- e nessun pacchetto di export resta scaricabile.
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

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (p_actor, 'family.member_removed', 'profiles', p_subject, p_subject);

  return jsonb_build_object(
    'subject_id',             p_subject,
    'delegates_revoked',      v_delegates,
    'links_revoked',          v_links,
    'emergency_card_removed', v_card,
    'questions_closed',       v_questions,
    'exports_expired',        v_exports
  );
end;
$$;

revoke execute on function public.m24_family_member_remove_internal(uuid, uuid)
  from public, anon, authenticated;

comment on function public.m24_family_member_remove_internal(uuid, uuid) is
  'Corpo della chiusura di un profilo gestito, senza controllo del chiamante: '
  'deleted_at, deleghe revocate, link revocati, scheda di emergenza '
  'cancellata, domande al medico non chiuse portate a ''closed'', export '
  '''ready'' portati a ''expired'' (stessa cascata di account_close) e audit '
  '''family.member_removed'' con attore p_actor. Restituisce {subject_id, '
  'delegates_revoked, links_revoked, emergency_card_removed, questions_closed, '
  'exports_expired}. Interna: la chiamano family_member_remove e '
  'soft_delete_account.';

comment on function public.family_member_remove(uuid) is
  'Chiude un profilo gestito: profiles.deleted_at, tutte le deleghe del '
  'soggetto (owner compresa) a revoked, link di condivisione attivi revocati, '
  'scheda di emergenza cancellata, domande al medico chiuse ed export pronti '
  'fatti scadere. Solo l''owner con delega attiva (42501); p_subject nullo '
  '22023. Audit ''family.member_removed''. La cancellazione dei dati clinici '
  'resta a purge_deleted_accounts, trenta giorni dopo.';

insert into public.app_migrations(name) values ('0030_family_hardening')
  on conflict do nothing;
