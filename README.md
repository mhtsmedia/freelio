# Freelio

Markedsplass der folk finner, sammenligner og leier lokale fotografer og videografer. Flere fagfelt kommer senere. Pengene skal holdes av en betalingspartner til jobben er levert og godkjent. Freelio tar 5 % av hvert oppdrag.

Live: https://mhtsmedia.github.io/freelio/

Nettsiden bruker Supabase til kontoer, frilanserprofiler, oppdrag, tilbud, bestillinger, meldinger, omtaler og leveransefiler. Betaling er fortsatt simulert. Er databasen ikke satt opp, kjører siden i demo-modus med data i nettleseren.

## Sett opp Supabase

1. Åpne prosjektet på supabase.com og gå til **SQL Editor**, så **New query**.
2. Lim inn hele `database/oppsett.sql` og trykk **Run**. Skriptet lager tabeller, tilgangsregler og fillagring. Det kan kjøres flere ganger.
3. Gå til **Authentication**, så **URL Configuration**:
   - Site URL: `https://mhtsmedia.github.io/freelio/`
   - Redirect URLs: legg til `https://mhtsmedia.github.io/freelio/**`
4. Under **Authentication**, så **Sign In / Providers**, så **Email**: slå av «Confirm email» mens dere tester. Den innebygde e-posttjenesten sender bare noen få e-poster i timen. Før lansering kobler dere på egen e-post (SMTP), for eksempel Resend, og slår bekreftelsen på igjen.

Adressen og den offentlige nøkkelen ligger i `js/config.js`. Den hemmelige nøkkelen (secret / service_role) skal aldri inn i koden.

Filer: `database/schema.sql` er tabeller og regler, `database/bilder.sql` er lagring av profil- og porteføljebilder, `database/fjern-demo.sql` sletter gamle demo-frilansere og demo-oppdrag, `database/video.sql` slår på video i porteføljen, `database/meldinger.sql` lar samtaler stå når en kunde sletter kontoen, `database/innlegg.sql` slår på innlegg på Utforsk, `database/mapper.sql` slår på mapper for lagrede frilansere, innlegg og oppdrag, `database/kommentarer.sql` slår på liker og kommentarer på innlegg, `database/oppdragsgiver.sql` viser hvem som har lagt ut et oppdrag (navn og bilde fra profilen), `database/moderering.sql` lar admin skjule, stenge og slette frilansere og fjerne innlegg, kommentarer og omtaler (admin.html), `database/admin.sql` lar admin fjerne andres annonser (legg inn deg selv nederst i filen), `database/grenser.sql` setter makspris (1 000 000 kr) og lengde på tekst, `database/push.sql` slår på push-varsler (se under), `database/vedlegg.sql` slår på vedlegg (bilder og filer) i meldinger, `database/sikkerhet.sql` legger inn grenser og regler som nettsiden ikke kan omgå (lengder, egne bilder, rekkefølge på bestillinger og fartsgrenser), `database/feil.sql` slår på «Meld feil» (se under), `database/juridisk.sql` tetter smutthullene fra den juridiske gjennomgangen (se under), `database/sjekkliste.sql` legger inn indekser, slår av GraphQL, renser navn, begrenser leveransefiler og setter fartsgrense på «Hent fra portefølje» (se under), `database/herding.sql` strammer inn funksjoner etter Security Advisor (se under), og `database/oppsett.sql` er alt samlet. Har du allerede kjørt et eldre `oppsett.sql`, kjør `database/oppdatering.sql`. Den har alle endringene samlet.

### Juridisk gjennomgang (november 2026)

Kjør `database/juridisk.sql` i SQL Editor (etter `avtale.sql`, `admin.sql` og `feil.sql`), eller hele `database/oppdatering.sql`. Uten den virker ikke «Send saken til Freelio», «Meld bilde» eller de nye reglene for avbestilling.

- **Pris og dato:** databasen henter prisen fra pakken eller tilbudet, og låser dato og sted ved booking.
- **Avbestilling:** gratis til og med 30 dager før, 50 % fra 29 til 7 dager før, ingenting etter det, og ikke etter avtalt dato. 14 dagers angrerett gir full refusjon. Bestillinger fra før følger den gamle regelen.
- **Sak hos Freelio:** ny status som stopper automatisk godkjenning. Admin avgjør saken på `saker.html` (lenken ligger i kontomenyen for admin). Alt logges i `admin_log`.
- **Frilansere** oppgir om de er næringsdrivende eller privatperson, org.nr. og MVA-status. Nettsiden spør aldri om fødselsnummer eller kontonummer. Det samles inn hos betalingspartneren når utbetaling slås på.
- **Meld bilde** bruker `meld-feil.html?bilde=1`. Når «Meld feil» fjernes etter testfasen, må «Meld bilde» få en egen side.
- **Skrifter og supabase-js** ligger lokalt i `css/fonts` og `js/vendor`. Ingen kall til Google Fonts eller jsDelivr.

