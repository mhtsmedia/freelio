# Freelio

Markedsplass der folk finner, sammenligner og leier lokale frilansere. Pengene holdes trygt til jobben er levert og godkjent. Freelio tar 5 % av hvert oppdrag.

Live: https://mhtsmedia.github.io/freelio/

Dette er en fungerende prototype av nettsiden. Alt kjører i nettleseren uten server, så du kan åpne den rett fra GitHub Pages. Innlogging, betaling og meldinger er simulert, og data lagres i `localStorage`.

## Kjør lokalt

```bash
python3 -m http.server 8000
```

Åpne http://localhost:8000.

## Publiser med GitHub Pages

Settings → Pages → Deploy from a branch → `main` / root. GitHub Pages på et privat repo krever et betalt GitHub-abonnement. Ellers må repoet være offentlig.

## Sider

| Side | Fil | Innlogging |
| --- | --- | --- |
| Forside med søk, kategorier, populære og nye oppdrag | `index.html` | Nei |
| Feed med arbeid fra frilansere | `utforsk.html` | Nei |
| Søk med filter, sortering og sammenligning | `sok.html` | Nei |
| Kart over frilansere i nærheten | `kart.html` | Nei |
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
| Logg inn med Vipps eller BankID | `logg-inn.html` | |
| Bli frilanser (lag og rediger profil) | `bli-frilanser.html` | Ja |
| Min side (lagrede, varsler, cookies, data, slett konto) | `min-side.html` | Ja |
| Slik fungerer det, trygg betaling og priser | `slik-fungerer-det.html` | Nei |
| Hjelpesenter med FAQ og kontaktskjema | `hjelp.html` | Nei |
| Om, vilkår, personvern, cookies, 404 | `om.html`, `vilkar.html`, `personvern.html`, `cookies.html`, `404.html` | Nei |

## Struktur

```
css/style.css   Design, lys og mørk modus, animasjoner og skeleton
img/            Logo (SVG) og favicon
js/logo.js      Logoen som vektor, følger lys og mørk modus
js/data.js      Eksempeldata: kategorier, frilansere og oppdrag
js/app.js       Felles kode: lagring, meny, cookies, kort, meldinger, assistent
*.html          Én fil per side. Sidespesifikk kode ligger nederst i hver fil.
```

## Neste steg mot ekte app

1. **Backend og database.** For eksempel Supabase (Postgres, auth, lagring av bilder, sanntid for meldinger). Bytt ut `H.load`, `H.save` og `HDATA` med API-kall.
2. **Innlogging.** Vipps Login og BankID via en leverandør som Signicat eller Criipto (OpenID Connect).
3. **Betaling med tilbakeholdt beløp.** Bruk en lisensiert leverandør med markedsplassløsning, for eksempel Stripe Connect, Adyen for Platforms eller Vipps MobilePay. Freelio skal ikke holde kundens penger selv, siden det krever konsesjon fra Finanstilsynet.
4. **Kart.** Mapbox eller Leaflet med OpenStreetMap. Vis omtrentlig posisjon.
5. **Assistent.** Koble til en språkmodell via en serverfunksjon, aldri direkte fra nettleseren.
6. **Varsler.** E-post (for eksempel Postmark) og push.
7. **Juridisk.** Vilkår, personvern og cookies er utkast og må gjennomgås av advokat. Fyll inn feltene i hakeparentes.
8. **App.** Når nettsiden fungerer, kan den pakkes som app med React Native, Flutter eller Capacitor.
