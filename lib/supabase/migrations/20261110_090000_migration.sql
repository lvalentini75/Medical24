-- ============================================================================
-- Medical 24 — 0021 DOCTOR V1 SCHEMA (P08-A1) — modulo M9 Medico v1
-- Revisione Tattica Web (R1–R7) sull'output dell'agente, 3 novembre 2026.
--
-- Solo schema, vincoli, indici, trigger e RLS. Nessuna funzione applicativa
-- (arrivano con P08-A2), nessuna Edge Function, nessuna schermata, nessun seed.
--
-- Tabelle create (cinque, tutte con RLS forzata e default deny in scrittura):
--   share_links        dossier condiviso con codice a 6 cifre e PIN separato
--   share_link_opens   registro append-only delle aperture, visibile al paziente
--   dossier_snapshots  copia congelata del dossier generato, append-only
--   questions          domande asincrone al medico e relativa risposta
--   emergency_cards    scheda di emergenza ICE, una per soggetto
--
-- Regole di accesso in breve:
--   si legge solo cio' che riguarda il proprio soggetto, sempre attraverso
--   can_access_subject(subject_id); nessuna scrittura diretta da authenticated
--   su nessuna delle cinque tabelle: le scritture arrivano con le funzioni
--   security definer di P08-A2. Il PIN non e' mai in chiaro: in colonna c'e'
--   soltanto l'hash bcrypt (crypt + gen_salt('bf') di pgcrypto), prodotto
--   dalle funzioni di A2.
--
-- Revisione (differenze rispetto all'output dell'agente):
--   R1 btree_gist nello schema extensions (convenzione Supabase).
--   R2 questions: colonna `title` al posto di `subject` (in tutto il progetto
--      "subject" e' il paziente); vincolo di coerenza della risposta corretto
--      (una domanda chiusa dopo la risposta la violava); formato di
--      doctor_email.
--   R3 dossier_snapshots: guardia dedicata che ammette una sola modifica,
--      pdf_path da nullo a valorizzato (la Edge Function dossier-pdf scrive
--      il percorso dopo aver generato il file); tolta created_at, doppione
--      di generated_at.
--   R4 audit: attore = created_by alla creazione e auth.uid() alla revoca
--      (l'agente scriveva null anche per il paziente); null solo per le
--      aperture, perche' chi apre non ha un account.
--   R5 emergency_cards: gruppo sanguigno in forma canonica (O, non 0: la
--      forma italiana "0" e' solo etichetta dell'interfaccia); tolto l'indice
--      doppione su public_token (unique lo crea gia').
--   R6 share_link_opens: limiti di lunghezza sugli hash; commento sul sale.
--   R7 nessuna policy per service_role: resta il bypass di default di
--      Supabase (default privileges), usato dalle Edge Functions dossier-pdf
--      e dossier-open.
--
-- Idempotente: puo' essere rieseguita senza effetti collaterali.
-- ============================================================================

create extension if not exists "pgcrypto";
create extension if not exists "btree_gist" with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. Enum del modulo
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_type where typname = 'share_open_outcome') then
    create type share_open_outcome as enum (
      'ok','wrong_pin','expired','revoked','locked','exhausted');
  end if;
  if not exists (select 1 from pg_type where typname = 'question_status') then
    create type question_status as enum ('draft','sent','answered','closed');
  end if;
  if not exists (select 1 from pg_type where typname = 'question_channel') then
    create type question_channel as enum ('link','app');
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Funzioni di validazione (immutabili: servono dentro i check)
--    m24_jsonb_keys_subset(jsonb, text[]) arriva dalla 0017 e viene riusata.
-- ---------------------------------------------------------------------------

-- scope del link: oggetto, in una sola delle due forme ammesse
--   {"all": true}
--   {"organs": [...], "from": "AAAA-MM-GG", "to": "AAAA-MM-GG", "categories": [...]}
-- con almeno una chiave presente, array di sole stringhe e date in forma ISO.
create or replace function public.m24_valid_share_scope(p_doc jsonb)
returns boolean
language sql
immutable
as $$
  select p_doc is not null
     and jsonb_typeof(p_doc) = 'object'
     and (
       p_doc = '{"all": true}'::jsonb
       or (
         not (p_doc ? 'all')
         and public.m24_jsonb_keys_subset(p_doc, array['organs','from','to','categories'])
         and (p_doc ?| array['organs','from','to','categories'])
         and (not (p_doc ? 'organs')
              or (jsonb_typeof(p_doc->'organs') = 'array'
                  and not exists (
                    select 1 from jsonb_array_elements(p_doc->'organs') as e(item)
                     where jsonb_typeof(e.item) <> 'string')))
         and (not (p_doc ? 'categories')
              or (jsonb_typeof(p_doc->'categories') = 'array'
                  and not exists (
                    select 1 from jsonb_array_elements(p_doc->'categories') as e(item)
                     where jsonb_typeof(e.item) <> 'string')))
         and (not (p_doc ? 'from')
              or (jsonb_typeof(p_doc->'from') = 'string'
                  and (p_doc->>'from') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'))
         and (not (p_doc ? 'to')
              or (jsonb_typeof(p_doc->'to') = 'string'
                  and (p_doc->>'to') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'))
         and (not (p_doc ? 'from' and p_doc ? 'to')
              or (p_doc->>'from') <= (p_doc->>'to'))
       )
     );
$$;

-- contatti della scheda di emergenza: array di {name, phone, relation opzionale}.
create or replace function public.m24_valid_emergency_contacts(p_doc jsonb)
returns boolean
language sql
immutable
as $$
  select p_doc is not null
     and jsonb_typeof(p_doc) = 'array'
     and jsonb_array_length(p_doc) <= 5
     and not exists (
       select 1 from jsonb_array_elements(p_doc) as e(item)
        where jsonb_typeof(e.item) <> 'object'
           or not public.m24_jsonb_keys_subset(e.item, array['name','phone','relation'])
           or coalesce(jsonb_typeof(e.item->'name'), 'missing') <> 'string'
           or coalesce(jsonb_typeof(e.item->'phone'), 'missing') <> 'string'
           or btrim(coalesce(e.item->>'name', '')) = ''
           or btrim(coalesce(e.item->>'phone', '')) = ''
           or char_length(e.item->>'name') > 80
           or char_length(e.item->>'phone') > 32
           or (e.item ? 'relation' and jsonb_typeof(e.item->'relation') <> 'string'));
$$;

-- fields_public: oggetto di soli booleani sui sei campi della pagina pubblica.
create or replace function public.m24_valid_public_fields(p_doc jsonb)
returns boolean
language sql
immutable
as $$
  select p_doc is not null
     and jsonb_typeof(p_doc) = 'object'
     and public.m24_jsonb_keys_subset(p_doc,
           array['blood_group','allergies','medications','conditions','contacts','notes'])
     and not exists (
       select 1 from jsonb_each(p_doc) as e(key, value)
        where jsonb_typeof(e.value) <> 'boolean');
$$;

-- ---------------------------------------------------------------------------
-- 3. Guardie delle tabelle append-only
-- ---------------------------------------------------------------------------
-- share_link_opens: vieta update e delete. L'unica eccezione e' la
-- cancellazione dell'account (diritto all'oblio): la purge alza
-- l'interruttore di sessione medical24.allow_purge prima di rimuovere
-- l'utente, altrimenti la cascata da auth.users resterebbe bloccata.
-- Stessa convenzione di medical24.allow_organ_state_write (0008).
create or replace function public.m24_block_mutation()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE'
     and coalesce(current_setting('medical24.allow_purge', true), 'off') = 'on' then
    return old;
  end if;
  raise exception 'append_only_table: %.%', tg_table_schema, tg_table_name
    using errcode = '42501';
end;
$$;
revoke execute on function public.m24_block_mutation() from public, anon, authenticated;

-- dossier_snapshots: come sopra, con una sola modifica ammessa: pdf_path da
-- nullo a valorizzato (la Edge Function dossier-pdf scrive il percorso del
-- file dopo averlo generato). Tutto il resto della riga deve restare uguale.
create or replace function public.m24_guard_dossier_snapshot()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    if coalesce(current_setting('medical24.allow_purge', true), 'off') = 'on' then
      return old;
    end if;
    raise exception 'append_only_table: %.%', tg_table_schema, tg_table_name
      using errcode = '42501';
  end if;
  if old.pdf_path is null
     and new.pdf_path is not null
     and (to_jsonb(new) - 'pdf_path') = (to_jsonb(old) - 'pdf_path') then
    return new;
  end if;
  raise exception 'append_only_table: %.% (solo pdf_path da nullo a valorizzato)',
    tg_table_schema, tg_table_name using errcode = '42501';
end;
$$;
revoke execute on function public.m24_guard_dossier_snapshot() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. share_links — dossier condiviso con codice a 6 cifre e PIN separato
-- ---------------------------------------------------------------------------
create table if not exists public.share_links (
  id              uuid primary key default gen_random_uuid(),
  subject_id      uuid not null references auth.users(id) on delete cascade,
  created_by      uuid not null references auth.users(id) on delete cascade,
  code            text not null check (code ~ '^[0-9]{6}$'),
  -- Mai il PIN in chiaro: qui c'e' solo l'hash bcrypt prodotto da
  -- crypt(p_pin, gen_salt('bf')) nelle funzioni di P08-A2.
  pin_hash        text not null check (pin_hash ~ '^\$2[aby]?\$'),
  scope           jsonb not null default '{"all": true}'::jsonb
                    check (public.m24_valid_share_scope(scope)),
  expires_at      timestamptz not null default (now() + interval '7 days'),
  max_opens       int not null default 20 check (max_opens between 1 and 100),
  opens_count     int not null default 0 check (opens_count >= 0),
  failed_attempts int not null default 0 check (failed_attempts >= 0),
  locked_until    timestamptz,
  revoked_at      timestamptz,
  last_opened_at  timestamptz,
  created_at      timestamptz not null default now(),
  constraint share_links_validity check (expires_at > created_at)
);

comment on table public.share_links is
  'Link di condivisione del dossier: codice a 6 cifre, PIN separato salvato '
  'come hash bcrypt, scope, scadenza a 7 giorni, limite di aperture. Lettura '
  'con can_access_subject; nessuna scrittura diretta (P08-A2).';
comment on column public.share_links.pin_hash is
  'Hash bcrypt del PIN (crypt + gen_salt(''bf'')). Il PIN in chiaro non entra '
  'mai nel database, nei log e negli URL.';
comment on column public.share_links.scope is
  'Oggetto {"all": true} oppure {"organs": [...], "from": "AAAA-MM-GG", '
  '"to": "AAAA-MM-GG", "categories": [...]}, validato da m24_valid_share_scope.';

-- Il codice e' univoco tra i link non revocati le cui finestre di validita' si
-- sovrappongono: un codice scaduto torna disponibile. Vincolo di esclusione
-- (gist, btree_gist per il testo) parziale sui link non revocati.
do $$ begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'share_links_code_active_excl'
       and conrelid = 'public.share_links'::regclass) then
    alter table public.share_links
      add constraint share_links_code_active_excl
      exclude using gist (
        code with =,
        tstzrange(created_at, expires_at, '[)') with &&)
      where (revoked_at is null);
  end if;
end $$;

create index if not exists idx_share_links_subject_created
  on public.share_links (subject_id, created_at desc);
create index if not exists idx_share_links_code_active
  on public.share_links (code) where revoked_at is null;

-- ---------------------------------------------------------------------------
-- 5. share_link_opens — registro append-only delle aperture
-- ---------------------------------------------------------------------------
create table if not exists public.share_link_opens (
  id              uuid primary key default gen_random_uuid(),
  share_link_id   uuid not null references public.share_links(id) on delete cascade,
  opened_at       timestamptz not null default now(),
  outcome         share_open_outcome not null,
  -- Hash (HMAC con sale giornaliero, calcolato dalla Edge Function
  -- dossier-open): mai l'IP o lo user agent in chiaro.
  ip_hash         text check (ip_hash is null or char_length(ip_hash) <= 128),
  user_agent_hash text check (user_agent_hash is null or char_length(user_agent_hash) <= 128)
);

comment on table public.share_link_opens is
  'Registro delle aperture di un link: esito, hash dell''IP e dello user agent. '
  'Append-only (trigger che vieta update e delete); e'' cio'' che il paziente '
  'vede nella pagina del link. Nessun dato clinico, nessun IP in chiaro.';

create index if not exists idx_share_link_opens_link_time
  on public.share_link_opens (share_link_id, opened_at desc);

drop trigger if exists trg_share_link_opens_append_only on public.share_link_opens;
create trigger trg_share_link_opens_append_only
  before update or delete on public.share_link_opens
  for each row execute function public.m24_block_mutation();

-- ---------------------------------------------------------------------------
-- 6. dossier_snapshots — copia congelata del dossier, append-only
-- ---------------------------------------------------------------------------
create table if not exists public.dossier_snapshots (
  id             uuid primary key default gen_random_uuid(),
  subject_id     uuid not null references auth.users(id) on delete cascade,
  share_link_id  uuid references public.share_links(id) on delete set null,
  generated_at   timestamptz not null default now(),
  payload        jsonb not null default '{}'::jsonb
                   check (jsonb_typeof(payload) = 'object'),
  pdf_path       text check (pdf_path is null or char_length(pdf_path) <= 512),
  rule_versions  jsonb not null default '{}'::jsonb
                   check (jsonb_typeof(rule_versions) = 'object')
);

comment on table public.dossier_snapshots is
  'Dossier congelato: stato di salute, rischi con livello, organi in '
  'attenzione, ultimi valori fuori intervallo con tendenza, esami consigliati '
  'ed elenco dei documenti nello scope (solo id, titolo, categoria e data). '
  'Append-only, salvo pdf_path da nullo a valorizzato; porta sempre le '
  'versioni delle regole usate.';

create index if not exists idx_dossier_snapshots_subject_time
  on public.dossier_snapshots (subject_id, generated_at desc);
create index if not exists idx_dossier_snapshots_link
  on public.dossier_snapshots (share_link_id);

drop trigger if exists trg_dossier_snapshots_append_only on public.dossier_snapshots;
create trigger trg_dossier_snapshots_append_only
  before update or delete on public.dossier_snapshots
  for each row execute function public.m24_guard_dossier_snapshot();

-- ---------------------------------------------------------------------------
-- 7. questions — domande asincrone al medico
-- ---------------------------------------------------------------------------
create table if not exists public.questions (
  id             uuid primary key default gen_random_uuid(),
  subject_id     uuid not null references auth.users(id) on delete cascade,
  share_link_id  uuid references public.share_links(id) on delete set null,
  doctor_email   text check (doctor_email is null
                   or (char_length(doctor_email) <= 320
                       and doctor_email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$')),
  title          text not null check (char_length(btrim(title)) between 1 and 120),
  body           text not null check (char_length(btrim(body)) between 1 and 4000),
  status         question_status not null default 'draft',
  answer         text check (answer is null or char_length(answer) <= 8000),
  answered_at    timestamptz,
  answered_via   question_channel,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  -- answered: risposta, data e canale presenti; draft e sent: nessuna risposta;
  -- closed: con o senza risposta (il paziente puo' chiudere anche senza).
  constraint questions_answer_consistency check (
    case status
      when 'answered' then answer is not null and answered_at is not null
                           and answered_via is not null
      when 'closed'   then (answer is null) = (answered_at is null)
      else answer is null and answered_at is null and answered_via is null
    end)
);

comment on table public.questions is
  'Domanda asincrona al medico, con il dossier eventualmente allegato tramite '
  'share_link_id. Lettura con can_access_subject; nessuna scrittura diretta.';

create index if not exists idx_questions_subject_created
  on public.questions (subject_id, created_at desc);
create index if not exists idx_questions_link
  on public.questions (share_link_id);

drop trigger if exists trg_questions_updated_at on public.questions;
create trigger trg_questions_updated_at before update on public.questions
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 8. emergency_cards — scheda di emergenza ICE, una per soggetto
-- ---------------------------------------------------------------------------
create table if not exists public.emergency_cards (
  subject_id    uuid primary key references auth.users(id) on delete cascade,
  -- Forma canonica ABO/Rh con la lettera O; l'interfaccia italiana mostra "0".
  blood_group   text check (blood_group is null or blood_group in
                  ('O-','O+','A-','A+','B-','B+','AB-','AB+')),
  allergies     text[] not null default '{}'
                  check (cardinality(allergies) <= 20),
  medications   text[] not null default '{}'
                  check (cardinality(medications) <= 20),
  conditions    text[] not null default '{}'
                  check (cardinality(conditions) <= 20),
  contacts      jsonb not null default '[]'::jsonb
                  check (public.m24_valid_emergency_contacts(contacts)),
  notes         text check (notes is null or char_length(notes) <= 500),
  public_token  text not null unique default encode(gen_random_bytes(16), 'hex')
                  check (public_token ~ '^[0-9a-f]{32}$'),
  fields_public jsonb not null default
                  '{"blood_group": true, "allergies": true, "medications": true,
                    "conditions": true, "contacts": true, "notes": false}'::jsonb
                  check (public.m24_valid_public_fields(fields_public)),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.emergency_cards is
  'Scheda di emergenza ICE. public_token (32 caratteri casuali, rigenerabile) '
  'e fields_public decidono che cosa compare sulla pagina pubblica, che viene '
  'letta da una funzione security definer di P08-A2 e mai da anon in diretta.';

drop trigger if exists trg_emergency_cards_updated_at on public.emergency_cards;
create trigger trg_emergency_cards_updated_at before update on public.emergency_cards
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 9. Audit: creazione, revoca e apertura riuscita di un link.
--    Creazione e revoca le fa il paziente (attore = created_by / auth.uid());
--    chi apre il link non ha un account: attore nullo.
-- ---------------------------------------------------------------------------
create or replace function public.m24_audit_share_link()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
    values (new.created_by, 'share_link.created', 'share_links', new.id, new.subject_id);
  elsif tg_op = 'UPDATE'
        and old.revoked_at is null and new.revoked_at is not null then
    insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
    values (auth.uid(), 'share_link.revoked', 'share_links', new.id, new.subject_id);
  end if;
  return null;
end;
$$;
revoke execute on function public.m24_audit_share_link() from public, anon, authenticated;

drop trigger if exists trg_share_links_audit on public.share_links;
create trigger trg_share_links_audit
  after insert or update on public.share_links
  for each row execute function public.m24_audit_share_link();

create or replace function public.m24_audit_share_link_open()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.outcome = 'ok' then
    insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
    select null, 'share_link.opened', 'share_links', l.id, l.subject_id
      from public.share_links l
     where l.id = new.share_link_id;
  end if;
  return null;
end;
$$;
revoke execute on function public.m24_audit_share_link_open() from public, anon, authenticated;

drop trigger if exists trg_share_link_opens_audit on public.share_link_opens;
create trigger trg_share_link_opens_audit
  after insert on public.share_link_opens
  for each row execute function public.m24_audit_share_link_open();

-- ---------------------------------------------------------------------------
-- 10. RLS — default deny su tutte e cinque, RLS forzata, sola lettura
-- ---------------------------------------------------------------------------
alter table public.share_links       enable row level security;
alter table public.share_link_opens  enable row level security;
alter table public.dossier_snapshots enable row level security;
alter table public.questions         enable row level security;
alter table public.emergency_cards   enable row level security;

alter table public.share_links       force row level security;
alter table public.share_link_opens  force row level security;
alter table public.dossier_snapshots force row level security;
alter table public.questions         force row level security;
alter table public.emergency_cards   force row level security;

drop policy if exists share_links_owner_select on public.share_links;
create policy share_links_owner_select on public.share_links for select to authenticated
  using (public.can_access_subject(subject_id));

drop policy if exists share_link_opens_owner_select on public.share_link_opens;
create policy share_link_opens_owner_select on public.share_link_opens for select to authenticated
  using (exists (
    select 1 from public.share_links l
     where l.id = share_link_opens.share_link_id
       and public.can_access_subject(l.subject_id)));

drop policy if exists dossier_snapshots_owner_select on public.dossier_snapshots;
create policy dossier_snapshots_owner_select on public.dossier_snapshots for select to authenticated
  using (public.can_access_subject(subject_id));

drop policy if exists questions_owner_select on public.questions;
create policy questions_owner_select on public.questions for select to authenticated
  using (public.can_access_subject(subject_id));

-- Unica policy di emergency_cards: il proprietario della scheda. Nessuna
-- policy per anon; la pagina pubblica passa dalla funzione con token di A2.
drop policy if exists emergency_cards_owner_select on public.emergency_cards;
create policy emergency_cards_owner_select on public.emergency_cards for select to authenticated
  using (public.can_access_subject(subject_id));

-- ---------------------------------------------------------------------------
-- 11. Grant — sola lettura per authenticated, niente per anon
-- ---------------------------------------------------------------------------
revoke all on public.share_links, public.share_link_opens,
  public.dossier_snapshots, public.questions, public.emergency_cards
  from anon, authenticated;

grant select on public.share_links, public.share_link_opens,
  public.dossier_snapshots, public.questions, public.emergency_cards
  to authenticated;

grant execute on function
  public.m24_valid_share_scope(jsonb),
  public.m24_valid_emergency_contacts(jsonb),
  public.m24_valid_public_fields(jsonb)
  to anon, authenticated, service_role;

insert into public.app_migrations(name) values ('0021_doctor_v1_schema') on conflict do nothing;