# Medical 24 — Progetto esecutivo v1.1 (MEDICAL24_MASTER)

24 ottobre 2026 · Luca Valentini · Progettazione e realizzazione: Tattica Web — progettista Luca Valentini

Versione live con i disegni (Claude Doc): https://claude.ai/code/artifact/13c590ed-6ea2-4388-b940-3dfe97985783

**Versione 1.1 del 24 ottobre 2026**: entrano l'Academy (modulo M14), l'alimentazione con il diario alimentare (modulo M15), lo storico analitico di ogni valore, lo storico per organo e le soglie personalizzate dal medico curante; il modello dati arriva a 56 tabelle e il piano da 16 a 19 prompt. La v1.0 del 20 ottobre resta nella cronologia del documento.

Medical 24 vuole diventare lo standard della prevenzione e del monitoraggio ordinario della salute personale, con un ponte verso i medici e un servizio di second opinion sulle diagnosi. Questo documento è la costituzione del rebuild da zero in Flutter + Dreamflow + Supabase: architettura, modello dati, norme, funzionalità per release, sicurezza, business e il piano dei prompt.

## 1. Missione e obiettivi

Medical 24 è l'app che una persona apre prima di andare dal medico e quando torna a casa: raccoglie ogni documento sanitario, lo trasforma in dati, dice che cosa significano e che cosa fare, e passa la mano al medico quando serve. La catena che vogliamo rendere lo standard è una sola: documento → dato → significato → azione → medico.

**Che cosa deve diventare**

1. Il posto unico dove vivono referti, esami, parametri e dispositivi di una persona e della sua famiglia, in qualunque Paese.
2. Il sistema di prevenzione personale: calendario degli screening, esami consigliati con motivazione, rischi per famiglia di patologia spiegati in parole semplici.
3. Il monitoraggio ordinario: stato di salute aggiornato ogni notte, storico completo di ogni valore e di ogni organo, diario alimentare, alert quando un valore esce dalla norma personale o dalla soglia fissata dal medico, dossier sempre pronto.
4. L'interfaccia con i medici: dossier leggibile in un minuto, domande asincrone, telemedicina, permessi di accesso decisi dal paziente, soglie personalizzate per i propri pazienti.
5. Il servizio di second opinion: parere scritto di uno specialista verificato sulla documentazione del paziente, in 72 ore, con responsabilità chiara.
6. La scuola della salute: l'Academy con corsi brevi del board e dei medici verificati, legati alla wiki, che insegnano a leggere i propri esami, a prevenire e a convivere con una condizione.

**Che cosa non è**: non emette diagnosi, non è una cartella clinica ospedaliera, non è un social, non è un e-commerce. Il medico decide; l'app prepara, spiega e ricorda.

**Obiettivi a 24 mesi dal lancio** (soglie proposte, da validare con il board scientifico e con i primi dati)

| Obiettivo | Misura | Soglia |
| --- | --- | --- |
| Prevenzione reale | Utenti attivi che eseguono almeno un esame consigliato entro 6 mesi | 30% |
| Monitoraggio ordinario | Documenti caricati per utente attivo al mese; referti analizzati senza correzioni manuali | 2; 85% |
| Interfaccia medici | Dossier condivisi aperti dal medico; NPS dei medici | 60%; oltre 40 |
| Second opinion | Tempo mediano di consegna; soddisfazione del paziente | 72 ore; 4,5 su 5 |
| Formazione | Utenti attivi che completano almeno un corso dell'Academy in 6 mesi | 20% |
| Alimentazione | Utenti del diario con almeno 4 giorni registrati a settimana | 35% |
| Sostenibilità | Conversione Free → Plus a 90 giorni; retention a 30 giorni | 5%; 40% |
| Fiducia | Diagnosi automatiche emesse; violazioni dati notificate (art. 33 GDPR) | 0; 0 |

## 2. Principi non negoziabili

Questo documento è la costituzione del progetto, come HB_SOCIAL_MASTER.md lo è per HB Social 2.0: ogni prompt Dreamflow la cita all'inizio, nessun prompt la contraddice, e un cambio di principio passa da una nuova versione di questo documento.

1. **Backend-first, zero mock.** Ogni schermata legge e scrive su Supabase attraverso RLS dal primo prompt; nessun dato finto, nessuna facciata. È la lezione del primo tentativo Dreamflow di HuntingBook.
2. **Nessuna diagnosi.** L'app estrae, normalizza, confronta con intervalli e regole validate dal board, spiega e suggerisce. Il verdetto clinico è sempre del medico e ogni schermata lo dice.
3. **Regole deterministiche, IA per il linguaggio.** Stati organo, rischi e score (SCORE2, FINDRISC, CKD-EPI, FRAX) escono da regole versionate e firmate dal board; Claude serve per leggere documenti, normalizzare e spiegare, mai per decidere.
4. **Privacy by design.** Dati sanitari come categoria particolare (art. 9 GDPR): consenso esplicito e separato, minimizzazione, cifratura, residenza EU, diritto all'oblio eseguibile in un tap.
5. **Sicurezza in ogni prompt.** La checklist della sezione 15 chiude ogni prompt Dreamflow; un prompt senza checklist non si esegue.
6. **Un codice, tre piattaforme.** Flutter per iOS, Android e web; nessuna funzione "solo app" o "solo web" salvo i sensori del telefono.
7. **Costi IA sotto controllo.** Una sola chiamata per documento, spiegazioni generate una volta e messe in cache, batch notturno, modello piccolo per OCR e classificazione, modello grande solo dove serve.
8. **Globale dal primo giorno.** Italiano e inglese in v1 con chiavi ARB, unità locali (mg/dL o mmol/L), formati data, residenza dati EU e US separate.
9. **Il medico è un utente, non un contenuto.** Ogni funzione per i medici deve fargli risparmiare tempo, altrimenti non entra.
10. **Misurabile.** Ogni modulo ha un KPI nella sezione 17 e un criterio di accettazione nel suo prompt.
11. **Board scientifico sovrano sui contenuti.** Intervalli, regole, testi delle spiegazioni, esami consigliati, corsi dell'Academy, riferimenti nutrizionali e limiti di sicurezza delle soglie: tutto passa dal pannello del board e porta una versione. Il medico curante può personalizzare le soglie dei suoi pazienti, dentro quei limiti e sempre accanto al riferimento istituzionale.
12. **Premium calmo.** Interfaccia "Calm Health 2026" del mockup: bianco caldo, teal, stati verde/giallo/rosso, niente FAB centrale, un'azione contestuale per schermata.

## 3. Schema a blocchi funzionale

Quattro canali, quindici moduli, una piattaforma: tutto passa dal motore.

- **Canali**: App iOS e Android · Web per PC · Dashboard medico (v2) · Backoffice (v3)
- **Moduli funzionali**: M1 Identità (consensi, famiglia) · M2 Archivio (categorie e ricerca) · M3 Motore (OCR ed estrazione) · M4 Stato di salute (score, storico, alert) · M5 Corpo e organi (12 aree, stati, storico) · M6 Prevenzione (rischi, score, esami) · M7 Spiegazioni (coach e wiki) · M8 Cure (tre famiglie, rating) · M9 Medici (dossier, video, soglie) · M10 Second opinion (parere in 72 ore) · M11 Dispositivi (HealthKit, BLE) · M12 Piani e admin (board, audit, piani) · M14 Academy (corsi del board e dei medici, legati alla wiki) · M15 Alimentazione (diario, foto dei pasti, piano del dietista) · M13 Strutture e ospedali (v3: backoffice, B2B, interoperabilità FHIR)
- **Piattaforma**: Supabase (Auth, Postgres, RLS, Storage, Edge Functions, pg_cron) · Claude API (OCR, estrazione, piatti, spiegazioni in cache) · RevenueCat e Stripe (abbonamenti, corsi, servizi uno a uno) · Sistema e sensori (push, Cloudflare Stream, HealthKit e Health Connect)

Il colore pieno nel disegno segna il motore M3: ogni dato clinico nasce lì e alimenta M4, M5, M6 e M15.

Si legge dall'alto: i quattro canali sono interfacce dello stesso backend; i moduli M1–M12 coprono v1 e v2, M14 Academy e M15 Alimentazione entrano in v1.5 e crescono in v2, M13 è la v3; la piattaforma è la stessa per tutti. Ogni dato clinico nasce nel motore M3 e da lì alimenta stato di salute, organi, prevenzione e la vista "alimentazione e valori"; nessun modulo scrive un valore clinico senza passare da lì. Le foto dei pasti seguono la stessa strada dei referti: entrano nel motore e ne escono come nutrienti.

## 4. Architettura tecnica

Il client vede solo Supabase; IA e pagamenti vivono dietro le Edge Functions.

- **Client Flutter**: iOS, Android, web; Riverpod, GoRouter; dashboard medico web; solo anon key, HTTPS. **Sul telefono**: HealthKit (iOS), Health Connect (Android), token cifrati, biometria; letture passate al client solo con consenso.
- **Supabase, regione EU**: Auth (OTP, Apple, Google, ruoli nel JWT) · Postgres con RLS via PostgREST (56 tabelle, can_access_subject()) · Storage privato (bucket per soggetto, signed URL) · Edge Functions (extract, explain, compute, dossier, delete-account, webhook pagamenti, academy, nutrition, video firmato) · pg_cron e Realtime (batch notturno, stato, chat)
- **Servizi esterni**, chiamati via API dalle Edge Functions e che rispondono con eventi firmati: Claude API (OCR, estrazione JSON, spiegazioni in cache) · RevenueCat (App Store e Play, Stripe per il web) · Stripe Connect (second opinion, video, payout ai medici) · APNs e FCM (notifiche, zero dati) · Cloudflare Stream (video dei corsi, token)

Nessun secret nel client: Claude, RevenueCat, Stripe e Cloudflare Stream sono raggiungibili solo dalle Edge Functions.

Il client Flutter parla solo con Supabase (Auth, PostgREST con RLS, Storage, Edge Functions) con la anon key e il JWT dell'utente; tutto ciò che costa o che ha un secret (Claude, RevenueCat, Stripe, push, Cloudflare Stream) vive dietro le Edge Functions, che ricevono i webhook firmati. I dati dei sensori restano sul telefono finché l'utente non li collega. I video dei corsi stanno su Cloudflare Stream e si riproducono con token firmati a scadenza; i dati alimentari vengono da banche dati aperte (CREA, USDA FoodData Central, Open Food Facts) seminate in `food_catalog` da una Edge Function.

