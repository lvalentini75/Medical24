# Medical 24 — Edge Functions

Una cartella per funzione, nome in kebab-case, input validato, risposta JSON,
errori con codice e messaggio neutro. Nessun dato clinico finisce nei log: si
registrano solo nomi di evento, codici di errore e conteggi.

| Funzione | Chi la chiama | verify_jwt | Scopo |
| --- | --- | --- | --- |
| `delete-account` | utente autenticato | sì | chiusura e cancellazione dell'account: soft delete, revoca link e scheda ICE, rimozione immediata dei file, signOut globale (P10) |
| `document-ingest` | utente autenticato | sì | validazione e finalizzazione dell'upload (P01) |
| `extract` | utente autenticato o `service_role` | sì | passi 2–4 della pipeline: classifica, estrae, normalizza (P02) |
| `extract-batch` | solo `service_role` | sì | accoda i documenti arretrati, nessuna chiamata IA (P02) |
| `extract-batch-poll` | solo `service_role` | sì | preleva la coda e invoca `extract`, una chiamata IA per documento (P02) |
| `explain` | utente autenticato | sì | passo 7: spiegazione in due livelli con cache per hash e filtro anti-diagnosi (P06) |
| `dossier-open` | chiunque abbia codice e PIN (apikey anonima) | **no** | apertura del dossier condiviso, risposta alle domande, PDF firmato (P08) |
| `dossier-pdf` | utente autenticato | sì | genera (una volta sola) il PDF del dossier e ne restituisce l'URL firmato (P08) |
| `export-data` | utente autenticato | sì | portabilità dei dati (art. 20 GDPR): costruisce lo `.zip` con JSON, documenti e dossier e ne restituisce l'URL firmato (P10) |

## Segreti

Da impostare in **Edge Functions > Secrets**, mai nel repository, nel client
o nelle migrazioni:

- `CLAUDE_API_KEY` — chiave Anthropic usata da `extract` e da `explain`.
- `CLAUDE_MODEL_SMALL` — facoltativa, modello del passo 2. Default `claude-haiku-4-5`.
- `CLAUDE_MODEL_MEDIUM` — facoltativa, modello del passo 3 e di `explain`. Default `claude-sonnet-4-5`.
- `CLAUDE_PRICE_MEDIUM_IN` / `CLAUDE_PRICE_MEDIUM_OUT` / `CLAUDE_PRICE_SMALL_IN` /
  `CLAUDE_PRICE_SMALL_OUT` — facoltative, USD per milione di token; servono al
  calcolo di `cost_micro_usd` in `extractions` e in `explanations`.
- `DOSSIER_HASH_SECRET` — **obbligatorio** per `dossier-open`: chiave HMAC degli
  hash giornalieri dell'IP e dello user agent e della firma della sessione. Se
  manca, la funzione risponde `500 config_missing` e non apre nulla.

## `dossier-open`: chi apre il link non ha un account

È l'unica funzione con `verify_jwt = false`: la pagina pubblica del dossier
chiama con la sola apikey anonima, perché il medico che riceve codice e PIN non
ha un account. Dentro, il client usa il `service_role` e chiama solo
`share_open_rate_check`, `share_link_open` (0024) e `question_answer_via_link`
(0023), che sono riservate al `service_role` e fanno tutti i controlli.

- `{action: 'open', code, pin}` — codice di sei cifre e PIN di 4–6 cifre,
  altrimenti `400 invalid_body`; `share_open_rate_check` falso → `429
  rate_limited`; poi `share_link_open`. Esiti: `ok` → 200, `wrong_pin`,
  `locked`, `revoked`, `expired`, `exhausted` → 403 con `{outcome,
  attempts_left?, locked_until?}`, `not_found` → 404 `{outcome}`. Su `wrong_pin`
  e `locked` la risposta aspetta **300 ms fissi**, così il tempo non dice nulla.
  Su `ok` tornano `share_link_id`, `scope`, `expires_at`, `opens_left`,
  `snapshot`, `questions` e una `session`: **`subject_id` non esce mai**.
- `session` = base64url di `{share_link_id, subject_id, snapshot_id, exp}` più
  `'.'` e l'HMAC-SHA256 del corpo, valida **trenta minuti**. Serve a non
  consumare una seconda apertura: `answer` e `pdf` viaggiano con la sessione,
  non con codice e PIN. Firma errata o sessione scaduta → `401 session_invalid`.
- `{action: 'answer', session, question_id, answer}` — risposta di 1–8000
  caratteri; `question_answer_via_link` → `200 {answered: true}`; `P0001`
  (domanda non più rispondibile) → `409 not_answerable`.
