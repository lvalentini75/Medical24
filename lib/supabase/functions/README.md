# Medical 24 — Edge Functions

Una cartella per funzione, nome in kebab-case, input validato, risposta JSON,
errori con codice e messaggio neutro. Nessun dato clinico finisce nei log: si
registrano solo nomi di evento, codici di errore e conteggi.

| Funzione | Chi la chiama | verify_jwt | Scopo |
| --- | --- | --- | --- |
| `delete-account` | utente autenticato | sì | cancellazione account (P00) |
| `document-ingest` | utente autenticato | sì | validazione e finalizzazione dell'upload (P01) |
| `extract` | utente autenticato o `service_role` | sì | passi 2–4 della pipeline: classifica, estrae, normalizza (P02) |
| `extract-batch` | solo `service_role` | sì | accoda i documenti arretrati, nessuna chiamata IA (P02) |
| `extract-batch-poll` | solo `service_role` | sì | preleva la coda e invoca `extract`, una chiamata IA per documento (P02) |
| `explain` | utente autenticato | sì | passo 7: spiegazione in due livelli con cache per hash e filtro anti-diagnosi (P06) |

## Segreti

Da impostare in **Edge Functions > Secrets**, mai nel repository, nel client
o nelle migrazioni:

- `CLAUDE_API_KEY` — chiave Anthropic usata da `extract` e da `explain`.
- `CLAUDE_MODEL_SMALL` — facoltativa, modello del passo 2. Default `claude-haiku-4-5`.
- `CLAUDE_MODEL_MEDIUM` — facoltativa, modello del passo 3 e di `explain`. Default `claude-sonnet-4-5`.
- `CLAUDE_PRICE_MEDIUM_IN` / `CLAUDE_PRICE_MEDIUM_OUT` / `CLAUDE_PRICE_SMALL_IN` /
  `CLAUDE_PRICE_SMALL_OUT` — facoltative, USD per milione di token; servono al
  calcolo di `cost_micro_usd` in `extractions` e in `explanations`.

`SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` sono già
presenti nell'ambiente delle Edge Functions e non vanno aggiunti a mano.

## Dipendenze di terze parti

| Pacchetto | Funzione | Motivo |
| --- | --- | --- |
| `jsr:@supabase/supabase-js@2` | tutte | client ufficiale Supabase |
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
