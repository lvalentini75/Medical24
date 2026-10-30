# Medical 24 — DATA_MODEL (sezione 5 del MASTER v1.1, 24 ottobre 2026)

Uso: lo legge l'agente nei prompt che toccano lo schema. Ogni tabella elenca contenuto, campi chiave e chi può accedere; la versione in parentesi (v1.5, v2, v3) dice in quale release la tabella nasce. Le tabelle senza versione nascono in v1. Il prompt dice quali tabelle creare: mai crearne altre in anticipo.

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
