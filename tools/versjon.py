"""Legger et versjonsnummer på CSS- og JS-filene i alle HTML-sidene, for eksempel js/app.js?v=3f2a91c0.
Nummeret regnes ut fra innholdet i filene. Da henter nettleseren ny kode etter hver endring
i stedet for å bruke en gammel kopi. Kjør før hver push: python3 tools/versjon.py"""
import glob, hashlib, re, os
os.chdir(os.path.join(os.path.dirname(__file__), '..'))
def ver(path):
    return hashlib.sha1(open(path, 'rb').read()).hexdigest()[:8]
pat = re.compile(r'((?:src|href)=")((?:js|css)/[\w.-]+\.(?:js|css))(?:\?v=\w+)?(")')
for page in glob.glob('*.html'):
    s = open(page, encoding='utf-8').read()
    n = pat.sub(lambda m: m.group(1) + m.group(2) + '?v=' + ver(m.group(2)) + m.group(3), s)
    if n != s:
        open(page, 'w', encoding='utf-8').write(n)
print('Versjoner oppdatert')
