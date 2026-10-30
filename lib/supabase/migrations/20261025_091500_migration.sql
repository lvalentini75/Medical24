-- ============================================================================
-- Medical 24 — 0006 BIOMARKER CATALOG SEED (P02-A)
--
-- Sorgente: doc/board/biomarker_catalog.csv (bozza del board, 24/10/2026).
-- Righe nel CSV: 73. Righe importate: 73. Righe illeggibili: 0.
-- Tutte le righe entrano con status = 'draft' e board_version = 0 e restano
-- così finché il board non le valida: fino ad allora il catalogo non è un
-- riferimento istituzionale e l'app lo dichiara.
--
-- Il seed è idempotente: on conflict (code) do update riallinea la riga al
-- CSV senza toccare righe aggiunte dal board.
--
-- unit_alternatives: mappa "unità letta" -> fattore moltiplicativo verso
-- unit_canonical. Il valore "IFCC" (HbA1c) indica la formula
-- % = (mmol/mol + 23.5) / 10.93, applicata da public.normalize_unit.
-- ============================================================================

insert into public.biomarker_catalog (
  code, name_it, name_en, synonyms_it, synonyms_en, category,
  unit_canonical, unit_alternatives,
  ref_low_m, ref_high_m, ref_low_f, ref_high_f, age_note,
  plausible_min, plausible_max, safety_low, safety_high,
  organs, notes, status, board_version
) values
-- ematologia -----------------------------------------------------------------
('718-7', 'Emoglobina', 'Hemoglobin',
 array['Hb','HGB','emoglobina'], array['Hb','HGB'], 'ematologia',
 'g/dL', '{"g/L":0.1,"mmol/L":1.611}'::jsonb,
 13.5, 17.5, 12.0, 16.0, null, 3, 25, 7, 20, array['blood'], null, 'draft', 0),

('4544-3', 'Ematocrito', 'Hematocrit',
 array['Hct','HCT','ematocrito'], array['Hct','HCT','PCV'], 'ematologia',
 '%', '{"L/L":100}'::jsonb,
 40, 52, 36, 46, null, 10, 70, null, null, array['blood'], null, 'draft', 0),

('789-8', 'Eritrociti', 'Erythrocytes (RBC)',
 array['globuli rossi','RBC','GR'], array['RBC','red blood cells'], 'ematologia',
 '10*6/uL', '{"10*12/L":1}'::jsonb,
 4.5, 5.9, 4.0, 5.2, null, 1, 8, null, null, array['blood'], null, 'draft', 0),

('6690-2', 'Leucociti', 'Leukocytes (WBC)',
 array['globuli bianchi','WBC','GB'], array['WBC','white blood cells'], 'ematologia',
 '10*3/uL', '{"10*9/L":1,"/uL":0.001}'::jsonb,
 4.0, 10.0, 4.0, 10.0, null, 0.1, 200, 1.0, 50, array['blood','immune'], null, 'draft', 0),

('777-3', 'Piastrine', 'Platelets',
 array['PLT','trombociti'], array['PLT','thrombocytes'], 'ematologia',
 '10*3/uL', '{"10*9/L":1,"/uL":0.001}'::jsonb,
 150, 400, 150, 400, null, 5, 2000, 30, 1000, array['blood'], null, 'draft', 0),

('787-2', 'MCV', 'MCV (mean corpuscular volume)',
 array['volume corpuscolare medio','VCM'], array['mean cell volume'], 'ematologia',
 'fL', '{}'::jsonb,
 80, 100, 80, 100, null, 40, 150, null, null, array['blood'], null, 'draft', 0),

('785-6', 'MCH', 'MCH (mean corpuscular hemoglobin)',
 array['emoglobina corpuscolare media','HCM'], array['mean cell hemoglobin'], 'ematologia',
 'pg', '{}'::jsonb,
 27, 33, 27, 33, null, 10, 50, null, null, array['blood'], null, 'draft', 0),

