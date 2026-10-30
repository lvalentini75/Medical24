# Medical 24 — Design system "Calm Health" v1.0 (29 ottobre 2026)

Progettazione e realizzazione: Tattica Web — progettista Luca Valentini.

Questo file è la fonte di verità per l'aspetto dell'app, su telefono, tablet e desktop. I riferimenti visivi sono i mockup in `doc/design/` (telefono 430×932 pt a 2×, desktop 1920×1080 scalato a 1672 px: le misure in pixel delle immagini desktop vanno moltiplicate per 1,15). I token qui sotto sono stati campionati da quei mockup: dove il mockup e questo file dovessero divergere di pochi punti, vale questo file, perché un'app ha bisogno di una scala coerente più che di una copia pixel per pixel di ogni immagine.

Regole di lettura per l'agente:

- I mockup contengono anche moduli che non esistono ancora (Prevenzione, Alimentazione, Academy, Cure, Medico, Televisita): sono il riferimento per quando verranno costruiti. Non si creano schermate, voci di menu, card o pulsanti per funzioni che non hanno un backend: niente facciate.
- Il chip "Dati dimostrativi" e la dicitura "demo" nei mockup sono un artefatto delle immagini: nell'app non esistono.
- Tutto ciò che è clinico porta il disclaimer. Sul desktop è la riga a piè di pagina; sul telefono è la barra `M24Disclaimer` in fondo alla schermata.

## 1. Colori

Modalità chiara (riferimento). Hex esatti.

| Token | Hex | Uso |
| --- | --- | --- |
| `bg` | `#F8F8F6` | Sfondo di pagina e della top bar desktop |
| `surface` | `#FFFFFF` | Card, barre di navigazione, sidebar, campi, fogli |
| `surfaceAlt` | `#F3F5F7` | Intestazioni delle tabelle, hover delle righe, sfondi secondari |
| `surfaceMuted` | `#EFF2F5` | Barra del disclaimer, stati neutri |
| `border` | `#E6E9EE` | Bordo 1 px di card, campi, chip in outline, sidebar |
| `divider` | `#EEF0F3` | Separatori interni alle liste e alle tabelle |
| `ink` | `#0B1B33` | Titoli, testo primario, icone principali, wordmark "Medical" |
| `inkSecondary` | `#4F5B7A` | Sottotitoli, testo secondario, icone di navigazione inattive |
| `inkMuted` | `#6B7590` | Didascalie, placeholder, piè di pagina, etichette degli assi |
| `primary` | `#007F88` | Pulsanti principali, tab e voce attiva, wordmark "24", link in teal |
| `primaryHover` | `#00737B` | Hover dei pulsanti principali |
| `primaryPressed` | `#006770` | Pressed dei pulsanti principali |
| `primaryTint` | `#E4F4F4` | Sfondo di chip selezionati, segmento attivo, riga selezionata in tabella (`#DCF3F4`) |
| `primarySoft` | `#E1F6F7` | Voce attiva della sidebar e della bottom bar, tile data in teal |
| `primaryInk` | `#005E62` | Testo e icona sopra `primaryTint` |
| `chart` | `#0A949A` | Linea dei grafici; area sotto la linea: gradiente da `#0A949A` al 22% a trasparente |
| `success` | `#0F9B8E` | Icone e testo "Analizzato", "Confermato", stato ok |
| `successTint` | `#E8F7F4` | Sfondo dei pill di successo e delle tile icona verdi |
| `successInk` | `#00565C` | Testo sopra `successTint` quando serve più contrasto |
| `info` | `#0B66E6` | Link di azione ("Vedi tutte", "Apri lo storico"), icone "Archiviato", "Programmata" |
| `infoTint` | `#E6F1FE` | Sfondo dei pill e delle tile icona blu |
| `infoInk` | `#0047C2` | Testo sopra `infoTint` |
| `warning` | `#E9700C` | Pulsante "Verifica", icone e punto dei pill "Da verificare", "Quadro parziale" |
| `warningTint` | `#FEF1E3` | Sfondo dei pill e dei banner arancioni; banner grandi `#FEF8F1` |
| `warningInk` | `#B9400A` | Testo sopra `warningTint` |
| `danger` | `#DC2F1A` | Stati critical, pulsante "Revoca", "Termina" |
| `dangerTint` | `#FDEDEA` | Sfondo dei pill e dei pulsanti outline rossi |
| `dangerInk` | `#B3200C` | Testo sopra `dangerTint` |
| `neutral` | `#3B4A6B` | Testo dei pill neutri ("Da concordare", dato mancante) |
| `neutralTint` | `#EDEEF2` | Sfondo dei pill neutri e dei punti "dato mancante" |
| `indigo` / `indigoTint` | `#4F46E5` / `#EEEBFF` | Riservato all'Academy (quando arriverà) |
| `avatarBg` | `#E5E6EA` | Sfondo dell'avatar con le iniziali in `ink` |
| `overlay` | `#0B1B33` al 40% | Sfondo dietro ai fogli modali |
| `focusRing` | `primary` al 40%, 2 px | Anello di focus da tastiera |