| Componente | Scelta | Perché | Scartato |
| --- | --- | --- | --- |
| App e web | Flutter stable generato e mantenuto con Dreamflow; Riverpod; GoRouter con StatefulShellRoute | Un codice per iOS, Android e web; lo stack che Luca già usa su HuntingBook e VisitCity | Native separate; React Native |
| Backend | Supabase: Auth, Postgres 15 con RLS, Storage, Edge Functions (Deno), pg_cron, Realtime, Vault, pgsodium | Un fornitore, RLS come unico punto di controllo, regione EU, self-hosting possibile in futuro come per ProntoRad | Firebase (no SQL, no RLS); backend custom |
| Estrazione e spiegazioni | Claude API: modello piccolo per classificare, medio per estrarre, Batch API per la notte, prompt caching, output JSON con schema | Lettura di foto e PDF in una chiamata, qualità su testi medici, batch a metà prezzo | OCR tradizionale + regex (fragile sui referti) |
| Regole cliniche | Funzioni SQL e TypeScript versionate in `rule_versions`, test con casi del board | Deterministiche, riproducibili, spiegabili al regolatore | Regole dentro il prompt IA |
| Abbonamenti | RevenueCat con `purchases_flutter`: App Store, Google Play e [Stripe per il web](https://www.revenuecat.com/integrations/stripe.md) in un solo entitlement; webhook verso la Edge Function che aggiorna `subscriptions` | Un solo stato di abbonamento su tre canali, ricevute e rinnovi gestiti | StoreKit e Play Billing diretti |
| Servizi a consumo | Stripe Checkout per second opinion e televisite; Stripe Connect per i payout ai medici; fatture B2B | Servizi uno-a-uno fuori dall'acquisto in-app; payout e fiscalità gestiti | Pagamenti fuori piattaforma |
| Notifiche | APNs e FCM via `firebase_messaging`, inviate da una Edge Function con testo neutro | Nessun dato clinico in transito | Email come canale primario |
| Sensori | `health` per HealthKit e Health Connect; `flutter_blue_plus` per i dispositivi BLE; OAuth Garmin | Lettura solo con consenso, dati scritti come observations con origine device | SDK proprietari per ogni marca in v1 |
| Video (v2) | Daily, 100ms o LiveKit: decisione aperta | Costo al minuto, GDPR, qualità su rete mobile | WebRTC fatto in casa |
| PDF | Edge Function con pdf-lib per dossier e pareri | Stesso output su app e web, firmabile | Generazione lato client |
| Osservabilità | Sentry (app e functions, dati oscurati), PostHog EU per il prodotto, log Supabase | Nessun dato clinico nei log | Analytics con dati sanitari |
| Hosting web e CI | Flutter web su Cloudflare Pages; GitHub per il codice con export dopo ogni prompt; Codemagic per le build degli store | Ripetibile, con storia; mai più un codice che vive solo nel builder | Codice solo in Dreamflow |
| Ambienti | Tre progetti Supabase (dev, staging, prod) e tre bundle id | Nessun test su dati veri | Un ambiente solo |
| Video dei corsi (Academy) | Cloudflare Stream: upload diretto firmato dallo studio autore, HLS adattivo, token di riproduzione firmati con scadenza, sottotitoli caricati dalla Edge Function academy | Stesso fornitore delle Pages, costo a minuto senza server video (5 $ al mese ogni 1.000 minuti archiviati, 1 $ ogni 1.000 minuti erogati), nessun tracciamento pubblicitario | MP4 nello Storage Supabase (banda, nessun adattivo); YouTube (pubblicità e tracciamento) |
| Dati alimentari (M15) | food_catalog seminato da CREA, USDA FoodData Central e Open Food Facts via Edge Function; riconoscimento di piatti e porzioni con Claude vision nella stessa Edge Function extract dei referti | Copertura Italia e mondo con licenze aperte; una sola pipeline per referti e pasti | SDK a pagamento (Nutritionix, Edamam) in v1.5 |

## 5. Modello dati

Un solo schema `public` su Postgres (Supabase), 56 tabelle, nessuna tabella senza policy RLS. Il soggetto dei dati è sempre `subject_id`: l'utente stesso o un familiare che gestisce. Tutto ciò che è clinico (`observations`, `organ_states`, `risk_scores`) porta la versione della regola che lo ha prodotto, così ogni numero è riproducibile.

**Regole RLS che valgono ovunque**

- Default deny: nessuna policy, nessun accesso. `anon` non scrive mai.
- Una funzione sola decide l'accesso clinico: `can_access_subject(subject_id)` = proprietario, oppure delegato familiare attivo, oppure medico con `doctor_patient_links` attivo e con quel dato nello scope.
- `service_role` solo dentro le Edge Functions; mai nel client.
- Le policy dello Storage ricalcano quelle delle tabelle: path `subjects/{subject_id}/documents/{document_id}/...`, bucket privati, signed URL con scadenza breve.
- `consents` e `audit_log` sono append-only: nessuna policy di update o delete.
- Cancellazione account = soft delete immediato + purge pianificata a 30 giorni (art. 17 GDPR), con log della purge.
- I ruoli stanno in `user_roles` (enum `app_role`: user, caregiver, doctor, facility_admin, facility_staff, board, admin) e finiscono nel JWT con l'auth hook di Supabase.
- Nessun valore clinico si sovrascrive: `observations` tiene ogni valore con la sua data e il suo documento, `organ_states` e `risk_scores` ricevono una riga a ogni calcolo; le viste `latest_organ_states` e `latest_risk_scores` danno lo stato di oggi, la tabella dà la storia.
- Le soglie si risolvono con una funzione sola, `resolve_thresholds(subject_id, code)`, che restituisce sempre tre livelli: laboratorio, istituzionale (board), medico. `threshold_overrides` e `nutrition_plans` li scrive solo un medico o un professionista con `doctor_patient_links` attivo e con lo scope giusto, e mai oltre i limiti di sicurezza fissati dal board in `rule_versions`.

**Tabelle**

| Tabella | Contenuto | Campi chiave | Accesso |
| --- | --- | --- | --- |
| profiles | Utente: nome, avatar, data di nascita, genere, lingua, unità, Paese, regione dati, fuso | id = auth.uid | Solo proprietario |
| family_members | Profili gestiti (figli, anziani): dati base, relazione, consenso del tutore | owner_id | Proprietario e delegati |
| user_roles | Ruolo applicativo per utente | user_id, role | Lettura propria; scrittura admin |
| consents | Consenso per tipo (sanitario art. 9, marketing, ricerca, condivisione, diario alimentare, contenuti d'autore), versione del testo, concessione e revoca | user_id, type, version | Append-only del proprietario |
| documents | File: soggetto, categoria, titolo, data documento, origine (camera, galleria, email, FSE), storage_path, hash, stato (uploaded, processing, analyzed, needs_review, failed) | owner_id, subject_id | can_access_subject |
| document_pages | Pagina, testo OCR, immagine normalizzata | document_id | come documents |
| extractions | Output IA grezzo in JSON, modello, versione prompt, confidenza media, token spesi; vale per referti e per foto dei pasti | document_id o meal_entry_id | Lettura proprietario; scrittura service_role |
| observations | Un valore clinico: codice LOINC, nome, valore numerico o testo, unità UCUM, intervallo del laboratorio, data, origine (documento, manuale, dispositivo), confidenza, confermato dall'utente; nessun valore viene sovrascritto, così lo storico per codice è completo; flag fuori soglia a tre livelli (laboratorio, istituzionale, medico) calcolato alla scrittura e ricalcolato quando cambia una soglia | subject_id, code, effective_at | can_access_subject |
| symptoms | Sintomo con severità, note, foto, data; anche i sintomi dopo un pasto | subject_id | can_access_subject |
| biomarker_catalog | Codice, nomi e sinonimi multilingua, unità canonica, conversioni, intervalli ottimali per età e genere (riferimento istituzionale), limiti di sicurezza non superabili, organi collegati, versione board | code | Lettura pubblica; scrittura board |
| threshold_overrides | Soglia personalizzata dal medico: codice, limite basso e alto, unità, ambito (tutti i suoi pazienti o un soggetto), motivazione obbligatoria, validità, versione; mai oltre i limiti di sicurezza del board; ogni modifica in audit e notifica al paziente (v2) | doctor_id, subject_id (vuoto = tutti), code | Scrittura medico con legame attivo; lettura paziente e medico |
| organs | Le 12 aree: nome, descrizione, posizione sulla silhouette | id | Lettura pubblica |
| organ_biomarker_map | Organo ↔ biomarcatore con peso | organ_id, code | Lettura pubblica |
| organ_states | Stato per organo (ok, monitor, attention, missing), input usati, versione regola, data calcolo; una riga per ogni calcolo, così la scheda organo ha lo storico e il confronto a 6 e 12 mesi; vista latest_organ_states per lo stato di oggi | subject_id, organ_id, computed_at | Lettura can_access_subject; scrittura service_role |
| risk_scores | Famiglia di patologia, livello basso/medio/alto, score numerico, input, versione regola; una riga per ogni calcolo, vista latest_risk_scores | subject_id, family, computed_at | come organ_states |
| recommendations | Esame, visita, abitudine o corso consigliato: motivazione, periodicità, scadenza, stato (open, done, dismissed), origine (regola o medico) | subject_id | can_access_subject |
| questionnaires, questionnaire_answers | Domande del board e risposte per soggetto | subject_id | can_access_subject |
| explanations | Testo IA per referto, organo, rischio o pasto: livello (semplice o clinico), lingua, hash degli input, modello; è la cache | subject_id, target | Lettura can_access_subject |
| medications | Farmaci in uso: nome, dose, orari, promemoria, attivo (v1.5); inizio e fine diventano annotazioni sulle serie storiche | subject_id | can_access_subject |
| nutrition_profiles | Profilo alimentare: schema (onnivoro, vegetariano, vegano, pescetariano, mediterraneo, senza glutine, senza lattosio, halal, kosher, altro), obiettivo, livello di attività, riferimenti per energia e nutrienti calcolati dalle regole del board, modulo attivo (v1.5) | subject_id | can_access_subject con scope nutrizione |
| food_catalog | Alimenti e prodotti: nome multilingua, categoria, nutrienti per 100 g e per porzione, porzioni tipiche, allergeni, codice a barre, fonte (CREA, USDA FoodData Central, Open Food Facts, professionista), licenza, versione | id, barcode | Lettura pubblica; scrittura board, professionisti verificati ed Edge Function |
| meal_entries | Pasto: tipo (colazione, pranzo, cena, spuntino, acqua), data e ora, foto, origine (foto IA, codice a barre, ricerca, manuale, ricetta), confidenza, confermato, note, sazietà, totali di energia e nutrienti (v1.5) | subject_id, eaten_at | can_access_subject con scope nutrizione |
| meal_items | Alimento di un pasto: voce del catalogo, quantità e unità, porzione stimata dall'IA e corretta dall'utente, nutrienti calcolati | meal_entry_id | come meal_entries |
| nutrition_plans | Piano del professionista: schema, target per nutriente (sovrascrivono i riferimenti, mai sotto i minimi del board), schema dei pasti, alimenti da preferire e da evitare, durata, note, versione, stato (v2) | subject_id, doctor_id | Professionista con legame attivo e paziente |
| devices | Dispositivo collegato: tipo, vendor, identificativo, ultimo sync (v2); le letture finiscono in observations con origine device | subject_id | Proprietario |
| alerts | Avviso: tipo (info, warning, critical), origine, messaggio, letto; porta il livello di soglia che lo ha generato | subject_id | can_access_subject |
| push_tokens | Token APNs/FCM per dispositivo e preferenze | user_id | Proprietario |
| treatments | Cura: titolo, famiglia (tradizionale, sperimentale, naturale), categoria, patologie, descrizione, evidenza, controindicazioni, costi, tempi, sede, medico, struttura, stato (draft, verified, published), versione | id, doctor_id, facility_id | Lettura pubblica se published; scrittura medico proprietario e admin |
| treatment_tags | Tag e categorie delle cure | treatment_id | Lettura pubblica |
| reviews | Recensione su cura, medico, struttura o corso: voto totale e sottovoci, testo, stato moderazione, verificata | author_id, target | Autore; lettura pubblica se approvata |
| favorites | Preferiti dell'utente | user_id, target | Proprietario |
| doctors | Profilo del professionista: ruolo (medico, medico dietologo, dietista, biologo nutrizionista), specialità, Ordine o albo e numero, stato verifica e documenti, lingue, bio, tariffe, disponibilità, account Stripe Connect, autore Academy (v2) | user_id | Lettura pubblica se verificato; scrittura proprietario |
| facilities | Struttura: tipo, accreditamento SSN, indirizzo e coordinate, contatti, servizi, orari, foto, verifica | id | Lettura pubblica |
| facility_staff | Personale di struttura con ruolo (admin, medico, segreteria) (v3) | facility_id, user_id | Admin di struttura |
| share_links | Condivisione dossier con codice: token, scope, scadenza, PIN, aperture (v1) | subject_id, token | Proprietario; apertura via Edge Function |
| doctor_patient_links | Legame medico ↔ paziente: scope (categorie, periodo, organi, nutrizione), stato (invited, active, revoked), scadenza (v2) | doctor_id, subject_id | Entrambe le parti |
| doctor_notes | Note e commenti del professionista su dossier, valore, organo, pasto o piano: testo cifrato, visibilità (solo professionista o condivisa con il paziente) (v2) | doctor_id, subject_id, target | Autore; paziente se condivisa |
| questions | Domanda asincrona al medico: testo, allegati, stato, risposta (v1) | subject_id, doctor_id | Entrambe le parti |
| appointments | Prenotazione: medico, struttura, slot, tipo (presenza, video, chat), stato (v2) | subject_id, doctor_id | Entrambe le parti |
| chat_messages | Messaggi paziente ↔ medico, allegati, letto (v2) | thread_id | Entrambe le parti |
| second_opinion_requests | Richiesta: specialità, livello di servizio, stato (draft, paid, assigned, in_review, needs_info, delivered, closed), snapshot del dossier, domande, prezzo, pagamento Stripe, medico assegnato, scadenza SLA (v2) | subject_id, doctor_id | Paziente e medico assegnato |
| second_opinion_reports | Parere strutturato, PDF, consegna, domanda di follow-up, valutazione (v2) | request_id | Paziente e medico |
| courses | Corso dell'Academy: titolo, sottotitolo, autore (board o professionista verificato), destinatari (paziente, caregiver, professionista), argomenti (condizioni, biomarcatori, organi, prevenzione), lingua, livello, prezzo (gratuito, incluso in Plus, a pagamento), stato (draft, in_review, published, retired), versione, data di revisione (v1.5; autori medici v2) | id, author_id | Lettura pubblica se published; scrittura autore e board |
| course_lessons | Lezione: ordine, tipo (video, testo, quiz), durata, id video su Cloudflare Stream, testo, sottotitoli, domande del quiz con risposte e spiegazioni, anteprima gratuita | course_id | come courses |
| content_references | Fonte citata da lezioni, articoli wiki e schede cura: tipo (linea guida, articolo con DOI o PubMed, sito istituzionale), titolo, autori, anno, URL, verificata dal board | target | Lettura pubblica; scrittura autore e board |
| course_enrollments | Iscrizione: utente, corso, origine (gratuito, Plus, acquisto, consigliato dal medico), data, completamento, attestato | user_id, course_id | Proprietario; l'autore vede solo conteggi aggregati |
| lesson_progress | Avanzamento per lezione: secondi visti, completata, esito del quiz, ultima posizione | user_id, lesson_id | Proprietario |
| subscriptions | Entitlement da RevenueCat: app_user_id, piano (free, plus, family, pro), store (apple, google, stripe), stato, rinnovo; aggiornata solo dal webhook | user_id | Lettura proprietario; scrittura service_role |
| payments, payouts | Pagamenti Stripe (second opinion, televisite, piani nutrizionali, B2B), acquisti singoli di corsi (webhook RevenueCat e Stripe) e payout a medici e autori (v2) | user_id, doctor_id | Parte interessata |
| platform_settings | Parametri commerciali e operativi modificabili dal pannello admin senza un rilascio: quota autore standard dei corsi, fasce di prezzo dei corsi, commissioni su second opinion, televisite e piani nutrizionali, limiti dei piani (documenti, analisi al mese, foto dei pasti al giorno), SLA e rimborsi; chiave, valore JSON, versione, chi l'ha cambiato e quando; ogni cambio conserva la versione precedente | key, version | Lettura pubblica delle chiavi marcate public (limiti e prezzi), le altre solo dalle Edge Functions; scrittura admin, con audit |
| author_terms | Condizioni di un singolo autore dell'Academy quando differiscono dallo standard: quota autore, validità da-a, motivo, chi l'ha impostata; la quota in vigore al momento dell'acquisto viene copiata sul pagamento, così i payout non cambiano a posteriori (v2) | author_id, valid_from | Lettura autore e admin; scrittura admin, con audit |
| rule_versions | Regole del board: tipo (stato organo, rischio, raccomandazione, intervallo, limite di sicurezza, riferimento nutrizionale), definizione JSON, versione, approvata da, data, attiva | id, version | Lettura pubblica; scrittura board |
| content_wiki | Articoli su biomarcatori e condizioni, lingua, versione board, corsi collegati (v1.5) | slug, lang | Lettura pubblica |
| audit_log | Chi ha fatto cosa su quale dato: attore, azione, tabella, id, soggetto, dispositivo, data; anche ogni soglia creata, cambiata o scaduta | subject_id, actor_id | Append-only; lettura proprietario del soggetto e admin |

**Mappa FHIR per la portabilità** (export in FHIR R4 JSON dal primo giorno, pronto per EHDS): profiles e family_members = Patient; documents = DocumentReference; observations = Observation con LOINC e UCUM; doctors = Practitioner; facilities = Organization; appointments = Appointment; medications = MedicationStatement; recommendations = ServiceRequest; nutrition_plans = NutritionOrder; meal_entries = Observation con i codici di assunzione alimentare (NutritionIntake con il passaggio a FHIR R5); threshold_overrides = referenceRange dell'Observation esportata, con l'autore della soglia; i corsi dell'Academy restano fuori dal FHIR.

## 6. Pipeline del motore

Otto passi, una chiamata IA per documento: 1 Carica → 2 Classifica → 3 Estrai → 4 Normalizza → 5 Verifica → 6 Calcola → 7 Spiega → 8 Agisci. Di notte pg_cron rianalizza in batch; il tap Aggiorna e il primo documento passano subito.

I passi 1–5 trasformano un documento in osservazioni verificate; i passi 6–8 trasformano le osservazioni in significato e azione. Il confine è netto: fino al passo 5 lavora l'IA (lettura, normalizzazione), dal passo 6 lavorano solo le regole del board; l'IA torna al passo 7 solo per scrivere il testo, mai per cambiare un numero. La stessa catena legge le foto dei pasti del modulo M15: al passo 2 il modello piccolo riconosce che è cibo, al passo 3 il modello medio elenca piatti e porzioni con una confidenza, al passo 4 il catalogo alimenti li trasforma in nutrienti, al passo 5 l'utente corregge le porzioni, dal passo 6 si calcolano i totali del giorno e l'aderenza allo schema alimentare.

| Passo | Chi lo fa | Input | Output | Costo |
| --- | --- | --- | --- | --- |
| 1 Carica | App | Foto, PDF, email, share sheet | `documents` in stato uploaded, pagine normalizzate a 1600 px | Storage |
| 2 Classifica | Edge Function extract, modello piccolo | Prima pagina o testo | Categoria, data presunta, hash per i duplicati | Una chiamata leggera |
| 3 Estrai | Edge Function extract, modello medio | Tutte le pagine | JSON con valori, unità, intervalli del laboratorio, date, frasi di follow-up | La chiamata principale, una per documento |
| 4 Normalizza | Funzione SQL | JSON grezzo + `biomarker_catalog` | `observations` con LOINC, UCUM, valore convertito | Nessuno |
| 5 Verifica | Utente, con l'app | Valori sotto soglia di confidenza | Conferma o correzione, tracciata | Nessuno |
| 6 Calcola | Edge Function compute + regole SQL | Osservazioni, profilo, questionario | `organ_states`, `risk_scores`, `recommendations`, alert | Nessuno |
| 7 Spiega | Edge Function explain | Stato, rischio o referto + livello + lingua | `explanations` in cache per hash | Una chiamata per bersaglio, poi zero |
| 8 Agisci | App | Raccomandazioni, alert, dossier | Calendario, notifiche, "ho fatto l'esame", PDF | Nessuno |

**Serie storiche e soglie a tre livelli**: nessun valore si sovrascrive. Ogni osservazione resta con la sua data e il suo documento, così per ogni biomarcatore (gamma GT, transferrina, glicemia, colesterolo, creatinina…) esiste lo storico completo: grafico su tutto il periodo, tabella dei valori con laboratorio e documento, minimo, massimo, media, ultimo valore e variazione, episodi fuori soglia con inizio e fine. Il confronto avviene su tre livelli sempre visibili insieme: l'intervallo del laboratorio stampato sul referto, il riferimento istituzionale del board per età e genere e, dal v2, la soglia del medico curante che segue quel paziente (sezione 12). Anche gli stati organo e i rischi si salvano a ogni calcolo e non si aggiornano in place: la scheda organo mostra il percorso nel tempo, con il confronto a 6 e 12 mesi e gli episodi di attenzione datati.

## 7. Funzionalità per release

Quindici moduli, quattro release. Le 264 voci dell'inventario sono tutte qui, ricollocate: le 26 che il draft v0.1 non aveva ripreso entrano nella release proposta dalla verifica di copertura, la parte ospedaliera diventa il modulo M13; con il brief del 24 ottobre 2026 l'Academy diventa il modulo M14 e l'alimentazione il modulo M15, lo storico dei valori e degli organi entra in M4 e M5, le soglie personalizzate in M9. Le voci marcate (nuova) vengono dalla sezione 8.

| Modulo | Nome | Release |
| --- | --- | --- |
| M1 | Identità, consensi, profilo, famiglia | v1, famiglia in v1.5 |
| M2 | Archivio documentale | v1 |
| M3 | Motore di estrazione | v1 |
| M4 | Stato di salute, parametri e storico dei valori | v1 |
| M5 | Corpo e organi, con storico per organo | v1 |
| M6 | Rischi, score, prevenzione | v1 |
| M7 | Spiegazioni, coach, wiki | v1 spiegazioni, v1.5 coach e wiki |
| M8 | Cure | v1 base, v1.5 avanzato |
| M9 | Medici: dossier, domande, telemedicina, soglie personalizzate | v1 dossier, v2 account medico e soglie |
| M10 | Second opinion | v2 |
| M11 | Dispositivi | v2 |
| M12 | Monetizzazione, admin, board | v1 |
| M13 | Strutture e ospedali | v3 |
| M14 | Academy e formazione | v1.5 corsi del board, v2 corsi dei medici e vendita |
| M15 | Alimentazione e diario alimentare | v1.5 diario, v2 con il professionista |

**v1 — lancio: il prodotto che funziona davvero**

| Modulo | Funzionalità |
| --- | --- |
| M1 | Registrazione email con OTP, login Apple e Google; segmentazione paziente; consensi separati sanitario (art. 9) e marketing; notifiche push spiegate prima del prompt; dati base, genere ed età per gli intervalli; lingua, unità, fuso; questionario sotto il minuto; patologie e sintomi noti per cluster; profilo salute (altezza, peso, gruppo sanguigno, allergie, farmaci, croniche, interventi); contatti di emergenza, scheda emergenza e pulsante SOS; percentuale di completamento; Face ID, impronta e PIN; eliminazione account ed export completo |
| M2 | Upload da fotocamera multipagina, galleria, PDF, share sheet; categorie Esami, Referti, Prescrizioni, Radiologia, Vaccinazioni, Fatture, Consensi, Tessere, Altro; tag utente e tag IA; ordinamento per data, tipo, medico, struttura; raggruppamento per anno, organo, episodio; ricerca testuale; anteprime; stato caricato / in analisi / analizzato / da verificare; "Visualizza analisi"; timeline; condivisione con link a scadenza; bucket privati, cifratura, signed URL; limiti Free e Plus |
| M3 | OCR ed estrazione strutturata (biomarcatore, valore, unità, intervallo, data, laboratorio); catalogo biomarcatori con sinonimi e conversioni; confidenza e conferma manuale dei dubbi; scansione notturna e a richiesta; cache dei risultati; osservazioni FHIR con LOINC e UCUM |
| M4 | Card stato di salute; health score 0–100; parametri manuali pressione, peso, glicemia, frequenza, temperatura, ossigeno; diario sintomi; grafici 7 / 30 / 90 giorni; storico completo per biomarcatore: tutti i valori di tutti i referti su un solo grafico, tabella con data, valore, laboratorio e documento, minimo, massimo, media, variazione sull'ultimo valore, episodi fuori soglia con inizio e fine, confronto di due valori sullo stesso grafico, annotazioni (nuova); tendenze sulla baseline personale; alert warning e critical con "contatta il medico"; centro avvisi; lista biomarcatori con filtri, preferiti, essenziali, "+ Traccia"; intervallo del laboratorio, riferimento istituzionale del board e, dal v2, soglia del medico, sempre mostrati insieme; checkup personalizzato; to-do in home; dashboard Analisi con data ultimo aggiornamento; export CSV e PDF |
| M5 | Silhouette interattiva con 12 aree; stati ok / da monitorare / attenzione / dato mancante; scheda organo con biomarcatori, ultimo esame, trend, esami suggeriti; tap sull'organo per lo stato di oggi e doppio tap o "Storico" per il percorso nel tempo: stati salvati a ogni calcolo, grafico dei biomarcatori dell'organo su tutto il periodo, confronto a 6 e 12 mesi con freccia di miglioramento o peggioramento, episodi di attenzione datati (nuova); livello di confidenza del quadro |
| M6 | Rischio basso / medio / alto per 8 famiglie; SCORE2, FINDRISC, CKD-EPI, FRAX; proiezione a 12 mesi; "perché" di ogni rischio; esami consigliati con motivazione e periodicità; calendario della prevenzione per età e genere (nuova); questionario integrativo; mappa rischi in home; regole versionate dal board, nessuna diagnosi |
| M7 | Spiegazione del referto in due livelli, semplice e clinico (nuova); spiegazione per organo e per rischio; disclaimer su ogni schermata |
| M8 | Database cure in tre famiglie; scheda base con foto, patologie, medico e struttura; ricerca per tag, categoria, patologia, medico; filtri rapidi; raggruppamenti; rating con sottovoci; recensioni verificate e moderate; anti-abuso; preferiti; cure in evidenza; anagrafiche base medico e struttura; stato vuoto con suggerimenti; admin cure |
| M9 | Dossier PDF e link con stato, rischi, esami; condivisione con codice a 6 cifre e PIN senza account per il medico (nuova); domande asincrone al medico |
| M12 | Piani Free e Plus via RevenueCat su App Store e Google Play, Stripe sul web; paywall contestuale dopo il primo documento; pannello admin (utenti, documenti, cure, verifiche, moderazione, metriche, parametri commerciali in platform_settings: quota autore standard e per singolo autore, fasce di prezzo, commissioni, limiti dei piani); pannello board (intervalli, regole, testi, versioni); audit log; analytics di prodotto; strumenti GDPR (export, oblio, registro consensi) |
| Piattaforma | iOS, Android e web da un codice; bottom bar Home · Salute · Archivio · Cure · Medico; home dashboard; azioni rapide contestuali; notifiche push; stati vuoti e di caricamento; dark mode e accessibilità; italiano e inglese; sito con landing, funzioni, prezzi, download |

**v1.5 — famiglia, coach, aderenza**

| Modulo | Funzionalità |
| --- | --- |
| M1 | Piano Family con 3 profili e cambio rapido; modalità caregiver con testi grandi e avvisi al familiare (nuova); import referti da Gmail, IMAP e forward-to-inbox |
| M2 | Archivio visite (note, diagnosi, prescrizioni per visita); note vocali e foto sintomi allegate; passaporto sanitario multilingua per i viaggi (nuova) |
| M4 | Farmaci in uso con promemoria e card in home; alert soft sulla baseline; benchmark per età e genere; "cause possibili" per valore alto o basso |
| M6 | Pre-visita: checklist di cosa portare e domande da fare, generata dal dossier (nuova) |
| M7 | Coach IA in chat con guardrail e link a stato, documenti e wiki; wiki biomarcatori e condizioni; articoli Plus |
| M8 | Scheda cura avanzata (costi, attese, requisiti, controindicazioni, esito, evidenza, sede); filtri avanzati e ordinamenti; confronto 2–4 cure; cure consigliate dal profilo di rischio; piano di cura personale con aderenza; ricerca vocale; pagine pubbliche SEO; ricerca medici e strutture con mappa |
| M14 | Academy base: catalogo dei corsi del board (prevenzione, come leggere i propri esami, condizioni croniche), lezioni video e testo, quiz, avanzamento e attestato, legame in entrambe le direzioni con la wiki e con le schede organo e rischio ("Impara"), "Per te" dal profilo di salute con una regola del board, corsi gratuiti e corsi inclusi in Plus, corso consigliato dal medico nel dossier |
| M15 | Diario alimentare: pasti con foto riconosciute dall'IA e porzioni da confermare, codice a barre, ricerca nel catalogo alimenti, inserimento manuale e ricette, acqua, note e sintomi dopo il pasto; profilo alimentare (onnivoro, vegetariano, vegano, pescetariano, mediterraneo, senza glutine o lattosio, halal, kosher) con controllo di coerenza; allergie e intolleranze del profilo incrociate con gli ingredienti; riepilogo del giorno e della settimana (energia, macronutrienti, fibre, sale, zuccheri, acqua) sui riferimenti del board; vista "alimentazione e valori" con diario e osservazioni sulla stessa linea del tempo (peso, glicemia, pressione, lipidi, HbA1c, transaminasi); report settimanale ed export |

**v2 — medici, second opinion, dispositivi**

| Modulo | Funzionalità |
| --- | --- |
| M9 | Account medico con verifica dell'Ordine e piano Pro; scheda estesa (disponibilità, prezzo, durata, cosa portare, recensioni); claim del profilo; lista pazienti con alert; dashboard web full HD; note cliniche; agenda personale; gestione cure, prezzi, risposta alle recensioni; permessi granulari in 2 passi; invito medico → paziente con scope, audit e revoca; chat; teleconsulto video; storico telemedicina; prenotazione con slot, conferma, promemoria, cancellazione; appuntamenti in home e nel calendario di sistema; prescrizioni e ricette caricate dal medico; vetrina consulti; triage leggero e assistente "che cosa vuoi fare?"; televisite a consumo; soglie personalizzate per tutti i propri pazienti o per uno solo, con motivazione, validità e limiti di sicurezza del board, mostrate accanto al riferimento istituzionale; storico dei valori e degli organi del paziente nella dashboard con le proprie soglie evidenziate; note cliniche su valori, organi e pasti |
| M10 | Second opinion completa: richiesta, dossier, pagamento Stripe, assegnazione, parere strutturato, follow-up, valutazione, payout |
| M11 | Apple Health e Health Connect; Garmin Health API; Fitbit, Oura, Xiaomi, Withings; misuratori di pressione, bilance e glucometri Bluetooth (ISO/IEEE 11073); aggregatori Validic, Thryve, Glooko; sonno, HRV, stress, respirazione, attività, temperatura; FSE e portali laboratori |
| M1, M4 | Modalità gravidanza; controllo interazioni tra farmaci con fonte validata dal board (nuova) |
| M14 | Studio autore per i professionisti Pro: corsi con video su Cloudflare Stream, trascrizione e sottotitoli automatici marcati come IA, bozza del quiz dall'IA approvata dall'autore, fonti obbligatorie per lezione, controlli automatici anti-promozione, revisione del board, prezzo entro le fasce, vendita con acquisto in-app (RevenueCat) e Stripe sul web, quota autore standard fissata dall'admin e modificabile autore per autore, payout mensile con Stripe Connect, domande all'autore moderate, statistiche aggregate |
| M15 | Alimentazione con il professionista (medico dietologo, dietista, biologo nutrizionista verificati): scope "nutrizione" nel legame, piano alimentare con target per nutriente e schema dei pasti, diario condiviso con commenti sui pasti, avvisi di aderenza, revisione settimanale in una pagina, prestazione a consumo con Stripe |

**v3 — strutture, ospedali, B2B**

| Modulo | Funzionalità |
| --- | --- |
| M13 | Ruoli di struttura (admin, medico, segreteria); agenda di struttura con stati, sovrapposizioni, buffer; workflow visita fino al no-show; audit di eventi, consensi e modifiche; reporting operativo (no-show, tempi, saturazione, conversioni); automazioni pre e post visita; multi-sede; reparti e ambulatori; dashboard struttura sulle proprie cure e medici; licenze B2B; campagne di prevenzione per aziende; reportistica B2B; partnership con associazioni e cliniche; telemonitoraggio domiciliare con alert alla struttura; ponte FHIR verso la cartella clinica ospedaliera (se il board lo approva); dati pseudonimizzati per la ricerca (se approvato) |
| M11 | Kit dispositivi ufficiale; negozio e ordini |

**Parcheggiato e lasciato**: badge, obiettivi, sfide e mindfulness restano parcheggiati fino a dopo la v2; Academy, nutrizione e riconoscimento delle foto dei pasti sono entrati come M14 e M15; blockchain, MedED Coin, VR/AR, FAB centrale e doppia bottom bar sono fuori.

## 8. Funzionalità consigliate in più

Queste non stanno in nessun documento di contesto: le propongo perché chiudono il cerchio della prevenzione (consiglio → esame fatto → referto caricato) e tolgono attrito al medico, che è il punto dove le app di salute di solito muoiono. Costo stimato in giorni di sviluppo con Dreamflow, da confermare prompt per prompt.

| Funzionalità | Perché serve | Release | Costo |
| --- | --- | --- | --- |
| Calendario della prevenzione per età e genere: screening raccomandati (cervice, mammella, colon-retto, pressione, lipidi, glicemia, vista, udito, vaccini dell'adulto) con scadenze e promemoria, fonti validate dal board | È la definizione operativa di "standard per la prevenzione": ogni utente sa sempre qual è il prossimo esame e perché | v1 | 3 giorni |
| "Ho fatto l'esame": ogni esame consigliato ha un bottone che apre la fotocamera; il referto caricato chiude la raccomandazione e aggiorna stato e rischi | Chiude il ciclo consiglio → azione → dato; oggi nessuna app lo misura | v1 | 1 giorno |
| Condivisione dossier con codice a 6 cifre e PIN, senza account per il medico, scadenza 7 giorni, log delle aperture | Il medico non installa niente: apre un link, vede il dossier, ha finito. Senza questo, la parte medici non parte | v1 | 2 giorni |
| Spiegazione a due livelli: "come a un amico" e "come a un medico", stesso dato | Il paziente capisce, il medico non perde tempo con testi semplificati | v1 | 1 giorno |
| Scheda emergenza ICE: gruppo sanguigno, allergie, farmaci, contatti, QR stampabile e widget sul blocco schermo | Valore immediato, costo nullo, richiesto dalla scheda SOS già presente nell'app | v1 | 1 giorno |
| Rilevazione duplicati e versioni dello stesso referto (hash e data) | Evita di contare due volte lo stesso esame nelle tendenze e nei rischi | v1 | 1 giorno |
| Export FHIR R4 e "porta via i tuoi dati" in un tap | Portabilità GDPR oggi, EHDS dal 2029: chi la offre per primo diventa lo standard | v1 | 2 giorni |
| Pre-visita: dal dossier, una pagina con sintesi in 10 righe, cosa portare, domande da fare | Trasforma una visita di 15 minuti in una visita utile; piace ai medici | v1.5 | 2 giorni |
| Promemoria di ripetizione letti dal referto ("controllo tra 6 mesi") | L'estrazione legge già la frase: basta creare la raccomandazione | v1.5 | 1 giorno |
| Modalità caregiver: testi grandi, un'azione per schermata, alert critical inoltrati al familiare | Anziani e famiglie sono metà del mercato Family | v1.5 | 3 giorni |
| Passaporto sanitario multilingua: dossier in inglese o nella lingua del Paese, unità convertite | App mondiale: un referto italiano letto a Londra o Dubai | v1.5 | 2 giorni |
| Widget iOS e Android: stato di salute e prossimo esame | Riporta nell'app ogni giorno senza notifiche invadenti | v1.5 | 2 giorni |
| Medico ospite: dal link del dossier il medico lascia un appunto firmato che torna nell'archivio del paziente | Primo passo verso l'account medico senza chiedergli di registrarsi | v1.5 | 2 giorni |
| Annotazioni automatiche sulle serie storiche: inizio o cambio di un farmaco, visita, cambio di schema alimentare compaiono come eventi sul grafico del valore | Spiega un cambiamento senza cercarlo in tre schermate diverse | v1.5 | 1 giorno |
| Controllo prudente tra ingredienti riconosciuti nel piatto e allergie o intolleranze del profilo ("potrebbe contenere") | Allergie e diario parlano la stessa lingua; il profilo salute esiste già | v1.5 | 2 giorni |
| Attestato di completamento di un corso dell'Academy in PDF, archiviato nel dossier | Chiude il corso con qualcosa da mostrare al medico o al datore di lavoro | v1.5 | 1 giorno |
| Controllo interazioni tra farmaci e allergie, con fonte validata dal board e nessun calcolo di dose | Riduce il rischio più comune nei pazienti con più farmaci; attenzione alla regola Apple 1.4.2 sui calcolatori di dose, che qui non entrano | v2 | 5 giorni |
| Second opinion sulle diagnosi (sezione 9) | Il servizio a più alto valore percepito e a più alto margine | v2 | 15 giorni |
| "Chiedi una soglia": dalla scheda di un valore il paziente chiede al medico curante di rivedere la soglia, con il grafico allegato | Rende visibile la personalizzazione delle soglie e avvia il dialogo invece di un'email | v2 | 1 giorno |
| Report settimanale "alimentazione e valori" in una pagina, condiviso con il professionista in un tap | Il dietista legge una pagina, non 21 pasti | v2 | 2 giorni |
| Import da portali dei laboratori: incolla il link o il QR del referto, l'app scarica il PDF | In Italia quasi tutti i laboratori consegnano via portale: elimina il passaggio foto | v2 | 5 giorni |
| Prevenzione aziendale: campagne di screening per dipendenti con dati aggregati e anonimi verso l'azienda | Entrata B2B con costo di acquisizione quasi nullo | v3 | 10 giorni |

## 9. Second opinion sulle diagnosi

Flusso: 1 Richiesta (specialità e livello, 72 o 24 ore) → 2 Snapshot (dossier e domande, copia congelata) → 3 Pagamento (Stripe, autorizzato, non ancora addebitato) → 4 Assegnazione (specialista dell'albo, parte lo SLA) → Servono integrazioni? sì: il paziente integra e lo SLA si ferma, torna al passo 2; no → 5 Parere (modello strutturato, limiti e consigli) → 6 Consegna (PDF nel dossier, 1 follow-up incluso) → 7 Chiusura (valutazione, addebito, payout 75% al medico). Parere scritto di un medico iscritto all'albo: non sostituisce la visita; le urgenze sono escluse al triage.

La second opinion è un parere scritto di uno specialista verificato sulla documentazione del paziente, consegnato in 72 ore (24 nella versione urgente), pagato solo alla consegna. Non è una visita e non la sostituisce: lo dice il consenso, lo dice il parere, lo dice ogni schermata.

**Che cosa riceve il paziente**: un parere strutturato in cinque parti fisse. 1) Sintesi del caso come lo ha letto lo specialista. 2) Valutazione della documentazione: completa, parziale, insufficiente. 3) Concordanza o discordanza con la diagnosi o il piano in corso, con le ragioni. 4) Suggerimenti: esami da aggiungere, domande da fare al curante, opzioni da discutere. 5) Limiti del parere e quando serve una visita. In fondo: nome, specialità, numero di iscrizione all'Ordine dello specialista, data, firma.