Venter til betaling er koblet på: at bare betalingsleverandøren kan sette en bestilling til betalt, kvitteringer i frilanserens navn, innsamling av opplysninger til Skatteetaten, og fjerning av unntaket for demo-frilansere. Plassholdere i hakeparentes i `vilkar.html`, `frilansvilkar.html` og `personvern.html` fylles inn når selskapet er stiftet.

### Sikkerhetssjekkliste (november 2026)

Kjør `database/sjekkliste.sql` i SQL Editor (eller hele `database/oppdatering.sql`), og legg inn `supabase/functions/hent-portefolje/index.ts` på nytt. Kjør så `database/sjekk-sikkerhet.sql`. `problemer` skal være 0.

- **Indekser** på kolonnene tilgangsreglene, fartsgrensene og listene slår opp i.
- **GraphQL er av.** Nettsiden bruker bare REST. Går det ikke fra SQL, slå av `pg_graphql` under Database, Extensions.
- **Navn:** usynlige tegn og tegn som snur teksten fjernes, Unicode gjøres om til én form (NFKC), og ingen kan kalle seg «Freelio», «Admin» eller «Kundeservice», eller blande latinske og kyrilliske bokstaver.
- **Leveranser:** høyst 50 MB per fil, bare bilder, video og bitene nettsiden deler store filer i.
- **Hent fra portefølje:** høyst 30 sider og 300 bilder i timen per bruker. Feilmeldinger viser aldri interne detaljer, og sidene leses med avgrensede mønstre (ingen ReDoS).
- **Nettsiden:** lenken etter innlogging (`?neste=`) kan ikke lenger brukes til å sette inn kode. Ukjente feil fra databasen vises som en vanlig melding, ikke med tabell- og regelnavn. Kartbiblioteket hentes med integritetssjekk (SRI).
- **18 år og vilkår:** alle bekrefter én gang at de er over 18 år og godtar vilkårene, også med Google og telefon. Bekreftelsen lagres på kontoen (`adult` og `vilkar` i brukerdataene). Eldre kontoer blir spurt neste gang de logger inn.
- **Cookies:** Freelio setter ingen cookies og bruker ingen statistikk. Cookie-meldingen sier det, og har ingen «Godta alle». Tar dere i bruk statistikk senere, må det spørres om samtykke først.
- **Betaling:** så lenge `H.PAY_LIVE = false` i `js/app.js`, står det på booking og bestilling at ingen penger trekkes.

### SEO, deling og herding (november 2026)

Kjør `python3 tools/seo.py` før hver push (sammen med `tools/versjon.py`, se under). Den gjør dette:

- **Hver side** får tittel, beskrivelse, `robots`, canonical, Open Graph (delingsbilde `img/og-freelio.png`), favicon i PNG og strukturert data (JSON-LD). Tekstene står i `SIDER` øverst i `tools/seo.py`. Sider som krever innlogging får `noindex`.
- **Frilanserprofiler og oppdrag** får egen tittel, beskrivelse, canonical og strukturert data fra `H.seo` i `js/app.js` når innholdet er lastet. Bare ekte omtaler telles, og demo-profiler får ikke strukturert data.
- **sitemap.xml** med faste sider og alle publiserte frilansere fra Supabase, **robots.txt** (alle søkemotorer og AI-tjenester er velkomne) og **llms.txt** (kort beskrivelse av Freelio for språkmodeller).
- **Bunnmenyen** ligger også rett i HTML-en, så lenkene finnes uten JavaScript. **404.html** får `<base>`, så den virker på alle adresser.
- Adressen til nettsiden står i `js/config.js` (`siteUrl`). Bytt den når dere får eget domene, og kjør `tools/seo.py` på nytt. Delingsbildet lages på nytt med `python3 tools/seo.py --bilde` (fra `tools/og/og.html`).
- **robots.txt og eget domene:** søkemotorene leser bare robots.txt fra roten av domenet, ikke fra `/freelio/`. Til dere har eget domene, sendes sitemap inn i Google Search Console.

**Opphavsrett:** `opphavsrett.html` beskriver hvordan rettighetshavere melder fra (også DMCA-varsler), hva som skjer, klage fra den som lastet opp, og at kontoer med gjentatte brudd stenges. Lenken ligger i bunnmenyen og i brukervilkårene, punkt 9.

**Innlogging:** «Logg ut» avslutter økten hos Supabase, fjerner push-abonnementet og sletter alt som er mellomlagret om brukeren i nettleseren (bare tema, design og cookie-svaret beholdes). «Opprett konto» gir samme svar om e-posten har konto fra før eller ikke. I Supabase er «Confirm email», minst 8 tegn og «Secure password change» på.