- `{action: 'pdf', session}` — legge `pdf_path` dello snapshot della sessione;
  se è nullo `404 pdf_missing`, altrimenti URL firmato di **600 secondi** sul
  bucket privato `dossiers` → `200 {url, expires_in: 600}`.
- Hash: `HMAC-SHA256(DOSSIER_HASH_SECRET, AAAA-MM-GG UTC + valore)` in
  esadecimale, **prime 32 cifre**, con l'IP dal primo valore di
  `x-forwarded-for` o da `cf-connecting-ip` e lo user agent dall'omonima
  intestazione; solo Web Crypto, nessuna libreria. Il giorno nella chiave fa
  ruotare l'hash ogni ventiquattro ore.
- Nei log non finiscono mai codice, PIN, indirizzo IP, user agent o dossier:
  **una sola riga per chiamata** con `action`, esito o codice d'errore e
  latenza.

Test: `deno test --allow-env lib/supabase/functions/dossier-open/index_test.ts`
(nessuna rete, nessun database): validazione del corpo, hash stabile nello
stesso giorno UTC e diverso il giorno dopo, sessione firmata verificata,
manomessa e scaduta, mappa esito → stato HTTP e i percorsi `open`, `answer` e
`pdf` dell'handler.

`SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` sono già
presenti nell'ambiente delle Edge Functions e non vanno aggiunti a mano.

## `dossier-pdf`: il PDF si scrive una volta sola

`POST {snapshot_id, lang?: 'it' | 'en'}` con il **JWT dell'utente obbligatorio**
(senza `Authorization: Bearer …` → `401 unauthenticated`). Nessun segreto nuovo.

- Lo snapshot si legge con il **client dell'utente** (JWT inoltrato, quindi
  sotto RLS): se la riga non è sua non esiste → `404 snapshot_not_found`.
  `snapshot_id` non UUID → `400 invalid_input`.
- `pdf_path` già valorizzato → nessuna rigenerazione: URL firmato di **600 s**
  sul bucket privato `dossiers` → `200 {pdf_path, url, expires_in: 600}`.
- Altrimenti il renderer `_shared/dossier_pdf.ts` costruisce il PDF dal payload
  congelato da `dossier_build` (versione 1) con **pdf-lib**, font standard
  Helvetica, **A4**, margini **48 pt**, interruzione di pagina automatica,
  numero di pagina e «Generato da Medical 24 il <data>» a piè di pagina.
  Sezioni nell'ordine: titolo, persona (nome, data di nascita, genere), lo
  scope in parole, stato di salute con i conteggi, aree da seguire, rischi
  (famiglia, livello, punteggio, versione della regola), valori fuori
  intervallo (nome, valore e unità, intervallo, segnalazione, data, tendenza e
  valore precedente), esami consigliati, elenco documenti (titolo, categoria,
  data), versioni delle regole e **avvertenze**. Le sezioni senza dati non
  spariscono: dichiarano che non ci sono dati.
- Il caricamento usa il `service_role` nel bucket privato `dossiers` (creato se
  manca, `public = false`) in `subjects/{subject_id}/dossier/{snapshot_id}.pdf`,
  poi `dossier_snapshot_set_pdf` (0022, riservata al `service_role`), infine
  l'URL firmato → `200 {pdf_path, url, expires_in: 600}`.
- Errori `500` con codice: `render_failed`, `upload_failed`.
- **Avvertenze incorporate nel modulo**, in italiano e in inglese: il dossier
  non è una diagnosi e non sostituisce la visita; i dati provengono dai referti
  caricati dalla persona e dalle misure che ha registrato; le valutazioni e le
  decisioni di cura spettano al medico.
- Nei log solo `snapshot_id`, esito, byte e latenza: **una riga per chiamata**,
  mai nomi, valori, documenti o contenuto del dossier.

Test: `deno test --allow-env --allow-net lib/supabase/functions/dossier-pdf/index_test.ts`
(rete solo per scaricare `pdf-lib` da esm.sh; nessun database, client finti):
il renderer con un payload di prova produce un buffer che inizia con `%PDF`,
cento documenti producono almeno **due pagine**, il payload vuoto produce
comunque un PDF di una pagina, la lingua `en` cambia il titolo
(«Health dossier») e il piè di pagina, più i percorsi dell'handler: 401 senza
JWT, 404 senza snapshot, `pdf_path` già presente (nessun upload, nessuna RPC),
generazione completa, `render_failed` e `upload_failed`.

## `export-data`: il pacchetto dei propri dati