('786-4', 'MCHC', 'MCHC',
 array['concentrazione emoglobinica corpuscolare media','CHCM'],
 array['mean cell hemoglobin concentration'], 'ematologia',
 'g/dL', '{"g/L":0.1}'::jsonb,
 32, 36, 32, 36, null, 20, 45, null, null, array['blood'], null, 'draft', 0),

('788-0', 'RDW', 'RDW (red cell distribution width)',
 array['ampiezza di distribuzione eritrocitaria','RDW-CV'], array['RDW-CV'], 'ematologia',
 '%', '{}'::jsonb,
 11.5, 14.5, 11.5, 14.5, null, 5, 40, null, null, array['blood'], null, 'draft', 0),

('751-8', 'Neutrofili', 'Neutrophils (absolute)',
 array['granulociti neutrofili','neutrofili assoluti'], array['ANC','neutrophil count'],
 'ematologia', '10*3/uL', '{"10*9/L":1,"/uL":0.001}'::jsonb,
 1.8, 7.5, 1.8, 7.5, null, 0, 100, 0.5, null, array['blood','immune'],
 'conta assoluta, non percentuale', 'draft', 0),

('731-0', 'Linfociti', 'Lymphocytes (absolute)',
 array['linfociti assoluti'], array['lymphocyte count'], 'ematologia',
 '10*3/uL', '{"10*9/L":1,"/uL":0.001}'::jsonb,
 1.0, 4.0, 1.0, 4.0, null, 0, 100, null, null, array['blood','immune'],
 'conta assoluta', 'draft', 0),

('742-7', 'Monociti', 'Monocytes (absolute)',
 array['monociti assoluti'], array['monocyte count'], 'ematologia',
 '10*3/uL', '{"10*9/L":1,"/uL":0.001}'::jsonb,
 0.2, 0.8, 0.2, 0.8, null, 0, 20, null, null, array['blood','immune'],
 'conta assoluta', 'draft', 0),

('711-2', 'Eosinofili', 'Eosinophils (absolute)',
 array['eosinofili assoluti'], array['eosinophil count'], 'ematologia',
 '10*3/uL', '{"10*9/L":1,"/uL":0.001}'::jsonb,
 0.0, 0.5, 0.0, 0.5, null, 0, 20, null, null, array['blood','immune'],
 'conta assoluta', 'draft', 0),

('704-7', 'Basofili', 'Basophils (absolute)',
 array['basofili assoluti'], array['basophil count'], 'ematologia',
 '10*3/uL', '{"10*9/L":1,"/uL":0.001}'::jsonb,
 0.0, 0.2, 0.0, 0.2, null, 0, 5, null, null, array['blood','immune'],
 'conta assoluta', 'draft', 0),

-- infiammazione / VES --------------------------------------------------------
('4537-7', 'VES', 'ESR (Westergren)',
 array['velocità di eritrosedimentazione','VES 1h'],
 array['erythrocyte sedimentation rate'], 'infiammazione',
 'mm/h', '{}'::jsonb,
 0, 15, 0, 20, 'sopra i 50 anni: M fino a 20, F fino a 30',
 0, 150, null, null, array['immune'], null, 'draft', 0),

-- glicemia -------------------------------------------------------------------
('2345-7', 'Glicemia', 'Glucose',
 array['glucosio','glucosio a digiuno','glicemia basale'],
 array['glucose','fasting glucose','FBG'], 'glicemia',
 'mg/dL', '{"mmol/L":18.016}'::jsonb,
 70, 99, 70, 99, 'a digiuno', 20, 1000, 50, 400, array['pancreas','metabolism'],
 'intervallo a digiuno; 100-125 alterata, >=126 da confermare con il medico', 'draft', 0),

