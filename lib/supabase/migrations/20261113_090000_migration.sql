-- ============================================================================
-- Medical 24 — 0024 DOCTOR V1 LINKS (P08-A2c-1, A2c-2) — modulo M9 Medico v1
-- Revisione Tattica Web (R1: codice da gen_random_bytes), 3 novembre 2026.
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- Creazione, revoca ed elenco dei link di condivisione del dossier, sopra lo
-- schema della 0021 (che non viene toccato) e la 0022 (dossier_build).
-- Nessuna tabella nuova, nessuna Edge Function, nessuna schermata, nessun seed.
-- L'apertura del link (codice + PIN) arriva con il prompt successivo.
--
--   share_link_create(p_subject uuid, p_pin text,
--                     p_scope jsonb default '{"all": true}'::jsonb,
--                     p_expires_in interval default '7 days',
--                     p_max_opens int default 20)          returns jsonb
--   share_link_revoke(p_id uuid)                           returns void
--   share_links_for_subject(p_subject uuid)                returns jsonb
--
-- Regole trasversali:
--   security definer con set search_path = public, extensions;
--   execute revocato a public, anon e service_role, concesso solo ad
--   authenticated;
--   errori con errcode: 22023 input non valido, 42501 not_allowed,
--   P0001 con codice parlante (too_many_links, code_exhausted);
--   il PIN non viene mai salvato, loggato o restituito in chiaro: in colonna
--   finisce soltanto crypt(p_pin, gen_salt('bf')) e nessun messaggio di errore
--   lo riporta. L'audit della creazione e della revoca lo scrive il trigger
--   trg_share_links_audit della 0021.
--
-- Idempotente: puo' essere rieseguita senza effetti collaterali.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. Guardia del PIN — interna, nessun execute per anon e authenticated.
--    Un PIN e' accettabile se ha 4-6 cifre, non e' fatto di cifre tutte
--    uguali e non e' una sequenza crescente o decrescente (1234, 123456,
--    4321, 9876...). Non registra, non restituisce e non stampa mai il PIN.
-- ---------------------------------------------------------------------------
create or replace function public.m24_valid_pin(p_pin text)
returns boolean
language plpgsql
immutable
as $$
declare
  v_len  int;
  v_asc  boolean := true;
  v_desc boolean := true;
  v_step int;
  i      int;
begin
  if p_pin is null or p_pin !~ '^[0-9]{4,6}$' then
    return false;
  end if;

  if p_pin ~ '^([0-9])\1*$' then
    return false;
  end if;

  v_len := char_length(p_pin);
  for i in 2..v_len loop
    v_step := ascii(substr(p_pin, i, 1)) - ascii(substr(p_pin, i - 1, 1));
    if v_step <> 1 then
      v_asc := false;
    end if;
    if v_step <> -1 then
      v_desc := false;
    end if;
  end loop;

  return not (v_asc or v_desc);
end;
$$;
revoke execute on function public.m24_valid_pin(text) from public, anon, authenticated;

comment on function public.m24_valid_pin(text) is
  'Interna: vero se il PIN ha 4-6 cifre, non tutte uguali e non in sequenza '
  'crescente o decrescente. Non salva, non stampa e non restituisce il PIN.';

-- ---------------------------------------------------------------------------
-- 0b. Codice casuale a sei cifre da tre byte del generatore crittografico di
--     pgcrypto (24 bit modulo 1.000.000). Interna.
-- ---------------------------------------------------------------------------
create or replace function public.m24_random_code()
returns text
language sql
volatile
set search_path = public, extensions
as $$
  select lpad((((get_byte(b, 0) << 16) | (get_byte(b, 1) << 8) | get_byte(b, 2)) % 1000000)::text, 6, '0')
    from (select gen_random_bytes(3) as b) s;
$$;
revoke execute on function public.m24_random_code() from public, anon, authenticated;

comment on function public.m24_random_code() is
  'Interna: codice di sei cifre da gen_random_bytes (pgcrypto), mai da random().';