**Ruoli e regole**

| Chi | Fa | Non fa |
| --- | --- | --- |
| Paziente | Sceglie specialità e livello, scrive le domande, paga, valuta, può fare una domanda di follow-up entro 7 giorni | Non riceve prescrizioni né diagnosi nuove |
| Specialista | Accetta entro 12 ore o passa, legge lo snapshot, chiede integrazioni una volta sola, scrive il parere con il modello, risponde al follow-up | Non vede il resto del dossier né i dati dopo la consegna; non contatta il paziente fuori piattaforma |
| Piattaforma | Verifica lo specialista (albo, documento, assicurazione RC), congela lo snapshot, misura lo SLA, trattiene il pagamento fino alla consegna, paga il medico con Stripe Connect, archivia il parere nel dossier | Non interviene nel contenuto clinico; non assegna a specialisti senza assicurazione |
| Board | Definisce il modello di parere, le specialità ammesse, il triage di esclusione delle urgenze, l'audit a campione dei pareri | — |

**Triage di esclusione** (prima del pagamento): sintomi acuti in corso, dolore toracico, dispnea, sanguinamento, ideazione suicidaria, bambini sotto i 2 anni, gravidanza con sintomi: la richiesta non parte e l'app rimanda al 112 o al curante.

**Livelli e tempi**: base 72 ore (una specialità, fino a 20 documenti), complessa 72 ore (caso oncologico o più specialità, fino a 50 documenti, due specialisti), urgente 24 ore (+50%). Se lo SLA salta, rimborso del 50% automatico. Prezzi nella sezione 17.

**Perché funziona per il medico**: lo snapshot arriva già ordinato (stato, valori fuori range, trend, documenti per data), il modello di parere si compila in 30–45 minuti, il pagamento è certo e la responsabilità è chiara. Il 75% di 249 € per 40 minuti di lavoro è la ragione per cui gli specialisti migliori restano sulla piattaforma.

**Responsabilità e contratti**: contratto specialista ↔ piattaforma (servizio reso al paziente, intermediazione, fatturazione), assicurazione RC professionale caricata e verificata, consenso del paziente alla prestazione a distanza con informativa secondo le Indicazioni nazionali per la telemedicina, classificazione giuridica del parere scritto da confermare con il legale sanitario prima del P14.

## 10. Academy e formazione

L'Academy è la scuola dentro l'app: corsi brevi su come leggere i propri esami, sulla prevenzione e sulle condizioni croniche, scritti dal board scientifico in v1.5 e, dal v2, dai medici e dai professionisti verificati. Ogni lezione cita le sue fonti; ogni corso è legato agli articoli della wiki, alle schede organo e ai rischi, così chi ha una patologia trova nello stesso posto la spiegazione breve (wiki) e il percorso completo (corso). Non è formazione ECM e non sostituisce una visita.

**Che cosa contiene un corso**

