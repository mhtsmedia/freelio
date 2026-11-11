# Før betatesterne slippes inn

Tre ting må være på plass. Gjør dem i denne rekkefølgen og kryss av underveis.

## 1. Bekreft at alle databasereglene er kjørt

- [ ] Supabase → **SQL Editor** → **New query**. Lim inn hele `database/sjekk-sikkerhet.sql` og trykk **Run**.
      Skriptet endrer ingenting. Kolonnen `problemer` skal være **0**.
- [ ] Står det MANGLER, ÅPEN eller AV på noe: kjør `database/oppdatering.sql`, deretter filene som står i `detalj`, og kjør sjekken på nytt.
- [ ] Kjør `database/stram-anon.sql` (ekstra sikring). Uinnloggede får da ikke engang spørre etter
      profiler, meldinger, bestillinger, tilbud og lagrede ting. RLS stopper dem allerede, men dette er et ekstra lag.
- [ ] Lim inn hele `database/test-tilgang.sql` i en ny query og trykk **Run**.
      Den lager tre falske brukere og prøver å lese og endre hverandres data som innlogget bruker.
      Alt testdata slettes igjen. `problemer` skal være **0**, og hver rad skal si **OK**.
- [ ] Står det ÅPEN eller FEIL på noe, ikke slipp inn testere før det er fikset.

## 2. Slå på e-postbekreftelse med egen e-posttjeneste (SMTP)

Den innebygde e-posten i Supabase sender bare noen få e-poster i timen, og bare til teammedlemmer.
Dere trenger egen SMTP. Uten eget domene er Gmail enklest:

- [ ] Google-kontoen som skal sende: slå på **totrinnsbekreftelse**, og lag et **app-passord**
      (myaccount.google.com → Sikkerhet → App-passord).
- [ ] Supabase → **Authentication** → **Emails** → **SMTP Settings** → slå på **Enable custom SMTP**:
  - Sender email: Gmail-adressen
  - Sender name: `Freelio`
  - Host: `smtp.gmail.com`, Port: `465`
  - Username: hele Gmail-adressen, Password: app-passordet (aldri det vanlige passordet)
- [ ] Supabase → **Authentication** → **Sign In / Providers** → **Email** → slå på **Confirm email**.
- [ ] Sjekk at **Authentication** → **URL Configuration** har Site URL `https://mhtsmedia.github.io/freelio/`
      og Redirect URL `https://mhtsmedia.github.io/freelio/**`.
- [ ] Valgfritt: **Authentication** → **Emails** → **Templates** → «Confirm signup» på norsk.
- [ ] Test: opprett en konto med en ekte e-postadresse, sjekk at e-posten kommer (også i søppelpost),
      trykk på lenken og logg inn.

Kontoer som ble laget mens bekreftelse var av, er allerede bekreftet og virker som før.
Når dere kjøper domene: bytt til en tjeneste som Resend med avsender på eget domene.

## 3. Minst 8 tegn i passord

- [x] Nettsiden krever nå minst 8 tegn for nye kontoer (`logg-inn.html`).
      Innlogging virker fortsatt for eldre kontoer med kortere passord.
- [ ] Supabase → **Authentication** → **Sign In / Providers** → **Email** → **Minimum password length**: `8`.
      Uten denne kan noen fortsatt lage korte passord ved å gå rundt nettsiden.
