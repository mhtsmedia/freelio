"""SEO for alle sidene. Kjør før hver push, sammen med versjon.py:

    python3 tools/seo.py && python3 tools/versjon.py

Gjør dette:
  1. Legger inn tittel, beskrivelse, robots, canonical, Open Graph, delingsbilde og strukturert data (JSON-LD)
     i <head> på hver side, mellom <!-- seo --> og <!-- /seo -->. Endre tekstene i SIDER under, ikke i HTML-en.
  2. Setter lang="nb" på alle sider.
  3. Legger en enkel bunnmeny rett i HTML-en (#site-footer), så lenkene finnes også uten JavaScript.
     js/app.js tegner den vanlige bunnmenyen oppå når siden starter.
  4. Gir 404.html en <base>, så stiler og skript virker også på adresser som /freelio/a/b/finnes-ikke.
  5. Lager sitemap.xml (faste sider og alle publiserte frilansere fra Supabase), robots.txt og llms.txt.

Adressen til nettsiden (siteUrl) og Supabase-nøkkelen leses fra js/config.js.
Med --bilde lages også img/og-freelio.png på nytt fra tools/og/og.html (krever Google Chrome).
"""
import datetime, glob, html, json, os, re, subprocess, sys, urllib.parse, urllib.request

os.chdir(os.path.join(os.path.dirname(__file__), '..'))

cfg = open('js/config.js', encoding='utf-8').read()
SITE = re.search(r"siteUrl:\s*'([^']+)'", cfg).group(1).rstrip('/') + '/'
SB_URL = re.search(r"supabaseUrl:\s*'([^']*)'", cfg).group(1)
SB_KEY = re.search(r"supabaseKey:\s*'([^']*)'", cfg).group(1)
BASE_PATH = urllib.parse.urlparse(SITE).path or '/'
OG_IMAGE = SITE + 'img/og-freelio.png'
OG_ALT = 'Freelio: finn fotograf, videograf og dronepilot. Se arbeidet, sammenlign og book lokalt.'
TODAY = datetime.date.today().isoformat()