('4548-4', 'Emoglobina glicata', 'Hemoglobin A1c',
 array['HbA1c','emoglobina glicosilata','A1c'],
 array['HbA1c','A1c','glycated hemoglobin'], 'glicemia',
 '%', '{"mmol/mol":"IFCC"}'::jsonb,
 4.0, 5.6, 4.0, 5.6, null, 3, 20, null, null, array['pancreas','metabolism'],
 'conversione IFCC: mmol/mol = (% x 10.93) - 23.5; 5.7-6.4 prediabete secondo ADA',
 'draft', 0),

('20448-7', 'Insulina', 'Insulin',
 array['insulinemia','insulina a digiuno'], array['insulin','fasting insulin'],
 'glicemia', 'u[IU]/mL', '{"pmol/L":0.144}'::jsonb,
 2, 25, 2, 25, 'a digiuno', 0, 300, null, null, array['pancreas','metabolism'],
 null, 'draft', 0),

-- lipidi ---------------------------------------------------------------------
('2093-3', 'Colesterolo totale', 'Cholesterol, total',
 array['colesterolemia','colesterolo'], array['total cholesterol','TC'], 'lipidi',
 'mg/dL', '{"mmol/L":38.67}'::jsonb,
 null, 200, null, 200, null, 50, 800, null, null, array['heart','metabolism'],
 'desiderabile <200', 'draft', 0),

('2085-9', 'Colesterolo HDL', 'Cholesterol in HDL',
 array['HDL','colesterolo buono'], array['HDL-C','HDL cholesterol'], 'lipidi',
 'mg/dL', '{"mmol/L":38.67}'::jsonb,
 40, null, 50, null, null, 5, 150, null, null, array['heart','metabolism'],
 'desiderabile: M >40, F >50', 'draft', 0),

('13457-7', 'Colesterolo LDL (calcolato)', 'Cholesterol in LDL by calculation',
 array['LDL','colesterolo cattivo','LDL calcolato','Friedewald'],
 array['LDL-C','LDL cholesterol calculated'], 'lipidi',
 'mg/dL', '{"mmol/L":38.67}'::jsonb,
 null, 116, null, 116, null, 10, 600, null, null, array['heart','metabolism'],
 'obiettivo dipende dal rischio cardiovascolare (ESC/EAS 2019): <116 rischio basso, <100 moderato, <70 alto, <55 molto alto',
 'draft', 0),

('2089-1', 'Colesterolo LDL (diretto)', 'Cholesterol in LDL, direct',
 array['LDL diretto'], array['LDL-C direct'], 'lipidi',
 'mg/dL', '{"mmol/L":38.67}'::jsonb,
 null, 116, null, 116, null, 10, 600, null, null, array['heart','metabolism'],
 'come 13457-7, misurato direttamente', 'draft', 0),

('2571-8', 'Trigliceridi', 'Triglycerides',
 array['trigliceridemia','TG'], array['TG','triglycerides'], 'lipidi',
 'mg/dL', '{"mmol/L":88.57}'::jsonb,
 null, 150, null, 150, 'a digiuno', 20, 5000, null, 1000,
 array['heart','metabolism','pancreas'],
 'desiderabile <150; >=500 rischio di pancreatite', 'draft', 0),

('10835-7', 'Lipoproteina (a)', 'Lipoprotein (a)',
 array['Lp(a)'], array['Lp(a)'], 'lipidi',
 'mg/dL', '{"nmol/L":0.4167}'::jsonb,
 null, 30, null, 30, null, 0, 500, null, null, array['heart'],
 'valore unico nella vita; desiderabile <30 mg/dL (<75 nmol/L)', 'draft', 0),

('1884-6', 'Apolipoproteina B', 'Apolipoprotein B',
 array['ApoB','apo B'], array['ApoB'], 'lipidi',
 'mg/dL', '{"g/L":100}'::jsonb,
 null, 100, null, 100, null, 10, 300, null, null, array['heart'],
 'desiderabile <100; <80 ad alto rischio, <65 a rischio molto alto', 'draft', 0),

