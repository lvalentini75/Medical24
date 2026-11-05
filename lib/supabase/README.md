# Medical 24 Supabase deployment

All SQL files are intentionally kept under `lib/supabase/` so they can be reviewed together with the application code.

## Order

Migrazioni e test si eseguono dal SQL Editor della dashboard Supabase, in ordine, come elencato qui sotto; il modulo Schema Deployment di Dreamflow non va usato per i file SQL e non va mai puntato alla cartella tests/; il modulo si usa solo per il deploy delle Edge Functions.

1. Run `supabase_tables.sql`.
2. Run `supabase_policies.sql`.
3. Enable the `pg_cron` extension from **Database > Extensions** before applying
   the archive migration.
4. Apply the files in `migrations/` in timestamp order:
   - `20261024_104530_migration.sql` — 0002 archive (tables, Storage, cron);
   - `20261024_163000_migration.sql` — 0003 archive completion
     (`documents.duplicate_dismissed_at`, `document_usage()`, grant);
   - `20261024_170000_migration.sql` — 0004 `soft_delete_document()`;
   - `20261025_090000_migration.sql` — 0005 engine schema
     (`biomarker_catalog`, `extractions`, `observations`, `normalize_unit`,
     `resolve_reference`, `resolve_flag`, `start_extraction`,
     `confirm_observation`, `analysis_usage`, RLS, realtime, cron);
   - `20261025_091500_migration.sql` — 0006 biomarker catalog seed
     (73 rows from `doc/board/biomarker_catalog.csv`, all `draft`,
     `board_version = 0`).
5. Run the pgTAP files in `tests/` only against the development project.
6. Redeploy `document-ingest` after step 4: it now validates the magic bytes
   of every page and sets `page_count` from the uploaded pages for
   camera/gallery documents.
7. Deploy `extract`, `extract-batch` and `extract-batch-poll` after step 4.
   Set `CLAUDE_API_KEY` and `SUPABASE_SERVICE_ROLE_KEY` in **Edge Functions >
   Secrets**; never commit their values. The function runtime already supplies
   `SUPABASE_URL` and `SUPABASE_ANON_KEY`.

In the Supabase panel, open **SQL Editor**, create a query for each file, paste its contents, and choose **Run**. Do not run the tests against production. The `app_migrations` table is deny-all by design; it is read only from the SQL Editor and Edge Functions. Add one `app_migrations` row at the end of every future migration.

## Storage and scheduled jobs

## 0007 — Salute

La migrazione 0007 aggiunge le tabelle del modulo Salute (`biomarker_catalog`, `biomarker_watch` e `observations`), la vista `biomarker_series` e le funzioni RPC `biomarker_catalog_for_subject(p_subject uuid)`, `biomarker_stats(p_subject uuid, p_code text, p_from timestamptz, p_to timestamptz)`, `biomarker_episodes(p_subject uuid, p_code text)` e `observations_export(p_subject uuid)`. Le policy consentono all'utente autenticato di leggere e modificare solo le righe con il proprio `subject_id`; le funzioni applicano lo stesso vincolo e la funzione di export restituisce esclusivamente le colonne dichiarate dalla migrazione. Migrazione e test si lanciano solo dal SQL Editor.

Enable `pg_net` and `vault` from **Database > Extensions** before configuring
the batch scheduler. Store the function URL and service-role key in Vault,
not in migrations or the Flutter client. Configure a cron invocation of
`extract-batch-poll` (for example every five minutes) through the Supabase
Edge Functions scheduler, using the Vault-backed secret.

Create the private bucket `documents` from **Storage > New bucket**. Set the file size limit to 25 MB. The archive migration also declares the bucket policies; review the resulting policies before enabling uploads.

After enabling `pg_cron` before 0002, the archive migration registers its cleanup schedule. Review it in **Database > Extensions** and **SQL Editor**. The scheduled job marks uploads older than 24 hours as failed; keep the account-deletion retention period at 30 days.

Migration 0005 registers a second job, `enqueue-pending-extractions` (03:45), which only queues the documents that were never read. The queue is drained by `extract-batch-poll`, which must be scheduled from the Edge Functions scheduler: it needs the `service_role` key and that key never belongs in a migration.

## 0011 — Rischi e prevenzione

La migrazione crea `risk_scores`, `questionnaires`, `questionnaire_answers`, `prevention_calendar`, `recommendations`, `risk_projections` e `doctor_thresholds`, oltre alla vista `latest_risk_scores`. Espone `refresh_recommendations(p_subject uuid)`, `complete_recommendation(p_id uuid, p_document uuid default null)` e `resolve_thresholds(p_subject uuid, p_code text)`. Trigger, cron e policy usano `can_access_subject(subject_id)`.

## 0012 — Raccomandazioni derivate

La migrazione aggiunge `recommendations.code`, `dismissed_at` e `dismiss_reason` e le funzioni `dismiss_recommendation(p_id uuid, p_reason text default null)` e `reopen_recommendation(p_id uuid)`. Le regole cliniche sono in `rule_versions` e restano `status = draft` finché il board non le valida.

## 0013 — Spiegazioni

