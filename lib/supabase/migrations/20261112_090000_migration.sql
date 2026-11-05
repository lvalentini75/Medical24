-- ============================================================================
-- Medical 24 — 0023 DOCTOR V1 QUESTIONS + ICE (P08-A2b-1, P08-A2b-2) — M9
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- Funzioni delle domande al medico e della scheda di emergenza, sopra lo
-- schema della 0021 che non viene toccato. Nessuna tabella nuova, nessuna
-- Edge Function, nessuna schermata, nessun seed.
--
-- Paziente (authenticated con can_access_subject sul soggetto della domanda):
--   question_create(p_subject, p_title, p_body, p_share_link_id, p_doctor_email) -> uuid
--   question_update(p_id, p_title, p_body)        -> void
--   question_send(p_id)                           -> void
--   question_record_answer(p_id, p_answer)        -> void
--   question_close(p_id)                          -> void
--   question_delete(p_id)                         -> void
--
-- Solo service_role (la pagina pubblica del dossier passa dalla Edge Function
-- dossier-open, che non ha mai il soggetto sotto mano):
--   questions_for_link(p_share_link_id)                        -> jsonb
--   question_answer_via_link(p_share_link_id, p_question_id, p_answer) -> void
--
-- Scheda di emergenza (ICE):
--   emergency_card_upsert(p_subject, p_payload)        -> jsonb (authenticated)
--   emergency_card_regenerate_token(p_subject)         -> text  (authenticated)
--   emergency_card_public(p_token)                     -> jsonb (anon + auth)
--
-- Regole trasversali:
--   security definer con set search_path = public, extensions;
--   execute revocato a public e anon, concesso solo ai ruoli indicati;
--   errori con errcode: 22023 input non valido, 42501 not_allowed,
--   P0001 con codice parlante (daily_limit, not_editable, not_sendable,
--   not_answerable, already_closed, not_deletable);
--   audit 'question.<azione>' a ogni cambio di stato, con attore auth.uid()
--   (nullo quando risponde il medico dal link), subject_id del soggetto e
--   target questions: mai il testo della domanda o della risposta.
--
-- Idempotente: puo' essere rieseguita senza effetti collaterali.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 0. Guardia comune: la riga della domanda, se il chiamante puo' vederla.
--    Una sola funzione interna, cosi' il controllo di accesso e' scritto
--    una volta sola ed e' identico per tutte le azioni del paziente.
-- ---------------------------------------------------------------------------
create or replace function public.m24_question_for_update(p_id uuid)
returns public.questions
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  q public.questions%rowtype;
begin
  if p_id is null then
    raise exception 'invalid_question' using errcode = '22023';
  end if;

  select * into q from public.questions where id = p_id for update;
  if not found then
    raise exception 'invalid_question' using errcode = '22023';
  end if;

  if auth.uid() is null or not public.can_access_subject(q.subject_id) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  return q;
end;
$$;
revoke execute on function public.m24_question_for_update(uuid) from public, anon, authenticated;

comment on function public.m24_question_for_update(uuid) is
  'Interna: blocca e restituisce la domanda se il chiamante ha '
  'can_access_subject sul soggetto; 22023 se non esiste, 42501 altrimenti.';

