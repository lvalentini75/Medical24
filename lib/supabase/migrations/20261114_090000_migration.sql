-- ============================================================================
-- Medical 24 — 0025 DOCTOR V1 HARDENING (P08-SEC-FIX-A) — modulo M9 Medico v1
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- Chiude tre buchi della revisione di sicurezza di P08-SEC:
--   1. il freno per indirizzo IP contava solo gli esiti wrong_pin di
--      share_link_opens, quindi un codice inesistente (not_found, che non
--      lascia traccia) permetteva di provare codici all'infinito;
--   2. non esisteva un modo, per le Edge Functions, di rivalidare un link gia'
--      aperto prima di una seconda azione (risposta a una domanda, PDF);
--   3. i tentativi, una volta registrati, non venivano mai ripuliti.
--
-- Contenuto:
--   share_open_attempts            tabella append-only dei tentativi per IP
--   share_link_open(...)           scrive un tentativo a ogni chiamata
--   share_open_rate_check(text)    conta su share_open_attempts, soglia 20/15'
--   share_link_is_active(uuid)     rivalidazione del link, solo service_role
--   purge_share_open_attempts()    cancellazione oltre le 24 ore
--   run_purge_share_open_attempts_logged()  wrapper con cron_run/cron_error
--   job pg_cron 'share-open-attempts-purge' alle 04:50
--
-- Nessuna schermata, nessuna Edge Function, nessun seed.
-- Idempotente: puo' essere rieseguita senza effetti collaterali.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. share_open_attempts — ogni tentativo di apertura, per hash di IP
--
--    Niente share_link_id: il codice inesistente non ha un link a cui
--    appoggiarsi, ed e' proprio il caso che vogliamo contare. Nessun dato
--    clinico, nessun IP in chiaro: solo l'hash giornaliero calcolato dalla
--    Edge Function dossier-open, oppure la costante 'unknown'.
--
--    RLS forzata e nessuna policy: default deny totale. Ci scrive soltanto
--    share_link_open, che e' security definer e appartiene al proprietario
--    della tabella; il service_role mantiene il bypass di default di Supabase.
-- ---------------------------------------------------------------------------
create table if not exists public.share_open_attempts (
  id         uuid primary key default gen_random_uuid(),
  ip_hash    text not null check (char_length(ip_hash) <= 128),
  outcome    text not null check (char_length(outcome) <= 40),
  created_at timestamptz not null default now()
);

