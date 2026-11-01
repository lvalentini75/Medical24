# Medical 24 — Piano di controllo dell'IA (GOVERNO_IA v1.0, 30 ottobre 2026)

Progettazione e realizzazione: Tattica Web — progettista Luca Valentini. Documento vivo: descrive il piano di controllo dell'IA costruito con le migrazioni 0014, 0015 e 0016 (prompt P09-GOV-A, GOV-A2, revisioni di Tattica Web) e il pannello di governo (P09-GOV-B). Integra il MASTER v1.1 (sezioni 7 "Costi IA", 16 "Ottimizzazione", 21 "Governance"); dove differisce, vale questo documento fino alla v1.2 del MASTER.

## 1. Perché

Il MASTER chiede costi IA sotto controllo, regole del board versionate e nessun dato clinico nei log. Fino al P06 modelli, prezzi e prompt vivevano nel codice delle Edge Functions e nei secret: cambiare modello voleva dire un deploy, controllare i costi voleva dire leggere i log. Il piano di controllo sposta tutto nel database, governato dal pannello admin con audit: il codice legge la configurazione, non la contiene.

Decisioni prese il 30 ottobre 2026:

1. Modello, prompt, prezzi, `max_output_tokens`, opzioni di richiesta, budget e limiti stanno in tabelle di controllo; le funzioni li leggono a ogni richiesta e falliscono con `config_missing` se mancano. Nessuna costante residua nel codice.
2. Budget giornaliero per compito: `explain` (e in futuro i pasti) si mette in **pausa** fino al giorno dopo quando sfora; `extract` emette solo un **avviso**, perché un referto non letto è un danno maggiore del costo.
3. I prompt di `explain` cambiano solo con l'approvazione di un **secondo admin** e un **test superato** (dry-run sui tre casi sintetici con filtro anti-diagnosi e chiusura obbligatoria); i prompt di estrazione li attiva un solo admin. Il **rollback** a una versione già attiva in passato non richiede nuova approvazione.
4. Il pannello di governo è **solo desktop**.
5. Gli admin scrivono solo tramite funzioni (`ai_task_set`, `ai_model_set`, `platform_setting_set`, `ai_prompt_*`, `rule_version_set_status`): nessuna scrittura diretta, nemmeno per loro; ogni azione lascia una riga in `audit_log` e un evento `admin_action`.
6. Il ledger non contiene testo clinico: solo compito, modello, versione del prompt, soggetto, esito, codice di errore, token e costo.
7. **Conferma automatica**: un valore estratto con confidenza ≥ 0.85 (`platform_settings 'extraction.auto_confirm_confidence'`) nasce confermato dal motore (`confirmed_by` nullo); sotto resta da verificare. L'utente può sempre scartare. Questa regola chiude il difetto del P02 (valori ad alta confidenza che restavano "in attesa" senza pulsanti e senza alimentare organi, rischi e spiegazioni).

## 2. Schema (migrazioni 0014–0016)

| Tabella | Contenuto | Accesso |
| --- | --- | --- |
| `ai_models` | id (stringa API, es. `claude-sonnet-5-5`), provider, nome, prezzi in **micro-USD per milione di token** (input, output, cache letta), finestra, stato `active`/`deprecated`, note | Lettura admin; scrittura solo `ai_model_set` |
| `ai_tasks` | `extract_classify`, `extract_values`, `explain`: modello, fallback (usato solo su 404 e 529, se abilitato), `max_output_tokens`, abilitato, budget giornaliero e azione (`alert`/`pause`), `paused_until`, limite giornaliero per utente, seconda approvazione, `request_options` (JSON fuso nel corpo della richiesta), prompt attivo | Lettura admin; scrittura solo `ai_task_set` |
| `ai_prompts` | Versioni dei prompt: system prompt, tool schema, template utente, stato `draft`/`active`/`retired`, creato/approvato/attivato/ritirato da e quando, `last_test` | Lettura admin; `ai_prompt_create/approve/record_test/activate/rollback` |
| `ai_usage_ledger` | Una riga per chiamata: compito, modello, versione prompt, soggetto, funzione, esito (`ok`/`error`/`refused`/`cached`), codice errore, token in (totale), token cache letti, token out, costo, latenza, request id; vista `ai_usage_daily` | Lettura admin; scrittura solo `ai_log_call` (service_role) |
| `platform_settings` + `_history` | Chiave, valore JSON, `is_public`, descrizione, versione, chi e quando; ogni cambio conserva la versione precedente | Pubbliche leggibili da tutti (anche anon, per la manutenzione prima del login); le altre da admin, service_role e contesti interni; scrittura `platform_setting_set` |
| `platform_events` | `cron_run`, `cron_error`, `ai_budget_alert`, `ai_task_paused`, `deploy`, `health`, `admin_action` con dettagli JSON | Lettura admin; scrittura `platform_event` (service_role) e funzioni admin |

