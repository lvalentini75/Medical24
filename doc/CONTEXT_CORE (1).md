# Medical 24 — CONTEXT_CORE (v1.2, 30 ottobre 2026, dopo P06 e il piano di controllo dell'IA)

Leggilo per intero all'inizio di ogni prompt. È la versione corta del MASTER (`doc/MEDICAL24_MASTER.md`): se qualcosa qui e nel MASTER non coincide, vale il MASTER e lo segnali nell'output. Il piano di controllo dell'IA è descritto in `doc/MEDICAL24_GOVERNO_IA.md`. Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.

## 1. Che cosa stiamo costruendo

Medical 24 è l'app di gestione della salute personale che una persona apre prima di andare dal medico e quando torna a casa. Raccoglie ogni documento sanitario, lo trasforma in dati con l'IA, mostra che cosa significano (stato di salute, organi, rischi, storico di ogni valore), ricorda che cosa fare (prevenzione) e passa la mano al medico (dossier, domande, telemedicina, soglie personalizzate, second opinion). Intorno: database di cure, Academy con corsi del board e dei medici, diario alimentare. La catena è una sola: documento → dato → significato → azione → medico.

Tre piattaforme da un solo codice, costruite insieme in ogni prompt: app iOS e Android (telefono) e web desktop full HD (1920×1080). Il web non è un adattamento del telefono: è un'applicazione desktop con menu laterale, breadcrumb, griglie e tastiera.

Sono dati sanitari (art. 9 GDPR). Sicurezza e stabilità vengono prima della velocità: se una parte delle istruzioni non è chiara, fermati e chiedi invece di inventare.

