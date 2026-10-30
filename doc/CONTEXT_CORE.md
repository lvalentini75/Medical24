# Medical 24 — CONTEXT_CORE (v1.1, 24 ottobre 2026)

Leggilo per intero all'inizio di ogni prompt. È la versione corta del MASTER (`/docs/MEDICAL24_MASTER.md`): se qualcosa qui e nel MASTER non coincide, vale il MASTER e lo segnali nell'output. Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.

## 1. Che cosa stiamo costruendo

Medical 24 è l'app di gestione della salute personale che una persona apre prima di andare dal medico e quando torna a casa. Raccoglie ogni documento sanitario, lo trasforma in dati con l'IA, mostra che cosa significano (stato di salute, organi, rischi, storico di ogni valore), ricorda che cosa fare (prevenzione) e passa la mano al medico (dossier, domande, telemedicina, soglie personalizzate, second opinion). Intorno: database di cure, Academy con corsi del board e dei medici, diario alimentare. La catena è una sola: documento → dato → significato → azione → medico.

Tre piattaforme da un solo codice, costruite insieme in ogni prompt: app iOS e Android (telefono) e web desktop full HD (1920×1080). Il web non è un adattamento del telefono: è un'applicazione desktop con menu laterale, griglie e tastiera.

Sono dati sanitari (art. 9 GDPR). Sicurezza e stabilità vengono prima della velocità: se una parte delle istruzioni non è chiara, fermati e chiedi invece di inventare.

## 2. I 12 principi in breve

1. Backend-first, zero mock: ogni schermata legge e scrive su Supabase attraverso RLS dal primo prompt.
2. Nessuna diagnosi: l'app estrae, confronta con regole del board, spiega e suggerisce; il verdetto è del medico e ogni schermata clinica lo dice.
3. Regole deterministiche, IA per il linguaggio: stati, rischi e score escono da regole versionate (`rule_versions`); Claude legge, normalizza e spiega, mai decide.
4. Privacy by design: consenso esplicito e separato, minimizzazione, cifratura, residenza EU, cancellazione in un tap.
5. Sicurezza in ogni prompt: la checklist di `/docs/SECURITY_CHECKLIST.md` chiude ogni prompt.
6. Un codice, tre piattaforme: ogni schermata nasce in due layout, telefono e desktop full HD, nello stesso prompt.
7. Costi IA sotto controllo: una chiamata per documento, spiegazioni in cache, batch notturno, modello piccolo dove basta.
8. Globale dal primo giorno: italiano e inglese con chiavi ARB, unità locali (mg/dL o mmol/L), regioni dati EU e US.
9. Il medico è un utente, non un contenuto: ogni funzione per i medici deve fargli risparmiare tempo.
10. Misurabile: ogni modulo ha un KPI e ogni prompt un criterio di accettazione.
11. Board scientifico sovrano sui contenuti: intervalli, regole, testi, corsi, riferimenti nutrizionali e limiti di sicurezza delle soglie portano una versione; il medico personalizza le soglie dentro quei limiti, sempre accanto al riferimento istituzionale.
12. Premium calmo: interfaccia "Calm Health", un'azione contestuale per schermata, niente FAB centrale.

## 3. Stack e versioni

- Flutter stable (canale stable corrente), Dart null-safe; stato con `flutter_riverpod`; navigazione con `go_router` e `StatefulShellRoute`; web con renderer CanvasKit e path URL strategy (URL senza `#`).
- Supabase: Auth, Postgres con RLS, Storage, Edge Functions in TypeScript (Deno), `pg_cron`, Realtime, Vault, `pgsodium`. Tre progetti: dev, staging, prod, in regione EU. Client con `supabase_flutter`.
- Servizi dietro le Edge Functions, mai nel client: Claude API (estrazione e spiegazioni), RevenueCat (`purchases_flutter`, abbonamenti e corsi), Stripe (servizi uno a uno, Connect per i payout), APNs e FCM, Cloudflare Stream (video dei corsi).
- Pacchetti di base: `supabase_flutter`, `flutter_riverpod`, `go_router`, `flutter_localizations` e `intl`, `local_auth`, `flutter_secure_storage`. Ogni altro pacchetto va motivato in una riga nell'output del prompt.
- Hosting web su Cloudflare Pages; codice su GitHub con export dopo ogni prompt; build degli store con Codemagic.

## 4. Struttura delle cartelle

- `/lib/core`: tema e token, router, `AppShell` adattiva, client Supabase, i18n, gestione errori con messaggi leggibili, logger che non registra mai dati personali.
- `/lib/features/<feature>`: una cartella per modulo (`auth`, `onboarding`, `home`, `health`, `archive`, `treatments`, `doctor`, `settings`, poi `academy`, `nutrition` e le altre quando il loro prompt le crea). Dentro: `data/` (repository e query Supabase), `providers/` (Riverpod), `screens/`, `widgets/`.
- `/lib/l10n`: `app_it.arb` e `app_en.arb`; nessuna stringa fissa nelle schermate.
- `/supabase/migrations`: migrazioni SQL versionate `NNNN_nome.sql`; `/supabase/functions/<nome-funzione>`: Edge Functions in kebab-case (`extract`, `explain`, `compute`, `dossier-pdf`, `delete-account`, `academy`, `nutrition`, `payments-webhook`); `/supabase/tests`: pgTAP.
- `/web`: `index.html`, `_headers` per Cloudflare Pages; `/test`: test widget e unitari; `/docs`: i file di contesto, mai modificati dall'agente.

## 5. Tema e layout adattivo

