-- ============================================================================
-- Medical 24 - 0020 TREATMENTS DEMO SEED (P07-A4) - modulo M8 Cure
--
-- Solo dati dimostrativi, tutti con identificativi fissi. La funzione interna
-- rende verificabile l'idempotenza e non e' eseguibile dai ruoli applicativi.
-- Nessun contenuto identifica persone o strutture reali e nessun testo promette
-- risultati clinici.
-- ============================================================================

create or replace function public.m24_seed_0020_treatments_demo()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  -- Sei autori dimostrativi delle recensioni.
  insert into auth.users(id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
  select ('a0200000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
    '00000000-0000-0000-0000-000000000000'::uuid,
    'authenticated', 'authenticated', 'utente' || i || '@demo.medical24.app', '',
    '2026-11-09 09:00:00+00'::timestamptz, '{}'::jsonb,
    jsonb_build_object('full_name', 'Utente ' || i || ' Demo'),
    '2026-11-09 09:00:00+00'::timestamptz, '2026-11-09 09:00:00+00'::timestamptz
  from generate_series(1, 6) as s(i)
  on conflict (id) do update set
    email = excluded.email,
    raw_user_meta_data = excluded.raw_user_meta_data,
    updated_at = excluded.updated_at;

  insert into public.facilities(id, name, kind, ssn_accredited, address, city, region,
    country, lat, lng, phone, email, website, services, opening_hours, photos,
    verified, is_demo)
  values
    ('f0200000-0000-4000-8000-000000000001','Centro salute demo Milano','poliambulatorio',true,'Via Dimostrativa 1','Milano','Lombardia','IT',45.464194,9.189635,'+39 02 0000001','milano@demo.medical24.app',null,array['fisioterapia','screening','diagnostica'],'{"lun-ven":"08:00-19:00","sab":"08:30-13:00"}',array['https://placehold.co/1200x800?text=Centro+demo+Milano'],false,true),
    ('f0200000-0000-4000-8000-000000000002','Studio riabilitazione demo Torino','centro_riabilitazione',false,'Corso Dimostrativo 2','Torino','Piemonte','IT',45.070339,7.686864,'+39 011 0000002','torino@demo.medical24.app',null,array['fisioterapia','rieducazione motoria','valutazione posturale'],'{"lun-ven":"08:30-18:30"}',array['https://placehold.co/1200x800?text=Studio+demo+Torino'],false,true),
    ('f0200000-0000-4000-8000-000000000003','Poliambulatorio prevenzione demo Bologna','poliambulatorio',true,'Piazza Dimostrativa 3','Bologna','Emilia-Romagna','IT',44.494887,11.342616,'+39 051 0000003','bologna@demo.medical24.app',null,array['prevenzione','screening','consulenze'],'{"lun-ven":"07:30-18:00","sab":"08:00-12:00"}',array['https://placehold.co/1200x800?text=Poliambulatorio+demo+Bologna'],false,true),
    ('f0200000-0000-4000-8000-000000000004','Clinica multidisciplinare demo Firenze','clinica',false,'Viale Dimostrativo 4','Firenze','Toscana','IT',43.769562,11.255814,'+39 055 0000004','firenze@demo.medical24.app',null,array['diagnostica','terapia manuale','benessere'],'{"lun-ven":"08:00-20:00"}',array['https://placehold.co/1200x800?text=Clinica+demo+Firenze'],false,true),
    ('f0200000-0000-4000-8000-000000000005','Centro diagnostico demo Roma','poliambulatorio',true,'Via Dimostrativa 5','Roma','Lazio','IT',41.902782,12.496366,'+39 06 0000005','roma@demo.medical24.app',null,array['diagnostica','screening','controlli periodici'],'{"lun-sab":"07:00-19:00"}',array['https://placehold.co/1200x800?text=Centro+demo+Roma'],false,true),
    ('f0200000-0000-4000-8000-000000000006','Studio benessere demo Napoli','studio',false,'Largo Dimostrativo 6','Napoli','Campania','IT',40.851799,14.268120,'+39 081 0000006','napoli@demo.medical24.app',null,array['stili di vita','gestione dello stress','educazione al sonno'],'{"lun-ven":"09:00-19:00"}',array['https://placehold.co/1200x800?text=Studio+demo+Napoli'],false,true),
    ('f0200000-0000-4000-8000-000000000007','Centro movimento demo Bari','centro_riabilitazione',true,'Via Dimostrativa 7','Bari','Puglia','IT',41.117143,16.871871,'+39 080 0000007','bari@demo.medical24.app',null,array['riabilitazione in acqua','movimento adattato','recupero funzionale'],'{"lun-ven":"08:00-19:30","sab":"09:00-13:00"}',array['https://placehold.co/1200x800?text=Centro+demo+Bari'],false,true),
    ('f0200000-0000-4000-8000-000000000008','Ambulatorio salute demo Palermo','poliambulatorio',false,'Piazza Dimostrativa 8','Palermo','Sicilia','IT',38.115688,13.361267,'+39 091 0000008','palermo@demo.medical24.app',null,array['prevenzione','salute metabolica','consulenze'],'{"lun-ven":"08:00-18:00"}',array['https://placehold.co/1200x800?text=Ambulatorio+demo+Palermo'],false,true),
    ('f0200000-0000-4000-8000-000000000009','Centro percorsi demo Genova','clinica',true,'Corso Dimostrativo 9','Genova','Liguria','IT',44.405650,8.946256,'+39 010 0000009','genova@demo.medical24.app',null,array['terapie tradizionali','riabilitazione','controlli'],'{"lun-ven":"08:00-19:00"}',array['https://placehold.co/1200x800?text=Centro+demo+Genova'],false,true),
    ('f0200000-0000-4000-8000-000000000010','Istituto ricerca clinica demo Padova','altro',false,'Via Dimostrativa 10','Padova','Veneto','IT',45.406435,11.876761,'+39 049 0000010','padova@demo.medical24.app',null,array['percorsi osservazionali','valutazioni multidisciplinari','ricerca clinica'],'{"lun-ven":"09:00-17:30"}',array['https://placehold.co/1200x800?text=Istituto+demo+Padova'],false,true)
  on conflict (id) do update set
    name=excluded.name, kind=excluded.kind, ssn_accredited=excluded.ssn_accredited,
    address=excluded.address, city=excluded.city, region=excluded.region,
    country=excluded.country, lat=excluded.lat, lng=excluded.lng, phone=excluded.phone,
    email=excluded.email, website=excluded.website, services=excluded.services,
    opening_hours=excluded.opening_hours, photos=excluded.photos,
    verified=excluded.verified, is_demo=excluded.is_demo;

  insert into public.doctors(id, display_name, role, specialties, registry_body,
    registry_number, verified, languages, bio, photo_url, facility_id, is_demo)
  values
    ('d0200000-0000-4000-8000-000000000001','Dott.ssa A. Rossi - demo','fisioterapista',array['riabilitazione ortopedica','terapia manuale'],'Albo demo professioni sanitarie','DEMO-FT-001',true,array['italiano','inglese'],E'Professionista dimostrativa dedicata alla valutazione funzionale.\nLe indicazioni sono informative e richiedono una valutazione individuale.','https://placehold.co/600x600?text=Professionista+demo+01','f0200000-0000-4000-8000-000000000001',true),
    ('d0200000-0000-4000-8000-000000000002','Dott. L. Bianchi - demo','fisioterapista',array['rieducazione motoria','postura'],'Albo demo professioni sanitarie','DEMO-FT-002',true,array['italiano','francese'],E'Professionista dimostrativo per percorsi motori graduali.\nObiettivi e carichi vengono adattati dopo valutazione professionale.','https://placehold.co/600x600?text=Professionista+demo+02','f0200000-0000-4000-8000-000000000002',true),
    ('d0200000-0000-4000-8000-000000000003','Dott.ssa M. Verdi - demo','medico',array['medicina preventiva','rischio cardiovascolare'],'Ordine demo dei medici','DEMO-MD-003',true,array['italiano','inglese'],E'Medica dimostrativa per prevenzione e lettura dei fattori di rischio.\nI percorsi non sostituiscono visite o prescrizioni del medico curante.','https://placehold.co/600x600?text=Professionista+demo+03','f0200000-0000-4000-8000-000000000003',true),
    ('d0200000-0000-4000-8000-000000000004','Dott. G. Neri - demo','medico',array['diagnostica generale','salute respiratoria'],'Ordine demo dei medici','DEMO-MD-004',true,array['italiano','tedesco'],E'Medico dimostrativo per percorsi di controllo programmato.\nEsami e frequenza vanno concordati in base alla storia personale.','https://placehold.co/600x600?text=Professionista+demo+04','f0200000-0000-4000-8000-000000000005',true),
    ('d0200000-0000-4000-8000-000000000005','Dott.ssa E. Romano - demo','biologo_nutrizionista',array['educazione alimentare','salute metabolica'],'Albo demo biologi','DEMO-BN-005',true,array['italiano','inglese','spagnolo'],E'Biologa nutrizionista dimostrativa per educazione alimentare.\nLe proposte generali non costituiscono un piano nutrizionale personale.','https://placehold.co/600x600?text=Professionista+demo+05','f0200000-0000-4000-8000-000000000006',true),
    ('d0200000-0000-4000-8000-000000000006','Dott. P. Gallo - demo','dietista',array['alimentazione consapevole','stili di vita'],'Albo demo dietisti','DEMO-DI-006',true,array['italiano','inglese'],E'Dietista dimostrativo per percorsi educativi sostenibili.\nOgni modifica rilevante va condivisa con i professionisti di riferimento.','https://placehold.co/600x600?text=Professionista+demo+06','f0200000-0000-4000-8000-000000000008',true),
    ('d0200000-0000-4000-8000-000000000007','Dott.ssa C. Fontana - demo','fisioterapista',array['riabilitazione in acqua','recupero funzionale'],'Albo demo professioni sanitarie','DEMO-FT-007',true,array['italiano','inglese'],E'Professionista dimostrativa per attivita in acqua e recupero graduale.\nL idoneita viene verificata prima di iniziare il percorso.','https://placehold.co/600x600?text=Professionista+demo+07','f0200000-0000-4000-8000-000000000007',true),
    ('d0200000-0000-4000-8000-000000000008','Dott. S. Conti - demo','medico',array['medicina fisica','dolore muscoloscheletrico'],'Ordine demo dei medici','DEMO-MD-008',true,array['italiano'],E'Medico dimostrativo per inquadramento funzionale multidisciplinare.\nLa scheda non anticipa diagnosi, prognosi o risultati individuali.','https://placehold.co/600x600?text=Professionista+demo+08','f0200000-0000-4000-8000-000000000004',true),
    ('d0200000-0000-4000-8000-000000000009','Dott.ssa V. Esposito - demo','medico',array['salute ossea','prevenzione'],'Ordine demo dei medici','DEMO-MD-009',true,array['italiano','inglese'],E'Medica dimostrativa per controlli preventivi e salute ossea.\nIndicazioni e intervalli dipendono dal profilo clinico individuale.','https://placehold.co/600x600?text=Professionista+demo+09','f0200000-0000-4000-8000-000000000009',true),
    ('d0200000-0000-4000-8000-000000000010','Dott. R. Ricci - demo','medico',array['terapia medica','salute metabolica'],'Ordine demo dei medici','DEMO-MD-010',true,array['italiano','francese'],E'Medico dimostrativo per percorsi terapeutici convenzionali.\nBenefici, rischi e alternative richiedono sempre confronto clinico.','https://placehold.co/600x600?text=Professionista+demo+10','f0200000-0000-4000-8000-000000000001',true),
    ('d0200000-0000-4000-8000-000000000011','Dott.ssa F. Marino - demo','medico_dietologo',array['medicina nutrizionale','sovrappeso'],'Ordine demo dei medici','DEMO-MD-011',true,array['italiano','inglese'],E'Medica dietologa dimostrativa per valutazioni integrate.\nIl percorso viene definito solo dopo anamnesi e verifica delle necessita.','https://placehold.co/600x600?text=Professionista+demo+11','f0200000-0000-4000-8000-000000000008',true),
    ('d0200000-0000-4000-8000-000000000012','Dott. D. Ferri - demo','altro',array['supporto psicologico','gestione dello stress'],'Albo demo professionisti','DEMO-PS-012',true,array['italiano','inglese'],E'Professionista dimostrativo per consapevolezza e gestione dello stress.\nIl servizio informativo non sostituisce un percorso psicologico personale.','https://placehold.co/600x600?text=Professionista+demo+12','f0200000-0000-4000-8000-000000000006',true),
    ('d0200000-0000-4000-8000-000000000013','Dott.ssa I. Greco - demo','fisioterapista',array['equilibrio','mobilita'],'Albo demo professioni sanitarie','DEMO-FT-013',true,array['italiano','spagnolo'],E'Professionista dimostrativa per equilibrio e autonomia motoria.\nIl livello degli esercizi viene deciso dopo una valutazione in presenza.','https://placehold.co/600x600?text=Professionista+demo+13','f0200000-0000-4000-8000-000000000010',true),
    ('d0200000-0000-4000-8000-000000000014','Dott. N. Serra - demo','medico',array['ricerca clinica','valutazione multidisciplinare'],'Ordine demo dei medici','DEMO-MD-014',true,array['italiano','inglese'],E'Medico dimostrativo per percorsi osservazionali di ricerca.\nPartecipazione, alternative e incertezze devono essere spiegate chiaramente.','https://placehold.co/600x600?text=Professionista+demo+14','f0200000-0000-4000-8000-000000000010',true),
    ('d0200000-0000-4000-8000-000000000015','Dott.ssa O. De Luca - demo','medico',array['salute visiva','salute uditiva'],'Ordine demo dei medici','DEMO-MD-015',true,array['italiano','inglese'],E'Medica dimostrativa per controlli sensoriali programmati.\nLa necessita di approfondimenti dipende dagli esiti e dai sintomi riferiti.','https://placehold.co/600x600?text=Professionista+demo+15','f0200000-0000-4000-8000-000000000003',true),
    ('d0200000-0000-4000-8000-000000000016','Dott. T. Moretti - demo','fisioterapista',array['attivita fisica adattata','domicilio'],'Albo demo professioni sanitarie','DEMO-FT-016',true,array['italiano','inglese'],E'Professionista dimostrativo per movimento adattato anche a domicilio.\nAmbiente, sicurezza e obiettivi vengono verificati prima delle sedute.','https://placehold.co/600x600?text=Professionista+demo+16','f0200000-0000-4000-8000-000000000009',true)
  on conflict (id) do update set
    display_name=excluded.display_name, role=excluded.role, specialties=excluded.specialties,
    registry_body=excluded.registry_body, registry_number=excluded.registry_number,
    verified=excluded.verified, languages=excluded.languages, bio=excluded.bio,
    photo_url=excluded.photo_url, facility_id=excluded.facility_id, is_demo=excluded.is_demo;

  insert into public.treatment_tags(tag, label_it, label_en, kind, sort_order)
  values
    ('fisioterapia','Fisioterapia','Physiotherapy','categoria',10),
    ('riabilitazione-motoria','Riabilitazione motoria','Motor rehabilitation','categoria',20),
    ('idroterapia','Riabilitazione in acqua','Aquatic rehabilitation','categoria',30),
    ('postura','Postura','Posture','categoria',40),
    ('terapia-manuale','Terapia manuale','Manual therapy','categoria',50),
    ('screening','Screening','Screening','categoria',60),
    ('diagnostica','Diagnostica','Diagnostics','categoria',70),
    ('nutrizione','Nutrizione','Nutrition','categoria',80),
    ('attivita-fisica','Attivita fisica','Physical activity','categoria',90),
    ('supporto-psicologico','Supporto psicologico','Psychological support','categoria',100),
    ('terapia-medica','Terapia medica','Medical therapy','categoria',110),
    ('ricerca-clinica','Ricerca clinica','Clinical research','categoria',120),
    ('lombalgia','Lombalgia','Low back pain','patologia',210),
    ('cervicalgia','Cervicalgia','Neck pain','patologia',220),
    ('dolore-articolare','Dolore articolare','Joint pain','patologia',230),
    ('recupero-post-operatorio','Recupero post operatorio','Post-operative recovery','patologia',240),
    ('equilibrio-mobilita','Equilibrio e mobilita','Balance and mobility','patologia',250),
    ('rischio-cardiovascolare','Rischio cardiovascolare','Cardiovascular risk','patologia',260),
    ('diabete','Diabete','Diabetes','patologia',270),
    ('salute-ossea','Salute ossea','Bone health','patologia',280),
    ('salute-respiratoria','Salute respiratoria','Respiratory health','patologia',290),
    ('salute-visiva','Salute visiva','Vision health','patologia',300),
    ('salute-uditiva','Salute uditiva','Hearing health','patologia',310),
    ('salute-metabolica','Salute metabolica','Metabolic health','patologia',320),
    ('sonno','Sonno','Sleep','patologia',330),
    ('stress','Stress','Stress','patologia',340),
    ('sovrappeso','Sovrappeso','Overweight','patologia',350),
    ('cefalea','Cefalea','Headache','patologia',360),
    ('mobilita','Migliorare la mobilita','Improve mobility','obiettivo',410),
    ('forza','Sostenere la forza','Support strength','obiettivo',420),
    ('autonomia','Sostenere l autonomia','Support independence','obiettivo',430),
    ('prevenzione','Prevenzione informata','Informed prevention','obiettivo',440),
    ('benessere-generale','Benessere generale','General wellbeing','obiettivo',450),
    ('alimentazione-consapevole','Alimentazione consapevole','Mindful nutrition','obiettivo',460),
    ('gestione-stress','Gestione dello stress','Stress management','obiettivo',470),
    ('qualita-sonno','Qualita del sonno','Sleep quality','obiettivo',480),
    ('in-presenza','In presenza','In person','modalita',510),
    ('online','Online','Online','modalita',520),
    ('ibrido','Ibrido','Hybrid','modalita',530),
    ('domicilio','A domicilio','At home','modalita',540)
  on conflict (tag) do update set
    label_it=excluded.label_it, label_en=excluded.label_en,
    kind=excluded.kind, sort_order=excluded.sort_order;

  with catalog(i, title) as (values
    (1,'Fisioterapia individuale per la mobilita'),
    (2,'Fisioterapia individuale per la zona lombare'),
    (3,'Fisioterapia individuale cervicale'),
    (4,'Rieducazione motoria graduale'),
    (5,'Riabilitazione in acqua assistita'),
    (6,'Percorso posturale individuale'),
    (7,'Terapia manuale con valutazione iniziale'),
    (8,'Valutazione fisioterapica funzionale'),
    (9,'Recupero motorio post operatorio'),
    (10,'Esercizio terapeutico per equilibrio'),
    (11,'Attivita motoria adattata a domicilio'),
    (12,'Percorso integrato per dolore articolare'),
    (13,'Screening cardiovascolare informativo'),
    (14,'Controllo periodico della salute metabolica'),
    (15,'Percorso di prevenzione del diabete'),
    (16,'Valutazione preventiva della salute ossea'),
    (17,'Controllo programmato della funzione respiratoria'),
    (18,'Screening visivo periodico'),
    (19,'Screening uditivo periodico'),
    (20,'Percorso diagnostico per cefalea ricorrente'),
    (21,'Valutazione diagnostica muscoloscheletrica'),
    (22,'Controllo multidisciplinare del sovrappeso'),
    (23,'Educazione al movimento quotidiano'),
    (24,'Percorso di alimentazione consapevole'),
    (25,'Laboratorio per la gestione dello stress'),
    (26,'Educazione alla qualita del sonno'),
    (27,'Gruppo di mobilita dolce'),
    (28,'Percorso di benessere respiratorio'),
    (29,'Cammino assistito per il benessere generale'),
    (30,'Consulenza sugli stili di vita'),
    (31,'Terapia medica tradizionale per cefalea'),
    (32,'Percorso terapeutico tradizionale respiratorio'),
    (33,'Terapia tradizionale per dolore articolare'),
    (34,'Percorso medico per salute metabolica'),
    (35,'Terapia tradizionale di supporto post operatorio'),
    (36,'Percorso terapeutico convenzionale integrato'),
    (37,'Percorso sperimentale osservazionale sulla mobilita'),
    (38,'Percorso sperimentale osservazionale sul sonno'),
    (39,'Percorso sperimentale osservazionale sullo stress'),
    (40,'Percorso sperimentale osservazionale metabolico')
  ), prepared as (
    select i, title,
      case when i <= 12 then 'riabilitazione'::treatment_scope
           when i <= 17 then 'prevenzione'::treatment_scope
           when i <= 22 then 'diagnostica'::treatment_scope
           when i <= 30 then 'benessere'::treatment_scope
           else 'terapia'::treatment_scope end as scope,
      case when i between 37 and 40 then 'sperimentale'::treatment_family
           when i between 23 and 30 then 'naturale'::treatment_family
           else 'tradizionale'::treatment_family end as family,
      case when i <= 22 then 'linee_guida'::treatment_evidence_level
           when i between 23 and 30 and i % 2 = 1 then 'esperienziale'::treatment_evidence_level
           when i between 23 and 30 then 'osservazionale'::treatment_evidence_level
           when i between 31 and 36 then 'studi_clinici'::treatment_evidence_level
           else 'osservazionale'::treatment_evidence_level end as evidence_level,
      case
        when i <= 3 then 'fisioterapia'
        when i = 4 then 'riabilitazione-motoria'
        when i = 5 then 'idroterapia'
        when i = 6 then 'postura'
        when i = 7 then 'terapia-manuale'
        when i between 8 and 12 then 'fisioterapia'
        when i in (13,15,16,18,19) then 'screening'
        when i between 14 and 22 then 'diagnostica'
        when i = 24 then 'nutrizione'
        when i in (23,27,29) then 'attivita-fisica'
        when i in (25,26,30) then 'supporto-psicologico'
        when i = 28 then 'attivita-fisica'
        when i between 31 and 36 then 'terapia-medica'
        else 'ricerca-clinica' end as category_tag,
      (array['lombalgia','cervicalgia','dolore-articolare','recupero-post-operatorio',
        'equilibrio-mobilita','rischio-cardiovascolare','diabete','salute-ossea',
        'salute-respiratoria','salute-visiva','salute-uditiva','salute-metabolica',
        'sonno','stress','sovrappeso','cefalea'])[((i - 1) % 16) + 1] as condition_tag,
      (array['mobilita','forza','autonomia','prevenzione','benessere-generale',
        'alimentazione-consapevole','gestione-stress','qualita-sonno'])[((i - 1) % 8) + 1] as goal_tag,
      (array['in-presenza','online','ibrido','domicilio'])[((i - 1) % 4) + 1] as modality_tag
    from catalog
  )
  insert into public.treatments(id, title, summary, description_sections, family, scope,
    category, conditions, tags, evidence_level, contraindications, price_from_cents,
    price_to_cents, currency, price_notes, ssn_covered, session_minutes, sessions_count,
    course_weeks, waiting_days, modality, requirements, expected_outcome, media,
    doctor_id, facility_id, status, version, is_demo, featured, published_at)
  select ('c0200000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
    title,
    'Scheda dimostrativa informativa su un percorso da valutare con un professionista, senza garanzia di risultato.',
    jsonb_build_object(
      'per_chi','Informazioni generali per adulti interessati a ' || lower(title) || '; l idoneita va verificata individualmente.',
      'come_funziona','Il percorso prevede una valutazione iniziale, obiettivi condivisi e controlli periodici con il professionista.',
      'durata','Durata e frequenza sono indicative e possono cambiare in base alla valutazione, alla risposta e alle necessita personali.',
      'rischi_e_controindicazioni','Possibili fastidi o affaticamento devono essere riferiti; condizioni acute o instabili richiedono prima un parere medico.',
      'evidenze_e_limiti',case when i between 37 and 40
        then 'Percorso sperimentale dimostrativo basato su osservazioni preliminari: efficacia e sicurezza non sono stabilite, i risultati possono non essere generalizzabili e la partecipazione richiede consenso informato e alternative chiare.'
        when i between 23 and 30
        then 'Le informazioni derivano da esperienza professionale o studi osservazionali; le prove sono limitate e non consentono di prevedere benefici individuali.'
        when i between 31 and 36
        then 'Esistono studi clinici pertinenti, ma benefici e rischi dipendono da indicazione, condizioni personali e supervisione del medico.'
        else 'Il percorso e coerente con linee guida generali; applicabilita, frequenza e risultati dipendono dal profilo individuale e dalla qualita delle prove disponibili.' end),
    family, scope, initcap(replace(category_tag, '-', ' ')), array[condition_tag],
    array[category_tag, condition_tag, goal_tag, modality_tag], evidence_level,
    case i % 3
      when 0 then jsonb_build_array(
        jsonb_build_object('text','Condizione acuta non ancora valutata','severity','alta'),
        jsonb_build_object('text','Dolore o sintomi in rapido peggioramento','severity','media'),
        jsonb_build_object('text','Difficolta a seguire le indicazioni in sicurezza','severity','bassa'))
      when 1 then jsonb_build_array(
        jsonb_build_object('text','Condizione clinica instabile senza parere medico','severity','alta'))
      else jsonb_build_array(
        jsonb_build_object('text','Sintomi nuovi non ancora valutati','severity','media'),
        jsonb_build_object('text','Affaticamento non tollerato','severity','bassa')) end,
    3500 + i * 250, 5000 + i * 350, 'EUR',
    'Importi dimostrativi; eventuali esenzioni o rimborsi vanno verificati con la struttura.',
    i <= 22 and i % 2 = 0, 30 + (i % 4) * 15, 4 + (i % 9),
    3 + (i % 10), 2 + (i % 20),
    case modality_tag when 'online' then 'online'::treatment_modality
      when 'ibrido' then 'ibrido'::treatment_modality
      when 'domicilio' then 'domicilio'::treatment_modality
      else 'presenza'::treatment_modality end,
    'Valutazione iniziale e condivisione di condizioni rilevanti, terapie in corso e obiettivi realistici.',
    'Possibile supporto al benessere o alla funzione; gli esiti variano e non sono garantiti.',
    case when i % 2 = 0 then jsonb_build_array(
      jsonb_build_object('type','image','url','https://placehold.co/1200x800?text=Cura+demo+' || lpad(i::text,2,'0'),'caption','Immagine dimostrativa del percorso'),
      jsonb_build_object('type','image','url','https://placehold.co/800x800?text=Dettaglio+demo+' || lpad(i::text,2,'0'),'caption','Dettaglio dimostrativo'))
    else jsonb_build_array(
      jsonb_build_object('type','image','url','https://placehold.co/1200x800?text=Cura+demo+' || lpad(i::text,2,'0'),'caption','Immagine dimostrativa del percorso')) end,
    ('d0200000-0000-4000-8000-' || lpad((((i - 1) % 16) + 1)::text, 12, '0'))::uuid,
    ('f0200000-0000-4000-8000-' || lpad((((i - 1) % 10) + 1)::text, 12, '0'))::uuid,
    'published', 1, true, i <= 8,
    '2026-10-01 09:00:00+00'::timestamptz + (i || ' days')::interval
  from prepared
  on conflict (id) do update set
    title=excluded.title, summary=excluded.summary,
    description_sections=excluded.description_sections, family=excluded.family,
    scope=excluded.scope, category=excluded.category, conditions=excluded.conditions,
    tags=excluded.tags, evidence_level=excluded.evidence_level,
    contraindications=excluded.contraindications,
    price_from_cents=excluded.price_from_cents, price_to_cents=excluded.price_to_cents,
    currency=excluded.currency, price_notes=excluded.price_notes,
    ssn_covered=excluded.ssn_covered, session_minutes=excluded.session_minutes,
    sessions_count=excluded.sessions_count, course_weeks=excluded.course_weeks,
    waiting_days=excluded.waiting_days, modality=excluded.modality,
    requirements=excluded.requirements, expected_outcome=excluded.expected_outcome,
    media=excluded.media, doctor_id=excluded.doctor_id, facility_id=excluded.facility_id,
    status=excluded.status, version=excluded.version, is_demo=excluded.is_demo,
    featured=excluded.featured, published_at=excluded.published_at;

  -- Tre recensioni approvate per ciascuna cura: 120 in totale. I voti medi
  -- risultano compresi tra 4,00 e 4,67, con sottovoci distribuite tra 3 e 5.
  insert into public.reviews(id, author_id, target_type, target_id, rating, sub_ratings,
    title, body, status, verified, created_at)
  select ('e0200000-0000-4000-8000-' || lpad((((t.i - 1) * 3) + u.i)::text, 12, '0'))::uuid,
    ('a0200000-0000-4000-8000-' || lpad(u.i::text, 12, '0'))::uuid,
    'treatment', ('c0200000-0000-4000-8000-' || lpad(t.i::text, 12, '0'))::uuid,
    case when (t.i + u.i) % 3 = 0 then 5 else 4 end,
    jsonb_build_object(
      'efficacia', 3 + ((t.i + u.i) % 3),
      'costo', 3 + ((t.i + u.i + 1) % 3),
      'esperienza', 3 + ((t.i + u.i + 2) % 3),
      'chiarezza', 3 + ((t.i + u.i) % 3)),
    'Esperienza demo ' || t.i || '-' || u.i,
    'Recensione dimostrativa: il percorso e stato descritto con chiarezza; questa esperienza non permette di prevedere risultati per altre persone.',
    'approved', u.i = 1,
    '2026-10-10 10:00:00+00'::timestamptz + (((t.i - 1) * 3 + u.i) || ' hours')::interval
  from generate_series(1, 40) as t(i)
  cross join generate_series(1, 3) as u(i)
  on conflict (id) do update set
    author_id=excluded.author_id, target_type=excluded.target_type,
    target_id=excluded.target_id, rating=excluded.rating,
    sub_ratings=excluded.sub_ratings, title=excluded.title, body=excluded.body,
    status=excluded.status, verified=excluded.verified, created_at=excluded.created_at;

  insert into public.reviews(id, author_id, target_type, target_id, rating, sub_ratings,
    title, body, status, moderation_note, verified, created_at)
  select ('e0200000-0000-4000-8000-' || lpad((120 + i)::text, 12, '0'))::uuid,
    'a0200000-0000-4000-8000-000000000004', 'treatment',
    ('c0200000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
    3 + (i % 3), '{"efficacia":4,"costo":3,"esperienza":4,"chiarezza":4}',
    'Recensione demo in attesa ' || i,
    'Testo dimostrativo prudente in attesa di moderazione; non contiene indicazioni rivolte ad altre persone.',
    'pending', null, false,
    '2026-11-01 10:00:00+00'::timestamptz + (i || ' hours')::interval
  from generate_series(1, 10) as s(i)
  on conflict (id) do update set
    author_id=excluded.author_id, target_type=excluded.target_type,
    target_id=excluded.target_id, rating=excluded.rating,
    sub_ratings=excluded.sub_ratings, title=excluded.title, body=excluded.body,
    status=excluded.status, moderation_note=excluded.moderation_note,
    verified=excluded.verified, created_at=excluded.created_at;

  insert into public.reviews(id, author_id, target_type, target_id, rating, sub_ratings,
    title, body, status, moderation_note, moderated_at, verified, created_at)
  select ('e0200000-0000-4000-8000-' || lpad((130 + i)::text, 12, '0'))::uuid,
    'a0200000-0000-4000-8000-000000000005', 'treatment',
    ('c0200000-0000-4000-8000-' || lpad(i::text, 12, '0'))::uuid,
    2 + (i % 3), '{"efficacia":3,"costo":3,"esperienza":3,"chiarezza":3}',
    'Recensione demo non pubblicata ' || i,
    'Testo dimostrativo escluso dalla pubblicazione durante la moderazione del catalogo di prova.',
    'rejected', 'Contenuto dimostrativo non pubblicato.',
    '2026-11-05 10:00:00+00'::timestamptz, false,
    '2026-11-02 10:00:00+00'::timestamptz + (i || ' hours')::interval
  from generate_series(1, 4) as s(i)
  on conflict (id) do update set
    author_id=excluded.author_id, target_type=excluded.target_type,
    target_id=excluded.target_id, rating=excluded.rating,
    sub_ratings=excluded.sub_ratings, title=excluded.title, body=excluded.body,
    status=excluded.status, moderation_note=excluded.moderation_note,
    moderated_at=excluded.moderated_at, verified=excluded.verified,
    created_at=excluded.created_at;
end;
$$;

revoke execute on function public.m24_seed_0020_treatments_demo() from public, anon, authenticated;
grant execute on function public.m24_seed_0020_treatments_demo() to service_role;

select public.m24_seed_0020_treatments_demo();

insert into public.app_migrations(name)
values ('0020_treatments_seed')
on conflict do nothing;