-- reni -----------------------------------------------------------------------
('2160-0', 'Creatinina', 'Creatinine',
 array['creatininemia','creatinina sierica'], array['creatinine','serum creatinine'],
 'reni', 'mg/dL', '{"umol/L":0.01131}'::jsonb,
 0.7, 1.2, 0.5, 1.0, null, 0.1, 30, null, 5, array['kidney'], null, 'draft', 0),

('98979-8', 'eGFR (CKD-EPI 2021)', 'eGFR (CKD-EPI 2021)',
 array['filtrato glomerulare stimato','VFG','GFR stimato','clearance stimata'],
 array['eGFR','estimated GFR'], 'reni',
 'mL/min/{1.73_m2}', '{}'::jsonb,
 90, null, 90, null, 'sopra i 65 anni valori 60-89 frequenti',
 1, 200, 15, null, array['kidney'],
 '>=90 normale; 60-89 lieve riduzione; <60 da valutare con il medico; calcolo da creatinina, età e sesso',
 'draft', 0),

('3091-6', 'Urea (azotemia)', 'Urea',
 array['azotemia','urea sierica'], array['urea','blood urea'], 'reni',
 'mg/dL', '{"mmol/L":6.006,"BUN mg/dL":2.14}'::jsonb,
 17, 49, 17, 49, null, 2, 400, null, null, array['kidney'],
 'BUN = urea / 2.14', 'draft', 0),

('3084-1', 'Acido urico', 'Uric acid',
 array['uricemia','urato'], array['urate','uric acid'], 'reni;metabolism',
 'mg/dL', '{"umol/L":0.01681}'::jsonb,
 3.5, 7.2, 2.6, 6.0, null, 0.5, 25, null, null,
 array['kidney','metabolism','bone'], null, 'draft', 0),

-- elettroliti ----------------------------------------------------------------
('2951-2', 'Sodio', 'Sodium',
 array['natriemia','Na'], array['Na','sodium'], 'elettroliti',
 'mmol/L', '{"mEq/L":1}'::jsonb,
 136, 145, 136, 145, null, 100, 180, 120, 160, array['kidney','heart'], null, 'draft', 0),

('2823-3', 'Potassio', 'Potassium',
 array['potassiemia','K','kaliemia'], array['K','potassium'], 'elettroliti',
 'mmol/L', '{"mEq/L":1}'::jsonb,
 3.5, 5.1, 3.5, 5.1, null, 1.5, 10, 2.5, 6.5, array['kidney','heart'], null, 'draft', 0),

('2075-0', 'Cloro', 'Chloride',
 array['cloremia','Cl'], array['Cl','chloride'], 'elettroliti',
 'mmol/L', '{"mEq/L":1}'::jsonb,
 98, 107, 98, 107, null, 60, 140, null, null, array['kidney'], null, 'draft', 0),

('17861-6', 'Calcio', 'Calcium',
 array['calcemia','Ca','calcio totale'], array['Ca','calcium'], 'elettroliti',
 'mg/dL', '{"mmol/L":4.008}'::jsonb,
 8.6, 10.2, 8.6, 10.2, null, 4, 18, 6, 13, array['bone','kidney'],
 'calcio totale, non ionizzato', 'draft', 0),

('19123-9', 'Magnesio', 'Magnesium',
 array['magnesiemia','Mg'], array['Mg','magnesium'], 'elettroliti',
 'mg/dL', '{"mmol/L":2.431,"mEq/L":1.215}'::jsonb,
 1.7, 2.4, 1.7, 2.4, null, 0.5, 8, null, null,
 array['kidney','heart','muscle'], null, 'draft', 0),

('2777-1', 'Fosforo', 'Phosphate',
 array['fosforemia','fosfato','P'], array['phosphorus','phosphate'], 'elettroliti',
 'mg/dL', '{"mmol/L":3.097}'::jsonb,
 2.5, 4.5, 2.5, 4.5, null, 0.5, 15, null, null, array['bone','kidney'], null, 'draft', 0),