Modalità scura: stessi ruoli con questa mappa, nessun colore inventato altrove. `bg #0F1621`, `surface #161F2E`, `surfaceAlt #1C2637`, `surfaceMuted #1A2334`, `border #263143`, `divider #212B3C`, `ink #F3F5F8`, `inkSecondary #AEB7C8`, `inkMuted #8792A8`, `primary #2AA7AE`, `primaryTint` = primary al 16% su surface, `primarySoft` = primary al 22%, `primaryInk #9ADFE3`, `chart #2AA7AE`; i colori di stato restano uguali e le loro tinte diventano il colore al 18% su `surface`, il testo sopra la tinta diventa il colore pieno. La modalità scura non è nei mockup: deve solo restare leggibile e coerente.

## 2. Tipografia

Font: **Inter** (file in `assets/fonts/`, pesi 400, 500, 600, 700, 800; licenza SIL OFL inclusa). È il sostituto libero del carattere dei mockup. Nessun font caricato dalla rete. Numeri sempre con cifre tabulari (`FontFeature.tabularFigures()`); titoli da 28 pt in su con `letterSpacing: -0.02em`.

Dichiarazione in `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
        - asset: assets/fonts/Inter-ExtraBold.ttf
          weight: 800
  assets:
    - assets/brand/
    - assets/brand/2.0x/
    - assets/brand/3.0x/
```

Scala (dimensione/interlinea in pt, peso). Telefono e tablet:

| Stile | Telefono | Desktop | Uso |
| --- | --- | --- | --- |
| `display` | 36/40 · 700 | 32/36 · 700 | Numeri grandi (ultimo valore con unità, "1.000 kcal") |
| `h1` | 32/38 · 700 | 32/40 · 600 | Titolo di pagina ("Archivio", "La mia salute", "Buongiorno, Anna.") |
| `h2` | 22/28 · 600 | 20/28 · 600 | Titolo di sezione e di card ("Documenti recenti", "Valori nel tempo") |
| `h3` | 18/24 · 600 | 18/26 · 600 | Titolo di riga grande, nome del biomarcatore nella card |
| `title` | 17/22 · 600 | 15/22 · 600 | Titolo delle righe di lista e delle celle principali |
| `body` | 16/24 · 400 | 15/22 · 400 | Testo corrente, descrizioni |
| `bodySmall` | 15/22 · 400 | 14/20 · 400 | Sottotitoli delle righe, testo nelle tabelle |
| `label` | 14/20 · 500 | 14/20 · 500 | Pill, chip, pulsanti piccoli, intestazioni di tabella |
| `caption` | 13/18 · 400 | 13/18 · 400 | Didascalie, assi dei grafici, piè di pagina |
| `navLabel` | 12/16 · 500 | 15/20 · 500 | Etichette della bottom bar (telefono) e delle voci della sidebar (desktop) |
| `button` | 16/20 · 600 | 15/20 · 600 | Testo dei pulsanti |
| `stat` | 28/32 · 700 | 28/32 · 700 | Numeri delle tile statistiche ("12", "18") |