# side: (tittel, beskrivelse, kort navn i brødsmuler, indekseres, fast canonical)
# Sider med innhold fra databasen (frilanser, annonse) får tittel, beskrivelse og canonical fra js/app.js (H.seo).
SIDER = {
    'index.html': ('Freelio | Finn lokale fotografer og videografer',
                   'Finn, sammenlign og book lokale fotografer, videografer og dronepiloter. Se arbeid, priser og omtaler. Pengene utbetales først når jobben er levert.',
                   'Forside', True, True),
    'sok.html': ('Finn fotograf eller videograf nær deg | Freelio',
                 'Søk blant lokale fotografer, videografer og dronepiloter. Filtrer på fagfelt, område, pris og vurdering, og sammenlign før du booker.',
                 'Finn frilanser', True, True),
    'utforsk.html': ('Utforsk foto og video fra lokale frilansere | Freelio',
                     'Bla gjennom bilder og videoer fra lokale fotografer og videografer. Finn stilen du liker, og book frilanseren bak arbeidet.',
                     'Utforsk', True, True),
    'kart.html': ('Kart over fotografer og videografer | Freelio',
                  'Se fotografer, videografer og dronepiloter i nærheten på kartet. Trykk på en frilanser for å se arbeid, priser og omtaler.',
                  'Kart', True, True),
    'oppdrag.html': ('Ledige foto- og videooppdrag | Freelio',
                     'Oppdrag fra kunder som trenger fotograf, videograf eller dronepilot. Er du frilanser, kan du sende tilbud direkte på Freelio.',
                     'Ledige oppdrag', True, True),
    'frilanser.html': ('Frilanser | Freelio',
                       'Portefølje, pakker, priser og omtaler for en lokal fotograf eller videograf på Freelio.',
                       'Frilanser', True, False),
    'annonse.html': ('Oppdrag | Freelio',
                     'Et oppdrag lagt ut på Freelio. Frilansere kan sende tilbud.',
                     'Oppdrag', True, False),
    'bli-frilanser.html': ('Bli frilanser: få foto- og videooppdrag | Freelio',
                           'Lag en gratis profil som fotograf, videograf eller dronepilot, vis frem arbeidet ditt og få oppdrag i nærheten. Freelio tar 5 % først når du får betalt.',
                           'Bli frilanser', True, True),
    'slik-fungerer-det.html': ('Slik fungerer Freelio: trygg booking og priser',
                               'Slik finner, booker og betaler du lokale fotografer og videografer på Freelio. Pengene holdes til jobben er godkjent. Se priser og avgift.',
                               'Slik fungerer det', True, True),
    'hjelp.html': ('Hjelpesenter og kontakt | Freelio',
                   'Svar på vanlige spørsmål om booking, betaling, avbestilling og frilanserprofiler på Freelio, og kontakt med kundeservice.',
                   'Hjelp', True, True),
    'assistent.html': ('Assistent: råd om fotograf og video | Freelio',
                       'Få råd om hva du bør se etter når du velger fotograf eller videograf, hva det koster, og hvordan du skriver en god annonse.',
                       'Assistent', True, True),
    'om.html': ('Om Freelio | Lokale fotografer og videografer',
                'Freelio gjør det enkelt å finne og booke lokale fotografer og videografer, med trygg betaling som først utbetales når jobben er levert.',
                'Om Freelio', True, True),
    'avtale.html': ('Oppdragsavtalen mellom kunde og frilanser | Freelio',
                    'Avtalen som gjelder mellom kunde og frilanser når du booker gjennom Freelio: leveranse, avbestilling, opphavsrett og betaling.',
                    'Oppdragsavtalen', True, True),
    'vilkar.html': ('Brukervilkår | Freelio',
                    'Brukervilkårene for kunder og frilansere på Freelio: konto, booking, betaling, avbestilling, innhold du laster opp og ansvar.',
                    'Brukervilkår', True, True),
    'frilansvilkar.html': ('Vilkår for frilansere | Freelio',
                           'Vilkårene for frilansere som tar oppdrag gjennom Freelio: profil, priser, leveranse, utbetaling, avgift og opphavsrett.',
                           'Vilkår for frilansere', True, True),
    'personvern.html': ('Personvernerklæring | Freelio',
                        'Hvordan Freelio samler inn, bruker og lagrer personopplysninger, hvor lenge de lagres, og hvilke rettigheter du har.',
                        'Personvern', True, True),
    'cookies.html': ('Cookies og lagring i nettleseren | Freelio',
                     'Freelio setter ingen sporings- eller reklamecookies. Her ser du hva som lagres i nettleseren for at siden skal virke.',
                     'Cookies', True, True),
    'opphavsrett.html': ('Opphavsrett og melding om ulovlig innhold | Freelio',
                         'Slik melder du bilder eller videoer som bryter opphavsretten din på Freelio, hva som skjer etterpå, og hvordan den som lastet opp kan klage.',
                         'Opphavsrett', True, True),
    # Sider som krever innlogging eller bare gir mening for den som bruker dem: indekseres ikke
    'logg-inn.html': ('Logg inn eller lag konto | Freelio', 'Logg inn eller lag konto på Freelio med e-post, Google eller telefonnummer.', 'Logg inn', False, False),
    'min-side.html': ('Min side | Freelio', 'Konto, frilanserprofil, varsler og personvern.', 'Min side', False, False),
    'mine-oppdrag.html': ('Mine oppdrag | Freelio', 'Bestillinger, annonser og tilbud.', 'Mine oppdrag', False, False),
    'meldinger.html': ('Meldinger | Freelio', 'Meldinger mellom kunder og frilansere.', 'Meldinger', False, False),
    'lagret.html': ('Lagret | Freelio', 'Frilansere, innlegg og oppdrag du har lagret, samlet i mapper.', 'Lagret', False, False),
    'sammenlign.html': ('Sammenlign frilansere | Freelio', 'Sammenlign opptil tre frilansere side om side.', 'Sammenlign', False, False),
    'book.html': ('Book frilanser | Freelio', 'Book en frilanser med trygg betaling.', 'Book', False, False),
    'bestilling.html': ('Bestilling | Freelio', 'Følg bestillingen fra booking til utbetaling.', 'Bestilling', False, False),
    'ny-annonse.html': ('Legg ut oppdrag | Freelio', 'Beskriv jobben med budsjett og område, så sender lokale frilansere deg tilbud.', 'Legg ut oppdrag', False, False),
    'meld-feil.html': ('Meld feil | Freelio', 'Fant du noe som ikke virker på Freelio? Fortell oss det, så fikser vi det.', 'Meld feil', False, False),
    'admin.html': ('Admin | Freelio', 'Moderering for administratorer.', 'Admin', False, False),
    'saker.html': ('Saker hos Freelio | Freelio', 'Saker mellom kunde og frilanser som Freelio avgjør.', 'Saker', False, False),
    '404.html': ('Fant ikke siden | Freelio', 'Lenken kan være feil, eller siden er flyttet.', 'Fant ikke siden', False, False),
}