-- ---------------------------------------------------------------------------
-- 1. question_create — nasce draft
-- ---------------------------------------------------------------------------
create or replace function public.question_create(
  p_subject       uuid,
  p_title         text,
  p_body          text,
  p_share_link_id uuid default null,
  p_doctor_email  text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid   uuid := auth.uid();
  v_title text := btrim(coalesce(p_title, ''));
  v_body  text := btrim(coalesce(p_body, ''));
  v_email text := nullif(btrim(lower(coalesce(p_doctor_email, ''))), '');
  v_today int;
  v_id    uuid;
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if v_uid is null or not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if char_length(v_title) < 1 or char_length(v_title) > 120 then
    raise exception 'invalid_title' using errcode = '22023';
  end if;
  if char_length(v_body) < 1 or char_length(v_body) > 4000 then
    raise exception 'invalid_body' using errcode = '22023';
  end if;
  if v_email is not null
     and (char_length(v_email) > 320
          or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') then
    raise exception 'invalid_doctor_email' using errcode = '22023';
  end if;

  -- Il link allegato deve essere del soggetto della domanda.
  if p_share_link_id is not null
     and not exists (select 1 from public.share_links l
                      where l.id = p_share_link_id
                        and l.subject_id = p_subject) then
    raise exception 'invalid_share_link' using errcode = '22023';
  end if;

  -- Tetto: venti domande create al giorno per soggetto.
  select count(*)::int into v_today
    from public.questions q
   where q.subject_id = p_subject
     and q.created_at >= date_trunc('day', now());
  if coalesce(v_today, 0) >= 20 then
    raise exception 'daily_limit' using errcode = 'P0001';
  end if;

  insert into public.questions(subject_id, share_link_id, doctor_email,
                               title, body, status)
  values (p_subject, p_share_link_id, v_email, v_title, v_body, 'draft')
  returning id into v_id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'question.created', 'questions', v_id, p_subject);

  return v_id;
end;
$$;

revoke execute on function public.question_create(uuid, text, text, uuid, text)
  from public, anon;
grant execute on function public.question_create(uuid, text, text, uuid, text)
  to authenticated;

comment on function public.question_create(uuid, text, text, uuid, text) is
  'Crea una domanda in stato draft per il soggetto indicato. Richiede '
  'can_access_subject(p_subject) (42501). Titolo 1-120 e testo 1-4000 '
  'caratteri gia'' ritagliati (22023); p_share_link_id deve essere un link '
  'dello stesso soggetto (invalid_share_link, 22023); massimo 20 domande '
  'create al giorno per soggetto (daily_limit, P0001). Audit question.created.';

-- ---------------------------------------------------------------------------
-- 2. question_update — solo finche' e' draft
-- ---------------------------------------------------------------------------
create or replace function public.question_update(
  p_id    uuid,
  p_title text,
  p_body  text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  q       public.questions%rowtype := public.m24_question_for_update(p_id);
  v_title text := btrim(coalesce(p_title, ''));
  v_body  text := btrim(coalesce(p_body, ''));
begin
  if q.status <> 'draft' then
    raise exception 'not_editable' using errcode = 'P0001';
  end if;
  if char_length(v_title) < 1 or char_length(v_title) > 120 then
    raise exception 'invalid_title' using errcode = '22023';
  end if;
  if char_length(v_body) < 1 or char_length(v_body) > 4000 then
    raise exception 'invalid_body' using errcode = '22023';
  end if;

  update public.questions
     set title = v_title, body = v_body
   where id = q.id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (auth.uid(), 'question.updated', 'questions', q.id, q.subject_id);
end;
$$;

revoke execute on function public.question_update(uuid, text, text) from public, anon;
grant execute on function public.question_update(uuid, text, text) to authenticated;

comment on function public.question_update(uuid, text, text) is
  'Modifica titolo e testo di una domanda ancora in draft (altrimenti '
  'not_editable, P0001). Richiede can_access_subject sul soggetto (42501). '
  'Audit question.updated.';

-- ---------------------------------------------------------------------------
-- 3. question_send — draft -> sent
-- ---------------------------------------------------------------------------
create or replace function public.question_send(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  q public.questions%rowtype := public.m24_question_for_update(p_id);
begin
  if q.status <> 'draft' then
    raise exception 'not_sendable' using errcode = 'P0001';
  end if;

  update public.questions set status = 'sent' where id = q.id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (auth.uid(), 'question.sent', 'questions', q.id, q.subject_id);
end;
$$;

revoke execute on function public.question_send(uuid) from public, anon;
grant execute on function public.question_send(uuid) to authenticated;

comment on function public.question_send(uuid) is
  'Porta la domanda da draft a sent (altrimenti not_sendable, P0001). '
  'Richiede can_access_subject sul soggetto (42501). Audit question.sent.';

-- ---------------------------------------------------------------------------
-- 4. question_record_answer — sent -> answered, canale 'app'
--    E' il paziente che registra una risposta ricevuta fuori dall'app
--    (allo sportello, al telefono, di persona): l'app non la riceve da sola.
-- ---------------------------------------------------------------------------
create or replace function public.question_record_answer(
  p_id     uuid,
  p_answer text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  q        public.questions%rowtype := public.m24_question_for_update(p_id);
  v_answer text := btrim(coalesce(p_answer, ''));
begin
  if q.status <> 'sent' then
    raise exception 'not_answerable' using errcode = 'P0001';
  end if;
  if char_length(v_answer) < 1 or char_length(v_answer) > 8000 then
    raise exception 'invalid_answer' using errcode = '22023';
  end if;

  update public.questions
     set status = 'answered',
         answer = v_answer,
         answered_at = now(),
         answered_via = 'app'
   where id = q.id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (auth.uid(), 'question.answered', 'questions', q.id, q.subject_id);
end;
$$;

revoke execute on function public.question_record_answer(uuid, text) from public, anon;
grant execute on function public.question_record_answer(uuid, text) to authenticated;

comment on function public.question_record_answer(uuid, text) is
  'Il paziente registra la risposta ricevuta fuori dall''app: sent -> '
  'answered con answered_via = ''app'' e answered_at = now(); da qualunque '
  'altro stato not_answerable (P0001). Risposta ritagliata, 1-8000 caratteri '
  '(22023). Audit question.answered.';

-- ---------------------------------------------------------------------------
-- 5. question_close — qualunque stato diverso da closed -> closed
--    La risposta, se c'e', resta: chiudere non cancella nulla.
-- ---------------------------------------------------------------------------
create or replace function public.question_close(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  q public.questions%rowtype := public.m24_question_for_update(p_id);
begin
  if q.status = 'closed' then
    raise exception 'already_closed' using errcode = 'P0001';
  end if;

  update public.questions set status = 'closed' where id = q.id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (auth.uid(), 'question.closed', 'questions', q.id, q.subject_id);
end;
$$;

revoke execute on function public.question_close(uuid) from public, anon;
grant execute on function public.question_close(uuid) to authenticated;

comment on function public.question_close(uuid) is
  'Chiude la domanda da qualunque stato diverso da closed (altrimenti '
  'already_closed, P0001), conservando la risposta. Richiede '
  'can_access_subject sul soggetto (42501). Audit question.closed.';

-- ---------------------------------------------------------------------------
-- 6. question_delete — solo una bozza si cancella
-- ---------------------------------------------------------------------------
create or replace function public.question_delete(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  q public.questions%rowtype := public.m24_question_for_update(p_id);
begin
  if q.status <> 'draft' then
    raise exception 'not_deletable' using errcode = 'P0001';
  end if;

  delete from public.questions where id = q.id;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (auth.uid(), 'question.deleted', 'questions', q.id, q.subject_id);
end;
$$;

revoke execute on function public.question_delete(uuid) from public, anon;
grant execute on function public.question_delete(uuid) to authenticated;

comment on function public.question_delete(uuid) is
  'Cancella una domanda ancora in draft (altrimenti not_deletable, P0001). '
  'Richiede can_access_subject sul soggetto (42501). Audit question.deleted.';

-- ---------------------------------------------------------------------------
-- 7. questions_for_link — solo service_role (Edge Function dossier-open)
--    Chi apre il link non ha un account: la pagina pubblica del dossier
--    riceve le domande gia' inviate, senza mai il soggetto ne' l'indirizzo
--    del medico.
-- ---------------------------------------------------------------------------
create or replace function public.questions_for_link(p_share_link_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_rows jsonb;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if p_share_link_id is null then
    raise exception 'invalid_share_link' using errcode = '22023';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', q.id,
           'title', q.title,
           'body', q.body,
           'status', q.status,
           'answer', q.answer,
           'answered_at', case when q.answered_at is null then null
             else to_char(q.answered_at at time zone 'UTC',
                          'YYYY-MM-DD"T"HH24:MI:SS"Z"') end,
           'created_at', to_char(q.created_at at time zone 'UTC',
                                 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
           order by q.created_at), '[]'::jsonb)
    into v_rows
  from public.questions q
  where q.share_link_id = p_share_link_id
    and q.status in ('sent', 'answered');

  return v_rows;
end;
$$;

revoke execute on function public.questions_for_link(uuid)
  from public, anon, authenticated;
grant execute on function public.questions_for_link(uuid) to service_role;

comment on function public.questions_for_link(uuid) is
  'Domande sent e answered allegate a quel link, nella forma {id, title, '
  'body, status, answer, answered_at, created_at}: mai subject_id, mai '
  'doctor_email. Eseguibile soltanto dal service_role (Edge Function '
  'dossier-open).';

-- ---------------------------------------------------------------------------
-- 8. question_answer_via_link — solo service_role, canale 'link'
-- ---------------------------------------------------------------------------
create or replace function public.question_answer_via_link(
  p_share_link_id uuid,
  p_question_id   uuid,
  p_answer        text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  q        public.questions%rowtype;
  v_answer text := btrim(coalesce(p_answer, ''));
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if p_share_link_id is null or p_question_id is null then
    raise exception 'invalid_question' using errcode = '22023';
  end if;
  if char_length(v_answer) < 1 or char_length(v_answer) > 8000 then
    raise exception 'invalid_answer' using errcode = '22023';
  end if;

  select * into q
  from public.questions
  where id = p_question_id and share_link_id = p_share_link_id
  for update;

  if not found then
    raise exception 'invalid_question' using errcode = '22023';
  end if;
  if q.status <> 'sent' then
    raise exception 'not_answerable' using errcode = 'P0001';
  end if;

  update public.questions
     set status = 'answered',
         answer = v_answer,
         answered_at = now(),
         answered_via = 'link'
   where id = q.id;

  -- Chi risponde dal link non ha un account: attore nullo, come per
  -- share_link.opened della 0021.
  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (null, 'question.answered', 'questions', q.id, q.subject_id);
end;
$$;

revoke execute on function public.question_answer_via_link(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.question_answer_via_link(uuid, uuid, text)
  to service_role;

comment on function public.question_answer_via_link(uuid, uuid, text) is
  'Il medico risponde dalla pagina pubblica del dossier: la domanda deve '
  'appartenere a quel link (22023) ed essere sent (not_answerable, P0001); '
  'diventa answered con answered_via = ''link''. Risposta ritagliata, 1-8000 '
  'caratteri. Eseguibile soltanto dal service_role.';

-- ---------------------------------------------------------------------------
-- 9. Scheda di emergenza (ICE)
--    Una riga per soggetto (emergency_cards della 0021). Il paziente la
--    scrive solo da qui; la pagina pubblica la legge solo dal token, senza
--    account e senza nessun altro dato del profilo.
--
--    emergency_card_upsert(p_subject, p_payload)  -> jsonb  (authenticated)
--    emergency_card_regenerate_token(p_subject)   -> text   (authenticated)
--    emergency_card_public(p_token)               -> jsonb  (anon, authenticated)
-- ---------------------------------------------------------------------------

-- Normalizza un array di testi del payload: ritagliato, senza vuoti,
-- al massimo 80 caratteri l'uno e 20 elementi. Tutto il resto e' 22023.
create or replace function public.m24_emergency_text_array(p_doc jsonb, p_key text)
returns text[]
language plpgsql
immutable
as $$
declare
  v text[];
begin
  if p_doc is null or jsonb_typeof(p_doc) <> 'array' then
    raise exception 'invalid_%', p_key using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_array_elements(p_doc) as e(item)
              where jsonb_typeof(e.item) <> 'string') then
    raise exception 'invalid_%', p_key using errcode = '22023';
  end if;

  select coalesce(array_agg(s.t order by s.ord), '{}'::text[]) into v
    from (select btrim(e.item #>> '{}') as t, e.ord
            from jsonb_array_elements(p_doc) with ordinality as e(item, ord)) s
   where s.t <> '';

  if cardinality(v) > 20 then
    raise exception 'invalid_%', p_key using errcode = '22023';
  end if;
  if exists (select 1 from unnest(v) as u(t) where char_length(u.t) > 80) then
    raise exception 'invalid_%', p_key using errcode = '22023';
  end if;

  return v;
end;
$$;
revoke execute on function public.m24_emergency_text_array(jsonb, text)
  from public, anon, authenticated;

comment on function public.m24_emergency_text_array(jsonb, text) is
  'Interna: array jsonb di stringhe -> text[] ritagliato, senza vuoti, '
  'massimo 20 elementi di 80 caratteri; qualunque altra forma e'' 22023.';

-- 9.1 emergency_card_upsert — crea la riga se manca, aggiorna le sole chiavi
--     presenti nel payload e restituisce la riga completa, token compreso.
create or replace function public.emergency_card_upsert(
  p_subject uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid         uuid := auth.uid();
  v_card        public.emergency_cards%rowtype;
  v_allergies   text[];
  v_medications text[];
  v_conditions  text[];
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if v_uid is null or not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'invalid_payload' using errcode = '22023';
  end if;
  if not public.m24_jsonb_keys_subset(p_payload,
       array['blood_group','allergies','medications','conditions',
             'contacts','notes','fields_public']) then
    raise exception 'unknown_key' using errcode = '22023';
  end if;
  if p_payload ? 'fields_public'
     and jsonb_typeof(p_payload->'fields_public') <> 'object' then
    raise exception 'invalid_fields_public' using errcode = '22023';
  end if;

  -- Gli array si normalizzano prima dell'update, cosi' un payload sbagliato
  -- fallisce con 22023 senza aver toccato nulla.
  if p_payload ? 'allergies' then
    v_allergies := public.m24_emergency_text_array(p_payload->'allergies', 'allergies');
  end if;
  if p_payload ? 'medications' then
    v_medications := public.m24_emergency_text_array(p_payload->'medications', 'medications');
  end if;
  if p_payload ? 'conditions' then
    v_conditions := public.m24_emergency_text_array(p_payload->'conditions', 'conditions');
  end if;

  -- La riga nasce qui, con public_token dal default della 0021.
  insert into public.emergency_cards(subject_id)
  values (p_subject)
  on conflict (subject_id) do nothing;

  update public.emergency_cards c
     set blood_group = case when p_payload ? 'blood_group'
                            then nullif(btrim(coalesce(p_payload->>'blood_group','')), '')
                            else c.blood_group end,
         allergies   = case when p_payload ? 'allergies'
                            then v_allergies else c.allergies end,
         medications = case when p_payload ? 'medications'
                            then v_medications else c.medications end,
         conditions  = case when p_payload ? 'conditions'
                            then v_conditions else c.conditions end,
         contacts    = case when p_payload ? 'contacts'
                            then p_payload->'contacts'
                            else c.contacts end,
         notes       = case when p_payload ? 'notes'
                            then nullif(btrim(coalesce(p_payload->>'notes','')), '')
                            else c.notes end,
         -- fields_public si aggiorna chiave per chiave: le voci assenti
         -- restano come sono.
         fields_public = case when p_payload ? 'fields_public'
                              then c.fields_public || (p_payload->'fields_public')
                              else c.fields_public end
   where c.subject_id = p_subject
  returning c.* into v_card;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'emergency_card.updated', 'emergency_cards', p_subject, p_subject);

  return to_jsonb(v_card);
end;
$$;

revoke execute on function public.emergency_card_upsert(uuid, jsonb) from public, anon;
grant execute on function public.emergency_card_upsert(uuid, jsonb) to authenticated;

comment on function public.emergency_card_upsert(uuid, jsonb) is
  'Crea o aggiorna la scheda di emergenza del soggetto. Chiavi ammesse: '
  'blood_group, allergies, medications, conditions, contacts, notes, '
  'fields_public (qualunque altra chiave e'' unknown_key, 22023); gli array '
  'di testi sono ritagliati, senza vuoti, massimo 20 elementi di 80 caratteri. '
  'Aggiorna solo le chiavi presenti, fields_public voce per voce; i valori '
  'fuori dai vincoli della 0021 (gruppo sanguigno, contatti, booleani) '
  'falliscono con 23514. Restituisce la riga completa, public_token compreso. '
  'Audit emergency_card.updated.';

-- 9.2 emergency_card_regenerate_token — il vecchio indirizzo pubblico muore
create or replace function public.emergency_card_regenerate_token(p_subject uuid)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid   uuid := auth.uid();
  v_token text;
begin
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;
  if v_uid is null or not public.can_access_subject(p_subject) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  update public.emergency_cards
     set public_token = encode(gen_random_bytes(16), 'hex')
   where subject_id = p_subject
  returning public_token into v_token;

  if v_token is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (v_uid, 'emergency_card.token_regenerated', 'emergency_cards', p_subject, p_subject);

  return v_token;
end;
$$;

revoke execute on function public.emergency_card_regenerate_token(uuid) from public, anon;
grant execute on function public.emergency_card_regenerate_token(uuid) to authenticated;

comment on function public.emergency_card_regenerate_token(uuid) is
  'Assegna un nuovo public_token (16 byte casuali in esadecimale) alla scheda '
  'del soggetto: il vecchio indirizzo pubblico smette di funzionare. Richiede '
  'can_access_subject (42501); se la scheda non esiste 22023. '
  'Audit emergency_card.token_regenerated.';

-- 9.3 emergency_card_public — la pagina del soccorritore
--     Chi legge non ha un account: nessuna policy, solo questa funzione.
--     Escono il nome dal profilo, la data di aggiornamento e i soli campi
--     marcati fields_public = true. Un token sbagliato e uno inesistente
--     danno la stessa risposta: null.
create or replace function public.emergency_card_public(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_card public.emergency_cards%rowtype;
  v_pub  jsonb;
  v_out  jsonb;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{32}$' then
    return null;
  end if;

  select * into v_card from public.emergency_cards where public_token = p_token;
  if not found then
    return null;
  end if;

  v_pub := v_card.fields_public;
  v_out := jsonb_build_object(
    'display_name', (select p.full_name from public.profiles p where p.id = v_card.subject_id),
    'updated_at', to_char(v_card.updated_at at time zone 'UTC',
                          'YYYY-MM-DD"T"HH24:MI:SS"Z"'));

  if coalesce((v_pub->>'blood_group')::boolean, false) then
    v_out := v_out || jsonb_build_object('blood_group', v_card.blood_group);
  end if;
  if coalesce((v_pub->>'allergies')::boolean, false) then
    v_out := v_out || jsonb_build_object('allergies', to_jsonb(v_card.allergies));
  end if;
  if coalesce((v_pub->>'medications')::boolean, false) then
    v_out := v_out || jsonb_build_object('medications', to_jsonb(v_card.medications));
  end if;
  if coalesce((v_pub->>'conditions')::boolean, false) then
    v_out := v_out || jsonb_build_object('conditions', to_jsonb(v_card.conditions));
  end if;
  if coalesce((v_pub->>'contacts')::boolean, false) then
    v_out := v_out || jsonb_build_object('contacts', v_card.contacts);
  end if;
  if coalesce((v_pub->>'notes')::boolean, false) then
    v_out := v_out || jsonb_build_object('notes', to_jsonb(v_card.notes));
  end if;

  -- Chi apre la pagina non ha un account: attore nullo, come share_link.opened.
  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (null, 'emergency_card.viewed', 'emergency_cards', v_card.subject_id, v_card.subject_id);

  return v_out;
end;
$$;

revoke execute on function public.emergency_card_public(text) from public;
grant execute on function public.emergency_card_public(text) to anon, authenticated;

comment on function public.emergency_card_public(text) is
  'Pagina pubblica della scheda di emergenza: token di 32 esadecimali, '
  'altrimenti null. Restituisce display_name (full_name del profilo), '
  'updated_at e i soli campi con fields_public = true; null se il token non '
  'esiste, senza distinguere i due casi. Nessun altro dato del profilo. '
  'Audit emergency_card.viewed con attore nullo.';

insert into public.app_migrations(name) values ('0023_doctor_v1_questions_ice') on conflict do nothing;