Colori del testo: `h1`, `h2`, `h3`, `title`, `display`, `stat` in `ink`; `body` in `ink`; `bodySmall`, sottotitoli e `caption` in `inkSecondary` o `inkMuted`.

## 3. Spaziatura, raggi, ombre

- Unità base 4 pt. Gutter di pagina 16 pt sul telefono, 24 pt sul tablet, 32 pt sul desktop. Larghezza massima del contenuto desktop 1440 pt, centrata.
- Spazio tra sezioni 24 pt; tra card nella stessa sezione 12 pt (telefono) o 24 pt (griglia desktop); dentro le card 16 pt (telefono) e 20 pt (desktop); tra titolo di sezione e prima card 12 pt.
- Raggi: card 16 (telefono) e 14 (desktop); pulsanti 12; campi di testo 14; tile icona 14; tile data 14; segmented 12 esterno e 10 interno; pill e chip 999; avatar cerchio; foglio modale 24 in alto.
- Bordi: 1 px `border` su card, campi, chip in outline, sidebar (destra), bottom bar (sopra), top bar desktop (sotto, solo se scorre il contenuto).
- Ombre: card `0 1 2 rgba(11,27,51,0.04)`; fogli e menu `0 8 24 rgba(11,27,51,0.10)`; nessun'altra ombra. L'aspetto "pulito" dei mockup viene dai bordi sottili e dal bianco sul grigio caldo, non dalle ombre.
- Altezze: pulsante principale 48 (telefono) e 44 (desktop), grande 56 per le call to action a tutta larghezza; campo di ricerca 48; riga di lista 72–80; voce della sidebar 44; bottom bar 64 più safe area; top bar desktop 64; tile icona 48 (telefono) e 44 (desktop); tile data 72×72 (telefono) e 64×64 (desktop).

## 4. Icone