# Bunnmenyen uten JavaScript (samme lenker som H.mountFooter i js/app.js)
FOOTER_LINKS = [('sok.html', 'Finn frilanser'), ('oppdrag.html', 'Oppdrag'), ('kart.html', 'Kart'), ('utforsk.html', 'Utforsk'),
                ('bli-frilanser.html', 'Bli frilanser'), ('slik-fungerer-det.html', 'Slik fungerer det'), ('slik-fungerer-det.html#priser', 'Priser'),
                ('hjelp.html', 'Hjelp'), ('om.html', 'Om oss'), ('vilkar.html', 'Vilkår'), ('frilansvilkar.html', 'Frilansvilkår'),
                ('personvern.html', 'Personvern'), ('opphavsrett.html', 'Opphavsrett'), ('cookies.html', 'Cookies')]
FOOTER = ('<div id="site-footer"><!-- statisk: tools/seo.py --><footer class="foot"><div class="wrap"><div class="foot-in">'
          '<div class="stack" style="gap:14px;max-width:300px"><a class="logo" href="index.html">Freelio</a>'
          '<p class="small muted">Finn, sammenlign og lei lokale frilansere. Pengene utbetales først når jobben er levert.</p></div>'
          '<nav aria-label="Bunnmeny">' + ''.join(f'<a href="{h}">{t}</a>' for h, t in FOOTER_LINKS) + '</nav></div>'
          '<div class="foot-bottom"><span>© 2026 Freelio</span></div></div></footer><!-- /statisk --></div>')

ORG = {'@type': 'Organization', '@id': SITE + '#organisasjon', 'name': 'Freelio', 'url': SITE,
       'logo': SITE + 'img/ikon-512.png', 'image': OG_IMAGE,
       'description': 'Markedsplass der folk finner, sammenligner og booker lokale fotografer, videografer og dronepiloter.',
       'areaServed': {'@type': 'Country', 'name': 'Norge'}}
WEBSITE = {'@type': 'WebSite', '@id': SITE + '#nettsted', 'name': 'Freelio', 'url': SITE, 'inLanguage': 'nb-NO',
           'publisher': {'@id': SITE + '#organisasjon'},
           'potentialAction': {'@type': 'SearchAction', 'target': {'@type': 'EntryPoint', 'urlTemplate': SITE + 'sok.html?q={search_term_string}'},
                               'query-input': 'required name=search_term_string'}}


def url_of(page):
    return SITE if page == 'index.html' else SITE + page


def ld_for(page, short):
    if page == 'index.html':
        return {'@context': 'https://schema.org', '@graph': [ORG, WEBSITE]}
    return {'@context': 'https://schema.org', '@type': 'BreadcrumbList', 'itemListElement': [
        {'@type': 'ListItem', 'position': 1, 'name': 'Forside', 'item': SITE},
        {'@type': 'ListItem', 'position': 2, 'name': short, 'item': url_of(page)}]}