-- fegato ---------------------------------------------------------------------
('1920-8', 'AST (GOT)', 'AST (SGOT)',
 array['transaminasi GOT','aspartato aminotransferasi','SGOT'],
 array['AST','aspartate aminotransferase'], 'fegato',
 'U/L', '{"ukat/L":60}'::jsonb,
 null, 40, null, 32, null, 1, 20000, null, null,
 array['liver','muscle','heart'], null, 'draft', 0),

('1742-6', 'ALT (GPT)', 'ALT (SGPT)',
 array['transaminasi GPT','alanina aminotransferasi','SGPT'],
 array['ALT','alanine aminotransferase'], 'fegato',
 'U/L', '{"ukat/L":60}'::jsonb,
 null, 41, null, 33, null, 1, 20000, null, null, array['liver'], null, 'draft', 0),

('2324-2', 'Gamma GT', 'Gamma glutamyl transferase',
 array['GGT','gamma glutamil transferasi','γGT'], array['GGT'], 'fegato',
 'U/L', '{"ukat/L":60}'::jsonb,
 10, 71, 6, 42, null, 1, 5000, null, null, array['liver'], null, 'draft', 0),

('6768-6', 'Fosfatasi alcalina', 'Alkaline phosphatase',
 array['ALP','fosfatasi alcalina totale'], array['ALP','alk phos'], 'fegato',
 'U/L', '{"ukat/L":60}'::jsonb,
 40, 130, 35, 105, 'adolescenti in crescita: valori più alti',
 5, 3000, null, null, array['liver','bone'], null, 'draft', 0),

('1975-2', 'Bilirubina totale', 'Bilirubin, total',
 array['bilirubinemia totale'], array['total bilirubin'], 'fegato',
 'mg/dL', '{"umol/L":0.05848}'::jsonb,
 0.2, 1.2, 0.2, 1.2, null, 0, 50, null, null, array['liver'], null, 'draft', 0),

('1968-7', 'Bilirubina diretta', 'Bilirubin, direct',
 array['bilirubina coniugata'], array['direct bilirubin','conjugated bilirubin'],
 'fegato', 'mg/dL', '{"umol/L":0.05848}'::jsonb,
 0, 0.3, 0, 0.3, null, 0, 30, null, null, array['liver'], null, 'draft', 0),

('1751-7', 'Albumina', 'Albumin',
 array['albuminemia'], array['albumin','serum albumin'], 'fegato',
 'g/dL', '{"g/L":0.1}'::jsonb,
 3.5, 5.0, 3.5, 5.0, null, 1, 7, null, null, array['liver','kidney'], null, 'draft', 0),

('2885-2', 'Proteine totali', 'Protein, total',
 array['protidemia','proteine totali sieriche'], array['total protein'], 'fegato',
 'g/dL', '{"g/L":0.1}'::jsonb,
 6.4, 8.3, 6.4, 8.3, null, 2, 12, null, null, array['liver','kidney'], null, 'draft', 0),

('2532-0', 'LDH', 'Lactate dehydrogenase',
 array['lattato deidrogenasi','LDH totale'], array['LDH','LD'], 'fegato;muscle',
 'U/L', '{"ukat/L":60}'::jsonb,
 135, 225, 135, 225, null, 20, 10000, null, null,
 array['liver','muscle','blood'], 'intervallo dipende dal metodo', 'draft', 0),

-- pancreas -------------------------------------------------------------------
('1798-8', 'Amilasi', 'Amylase',
 array['amilasemia','amilasi totale'], array['amylase'], 'pancreas',
 'U/L', '{"ukat/L":60}'::jsonb,
 28, 100, 28, 100, null, 1, 5000, null, null, array['pancreas'], null, 'draft', 0),

('3040-3', 'Lipasi', 'Lipase',
 array['lipasemia'], array['lipase'], 'pancreas',
 'U/L', '{"ukat/L":60}'::jsonb,
 13, 60, 13, 60, null, 1, 5000, null, null, array['pancreas'], null, 'draft', 0),