Impostazioni seed: `limits.free_analyses_per_month` (30 in dev, 10 al lancio), `limits.explanations_per_day` (30), `limits.free_documents` (30), `features.explain_enabled`, `features.body_enabled`, `platform.maintenance_mode`, `platform.maintenance_message_key`, `extraction.auto_confirm_confidence` (0.85, non pubblica).

Modelli seed (listino Anthropic al 30 ottobre 2026, da aggiornare dal pannello): Haiku 5.5 0,10 / 0,50 $ per MTok, cache letta 0,01 (fascia ≤ 100K token di input); Sonnet 5.5 2 / 10 $ per MTok, cache letta 0,20.

Opzioni di richiesta seed: `explain` → `{"thinking":{"type":"between_tools"},"output_config":{"effort":"medium"}}`; `extract_values` → stesso con `effort: high`; `extract_classify` (Haiku 5.5) nessuna opzione finché il supporto non è verificato.

## 3. Funzioni

- Lettura dalle Edge Functions (service_role): `ai_task_config(task)` → JSON con modello, fallback, `max_output_tokens`, `paused`, `maintenance`, limite per utente, `request_options`, prompt attivo (versione, system, tool schema, template), prezzi. `platform_setting(key)`.
- Scrittura dalle Edge Functions: `ai_log_call(...)` → id e costo; applica il budget (alert o pausa fino a domani, un evento al giorno). `platform_event(...)`. `ai_prompt_record_test(id, risultato)`. `auto_confirm_extraction(extraction_id)` → numero di valori confermati dal motore.
- Scrittura admin: `platform_setting_set(key, value, descrizione)`, `ai_task_set(task, patch)` (chiavi ammesse e validate, modello attivo obbligatorio, `paused_until` nullo per riprendere), `ai_model_set(id, patch)` (crea se manca; un modello in uso non si ritira), `ai_prompt_create/approve/activate/rollback`, `rule_version_set_status` (admin o board).
- Lettura admin (ogni lettura scrive `admin.read` in audit): `admin_overview`, `admin_ai_tasks`, `admin_prompts(task)`, `admin_usage(da, a, task)`, `admin_ai_calls(da, a, task, stato, limit, offset)`, `admin_events(...)`, `admin_audit(...)`, `admin_rules`.
- Cron registrati con pg_cron, tutti passando dai wrapper che scrivono `cron_run`/`cron_error`: `enqueue-pending-extractions` (03:45), `compute-organ-states` (04:15), `medical24-risk-scores-nightly` (04:35), `platform-health` (05:00, fotografia giornaliera: documenti, estrazioni ok/fallite, costo per compito, utenti attivi).
- Conferma dei valori: `confirm_observation_internal(observation_id, actor, …)` è l'unico corpo; `confirm_observation` (utente) e `auto_confirm_extraction` (motore) lo chiamano; la conferma è una riga nuova che supera la precedente e fa scattare i trigger di organi e rischi.

## 4. Come si comportano le funzioni

**extract** (classificazione con il modello piccolo, trascrizione con il medio): legge le due configurazioni, rifiuta con `paused` (`aiTaskPaused` o `maintenanceMessage`) se un compito è fermo; fallback sul modello di riserva solo su 404 e 529, registrato come chiamata a sé; limite giornaliero per soggetto su `extract_values` (fallimento `daily_limit`, 429); soglia di revisione = soglia di conferma automatica; alla chiusura chiama `auto_confirm_extraction` e riporta `values_confirmed`; ogni chiamata nel ledger con token totali e quota cache; il prompt di `extract_values` contiene la regola sulle percentuali della formula leucocitaria (codici `%` distinti dai conteggi).