def block(page):
    title, desc, short, index, canonical = SIDER[page]
    a = lambda s: html.escape(s, quote=True)
    out = ['<!-- seo: lages av tools/seo.py. Endre tekstene der, ikke her. -->',
           f'<meta name="description" content="{a(desc)}">',
           f'<meta name="robots" content="{"index, follow, max-image-preview:large" if index else "noindex, follow"}">']
    if canonical:
        out.append(f'<link rel="canonical" href="{url_of(page)}">')
    # Skriften i standarddesignet hentes med en gang, så teksten ikke hopper når den lastes (bedre LCP og CLS)
    out.append('<link rel="preload" href="css/fonts/figtree-latin.woff2" as="font" type="font/woff2" crossorigin>')
    out += ['<link rel="icon" href="img/favicon-48.png" sizes="48x48" type="image/png">',
            '<meta property="og:type" content="website">',
            '<meta property="og:site_name" content="Freelio">',
            '<meta property="og:locale" content="nb_NO">',
            f'<meta property="og:title" content="{a(title)}">',
            f'<meta property="og:description" content="{a(desc)}">']
    if canonical:
        out.append(f'<meta property="og:url" content="{url_of(page)}">')
    out += [f'<meta property="og:image" content="{OG_IMAGE}">',
            '<meta property="og:image:width" content="1200">',
            '<meta property="og:image:height" content="630">',
            f'<meta property="og:image:alt" content="{a(OG_ALT)}">',
            '<meta name="twitter:card" content="summary_large_image">']
    if index and page not in ('frilanser.html', 'annonse.html'):
        out.append('<script type="application/ld+json">' + json.dumps(ld_for(page, short), ensure_ascii=False).replace('</', '<\\/') + '</script>')
    out.append('<!-- /seo -->')
    return '\n'.join(out)


def fix_page(page):
    s = open(page, encoding='utf-8').read()
    orig = s
    title = SIDER[page][0]
    s = re.sub(r'<html lang="[^"]*">', '<html lang="nb">', s, count=1)
    s = re.sub(r'<title>[^<]*</title>', lambda m: f'<title>{html.escape(title, quote=False)}</title>', s, count=1)
    s = re.sub(r'\n<!-- seo:.*?<!-- /seo -->', '', s, flags=re.S)
    s = re.sub(r'\n<meta name="(description|robots)"[^>]*>', '', s)
    s = re.sub(r'(<title>[^<]*</title>)', lambda m: m.group(1) + '\n' + block(page), s, count=1)
    if page == '404.html':
        s = re.sub(r'\n<base href="[^"]*">', '', s)
        s = s.replace('<meta charset="utf-8">', f'<meta charset="utf-8">\n<base href="{BASE_PATH}">', 1)
    s = re.sub(r'<div id="site-footer">(<!-- statisk.*?<!-- /statisk -->)?</div>', FOOTER, s, count=1, flags=re.S)
    if s != orig:
        open(page, 'w', encoding='utf-8').write(s)
        return True
    return False


def lastmod(path):
    try:
        if subprocess.run(['git', 'status', '--porcelain', '--', path], capture_output=True, text=True).stdout.strip():
            return TODAY
        d = subprocess.run(['git', 'log', '-1', '--format=%cs', '--', path], capture_output=True, text=True).stdout.strip()
        return d or TODAY
    except OSError:
        return TODAY


def frilansere():
    """Publiserte frilansere fra Supabase (samme data som alle besøkende ser). Tom liste uten nett."""
    if not SB_URL or not SB_KEY:
        return []
    q = 'select=id,demo,published,created_at,name:data->>name,role:data->>role,area:data->>area&published=eq.true&order=created_at'
    req = urllib.request.Request(f'{SB_URL}/rest/v1/freelancers?{q}', headers={'apikey': SB_KEY, 'Accept': 'application/json'})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            rows = json.load(r)
    except Exception as e:  # noqa: BLE001 - sitemap lages uten profiler hvis Supabase ikke svarer
        print('Fikk ikke hentet frilansere fra Supabase:', e)
        return []
    return [x for x in rows if x.get('demo') is False and x.get('name')]


def write(path, text):
    old = open(path, encoding='utf-8').read() if os.path.exists(path) else None
    if old != text:
        open(path, 'w', encoding='utf-8', newline='\n').write(text)
        return True
    return False


