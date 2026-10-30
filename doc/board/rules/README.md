# Regole del board — bozza v0.1 (30 ottobre 2026)

Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.

Questi file sono BOZZE preparate per il P05 a partire da fonti pubblicate. Sono marcati `status: draft` e vanno validati dal board scientifico prima di diventare `active`: i coefficienti vanno confrontati con le pubblicazioni originali e i punteggi con i calcolatori ufficiali su almeno 10 casi ciascuno (criterio del gate G1 nel MASTER).

| File | Regola | Fonte | Stato |
| --- | --- | --- | --- |
| `score2.json` | SCORE2, rischio cardiovascolare a 10 anni, 40–69 anni, regione a rischio moderato (Italia) | ESC 2021, Eur Heart J 42:2439 | coefficienti da verificare; SCORE2-OP (70+) non incluso |
| `findrisc.json` | FINDRISC, rischio di diabete di tipo 2 a 10 anni | Lindström & Tuomilehto, Diabetes Care 2003 | tabella dei punti, pubblica |
| `ckd_epi_2021.json` | eGFR CKD-EPI 2021 da creatinina, stadi KDIGO | Inker et al., NEJM 2021 | formula pubblica |
| `fracture_risk.json` | Fattori di rischio di frattura (checklist) + link a FRAX | FRAX non è reimplementabile (algoritmo proprietario) | regola di bozza da ricalibrare |
| `../prevention_calendar.csv` | Calendario della prevenzione per età e sesso | Programmi di screening del SSN, calendario vaccinale nazionale, linee guida ESC, SID/AMD, LEA | intervalli e fasce da confermare per Regione |

Convenzioni: unità canoniche del catalogo (`biomarker_catalog`); i livelli dell'app sono `low`, `medium`, `high` (mappa `app_levels_map` in ogni file); ogni regola porta `disclaimer_it`; i `test_cases` marcati `internal` verificano l'implementazione, non la correttezza clinica.

Stato nel database: 0011/0012, status draft. Casi di test eseguiti: sei `test_cases` di `fracture_risk.json`, casi interni di `score2.json`, `findrisc.json` e `ckd_epi_2021.json`, test pgTAP delle migrazioni 0011 e 0012.