**Herding:** `database/herding.sql` (også i `oppdatering.sql` og `oppsett.sql`) setter fast `search_path` på fire funksjoner, gjør at ingen kan kalle triggerfunksjonene direkte, og at hjelpefunksjonene med SECURITY DEFINER bare kan kalles av innloggede (unntak: `job_posters`, som forsiden trenger). `test-tilgang.sql` gir fortsatt 0 problemer. Gjenstår i Security Advisor: `pg_net` ligger i `public` (kan ikke flyttes uten å installere den på nytt), og «Leaked password protection» krever Pro-planen.

### Meld feil (midlertidig)

Mens Freelio testes, ligger det en stripe øverst på sidene med knappen «Meld feil». Den åpner `meld-feil.html`, der alle kan fortelle hva som ikke virker, også uten å logge inn. Lenken finnes også i menyen og nederst på alle sider. Feilmeldingen får med seg siden du kom fra, nettleser, skjermstørrelse, versjon og de siste feilene i nettleseren.

1. Kjør `database/admin.sql` (hvis du ikke har gjort det) og så `database/feil.sql` i SQL Editor.
2. Feilene ser du nederst på `meld-feil.html` når du er logget inn som admin. Der kan du merke dem som fikset eller avvist. De ligger også i Supabase under **Table Editor → bug_reports**.
3. Når testfasen er over: sett `H.BUGS = false` i `js/app.js` (da forsvinner stripen og lenkene) og slett `meld-feil.html`.

### Hent fra portefølje (Edge Function)

På «Bli frilanser» kan frilansere lime inn en lenke til porteføljen sin, så hentes beskrivelse og bilder automatisk. Det krever en liten funksjon i Supabase, fordi nettleseren ikke får lese andre nettsider:

1. I Supabase: **Edge Functions**, så **Deploy a new function**, så **Via Editor**.
2. Gi den navnet `hent-portefolje`, slett eksempelkoden («Hello …»), lim inn hele `supabase/functions/hent-portefolje/index.ts` og trykk **Deploy**.
3. Funksjonen sjekker selv at brukeren er logget inn, så **Verify JWT** kan stå på eller av.

Funksjonen henter bare vanlige nettsider (aldri interne adresser), har tidsfrist og maks størrelse, og bildene lastes opp i frilanserens egen mappe. Uten funksjonen viser skjemaet «Henting fra portefølje er ikke slått på ennå».

### Push-varsler (Edge Function)

Når noen gir tilbud på et oppdrag, eller sender en melding, får mottakeren varsel på mobilen eller PC-en, også når Freelio ikke er åpen. Hver bruker slår det på under **Min side → Varsler** (eller på sin egen annonse). På iPhone må Freelio først legges til på Hjem-skjermen (Del → «Legg til på Hjem-skjerm»).

1. I Supabase: **Edge Functions**, **Deploy a new function**, **Via Editor**. Navn: `varsle`. Lim inn hele `supabase/functions/varsle/index.ts` og trykk **Deploy**.
2. Slå **av** «Verify JWT» for `varsle` (databasen kaller den). Funksjonen sender bare om tilbud og meldinger som finnes, er nye og ikke er varslet før.
3. **Edge Functions → Secrets**: legg inn `VAPID_PUBLIC_KEY` og `VAPID_PRIVATE_KEY`. Den offentlige nøkkelen står også i `js/config.js` (`vapidPublicKey`). Den hemmelige skal aldri ligge i koden.
4. Kjør `database/push.sql` i SQL Editor. Vil du også ha varsel når noen melder en feil (gjelder alle admin), kjør `database/feil-varsel.sql` etterpå.
5. Test: Min side → Varsler → **Slå på**, så **Send test**.

## Kjør lokalt

```bash
python3 -m http.server 8000
```

Åpne http://localhost:8000.

## Publiser med GitHub Pages

Kjør `python3 tools/seo.py && python3 tools/versjon.py` før hver push. `seo.py` oppdaterer metadata, sitemap og llms.txt (se over). `versjon.py` gir CSS- og JS-filene et nytt versjonsnummer, så nettleseren ikke bruker en gammel kopi.


Settings → Pages → Deploy from a branch → `main` / root. GitHub Pages på et privat repo krever et betalt GitHub-abonnement. Ellers må repoet være offentlig.

## Sider