La migrazione crea `explanations` (cache per soggetto, bersaglio, livello, lingua e `inputs_hash`, con l'indice unico su quelle sei colonne) e le funzioni `normalize_for_filter(p_text text)`, `check_forbidden_phrases(p_text text)`, `explanation_context(p_subject uuid, p_target_type text, p_target_id text)`, `explanation_lookup(...)`, `explanation_usage(p_subject uuid)` ed `explanation_save(...)`. La regola `forbidden_phrases 0.1-draft` entra in `rule_versions` con `status = active`: è un filtro di sicurezza e non può restare in bozza, il board la amplia aggiungendo pattern alla stessa riga. `explanations` ha una sola policy, di lettura, con `can_access_subject(subject_id)`: la scrittura passa esclusivamente da `explanation_save`, eseguibile solo dalla service role, che registra `explanation.generated` in `audit_log` senza il testo. Il limite è di 30 generazioni nuove al giorno per soggetto.

Nota tecnica: nelle espressioni regolari di PostgreSQL `\b` è il backspace, non il confine di parola; `check_forbidden_phrases` traduce i `\b` dei pattern del board in `\y` prima di applicarli con `~*`.

Dopo la 0013 va deployata la Edge Function `explain` (verify_jwt attivo) e vanno impostati `CLAUDE_API_KEY` e `CLAUDE_MODEL_MEDIUM` in **Edge Functions > Secrets**.

## 0017 — Cure: schema e RLS

La migrazione `20261106_090000_migration.sql` (registro `0017_treatments_schema`) crea le sette tabelle del modulo M8 Cure: `facilities`, `doctors`, `treatment_tags`, `treatments`, `reviews`, `favorites` e `rating_summaries`. Tutte hanno RLS attiva e forzata e nascono in default deny.

Enum introdotti: `facility_kind`, `doctor_role`, `treatment_tag_kind`, `treatment_family`, `treatment_scope`, `treatment_evidence_level`, `treatment_modality`, `treatment_status`, `review_target_type` (condiviso da `reviews`, `favorites` e `rating_summaries`) e `review_status`.

`treatments.search_vector` è una colonna generata (`stored`) costruita da `m24_treatment_search_doc` con configurazione `italian` su titolo, sommario, categoria, patologie, tag e testo delle cinque sezioni di `description_sections`; è indicizzata con GIN. Ci sono inoltre indici su `(status, scope)`, `(status, family)`, `(facility_id)`, `(doctor_id)` e un indice trigram su `title` (estensione `pg_trgm`, abilitata dalla migrazione).

Vincoli notevoli: `summary` ≤ 240 caratteri, `price_from_cents ≤ price_to_cents`, `description_sections` oggetto con sole chiavi `per_chi`, `come_funziona`, `durata`, `rischi_e_controindicazioni`, `evidenze_e_limiti`, `contraindications` array di `{text, severity: bassa|media|alta}`, `media` array di `{type: image|video, url, caption}`, `reviews.rating` 1–5, `title` ≤ 80, `body` 20–2000, unique `(author_id, target_type, target_id)`.

Trigger: `trg_treatments_check_tags` rifiuta (errore `23514`) ogni tag che non esista in `treatment_tags`; `trg_reviews_rating_summary` ricalcola `rating_summaries` contando solo le recensioni `approved`, a ogni insert, cambio di stato e ritiro; i `trg_*_updated_at` usano `set_updated_at()` delle fondamenta.

Accesso: lettura pubblica (`anon` e `authenticated`) delle strutture e dei medici solo se `verified` o `is_demo`, delle cure solo con `status = 'published'`, delle recensioni solo se `approved`, del vocabolario dei tag e di `rating_summaries` sempre; l'autore legge le proprie recensioni in ogni stato; l'admin legge tutto. **Nessuna scrittura diretta**: l'unica tabella scrivibile dal client è `favorites` (select, insert e delete del solo proprietario). Le funzioni di redazione, ricerca e moderazione arrivano con P07-A2 e P07-A3; questa migrazione non contiene seed di contenuto.

Il test `tests/0017_treatments_schema_test.sql` dichiara `plan(28)` e si esegue solo sul progetto dev dal SQL Editor.

## 0018 — Cure: funzioni di lettura

La migrazione `20261107_090000_migration.sql` (registro `0018_treatments_read`) aggiunge **solo funzioni di lettura** sopra lo schema della 0017, che non viene toccata. Nessuna scrittura, nessuna tabella nuova, nessun seed, nessuna schermata: la redazione e la moderazione arrivano con P07-A3.

Tutte le funzioni pubbliche sono `security invoker` e `stable`, eseguibili da `anon` e `authenticated`: girano con i privilegi del chiamante, quindi la RLS della 0017 resta l'unico guardiano e chi non è admin vede comunque soltanto le cure `published`, i medici e le strutture `verified` o `is_demo` e le recensioni `approved`.

- `search_treatments(p_query text, p_scope text[], p_family text[], p_modality text[], p_city text, p_min_rating numeric, p_max_price_cents int, p_duration_bucket text, p_conditions text[], p_tags text[], p_sort text, p_limit int, p_offset int)` → `id, title, summary, family, scope, evidence_level, price_from_cents, session_minutes, modality, doctor_display_name, facility_name, facility_city, cover_url, rating_avg, rating_count, is_demo, featured, total_count`. Il testo libero usa `websearch_to_tsquery('italian')` su `search_vector`, più `ilike` sul nome del medico e su quello della struttura, più similarità trigram sul titolo con soglia 0,3. `p_duration_bucket` accetta `30|45|60|90` e seleziona `session_minutes <= bucket` (altro valore: `22023`). `p_sort` accetta `pertinenza` (ts_rank poi valutazione), `rating`, `prezzo_asc`, `prezzo_desc`, `attesa`, `recenti` (altro valore: `22023`). `p_limit` è costretto tra 1 e 50; `total_count` è una window function e resta il totale prima della paginazione.
- `facets_for_treatments(...)` — stessi dieci filtri, senza ordinamento né paginazione → `jsonb` con `total` e i conteggi per `scope`, `family`, `modality`, `city` ed `evidence_level` calcolati sullo stesso insieme filtrato della ricerca.
- `treatment_detail(p_id uuid)` → `jsonb` completo della cura (sezioni, controindicazioni con la severità massima, prezzi, tempi, media, `cover_url`) con `doctor`, `facility`, `rating` da `rating_summaries` e le ultime cinque recensioni `approved`; `null` se la cura non è visibile al chiamante.
- `treatment_compare(p_ids uuid[])` → da 2 a 4 cure (fuori intervallo: `22023`) con `title, session_minutes, sessions_count, course_weeks, price_from_cents, price_to_cents, waiting_days, modality, evidence_level, max_contraindication_severity, rating_avg, rating_count, doctor_display_name, facility_name`, nell'ordine degli id richiesti.
- `reviews_for_target(p_target_type text, p_target_id uuid, p_limit int, p_offset int)` → recensioni `approved` dalla più recente, con `author_label` (nome più iniziale del cognome), `verified` e `total_count`.
- `featured_treatments(p_limit int)` → cure `published` e `featured` per la home.

Funzioni interne (prefisso `m24_`, non destinate al client): `m24_treatments_filtered(...)` è il corpo unico del filtro condiviso da ricerca, faccette e confronto; `m24_display_name_initial`, `m24_treatment_cover_url` e `m24_max_contraindication` sono pure; `m24_review_author_label(uuid)` è `security definer` e legge da `profiles` esclusivamente `full_name`, restituendolo già ridotto (nessun altro campo del profilo esce dalla funzione).

Il test `tests/0018_treatments_read_test.sql` dichiara `plan(34)` e si esegue solo sul progetto dev dal SQL Editor.

## 0019 — Cure: funzioni di scrittura e moderazione

La migrazione `20261108_090000_migration.sql` (registro `0019_treatments_write`) aggiunge **solo funzioni di scrittura e moderazione** sopra lo schema della 0017 e le letture della 0018, che non vengono toccate. Nessuna tabella nuova, nessun seed, nessuna schermata.

Le tabelle del modulo non hanno policy di scrittura (default deny della 0017): la via di scrittura è una sola. Tutte le funzioni sono `security definer`, **revocate a `public` e a `anon`** e concesse a `authenticated` (e `service_role`), con i controlli dentro.

- `submit_review(p_target_type text, p_target_id uuid, p_rating int, p_sub_ratings jsonb, p_title text, p_body text)` → `uuid`. Autore = `auth.uid()`; il bersaglio deve esistere ed essere visibile (cura `published`, medico o struttura `verified`/`is_demo`); voto 1–5; `sub_ratings` con sole chiavi `efficacia`, `costo`, `esperienza`, `chiarezza` e valori interi 1–5; titolo ≤ 80; corpo 20–2000 caratteri, senza URL (riconosciuti via espressione regolare) e senza nessuno dei trenta pattern della regola `forbidden_phrases` del board (`check_forbidden_phrases`): una recensione non è il posto per diagnosi o terapie rivolte ad altri. Massimo **cinque recensioni al giorno** per autore (`daily_limit_reached`, `P0001`); una sola per autore e bersaglio (il `23505` dell'indice unico diventa l'errore leggibile `review_exists`, sempre `23505`). La recensione nasce `pending`; audit `review.submitted`.
- `moderate_review(p_id uuid, p_status text, p_note text)` → `void`. Solo admin (`42501`); `p_status` è `approved` o `rejected`; valorizza `moderated_by` e `moderated_at`; audit `review.moderated` e riga `admin_action` in `platform_events` (inserimento diretto, come in `ai_task_set`).
- `withdraw_review(p_id uuid)` → `void`. Solo l'autore (`42501` per chiunque altro); stato `withdrawn`; audit `review.withdrawn`.
- `treatment_upsert(p_payload jsonb)` → `uuid`. Solo admin. Payload a chiavi chiuse; senza `id` crea una scheda `draft`, con `id` aggiorna. Valida enum (`family`, `scope`, `evidence_level`, `modality`), prezzi (non negativi e `from ≤ to`), valuta a tre lettere, minuti e conteggi positivi, chiavi ammesse di `description_sections`, esistenza dei `tags` nel vocabolario, forma di `contraindications` e `media`, esistenza di `doctor_id` e `facility_id`. **Una modifica a una cura `published` incrementa `version`**: la scheda pubblicata non cambia in silenzio. Audit `treatment.upsert`.
- `treatment_set_status(p_id uuid, p_status text)` → `void`. Solo admin. Transizioni ammesse: `draft → verified → published → retired` e `published → verified`; qualsiasi altra è `invalid_transition` (`22023`). `published` richiede un medico **o** una struttura e la sezione `evidenze_e_limiti` non vuota; `published_at` è valorizzato alla prima pubblicazione e non viene più riscritto. Audit `treatment.status` e `admin_action`.
- `doctor_upsert(p_payload jsonb)` e `facility_upsert(p_payload jsonb)` → `uuid`. Solo admin, payload a chiavi chiuse, validazione di enum, coordinate, orari e array; un medico `verified` deve avere albo e numero di iscrizione. Audit `doctor.upsert` e `facility.upsert`.
- `toggle_favorite(p_target_type text, p_target_id uuid)` → `boolean`. Aggiunge o rimuove il preferito di `auth.uid()` e restituisce lo stato finale: `true` se adesso è tra i preferiti, `false` se è stato tolto.

Funzioni interne (prefisso `m24_`, non destinate al client ma eseguibili da `authenticated` perché usate dalle precedenti): `m24_require_auth`, `m24_require_admin`, `m24_target_exists`, `m24_has_url`, `m24_valid_sub_ratings` e i lettori tipati `m24_jsonb_text`, `m24_jsonb_int`, `m24_jsonb_bool`, `m24_jsonb_text_array`.

Il test `tests/0019_treatments_write_test.sql` dichiara `plan(26)` e si esegue solo sul progetto dev dal SQL Editor (Alice utente, Bob admin, Carla terza utente).

## 0020 — Cure: seed dimostrativo

La migrazione `20261109_090000_migration.sql` (registro `0020_treatments_seed`) aggiunge esclusivamente dati dimostrativi idempotenti con identificativi fissi: 10 strutture, 16 professionisti, 40 tag, 40 cure `published` (8 `featured`), 6 utenti Auth e 134 recensioni (120 `approved`, 10 `pending`, 4 `rejected`). Strutture, professionisti e cure hanno `is_demo = true`; i nomi dichiarano esplicitamente la natura demo e i contenuti italiani sono informativi, prudenti e privi di promesse di guarigione. Le immagini usano soltanto URL neutri `https://placehold.co/...`.

La distribuzione delle cure e': 12 riabilitazione, 10 prevenzione/diagnostica con evidenza `linee_guida`, 8 benessere con evidenza `esperienziale` o `osservazionale`, 6 terapie tradizionali con `studi_clinici` e 4 percorsi sperimentali `osservazionale` con limiti espliciti. Ogni scheda ha cinque sezioni, 1-3 controindicazioni, prezzi, tempi, modalita', 1-2 media, medico e struttura. Il trigger della 0017 aggiorna i 40 riepiloghi di valutazione.

La funzione interna `m24_seed_0020_treatments_demo()` e' revocata a `public`, `anon` e `authenticated` e serve soltanto a eseguire e verificare nuovamente lo stesso seed senza duplicazioni. Il test `tests/0020_treatments_seed_test.sql` dichiara `plan(35)` e si esegue solo sul progetto dev dal SQL Editor.

## 0021 — Medico v1: dossier condiviso, domande, scheda di emergenza

La migrazione `20261110_090000_migration.sql` (registro `0021_doctor_v1_schema`) crea le cinque tabelle del modulo M9 Medico v1: `share_links`, `share_link_opens`, `dossier_snapshots`, `questions` ed `emergency_cards`. Tutte hanno RLS attiva e **forzata**, una sola policy di `select` e nessuna policy di scrittura: le funzioni applicative arrivano con P08-A2, le Edge Functions (`dossier-pdf`) più avanti. Nessun seed, nessuna schermata.

Enum introdotti: `share_open_outcome` (`ok`, `wrong_pin`, `expired`, `revoked`, `locked`, `exhausted`), `question_status` (`draft`, `sent`, `answered`, `closed`), `question_channel` (`link`, `app`). Estensioni richieste: `pgcrypto` (già attiva) e `btree_gist` per il vincolo di esclusione sul codice.

- `share_links`: `code` è di sei cifre (`^[0-9]{6}$`); `pin_hash` accetta solo un hash bcrypt (`^\$2[aby]?\$`), prodotto da `crypt(pin, gen_salt('bf'))` nelle funzioni di A2 — **il PIN in chiaro non entra mai nel database, nei log e negli URL**. `scope` è validato da `m24_valid_share_scope`: o esattamente `{"all": true}`, o un oggetto con sole chiavi `organs`, `from`, `to`, `categories`, array di stringhe e date `AAAA-MM-GG` con `from ≤ to`. Default: scadenza a 7 giorni, `max_opens` 20, contatori a zero. Il codice è univoco tra i link **non revocati le cui finestre di validità si sovrappongono** (vincolo di esclusione GiST `share_links_code_active_excl` su `code` e `tstzrange(created_at, expires_at)`, `where revoked_at is null`): scaduto il link, il codice torna disponibile.
- `share_link_opens`: registro delle aperture con esito, `ip_hash` e `user_agent_hash` — mai l'IP o lo user agent in chiaro, mai un dato clinico. Append-only: il trigger `trg_share_link_opens_append_only` rifiuta `update` e `delete` con `42501` anche per `postgres` (unica eccezione, l'interruttore di sessione `medical24.allow_purge` usato dalla cancellazione dell'account). È ciò che il paziente vede nella pagina del link.
- `dossier_snapshots`: `payload` jsonb con stato di salute, rischi con livello, organi in attenzione, ultimi valori fuori intervallo con tendenza, esami consigliati ed elenco dei documenti nello scope (solo id, titolo, categoria e data); `pdf_path` e `rule_versions` con le versioni delle regole usate. Append-only con lo stesso trigger.
- `questions`: `title` ≤ 120 caratteri (la colonna si chiama `title`, non `subject`: in tutto il progetto "subject" è il paziente), `body` ≤ 4000, `answer` con `answered_at` e `answered_via` coerenti (vincolo `questions_answer_consistency`: `status = 'answered'` se e solo se risposta e data sono presenti).
- `emergency_cards`: una riga per soggetto (`subject_id` chiave primaria); `blood_group` ristretto ai valori ABO/Rh; `contacts` array di `{name, phone, relation}` validato da `m24_valid_emergency_contacts`; `notes` ≤ 500; `public_token` di 32 caratteri esadecimali casuali, univoco e rigenerabile; `fields_public` oggetto di soli booleani sui sei campi (`m24_valid_public_fields`). **Nessuna policy per `anon`**: la pagina pubblica legge con una funzione `security definer` a token, in A2.

Indici: `share_links(subject_id, created_at desc)` e `share_links(code)` parziale sui non revocati, `share_link_opens(share_link_id, opened_at desc)`, `dossier_snapshots(subject_id, generated_at desc)`, `questions(subject_id, created_at desc)`, `emergency_cards(public_token)`.

Audit: `trg_share_links_audit` scrive `share_link.created` alla creazione e `share_link.revoked` al primo valorizzare di `revoked_at`; `trg_share_link_opens_audit` scrive `share_link.opened` solo per le aperture con esito `ok`. In tutti e tre i casi `actor_id` è `null` (chi apre il link non ha un account) e `subject_id` è quello del soggetto.

Accesso: una sola policy di `select` per tabella, tutte basate su `can_access_subject(subject_id)` (per `share_link_opens` attraverso il join sul link). `anon` non ha alcun privilegio; `authenticated` ha solo `select`: ogni tentativo di `insert`, `update` o `delete` diretto fallisce con `42501`.

Il test `tests/0021_doctor_v1_schema_test.sql` dichiara `plan(32)` e si esegue solo sul progetto dev dal SQL Editor (fixture Alice e Bob).

## 0022 — Medico v1: costruzione del dossier

La migrazione `20261111_090000_migration.sql` (registro `0022_doctor_v1_dossier`) aggiunge **tre funzioni** sopra lo schema della 0021, che non viene toccata. Nessuna tabella nuova, nessuna Edge Function, nessuna schermata, nessun seed.

`dossier_build(p_subject uuid, p_scope jsonb default '{"all": true}'::jsonb, p_share_link_id uuid default null) → uuid`. `security definer`, `set search_path = public, extensions`, `execute` revocato a `public` e `anon` e concesso solo ad `authenticated` e `service_role`. Richiede `can_access_subject(p_subject)` oppure il `service_role` (altrimenti `not_allowed`, `42501`); `p_subject` nullo, scope non valido secondo `m24_valid_share_scope` e `p_share_link_id` che non appartiene al soggetto sono `22023` (`invalid_subject`, `invalid_scope`, `invalid_share_link`).

Inserisce una riga in `dossier_snapshots` (con `generated_at = clock_timestamp()`) e ne restituisce l'id. Il `payload` ha `version = 1` e queste chiavi:

- `subject`: solo `full_name`, `birth_date`, `gender` da `profiles`; nient'altro.
- `scope`: lo scope ricevuto, così com'è.
- `health_status`: `level`, `organs_ok`, `organs_monitor`, `organs_attention`, `organs_missing` da `latest_organ_states`; `level` è `attention` se almeno un organo è in attenzione, altrimenti `monitor` se almeno uno è da monitorare, `missing` se non c'è alcun dato, altrimenti `ok`.
- `organs`: da `latest_organ_states` i soli stati `monitor` e `attention` (`organ_id`, `state`, `computed_at`, `rule_version`), ordinati con gli organi in **attenzione prima** di quelli da monitorare e, a parità di stato, per `organ_id`; con `scope.organs` solo quelli elencati.
- `risks`: da `latest_risk_scores` (`family`, `level`, `score`, `computed_at`, `rule_version`).
- `out_of_range`: per ogni codice l'ultimo valore confermato e non superato con flag fuori intervallo (`below`, `above`, `critical_low`, `critical_high`), con `code`, `name` (dal catalogo nella lingua del profilo), `value`, `unit`, `ref_low`, `ref_high`, `flag`, `effective_at`, `document_id`, `trend`, `previous_value`, `previous_at`. `trend` è `up`/`down`/`stable` rispetto al valore confermato precedente dello stesso codice (`stable` entro il 5%), `null` se non esiste un precedente. Con `scope.organs` solo i codici di quegli organi in `organ_biomarker_map`; con `from`/`to` solo gli `effective_at` nell'intervallo; ordinamento `effective_at desc`, massimo 40 righe.
- `recommended_exams`: da `recommendations` con `status = 'open'` (`id`, `kind`, `title`, `reason`, `due_at`, `origin`), massimo 20.
- `documents`: da `documents` nello scope (`categories` e `from`/`to` su `document_date`): solo `id`, `title`, `category`, `document_date`, data decrescente, massimo 100. **Mai `storage_path`, mai il testo del documento.**
- `counts`: `observations_confirmed` e `documents_total` con gli stessi filtri dello scope.
- `disclaimer_key`: `'dossier.disclaimer'`.

Nessun testo generato dall'IA entra nel dossier. `rule_versions` della riga è `{organ_rules: [...], risk_rules: [...]}` con le sole versioni distinte effettivamente usate. Audit: `dossier.built` con attore `auth.uid()` (nullo per il `service_role`), `target_table = 'dossier_snapshots'`, `target_id` dello snapshot e `subject_id` del soggetto — nessun dato clinico.

`dossier_latest(p_subject uuid) → jsonb`. `security definer`, `stable`, `execute` revocato a `public` e `anon` e concesso ad `authenticated` e `service_role`; richiede `can_access_subject(p_subject)` oppure il `service_role` (`42501`), `p_subject` nullo è `22023`. Restituisce l'**ultimo dossier personale** del soggetto — l'ultimo `dossier_snapshots` **senza `share_link_id`**, perché i dossier congelati per un link appartengono a quel link e non alla schermata del paziente — nella forma `{id, generated_at, payload, pdf_path}`; `null` se non ce n'è nessuno.

`dossier_snapshot_set_pdf(p_snapshot uuid, p_path text) → void`. `security definer`, `execute` revocato a `public`, `anon` e `authenticated` e concesso **soltanto a `service_role`**: la scrive esclusivamente la Edge Function `dossier-pdf`, e una chiamata da `authenticated` fallisce con `42501` prima di entrare nel corpo. Il percorso deve essere esattamente `subjects/{subject_id}/dossier/{snapshot_id}.pdf`, altrimenti `invalid_pdf_path` (`22023`); snapshot inesistente e percorso vuoto sono anch'essi `22023`. La scrittura avviene una volta sola: la seconda è rifiutata dal trigger `m24_guard_dossier_snapshot` della 0021 con `42501`.

Il test `tests/0022_doctor_v1_dossier_test.sql` dichiara `plan(23)` e si esegue solo sul progetto dev dal SQL Editor (Alice con due stati d'organo, un punteggio di rischio, tre osservazioni confermate, un documento e un esame consigliato; Bob estraneo). Per la durata della prova i trigger di ricalcolo su `observations` restano disattivati, così il dossier legge esattamente la fixture dichiarata.

## 0023 — Medico v1: domande al medico e scheda di emergenza

La migrazione `20261112_090000_migration.sql` (registro `0023_doctor_v1_questions_ice`) aggiunge le **funzioni delle domande** e quelle della **scheda di emergenza (ICE)** sopra lo schema della 0021, che non viene toccato. Nessuna tabella nuova, nessuna Edge Function, nessuna schermata, nessun seed.

Tutte le funzioni sono `security definer` con `set search_path = public, extensions`, `execute` revocato a `public` e `anon` e concesso soltanto ai ruoli indicati. Errori: `22023` per l'input non valido (`invalid_subject`, `invalid_title`, `invalid_body`, `invalid_answer`, `invalid_doctor_email`, `invalid_share_link`, `invalid_question`), `42501` `not_allowed` per l'accesso, `P0001` con codice parlante per lo stato (`daily_limit`, `not_editable`, `not_sendable`, `not_answerable`, `already_closed`, `not_deletable`). Ogni cambio di stato scrive `audit_log` con azione `question.<azione>`, `target_table = 'questions'`, `target_id` della domanda e `subject_id` del soggetto: mai il testo della domanda o della risposta.

La guardia interna `m24_question_for_update(p_id)` (nessun `execute` per `anon` e `authenticated`) blocca la riga e verifica `can_access_subject(subject_id)` una volta sola per tutte le azioni del paziente.

Per `authenticated` con `can_access_subject` sul soggetto della domanda:

- `question_create(p_subject uuid, p_title text, p_body text, p_share_link_id uuid default null, p_doctor_email text default null) → uuid`: nasce `draft`; titolo e testo ritagliati (1–120 e 1–4000 caratteri); `p_share_link_id`, se presente, deve essere un link dello stesso soggetto (`invalid_share_link`); massimo **20 domande create al giorno per soggetto** (`daily_limit`). Audit `question.created`.
- `question_update(p_id uuid, p_title text, p_body text) → void`: solo in `draft`, altrimenti `not_editable`. Audit `question.updated`.
- `question_send(p_id uuid) → void`: `draft → sent`, altrimenti `not_sendable`. Audit `question.sent`.
- `question_record_answer(p_id uuid, p_answer text) → void`: `sent → answered` con `answered_via = 'app'` e `answered_at = now()` — è il paziente che registra una risposta ricevuta **fuori dall'app**; da ogni altro stato `not_answerable`. Risposta ritagliata, 1–8000 caratteri. Audit `question.answered`.
- `question_close(p_id uuid) → void`: da qualunque stato diverso da `closed` a `closed`, **conservando la risposta**; se è già chiusa `already_closed`. Audit `question.closed`.
- `question_delete(p_id uuid) → void`: solo in `draft`, altrimenti `not_deletable`. Audit `question.deleted`.

Soltanto per `service_role` (la pagina pubblica del dossier passa dalla Edge Function `dossier-open`; `execute` revocato anche ad `authenticated`):

- `questions_for_link(p_share_link_id uuid) → jsonb`: le domande `sent` e `answered` allegate a quel link, in ordine di creazione, nella forma `{id, title, body, status, answer, answered_at, created_at}` — **mai `subject_id`, mai `doctor_email`**.
- `question_answer_via_link(p_share_link_id uuid, p_question_id uuid, p_answer text) → void`: la domanda deve appartenere a quel link (`invalid_question`, `22023`) ed essere `sent` (`not_answerable`, `P0001`); diventa `answered` con `answered_via = 'link'`. Risposta ritagliata, 1–8000 caratteri. L'audit ha `actor_id` nullo, come `share_link.opened` della 0021: chi risponde dal link non ha un account.

### Scheda di emergenza (ICE)

- `emergency_card_upsert(p_subject uuid, p_payload jsonb) → jsonb`, `execute` solo ad `authenticated`, richiede `can_access_subject(p_subject)` (`42501`). Chiavi ammesse: `blood_group`, `allergies`, `medications`, `conditions`, `contacts`, `notes`, `fields_public`; qualunque altra chiave è `unknown_key` (`22023`). Gli array di testi arrivano **ritagliati, senza elementi vuoti, al massimo 80 caratteri l'uno e 20 in tutto** (altrimenti `invalid_<chiave>`, `22023`), normalizzati **prima** dell'update così che un payload sbagliato non lasci scritture a metà. Crea la riga se manca (con `public_token` dal default della 0021) e **aggiorna solo le chiavi presenti**: le assenti restano come sono, e `fields_public` si fonde voce per voce. I valori fuori dai vincoli della 0021 (gruppo sanguigno non canonico, contatto senza telefono, `fields_public` non booleani) falliscono con `23514`. Restituisce la riga completa, `public_token` compreso. Audit `emergency_card.updated`.
- `emergency_card_regenerate_token(p_subject uuid) → text`, `execute` solo ad `authenticated`, `can_access_subject` (`42501`): nuovo `encode(gen_random_bytes(16), 'hex')`, il vecchio indirizzo pubblico smette di funzionare; scheda inesistente `22023`. Audit `emergency_card.token_regenerated`.
- `emergency_card_public(p_token text) → jsonb`, `execute` ad **`anon` e `authenticated`**: il token deve essere di 32 caratteri esadecimali, altrimenti `null`; se la scheda esiste restituisce `display_name` (il `full_name` di `profiles`), `updated_at` e **i soli campi con `fields_public = true`** — `notes` è `false` per impostazione predefinita; se non esiste restituisce `null`, senza distinguere i due casi. Nessun altro dato del profilo. Audit `emergency_card.viewed` con `actor_id` nullo (chi soccorre non ha un account) e il `subject_id` del soggetto.

La funzione interna `m24_emergency_text_array(jsonb, text)` (nessun `execute` per `anon` e `authenticated`) normalizza gli array di testi.

Il test `tests/0023_doctor_v1_questions_ice_test.sql` dichiara `plan(39)` e si esegue solo sul progetto dev dal SQL Editor (Alice e Bob con un link attivo ciascuno): ciclo di vita completo della domanda, link di un altro soggetto, tetto di 20 domande al giorno, accesso negato a Bob, funzioni riservate viste dal contesto interno, e per la scheda chiave ignota, gruppo sanguigno non valido, upsert parziale, rigenerazione del token e pagina pubblica letta come `anon`.

Nella 0022, inoltre, l'array `organs` del payload è ora ordinato con gli organi in **attenzione prima** di quelli da monitorare e, a parità di stato, per `organ_id`; la migrazione resta idempotente.

## 0024 — Medico v1: creazione, revoca, elenco e apertura dei link

La migrazione `20261113_090000_migration.sql` (registro `0024_doctor_v1_links`) aggiunge **cinque funzioni** sopra lo schema della 0021 (non toccato), `dossier_build` della 0022 e `questions_for_link` della 0023. Nessuna tabella nuova, nessuna Edge Function, nessuna schermata, nessun seed.

Le tre funzioni del paziente sono `security definer` con `set search_path = public, extensions`, `execute` revocato a `public`, `anon` e `service_role` e concesso **soltanto ad `authenticated`**. Errori: `22023` per l'input non valido (`invalid_subject`, `weak_pin`, `invalid_expires_in`, `invalid_max_opens`, `invalid_scope`, `invalid_share_link`), `42501` `not_allowed` per l'accesso, `P0001` con codice parlante (`too_many_links`, `code_exhausted`). **Il PIN non viene mai salvato, loggato o restituito in chiaro**: in colonna finisce solo `crypt(p_pin, gen_salt('bf'))` e nessun messaggio di errore lo riporta.

La guardia interna `m24_valid_pin(text)` (nessun `execute` per `anon` e `authenticated`) accetta un PIN di 4–6 cifre che non siano tutte uguali e non formino una sequenza crescente o decrescente (`1234`, `123456`, `4321`, `9876`…).

- `share_link_create(p_subject uuid, p_pin text, p_scope jsonb default '{"all": true}'::jsonb, p_expires_in interval default '7 days', p_max_opens int default 20) → jsonb`: richiede `can_access_subject(p_subject)`. Scadenza fra **un'ora e trenta giorni**, aperture **da 1 a 100**, scope validato con `m24_valid_share_scope`; massimo **cinque link attivi** (non revocati e non scaduti) per soggetto, altrimenti `too_many_links`. Il codice è di sei cifre casuali (`lpad(floor(random()*1000000)::int::text, 6, '0')`), mai tutte uguali; se il vincolo di esclusione della 0021 lo rifiuta (`23P01`) si riprova, fino a dieci volte, poi `code_exhausted`. `created_by = auth.uid()`. Dopo l'insert chiama `dossier_build(p_subject, p_scope, id)` per congelare lo snapshot del link e restituisce `{id, code, scope, expires_at, max_opens, snapshot_id}`: **il PIN non torna indietro**. L'audit `share_link.created` lo scrive il trigger `trg_share_links_audit` della 0021.
- `share_link_revoke(p_id uuid) → void`: solo il proprietario (`can_access_subject` sul soggetto del link, altrimenti `42501`; link inesistente `22023`). Valorizza `revoked_at = now()` se è nullo, altrimenti non fa nulla, così l'audit `share_link.revoked` resta uno solo.
- `share_links_for_subject(p_subject uuid) → jsonb`: i link del soggetto degli **ultimi novanta giorni**, dal più recente, nella forma `{id, code, scope, created_at, expires_at, max_opens, opens_count, last_opened_at, status, opens}`. `status` è calcolato nell'ordine `revoked`, `expired`, `locked` (`locked_until > now()`), `exhausted` (`opens_count >= max_opens`), `active`; `opens` sono le ultime dieci righe di `share_link_opens` con `{opened_at, outcome}`. **Mai `pin_hash`, mai gli hash dell'IP e dello user agent.**

### Apertura del link (solo `service_role`)

Le due funzioni seguenti hanno `execute` revocato a `public`, `anon` e `authenticated`, concesso soltanto a `service_role`, e in più controllano `auth.role() = 'service_role'` come `questions_for_link` della 0023: le chiama unicamente la Edge Function `dossier-open`, perché chi apre il link non ha un account.

- `share_link_open(p_code text, p_pin text, p_ip_hash text default null, p_ua_hash text default null) → jsonb`: cerca il link **più recente** con quel codice (`select … for update`). Se non esiste restituisce `{outcome: 'not_found'}` **senza scrivere nulla**. Altrimenti registra sempre una riga in `share_link_opens` con l'esito, `p_ip_hash` e `p_ua_hash`, e risponde nell'ordine: `revoked` (se `revoked_at` non è nullo); `expired` (se `now()` è fuori da `[created_at, expires_at)`); `locked` con `locked_until` (se `locked_until > now()`); `exhausted` (se `opens_count >= max_opens`); con PIN errato `failed_attempts + 1` e risposta `wrong_pin` con `attempts_left`, ma al **quinto** errore `locked_until = now() + 15 minuti`, `failed_attempts = 0` ed esito `locked`. Con il PIN giusto incrementa `opens_count`, scrive `last_opened_at = now()`, azzera `failed_attempts` e restituisce `{outcome: 'ok', share_link_id, subject_id, scope, expires_at, opens_left, snapshot: {id, generated_at, payload, rule_versions}, questions}`, dove lo `snapshot` è l'ultimo `dossier_snapshots` del link e `questions` è `questions_for_link(id)`. **Le risposte di errore portano solo `outcome` e, quando servono, `attempts_left` o `locked_until`: mai `subject_id`, mai il dossier.** L'audit `share_link.opened` lo scrive il trigger della 0021 sulla riga del registro.
- `share_open_rate_check(p_ip_hash text) → boolean`: `false` quando lo stesso hash di IP ha **più di venti** esiti `wrong_pin` negli ultimi **quindici minuti**, `true` altrimenti; con `p_ip_hash` nullo `true`.

Il test `tests/0024_doctor_v1_links_test.sql` dichiara `plan(37)` e si esegue solo sul progetto dev dal SQL Editor: creazione con codice a sei cifre, hash bcrypt, snapshot collegato e audit; PIN deboli rifiutati; sesto link attivo; Bob sul soggetto di Alice; elenco con `status` e senza `pin_hash`; revoca; e, dal contesto interno, codice inesistente, i cinque tentativi con il blocco, l'apertura riuscita, link esaurito, revocato e scaduto, il freno per IP e il rifiuto ad `authenticated`.

## P08-A3-1 — Edge Function `dossier-open`

`functions/dossier-open/index.ts` è la pagina pubblica del dossier: **unica funzione con `verify_jwt = false`** (`[functions.dossier-open]` in `config.toml`), perché chi apre il link non ha un account e la pagina chiama con la sola apikey anonima. Dentro usa il `service_role` e chiama solo `share_open_rate_check` e `share_link_open` (0024) e `question_answer_via_link` (0023). Nessuna migrazione, nessuna schermata; si pubblica dal modulo Schema Deployment con **«Migration File: No file selected»**.

Segreto obbligatorio: **`DOSSIER_HASH_SECRET`** (se manca, `500 config_missing`).

- `{action: 'open', code, pin}` → codice di sei cifre e PIN di 4–6 cifre, altrimenti `400 invalid_body`; `share_open_rate_check` falso → `429 rate_limited`; esiti di `share_link_open`: `ok` → 200, `wrong_pin`/`locked`/`revoked`/`expired`/`exhausted` → 403 con `{outcome, attempts_left?, locked_until?}`, `not_found` → 404 `{outcome}`. Su `wrong_pin` e `locked` la risposta attende **300 ms fissi**. Su `ok` tornano `share_link_id`, `scope`, `expires_at`, `opens_left`, `snapshot`, `questions` e `session`: **`subject_id` non esce mai**.
- `session` = base64url di `{share_link_id, subject_id, snapshot_id, exp = ora + 30 minuti}` + `'.'` + HMAC-SHA256 firmata con il segreto: `answer` e `pdf` non consumano una seconda apertura. Firma manomessa o sessione scaduta → `401 session_invalid`.
- `{action: 'answer', session, question_id, answer}` → risposta di 1–8000 caratteri, `question_answer_via_link`, `200 {answered: true}`; `P0001` → `409 not_answerable`.
- `{action: 'pdf', session}` → `pdf_path` dello snapshot della sessione; nullo → `404 pdf_missing`, altrimenti URL firmato di 600 s del bucket privato `dossiers` → `200 {url, expires_in: 600}`.
- Hash: `HMAC-SHA256(DOSSIER_HASH_SECRET, AAAA-MM-GG UTC + valore)` in esadecimale, prime **32 cifre**; IP dal primo valore di `x-forwarded-for` o da `cf-connecting-ip`, user agent dall'omonima intestazione; solo Web Crypto.
- **Nei log mai codice, PIN, IP, user agent o dossier**: una riga per chiamata con `action`, esito o codice d'errore e latenza. CORS come `explain`.

Test: `deno test --allow-env lib/supabase/functions/dossier-open/index_test.ts` — senza rete e senza database.

## P08-A3-2 — Edge Function `dossier-pdf`

`functions/dossier-pdf/index.ts` genera il PDF del dossier; il renderer vive in `functions/_shared/dossier_pdf.ts` ed è una funzione pura (nessuna rete, nessun database), così i test lo chiamano direttamente. `[functions.dossier-pdf]` ha **`verify_jwt = true`**: il PDF è del paziente. Nessuna migrazione, nessuna schermata, nessun segreto nuovo; si pubblica dal modulo Schema Deployment con **«Migration File: No file selected»**.

`POST {snapshot_id, lang?: 'it' | 'en'}` con il JWT dell'utente **obbligatorio** (senza `Authorization: Bearer …` → `401 unauthenticated`).

- Lo snapshot si legge con il **client dell'utente** (JWT inoltrato, quindi sotto RLS): riga assente o non sua → `404 snapshot_not_found`; `snapshot_id` non UUID → `400 invalid_input`.
- `pdf_path` già valorizzato → **nessuna rigenerazione**: URL firmato di **600 s** del bucket privato `dossiers` → `200 {pdf_path, url, expires_in: 600}`.
- Altrimenti il PDF nasce dal payload congelato da `dossier_build` (**versione 1**, 0022) con **pdf-lib** (`https://esm.sh/pdf-lib@1.17.1`), font standard **Helvetica**, **A4**, margini **48 pt**, interruzione di pagina automatica, numero di pagina e «Generato da Medical 24 il &lt;data&gt;» a piè di pagina. Sezioni: titolo («Dossier di salute» / «Health dossier»), persona (nome, data di nascita, genere), scope in parole, stato di salute con i conteggi, aree da seguire, rischi (famiglia, livello, punteggio, versione della regola), valori fuori intervallo (nome, valore e unità, intervallo, segnalazione, data, tendenza e valore precedente), esami consigliati, documenti (titolo, categoria, data), versioni delle regole, avvertenze.
- Lingua da `body.lang`, altrimenti `Accept-Language`, altrimenti `it`.
- Caricamento con il `service_role` nel bucket privato `dossiers` (creato se manca, `public = false`) in `subjects/{subject_id}/dossier/{snapshot_id}.pdf`, poi `dossier_snapshot_set_pdf` (0022, riservata al `service_role`), infine l'URL firmato → `200 {pdf_path, url, expires_in: 600}`.
- Errori `500` con codice: **`render_failed`**, **`upload_failed`**.
- **Avvertenze incorporate nel modulo**, in italiano e in inglese: il dossier non è una diagnosi e non sostituisce la visita; i dati provengono dai referti caricati dalla persona e dalle misure che ha registrato; le valutazioni e le decisioni di cura spettano al medico.
- **Nei log solo `snapshot_id`, esito, byte e latenza**: una riga per chiamata. CORS come `explain`.

Test: `deno test --allow-env --allow-net lib/supabase/functions/dossier-pdf/index_test.ts` (la rete serve solo a scaricare `pdf-lib` da esm.sh; database e storage sono finti) — buffer che inizia con `%PDF`, due pagine con cento documenti, PDF di una pagina dal payload vuoto, titolo e piè di pagina in inglese con `lang: 'en'`, e i percorsi dell'handler (401, 404, `pdf_path` già presente, generazione completa, `render_failed`, `upload_failed`).

## Edge Functions

From **Edge Functions**, deploy `document-ingest`, `extract`,
`extract-batch`, `extract-batch-poll`, `explain`, `dossier-open`, `dossier-pdf` and `delete-account` using the
function directories under `lib/supabase/functions/`. Keep JWT verification enabled for
authenticated endpoints. Configure required secrets in **Edge Functions >
Secrets**; never place them in SQL, tests, or the Flutter client.

After deployment, use the panel's **Logs** view to verify an authenticated ingest and account-deletion request. The test fixtures use invalid example identities only and must not be copied into production data.

## Tests

Run each `tests/*.sql` file in the SQL Editor on the development project only.
Each file creates its pgTAP plan, prints the collected TAP rows, and rolls back
its fixtures. Do not run these files against production.

## 0008 — Corpo e organi

La migrazione 0008 crea `organs`, `organ_biomarker_map`, `organ_states` e le viste `organ_overview`, `organ_history`, `organ_comparison` e `organ_episodes`. Espone le funzioni `compute_organ_states(p_subject uuid)`, `organ_overview(p_subject uuid)`, `organ_history(p_subject uuid, p_organ_id text)`, `organ_comparison(p_subject uuid, p_organ_id text)` e `rebuild_organ_biomarker_map()`. Gli stati sono append-only; il calcolo legge i biomarcatori mappati e salva la versione della regola. Le policy usano `can_access_subject(subject_id)` e impediscono letture o scritture tra soggetti. Il trigger di aggiornamento dei timestamp e il cron di calcolo sono dichiarati dalla migrazione; il job gira sul progetto Supabase e non nel client.

## 0009 — Aree per sesso e indice

La migrazione 0009 aggiunge la selezione delle aree in base al sesso del profilo e l'indice `stress_score`. Aggiunge `subject_sex(p_subject uuid)` e `organ_ids_for_catalog_key(p_catalog_key text)`, estende `organ_overview(p_subject uuid)`, `organ_history(p_subject uuid, p_organ_id text)` e `organ_comparison(p_subject uuid, p_organ_id text)` con sesso e indice, e mantiene `organ_states` append-only. Le policy restano basate su `can_access_subject`; i trigger di integrità e il cron esistente non cambiano. Le aree senza sesso compatibile non vengono restituite.

## 0010 — Regola 0.3

La migrazione 0010 pubblica la versione `organ_state 0.3`, ritira la 0.2 e aggiorna `compute_organ_states(p_subject uuid)` per derivare lo stato dall'indice: norma sotto 0,05, monitoraggio da 0,05 a 0,60, attenzione da 0,60 a 0,80 e criticità da 0,80. La funzione conserva la provenienza in `organ_states` e rispetta RLS e `can_access_subject`. Non introduce nuove policy, trigger o cron: usa quelli del modulo Corpo. La regola vive in `rule_versions`: per cambiarla si inserisce una nuova riga versionata e non si modifica la regola esistente né si usa una nuova migrazione.