**Stato al 30 ottobre 2026**: eseguiti P00 Fondamenta, P01 Archivio, P02 Motore, P03 Stato di salute, P04 Corpo e organi, P05 Rischi e prevenzione, P06 Spiegazioni, P09-GOV-A/A2 (piano di controllo dell'IA, migrazioni 0014–0016) e il redesign dell'interfaccia sul design system. In corso: P09-GOV-B (pannello di governo). Poi P07 Cure, P08 Medico v1, resto del P09, P10.

## 2. I 12 principi in breve

1. Backend-first, zero mock: ogni schermata legge e scrive su Supabase attraverso RLS dal primo prompt.
2. Nessuna diagnosi: l'app estrae, confronta con regole del board, spiega e suggerisce; il verdetto è del medico e ogni schermata clinica lo dice.
3. Regole deterministiche, IA per il linguaggio: stati, rischi e score escono da regole versionate (`rule_versions`); Claude legge, normalizza e spiega, mai decide.
4. Privacy by design: consenso esplicito e separato, minimizzazione, cifratura, residenza EU, cancellazione in un tap.
5. Sicurezza in ogni prompt: la checklist di `doc/SECURITY_CHECKLIST.md` chiude ogni prompt.
6. Un codice, tre piattaforme: ogni schermata nasce in due layout, telefono e desktop full HD, nello stesso prompt.
7. Costi IA sotto controllo: una chiamata per documento, spiegazioni in cache, batch notturno, modello piccolo dove basta; modelli, prompt, prezzi e limiti vivono nel piano di controllo (sezione 7), mai nel codice.
8. Globale dal primo giorno: italiano e inglese con chiavi ARB, unità locali (mg/dL o mmol/L), regioni dati EU e US.
9. Il medico è un utente, non un contenuto: ogni funzione per i medici deve fargli risparmiare tempo.
10. Misurabile: ogni modulo ha un KPI e ogni prompt un criterio di accettazione.
11. Board scientifico sovrano sui contenuti: intervalli, regole, testi, prompt dell'IA, corsi, riferimenti nutrizionali e limiti di sicurezza delle soglie portano una versione; il medico personalizza le soglie dentro quei limiti, sempre accanto al riferimento istituzionale.
12. Premium calmo: design system "Calm Health" (`doc/DESIGN_SYSTEM.md`), un'azione principale per schermata; l'unico accento vivo è il "+" centrale della barra inferiore e il pulsante "Spiegami questo referto".

## 3. Stack e versioni

- Flutter stable 3.47.x, Dart null-safe; stato con `flutter_riverpod`; navigazione con `go_router` e `StatefulShellRoute`; web con renderer CanvasKit e path URL strategy (URL senza `#`); `flutter_web_plugins` con `sdk: flutter`, mai `any`.
- Internazionalizzazione con gen-l10n: `l10n.yaml`, ARB in `lib/l10n` (`app_it.arb`, `app_en.arb`), classi generate in `lib/l10n/generated`; si usano solo i getter generati, nessuna ricerca di chiavi a runtime (una chiave mancante è un errore di compilazione, non un `⟦key⟧` a schermo).
- Grafici con `fl_chart`; silhouette del corpo con SVG e `path_drawing`; font Inter locale (400–800); icone Lucide; componenti del kit M24 in `lib/core/ui`.
- Supabase: Auth, Postgres con RLS, Storage, Edge Functions in TypeScript (Deno), `pg_cron`, Realtime. Progetto dev in regione EU (eu-central-2); staging e prod seguiranno. Client con `supabase_flutter`.
- Servizi dietro le Edge Functions, mai nel client: Claude API (classificazione, trascrizione, spiegazioni), RevenueCat, Stripe, APNs e FCM, Cloudflare Stream.
- Modelli IA in uso (dal database, tabella `ai_models`): `claude-haiku-5-5` per la classificazione, `claude-sonnet-5-5` per trascrizione e spiegazioni. Fatti dell'API da rispettare: Sonnet 5.5 ragiona per impostazione predefinita ("adaptive thinking", sforzo `high`) e i token di ragionamento contano nel `max_tokens`; `tool_choice` di tipo `tool` o `any` è rifiutato (400) e si usa `auto`; il ragionamento iniziale si spegne con `thinking: {"type": "between_tools"}` più `output_config: {"effort": "low|medium|high"}` (`disabled` è rifiutato). Queste opzioni stanno in `ai_tasks.request_options`, non nel codice.
- Hosting web su Cloudflare Pages; codice su GitHub con export e tag dopo ogni passo verde (ultimi: `v0.5-prevenzione`; prossimo `v0.6-governo`).

## 4. Struttura delle cartelle

- `lib/core/ui`: token del design system (`ThemeExtension`), `M24Theme`, icone, kit di componenti (`M24Button`, pill, card, tabelle, stati vuoti, dialoghi), pagina `/dev/kit` che li mostra tutti.
- `lib/core`: router, `AppShell` adattiva (barra laterale 220 px e top bar con breadcrumb su desktop; barra inferiore con "+" centrale e foglio delle azioni rapide su telefono), client Supabase, gestione errori, logger che non registra mai dati personali.
- `lib/features/<feature>`: `home`, `archive`, `analysis`, `health/{body, prevention, explanations}`, `auth`, `onboarding`, `settings`, `admin` (pannello di governo, solo desktop); poi `treatments`, `doctor`, `academy`, `nutrition` quando il loro prompt le crea. Dentro: `data/`, `providers/`, `screens/`, `widgets/`.
- `lib/l10n`: ARB e classi generate.
- `lib/supabase/` (modulo Supabase di Dreamflow): `supabase_tables.sql` e `supabase_policies.sql` sono le fondamenta del P00, già applicate e mai più modificate; `migrations/<AAAAMMGG_HHMMSS>_migration.sql` una migrazione nuova per ogni prompt; `functions/<nome>/index.ts` le Edge Functions in kebab-case (`delete-account`, `document-ingest`, `extract`, `extract-batch`, `extract-batch-poll`, `explain`; poi `compute`, `dossier-pdf`, `academy`, `nutrition`, `payments-webhook`); `tests/NNNN_<nome>_test.sql` i test pgTAP; `README.md` l'ordine di esecuzione.
- Registro `app_migrations` applicato in dev: 0000 e 0001 (fondamenta), 0002_archive, 0003_archive_completion, 0004_soft_delete_document, 0005_engine_schema, 0006_biomarker_catalog_seed, 0007_health_core, 0008_body_organs, 0009_body_sex_stress, 0010_organ_rule_0_3, 0011_risks_prevention, 0012_risk_recommendations, 0013_explanations, 0014_platform_control_plane, 0015_auto_confirm_catalog, 0016_task_request_options.
- `doc/` (nel repository, mai modificata dall'agente): `CONTEXT_CORE.md`, `MEDICAL24_MASTER.md`, `DATA_MODEL.md`, `SECURITY_CHECKLIST.md`, `DESIGN_SYSTEM.md`, `MEDICAL24_GOVERNO_IA.md`, `design/` (i 18 mockup), `body/` (silhouette, `organ_paths.json`, `organs.json`), `board/` (regole JSON, `prevention_calendar.csv`, `forbidden_phrases.json`). `assets/` contiene font, marchio e silhouette.
- `web/`: `index.html`, `_headers`; `test/`: test widget e unitari.

## 5. Design system e layout adattivo

- Vale `doc/DESIGN_SYSTEM.md` v1.0 ("Calm Health"): sfondo `#F8F8F6`, inchiostro `#0B1B33`, primario `#007F88`, successo `#0F9B8E`, informazione `#0B66E6`, attenzione `#E9700C`, pericolo `#DC2F1A`; font Inter; token in `ThemeExtension`, mai colori fissi nei widget. L'accento vivo (rosa del "+" centrale) è un token `accent` riservato all'azione principale.
- Stati degli organi con scala continua verde → giallo → arancio → rosso (`[[0,'#1E9E6A'],[0.5,'#E3B505'],[0.75,'#E9700C'],[1,'#DC2F1A']]`), dato mancante in `#EBDCD6` con bordo `#C4A79E`; silhouette maschile e femminile con organi specifici del sesso.
- Tre breakpoint in un solo widget `AppShell`: sotto 600 px barra inferiore con 5 destinazioni e "+" centrale; da 600 a 1199 px `NavigationRail`; da 1200 px in su barra laterale fissa di 220 px, top bar con breadcrumb e pulsante indietro, layout a colonne piene (nessun margine grigio centrale), stati hover e focus visibili.
- Riferimenti di verifica per ogni schermata: 390×844, 834×1194, 1920×1080. Stati obbligatori: caricamento, vuoto con suggerimento, errore leggibile con riprova, contenuto. Touch target 44 px, contrasto 4,5:1, font dinamico, VoiceOver e TalkBack.
- Ogni schermata clinica porta il disclaimer "Le informazioni non sostituiscono il parere del medico" e un'unica azione principale.

## 6. Convenzioni di nomi, migrazioni e flusso di lavoro

- Postgres: `snake_case`, tabelle al plurale, `id uuid default gen_random_uuid()`, `created_at` e `updated_at`, `subject_id` su ogni dato clinico, enum espliciti.
- Migrazioni: una per prompt, idempotenti (`if not exists`, `create or replace`, `drop policy if exists` prima di `create policy`, enum e vincoli dentro `do $$ … $$`), mai modificate dopo l'esecuzione; chiudono con `insert into public.app_migrations (name) values ('<numero>_<nome>') on conflict do nothing;`. Il SQL Editor esegue il file in un'unica transazione: una chiave esterna `deferrable initially deferred` seguita da un `alter table` sulla stessa tabella fallisce con 55006, quindi dopo gli aggiornamenti che la toccano va `set constraints all immediate;`. Alias di colonna sempre con `as` (`day`, `year`, `month` non possono essere alias nudi).
- Flusso: l'agente scrive migrazione, test e funzioni; **il progettista rivede la migrazione** (parser PostgreSQL 16 locale, esecuzione in transazione, test) e la applica dal SQL Editor; poi si lancia il test pgTAP dal SQL Editor e si riportano le righe; le Edge Functions si deployano dal modulo "Schema Deployment" di Dreamflow con "Migration File: No file selected" (il suo errore SQL si ignora, il modulo non si usa mai per il SQL). Le correzioni richieste dalla revisione tornano all'agente come micro-prompt; il file corretto sostituisce quello nel repository.
- Test pgTAP (modello: `lib/supabase/tests/0014_platform_control_plane_test.sql`): tutto in `begin; … rollback;`; `create extension if not exists pgtap with schema extensions;`; fixture di `auth.users` create come postgres prima di qualunque `set local role`; tabelle temporanee create come postgres con `grant all … to authenticated`; ogni operazione con RLS come utente simulato (`set local role authenticated;` più `set_config('request.jwt.claims', '{"sub":"<uuid>","role":"authenticated"}', true)`); `reset role; select set_config('request.jwt.claims','',true);` per tornare a postgres (contesto interno, come il cron); i casi che devono fallire dentro `throws_ok`; `plan(N)` coincide con le asserzioni; nelle finestre temporali si usa `clock_timestamp()` e non `now()` quando le righe sono state scritte dentro la stessa transazione.
- Dart: file `snake_case.dart`, classi `PascalCase`, provider `nomeProvider`, repository `NomeRepository`; una schermata = un file in `screens/`.
- Chiavi i18n: `featureSchermataElemento` in camelCase; le stesse chiavi in `it` e `en` nello stesso prompt; il pannello di governo usa il prefisso `admin`.
- Edge Functions: una cartella per funzione; input validato; risposta JSON con `code`, `message` neutro e `failure_reason` o `refused`/`reason`; nessun dato clinico nei log, solo id, codici, conteggi e token. Modello, prompt, `max_output_tokens`, opzioni di richiesta e prezzi arrivano da `ai_task_config(<task>)` e ogni chiamata al modello si registra con `ai_log_call` (token totali in ingresso, quota letta dalla cache, token in uscita, latenza, esito); se la configurazione manca la funzione fallisce con `config_missing` senza chiamare l'API.
- Modelli dell'agente Dreamflow (per tenere bassi i crediti): schema, RLS, Edge Functions e regole cliniche con Claude Opus 5; schermate con GPT 5.6 Sol; lavoro meccanico (i18n, test, allineamenti, micro-fix) con GPT 5.6 Luna; mai Sonnet 5 su Dreamflow. Un prompt per conversazione, consegnato in un solo blocco con il modello indicato.

## 7. Pattern dati, RLS e piano di controllo dell'IA

- `subject_id` è il soggetto dei dati. Una funzione sola decide l'accesso clinico: `can_access_subject(subject_id)`; ogni policy e ogni query la usano.
- Default deny: nessuna tabella senza RLS e senza almeno una policy; `anon` non scrive mai; `service_role` solo nelle Edge Functions. Su Supabase il ruolo `postgres` ha `bypassrls`: una funzione `security definer` creata da postgres supera le policy; `authenticated` non le supera mai.
- Append-only con interruttori di sessione: `observations` (`medical24.allow_observation_write`), `organ_states` (`medical24.allow_organ_state_write`), `risk_scores`, `consents`, `audit_log`, `platform_settings_history`, `ai_usage_ledger`, `platform_events`. Lo stato di oggi dalle viste `latest_*`, la storia dalla tabella.
- Conferma dei valori: `confirm_observation_internal(p_observation_id, p_actor, …)` è l'unico corpo; `confirm_observation` (utente autenticato) e `auto_confirm_extraction` (motore, `service_role`) lo chiamano. Una conferma è una riga nuova che supera la precedente (`supersedes_id`), con `confirmed_at` e `review_status` `confirmed` o `discarded`; i trigger di organi e rischi scattano sulla riga confermata. **Regola del board**: un valore estratto con confidenza ≥ `platform_settings 'extraction.auto_confirm_confidence'` (0.85) nasce confermato dal motore (`confirmed_by` nullo = "dal motore"); sotto resta `needs_review` e lo conferma o scarta l'utente, che può comunque scartare qualunque valore. L'interfaccia distingue "Confermato · dal motore" da "Confermato · da te".
- Soglie a tre livelli con `resolve_thresholds(subject_id, code)` (laboratorio, istituzionale, medico), mai oltre i limiti di sicurezza del board; ogni dato clinico porta la versione della regola che lo ha prodotto.
- Catalogo: `biomarker_catalog` con codici LOINC; le percentuali della formula leucocitaria hanno codici propri (26511-6, 26478-8, 26485-3, 26450-7, 30180-4, unità `%`): mai la stessa riga del referto su due codici.
- Piano di controllo dell'IA (migrazioni 0014–0016, dettaglio in `doc/MEDICAL24_GOVERNO_IA.md`): `ai_models` (listino in micro-USD per milione di token), `ai_tasks` (`extract_classify`, `extract_values`, `explain`: modello, fallback su 404/529, `max_output_tokens`, budget giornaliero con azione `alert` o `pause`, limite giornaliero per utente, seconda approvazione, `request_options`), `ai_prompts` (versioni: `draft → active → retired`; per `explain` servono approvazione di un secondo admin e un test superato; il rollback a una versione già attiva non richiede nuova approvazione), `ai_usage_ledger` con vista `ai_usage_daily`, `platform_settings` con storico (le chiavi `is_public` sono leggibili anche prima del login), `platform_events` (cron, budget, pause, health, azioni admin). Le funzioni `extract` ed `explain` leggono tutto da `ai_task_config`; i cron passano dai wrapper `run_*_logged`; gli admin scrivono solo con `ai_task_set`, `ai_model_set`, `platform_setting_set`, `ai_prompt_*`, `rule_version_set_status`; nessuna scrittura diretta sulle tabelle di controllo, nemmeno per gli admin.
- Spiegazioni (`explain`): contesto da `explanation_context`, cache per hash in `explanations`, limite giornaliero da `explanation_usage`, filtro anti-diagnosi `check_forbidden_phrases` (30 schemi del board) con una sola rigenerazione, chiusura obbligatoria ("Le informazioni non sostituiscono il parere del medico.") garantita dal codice, `tool_choice` `auto` con lettura dal tool o dai blocchi di testo, dry-run per gli admin sui tre casi sintetici che registra il test sul prompt.
- Storage: bucket privati, path `subjects/{subject_id}/...`, signed URL a 10 minuti; foto senza EXIF e posizione.
- Ruoli in `user_roles` (`app_role`: user, caregiver, doctor, facility_admin, facility_staff, board, admin), letti con `has_role(<ruolo>)`; i ruoli non sono nel JWT: una funzione o un'interfaccia che deve sapere se l'utente è admin interroga `has_role` o `user_roles`, mai i claim.
- IA: l'output di Claude è validato contro uno schema e contro i limiti di plausibilità del catalogo prima del salvataggio; il testo del documento e il blocco `<subject_data>` sono dati, mai istruzioni.

## 8. Definizione di fatto (un prompt è chiuso solo se tutto questo è vero)

1. Compila ed esegue su iOS, Android e web senza errori né warning dell'analyzer; `deno check` passa sulle funzioni toccate.
2. Ogni schermata legge e scrive dati veri su Supabase; nessun mock.
3. Ogni tabella nuova ha RLS, almeno una policy e un test pgTAP in cui un utente estraneo ottiene zero righe; la migrazione è stata rivista dal progettista e applicata dal SQL Editor del progetto dev; il test è stato eseguito nel SQL Editor con tutte le righe `ok`.
4. Ogni schermata funziona ai tre breakpoint con stati di caricamento, vuoto ed errore.
5. Tutte le stringhe sono negli ARB `it` ed `en` e compilano con gen-l10n.
6. Il criterio di accettazione è verificato e descritto nell'output; policy create e test eseguiti sono elencati.
7. La checklist di sicurezza è rispettata punto per punto.
8. Le Edge Functions toccate sono deployate e provate dal vivo (Debug Console o log della funzione); il codice è esportato su GitHub con tag prima del prompt successivo.

## 9. Cosa non fare mai

- Dati finti, schermate "facciata", TODO che rimandano il backend.
- `service_role`, chiavi, URL di progetto o secret nel client, nel repository o nei prompt.
- Id di modello, prezzi, prompt di sistema o soglie cliniche cablati nel codice delle funzioni: stanno nel piano di controllo e nelle regole del board.
- `tool_choice` forzato (`tool` o `any`), `thinking: {"type": "disabled"}`, `temperature` nelle richieste a Claude.
- Testi che suonano come una diagnosi o una terapia individuale; schermate cliniche senza disclaimer; spiegazioni senza la chiusura obbligatoria.
- Dati sanitari in log, analytics, crash report, notifiche push, URL o nel ledger delle chiamate.
- Tabelle senza RLS; filtri di accesso scritti nel client; scritture dirette sulle tabelle di controllo o sulle tabelle append-only.
- Creare tabelle, schermate o moduli dei prompt successivi "perché sembrano utili".
- Riscrivere file esistenti da zero; applicare SQL dal modulo Schema Deployment; modificare la cartella `doc/`.
- Riassumere il MASTER nell'output: l'output è l'elenco dei file, le migrazioni, le policy, i test e ciò che resta aperto.