comment on table public.share_open_attempts is
  'Tentativi di apertura di un link, per hash giornaliero dell''IP (o '
  '''unknown''), compreso il codice inesistente. Append-only, senza policy: '
  'ci scrive soltanto share_link_open (security definer). Base del freno '
  'share_open_rate_check; ripulita ogni notte oltre le ventiquattro ore.';

alter table public.share_open_attempts enable row level security;
alter table public.share_open_attempts force row level security;

create index if not exists idx_share_open_attempts_ip_time
  on public.share_open_attempts (ip_hash, created_at desc);

-- Append-only: update e delete vietati, salvo l'interruttore di purge.
drop trigger if exists trg_share_open_attempts_append_only on public.share_open_attempts;
create trigger trg_share_open_attempts_append_only
  before update or delete on public.share_open_attempts
  for each row execute function public.m24_block_mutation();

revoke all on public.share_open_attempts from public, anon, authenticated;

-- ============================================================================
-- 2. share_link_open — come nella 0024, ma ogni chiamata lascia un tentativo
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
  v_ip        text := coalesce(nullif(btrim(coalesce(p_ip_hash, '')), ''), 'unknown');
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

  -- Codice inesistente: nessuna riga in share_link_opens (non c'e' un link a
  -- cui legarla), ma il tentativo viene comunque contato per IP: e' il caso
  -- che permetteva di provare codici a raffica senza lasciare traccia.
  if not found then
    insert into public.share_open_attempts(ip_hash, outcome)
    values (v_ip, 'not_found');
    return jsonb_build_object('outcome', 'not_found');
  end if;

  -- 1. Revocato -------------------------------------------------------------
  if l.revoked_at is not null then
    insert into public.share_open_attempts(ip_hash, outcome) values (v_ip, 'revoked');
    insert into public.share_link_opens(share_link_id, outcome, ip_hash, user_agent_hash)
    values (l.id, 'revoked', p_ip_hash, p_ua_hash);
    return jsonb_build_object('outcome', 'revoked');
  end if;

  -- 2. Fuori dalla finestra [created_at, expires_at) -------------------------
  if now() < l.created_at or now() >= l.expires_at then
    insert into public.share_open_attempts(ip_hash, outcome) values (v_ip, 'expired');
    insert into public.share_link_opens(share_link_id, outcome, ip_hash, user_agent_hash)
    values (l.id, 'expired', p_ip_hash, p_ua_hash);
    return jsonb_build_object('outcome', 'expired');
  end if;

  -- 3. Bloccato per troppi PIN sbagliati -------------------------------------
  if l.locked_until is not null and l.locked_until > now() then
    insert into public.share_open_attempts(ip_hash, outcome) values (v_ip, 'locked');
    insert into public.share_link_opens(share_link_id, outcome, ip_hash, user_agent_hash)
    values (l.id, 'locked', p_ip_hash, p_ua_hash);
    return jsonb_build_object(
      'outcome', 'locked',
      'locked_until', to_char(l.locked_until at time zone 'UTC',
                              'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
  end if;

  -- 4. Aperture esaurite ------------------------------------------------------
  if l.opens_count >= l.max_opens then
    insert into public.share_open_attempts(ip_hash, outcome) values (v_ip, 'exhausted');
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

      insert into public.share_open_attempts(ip_hash, outcome) values (v_ip, 'locked');
      insert into public.share_link_opens(share_link_id, outcome, ip_hash, user_agent_hash)
      values (l.id, 'locked', p_ip_hash, p_ua_hash);

      return jsonb_build_object(
        'outcome', 'locked',
        'locked_until', to_char(v_locked at time zone 'UTC',
                                'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
    end if;

    update public.share_links set failed_attempts = v_failed where id = l.id;

    insert into public.share_open_attempts(ip_hash, outcome) values (v_ip, 'wrong_pin');
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

  insert into public.share_open_attempts(ip_hash, outcome) values (v_ip, 'ok');

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
  'Function dossier-open). Ogni chiamata, codice inesistente compreso, lascia '
  'una riga in share_open_attempts con l''hash dell''IP (o ''unknown'') e '
  'l''esito. Negli altri casi registra anche share_link_opens e risponde, '
  'nell''ordine, revoked, expired, locked (con locked_until), exhausted, '
  'wrong_pin (con attempts_left; al quinto errore blocco di quindici minuti) '
  'oppure ok con share_link_id, subject_id, scope, expires_at, opens_left, '
  'snapshot e questions. Le risposte di errore non portano mai subject_id.';

-- ============================================================================
-- 3. share_open_rate_check — venti tentativi falliti in quindici minuti
-- ============================================================================
create or replace function public.share_open_rate_check(p_ip_hash text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_ip    text := coalesce(nullif(btrim(coalesce(p_ip_hash, '')), ''), 'unknown');
  v_count int;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select count(*)::int into v_count
    from public.share_open_attempts a
   where a.ip_hash = v_ip
     and a.outcome <> 'ok'
     and a.created_at >= now() - interval '15 minutes';

  return coalesce(v_count, 0) < 20;
end;
$$;

revoke execute on function public.share_open_rate_check(text)
  from public, anon, authenticated;
grant execute on function public.share_open_rate_check(text) to service_role;

comment on function public.share_open_rate_check(text) is
  'Falso quando lo stesso hash di IP ha almeno venti tentativi con esito '
  'diverso da ok negli ultimi quindici minuti (codice inesistente compreso), '
  'vero altrimenti. Un hash nullo o vuoto vale ''unknown''. Eseguibile '
  'soltanto dal service_role.';

-- ============================================================================
-- 4. share_link_is_active — rivalidazione del link, solo service_role
--
--    La sessione firmata di dossier-open dura trenta minuti: nel frattempo il
--    paziente puo' revocare il link, oppure il link puo' scadere o esaurirsi.
--    Prima di una risposta a una domanda o di un PDF la Edge Function chiede
--    qui se il link vale ancora.
-- ============================================================================
create or replace function public.share_link_is_active(p_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_active boolean;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if p_id is null then
    return false;
  end if;

  select true into v_active
    from public.share_links l
   where l.id = p_id
     and l.revoked_at is null
     and now() >= l.created_at
     and now() < l.expires_at
     and (l.locked_until is null or l.locked_until <= now())
     and l.opens_count < l.max_opens;

  return coalesce(v_active, false);
end;
$$;

revoke execute on function public.share_link_is_active(uuid)
  from public, anon, authenticated;
grant execute on function public.share_link_is_active(uuid) to service_role;

comment on function public.share_link_is_active(uuid) is
  'Vero se il link esiste, non e'' revocato, now() e'' nella finestra '
  '[created_at, expires_at), non e'' bloccato e ha ancora aperture residue. '
  'Non registra nulla e non consuma aperture. Solo service_role.';

-- ============================================================================
-- 5. Pulizia notturna dei tentativi oltre le ventiquattro ore
-- ============================================================================
create or replace function public.purge_share_open_attempts()
returns int
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_rows int;
begin
  if auth.role() <> 'service_role' and auth.uid() is not null then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  -- La tabella e' append-only: l'interruttore di sessione apre la porta alla
  -- sola cancellazione, come per share_link_opens (0021).
  perform set_config('medical24.allow_purge', 'on', true);
  delete from public.share_open_attempts
   where created_at < now() - interval '24 hours';
  get diagnostics v_rows = row_count;
  perform set_config('medical24.allow_purge', 'off', true);

  return v_rows;
end;
$$;

revoke execute on function public.purge_share_open_attempts()
  from public, anon, authenticated;
grant execute on function public.purge_share_open_attempts() to service_role;

comment on function public.purge_share_open_attempts() is
  'Cancella i tentativi piu'' vecchi di ventiquattro ore alzando '
  'l''interruttore medical24.allow_purge. Restituisce le righe rimosse.';

create or replace function public.run_purge_share_open_attempts_logged()
returns int
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  started timestamptz := clock_timestamp();
  n int;
begin
  perform public.platform_event('cron_run', 'purge_share_open_attempts', 'started', '{}');
  n := public.purge_share_open_attempts();
  perform public.platform_event('cron_run', 'purge_share_open_attempts', 'ok',
    jsonb_build_object('rows', n,
      'duration_ms', extract(milliseconds from clock_timestamp() - started)::int));
  return n;
exception when others then
  perform public.platform_event('cron_error', 'purge_share_open_attempts', 'error',
    jsonb_build_object('code', sqlstate,
      'duration_ms', extract(milliseconds from clock_timestamp() - started)::int));
  raise;
end;
$$;

revoke execute on function public.run_purge_share_open_attempts_logged()
  from public, anon, authenticated;
grant execute on function public.run_purge_share_open_attempts_logged() to service_role;

comment on function public.run_purge_share_open_attempts_logged() is
  'Wrapper del job notturno: scrive cron_run (started, ok) oppure cron_error '
  'in platform_events, come i wrapper della 0014.';

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid) from cron.job
     where jobname = 'share-open-attempts-purge';
    perform cron.schedule('share-open-attempts-purge', '50 4 * * *',
      'select public.run_purge_share_open_attempts_logged();');
  end if;
exception when undefined_table or invalid_schema_name then null;
end $$;

insert into public.app_migrations(name) values ('0025_doctor_v1_hardening')
  on conflict do nothing;