| Side | Fil | Innlogging |
| --- | --- | --- |
| Forside med søk, kategorier, populære og nye oppdrag | `index.html` | Nei |
| Utforsk: rutenett med arbeid fra frilansere. Trykk på et innlegg for fullskjerm med liker, kommentarer, lagring og deling | `utforsk.html?p=` | Nei |
| Søk med filter, sortering og sammenligning | `sok.html` | Nei |
| Kart over frilansere i nærheten (OpenStreetMap, eller Google Maps med nøkkel i `js/config.js`) | `kart.html` | Nei |
| Frilanserprofil med portefølje, pakker og omtaler | `frilanser.html?id=` | Nei |
| Sammenlign opptil tre frilansere | `sammenlign.html` | Nei |
| Oppdragsbørs (annonser fra kunder) | `oppdrag.html` | Nei |
| Enkelt oppdrag, tilbud og send tilbud | `annonse.html?id=` | Delvis |
| Legg ut oppdrag | `ny-annonse.html` | Ja |
| Book og betal | `book.html?id=&pk=` | Ja |
| Mine oppdrag (bestillinger, annonser, sendte tilbud) | `mine-oppdrag.html` | Ja |
| Bestilling med trygg betaling, avbestilling, feil og omtale | `bestilling.html?id=` | Ja |
| Meldinger | `meldinger.html?med=` | Ja |
| Assistent | `assistent.html` | Nei |
| Logg inn eller lag konto med e-post, Google eller telefonnummer | `logg-inn.html` | |
| Bli frilanser (lag og rediger profil) | `bli-frilanser.html` | Ja |
| Min side: oversikt med fliser, og egne visninger for konto, frilanserprofil, varsler og personvern | `min-side.html?vis=` | Ja |
| Lagret: mapper med frilansere, innlegg og oppdrag | `lagret.html?mappe=` | Nei |
| Slik fungerer det, trygg betaling og priser | `slik-fungerer-det.html` | Nei |
| Hjelpesenter med FAQ og kontaktskjema | `hjelp.html` | Nei |
| Meld feil (midlertidig, mens Freelio testes). Admin ser innsendte feil nederst | `meld-feil.html?fra=` | Nei |
| Om, vilkår, frilansvilkår, personvern, opphavsrett, cookies, 404 | `om.html`, `vilkar.html`, `frilansvilkar.html`, `personvern.html`, `opphavsrett.html`, `cookies.html`, `404.html` | Nei |
| Saker hos Freelio (bare admin) | `saker.html` | Ja |

## Struktur

```
css/style.css   Design, lys og mørk modus, animasjoner og skeleton
css/ny.css      Det nye designet oppå style.css. Slås av i js/design.js
css/finn.css    FINN-inspirert design oppå ny.css (smal bredde på alle sider, egen forside). Bare med design 'finn'
js/design.js    Velger design: STANDARD = 'ny', 'finn' eller 'gammel'. Prøv selv med ?design=finn
img/            Logo (SVG) og favicon
js/logo.js      Logoen som vektor, følger lys og mørk modus
js/data.js      Kategorier og farger
js/config.js    Adresse og offentlig nøkkel til Supabase
js/cloud.js     Henter og lagrer data i Supabase. Faller tilbake til demo-modus
js/media.js     Leveranser: komprimerte forhåndsvisninger og originaler i Supabase Storage (eller IndexedDB i demo)
database/       SQL for Supabase: tabeller og tilgangsregler
js/app.js       Felles kode: lagring, meny, cookies, kort, meldinger, assistent
*.html          Én fil per side. Sidespesifikk kode ligger nederst i hver fil.
```

## Neste steg mot ekte app

1. **Komprimering av video.** Porteføljevideoer lagres som de lastes opp. En tjeneste som Mux eller Cloudflare Stream kan gjøre dem mindre.
2. **Innlogging.** Vipps Login og BankID via en leverandør som Signicat eller Criipto (OpenID Connect).
3. **Betaling med tilbakeholdt beløp.** Bruk en lisensiert leverandør med markedsplassløsning, for eksempel Stripe Connect, Adyen for Platforms eller Vipps MobilePay. Freelio skal ikke holde kundens penger selv, siden det krever konsesjon fra Finanstilsynet.
4. **Kart.** Mapbox eller Leaflet med OpenStreetMap. Vis omtrentlig posisjon.
5. **Assistent.** Koble til en språkmodell via en serverfunksjon, aldri direkte fra nettleseren.
6. **Leveranser.** Last opp originaler direkte til lagring (S3, Cloudflare R2 eller Supabase Storage) med signerte lenker. La serveren lage forhåndsvisninger: bilder i WebP og video som 720p-strøm (for eksempel Cloudflare Stream eller Mux). Originalene låses opp når kunden godkjenner.
7. **Varsler.** E-post (for eksempel Postmark) og push.
8. **Juridisk.** Vilkår, personvern og cookies er utkast og må gjennomgås av advokat. Fyll inn feltene i hakeparentes.
9. **App.** Når nettsiden fungerer, kan den pakkes som app med React Native, Flutter eller Capacitor.