| Elemento | Regola |
| --- | --- |
| Autore | Board scientifico o Tattica Web con il board (v1.5); medico o professionista con account Pro verificato (v2); ogni corso ha un autore responsabile con nome, specialità e numero di iscrizione all'Ordine o all'albo |
| Destinatari | Paziente, caregiver o professionista: il corso dichiara il suo pubblico e il linguaggio si adegua |
| Struttura | Da 3 a 12 lezioni di massimo 15 minuti: video, testo con immagini, quiz di verifica; la prima lezione è sempre gratuita in anteprima |
| Fonti | Almeno una fonte per lezione (linea guida, articolo con DOI o PubMed, sito istituzionale) in `content_references`; prima dell'invio al board l'IA segnala le affermazioni senza fonte |
| Argomenti | Condizioni, biomarcatori, organi, famiglie di rischio, prevenzione, stili di vita, alimentazione; tag dallo stesso catalogo della wiki |
| Lingua e sottotitoli | Italiano o inglese; trascrizione e sottotitoli generati dall'IA, marcati come tali e corretti dall'autore |
| Prezzo | Gratuito (prevenzione e lettura degli esami), incluso in Plus, oppure a pagamento singolo entro fasce fissate dalla piattaforma (9,90–49,90 €, ipotesi) |
| Stato e versione | draft → in_review → published → retired; ogni modifica di contenuto crea una versione; revisione obbligatoria ogni 12 mesi o quando cambia la linea guida citata |

**Flusso di pubblicazione**

1. L'autore crea il corso nello studio sul web: lezioni, video caricati con upload diretto firmato su Cloudflare Stream, testo, quiz, fonti.
2. Controlli automatici: formato delle fonti, durata, assenza di prezzi, offerte e nomi di prodotti nel testo, lista di frasi che implicano diagnosi o terapia individuale.
3. Revisione del board con una checklist: fonti pertinenti e aggiornate, nessun consiglio terapeutico individuale, nessuna promozione di farmaci, integratori, prodotti o della propria attività (sezione 13), linguaggio chiaro, disclaimer presente. Esito: pubblicato, da correggere o respinto con motivo.
4. Pubblicazione con versione: il corso compare negli articoli della wiki collegati, nelle schede organo e rischio sotto "Impara" e in "Per te".
5. Revisione periodica; ritiro con avviso agli iscritti, che conservano le lezioni completate.

**Chi fa cosa**

| Chi | Fa | Non fa |
| --- | --- | --- |
| Paziente o caregiver | Sceglie i corsi, segue le lezioni, fa i quiz, scarica l'attestato di completamento, fa una domanda all'autore (moderata), valuta il corso | Non riceve consigli individuali: per quelli c'è il medico |
| Autore (board o professionista Pro) | Scrive e aggiorna il corso, cita le fonti, risponde alle domande in forma generale, vede statistiche aggregate (iscritti, completamento, valutazioni) | Non vede chi sono gli iscritti né i loro dati clinici; non promuove servizi, prodotti o la propria attività nel corso |
| Board scientifico | Approva e versiona ogni corso, fissa la checklist e gli argomenti prioritari, scrive i corsi fondativi | — |
| Piattaforma | Ospita i video, misura, vende, paga gli autori, modera le domande, ritira i corsi segnalati | Non modifica i contenuti clinici senza l'autore |

**Legame con wiki e profilo**: ogni articolo della wiki (M7) elenca i corsi collegati e ogni corso i suoi articoli; dalla scheda organo e dalla scheda rischio il bottone "Impara" apre il corso pertinente; "Per te" propone corsi in base a condizioni dichiarate, rischi e organi in attenzione con una regola del board, non con l'IA; il medico curante consiglia un corso a un paziente dal dossier e il consiglio compare in home come raccomandazione.