- Token "Calm Health": sfondo `#F7F7F4`, testo `#111418`, secondario `#5B6470`, accento teal `#0E7C86`, stato verde `#1E9E6A`, giallo `#D98A0B`, rosso `#D64545`, grigio `#A3ABB4`; font Manrope; card con raggio 20 e bordo `rgba(17,20,24,0.06)`; dark mode con gli stessi token; niente FAB centrale.
- Tre breakpoint in un solo widget `AppShell`: sotto 600 px bottom bar a 5 tab (Home, Salute, Archivio, Cure, Medico); da 600 a 1199 px `NavigationRail`; da 1200 px in su menu laterale fisso di 260 px, contenuto centrato con larghezza massima 1440 px, griglie a 2 o 3 colonne, stati hover e focus visibili, scorciatoie da tastiera di base.
- Riferimenti di verifica per ogni schermata: 390×844 (telefono), 834×1194 (tablet), 1920×1080 (desktop full HD). Una schermata è consegnata solo se funziona in tutti e tre.
- Stati obbligatori per ogni schermata con dati: caricamento, vuoto con suggerimento, errore leggibile con riprova, contenuto. Touch target di almeno 44 px, contrasto 4,5:1, font dinamico, VoiceOver e TalkBack.
- Ogni schermata clinica porta il disclaimer "non è una diagnosi, parlane con il tuo medico" e un'unica azione contestuale.

## 6. Convenzioni di nomi e migrazioni

- Postgres: tabelle e colonne in `snake_case`, tabelle al plurale (`observations`, `meal_entries`), chiavi `id uuid` con default `gen_random_uuid()`, `created_at` e `updated_at` ovunque, `subject_id` su ogni dato clinico, enum espliciti per gli stati.
- Migrazioni: una per prompt, numerate in sequenza (`0001_foundation.sql`, `0002_archive.sql`…), idempotenti dove possibile, mai modificate dopo l'esecuzione: una correzione è una nuova migrazione. Nessun cambio manuale dal pannello Supabase.
- Dart: file `snake_case.dart`, classi `PascalCase`, provider `nomeProvider`, repository `NomeRepository`; una schermata = un file in `screens/`.
- Chiavi i18n: `feature_schermata_elemento` in camelCase ARB (`archiveListEmptyTitle`); le stesse chiavi in `it` e `en` nello stesso prompt.
- Edge Functions: una cartella per funzione, input validato con uno schema, risposta JSON, errori con codice e messaggio neutro, nessun dato clinico nei log.

## 7. Pattern dati e RLS

- `subject_id` è il soggetto dei dati: l'utente stesso o un familiare che gestisce. Una funzione sola decide l'accesso clinico: `can_access_subject(subject_id)`; ogni policy e ogni query la usano, nessun filtro "a mano" nel client.
- Default deny: nessuna tabella senza RLS e senza almeno una policy; `anon` non scrive mai; `service_role` solo nelle Edge Functions.
- Append-only: `consents`, `audit_log`, `observations`, `organ_states`, `risk_scores` non si aggiornano né si cancellano; lo stato di oggi arriva dalle viste `latest_*`, la storia dalla tabella.
- Ogni dato clinico porta la versione della regola che lo ha prodotto; le soglie si risolvono con `resolve_thresholds(subject_id, code)` su tre livelli (laboratorio, istituzionale, medico), mai oltre i limiti di sicurezza del board.
- Storage: bucket privati, path `subjects/{subject_id}/...`, policy uguali alle tabelle, signed URL a 10 minuti; foto senza EXIF e posizione.
- Ruoli in `user_roles` (enum `app_role`: user, caregiver, doctor, facility_admin, facility_staff, board, admin) e nel JWT con l'auth hook.
- Parametri commerciali (prezzi, fasce, commissioni, quota autore standard, limiti dei piani) in `platform_settings`, modificabili dall'admin con versione e audit; la quota di un singolo autore in `author_terms`.
- IA: l'output di Claude è validato contro uno schema JSON e contro intervalli plausibili prima del salvataggio; il testo del documento è dato, mai istruzione; le spiegazioni si salvano in `explanations` e si rigenerano solo se cambia un input.

## 8. Definizione di fatto (un prompt è chiuso solo se tutto questo è vero)

1. Compila ed esegue su iOS, Android e web senza errori né warning dell'analyzer.
2. Ogni schermata legge e scrive dati veri su Supabase; nessun mock, nessun dato finto.
3. Ogni tabella nuova ha RLS, almeno una policy e un test pgTAP in cui un utente estraneo ottiene zero righe.
4. Ogni schermata funziona ai tre breakpoint (390×844, 834×1194, 1920×1080) con stati di caricamento, vuoto ed errore.
5. Tutte le stringhe sono in `app_it.arb` e `app_en.arb`.
6. Il criterio di accettazione del prompt è verificato e descritto nell'output; le policy create e i test eseguiti sono elencati.
7. La checklist di sicurezza è rispettata punto per punto.
8. Il codice è esportato su GitHub prima del prompt successivo.

## 9. Cosa non fare mai

- Dati finti, schermate "facciata", TODO che rimandano il backend.
- `service_role`, chiavi, URL di progetto o secret nel client, nel repository o nei prompt.
- Testi che suonano come una diagnosi o una terapia individuale; schermate cliniche senza disclaimer.
- Dati sanitari in log, analytics, crash report, notifiche push o URL.
- Tabelle senza RLS; filtri di accesso scritti nel client invece che nelle policy.
- Creare tabelle, schermate o moduli dei prompt successivi "perché sembrano utili".
- Riscrivere file esistenti da zero: modifiche incrementali, una cosa alla volta, con il diff spiegato.
- Pacchetti nuovi senza motivazione; modifiche manuali al database; modifiche alla cartella `/docs`.
- Riassumere il MASTER nell'output: l'output è l'elenco dei file, le migrazioni, le policy, i test e ciò che resta aperto.