-- muscolo --------------------------------------------------------------------
('2157-6', 'CK (CPK)', 'Creatine kinase',
 array['creatinchinasi','CPK','creatinfosfochinasi'],
 array['CK','CPK','creatine kinase'], 'muscle',
 'U/L', '{"ukat/L":60}'::jsonb,
 39, 308, 26, 192, null, 5, 100000, null, null, array['muscle','heart'],
 null, 'draft', 0),

-- tiroide --------------------------------------------------------------------
('3016-3', 'TSH', 'TSH',
 array['tireotropina','ormone tireostimolante'], array['thyrotropin','TSH'], 'tiroide',
 'm[IU]/L', '{"u[IU]/mL":1}'::jsonb,
 0.27, 4.2, 0.27, 4.2, 'gravidanza: intervalli per trimestre',
 0.005, 200, null, null, array['thyroid'], null, 'draft', 0),

('3024-7', 'FT4', 'Free T4',
 array['tiroxina libera','T4 libero'], array['free thyroxine'], 'tiroide',
 'ng/dL', '{"pmol/L":0.0777}'::jsonb,
 0.93, 1.7, 0.93, 1.7, null, 0.1, 10, null, null, array['thyroid'], null, 'draft', 0),

('3051-0', 'FT3', 'Free T3',
 array['triiodotironina libera','T3 libero'], array['free triiodothyronine'], 'tiroide',
 'pg/mL', '{"pmol/L":0.651}'::jsonb,
 2.0, 4.4, 2.0, 4.4, null, 0.1, 30, null, null, array['thyroid'], null, 'draft', 0),

-- ferro ----------------------------------------------------------------------
('2498-4', 'Sideremia', 'Iron',
 array['ferro sierico','ferro'], array['serum iron'], 'ferro',
 'ug/dL', '{"umol/L":5.587}'::jsonb,
 59, 158, 37, 145, null, 5, 1000, null, null, array['blood','liver'], null, 'draft', 0),

('2276-4', 'Ferritina', 'Ferritin',
 array['ferritinemia'], array['ferritin'], 'ferro',
 'ng/mL', '{"ug/L":1,"pmol/L":0.445}'::jsonb,
 30, 400, 13, 150, null, 1, 20000, null, null, array['blood','liver'], null, 'draft', 0),

('3034-6', 'Transferrina', 'Transferrin',
 array['transferrinemia'], array['transferrin'], 'ferro',
 'mg/dL', '{"g/L":100,"umol/L":7.87}'::jsonb,
 200, 360, 200, 360, null, 50, 700, null, null, array['blood','liver'], null, 'draft', 0),

('2502-3', 'Saturazione della transferrina', 'Iron saturation',
 array['saturazione transferrina','TSAT'], array['transferrin saturation','TSAT'],
 'ferro', '%', '{}'::jsonb,
 20, 50, 15, 50, null, 1, 100, null, null, array['blood','liver'], null, 'draft', 0),

('2500-7', 'TIBC', 'Iron binding capacity',
 array['capacità totale legante il ferro'], array['TIBC'], 'ferro',
 'ug/dL', '{"umol/L":5.587}'::jsonb,
 250, 450, 250, 450, null, 50, 900, null, null, array['blood'], null, 'draft', 0),

-- vitamine -------------------------------------------------------------------
('2132-9', 'Vitamina B12', 'Vitamin B12',
 array['cobalamina','B12'], array['cobalamin','B12'], 'vitamine',
 'pg/mL', '{"pmol/L":1.355}'::jsonb,
 197, 771, 197, 771, null, 20, 5000, null, null, array['blood'], null, 'draft', 0),

('2284-8', 'Folati', 'Folate',
 array['acido folico','folato sierico'], array['folic acid','serum folate'], 'vitamine',
 'ng/mL', '{"nmol/L":0.4413}'::jsonb,
 3.9, 26.8, 3.9, 26.8, null, 0.1, 100, null, null, array['blood'], null, 'draft', 0),