def main():
    # Bekreftelsesfilen fra Google Search Console (google<kode>.html) skal stå urørt
    pages = sorted(p for p in glob.glob('*.html') if not re.fullmatch(r'google[0-9a-f]+\.html', p))
    unknown = [p for p in pages if p not in SIDER]
    if unknown:
        sys.exit('Mangler SEO-tekster i tools/seo.py for: ' + ', '.join(unknown))
    changed = [p for p in pages if fix_page(p)]

    profs = frilansere()
    urls = [(url_of(p), lastmod(p), '1.0' if p == 'index.html' else '0.8' if p in ('sok.html', 'utforsk.html', 'oppdrag.html', 'kart.html', 'bli-frilanser.html') else '0.5')
            for p in pages if SIDER[p][3] and SIDER[p][4]]
    urls += [(SITE + 'frilanser.html?id=' + urllib.parse.quote(f['id']), (f.get('created_at') or TODAY)[:10], '0.7') for f in profs]
    sm = ['<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    sm += [f'  <url><loc>{html.escape(u)}</loc><lastmod>{d}</lastmod><priority>{pr}</priority></url>' for u, d, pr in urls]
    sm.append('</urlset>')
    write('sitemap.xml', '\n'.join(sm) + '\n')

    write('robots.txt', '\n'.join([
        '# Freelio: alle søkemotorer og AI-tjenester (også GPTBot, ClaudeBot, PerplexityBot og Google-Extended) er velkomne.',
        '# Sider som krever innlogging har <meta name="robots" content="noindex"> i stedet for å stenges her,',
        '# så søkemotorene ser at de ikke skal i søkeresultatene.',
        '# Merk: robots.txt leses bare fra roten av domenet. På github.io/freelio/ virker den først med eget domene.',
        'User-agent: *',
        'Allow: /',
        '',
        f'Sitemap: {SITE}sitemap.xml',
        '']))

    L = lambda page, text: f'- [{SIDER[page][2]}]({url_of(page)}): {text}'
    llms = ['# Freelio', '',
            '> Freelio er en norsk markedsplass der folk finner, sammenligner og booker lokale fotografer, videografer og dronepiloter. '
            'Pengene holdes av en betalingspartner og utbetales til frilanseren først når kunden har godkjent leveransen. Freelio tar 5 % av hvert oppdrag.', '',
            'Freelio er i testfase, og betaling er ikke koblet på ennå. Tjenesten starter med foto og video i Bærum, Asker og Oslo. '
            'Fagfelt: bryllup, portrett, event, produkt, eiendom, bil, drone, reklamefilm og sosiale medier. Alt innhold er på norsk (bokmål).', '',
            '## Finn og book', '',
            L('sok.html', 'søk blant frilansere, filtrer på fagfelt, område, pris og vurdering'),
            L('kart.html', 'frilansere i nærheten på kart'),
            L('utforsk.html', 'bilder og video fra frilanserne'),
            L('oppdrag.html', 'oppdrag lagt ut av kunder, der frilansere kan sende tilbud'),
            L('slik-fungerer-det.html', 'hvordan booking, trygg betaling, avbestilling og priser fungerer'), '']
    if profs:
        llms += ['## Frilansere', '']
        llms += [f"- [{f['name']}]({SITE}frilanser.html?id={urllib.parse.quote(f['id'])}): {f.get('role') or 'Frilanser'}" + (f" i {f['area']}" if f.get('area') else '') for f in profs]
        llms.append('')
    llms += ['## For frilansere', '',
             L('bli-frilanser.html', 'lag gratis profil og få oppdrag'),
             L('frilansvilkar.html', 'vilkår for frilansere'), '',
             '## Vilkår, personvern og hjelp', '',
             L('avtale.html', 'oppdragsavtalen mellom kunde og frilanser'),
             L('vilkar.html', 'brukervilkår'),
             L('personvern.html', 'personvernerklæring'),
             L('opphavsrett.html', 'slik meldes brudd på opphavsretten'),
             L('cookies.html', 'hva som lagres i nettleseren'),
             L('hjelp.html', 'vanlige spørsmål og kontakt'), '',
             '## Optional', '',
             L('om.html', 'hvorfor Freelio finnes'), '']
    write('llms.txt', '\n'.join(llms))

    print(f'SEO oppdatert: {len(changed)} sider endret, {len(urls)} adresser i sitemap.xml ({len(profs)} frilansere).')


def bilde():
    chrome = next((p for p in [r'C:\Program Files\Google\Chrome\Application\chrome.exe', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
                               '/usr/bin/google-chrome', '/usr/bin/chromium'] if os.path.exists(p)), None)
    if not chrome:
        sys.exit('Fant ikke Google Chrome')
    src = 'file:///' + os.path.abspath('tools/og/og.html').replace('\\', '/').lstrip('/')
    subprocess.run([chrome, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1', '--window-size=1200,630',
                    '--allow-file-access-from-files', '--screenshot=' + os.path.abspath('img/og-freelio.png'), src], check=True)
    print('Lagde img/og-freelio.png')


if __name__ == '__main__':
    if '--bilde' in sys.argv:
        bilde()
    main()