`POST {subject_id?}` con il **JWT dell'utente obbligatorio** (senza
`Authorization: Bearer …` → `401 unauthenticated`; `GET` → `405
method_not_allowed`). `subject_id` assente significa «io»; se c'è e non è un
UUID → `400 invalid_input`. Nessun segreto nuovo.

- La richiesta passa da `data_export_request` (0027) chiamata con il **client
  dell'utente**, quindi sotto RLS e con il freno delle ventiquattro ore:
  `P0001` → `429 daily_limit`, `42501` → `403 not_allowed`, `22023` → `400
  invalid_input`.
- Poi il `service_role` raccoglie i dati del soggetto, **un file JSON per
  tabella**: `profile` (senza `data_region` e `deleted_at`), `consents`,
  `documents` (metadati, **senza `storage_path`** e senza il vettore di
  ricerca), `observations`, `symptoms`, `organ_states`, `risk_scores`,
  `recommendations`, `questionnaire_answers`, `alerts`, `explanations` (testo
  compreso), `share_links` (**senza `pin_hash`**), `share_link_opens`,
  `questions`, `emergency_card` (**senza `public_token`**), `favorites`,
  `reviews`, `data_exports`. Massimo 20 000 righe per tabella.
- `README.txt` bilingue (it/en): che cosa contiene, data, versione dell'app,
  elenco dei file allegati e la nota che **i valori provengono dai referti
  caricati e dalle misure registrate, non sono una diagnosi**.
- Allegati: i file originali dei documenti dal bucket `documents`
  (`subjects/{subject_id}/documents/*/original.*`) e i PDF del bucket
  `dossiers`, fino a un totale di **150 MB**. Oltre il tetto i file restanti
  non entrano nello zip: vengono **elencati nel README** e la riga è segnata
  `truncated`.
- Lo zip si costruisce con `npm:jszip@3.10.1` in memoria, si carica nel bucket
  privato `exports` in `subjects/{subject_id}/exports/{id}.zip`, poi
  `data_export_finish` con stato `ready`, byte, numero di file e `truncated`.
  Risposta `200 {export_id, url, url_expires_in: 600, expires_at, bytes,
  file_count, truncated}`; la URL firmata dura **600 s**, il file **sette
  giorni**.
- Su errore: `data_export_finish` con stato `failed` e il codice, risposta
  `500 {code}` — `build_failed`, `upload_failed`, `finish_failed`,
  `sign_failed`.
- `{action: 'latest', subject_id?}` → `data_export_latest` (0027): stato, date,
  byte, numero di file, `truncated` ed `error_code`; più `url` e
  `url_expires_in` se l'export è `ready` e non scaduto (la funzione SQL
  restituisce la `storage_path` solo in quel caso). Nessun export → `200
  {export: null}`.
- Nei log solo `export_id`, esito, byte, numero di file e latenza: **una riga
  per chiamata**, mai nomi, valori, documenti o contenuto del pacchetto.

Test: `deno test --allow-env --allow-net --allow-read lib/supabase/functions/export-data/index_test.ts`
(rete solo per scaricare `jszip`; nessun database, client finti): la raccolta
produce un file per tabella e toglie `storage_path`, `pin_hash` e
`public_token`; lo zip contiene `README.txt` e i JSON leggibili; il tetto dei
150 MB con file finti lascia fuori i file eccedenti e li elenca nel README;
la mappa degli errori `P0001`/`42501`/`22023`; i percorsi dell'handler: 401
senza JWT, 405 su `GET`, flusso completo con `finish ready`, `build_failed` e
`upload_failed` con `finish failed`, e l'azione `latest` nei tre casi.

## `delete-account`: la conferma è esplicita e i file spariscono subito

`POST {confirm: "DELETE"}` con il **JWT dell'utente obbligatorio** (senza
`Authorization: Bearer …` → `401 unauthenticated`; `GET` → `405
method_not_allowed`). Senza la parola di conferma → `400 not_confirmed`: la
schermata chiede di scrivere ELIMINA / DELETE e il bottone resta spento finché
non combacia. Nessun segreto nuovo.

Nell'ordine:

1. `soft_delete_account` con il **client dell'utente** (quindi sotto RLS):
   `profiles.deleted_at = now()` e audit `account_soft_deleted`. Errore →
   `500 soft_delete_failed`, e non si prosegue.
2. `account_close(p_subject)` con il **`service_role`** (0028): revoca tutti i
   link di condivisione attivi, **cancella la riga di `emergency_cards`** —
   il QR pubblico smette di funzionare nello stesso istante, perché sparisce il
   `public_token` — chiude le domande al medico non chiuse e segna `expired`
   gli export pronti. Errore → `500 close_failed`.