('62292-8', 'Vitamina D (25-OH)', '25-Hydroxyvitamin D (D2+D3)',
 array['25-idrossivitamina D','25-OH-D','calcifediolo'],
 array['25-OH vitamin D','calcidiol'], 'vitamine',
 'ng/mL', '{"nmol/L":0.4006}'::jsonb,
 30, 100, 30, 100, null, 1, 300, null, null, array['bone','immune'],
 '20-30 insufficienza; <20 carenza; sufficienza >=30 (soglie da confermare dal board)',
 'draft', 0),

-- infiammazione --------------------------------------------------------------
('1988-5', 'Proteina C reattiva', 'C reactive protein',
 array['PCR','CRP'], array['CRP'], 'infiammazione',
 'mg/L', '{"mg/dL":10}'::jsonb,
 null, 5, null, 5, null, 0, 1000, null, null, array['immune'], null, 'draft', 0),

('30522-7', 'PCR ad alta sensibilità', 'hs-CRP',
 array['hs-PCR','PCR ultrasensibile'], array['hs-CRP'], 'infiammazione',
 'mg/L', '{"mg/dL":10}'::jsonb,
 null, 3, null, 3, null, 0, 100, null, null, array['heart','immune'],
 'rischio cardiovascolare: <1 basso, 1-3 medio, >3 alto', 'draft', 0),

('13965-9', 'Omocisteina', 'Homocysteine',
 array['omocisteinemia'], array['homocysteine'], 'infiammazione',
 'umol/L', '{"mg/L":7.397}'::jsonb,
 5, 15, 5, 15, null, 1, 500, null, null, array['heart','blood'], null, 'draft', 0),

-- coagulazione ---------------------------------------------------------------
('5902-2', 'Tempo di protrombina', 'Prothrombin time',
 array['PT','tempo di Quick'], array['PT'], 'coagulazione',
 's', '{}'::jsonb,
 11, 13.5, 11, 13.5, null, 5, 120, null, null, array['blood','liver'], null, 'draft', 0),

('6301-6', 'INR', 'INR',
 array['rapporto internazionale normalizzato','PT INR'], array['INR'], 'coagulazione',
 '{INR}', '{}'::jsonb,
 0.8, 1.2, 0.8, 1.2, 'in terapia anticoagulante l intervallo lo fissa il medico',
 0.5, 20, null, 5, array['blood','liver'], null, 'draft', 0),

('3173-2', 'aPTT', 'aPTT',
 array['tempo di tromboplastina parziale attivata','PTT'],
 array['activated partial thromboplastin time'], 'coagulazione',
 's', '{}'::jsonb,
 25, 35, 25, 35, null, 10, 300, null, null, array['blood'], null, 'draft', 0),

('3255-7', 'Fibrinogeno', 'Fibrinogen',
 array['fibrinogenemia'], array['fibrinogen'], 'coagulazione',
 'mg/dL', '{"g/L":100}'::jsonb,
 200, 400, 200, 400, null, 20, 1500, 100, null, array['blood','liver'], null, 'draft', 0),

('48065-7', 'D-dimero', 'D-dimer (FEU)',
 array['D-dimeri','DD'], array['D-dimer'], 'coagulazione',
 'ug/mL{FEU}', '{"ng/mL{FEU}":0.001}'::jsonb,
 null, 0.5, null, 0.5, 'sopra i 50 anni: soglia età x 0.01',
 0, 100, null, null, array['blood','heart'], null, 'draft', 0),

-- ormoni ---------------------------------------------------------------------
('2143-6', 'Cortisolo (mattino)', 'Cortisol (morning)',
 array['cortisolemia','cortisolo ore 8'], array['cortisol'], 'ormoni',
 'ug/dL', '{"nmol/L":0.03625}'::jsonb,
 6.2, 19.4, 6.2, 19.4, 'prelievo del mattino', 0.1, 150, null, null,
 array['immune','metabolism'], null, 'draft', 0),