**Monetizzazione e regole degli store**: i corsi sono contenuto digitale fruito nell'app, quindi su iOS e Android si vendono solo con acquisto in-app (regola Apple 3.1.1): prodotti non consumabili in RevenueCat, con la commissione dello store del 15% o 30%; sul web con Stripe allo stesso prezzo; un acquisto sblocca il corso su tutte le piattaforme (Apple 3.1.3 b). I corsi inclusi in Plus pagano gli autori da un fondo mensile ripartito sui minuti visti. Quota autore standard 70% del netto dopo le commissioni, impostata dall'admin in platform_settings e modificabile autore per autore in author_terms (la quota in vigore al momento dell'acquisto resta scritta sul pagamento), payout mensile con Stripe Connect; diritto di recesso di 14 giorni salvo rinuncia espressa all'avvio del corso, come per i contenuti digitali nell'UE. Costo video: Cloudflare Stream a 5 $ al mese ogni 1.000 minuti archiviati e 1 $ ogni 1.000 minuti erogati, cioè circa 0,10 € per iscritto a un corso di 90 minuti.

**Che cosa non è**: non dà crediti ECM (servirebbe un provider accreditato da AGENAS: decisione per la v3); non è un consulto; non ospita pubblicità né contenuti sponsorizzati; nessun corso generato interamente dall'IA viene pubblicato.

## 11. Alimentazione e diario alimentare

Il modulo M15 è il diario alimentare che si tiene davvero: una foto del piatto, un codice a barre o una ricerca bastano per registrare un pasto, e il diario parla con il resto dell'app: con i valori (peso, glicemia, lipidi, transaminasi), con le allergie del profilo e, dal v2, con il professionista della nutrizione che segue la persona. Non prescrive diete: mostra, confronta e passa la mano al professionista.

**Come si registra un pasto**

| Modo | Che cosa succede | Chi conferma |
| --- | --- | --- |
| Foto del piatto | Il motore (sezione 6) riconosce piatti e porzioni con una confidenza; l'utente conferma o corregge le porzioni con tre taglie e un cursore | Utente, sempre |
| Codice a barre | Lettura del prodotto da Open Food Facts (licenza ODbL, con attribuzione) e dal catalogo; porzione da scegliere | Utente |
| Ricerca | Catalogo `food_catalog` da CREA, USDA FoodData Central e alimenti inseriti dai professionisti, con sinonimi e porzioni tipiche | Utente |
| Manuale e ricette | Alimenti e quantità a mano; ricette salvate e ripetibili; pasti frequenti in un tap | Utente |
| Acqua, note e sintomi | Bicchieri d'acqua, sazietà, note, sintomi dopo il pasto (gonfiore, reflusso, mal di testa) che finiscono anche in `symptoms` | Utente |

**Profilo alimentare**: schema scelto dall'utente (onnivoro, vegetariano, vegano, pescetariano, mediterraneo, senza glutine, senza lattosio, halal, kosher, altro); allergie e intolleranze lette dal profilo salute; obiettivo (mantenere, cambiare peso con il professionista, controllo della glicemia, salute cardiovascolare); riferimenti per energia e nutrienti calcolati dalle regole del board su età, genere, peso, altezza e attività (fonte LARN V revisione della SINU, 2024, versionata in `rule_versions`); controllo di coerenza con lo schema: un alimento di origine animale in uno schema vegano viene segnalato, non bloccato.

**Che cosa mostra**: riepilogo del giorno e della settimana (energia, proteine, carboidrati, grassi, fibre, zuccheri, sale, acqua) confrontato con i riferimenti; distribuzione dei pasti; giorni registrati; la vista "alimentazione e valori" mette sulla stessa linea del tempo il diario e le osservazioni (peso, circonferenza vita, glicemia e HbA1c, pressione, colesterolo e trigliceridi, uricemia, transaminasi e gamma GT), così la persona e il medico vedono insieme che cosa è cambiato e quando; report settimanale in PDF; export CSV.

**Con il professionista (v2)**

- Professionisti ammessi: medico dietologo, dietista (albo TSRM-PSTRP) e biologo nutrizionista (Ordine dei biologi), verificati come i medici; gli ambiti di ciascuno (chi può elaborare una dieta per una patologia) li fissa il legale sanitario prima del P12.
- Scope "nutrizione" nel legame professionista-paziente: senza quello scope il diario non si vede, anche con legame attivo.
- Piano in `nutrition_plans`: schema, target per nutriente che sovrascrivono i riferimenti (stesso meccanismo delle soglie personalizzate, sezione 12), schema dei pasti, alimenti da preferire e da evitare, durata; il paziente vede sempre anche il riferimento del board.
- Diario condiviso: il professionista legge pasti e foto, commenta un pasto in `doctor_notes`, riceve un avviso di aderenza settimanale, apre la vista "alimentazione e valori" e il report in una pagina.
- Prestazione a consumo (prima visita, piano, controlli) pagata con Stripe fuori dall'acquisto in-app (regola Apple 3.1.3 d), 85% al professionista come la televisita.

**Guardrail**

- Nessun obiettivo di energia sotto i minimi di sicurezza fissati dal board, nemmeno su richiesta; una richiesta ripetuta di obiettivi molto bassi apre un messaggio neutro e il rimando al professionista.
- Linguaggio neutro: niente punteggi sul peso, niente badge, niente "sgarri"; i grafici del peso mostrano tendenze, non voti.
- Per i profili dei minori il diario si attiva solo dal tutore e senza obiettivi di peso.
- Il riconoscimento dalle foto è un aiuto: i totali del giorno si calcolano solo sui pasti confermati.
- Il controllo allergie dice "potrebbe contenere", mai "è sicuro".
- Nessuna diagnosi: intolleranze e disturbi si discutono con il medico; l'app registra e mostra.

**Dati**: foto nel bucket del soggetto con EXIF e posizione rimossi; opzione "conserva solo i nutrienti" che cancella le foto dopo 90 giorni; modulo attivabile e disattivabile dalle impostazioni con cancellazione di tutto il diario; catalogo alimenti con fonte e licenza per riga; Free fino a 3 foto al giorno, Plus senza limiti (sezione 17).

## 12. Interfaccia con medici e strutture

Il medico entra in tre passi, uno per release: in v1 riceve un dossier senza registrarsi, in v2 ha un account e una lista pazienti, in v3 la sua struttura ha un backoffice. A ogni passo la regola è la stessa: il paziente decide chi vede cosa e per quanto tempo, e ogni accesso finisce nel registro.

**Chi vede cosa**

| Ruolo | Vede | Può fare | Da |
| --- | --- | --- | --- |
| Paziente | Tutto il proprio dossier e quello dei familiari delegati, con lo storico di ogni valore e di ogni organo | Caricare, condividere, revocare, chiedere, prenotare, pagare, seguire i corsi, tenere il diario alimentare | v1 |
| Medico ospite (senza account) | Il dossier del link: stato, rischi, esami, documenti nello scope, per 7 giorni | Leggere, scaricare il PDF, dal v1.5 lasciare un appunto firmato | v1 |
| Medico con account (Pro) | I pazienti che lo hanno invitato o accettato, nello scope concesso, con gli stessi grafici dello storico che vede il paziente | Lista pazienti con alert, note cliniche, risposte, chat e video, prescrizioni, agenda, gestione cure e recensioni; soglie personalizzate per i propri pazienti; consigliare un corso; pubblicare corsi come autore | v2 |
| Professionista della nutrizione (Pro, scope nutrizione) | Diario alimentare, profilo alimentare e vista "alimentazione e valori" dei pazienti collegati | Piano alimentare con target, commenti sui pasti, avvisi di aderenza, report settimanale | v2 |
| Specialista second opinion | Solo lo snapshot del dossier della richiesta assegnata | Chiedere integrazioni, scrivere il parere, rispondere a un follow-up | v2 |
| Struttura: admin, medico, segreteria | Agenda, pazienti e cure della struttura, nei limiti del ruolo | Agenda, workflow visita, automazioni, reporting, multi-sede | v3 |
| Board scientifico | Catalogo, regole, testi, corsi, riferimenti nutrizionali, limiti di sicurezza delle soglie | Approvare e versionare | v1 |
| Admin piattaforma | Metadati, verifiche, moderazione, metriche; mai i contenuti clinici in chiaro senza motivo registrato | Verificare medici, professionisti e strutture, moderare, sospendere; impostare in platform_settings quote, prezzi, commissioni e limiti, e la quota di un singolo autore in author_terms | v1 |

**v1: dossier e domande**

- Il dossier è una pagina sola: stato di salute, 8 rischi con livello, organi in attenzione, ultimi valori fuori range con trend, esami consigliati, documenti allegati. In PDF e come link.
- Condivisione con codice a 6 cifre e PIN separato (inviato per altro canale), scadenza 7 giorni, scope scelto dal paziente (tutto, solo un organo, solo un periodo), registro delle aperture visibile al paziente.
- Domande asincrone: il paziente scrive al proprio medico (indirizzo email o medico in anagrafica), allega il dossier; la risposta torna nell'app e nell'archivio.

**v2: account medico e telemedicina**

- Verifica del medico: nome, Ordine e numero di iscrizione controllati sull'albo FNOMCeO, documento d'identità, partita IVA o struttura; badge "verificato" solo dopo controllo umano. Stessa verifica, sull'albo di competenza, per dietisti e biologi nutrizionisti.
- Permessi in due passi: il paziente invita (o il medico chiede) → l'altra parte accetta → lo scope è esplicito (categorie, periodo, organi, nutrizione) → revoca in un tap → ogni lettura in `audit_log`.
- Lista pazienti ordinata per alert: il medico vede prima chi ha un valore critical o un esame scaduto.
- Soglie personalizzate: il medico imposta un intervallo diverso per un biomarcatore, per tutti i suoi pazienti o per uno solo, con motivazione e validità; il motore lo usa per alert e stati di quel paziente, il paziente vede la soglia del medico accanto a quella istituzionale, il board fissa i limiti che nessuna soglia può superare (dettaglio qui sotto).
- Storico nella dashboard: per ogni paziente il medico apre gli stessi grafici dello storico per valore e per organo che vede il paziente, con le proprie soglie evidenziate, e lascia note cliniche su un valore, un organo o un pasto.
- Diario alimentare: visibile solo con lo scope nutrizione; piano e commenti come nella sezione 11.
- Chat e teleconsulto video dentro l'app, con registrazione del consenso alla prestazione a distanza; il fornitore video (Daily, 100ms o LiveKit) è una decisione aperta della sezione 23.
- Prenotazione: slot pubblicati dal medico, conferma, promemoria 24 ore prima, regole di cancellazione; l'appuntamento finisce nel calendario del telefono.
- Prescrizioni e ricette: il medico carica il documento nel dossier del paziente, che lo ritrova in Archivio con la categoria giusta.
- Pagamenti: televisite, second opinion e piani nutrizionali con Stripe (servizio uno-a-uno, ammesso fuori dall'acquisto in-app dalla regola Apple 3.1.3 d), abbonamento Pro con RevenueCat, corsi a pagamento con acquisto in-app.

**Soglie personalizzate dal medico (v2)**: tre livelli di riferimento convivono per ogni valore e si vedono sempre insieme; il livello più specifico guida alert e stati, gli altri restano a confronto.

| Livello | Fonte | Chi lo cambia | Vale per | Dove si vede |
| --- | --- | --- | --- | --- |
| Laboratorio | Intervallo stampato sul referto, estratto al passo 3 della pipeline | Nessuno: è un dato del documento | Quel singolo valore | Scheda del valore e storico |
| Istituzionale | `biomarker_catalog` e `rule_versions` del board, per età e genere, con fonte e versione | Board, con versione e nota di cambio visibile all'utente | Tutti | Ovunque, sempre, anche quando esiste una soglia del medico |
| Medico | `threshold_overrides`: intervallo, motivazione obbligatoria, validità, ambito (tutti i propri pazienti o un soggetto) | Medico con legame attivo e scope sul biomarcatore o sull'organo | I pazienti nell'ambito, finché il legame è attivo | Accanto al riferimento istituzionale, con nome del medico e motivo |

Regole: la soglia del medico non può superare i limiti di sicurezza che il board fissa per ogni biomarcatore, quindi un alert critical non si spegne; ogni creazione, modifica e scadenza finisce in `audit_log` e il paziente riceve una notifica neutra; la revoca del legame disattiva le soglie di quel medico e il motore ricalcola; se due medici hanno soglie diverse sullo stesso paziente, il paziente vede entrambe e sceglie il curante di riferimento per gli alert; lo stesso meccanismo governa i target nutrizionali del piano (sezione 11).

**v3: struttura e ospedale (M13)**

- Account di struttura con ruoli admin, medico, segreteria; i medici della struttura restano titolari dei propri pazienti.
- Agenda di struttura con stati visita, sovrapposizioni, buffer, regole di cancellazione; workflow prenotata → confermata → in corso → completata → no-show.
- Automazioni: messaggi pre e post visita, promemoria, follow-up; reporting operativo su no-show, tempi medi, saturazione, conversioni; multi-sede.
- Interoperabilità: export e import FHIR R4 verso la cartella clinica della struttura, se il board approva l'ingresso in ospedale; telemonitoraggio domiciliare con alert alla struttura.

**Che cosa fa risparmiare tempo al medico** (il criterio di ingresso di ogni funzione di questa sezione)

1. Un dossier di una pagina invece di dieci PDF fotografati.
2. I valori fuori range già evidenziati, con il trend accanto.
3. Le domande del paziente arrivano con il contesto allegato.
4. La pre-visita è già scritta.
5. Il parere di second opinion ha un modello strutturato: si compila, non si scrive da zero.

## 13. Norme e compliance

La decisione che pesa di più è una sola: se i rischi per famiglia di patologia e gli esami consigliati fanno di Medical 24 un dispositivo medico. Tutto il resto (GDPR, AI Act, legge italiana, store) è lavoro noto. Date e obblighi qui sotto vengono dalle pagine citate, lette il 20 e il 24 ottobre 2026.

| Norma | Che cosa impone a Medical 24 | Come la rispettiamo | Quando |
| --- | --- | --- | --- |
| GDPR, art. 9 e 35 | Consenso esplicito per i dati sanitari, DPIA obbligatoria, responsabili con contratto, notifica violazioni in 72 ore | Sezione 14: consensi versionati, DPIA prima del lancio, DPA con ogni fornitore, procedura breach | Prima della beta |
| [MDR 2017/745 e MDCG 2019-11](https://openregulatory.com/mdcg/mdcg-2019-11) | È dispositivo medico il software con finalità medica (diagnosi, prevenzione, monitoraggio, predizione); regola 11: informazioni usate per decisioni diagnostiche o terapeutiche = classe IIa o superiore; app di benessere senza claim medici = fuori | Posizionamento v1 come informazione e organizzazione della salute personale, nessuna diagnosi, score pubblici validati presentati come educativi; parere scritto di un consulente regolatorio prima dell'invio agli store (gate G1); architettura pronta per una classe IIa futura (documentazione IEC 62304, rischi ISO 14971); le soglie del medico sono una scelta del medico, non dell'app | Gate G1 |
| [AI Act 2024/1689 e Omnibus](https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/) | Obblighi di trasparenza (art. 50) dal 2 agosto 2026; alto rischio per i sistemi in prodotti dell'allegato I (dispositivi medici) dal 2 agosto 2028 secondo l'accordo provvisorio del 6 maggio 2026, in attesa di pubblicazione in Gazzetta UE | Ogni testo generato dall'IA è marcato come tale, sottotitoli e bozze dei quiz compresi; informativa sull'uso dell'IA; nessun sistema ad alto rischio finché l'app non è dispositivo medico; se lo diventa, piano di conformità entro il 2028 | v1, poi 2028 |
| [Legge 132/2025](https://www.ictsecuritymagazine.com/notizie/legge-italiana-sullintelligenza-artificiale/) (in vigore dal 10 ottobre 2025) | Art. 7: in sanità l'IA è supporto, la decisione resta sempre ai medici; art. 13: nelle professioni l'IA solo per attività strumentali e di supporto, con [informazione al cliente in linguaggio chiaro](https://www.quotidianosanita.it/lavoro-e-professioni/in-vigore-la-legge-sull-ai-medico-obbligato-a-informare-il-paziente-se-ne-fa-uso/); art. 10: piattaforma nazionale IA presso AGENAS | L'app non decide mai; i medici sulla piattaforma hanno un testo pronto per informare i pazienti; export FHIR pronto per la futura piattaforma AGENAS | v1 |
| [Decalogo del Garante sull'IA in sanità](https://www.quotidianosanita.it/?p=129232) (ottobre 2023) | Trasparenza dei processi decisionali, supervisione umana, non discriminazione algoritmica, qualità dei dati, DPIA centrale | Regole deterministiche pubblicate e versionate dal board; spiegazione della logica per ogni rischio; verifica periodica di bias per età, genere, origine dei dati | v1 |
| [EHDS, Regolamento 2025/327](https://healthcarelifesciences.bakermckenzie.com/?p=967) | In vigore dal 26 marzo 2025; atti di esecuzione entro marzo 2027; diritti di accesso e portabilità dal marzo 2029; le app di benessere potranno dichiarare l'interoperabilità con le componenti dei sistemi EHR | Export e import FHIR R4 dal v1; candidatura all'etichetta di interoperabilità quando gli atti saranno pubblicati | v1, poi 2027–2029 |
| [Indicazioni nazionali per la telemedicina](https://www.lcalex.it/wp-content/uploads/2020/12/Indicazioni-nazionali-per-la-telemedicina.pdf) (Conferenza Stato-Regioni, 17 dicembre 2020) | La televisita è un atto sanitario con piena responsabilità del medico; serve adesione preventiva del paziente dopo informativa; sconsigliata per patologie acute e pazienti fragili | Consenso alla prestazione a distanza registrato per ogni televisita, second opinion e piano nutrizionale; triage di esclusione delle urgenze con rimando al 112; il medico è sempre identificato e verificato | v2 |
| Codice di deontologia medica (FNOMCeO) | Telemedicina, pubblicità sanitaria, rapporto con le recensioni | Profili medici verificati sull'albo, recensioni moderate con diritto di replica, nessuna classifica a pagamento | v1 cure, v2 medici |
| [Informazione sanitaria e pubblicità](https://odmeo.re.it/wp-content/uploads/2025/03/Documentazione-normativainformazionesanitaria-agg20-2-2025.pdf): L. 248/2006 art. 2; L. 145/2018 art. 1 c. 525 come modificato dal D.L. 69/2023; Codice di deontologia artt. 55–57 | Le comunicazioni dei professionisti e delle strutture possono contenere solo informazioni funzionali a scelte sicure, senza elementi attrattivi o suggestivi, offerte, sconti o promozioni; vigilanza degli Ordini con segnalazione ad AGCOM | Corsi dell'Academy, profili e schede cura con contenuto informativo e fonti; revisione del board; nessuna promozione di prodotti, farmaci o della propria attività, nessuna offerta; checklist anti-promozione nel flusso di pubblicazione | v1 cure, v1.5 Academy |
| D.Lgs. 219/2006, artt. 115–116 | Vietata la pubblicità al pubblico dei medicinali con obbligo di prescrizione | Corsi, wiki e schede cura parlano di classi e principi in forma informativa, mai di prodotti con invito all'uso; filtro nel controllo automatico dei corsi | v1.5 |
| [Apple App Review Guidelines](https://developer.apple.com/support/downloads/terms/app-review-guidelines/App-Review-Guidelines-English-UK.pdf) | 1.4.1: le app mediche sono esaminate con più rigore, devono ricordare di consultare un medico e non possono misurare parametri con i soli sensori; 3.1.1: abbonamenti e contenuti digitali, corsi compresi, solo con acquisto in-app; 3.1.3(b): un acquisto fatto sul web può essere sbloccato nell'app; 3.1.3(d): i servizi uno-a-uno in tempo reale, consulti medici compresi, possono pagare fuori dall'app; 5.1.3: dati sanitari mai per pubblicità né ceduti a terzi, mai in iCloud, mai dati falsi in HealthKit, ricerca solo con consenso e comitato etico | Plus, Family e corsi singoli con RevenueCat; televisite, second opinion e piani nutrizionali con Stripe; nessuna pubblicità; nessun backup iCloud dei dati sanitari; disclaimer su ogni schermata clinica | v1, corsi v2 |
| [Google Play, politica app sanitarie](https://support.google.com/googleplay/android-developer/answer/16555673) | Modulo di dichiarazione per le app sanitarie; i dati da Health Connect sono dati personali sensibili; privacy policy pubblica e completa; permessi solo se necessari | Dichiarazione compilata; permessi Health Connect solo in v2 e solo per i tipi usati | v1, v2 |
| [Licenze dei dati alimentari](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorials/license-be-on-the-legal-side/): Open Food Facts (ODbL e DbCL, immagini CC BY-SA), CREA, USDA FoodData Central | Attribuzione, condivisione allo stesso modo delle banche dati derivate, termini d'uso dell'API | Attribuzione nelle schermate del diario, catalogo con fonte e licenza per riga, nessuna rivendita dei dati, verifica del legale sui termini CREA | v1.5 |
| Formazione continua (ECM, AGENAS) | I crediti ECM si rilasciano solo tramite provider accreditati | L'Academy rilascia attestati di completamento, non crediti ECM; accreditamento come provider da valutare in v3 | v1.5, v3 |
| [FTC Health Breach Notification Rule](https://www.ftc.gov/business-guidance/blog/2024/04/updated-ftc-health-breach-notification-rule-puts-new-provisions-place-protect-users-health-apps) (USA) | Vale per le app sanitarie non coperte da HIPAA; la divulgazione non autorizzata è una violazione; avviso agli utenti entro 60 giorni e alla FTC se oltre 500 persone | Stessa procedura breach della sezione 14 con il canale FTC; HIPAA e BAA solo se un cliente B2B statunitense lo richiede | Apertura USA |
| European Accessibility Act (da verificare con il legale) | Servizi digitali ai consumatori accessibili | WCAG 2.1 AA, font dinamico, contrasto, VoiceOver e TalkBack testati; sottotitoli su ogni video dei corsi | v1 |
| DAC7 e fiscalità dei payout (da verificare con il commercialista) | Comunicazione dei compensi pagati a medici e autori tramite piattaforma | Stripe Connect con raccolta dei dati fiscali di medici e autori | v2 |

**La decisione sul dispositivo medico, spiegata**

Secondo MDCG 2019-11 conta l'intended purpose dichiarato: etichette, istruzioni, marketing. Se Medical 24 dice "ti dico se sei a rischio di diabete" sta facendo predizione a beneficio del singolo paziente, e un regolatore può leggerla come finalità medica (classe IIa per la regola 11). Se dice "ti mostro il tuo FINDRISC, un calcolatore pubblico, e ti ricordo gli screening raccomandati per la tua età" sta organizzando informazione già pubblica. La linea di v1 è la seconda, e va scritta così in ogni testo. Il board e il consulente regolatorio firmano il posizionamento al gate G1; se la risposta è "dispositivo", il modulo M6 esce dalla v1 e rientra come modulo certificato, senza toccare il resto.

## 14. Gestione dati e privacy

I dati di Medical 24 sono quasi tutti "categorie particolari" (art. 9 GDPR): la regola è trattarli con consenso esplicito, tenerne il meno possibile, cifrarli, tenerli in Europa e saperli cancellare. Tattica Web è titolare del trattamento; Supabase, Anthropic, RevenueCat, Stripe, Cloudflare (Stream e Pages) e i fornitori push sono responsabili con contratto art. 28.

**Consensi** (tabella `consents`, append-only, testo versionato)

| Consenso | Base giuridica | Quando | Revoca |
| --- | --- | --- | --- |
| Trattamento dei dati sanitari per il servizio | Art. 9.2.a, consenso esplicito | Onboarding, prima del primo documento | Chiude il servizio: export e cancellazione |
| Elaborazione IA dei documenti e delle foto dei pasti (Claude API, responsabile del trattamento) | Art. 9.2.a + informativa sull'uso dell'IA (L. 132/2025, art. 13) | Onboarding, voce separata | Resta l'archivio, si fermano analisi, riconoscimento dei pasti e spiegazioni |
| Condivisione con un medico o un professionista | Art. 9.2.a, per singolo link o legame, con lo scope (nutrizione compresa) | A ogni condivisione | Revoca del link, del legame o del solo scope |
| Diario alimentare e foto dei pasti | Art. 9.2.a, dentro il consenso sanitario, con attivazione separata del modulo | Prima attivazione del diario | Disattivazione del modulo con cancellazione del diario e delle foto |
| Profili familiari | Consenso del tutore o delega dell'adulto | Creazione del profilo | Cancellazione del profilo |
| Contenuti dell'Academy pubblicati da un autore (voce, immagine, testi) | Contratto d'autore e liberatoria (art. 6.1.b) | Apertura dello studio autore | Ritiro del corso; gli iscritti conservano le lezioni completate |
| Marketing e comunicazioni | Art. 6.1.a | Opzionale, mai in bundle | In ogni momento |
| Ricerca con dati pseudonimizzati | Da decidere con legale e board (art. 9.2.j e art. 8 L. 132/2025) | Solo se approvato, separato | In ogni momento |

**Minimizzazione e conservazione**

- Si estrae dal documento solo ciò che serve al modello dati; il testo OCR completo resta cifrato nello Storage, non nel database.
- Nessun dato sanitario nei log applicativi, negli eventi analytics, nelle notifiche push (il testo della push dice "hai un nuovo avviso", mai il valore; "il tuo medico ha aggiornato una soglia", mai quale).
- Claude API riceve il documento o la foto del pasto e restituisce JSON; non viene usato per addestrare modelli e i dati non vengono conservati dal fornitore oltre il necessario, da fissare nel contratto (DPA) e nell'informativa.
- Foto dei pasti e dei documenti senza EXIF e posizione; opzione che conserva solo i nutrienti e cancella le foto dei pasti dopo 90 giorni; nessun volto cercato o riconosciuto nelle foto.
- I video dei corsi stanno su Cloudflare Stream, separati dai dati clinici, con token firmati; chi segue un corso non è visibile all'autore se non come numero.
- Conservazione: finché l'account esiste; dopo la cancellazione, purge a 30 giorni; backup cifrati con rotazione a 35 giorni; audit log 24 mesi.
- Analytics di prodotto solo con eventi senza contenuto clinico ("documento caricato", "pasto registrato", non "glicemia 120").

**Residenza e trasferimenti**

- Utenti EU: progetto Supabase in regione EU (Francoforte), Storage EU, backup EU.
- Utenti extra EU: secondo progetto Supabase nella regione più vicina (US East per le Americhe) con lo stesso schema; l'utente sceglie la regione all'iscrizione e non la cambia senza migrazione esplicita.
- Fornitori USA (Anthropic, RevenueCat, Stripe, Apple, Google): clausole contrattuali standard e Data Privacy Framework dove disponibile, elencati nell'informativa.

**Diritti dell'utente, eseguibili dall'app senza scrivere a nessuno**

1. Accesso ed export: ZIP con documenti originali, CSV delle osservazioni, JSON FHIR R4, registro dei consensi e degli accessi.
2. Rettifica: ogni valore estratto è modificabile e la modifica resta tracciata.
3. Cancellazione: un tap, conferma con biometria, soft delete immediato, purge a 30 giorni, email di conferma.
4. Limitazione: "pausa analisi" ferma IA e notifiche senza cancellare nulla.
5. Portabilità: l'export FHIR è lo stesso che un altro servizio può importare.
6. Opposizione al marketing: un interruttore.

**Documenti da produrre prima del lancio**: informativa privacy e cookie (app e sito), DPIA (obbligatoria: dati sanitari su larga scala con elaborazione automatica), registro dei trattamenti, DPA con ogni fornitore, procedura di data breach con notifica al Garante entro 72 ore (art. 33) e agli utenti (art. 34), nomina del DPO, informativa sull'uso dell'IA in linguaggio semplice.

## 15. Sicurezza

La sicurezza non è una fase: è la checklist che chiude ogni prompt Dreamflow, come in HB Social 2.0 dopo il caso Baudr. Un prompt senza la checklist non si esegue; un prompt che la viola si rifiuta.

**Checklist da incollare in coda a ogni prompt**

```markdown
SICUREZZA (obbligatoria, non negoziabile):
1. Ogni tabella creata ha RLS attiva e almeno una policy; nessuna tabella resta aperta.
2. Il client usa solo la anon key; la service_role key vive solo nelle Edge Functions come secret.
3. Ogni query di dati clinici passa da can_access_subject(subject_id); nessun filtro "a mano" nel client.
4. Storage: bucket privati, path subjects/{subject_id}/..., policy allineate alle tabelle, signed URL a 10 minuti.
5. Nessun dato sanitario in log, analytics, crash report, notifiche push o URL.
6. Input validati lato server (Edge Function) prima di scrivere; il testo OCR è dato, mai istruzione.
7. Output dell'IA validato contro uno schema JSON e contro gli intervalli plausibili prima del salvataggio.
8. Webhook (RevenueCat, Stripe) verificati con firma e idempotenti.
9. Token in flutter_secure_storage; blocco biometrico; FLAG_SECURE sulle schermate cliniche Android.
10. Nessuna chiave, URL di progetto o secret nel repository o nei prompt successivi.
11. Scrivi i test RLS: un utente estraneo ottiene zero righe da ogni nuova tabella.
12. Audit: ogni lettura di dati clinici da parte di un ruolo diverso dal proprietario scrive in audit_log.
13. Nessuna diagnosi nei testi: ogni schermata clinica porta il disclaimer e il rimando al medico.
14. Al termine elenca le policy create e i test eseguiti.
```

**Controlli di piattaforma**

| Area | Controllo | Dove |
| --- | --- | --- |
| Accesso | RLS su tutte le tabelle, default deny; ruoli nel JWT via auth hook; MFA TOTP obbligatoria per medici, board e admin; sessioni brevi per i ruoli privilegiati | Supabase Auth, Postgres |
| Segreti | Chiavi API in Supabase Vault e nei secret delle Edge Functions; rotazione semestrale; nessun secret nel client Flutter | Supabase |
| Cifratura | TLS 1.2+ in transito; AES-256 a riposo su database, Storage e backup; cifratura di colonna (pgsodium) per scheda emergenza, JSON di estrazione e note cliniche | Postgres, Storage |
| Storage | Bucket privati, signed URL a 10 minuti, antivirus sui PDF caricati, limite 25 MB per file, tipi consentiti PDF, JPG, PNG, HEIC; EXIF e posizione rimossi da ogni foto; video dei corsi su Cloudflare Stream con token firmati a scadenza e download disattivato | Supabase Storage |
| Abuso | Rate limiting su auth, upload ed Edge Functions; captcha sul web; blocco dopo 5 tentativi di PIN di condivisione | Edge Functions, Auth |
| IA | Prompt con ruolo fisso, documento passato come dato, output JSON strutturato, nessuna chiamata a strumenti dal contenuto del documento; validazione di schema e intervalli; log dei token senza contenuto; le foto dei pasti seguono le stesse regole dei referti | Edge Function extract/explain |
| App | Obfuscation Flutter in release, certificate pinning, rilevazione root e jailbreak con avviso, blocco biometrico, FLAG_SECURE, nessuna cache di immagini cliniche fuori dal sandbox | Flutter |
| Web | CSP stretta, HSTS, cookie SameSite, nessuno script inline, header di sicurezza sul sito e sulla web app | Hosting web |
| Supply chain | Dependabot, scansione dei pacchetti pub.dev, lockfile, revisione delle dipendenze trimestrale | CI |
| Ambienti | Tre progetti Supabase: dev, staging, prod; migrazioni versionate; nessun accesso diretto a prod senza ticket | DevOps |
| Backup | PITR 7 giorni e backup giornalieri cifrati a 35 giorni, prova di ripristino trimestrale, obiettivo di ripristino 4 ore | Supabase |
| Test | pgTAP per ogni policy RLS; test end-to-end sul flusso documento → osservazione; pentest esterno prima del lancio e ogni anno; obiettivo OWASP MASVS L2 | CI, fornitore esterno |
| Incidenti | Runbook: rilevare, contenere, valutare, notificare al Garante entro 72 ore e agli utenti, post-mortem pubblico interno; esercitazione semestrale | Team |
| Persone | Accesso ai dati clinici solo con motivo registrato; revisione accessi trimestrale; formazione privacy annuale; NDA e nomina a incaricato per chi entra | Tattica Web |
| Soglie e contenuti | Override di soglia solo da un medico con legame attivo e dentro i limiti di sicurezza del board, con audit e notifica al paziente; corsi pubblicati solo dopo la revisione del board, con controllo automatico anti-promozione; catalogo alimenti scrivibile solo da board, professionisti verificati ed Edge Function; piani nutrizionali mai sotto i minimi del board | Postgres, Edge Functions, pannello board |

## 16. Ottimizzazione

Il costo variabile di Medical 24 è l'IA: ogni documento costa una chiamata, ogni spiegazione un'altra. L'obiettivo è un costo IA per utente Plus sotto il 5% del prezzo dell'abbonamento, misurato ogni mese sui prezzi correnti dell'API; i numeri qui sotto sono obiettivi, non prezzi.

**Costi IA: le otto regole**

1. Testo prima delle immagini: un PDF con layer di testo non passa dalla visione; solo foto e scansioni vanno al modello multimodale.
2. Modello per compito: classificazione del documento e rilevazione duplicati con il modello più piccolo (classe Haiku); estrazione dei referti con il modello medio (classe Sonnet); il modello grande non entra nella pipeline.
3. Una chiamata per documento: l'estrazione produce in un colpo categoria, data, laboratorio, tutti i valori con unità e intervalli, e le frasi di follow-up ("ripetere tra 6 mesi").
4. Spiegazioni in cache: la tabella `explanations` è indicizzata su soggetto, bersaglio, lingua, livello e hash degli input; si rigenera solo quando cambia un input.
5. Batch notturno: le rianalisi non urgenti passano dall'API batch (costo dimezzato) con `pg_cron`; la chiamata immediata esiste solo per il tap "Aggiorna" e per il primo documento di un nuovo utente, che deve vedere il risultato subito.
6. Prompt caching sul prompt di sistema e sul catalogo biomarcatori, che sono sempre uguali.
7. Budget per piano: Free fino a 10 documenti analizzati al mese, Plus e Family uso corretto con soglia di allarme interna; immagini ridotte a 1600 px sul lato lungo prima dell'invio, massimo 20 pagine per documento.
8. Foto dei pasti: una sola chiamata per pasto con il modello medio, immagine a 1024 px, Free fino a 3 foto al giorno; i prodotti con codice a barre non passano dall'IA. Corsi: trascrizione, sottotitoli e bozza del quiz generati una volta sola per versione della lezione, mai a ogni visualizzazione.

**Prestazioni**

| Punto | Scelta |
| --- | --- |
| Home | Una vista materializzata `home_snapshot` per soggetto (stato, score, 8 rischi, prossimi esami, ultimi valori), ricalcolata di notte e a ogni nuovo dato; la home fa una query sola |
| Liste | Paginazione a cursore su documenti e osservazioni; indici su (subject_id, effective_at) e (subject_id, code, effective_at) |
| Immagini | Compressione lato client (HEIC in JPEG 85%), miniature generate dalla Edge Function al caricamento, cache locale cifrata |
| Offline | Archivio e dossier leggibili senza rete (cache locale con Drift); inserimenti manuali in coda e sincronizzati; nessuna analisi offline |
| Realtime | Supabase Realtime solo per lo stato del documento in analisi e per la chat; tutto il resto a richiesta |
| Regioni | Edge Functions e database nella stessa regione; CDN per il sito e per gli asset statici |
| Web | Flutter web con renderer CanvasKit, caricamento differito delle sezioni pesanti (silhouette, grafici) |
| Storico | Vista materializzata per lo storico per biomarcatore e per organo (valori, bande di riferimento a tre livelli, episodi fuori soglia), aggiornata dal batch notturno e dopo ogni analisi; grafici campionati oltre i 500 punti; la vista "alimentazione e valori" legge la stessa vista più i totali giornalieri del diario |
| Video | Cloudflare Stream con HLS adattivo e token firmati; nessun video passa dal backend; miniature e durata lette dal webhook di Stream |

**Osservabilità** (senza mai un dato clinico nei log)

- Sentry per app e Edge Functions con scrubbing dei campi; log Supabase con conservazione 30 giorni.
- Metriche del motore: documenti analizzati al giorno, tasso di successo, distribuzione della confidenza, correzioni manuali per documento, costo IA per documento e per utente, latenza p95, durata del batch notturno, errori per modello.
- Allarmi: batch notturno fallito, tasso di errore oltre il 2%, costo giornaliero oltre il budget, coda di analisi oltre 15 minuti.
- Analytics di prodotto (PostHog in regione EU) con eventi senza contenuto: documento caricato, analisi vista, dossier condiviso, paywall visto, abbonamento attivato.

**Quando crescerà**: partizionamento di `observations` e `audit_log` per mese oltre i 50 milioni di righe; replica di lettura per le dashboard medico e struttura; coda dedicata per l'estrazione se la latenza p95 supera i 60 secondi.

## 17. Modello di business

La prevenzione è gratis, il comfort si paga, il medico paga per il tempo che risparmia, la struttura paga per i pazienti che non perde. Niente pubblicità: la regola Apple 5.1.3 la vieta sui dati sanitari e la fiducia vale più di qualunque CPM. I prezzi sono quelli del Draft v0.1 dove c'erano, ipotesi marcate dove mancavano.

**Piani**

| Piano | Per chi | Prezzo | Cosa include | Canale di pagamento |
| --- | --- | --- | --- | --- |
| Free | Tutti | 0 € | 1 profilo, 30 documenti, 10 analisi al mese, stato di salute, corpo, rischi, storico dei valori degli ultimi 12 mesi, calendario della prevenzione, scheda emergenza, 1 dossier condiviso al mese, corsi gratuiti dell'Academy, diario alimentare con 3 foto al giorno | — |
| Plus | Chi vuole il monitoraggio completo | 9,99 € al mese o 99 € l'anno | Documenti e analisi illimitati, scansione notturna, spiegazione clinica, coach, farmaci, import email, export, condivisioni illimitate, wiki e articoli, storico completo con confronti e annotazioni, diario alimentare senza limiti con la vista "alimentazione e valori", corsi dell'Academy inclusi | RevenueCat: App Store, Google Play, Stripe sul web |
| Family | Famiglie e caregiver | 14,99 € al mese o 149 € l'anno | Plus per 3 profili (ipotesi: 5 dal v2), modalità caregiver, avvisi ai familiari, diario e corsi per ogni profilo | RevenueCat |
| Pro medico | Medici e professionisti della nutrizione | 29 € al mese o 290 € l'anno (ipotesi) | Lista pazienti, dashboard web, agenda, chat e video, prescrizioni, gestione cure, soglie personalizzate, strumenti per il diario alimentare, studio autore dell'Academy, commissione ridotta su second opinion e televisite | RevenueCat |
| Struttura | Cliniche, poliambulatori, RSA | da 199 € al mese per sede + 15 € per medico (ipotesi) | Backoffice M13, agenda, automazioni, reporting, multi-sede | Stripe con fattura |
| Prevenzione aziendale | Aziende | 3 € per dipendente al mese (ipotesi) | Campagne di screening, Plus per i dipendenti, corsi dell'Academy, report aggregati anonimi | Stripe con fattura |

**Servizi a consumo** (Stripe per i servizi uno-a-uno, fuori dall'acquisto in-app per la regola Apple 3.1.3 d; i corsi sono contenuto digitale e passano dall'acquisto in-app, regola 3.1.1)

| Servizio | Prezzo al paziente | Al medico o all'autore | Alla piattaforma | Canale | Da |
| --- | --- | --- | --- | --- | --- |
| Second opinion base (parere scritto in 72 ore) | 149 € | 75% | 25% meno le commissioni Stripe | Stripe (Apple 3.1.3 d) | v2 |
| Second opinion complessa (caso oncologico, più specialità) | 249–349 € | 75% | 25% | Stripe | v2 |
| Second opinion urgente (24 ore) | +50% | 75% | 25% | Stripe | v2 |
| Televisita | Prezzo fissato dal medico | 85% | 15% | Stripe | v2 |
| Piano alimentare con il professionista (prima visita, piano, controlli) | Prezzo fissato dal professionista | 85% | 15% | Stripe | v2 |
| Corso dell'Academy a pagamento (contenuto digitale) | 9,90–49,90 € (fascia, ipotesi) | 70% del netto come standard dell'admin, modificabile autore per autore | 30% del netto, dopo la commissione dello store (15–30%) | Acquisto in-app con RevenueCat; Stripe solo sul web | v2 |
| Kit dispositivi | Prezzo di listino | — | Margine commerciale | Stripe | v3 |

Prezzi e percentuali sono ipotesi da validare con 10 medici del board e con i primi 100 pazienti; la commissione per i medici Pro scende al 15% sulla second opinion.

**Perché può diventare lo standard**

1. Il livello gratuito fa prevenzione vera: chi non paga ha comunque il calendario degli screening, il corpo e i rischi. È questo che porta volume e fiducia.
2. I dati sono portabili (FHIR, EHDS) e mai venduti: il paziente non è prigioniero, quindi resta.
3. Il medico entra senza registrarsi e ci guadagna tempo; quando si registra ci guadagna pazienti e parcelle.
4. Il board scientifico pubblica le regole con versione: la trasparenza è un vantaggio competitivo, non un costo.
5. Le strutture comprano quello che i loro pazienti usano già: la vendita B2B parte dal B2C.

**Economia unitaria, scenario di lavoro** (da sostituire con i dati reali dopo 90 giorni)

| Voce | Ipotesi |
| --- | --- |
| Ricavo netto per utente Plus al mese | 8,50 € (9,99 € meno il 15% dello store; sul web 9,50 € meno Stripe) |
| Costo IA per utente Plus al mese | 0,40 € obiettivo, 0,80 € soglia di allarme |
| Costo infrastruttura per utente attivo al mese | 0,05 € oltre i 10.000 attivi |
| Costo di acquisizione per utente attivo | 4–8 € (store, contenuti del board, passaparola medico → paziente) |
| Conversione Free → Plus a 90 giorni | 5% |
| Churn mensile Plus | sotto il 4% |
| Margine lordo su una second opinion da 249 € | circa 55 € dopo medico e commissioni |
| Rientro del costo di acquisizione | sotto i 6 mesi |
| Costo IA di un pasto fotografato | sotto 0,01 €; 30 foto al mese restano dentro il budget Plus di 0,40 € |
| Costo video per iscritto a un corso di 90 minuti | circa 0,10 € di erogazione (Cloudflare Stream, 1 $ ogni 1.000 minuti) più 5 $ al mese ogni 1.000 minuti archiviati |
| Margine su un corso venduto a 29,90 € | 6–7,5 € alla piattaforma dopo la commissione dello store (15–30%) e la quota autore (70% del netto) |

**KPI di successo** (gli stessi della sezione 1, misurati ogni settimana)

| Fase | KPI | Soglia |
| --- | --- | --- |
| Attivazione | Primo documento caricato entro 24 ore dall'iscrizione | 50% |
| Momento "aha" | Primo stato di salute visto entro 48 ore | 70% degli attivati |
| Abitudine | Documenti per utente attivo al mese; retention a 30 giorni | 2; 40% |
| Prevenzione | Esami consigliati chiusi con un referto entro 6 mesi | 30% |
| Medici | Dossier aperti dal medico; medici che tornano entro 30 giorni | 60%; 50% |
| Ricavi | Conversione Plus a 90 giorni; ricavo medio per utente attivo al mese | 5%; 0,60 € |
| Second opinion | Tempo mediano di consegna; valutazione media; parere con follow-up richiesto | 72 ore; 4,5; sotto il 30% |
| Academy | Corsi avviati per utente attivo al mese; corsi completati tra quelli avviati | 0,5; 40% |
| Alimentazione | Giorni di diario a settimana per utente del modulo; pasti fotografati confermati | 4; 80% |
| Soglie | Pazienti seguiti con almeno una soglia personalizzata; alert su soglia del medico aperti entro 24 ore | 20%; 70% |

## 18. Piano dei prompt Dreamflow

Diciannove prompt, uno per conversazione, nell'ordine qui sotto; il prompt successivo parte solo quando il criterio di accettazione del precedente è superato. Ogni prompt inizia con "Leggi /docs/MEDICAL24_MASTER.md" per le sezioni che gli servono e con "Leggi /docs/CONTEXT_CORE.md" per intero (file di contesto nella tabella qui sotto), e finisce con la checklist della sezione 15. Le versioni app (iOS e Android) e web desktop full HD si costruiscono insieme in ogni prompt: la shell adattiva nasce nel P00 e ogni schermata successiva si consegna testata ai tre breakpoint. I tre prompt nuovi della v1.1 (P16, P17, P18) coprono Academy e alimentazione; storico dei valori, storico degli organi e soglie entrano nei prompt P03, P04, P05 e P12 già previsti.

**Regole sui modelli** (per tenere bassi i crediti)

- Schema, RLS, Edge Functions, regole cliniche, pagamenti e webhook: Claude Opus 5; se si interrompe, GPT 5.6 Sol. Mai Sonnet 5 su questi prompt: su Dreamflow si interrompe spesso con "internal error".
- Schermate, navigazione, layout adattivo e tema: GPT 5.6 Sol, che completa sempre il prompt ed è veloce.
- Lavoro meccanico con un criterio di accettazione chiaro (chiavi i18n, test pgTAP da una lista di policy, seed, pulizia analyzer, rinomine, test widget): GPT 5.6 Luna, il più economico e veloce della famiglia; Claude Haiku 4.5 in alternativa per testi e rinomine.
- GPT 5.6 Terra non è un default: si prova una volta sulle schermate del P07 (Cure) e resta solo se la qualità è pari a Sol a costo minore.
- I prompt che hanno sia schema sia schermate si eseguono in tre passate nella stessa conversazione, cambiando modello: (a) backend con Opus 5, (b) interfaccia con GPT 5.6 Sol, (c) test, i18n e pulizia con GPT 5.6 Luna.
- Revisione di sicurezza: alla fine dei prompt critici (P00, P02, P05, P08, P09, P12, P14, P18) una conversazione separata con GPT 5.6 Sol legge solo il diff e la checklist e risponde con la lista delle violazioni, senza scrivere codice; le correzioni le fa Luna se banali, Opus 5 se toccano RLS o Edge Functions.

**Regole sui token** (risparmio senza perdere qualità: su dati sanitari si taglia il contesto inutile, mai il modello sulle parti critiche)

1. Un prompt per conversazione: conversazione nuova a ogni prompt, così il contesto resta piccolo e il modello non rilegge la storia.
2. Contesto a strati: CONTEXT_CORE.md sempre e per intero; del MASTER solo le sezioni citate dal prompt; DATA_MODEL.md solo nei prompt che toccano lo schema.
3. Perimetro dei file: ogni prompt elenca le cartelle che può toccare e vieta le altre; modifiche incrementali, mai riscritture di file esistenti.
4. Criterio di accettazione e output atteso in ogni prompt: una sola esecuzione, niente "riprova"; gli errori si incollano come testo, gli screenshot solo quando servono.
5. Il lavoro meccanico va a Luna, mai a Opus 5 o a Sol; i prompt meccanici si accodano nella stessa conversazione del prompt principale.
6. Quello che non si taglia: schema, RLS, Edge Functions, regole cliniche e revisione di sicurezza restano sui modelli grandi. Un token risparmiato lì costa un incidente.

**File di contesto nel progetto Dreamflow** (cartella `/docs`, caricati prima del P00 e aggiornati a ogni versione di questo documento)

| File | Contenuto | Quando lo legge l'agente |
| --- | --- | --- |
| `/docs/CONTEXT_CORE.md` | Due pagine: cosa stiamo costruendo, i 12 principi in breve, stack e versioni, struttura delle cartelle, tema e layout adattivo con i tre breakpoint, convenzioni di nomi e migrazioni, pattern dati e RLS, definizione di fatto, cosa non fare mai | All'inizio di ogni prompt, per intero |
| `/docs/MEDICAL24_MASTER.md` | Questo documento esportato | Solo le sezioni citate dal prompt |
| `/docs/DATA_MODEL.md` | La sezione 5: tabelle, campi chiave, accessi, regole RLS, mappa FHIR | Prompt che toccano lo schema: P00, P02, P03, P05, P07, P08, P09, P12–P18 |
| `/docs/SECURITY_CHECKLIST.md` | I 14 punti della sezione 15 | In coda a ogni prompt; il file serve alla revisione di sicurezza e ai test |
| `/docs/board/` (CSV e JSON) | Catalogo biomarcatori, regole di stato e rischio, calendario della prevenzione, limiti di sicurezza delle soglie, riferimenti nutrizionali, trenta frasi anti-diagnosi: li consegna il board in F0 | P02, P05, P06, P17 |

Nella schermata iniziale di Dreamflow si crea il progetto vuoto con "New Project", si collega il progetto Supabase dev dal pannello delle integrazioni, si caricano i file in `/docs` dalla vista del codice e solo allora si incolla il P00 nell'agente con Claude Opus 5.

| Prompt | Modulo | Che cosa costruisce | Modello | Dipende da | Criterio di accettazione |
| --- | --- | --- | --- | --- | --- |
| P00 Fondamenta | Piattaforma, M1 | Progetto Flutter, tema, i18n, router a 5 sezioni con AppShell adattiva (bottom bar sotto 600 px, NavigationRail fino a 1199 px, menu laterale su desktop full HD), header di sicurezza per il web, Supabase, auth (OTP, Apple, Google), profiles, user_roles, consents, audit_log, RLS, auth hook, onboarding consensi e dati base, impostazioni, eliminazione account | Opus 5 | — | Login su iOS, Android e web; un secondo utente legge zero righe; consensi append-only; eliminazione account funzionante |
| P01 Archivio | M2 | documents, document_pages, bucket privato e policy, upload da fotocamera multipagina, galleria, PDF, share sheet, categorie, tag, lista, ricerca, filtri, anteprima, stati, condivisione base, rimozione di EXIF e posizione | Opus 5 (a), GPT 5.6 Sol (b) | P00 | 50 documenti caricati da tre sorgenti senza perdite; signed URL scadono; utente estraneo zero file |
| P02 Motore | M3 | Seed del catalogo biomarcatori dal CSV del board, extractions, observations append-only, Edge Function extract con Claude API e schema JSON, validazione, macchina a stati, cache, pg_cron notturno, "Aggiorna", conferma dei valori dubbi | Opus 5 (a), Sol (b) | P01 | Su 20 referti di prova almeno il 90% dei valori corretti con unità e data; costo per documento registrato; nessun valore senza codice |
| P03 Stato e parametri | M4 | home_snapshot, health score dalla regola del board, inserimento manuale, sintomi, grafici 7/30/90, storico completo per biomarcatore (vista materializzata, bande di riferimento a tre livelli, episodi fuori soglia, confronto di due valori, annotazioni), tendenze, alert, centro avvisi, lista biomarcatori, export | Opus 5 (a), Sol (b) | P02 | Home con una sola query sotto 300 ms; alert critical generato da un valore di prova; lo storico della glicemia mostra i valori di 5 referti con due episodi fuori soglia datati |
| P04 Corpo | M5 | organs, organ_biomarker_map, organ_states append-only via Edge Function compute con vista latest, silhouette SVG interattiva con 12 aree, scheda organo con storico, confronto a 6 e 12 mesi e doppio tap, confidenza | Opus 5 (a), Sol (b) | P03 | Ogni organo cambia stato con i valori di prova; lo storico del fegato mostra il passaggio di stato tra due referti; dato mancante mostrato come tale |
| P05 Rischi e prevenzione | M6 | rule_versions, risk_scores append-only con SCORE2, FINDRISC, CKD-EPI, FRAX in SQL o TypeScript con test, recommendations, calendario della prevenzione, questionario, "ho fatto l'esame", proiezione 12 mesi; threshold_overrides con resolve_thresholds a tre livelli e limiti di sicurezza del board (tabella e funzione, senza interfaccia medico) | Opus 5 (a), Sol (b) | P04 | I quattro score coincidono con i calcolatori di riferimento su 10 casi; ogni rischio mostra versione della regola e fattori; con un override di prova l'alert di un solo soggetto cambia e il riferimento istituzionale resta visibile |
| P06 Spiegazioni | M7 | Edge Function explain a due livelli, cache per hash, marcatura "testo generato dall'IA", disclaimer, schermate spiegazione referto, organo, rischio | Opus 5 (a), Sol (b) | P05 | Seconda apertura senza nuova chiamata; nessuna frase diagnostica nei 30 test di contenuto del board |
| P07 Cure | M8 | treatments, tags, reviews, favorites, doctors e facilities base, ricerca full-text, filtri rapidi, raggruppamenti, rating con sottovoci, moderazione | Opus 5 (a), Sol (b) | P00 | 100 cure di seed cercabili; recensione non approvata invisibile al pubblico |
| P08 Medico v1 | M9 | Edge Function dossier-pdf, share_links con codice e PIN, pagina web del dossier, questions, scheda emergenza e SOS con QR | Opus 5 (a), Sol (b) | P05 | Un medico senza account apre il dossier con codice e PIN e l'apertura finisce nel registro; link scaduto rifiutato |
| P09 Monetizzazione e admin | M12 | RevenueCat (purchases_flutter) con webhook su subscriptions, paywall, gating per entitlement, Stripe sul web, pannello admin con platform_settings (quota autore standard, fasce di prezzo, commissioni, limiti dei piani, con versioni e audit), pannello board con versioni, eventi analytics, export e cancellazione GDPR | Opus 5 (a), Sol (b) | P08 | Acquisto sandbox su iOS, Android e web sblocca Plus; webhook con firma errata rifiutato; export ZIP completo |
| P10 Hardening e rilascio | Tutti | pgTAP su ogni policy, correzioni del pentest, prestazioni, accessibilità, privacy manifest iOS, dichiarazione Play, asset degli store, i18n completa, crash-free | Opus 5 per l'audit, Luna o Haiku 4.5 per le correzioni | P09 | Zero tabelle senza test; crash-free oltre il 99,5% in beta; approvazione degli store |
| P11 v1.5 | M1, M2, M4, M7, M8 | Family e caregiver, coach IA, wiki con content_references, farmaci e promemoria con annotazioni sullo storico, piano di cura, import email, pre-visita, passaporto multilingua, widget, medico ospite | Opus 5 (a), Sol (b) | P10 | Tre profili con dati separati; coach che rifiuta una richiesta di diagnosi nei test |
| P12 v2 Medico | M9 | Account medico con verifica, Pro, lista pazienti, dashboard web con storico dei valori e degli organi, soglie personalizzate con limiti del board, doctor_notes, permessi in due passi con scope nutrizione, chat, video, prenotazione, prescrizioni, triage, televisite con Stripe | Opus 5 (a), Sol (b) | P11 | Medico senza legame attivo legge zero righe; revoca immediata; video con consenso registrato; un override cambia l'alert di un solo paziente e il paziente lo vede accanto al riferimento istituzionale; senza scope nutrizione il diario non si legge |
| P13 v2 Dispositivi | M11 | HealthKit e Health Connect, Garmin, BLE (pressione, bilance, glucometri), aggregatori, nuovi parametri, alert soft | Opus 5 (a), Sol (b) | P03 | Lettura da HealthKit finisce in observations con origine device; nessun dato scritto falso |
| P14 v2 Second opinion | M10 | Richieste e pareri, Stripe Connect, assegnazione, modello di parere, SLA, follow-up, valutazione, payout | Opus 5 (a), Sol (b) | P12 | Flusso completo in sandbox da richiesta a payout; lo specialista vede solo lo snapshot |
| P15 v3 Strutture | M13 | Account di struttura, ruoli, agenda, workflow, automazioni, reporting, multi-sede, export e import FHIR | Opus 5 (a), Sol (b) | P12 | Segreteria non legge contenuti clinici; report no-show corretto sui dati di prova |
| P16 v1.5 Academy base | M14 | courses, course_lessons, content_references, course_enrollments, lesson_progress, Edge Function academy con Cloudflare Stream (upload firmato, token di riproduzione), catalogo, player, quiz, avanzamento, attestato PDF, legami con wiki, organi e rischi, "Per te", pannello board per la revisione | Opus 5 (a), Sol (b) | P11 | Un corso di prova con 3 lezioni si segue fino all'attestato; un corso non pubblicato è invisibile; il token video scade; un autore non legge gli iscritti |
| P17 v1.5 Alimentazione base | M15 | nutrition_profiles, food_catalog con seed CREA e USDA e lookup Open Food Facts, meal_entries, meal_items, riconoscimento dei pasti dalla foto nella Edge Function extract, codice a barre, riepiloghi, vista "alimentazione e valori", guardrail del board, export | Opus 5 (a), Sol (b) | P03 | Su 20 foto di pasti i piatti sono riconosciuti nell'80% dei casi e le porzioni si correggono in un tap; un alimento animale in uno schema vegano viene segnalato; nessun obiettivo sotto i minimi del board accettato |
| P18 v2 Academy autori e nutrizione con il professionista | M14, M15 | Studio autore per i Pro, controlli automatici e revisione del board, vendita con RevenueCat (non consumabili) e Stripe sul web, quota autore (standard da platform_settings, override per autore in author_terms, copiata sul pagamento) e payout con Stripe Connect, domande all'autore; nutrition_plans, diario condiviso con scope nutrizione, commenti, avvisi di aderenza, report settimanale, prestazione a consumo | Opus 5 (a), Sol (b) | P14, P16, P17 | Un acquisto sandbox sblocca il corso su app e web; l'autore non vede i dati degli iscritti; il dietista con scope legge il diario e senza scope ottiene zero righe; un target sotto i minimi viene rifiutato |

Come in HB Social 2.0, i prompt completi si scrivono uno alla volta, subito prima di eseguirli, così ognuno incorpora quello che il precedente ha prodotto davvero. Il P00 è nella sezione 19; gli altri li genero su richiesta nello stesso formato, un blocco da incollare.

## 19. Prompt P00 completo: fondamenta

Modello: Claude Opus 5 nel Dreamflow agent; se si interrompe, GPT 5.6 Sol. Non usare Sonnet 5 né Luna qui: è un prompt di schema e sicurezza. Prima di incollarlo: progetto creato, Supabase dev collegato, i file `/docs/CONTEXT_CORE.md`, `/docs/MEDICAL24_MASTER.md`, `/docs/DATA_MODEL.md` e `/docs/SECURITY_CHECKLIST.md` caricati nel progetto Dreamflow.

```markdown
PROMPT P00 — MEDICAL 24 · FONDAMENTA (modello: Claude Opus 5; se si interrompe, GPT 5.6 Sol)

CONTESTO
Stai costruendo "Medical 24", app Flutter per iOS, Android e web desktop full HD con backend Supabase, per la gestione della salute personale: archivio di documenti sanitari, estrazione dei dati con IA, stato di salute e storico dei valori, corpo umano interattivo con organi, prevenzione, database di cure, interfaccia con i medici, Academy e diario alimentare. Prima di scrivere codice leggi per intero /docs/CONTEXT_CORE.md e le sezioni 2, 5, 13 e 15 di /docs/MEDICAL24_MASTER.md; /docs/DATA_MODEL.md descrive tutte le tabelle del progetto, ma in questo prompt ne crei solo quattro. Questo è il primo di diciannove prompt: qui si costruiscono solo le fondamenta. Niente dati clinici, niente moduli dei prompt successivi. Sono dati sanitari: sicurezza e stabilità vengono prima della velocità; se una parte del MASTER non è chiara, fermati e chiedi invece di inventare.

STACK OBBLIGATORIO
- Flutter stable, Dart null-safe, un solo codebase per iOS, Android e web; il web è un'applicazione desktop a tutti gli effetti, non un adattamento del telefono.
- Riverpod per lo stato; GoRouter con StatefulShellRoute per le 5 sezioni: Home, Salute, Archivio, Cure, Medico; sul web URL senza "#" (path URL strategy) e deep link sulle stesse rotte.
- Layout adattivo in un solo widget AppShell: sotto 600 px bottom bar a 5 tab; da 600 a 1199 px NavigationRail; da 1200 px in su menu laterale fisso di 260 px, contenuto centrato con larghezza massima 1440 px, griglie a 2 o 3 colonne, stati hover e focus visibili, scorciatoie da tastiera di base. Riferimento desktop: 1920×1080.
- Supabase: Auth, Postgres con RLS, Storage, Edge Functions in TypeScript (Deno). Migrazioni SQL versionate in /supabase/migrations; nessuna modifica manuale al database.
- Internazionalizzazione con file ARB in /lib/l10n per it ed en; nessuna stringa fissa nelle schermate.
- Tema "Calm Health": sfondo #F7F7F4, testo #111418, secondario #5B6470, accento teal #0E7C86, stato verde #1E9E6A, giallo #D98A0B, rosso #D64545, grigio #A3ABB4; font Manrope; card con raggio 20 e bordo rgba(17,20,24,0.06); nessun FAB centrale; dark mode con gli stessi token.
- Pacchetti: supabase_flutter, flutter_riverpod, go_router, flutter_localizations e intl, local_auth, flutter_secure_storage; nessun altro pacchetto senza una riga di motivazione nell'output.

COSA COSTRUIRE
1. Progetto Flutter feature-first: /lib/core (tema, router, AppShell adattiva, client Supabase, i18n, gestione errori con messaggi leggibili, logger che non registra mai dati personali), /lib/features/{auth, onboarding, home, health, archive, treatments, doctor, settings}. La cartella /docs resta com'è.
2. Migrazione 0001_foundation.sql con:
   - enum app_role: user, caregiver, doctor, facility_admin, facility_staff, board, admin;
   - tabelle profiles (id = auth.uid, nome, avatar_url, data_di_nascita, genere, lingua, unita, paese, regione_dati, fuso, deleted_at), user_roles (user_id, role), consents (id, user_id, type, version, granted_at, revoked_at), audit_log (id, actor_id, action, target_table, target_id, subject_id, device, created_at);
   - trigger che alla registrazione crea profiles e user_roles con role = user;
   - funzione can_access_subject(subject_id uuid) che per ora ritorna true solo se subject_id = auth.uid(); verrà estesa nei prompt successivi;
   - RLS attiva su tutte le tabelle: profiles solo proprietario; user_roles lettura propria e scrittura solo service_role; consents insert e select del proprietario, nessuna policy di update o delete; audit_log insert solo tramite funzione security definer log_audit(action, target_table, target_id, subject_id), select del proprietario del soggetto e degli admin.
3. Auth hook custom access token che mette i ruoli nel JWT come claim app_roles.
4. Autenticazione: email e password con OTP via email, Sign in with Apple, Google Sign-In. Schermate: benvenuto, registrazione, login, OTP, recupero password; sul desktop le stesse schermate in una colonna centrata di 480 px.
5. Onboarding in tre passi: (a) consensi separati con testo versionato: trattamento dati sanitari art. 9 GDPR (obbligatorio), elaborazione IA dei documenti (obbligatoria per usare le analisi, l'archivio funziona anche senza), marketing (opzionale); ogni consenso scrive una riga in consents con version; (b) dati base: nome, data di nascita, genere, lingua, unità mg/dL o mmol/L, Paese; (c) schermata "profilo pronto".
6. Impostazioni: profilo, lingua, unità, sicurezza (blocco biometrico con local_auth e PIN di riserva), privacy (esporta i miei dati, elimina account, informativa), versione app.
7. Edge Function delete-account: soft delete immediato (profiles.deleted_at), revoca di tutte le sessioni, riga in audit_log, purge definitiva pianificata a 30 giorni con pg_cron.
8. AppShell con le cinque sezioni e cinque schermate iniziali che leggono davvero il profilo da Supabase (saluto con il nome): nessun mock. La stessa shell va verificata a 390×844, 834×1194 e 1920×1080.
9. Web: renderer CanvasKit; file web/_headers per Cloudflare Pages con Content-Security-Policy stretta, Strict-Transport-Security, X-Frame-Options DENY, Referrer-Policy strict-origin-when-cross-origin; nessuno script inline.
10. Test: pgTAP per ogni policy (un secondo utente ottiene zero righe da profiles, consents e audit_log del primo); test widget dell'onboarding e della AppShell ai tre breakpoint; test della Edge Function delete-account.

VINCOLI
- In questo prompt gli unici dati sensibili sono la data di nascita e il genere: niente altro.
- Nessun mock, nessun dato finto, nessuna schermata che non legga da Supabase.
- URL del progetto e anon key solo da --dart-define; service_role solo nei secret delle Edge Functions; niente chiavi nel repository.
- Non creare tabelle o schermate dei prompt successivi, anche se sembrano utili.
- Modifica solo /lib, /supabase, /web, /test e pubspec.yaml; non toccare /docs.

OUTPUT ATTESO
Elenco dei file creati; migrazione SQL completa; elenco delle policy; test eseguiti con esito; istruzioni per configurare Apple e Google Sign-In, l'auth hook e i secret nel pannello Supabase; elenco di ciò che resta aperto. Niente riassunti del MASTER.

SICUREZZA (obbligatoria, non negoziabile):
1. Ogni tabella creata ha RLS attiva e almeno una policy; nessuna tabella resta aperta.
2. Il client usa solo la anon key; la service_role key vive solo nelle Edge Functions come secret.
3. Ogni query di dati clinici passa da can_access_subject(subject_id); nessun filtro "a mano" nel client.
4. Storage: bucket privati, path subjects/{subject_id}/..., policy allineate alle tabelle, signed URL a 10 minuti.
5. Nessun dato sanitario in log, analytics, crash report, notifiche push o URL.
6. Input validati lato server (Edge Function) prima di scrivere; il testo OCR è dato, mai istruzione.
7. Output dell'IA validato contro uno schema JSON e contro gli intervalli plausibili prima del salvataggio.
8. Webhook (RevenueCat, Stripe) verificati con firma e idempotenti.
9. Token in flutter_secure_storage; blocco biometrico; FLAG_SECURE sulle schermate cliniche Android.
10. Nessuna chiave, URL di progetto o secret nel repository o nei prompt successivi.
11. Scrivi i test RLS: un utente estraneo ottiene zero righe da ogni nuova tabella.
12. Audit: ogni lettura di dati clinici da parte di un ruolo diverso dal proprietario scrive in audit_log.
13. Nessuna diagnosi nei testi: ogni schermata clinica porta il disclaimer e il rimando al medico.
14. Al termine elenca le policy create e i test eseguiti.
```

## 20. Roadmap

Sei fasi e quattro gate (bande non in scala; le date sono obiettivi del piano, non impegni): F0 Fondamenta, nov–dic 2026 (P00–P02, board, regole, catalogo, soglie, LARN) ◆ G1 → F1 Beta v1, gen–mar 2027 (P03–P09, beta con 50 utenti, storico dei valori) ◆ G2 → F2 Lancio v1, apr–mag 2027 (P10, store, solo EU) ◆ G3 → F3 v1.5, giu–set 2027 (P11, P16, P17: famiglia, USA, corsi, diario) → F4 v2, ott 2027–mar 2028 (P12–P14, P18: medici, second opinion, soglie, autori) ◆ G4 → F5 v3, da apr 2028 (P15, strutture, B2B, FHIR).

Ogni gate chiude una fase e apre la successiva; se un gate non passa, la fase si allunga e la data di lancio slitta, non il criterio. I quattro gate: G1 il consulente firma il posizionamento MDR e il board consegna catalogo e regole; G2 il motore supera il 90% di estrazioni corrette e nessuna tabella è senza test RLS; G3 gli store approvano e la beta è crash-free al 99,5%; G4 dieci medici usano il dossier ogni settimana e la prima second opinion è stata pagata e consegnata.

| Fase | Quando | Che cosa | Gate di uscita |
| --- | --- | --- | --- |
| F0 Fondamenta | novembre–dicembre 2026 | Board al lavoro su catalogo, regole, limiti di sicurezza delle soglie e riferimenti nutrizionali; consulente regolatorio e DPO; ambienti; P00, P01, P02 | G1 |
| F1 Beta v1 | gennaio–marzo 2027 | P03–P09 con storico dei valori e degli organi; beta chiusa con 50 utenti e 10 medici pilota; DPIA e informative; pentest | G2 |
| F2 Lancio v1 | aprile–maggio 2027 | P10; invio agli store; sito; lancio Italia e Paesi EU in inglese | G3 |
| F3 v1.5 | giugno–settembre 2027 | P11: Family, caregiver, coach, wiki, farmaci, import email, pre-visita, passaporto; P16 Academy base con i primi 10 corsi del board; P17 diario alimentare; secondo progetto dati per gli Stati Uniti | Retention a 30 giorni sopra il 40%; 10 corsi del board pubblicati |
| F4 v2 | ottobre 2027–marzo 2028 | P12 account medico, telemedicina e soglie personalizzate; P13 dispositivi; P14 second opinion; P18 Academy autori e nutrizione con il professionista | G4 |
| F5 v3 | da aprile 2028 | P15 strutture, B2B, telemonitoraggio, ponte FHIR se approvato; valutazione del provider ECM | Prima struttura pagante e primo report operativo |

## 21. Governance

Tre poteri separati: il prodotto decide cosa si costruisce, il board scientifico decide cosa l'app può dire, la compliance decide cosa l'app può fare con i dati. Nessuno dei tre scavalca gli altri.

| Ruolo | Chi | Responsabilità | Decide su |
| --- | --- | --- | --- |
| Progettista e product owner | Luca Valentini, Tattica Web | Visione, roadmap, prompt, priorità, rilasci | Scope delle release, ordine dei prompt |
| Sviluppo | Dreamflow agent guidato da Luca | Codice Flutter, migrazioni, Edge Functions, test | Scelte implementative dentro il MASTER |
| Clinical lead del board | Un medico del board (internista o medico di medicina generale) | Sicurezza clinica dei contenuti, approvazione finale delle regole, revisione dei testi | Tutto ciò che l'app mostra come significato clinico |
| Board scientifico | Staff medico: cardiologo, diabetologo o endocrinologo, nefrologo, patologo clinico, farmacista; da allargare per specialità della second opinion | Catalogo biomarcatori, intervalli, regole di stato e rischio, esami consigliati, calendario della prevenzione, test anti-diagnosi | Contenuti e regole, con versione |
| DPO (esterno) | Da nominare | DPIA, registro dei trattamenti, breach, rapporti con il Garante | Conformità privacy |
| Consulente regolatorio | Da incaricare | Qualifica MDR, AI Act, EHDS, store | Posizionamento e gate G1 |
| Legale sanitario e commercialista | Da incaricare | Contratti con medici, termini second opinion, assicurazioni, DAC7, fatturazione | Testi contrattuali e fiscali |
| Admin piattaforma | Tattica Web | Verifiche di medici e strutture, moderazione, supporto | Operatività quotidiana |

**Come lavora il board**

1. Ogni regola è una scheda: definizione, fonte (linea guida, calcolatore pubblico), intervalli, casi di test, approvatore, data, versione.
2. Le schede entrano dal pannello board in `rule_versions` e `biomarker_catalog`; l'app usa solo regole attive e mostra la versione.
3. Ogni cambio di regola produce una nota visibile all'utente ("il tuo rischio cardiovascolare è cambiato perché abbiamo aggiornato la regola X").
4. Trenta frasi di test anti-diagnosi: testi che l'app non deve mai produrre; girano nei test del prompt P06 e a ogni cambio di prompt IA.
5. Revisione semestrale di tutto il catalogo; revisione immediata se una linea guida cambia.

**Rituali**: punto prodotto settimanale (Luca + Dreamflow, 30 minuti, un prompt alla volta); board mensile (regole e testi); comitato di compliance a ogni gate; beta chiusa di due settimane su TestFlight e Play internal testing prima di ogni release.

**Documenti vivi**: questo MASTER (versionato), CHANGELOG delle release, registro delle regole, DPIA, runbook incidenti, registro dei fornitori e dei DPA.

## 22. Rischi e mitigazioni

I due rischi che possono fermare il progetto sono la qualifica come dispositivo medico e un'estrazione che sbaglia i numeri; tutti gli altri si gestiscono con il metodo. Le lezioni di HuntingBook (database perso, codice rimaneggiato da troppi modelli) sono già dentro le mitigazioni.

| Rischio | Probabilità | Impatto | Mitigazione | Segnale di allarme |
| --- | --- | --- | --- | --- |
| Il regolatore considera rischi ed esami consigliati una finalità medica (MDR classe IIa) | Media | Alto | Parere regolatorio al gate G1; testi "educativi" su score pubblici; modulo M6 separabile e certificabile dopo | Il consulente non firma il posizionamento |
| Estrazione imprecisa: un valore sbagliato cambia un rischio | Media | Alto | Confidenza per valore, conferma manuale dei dubbi, soglia 90% sui referti di prova, catalogo con sinonimi, correzioni che rientrano nei test | Correzioni manuali oltre il 10% dei valori |
| Costi IA fuori controllo | Media | Medio | Budget per piano, batch notturno, cache, modello piccolo dove basta, allarme giornaliero | Costo per utente Plus oltre 0,80 € al mese |
| Dreamflow produce facciate senza backend, come il primo HuntingBook | Media | Alto | Backend-first in ogni prompt, criterio di accettazione con test RLS, export del repository dopo ogni prompt, migrazioni versionate | Una schermata mostra dati non letti da Supabase |
| Perdita del database, come HuntingBook | Bassa | Altissimo | PITR, backup giornalieri cifrati, copia settimanale su bucket separato, prova di ripristino trimestrale, tre ambienti | Prova di ripristino fallita |
| Rifiuto degli store (regole 1.4.1, 3.1.1 e 5.1.3) | Media | Medio | Disclaimer su ogni schermata clinica, nessuna misurazione via sensori, privacy manifest, dichiarazione Play, pagamenti nel canale giusto (corsi con acquisto in-app) | Prima revisione respinta |
| Violazione dei dati | Bassa | Altissimo | Sezione 15 per intero, pentest, assicurazione cyber, runbook con notifica in 72 ore | Allarme di accesso anomalo |
| I medici non adottano | Alta | Alto | v1 senza account, dossier di una pagina, pre-visita, 10 medici pilota del board, nessuna funzione che non faccia risparmiare tempo | Dossier aperti sotto il 40% |
| Responsabilità sulla second opinion | Media | Alto | Contratto con il medico, RC professionale obbligatoria, consenso alla prestazione a distanza, esclusione delle urgenze, piattaforma come intermediario con termini chiari | Un parere contestato senza documentazione |
| Corsi dell'Academy promozionali o senza fonti | Media | Alto | Fonti obbligatorie per lezione, controllo automatico, revisione del board, checklist anti-promozione, segnalazione e ritiro | Un corso cita un prodotto, un'offerta o la propria attività |
| Diario alimentare che alimenta comportamenti disfunzionali | Bassa | Alto | Minimi di sicurezza del board, linguaggio neutro, niente badge né punteggi sul peso, rimando al professionista, minori solo via tutore | Richieste ripetute di obiettivi sotto i minimi |
| Soglie del medico usate per spegnere gli alert | Bassa | Alto | Limiti di sicurezza del board non superabili, motivazione obbligatoria, audit, notifica al paziente, riferimento istituzionale sempre visibile | Override vicini ai limiti su molti pazienti dello stesso medico |
| Costo dei video e del riconoscimento dei pasti | Media | Medio | Cloudflare Stream a consumo, durata massima delle lezioni, foto a 1024 px, Free con 3 foto al giorno, allarme giornaliero | Costo video sopra 0,15 € per iscritto |
| Dipendenza da un solo fornitore IA | Media | Medio | Edge Function con interfaccia modello intercambiabile, prompt e schema JSON indipendenti dal fornitore, test con un secondo modello ogni trimestre | Aumento di prezzo o deprecazione del modello |
| Norme in movimento (Omnibus AI Act, EHDS, atti italiani) | Alta | Medio | Revisione trimestrale della sezione 13, newsletter regolatoria del consulente | Una data in sezione 13 è passata |
| L'utente percepisce una diagnosi | Media | Alto | Trenta frasi di test, revisione dei testi dal clinical lead, livello "semplice" sempre con rimando al medico | Reclamo o recensione "l'app mi ha detto che ho…" |
| Codice rimaneggiato da troppi modelli | Media | Medio | Un modello per tipo di compito (sezione 18), un prompt per conversazione, revisione del diff prima di accettare | Prompt che riscrive file non suoi |
| Supabase irraggiungibile o policy che bloccano (gli errori visti nell'app attuale) | Bassa | Medio | Staging identico a prod, test pgTAP, monitoraggio con allarmi, retry e stati di errore leggibili | Errore "permission denied" in produzione |

## 23. Decisioni aperte e prossimi passi

**Da decidere prima del P00** (proposta tra parentesi)

- [ ] Posizionamento MDR: incaricare il consulente regolatorio per il parere del gate G1 (sì, subito)
- [ ] SOS e scheda emergenza in v1 (sì)
- [ ] Farmaci con promemoria: v1 o v1.5 (v1.5)
- [ ] Regione dati USA: dal lancio o dopo (v1 solo EU, secondo progetto USA in v1.5)
- [ ] Badge, obiettivi, sfide e mindfulness: restano parcheggiati (sì, fino a dopo v2; Academy e alimentazione sono entrate come M14 e M15 con il brief del 24 ottobre)
- [ ] Storico dei valori nel piano Free: ultimi 12 mesi o completo (12 mesi; completo con confronti e annotazioni in Plus)
- [ ] Quinta tab: "Medico" o "Profilo" ("Medico"; il profilo sta in alto a destra)
- [ ] Profili Family: 3 o 5 (3 in v1.5, 5 in v2)

**Da decidere prima del P16 e del P17** (v1.5)

- [ ] Primi 10 corsi del board: argomenti e autori sui tre filoni della sezione 10, lettura dei propri esami, prevenzione, condizioni croniche (lista del board entro il gate G2)
- [ ] Licenze dei dati alimentari: termini CREA da verificare con il legale, attribuzione Open Food Facts nelle schermate del diario (sì)
- [ ] Foto dei pasti: conservarle o tenere solo i nutrienti dopo 90 giorni come impostazione predefinita (foto conservate, opzione "solo nutrienti" disponibile)
- [ ] Diario alimentare per i profili dei minori: attivo solo dal tutore e senza obiettivi di peso (sì)
- [ ] Vista "alimentazione e valori": in Free o solo in Plus (Plus, come il diario senza limiti)

**Da decidere prima del P12** (v2)

- [ ] Fornitore video per la telemedicina: Daily, 100ms o LiveKit (prova con due, scelta su costo per minuto e GDPR)
- [ ] Verifica dei medici: controllo manuale sull'albo FNOMCeO o servizio esterno (manuale fino a 500 medici)
- [ ] Prezzi di Pro, Struttura e second opinion (validare con 10 medici e 100 pazienti)
- [ ] Ambiti dei professionisti della nutrizione: chi può elaborare un piano per una patologia (parere del legale sanitario)
- [ ] Soglie del medico: notifica al paziente a ogni modifica e scelta del curante di riferimento quando due medici hanno soglie diverse (sì a entrambe)
- [ ] Corsi dei medici: fasce di prezzo 9,90–49,90 €, impostate nel pannello admin (validare con i primi 10 autori); la quota autore è decisa il 24 ottobre 2026: standard 70% del netto in platform_settings, modificabile autore per autore dall'admin
- [ ] Dati pseudonimizzati per la ricerca: sì o no, con quale consenso (decisione del board e del legale)
- [ ] Ingresso in ospedale: ponte FHIR verso la cartella clinica o nessun ingresso (decisione del board in v3)
- [ ] Provider ECM per l'Academy: accreditamento AGENAS in v3 o mai (valutare in v3 sui numeri dell'Academy)

**Prossimi 30 giorni**

1. Esportare questo documento come `/docs/MEDICAL24_MASTER.md` nel repository e nel progetto Dreamflow.
2. Board: consegnare il CSV del catalogo con i 200 biomarcatori essenziali (codice LOINC, sinonimi, unità, intervalli ottimali per età e genere, limiti di sicurezza che nessuna soglia del medico può superare, organi), le regole di stato organo, i quattro score con 10 casi di test ciascuno, il calendario della prevenzione per età e genere, i riferimenti nutrizionali dai LARN, le trenta frasi anti-diagnosi.
3. Board: scegliere i primi 10 corsi dell'Academy e i loro autori.
4. Incaricare consulente regolatorio e DPO; aprire la DPIA, che copre anche le foto dei pasti e le soglie del medico.
5. Creare i tre progetti Supabase (dev, staging, prod) in regione EU; account RevenueCat, Stripe e Cloudflare Stream; Apple Developer e Google Play con i moduli sanitari.
6. Eseguire P00 e P01 e verificarne i criteri di accettazione.
7. Reclutare 10 medici pilota dal board e 50 utenti per la beta chiusa.
8. Verificare marchio e domini di "Medical 24" nei Paesi di lancio.

## 24. Fonti

**Documenti del progetto medical24.app** (analizzati per intero; l'inventario delle 264 funzionalità è nel documento "Medical 24 — Inventario completo delle funzionalità")

- promt.rtf (brief originale), Gpt1.txt (ecosistema e dispositivi), Gpt2.txt (analisi Ornament), Gpt3.txt (archetipi backoffice e myhealth24), Gpt4.txt (sito e dashboard), Gpt5.txt (Cure, Academy, redesign), MedEd24_Investor_Pitch.pptx, MedEd24.pdf, 32 screenshot dell'app MedEd24 e homepage.png
- Medical 24 — Draft di progetto v0.1 e Medical 24 — Mockup app e sito (Calm Health 2026)
- Brief di Luca in chat del 18, del 20 e del 24 ottobre 2026 (il terzo: Academy, alimentazione, storico dei valori e degli organi, soglie del medico)

**Pagine ufficiali e di settore consultate il 20 e il 24 ottobre 2026**

- [Gibson Dunn — EU AI Act Omnibus agreement: postponed high-risk deadlines](https://www.gibsondunn.com/eu-ai-act-omnibus-agreement-postponed-high-risk-deadlines-and-other-key-changes/)
- [Baker McKenzie — European Health Data Space: timeline and obligations](https://healthcarelifesciences.bakermckenzie.com/?p=967)
- [ICT Security Magazine — Legge italiana sull'intelligenza artificiale (L. 132/2025)](https://www.ictsecuritymagazine.com/notizie/legge-italiana-sullintelligenza-artificiale/)
- [Quotidiano Sanità — In vigore la legge sull'AI: il medico informa il paziente](https://www.quotidianosanita.it/lavoro-e-professioni/in-vigore-la-legge-sull-ai-medico-obbligato-a-informare-il-paziente-se-ne-fa-uso/)
- [Quotidiano Sanità — Il decalogo del Garante Privacy sull'IA in sanità](https://www.quotidianosanita.it/?p=129232)
- [OpenRegulatory — MDCG 2019-11: qualification and classification of software](https://openregulatory.com/mdcg/mdcg-2019-11)
- [Conferenza Stato-Regioni — Indicazioni nazionali per l'erogazione di prestazioni in telemedicina (17 dicembre 2020)](https://www.lcalex.it/wp-content/uploads/2020/12/Indicazioni-nazionali-per-la-telemedicina.pdf)
- [Apple — App Review Guidelines](https://developer.apple.com/support/downloads/terms/app-review-guidelines/App-Review-Guidelines-English-UK.pdf)
- [Google Play — Norme per le app sanitarie e Health Connect](https://support.google.com/googleplay/android-developer/answer/16555673)
- [FTC — Updated Health Breach Notification Rule for health apps](https://www.ftc.gov/business-guidance/blog/2024/04/updated-ftc-health-breach-notification-rule-puts-new-provisions-place-protect-users-health-apps)
- [RevenueCat — Stripe integration](https://www.revenuecat.com/integrations/stripe.md)
- [Cloudflare Stream — Pricing](https://developers.cloudflare.com/stream/pricing/) (5 $ al mese ogni 1.000 minuti archiviati, 1 $ ogni 1.000 minuti erogati; letta il 24 ottobre 2026)
- [Open Food Facts — Licenze dei dati e delle immagini (ODbL, DbCL, CC BY-SA)](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorials/license-be-on-the-legal-side/)
- [SINU — LARN V revisione](https://sinu.it/larn/) (tabelle riassuntive pubbliche, volume a pagamento per il board)
- [Ordine dei Medici di Reggio Emilia — Documentazione normativa sull'informazione sanitaria, aggiornata al 20 febbraio 2025](https://odmeo.re.it/wp-content/uploads/2025/03/Documentazione-normativainformazionesanitaria-agg20-2-2025.pdf)

Le date dell'Omnibus AI Act sono quelle dell'accordo provvisorio del 6 maggio 2026 e diventano definitive solo con la pubblicazione in Gazzetta ufficiale dell'UE: da ricontrollare al gate G1.