3. Cancellazione immediata dei file del soggetto nei bucket privati
   `documents`, `dossiers` ed `exports`: elenco **ricorsivo** di
   `subjects/{subject_id}/` e `remove` a blocchi di **100** percorsi. I file
   non aspettano i trenta giorni, perché una URL firmata già emessa vivrebbe
   comunque. Errore → `500 storage_failed`.
4. Audit `account.deleted` con il numero di file rimossi (l'audit non blocca:
   il profilo è già chiuso).
5. `signOut` **globale**: tutte le sessioni, su tutti i dispositivi.

Risposta `200 {deleted: true, files_removed, purge_at, purge_after_days: 30}`:
`purge_at` è la data della purge definitiva delle righe, che resta a trenta
giorni con `purge_deleted_accounts` → `purge_subject_data` (0026/0027).

Nei log solo esito, file rimossi e latenza: **una riga per chiamata**, mai
l'identità dell'utente, mai un percorso, mai un dato clinico.

Test: `deno test --allow-env --allow-net lib/supabase/functions/delete-account/index_test.ts`
(nessun database, client finti): 405 su `GET`, 401 senza JWT e con un JWT che
non identifica nessuno, 400 senza conferma, con conferma sbagliata e con corpo
illeggibile, la conferma tollerante a maiuscole e spazi, l'ordine delle cinque
operazioni, i file dei tre bucket tutti rimossi, i file di un altro soggetto
intatti, l'audit con il conteggio, il `signOut` globale col token della
richiesta, i tre errori `500` con codice, l'audit e il `signOut` che falliscono
senza cambiare la risposta, l'elenco ricorsivo e la cancellazione a blocchi di
cento (compreso il blocco che fallisce e non viene contato).

## Dipendenze di terze parti

| Pacchetto | Funzione | Motivo |
| --- | --- | --- |
| `jsr:@supabase/supabase-js@2` | tutte | client ufficiale Supabase |
| `https://esm.sh/pdf-lib@1.17.1` | `dossier-pdf` | genera il PDF dentro Deno con i font standard PDF (Helvetica), senza binari di sistema, senza file di font da imbarcare e **senza inviare il dossier a un servizio esterno**: il PDF nasce e muore dentro la Edge Function. |
| `npm:jszip@3.10.1` | `export-data` | unica libreria ZIP stabile sul runtime Deno di Supabase: lavora **in memoria**, senza binari di sistema e senza file temporanei, e non invia nulla a servizi esterni. Le alternative native di Deno per lo ZIP non sono disponibili nel runtime delle Edge Functions. |
| `npm:unpdf@0.12.1` | `extract` | estrae il livello di testo dei PDF nativi dentro Deno, senza binari di sistema e senza inviare il file a servizi esterni. Quando il PDF ha già il testo si evita la chiamata vision, che costa molto di più; se il testo manca o è troppo corto si passa alle immagini delle pagine. Approvata con la risposta al P02-A. |

## Il documento è un dato, non un'istruzione

`extract` passa il contenuto del referto dentro un blocco `<document>` e il
prompt di sistema dichiara esplicitamente che tutto ciò che si trova lì dentro
va trattato come dato: comandi, richieste e "nuove regole" scritti nel
documento vengono ignorati. L'output del modello è validato contro uno schema
e contro i limiti di plausibilità del catalogo del board prima di qualunque
scrittura. Codice LOINC, unità canonica, intervallo di riferimento e flag non
li decide mai il modello: arrivano dalle funzioni SQL `normalize_unit`,
`resolve_reference` e `resolve_flag`.

`explain` applica la stessa regola: i dati clinici del soggetto arrivano dalla
funzione SQL `explanation_context` (solo i campi necessari, mai il testo libero
del documento) e viaggiano dentro un blocco `<subject_data>` dichiarato come
dato nel prompt di sistema. Il testo generato passa da `check_forbidden_phrases`:
un solo match dei trenta pattern del board e il testo non viene salvato, con una
sola rigenerazione prima del rifiuto `{refused: true, reason: 'filter'}`.

## pg_cron

La coda notturna è registrata dalla migrazione 0005
(`enqueue-pending-extractions`, 03:45). Lo svuotamento della coda va
pianificato nel progetto chiamando `extract-batch-poll` dallo scheduler delle
Edge Functions oppure da `pg_cron` con `pg_net`; non è registrato in SQL
perché richiederebbe il `service_role` dentro una migrazione.