('2986-8', 'Testosterone totale', 'Testosterone, total',
 array['testosteronemia'], array['testosterone'], 'ormoni',
 'ng/dL', '{"nmol/L":28.84,"ng/mL":100}'::jsonb,
 264, 916, 15, 70, 'adulti; cala con l età', 1, 3000, null, null,
 array['reproductive'], null, 'draft', 0),

('2243-4', 'Estradiolo', 'Estradiol',
 array['E2','17-beta estradiolo'], array['E2','estradiol'], 'ormoni',
 'pg/mL', '{"pmol/L":0.2724}'::jsonb,
 11, 44, null, null,
 'donne: dipende dalla fase del ciclo (follicolare 12-166, luteale 44-211, postmenopausa <40)',
 1, 5000, null, null, array['reproductive'], null, 'draft', 0),

('15067-2', 'FSH', 'FSH',
 array['ormone follicolo-stimolante','follitropina'],
 array['follicle stimulating hormone'], 'ormoni',
 'm[IU]/mL', '{"[IU]/L":1}'::jsonb,
 1.5, 12.4, null, null,
 'donne: follicolare 3.5-12.5, postmenopausa 25.8-134.8',
 0.1, 300, null, null, array['reproductive'], null, 'draft', 0),

('10501-5', 'LH', 'LH',
 array['ormone luteinizzante','lutropina'], array['luteinizing hormone'], 'ormoni',
 'm[IU]/mL', '{"[IU]/L":1}'::jsonb,
 1.7, 8.6, null, null,
 'donne: follicolare 2.4-12.6, picco ovulatorio 14-96, postmenopausa 7.7-58.5',
 0.1, 300, null, null, array['reproductive'], null, 'draft', 0),

('2842-3', 'Prolattina', 'Prolactin',
 array['PRL','prolattinemia'], array['PRL','prolactin'], 'ormoni',
 'ng/mL', '{"m[IU]/L":0.04717}'::jsonb,
 4, 15, 5, 23, null, 0.5, 2000, null, null, array['reproductive'], null, 'draft', 0),

-- oncologia ------------------------------------------------------------------
('2857-1', 'PSA totale', 'PSA, total',
 array['antigene prostatico specifico','PSA'], array['prostate specific antigen'],
 'oncologia', 'ng/mL', '{"ug/L":1}'::jsonb,
 null, 4, null, null,
 'solo uomini; per età: 40-49 <2.5, 50-59 <3.5, 60-69 <4.5, 70+ <6.5',
 0, 5000, null, null, array['prostate'], null, 'draft', 0)

on conflict (code) do update set
  name_it           = excluded.name_it,
  name_en           = excluded.name_en,
  synonyms_it       = excluded.synonyms_it,
  synonyms_en       = excluded.synonyms_en,
  category          = excluded.category,
  unit_canonical    = excluded.unit_canonical,
  unit_alternatives = excluded.unit_alternatives,
  ref_low_m         = excluded.ref_low_m,
  ref_high_m        = excluded.ref_high_m,
  ref_low_f         = excluded.ref_low_f,
  ref_high_f        = excluded.ref_high_f,
  age_note          = excluded.age_note,
  plausible_min     = excluded.plausible_min,
  plausible_max     = excluded.plausible_max,
  safety_low        = excluded.safety_low,
  safety_high       = excluded.safety_high,
  organs            = excluded.organs,
  notes             = excluded.notes;

-- Controllo del seed: deve stampare 73.
do $$
declare
  n int;
begin
  select count(*) into n from public.biomarker_catalog;
  raise notice 'biomarker_catalog: % righe presenti (attese almeno 73)', n;
end $$;

insert into public.app_migrations (name)
values ('0006_biomarker_catalog_seed_20261025_091500')
on conflict do nothing;
