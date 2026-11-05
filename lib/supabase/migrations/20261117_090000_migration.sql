-- ============================================================================
-- Medical 24 — 0028 CHIUSURA DELL'ACCOUNT (P10-A4)
--
-- Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.
--
-- Il soft delete (soft_delete_account) chiude l'accesso e avvia il conto alla
-- rovescia dei trenta giorni, ma fino a ieri lasciava vive tre cose che non
-- passano dall'app: i link di condivisione del dossier, il QR della scheda di
-- emergenza e le domande inviate al medico. Chi aveva il codice continuava a
-- leggere i dati di una persona che se n'era andata.
--
--   account_close(p_subject uuid) returns jsonb   solo service_role
--
-- Che cosa fa, nell'ordine:
--   1. revoca tutti gli share_links attivi del soggetto (revoked_at = now());
--   2. cancella la riga di emergency_cards: il QR pubblico smette di
--      funzionare nello stesso istante, perche' sparisce il public_token;
--   3. chiude le questions che non sono gia' chiuse;
--   4. segna 'expired' i data_exports ready: il pacchetto non si scarica piu';
--   5. scrive audit 'account.closed'.
--
-- Non tocca i dati clinici: quelli li cancella purge_subject_data a trenta
-- giorni, chiamata da purge_deleted_accounts. Questa funzione spegne soltanto
-- le porte aperte verso l'esterno.
--
-- Idempotente due volte: la migrazione (create or replace) e la funzione
-- stessa (la seconda chiamata trova tutto gia' fatto e restituisce zeri).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. account_close — chiude tutto cio' che e' raggiungibile da fuori
--
--    Attore dell'audit: auth.uid() quando la chiamata nasce da una sessione
--    (la Edge Function usa il service_role, quindi di norma e' nullo). Un
--    attore nullo non e' un difetto: e' la chiusura eseguita dal servizio.
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
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'not_allowed' using errcode = '42501';
  end if;
  if p_subject is null then
    raise exception 'invalid_subject' using errcode = '22023';
  end if;

  -- 1. Link di condivisione ancora validi: revocati tutti insieme. Il trigger
  --    trg_share_links_audit della 0021 scrive una riga share_link.revoked per
  --    ciascuno, quindi qui non serve altro audit.
  update public.share_links
     set revoked_at = now()
   where subject_id = p_subject
     and revoked_at is null;
  get diagnostics v_links = row_count;

  -- 2. Scheda di emergenza: si cancella, non si nasconde. Finche' la riga
  --    esiste esiste anche il public_token, e il QR stampato continua a
  --    funzionare.
  delete from public.emergency_cards where subject_id = p_subject;
  get diagnostics v_card = row_count;

  -- 3. Domande al medico: chiuse. Non si cancellano, perche' una risposta gia'
  --    ricevuta resta un dato del soggetto fino alla purge.
  update public.questions
     set status = 'closed'
   where subject_id = p_subject
     and status <> 'closed';
  get diagnostics v_questions = row_count;

  -- 4. Export pronti: scaduti subito. La URL firmata vive dieci minuti, ma il
  --    file non deve poter essere richiesto di nuovo.
  update public.data_exports
     set status     = 'expired',
         expires_at = least(coalesce(expires_at, now()), now())
   where subject_id = p_subject
     and status = 'ready';
  get diagnostics v_exports = row_count;

  insert into public.audit_log(actor_id, action, target_table, target_id, subject_id)
  values (auth.uid(), 'account.closed', 'profiles', p_subject, p_subject);

  return jsonb_build_object(
    'links_revoked',          v_links,
    'questions_closed',       v_questions,
    'emergency_card_removed', v_card,
    'exports_expired',        v_exports
  );
end;
$$;

revoke execute on function public.account_close(uuid)
  from public, anon, authenticated;
grant execute on function public.account_close(uuid) to service_role;

comment on function public.account_close(uuid) is
  'Chiusura dell''account: revoca tutti i link di condivisione attivi, cancella '
  'la scheda di emergenza (il QR pubblico smette di funzionare subito), chiude '
  'le domande al medico non chiuse e segna scaduti gli export pronti. Audit '
  '''account.closed'' con attore auth.uid() se la chiamata nasce da una '
  'sessione, altrimenti nullo. Solo service_role (42501); p_subject nullo e'' '
  '22023. Restituisce {links_revoked, questions_closed, emergency_card_removed, '
  'exports_expired}; idempotente, la seconda chiamata restituisce tutti zeri. '
  'Non cancella dati clinici: quelli sono di purge_subject_data a trenta giorni.';

insert into public.app_migrations(name) values ('0028_account_closure')
  on conflict do nothing;
