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

## Edge Functions

From **Edge Functions**, deploy `document-ingest`, `extract`,
`extract-batch`, `extract-batch-poll`, `explain` and `delete-account` using the
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