Famiglia **Lucide** (pacchetto `lucide_icons_flutter`, o `lucide_icons` se è l'unico compatibile): icone lineari, tratto 1,75–2, dimensione 24 nelle barre di navigazione, 20 nelle righe e nei pulsanti, 18 dentro pill e chip, 28 nelle tile icona. Mai le icone Material nelle schermate dell'app.

| Dove | Icona Lucide |
| --- | --- |
| Home | `house` |
| Salute | `heart` (attiva: `heart` pieno con `fill` primary) |
| Archivio | `file-text` |
| Cure | `pill` |
| Medico | `users` |
| Prevenzione (futura) | `shield` |
| Alimentazione (futura) | `utensils` |
| Academy (futura) | `graduation-cap` |
| Aiuto / Impostazioni | `circle-help` / `settings` |
| Cerca / Notifiche / Avatar | `search` / `bell` / iniziali |
| Carica referto | `file-up` |
| Da verificare | `file-check` o `file-pen` (arancione) |
| Documento archiviato / analizzato | `file-text` (blu) / `file-check-2` (verde) |
| Storico, grafici | `chart-no-axes-column` (barre) o `trending-up` |
| Avvisi | `bell`, critical `alert-circle`, warning `alert-triangle` |
| Sintomi | `activity` |
| Valore manuale | `plus-circle` |
| Calendario, orario | `calendar`, `clock` |
| Conferma / scarto | `check-circle-2` / `x-circle` |
| Freccia riga / indietro | `chevron-right` / `chevron-left` |
| Download, condividi, esporta | `download`, `share-2`, `file-down` |
| Info, disclaimer | `info` |

## 5. Componenti (`lib/core/ui/`)

Ogni componente è un widget con un nome fisso, così i prompt successivi lo chiamano per nome. Nessuna schermata ridisegna questi elementi a mano.

- `M24Theme` — `ThemeData` chiaro e scuro costruito dai token: `ColorScheme` esplicito, `TextTheme` con Inter e la scala della sezione 2, e i temi dei componenti Material usati (card, chip, pulsanti, campi, navigation bar, navigation rail, segmented button, tab bar, divider, app bar, bottom sheet, snackbar, dialog). Espone `M24Colors` e `M24TextStyles` come `ThemeExtension`, così ogni widget legge `context.m24.colors.primary` e mai un hex.
- `M24Logo` — mark (`assets/brand/logo_mark.png`, con 2.0x e 3.0x) e lockup (`logo_lockup.png`: mark + "Medical" in ink + "24" in primary). Altezze: 28 nella header telefono e nella sidebar, 40 nella schermata di benvenuto. Il file `logo_mark.svg` è la sorgente vettoriale.
- `M24Avatar` — cerchio 40 (36 sul desktop) `avatarBg` con iniziali `label` 600 in ink; sul desktop apre il menu con profilo, impostazioni, esci.
- `M24AppHeader` (telefono e tablet) — riga di 56 pt: lockup a sinistra, a destra pulsante campanella (con punto `warning` se ci sono avvisi non letti) e avatar. Senza titolo: il titolo sta nel `M24PageHeader` sottostante. Sulle schermate di dettaglio diventa `M24DetailAppBar`: freccia `chevron-left` 24, titolo `h3` centrato o a sinistra, sottotitolo con il nome della schermata madre in `caption` `inkSecondary`.
- `M24PageHeader` — titolo `h1` con sottotitolo `bodySmall` `inkSecondary` (es. "12 documenti", "Quadro aggiornato al 20 ottobre 2026") e azione principale a destra (`M24Button.primary` con icona); sul desktop è la testata del contenuto, con sotto la riga delle `M24Tabs` quando la schermata ne ha.
- `M24Card` — `surface`, raggio 16/14, bordo 1 px `border`, ombra card, padding 16/20; varianti: `tinted` (sfondo di tinta per i banner: `warningTint`, `primarySoft`, `infoTint`) e `selectable` (hover `surfaceAlt`, selezionata `primaryTint`).
- `M24SectionHeader` — titolo `h2` a sinistra e link di azione a destra in `info` `label` 500 con `arrow-right` ("Vedi tutte", "Tutti i documenti").
- `M24IconTile` — quadrato 48/44 raggio 14 con icona 28/24: varianti `info` (blu su `infoTint`), `success` (su `successTint`), `warning` (su `warningTint`), `danger`, `neutral`, `primary` (su `primaryTint`); è la testa delle righe di lista e delle tile statistiche.
- `M24StatusPill` — pill altezza 28, padding 10/12, punto 8 px + testo `label` 500: `info` "Archiviato", `success` "Analizzato" / "Confermato", `warning` "Da verificare" / "In analisi", `danger` "Critico" / "Lettura non riuscita", `neutral` "Caricato" / "Da concordare". Sempre con il punto a sinistra, come nei mockup.
- `M24Button` — `primary` (riempito `primary`, testo bianco 600, hover/pressed dai token, icona 20 a sinistra), `secondary` (sfondo `primaryTint`, testo `primaryInk`), `outline` (bordo 1 px `border`, testo ink; variante `outlinePrimary` con bordo e testo `primary` come "Carica documento" sul desktop), `tertiary` (solo testo in `info` o `primary`, per i link "Apri lo storico"), `destructiveOutline` (bordo e testo `danger` su `dangerTint`), `warning` (riempito `warning`, testo bianco: "Verifica i 2 valori"). Dimensioni: `medium` 48/44, `large` 56 a tutta larghezza, `small` 36. Raggio 12. Stato disabilitato al 40%. Caricamento: spinner 18 al posto dell'icona.
- `M24IconButton` — cerchio 40 (36 desktop) trasparente con hover `surfaceAlt`; variante `tinted` (cerchio `infoTint` con icona `info`, come il "+" dell'acqua).
- `M24Segmented` — contenitore `surface` con bordo 1 px, raggio 12, altezza 44; segmenti con icona 20 + testo `label` 500; segmento attivo `primaryTint` raggio 10 con testo e icona `primaryInk`. Usato per "Corpo · Valori · Storico" e per "Giorno · Settimana".
- `M24FilterChip` — altezza 40, raggio 999: selezionato `primaryTint` con testo `primaryInk` (chip "Tutti"), non selezionato `surface` con bordo 1 px e testo ink; varianti con icona a sinistra e `chevron-down` a destra per i menu ("2026 ▾", "Filtri").
- `M24SearchField` — altezza 48, raggio 14, `surface`, bordo 1 px, icona `search` 20 `inkMuted` a sinistra, placeholder `body` `inkMuted`; focus: bordo `primary`.
- `M24ListRow` — altezza minima 72: `M24IconTile` a sinistra, titolo `title` ink, sottotitolo `bodySmall` `inkSecondary` ("20 ott 2026 · Esami"), a destra `M24StatusPill` e `chevron-right` 20 `inkMuted`; hover `surfaceAlt` sul desktop; dentro una `M24Card` senza padding con `divider` tra le righe, oppure righe-card separate con 12 pt (telefono, come in Archivio).
- `M24StatTile` — card con `M24IconTile` a sinistra, etichetta `bodySmall` `inkSecondary` e numero `stat` sotto ("Documenti · 12"). Griglia a 4 sul desktop.
- `M24DateTile` — quadrato 72/64 raggio 14 con numero del giorno `display` (28) e mese abbreviato `label` 600 maiuscolo: varianti `primary` (`primarySoft`, testo ink), `warning` (`warningTint`, testo `warningInk`), `neutral`.
- `M24Banner` — card tinta a tutta larghezza (`warningTint` con icona `warning`, `infoTint`, `primarySoft`) con titolo `title` nel colore `*Ink`, sottotitolo `bodySmall`, `chevron-right`; è "2 valori da verificare · Dal referto del 20 ottobre".
- `M24Disclaimer` — barra `surfaceMuted` raggio 12, icona `info` 18, testo `caption` `inkSecondary`: "Informazioni da discutere con il medico." (telefono) e riga di piè di pagina "Le informazioni non sostituiscono il parere del medico." (desktop).
- `M24Tabs` — tab testuali con sottolineatura 2 px `primary`, testo `label` 500: attiva `primary`, inattiva `inkSecondary`; spazio 24 tra le tab; sul telefono scorrevoli.
- `M24Table` — intestazione `surfaceAlt` con testo `label` 500 `inkSecondary`, righe 48 con `divider`, celle `bodySmall` ink, riga selezionata `primaryTint`, hover `surfaceAlt`, pill di stato nelle celle di stato, icona `file-text` 18 prima del nome del documento.
- `M24EmptyState` — icona 40 in `inkMuted` dentro cerchio `surfaceAlt`, titolo `h3`, testo `body` `inkSecondary`, un solo `M24Button.primary`.
- `M24ChartStyle` — stile per fl_chart: linea `chart` spessore 2,5; punti raggio 5 con riempimento `surface` e bordo `chart` 2; area gradiente dal 22% a 0; etichette dei valori sopra i punti in `label` 600 ink; griglia orizzontale `divider`; assi `caption` `inkMuted`; banda del riferimento istituzionale `primaryTint` al 60%; linea di riferimento tratteggiata `inkMuted`; punti fuori riferimento colorati `warning` o `danger`; tooltip `ink` con testo bianco raggio 10.
- `M24Sheet` — foglio modale dal basso (telefono) e menu ancorato (desktop): `surface`, raggio 24 in alto, maniglia 36×4 `border`, voci di 56 con icona 24 in `M24IconTile` piccola e testo `title`.
- `M24Breadcrumb` — solo desktop: segmenti `label` 500 `inkSecondary` separati da `chevron-right` 16, ultimo segmento ink; nella top bar a sinistra.

## 6. Shell e navigazione

Telefono (sotto 600 pt): `M24AppHeader` in alto, contenuto scorrevole con gutter 16, `M24BottomBar` in basso: altezza 64 più safe area, `surface`, bordo sopra 1 px `border`; 5 voci con icona 24 e `navLabel`; voce attiva: icona e testo `primary`, icona dentro una pastiglia `primarySoft` 44×32 raggio 10; inattiva: `inkSecondary`. Badge: cerchio 16 `warning` con numero bianco 11/600 sull'angolo dell'icona (solo Salute, avvisi non letti). Pulsante "+" (`FloatingActionButton` esteso o circolare 56) `primary` con `plus` bianco, in basso a destra sopra la bottom bar, solo sulle liste.

Tablet (600–1199 pt): `NavigationRail` di 80 pt a sinistra, `surface`, bordo destro 1 px, voci icona + `navLabel` con la stessa pastiglia attiva; header e contenuto come sul telefono con gutter 24.

Desktop (da 1200 pt), riferimento 1920×1080:

- Sidebar 220 pt, `surface`, bordo destro 1 px: lockup 28 pt con padding 24/20; voci 44 pt raggio 12 con padding orizzontale 12, icona 20 + `navLabel`; attiva `primarySoft` con testo e icona `primary`; hover `surfaceAlt`. Ordine: Home (etichetta "Panoramica"), Salute ("La mia salute"), Archivio, Cure, Medico; in fondo, dopo un `divider`: Aiuto, Impostazioni. Le voci Prevenzione (sotto La mia salute, rientrata di 24), Alimentazione e Academy si aggiungono quando esistono i moduli. Pulsante "+ Aggiungi" (`M24Button.primary` a tutta larghezza della sidebar) sotto il lockup.
- Top bar 64 pt su `bg`: a sinistra `M24Breadcrumb` (primo segmento "Il mio spazio salute"), a destra campanella e avatar. Il campo "Cerca in Medical24" arriverà con la ricerca globale: non si mette un campo che non cerca.
- Contenuto: padding 32, larghezza massima 1440 centrata, `M24PageHeader` in alto (titolo a sinistra, azione principale a destra, tab sotto), griglia a 12 colonne con spazio 24; tre colonne tipiche: 8+4 oppure 4+5+3. Piè di pagina: `M24Disclaimer` desktop centrato a 13 pt.

Schermata di dettaglio (tutte le piattaforme): freccia indietro con pop, altrimenti rotta madre; sul desktop il breadcrumb mostra il percorso completo.

## 7. Schermate esistenti e mockup di riferimento

| Schermata | Mockup | Struttura da rispettare |
| --- | --- | --- |
| Home telefono | `home_mobile.png` | Header; `h1` "Ciao, Nome." con sottotitolo "Il tuo spazio salute"; pulsante "Carica" nell'header a destra; card "La tua salute" con link "Apri il quadro →", etichetta "Ultimo referto: data", nome del biomarcatore seguito, `display` con unità, grafico `M24ChartStyle` degli ultimi valori; `M24Banner` "N valori da verificare · Dal referto del …"; sezione "Documenti recenti" con `M24SectionHeader` "Tutti i documenti →" e `M24ListRow` con pill. La card "Stato di salute · In preparazione" resta finché non esiste il punteggio. Niente card appuntamento né "I tuoi percorsi" finché non esistono i moduli. |
| Home desktop | `panoramica_desktop.png` | `h1` "Buongiorno, Nome." con "Aggiornato al …" e "Carica referto" a destra; 4 `M24StatTile` (Documenti, Valori seguiti, Valori da verificare, Avvisi non letti al posto di "Prossimo controllo"); riga a 8+4: card "Valori nel tempo" (selettore del biomarcatore `M24FilterChip` con chevron, periodo, link "Apri storico →", grafico, riga "Ultimo · Precedente · Variazione"), card "Ultimi valori confermati" (tabella Parametro · Valore · Verifica con pill), colonna "Da fare" (righe con `M24IconTile`: verifica valori estratti, avvisi non letti); riga sotto: "Documenti recenti" come `M24Table` (Documento · Data · Categoria · Stato) con "Tutti i N documenti →". Le card Alimentazione e Corso arriveranno con i loro moduli. |
| Archivio telefono | `archivio_mobile.png` | Header; `h1` "Archivio" + "N documenti" + `M24Button.primary` "Carica" con `file-up`; `M24SearchField` "Cerca un documento"; riga di chip: "Tutti" selezionato, anno con chevron, "Filtri" con `sliders-horizontal`; righe-card con `M24IconTile` colorata dallo stato (warning da verificare, info archiviato, success analizzato), titolo, "data · categoria", pill, chevron. |
| Archivio desktop | `archivio_desktop.png` | `h1` "Archivio" + "N documenti · Elenco, originale e analisi" + `M24Button.outlinePrimary` "Carica documento"; riga filtri (ricerca, categoria, anno); tre colonne 4+5+3: `M24Table` dei documenti con riga selezionata, visore dell'originale (pagina N di M con frecce, zoom, download, pagina su sfondo `surfaceAlt`, "Apri a tutto schermo"), colonna "Dati estratti" con banner "N valori da confermare", tabella Parametro · Valore · Verifica con pill e `M24Button.primary` "Verifica i N valori". La card "Spiegazione" arriva con il P06. |
| Salute telefono (lista valori, storico, sintomi, avvisi) | `salute_mobile.png` | `h1` "La mia salute" con data dell'ultimo aggiornamento; `M24Segmented` con i segmenti disponibili (Valori · Sintomi · Avvisi; "Corpo" arriverà con il P04 in prima posizione); card per biomarcatore con `M24IconTile`, nome `h3`, unità, valore `display` a destra con data e laboratorio, pill "Confermato", grafico, due azioni in basso "Apri lo storico" e "Fonte e riferimenti" (il documento di origine); righe compatte per gli altri valori; `M24Disclaimer` in fondo. |
| Salute desktop | `salute_desktop.png` | `h1` "La mia salute" + "Quadro aggiornato al …" + "Carica referto"; `M24Tabs` (Tutti i valori · Storico · Sintomi · Avvisi; "Corpo e organi" arriverà con il P04); colonna sinistra lista dei valori (card con righe), colonna centrale card per biomarcatore con selettore e periodo, grafico, riga statistiche, "Storico delle rilevazioni" come tabella Data · valore · Documento; colonna destra "Il valore selezionato" (valore, data, pill "Estrazione confermata", Fonte con link al referto, righe Laboratorio · Riferimento istituzionale · Soglia del medico "Non impostata"), "Altri valori confermati", card `warningTint` "Da verificare nell'originale" con `M24Button.warning`. |
| Analisi del referto (verifica dei valori) | `archivio_desktop.png` colonna destra, `archivio_mobile.png` | Righe Parametro · Valore con unità · pill di verifica e chevron; pulsanti "Approva" (`primary`) e "Scarta" (`outline`); i valori da verificare evidenziati con `warningTint`. |
| Autenticazione, onboarding, impostazioni | nessun mockup | Componenti del sistema: colonna centrata di 480 sul desktop, lockup 40 in alto, campi `M24SearchField`-like, `M24Button.primary` large, testi `body`. |
| Stati vuoti | — | `M24EmptyState` con una sola azione. |

## 8. Cosa non fare

- Nessun colore, raggio o dimensione fuori dai token; nessun hex nelle schermate.
- Nessuna icona Material; nessun font diverso da Inter; nessun font dalla rete.
- Nessuna ombra oltre le due definite; nessun gradiente oltre l'area dei grafici.
- Nessun chip "Dati dimostrativi", nessun dato di esempio, nessuna card o voce di menu per funzioni senza backend.
- Nessun FAB centrale; il "+" sta in basso a destra, solo sulle liste.