-- ============================================================================
-- 1. share_link_create — un link nuovo, con il dossier congelato
-- ============================================================================
create or replace function public.share_link_create(
  p_subject    uuid,
  p_pin        text,
  p_scope      jsonb default '{"all": true}'::jsonb,
  p_expires_in interval default interval '7 days',
  p_max_opens  int default 20
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid       uuid := auth.uid();
  v_scope     jsonb := coalesce(p_scope, '{"all": true}'::jsonb);
  v_active    int;
  v_code      text;
  v_id        uuid;
  v_expires   timestamptz;
  v_snapshot  uuid;
  v_inserted  boolean := false;
  v_attempt   int;
begin
  -- 1. Chi puo' creare il link ------------------------------------------------
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if v_uid is null or not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  -- 2. Validazione degli argomenti --------------------------------------------
  -- Il PIN non compare mai nel messaggio di errore.
  if not coalesce(public.m24_valid_pin(p_pin), false) then
    raise exception 'weak_pin' using errcode = '22023';
  end if;

  if p_expires_in is null
     or p_expires_in < interval '1 hour'
     or p_expires_in > interval '30 days' then
    raise exception 'invalid_expires_in' using errcode = '22023';
  end if;

  if p_max_opens is null or p_max_opens < 1 or p_max_opens > 100 then
    raise exception 'invalid_max_opens' using errcode = '22023';
  end if;

  if coalesce(public.m24_valid_share_scope(v_scope), false) = false then
    raise exception 'invalid_scope' using errcode = '22023';
  end if;

  -- 3. Tetto: cinque link attivi per soggetto ---------------------------------
  select count(*)::int into v_active
    from public.share_links l
   where l.subject_id = p_subject
     and l.revoked_at is null
     and l.expires_at > now();

  if coalesce(v_active, 0) >= 5 then
    raise exception 'too_many_links' using errcode = 'P0001';
  end if;

  v_expires := now() + p_expires_in;

  -- 4. Codice a sei cifre, mai tutte uguali -----------------------------------
  -- Revisione Tattica Web (R1): il codice viene da gen_random_bytes di
  -- pgcrypto (generatore crittografico), non da random(), che e' prevedibile.
  -- Il vincolo di esclusione della 0021 rifiuta (23P01) un codice gia' in uso
  -- da un link non revocato con finestra di validita' sovrapposta: in quel
  -- caso si riprova, fino a dieci volte.
  for v_attempt in 1..10 loop
    v_code := public.m24_random_code();
    while v_code ~ '^([0-9])\1{5}$' loop
      v_code := public.m24_random_code();
    end loop;

    begin
      insert into public.share_links(subject_id, created_by, code, pin_hash,
                                     scope, expires_at, max_opens)
      values (p_subject, v_uid, v_code,
              crypt(p_pin, gen_salt('bf')),
              v_scope, v_expires, p_max_opens)
      returning id into v_id;
      v_inserted := true;
      exit;
    exception
      when exclusion_violation then
        v_inserted := false;
    end;
  end loop;

  if not v_inserted then
    raise exception 'code_exhausted' using errcode = 'P0001';
  end if;

  -- 5. Dossier congelato per questo link --------------------------------------
  v_snapshot := public.dossier_build(p_subject, v_scope, v_id);

  -- Il PIN non torna indietro: solo id, codice, scope e limiti.
  return jsonb_build_object(
    'id', v_id,
    'code', v_code,
    'scope', v_scope,
    'expires_at', to_char(v_expires at time zone 'UTC',
                          'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'max_opens', p_max_opens,
    'snapshot_id', v_snapshot);
end;
$$;

revoke execute on function
  public.share_link_create(uuid, text, jsonb, interval, int)
  from public, anon, service_role;
grant execute on function
  public.share_link_create(uuid, text, jsonb, interval, int)
  to authenticated;

comment on function public.share_link_create(uuid, text, jsonb, interval, int) is
  'Crea un link di condivisione del dossier: codice a sei cifre, PIN salvato '
  'solo come hash bcrypt, scope validato, scadenza fra un''ora e trenta '
  'giorni, da una a cento aperture, massimo cinque link attivi per soggetto. '
  'Congela subito il dossier con dossier_build e restituisce '
  '{id, code, scope, expires_at, max_opens, snapshot_id}: il PIN non torna '
  'mai indietro.';

-- ============================================================================
-- 2. share_link_revoke — spegne il link, una volta sola
-- ============================================================================
create or replace function public.share_link_revoke(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_subject uuid;
  v_revoked timestamptz;
begin
  if p_id is null then
    raise exception 'invalid_share_link' using errcode = '22023';
  end if;

  select l.subject_id, l.revoked_at
    into v_subject, v_revoked
  from public.share_links l
  where l.id = p_id
  for update;

  if not found then
    raise exception 'invalid_share_link' using errcode = '22023';
  end if;

  if auth.uid() is null or not public.can_access_subject(v_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  -- Gia' revocato: non si fa nulla, cosi' l'audit resta uno solo.
  if v_revoked is not null then
    return;
  end if;

  update public.share_links
     set revoked_at = now()
   where id = p_id
     and revoked_at is null;
  -- L'audit 'share_link.revoked' lo scrive il trigger della 0021.
end;
$$;

revoke execute on function public.share_link_revoke(uuid) from public, anon, service_role;
grant execute on function public.share_link_revoke(uuid) to authenticated;

comment on function public.share_link_revoke(uuid) is
  'Revoca il link del proprio soggetto (can_access_subject, altrimenti 42501; '
  'link inesistente 22023). Se era gia'' revocato non fa nulla. L''audit lo '
  'scrive il trigger trg_share_links_audit della 0021.';

-- ============================================================================
-- 3. share_links_for_subject — i link degli ultimi novanta giorni
-- ============================================================================
create or replace function public.share_links_for_subject(p_subject uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_rows jsonb;
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if auth.uid() is null or not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(item order by created_at desc), '[]'::jsonb)
    into v_rows
  from (
    select l.created_at,
           jsonb_build_object(
             'id', l.id,
             'code', l.code,
             'scope', l.scope,
             'created_at', to_char(l.created_at at time zone 'UTC',
                                   'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
             'expires_at', to_char(l.expires_at at time zone 'UTC',
                                   'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
             'max_opens', l.max_opens,
             'opens_count', l.opens_count,
             'last_opened_at', case when l.last_opened_at is null then null
               else to_char(l.last_opened_at at time zone 'UTC',
                            'YYYY-MM-DD"T"HH24:MI:SS"Z"') end,
             -- Ordine dichiarato: revocato, scaduto, bloccato, esaurito, attivo.
             'status', case
               when l.revoked_at is not null then 'revoked'
               when l.expires_at <= now() then 'expired'
               when l.locked_until is not null and l.locked_until > now() then 'locked'
               when l.opens_count >= l.max_opens then 'exhausted'
               else 'active' end,
             -- Ultime dieci aperture: solo quando e come e' andata.
             -- Mai pin_hash, mai gli hash dell'IP e dello user agent.
             'opens', coalesce((
               select jsonb_agg(jsonb_build_object(
                        'opened_at', to_char(o.opened_at at time zone 'UTC',
                                             'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                        'outcome', o.outcome)
                      order by o.opened_at desc)
               from (
                 select o2.opened_at, o2.outcome
                 from public.share_link_opens o2
                 where o2.share_link_id = l.id
                 order by o2.opened_at desc
                 limit 10
               ) o), '[]'::jsonb)
           ) as item
    from public.share_links l
    where l.subject_id = p_subject
      and l.created_at >= now() - interval '90 days'
  ) s;

  return v_rows;
end;
$$;

revoke execute on function public.share_links_for_subject(uuid) from public, anon, service_role;
grant execute on function public.share_links_for_subject(uuid) to authenticated;

comment on function public.share_links_for_subject(uuid) is
  'I link del soggetto degli ultimi novanta giorni, dal piu'' recente, con '
  'status (revoked, expired, locked, exhausted, active) e le ultime dieci '
  'aperture {opened_at, outcome}. Mai pin_hash, mai gli hash dell''IP e dello '
  'user agent. Richiede can_access_subject(p_subject).';

-- ============================================================================
-- 4. share_link_open — l'apertura vera e propria, solo service_role
--
--    La chiama soltanto la Edge Function dossier-open: chi apre il link non ha
--    un account, quindi non esiste un auth.uid() da controllare. Come in
--    questions_for_link, oltre al grant c'e' il controllo esplicito su
--    auth.role().
--
--    Ogni tentativo, tranne il codice inesistente, lascia una riga in
--    share_link_opens con l'esito e gli hash dell'IP e dello user agent: e'
--    cio' che il paziente vede nella pagina del link. Le risposte di errore
--    portano soltanto outcome (piu' attempts_left o locked_until quando
--    servono): mai subject_id, mai il dossier, mai il PIN.
-- ============================================================================
create or replace function public.share_link_open(
  p_code    text,
  p_pin     text,
  p_ip_hash text default null,
  p_ua_hash text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  l           public.share_links%rowtype;
  v_failed    int;
  v_locked    timestamptz;
  v_opens     int;
  v_snapshot  jsonb;
  v_questions jsonb;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  -- Il link piu' recente con quel codice (un codice scaduto puo' tornare).
  select * into l
    from public.share_links
   where code = p_code
   order by created_at desc
   limit 1
   for update;

  -- Codice inesistente: nessuna riga nel registro, nessuna traccia.
  if not found then
    return jsonb_build_object('outcome', 'not_found');
  end if;

  -- 1. Revocato -------------------------------------------------------------
  if l.revoked_at is not null then
    insert into public.share_link_opens(share_link_id, outcome, ip_hash, user_agent_hash)
    values (l.id, 'revoked', p_ip_hash, p_ua_hash);
    return jsonb_build_object('outcome', 'revoked');
  end if;

  -- 2. Fuori dalla finestra [created_at, expires_at) -------------------------
  if now() < l.created_at or now() >= l.expires_at then
    insert into public.share_link_opens(share_link_id, outcome, ip_hash, user_agent_hash)
    values (l.id, 'expired', p_ip_hash, p_ua_hash);
    return jsonb_build_object('outcome', 'expired');
  end if;

  -- 3. Bloccato per troppi PIN sbagliati -------------------------------------
  if l.locked_until is not null and l.locked_until > now() then
    insert into public.share_link_opens(share_link_id, outcome, ip_hash, user_agent_hash)
    values (l.id, 'locked', p_ip_hash, p_ua_hash);
    return jsonb_build_object(
      'outcome', 'locked',
      'locked_until', to_char(l.locked_until at time zone 'UTC',
                              'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
  end if;

  -- 4. Aperture esaurite ------------------------------------------------------
  if l.opens_count >= l.max_opens then
    insert into public.share_link_opens(share_link_id, outcome, ip_hash, user_agent_hash)
    values (l.id, 'exhausted', p_ip_hash, p_ua_hash);
    return jsonb_build_object('outcome', 'exhausted');
  end if;

  -- 5. PIN sbagliato (p_pin nullo compreso: coalesce lo tratta come errato) ---
  if not coalesce(crypt(coalesce(p_pin, ''), l.pin_hash) = l.pin_hash, false) then
    v_failed := l.failed_attempts + 1;

    if v_failed >= 5 then
      update public.share_links
         set failed_attempts = 0,
             locked_until = now() + interval '15 minutes'
       where id = l.id
      returning locked_until into v_locked;

      insert into public.share_link_opens(share_link_id, outcome, ip_hash, user_agent_hash)
      values (l.id, 'locked', p_ip_hash, p_ua_hash);

      return jsonb_build_object(
        'outcome', 'locked',
        'locked_until', to_char(v_locked at time zone 'UTC',
                                'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
    end if;

    update public.share_links set failed_attempts = v_failed where id = l.id;

    insert into public.share_link_opens(share_link_id, outcome, ip_hash, user_agent_hash)
    values (l.id, 'wrong_pin', p_ip_hash, p_ua_hash);

    return jsonb_build_object('outcome', 'wrong_pin', 'attempts_left', 5 - v_failed);
  end if;

  -- 6. PIN giusto -------------------------------------------------------------
  update public.share_links
     set opens_count = opens_count + 1,
         last_opened_at = now(),
         failed_attempts = 0
   where id = l.id
  returning opens_count into v_opens;

  -- L'audit 'share_link.opened' lo scrive il trigger della 0021 su questa riga.
  insert into public.share_link_opens(share_link_id, outcome, ip_hash, user_agent_hash)
  values (l.id, 'ok', p_ip_hash, p_ua_hash);

  select jsonb_build_object(
           'id', s.id,
           'generated_at', to_char(s.generated_at at time zone 'UTC',
                                   'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           'payload', s.payload,
           'rule_versions', s.rule_versions)
    into v_snapshot
  from public.dossier_snapshots s
  where s.share_link_id = l.id
  order by s.generated_at desc
  limit 1;

  v_questions := public.questions_for_link(l.id);

  return jsonb_build_object(
    'outcome', 'ok',
    'share_link_id', l.id,
    'subject_id', l.subject_id,
    'scope', l.scope,
    'expires_at', to_char(l.expires_at at time zone 'UTC',
                          'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'opens_left', greatest(l.max_opens - v_opens, 0),
    'snapshot', coalesce(v_snapshot, 'null'::jsonb),
    'questions', coalesce(v_questions, '[]'::jsonb));
end;
$$;

revoke execute on function public.share_link_open(text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.share_link_open(text, text, text, text)
  to service_role;

comment on function public.share_link_open(text, text, text, text) is
  'Apertura di un link con codice e PIN, riservata al service_role (Edge '
  'Function dossier-open). Codice inesistente: {outcome: not_found} e nessuna '
  'riga nel registro. Negli altri casi registra sempre l''esito in '
  'share_link_opens con gli hash dell''IP e dello user agent e risponde, '
  'nell''ordine, revoked, expired, locked (con locked_until), exhausted, '
  'wrong_pin (con attempts_left; al quinto errore blocco di quindici minuti) '
  'oppure ok con share_link_id, subject_id, scope, expires_at, opens_left, '
  'snapshot e questions. Le risposte di errore non portano mai subject_id.';

-- ============================================================================
-- 5. share_open_rate_check — freno per indirizzo IP, solo service_role
-- ============================================================================
create or replace function public.share_open_rate_check(p_ip_hash text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_count int;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  -- Senza hash dell'IP non c'e' nulla da contare: si lascia passare.
  if p_ip_hash is null then
    return true;
  end if;

  select count(*)::int into v_count
    from public.share_link_opens
   where ip_hash = p_ip_hash
     and outcome = 'wrong_pin'
     and opened_at >= now() - interval '15 minutes';

  return coalesce(v_count, 0) <= 20;
end;
$$;

revoke execute on function public.share_open_rate_check(text)
  from public, anon, authenticated;
grant execute on function public.share_open_rate_check(text) to service_role;

comment on function public.share_open_rate_check(text) is
  'Falso quando lo stesso hash di IP ha piu'' di venti esiti wrong_pin negli '
  'ultimi quindici minuti, vero altrimenti (e vero se l''hash e'' nullo). '
  'Eseguibile soltanto dal service_role.';

insert into public.app_migrations(name) values ('0024_doctor_v1_links') on conflict do nothing;