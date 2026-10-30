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

## Edge Functions

From **Edge Functions**, deploy `document-ingest`, `extract`,
`extract-batch`, `extract-batch-poll` and `delete-account` using the function
directories under `lib/supabase/functions/`. Keep JWT verification enabled for
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