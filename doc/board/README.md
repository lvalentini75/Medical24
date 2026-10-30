# /docs/board — dati del board scientifico

## biomarker_catalog.csv (bozza del 24 ottobre 2026, da validare dal board)

73 biomarcatori ematici essenziali. Ogni riga ha status = draft e board_version = 0: entra nell'app come riferimento
istituzionale solo quando il board la porta a status = validated con una versione.

Colonne:
- code: codice LOINC (verificato su loinc.org); è la chiave.
- name_it, name_en: nome principale; synonyms_it, synonyms_en: sinonimi separati da ";" (servono al motore di lettura).
- category: ematologia, glicemia, lipidi, reni, elettroliti, fegato, pancreas, muscle, tiroide, ferro, vitamine, infiammazione, coagulazione, ormoni, oncologia.
- unit_canonical: unità UCUM in cui il valore viene conservato.
- unit_alternatives: "unità:fattore" separate da ";": valore_canonico = valore_letto x fattore quando l'unità letta è quella alternativa
  (es. glucosio: 1 mmol/L x 18.016 = 18.016 mg/dL). "IFCC" per HbA1c indica la formula inversa (% = (mmol/mol + 23.5) / 10.93).
- ref_low_m, ref_high_m, ref_low_f, ref_high_f: intervallo di riferimento istituzionale per adulti, uomini e donne; vuoto = nessun limite da quel lato.
- age_note: eccezioni per età o condizione, in parole, da trasformare in regole dal board.
- plausible_min, plausible_max: limiti di plausibilità fisica usati per scartare letture errate (fuori = da verificare).
- safety_low, safety_high: limiti di sicurezza; un valore oltre questi è sempre un avviso critico e nessuna soglia del medico può spegnerlo.
- organs: aree del corpo collegate (chiavi: heart, liver, kidney, thyroid, pancreas, blood, bone, immune, prostate, reproductive, muscle, metabolism).
- notes: avvertenze per il board e per i testi dell'app.

Gli intervalli sono quelli di uso comune nei laboratori italiani per adulti e NON sono ancora validati: il board li conferma o li
corregge riga per riga, aggiunge gli intervalli per fasce di età e i biomarcatori mancanti (urine, marcatori tumorali, vitamine
e ormoni aggiuntivi, fino ai 200 essenziali previsti dal progetto).