**explain**: configurazione da `ai_task_config('explain')`; contesto, cache, limite giornaliero e filtro anti-diagnosi come nel P06; `tool_choice` `auto` con lettura dal tool `explanation` o dai blocchi di testo; chiusura obbligatoria garantita dal codice (appesa se manca, segnalata nel log); dry-run degli admin (verifica con `user_roles`, non con il JWT) sui tre casi sintetici, che registra il test sul prompt; template utente dal database.

**Fatti dell'API Anthropic che hanno guidato le scelte** (verificati il 30 ottobre 2026 sulla documentazione di Sonnet 5.5): il tool forzato restituisce `400 tool_choice: type "tool" and "any" are not supported for this model`; il ragionamento adattivo è attivo per impostazione predefinita con sforzo `high` e i suoi token contano nel `max_tokens` (una spiegazione con `max_tokens` 1000 tornava vuota: tutto ragionamento, zero testo); si spegne con `thinking: {"type":"between_tools"}` e si modula con `output_config.effort`; `thinking: disabled` è rifiutato. Fonti: [What's new in Claude Sonnet 5.5](https://platform.claude.com/docs/en/models/sonnet-5-5/whats-new-sonnet-5-5), [Guida alla migrazione](https://platform.claude.com/docs/it/models/sonnet-5-5/migration-guide).

## 5. Pannello di governo (P09-GOV-B)

Solo desktop, voce "Governo" visibile agli admin (`has_role('admin')`). Parte 1: panoramica (`admin_overview`, aggiornamento ogni 60 s), compiti AI e modelli (tabella, pannello di modifica con preimpostazioni delle opzioni di richiesta, pausa e ripresa, listino), impostazioni con storico e interruttore di manutenzione. Parte 2: prompt (nuova versione, approvazione, test dal pannello via dry-run, attivazione, rollback, confronto), consumi (costo giornaliero per compito, chiamate ok/errori/cache, chiamate recenti), eventi e salute, audit, regole del board. Costi mostrati in dollari con quattro decimali (micro-USD / 1.000.000).

## 6. Test e revisione

Ogni migrazione del piano di controllo è stata rivista da Tattica Web su PostgreSQL 16 locale prima dell'applicazione (parser, esecuzione in unica transazione come il SQL Editor, test pgTAP, idempotenza alla seconda esecuzione) e poi applicata dal SQL Editor del progetto dev. Esiti: 0014 test 59/59, 0015 test 19/19, 0016 test 25/25; regressioni 0014 e 0015 verdi dopo la 0016. Correzioni fatte in revisione sull'output dell'agente: alias `day`, modelli e prezzi seed, lettura delle impostazioni pubbliche prima del login, rollback dei prompt, `set constraints all immediate` dopo il collegamento task→prompt, colonne dei prezzi e costo atteso nel test (fattore un milione), riferimenti rotti e conteggio token nelle funzioni, controllo admin dal JWT invece che da `user_roles`, chiusura obbligatoria non verificata.

## 7. Aperto

- GOV-B parte 2 e tag GitHub `v0.6-governo`.
- Ottimizzazione: la conferma del motore fa scattare organi e rischi una volta per valore; prima del lancio un interruttore di sessione rinvia il ricalcolo alla fine dell'estrazione.
- Verificare se Haiku 5.5 accetta `thinking: between_tools` e, in caso, impostare `request_options` anche su `extract_classify` dal pannello.
- I test Deno delle funzioni non girano nell'ambiente Dreamflow: si eseguono in locale o in CI dopo l'export.
- `platform_event` rifiuta gli utenti autenticati: le funzioni admin scrivono gli eventi direttamente; valutare un `platform_event_admin` se servirà dall'app.
- MASTER v1.2: consolidare questo documento nelle sezioni 7, 16 e 21 e aggiornare le regole sui modelli (sezione 18) con i fatti dell'API.
