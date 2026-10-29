/* Felles kode for alle sider: lagring, toppmeny, bunntekst, cookies, kort og hjelpefunksjoner.
   All data lagres i nettleseren (localStorage). Bytt ut H.store med API-kall når backend er på plass. */
(function () {
  const D = window.HDATA;
  const H = (window.H = {});

  /* ---------- ikoner ---------- */
  const ICON = {
    home: '<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6h-6v6H4a1 1 0 0 1-1-1z"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    map: '<path d="M9 4 3 6v14l6-2 6 2 6-2V4l-6 2z"/><path d="M9 4v14M15 6v14"/>',
    bag: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/>',
    heart: '<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/>',
    save: '<path d="M6 4h12v16l-6-4-6 4z"/>',
    spark: '<path d="M12 3l1.8 4.6L18.5 9.5l-4.7 1.9L12 16l-1.8-4.6L5.5 9.5l4.7-1.9z"/><path d="M19 15l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8z"/>',
    back: '<path d="m15 18-6-6 6-6"/>',
    next: '<path d="m9 18 6-6-6-6"/>',
    close: '<path d="M6 6l12 12M18 6 6 18"/>',
    check: '<path d="m5 12 5 5 9-10"/>',
    shield: '<path d="M12 3 4 6v6c0 4.5 3.4 8.3 8 9 4.6-.7 8-4.5 8-9V6z"/><path d="m9 12 2 2 4-4"/>',
    chat: '<path d="M4 5h16v11H9l-5 4z"/>',
    arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/>',
    star: '<path d="M12 2.5l2.9 6 6.6.8-4.9 4.6 1.3 6.6L12 17.3l-5.9 3.2 1.3-6.6L2.5 9.3l6.6-.8z"/>',
    lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
    camera: '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
    video: '<rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3"/>',
    pen: '<path d="M4 20l4-1 11-11-3-3L5 16z"/><path d="m14 6 3 3"/>',
    hammer: '<path d="M14 4l6 6-3 3-6-6z"/><path d="M11 7 3 15l3 3 8-8"/>',
    music: '<path d="M9 18V5l11-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="17" cy="16" r="3"/>',
    paw: '<circle cx="7" cy="9" r="2"/><circle cx="12" cy="6" r="2"/><circle cx="17" cy="9" r="2"/><path d="M8 17c0-3 2-5 4-5s4 2 4 5c0 2-2 3-4 2-2 1-4 0-4-2z"/>',
    code: '<path d="m8 8-5 4 5 4M16 8l5 4-5 4M14 5l-4 14"/>',
    book: '<path d="M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2z"/><path d="M4 19V5"/>',
    menu: '<path d="M4 7h16M4 12h16M4 17h16"/>',
    pin: '<path d="M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11z"/><circle cx="12" cy="10" r="2.5"/>',
    filter: '<path d="M4 6h16M7 12h10M10 18h4"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    columns: '<rect x="3" y="4" width="7" height="16" rx="1.5"/><rect x="14" y="4" width="7" height="16" rx="1.5"/>',
    grid: '<rect x="4" y="4" width="7" height="7" rx="1"/><rect x="13" y="4" width="7" height="7" rx="1"/><rect x="4" y="13" width="7" height="7" rx="1"/><rect x="13" y="13" width="7" height="7" rx="1"/>',
    logout: '<path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10"/>'
  };
  H.icon = (n, s = 20, w = 1.8, fill = 'none') => `<svg aria-hidden="true" width="${s}" height="${s}" viewBox="0 0 24 24" fill="${fill}" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${ICON[n] || ''}</svg>`;
  H.star = (s = 14) => `<svg aria-hidden="true" width="${s}" height="${s}" viewBox="0 0 24 24" fill="currentColor">${ICON.star}</svg>`;

  /* ---------- små hjelpere ---------- */
  H.esc = (t) => String(t == null ? '' : t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  H.kr = (n) => Math.round(+n || 0).toLocaleString('nb-NO').replace(/\u00a0/g, ' ') + ' kr';
  H.num = (n) => String(n).replace('.', ',');
  H.qs = (k) => new URLSearchParams(location.search).get(k);
  H.pal = (i) => D.PAL[((i % D.PAL.length) + D.PAL.length) % D.PAL.length];
  H.phStyle = (i) => { const p = H.pal(i); return `--a:${p[0]};--b:${p[1]};--s:${p[2]}`; };
  H.cat = (id) => D.CATS.find((c) => c.id === id) || { id, name: id, icon: 'grid' };
  H.first = (name) => String(name).split(' ')[0];
  H.FEE = 0.05;
  H.today = () => new Date().toLocaleDateString('nb-NO', { day: '2-digit', month: '2-digit', year: 'numeric' });

  /* ---------- lagring ---------- */
  const KEY = 'freelio:v1';
  const DEFAULTS = () => ({
    user: null, saved: [], liked: [], cmp: [],
    orders: [{ id: 'o-seed', fid: 'jonas', title: 'Dronefilm', price: 4500, date: '20.10.2026', status: 'delivered', reviewed: false, delivered: '1 film, 62 sekunder i 4K', created: Date.now() - 864e5 * 10 }],
    myJobs: [], threads: {}, readThreads: {}, cookie: null, cookies: { analyse: false, ads: false },
    extraReviews: {}, profile: null, sentOffers: {}, asst: []
  });
  let mem = null;
  H.load = () => {
    if (mem) return mem;
    try { const raw = localStorage.getItem(KEY); mem = raw ? Object.assign(DEFAULTS(), JSON.parse(raw)) : DEFAULTS(); }
    catch (e) { mem = DEFAULTS(); }
    return mem;
  };
  H.save = () => { try { localStorage.setItem(KEY, JSON.stringify(mem)); } catch (e) { /* privat modus: data lever bare i denne fanen */ } };
  H.reset = () => { mem = DEFAULTS(); H.save(); };
  const S = (H.S = H.load());

  /* ---------- frilansere ---------- */
  H.all = () => {
    const list = D.FREELANCERS.map((f) => {
      const extra = S.extraReviews[f.id] || [];
      return extra.length ? Object.assign({}, f, { rv: extra.concat(f.rv), reviews: f.reviews + extra.length }) : f;
    });
    if (S.profile && S.profile.published) list.push(S.profile);
    return list;
  };
  H.byId = (id) => H.all().find((f) => f.id === id);
  H.priceTxt = (f) => 'fra ' + H.kr(f.from) + (f.unit || '');
  H.avatar = (f, s = 40) => `<span class="av" style="width:${s}px;height:${s}px;background:${f.col};font-size:${Math.round(s * 0.36)}px">${H.esc(f.ini)}</span>`;
  H.verified = (f) => (f.verified ? `<span style="color:var(--accent-ink);display:inline-flex" role="img" aria-label="BankID-verifisert">${H.icon('shield', 16, 2)}</span>` : '');

  H.fCard = (f, opts = {}) => {
    const saved = S.saved.includes(f.id);
    const inCmp = S.cmp.includes(f.id);
    return `<article class="fcard">
      <a href="frilanser.html?id=${f.id}" class="ph" style="${H.phStyle(f.pal)};aspect-ratio:4/3;border-radius:var(--radius)" aria-label="${H.esc(f.name)}, ${H.esc(f.role)}"></a>
      <button class="ibtn heart" data-a="save" data-v="${f.id}" aria-pressed="${saved}" aria-label="${saved ? 'Fjern fra lagrede' : 'Lagre'} ${H.esc(f.name)}" style="color:${saved ? 'var(--like)' : 'inherit'}">${H.icon('heart', 20, 1.8, saved ? 'currentColor' : 'none')}</button>
      ${opts.cmp ? `<button class="cmp" data-a="cmp" data-v="${f.id}" aria-pressed="${inCmp}">${H.icon(inCmp ? 'check' : 'columns', 14, 2.2)} Sammenlign</button>` : ''}
      <div class="row" style="justify-content:space-between"><span class="meta">${H.esc(f.area)} · ${f.km} km</span><span class="rate">${H.star()} ${H.num(f.rating.toFixed(1))} <span class="meta" style="font-weight:600">(${f.reviews})</span></span></div>
      <a href="frilanser.html?id=${f.id}" class="t" style="color:var(--fg);text-decoration:none">${H.esc(f.name)} ${H.verified(f)}</a>
      <span class="meta" style="margin-top:-6px">${H.esc(f.role)}</span>
      <span class="price">${H.priceTxt(f)}</span>
    </article>`;
  };

  /* ---------- oppdrag (annonser) ---------- */
  H.allJobs = () => S.myJobs.map((j) => Object.assign({ mine: true, km: 0, by: 'Deg', posted: j.postedTxt || 'nå' }, j)).reverse().concat(D.JOBS);
  H.jobById = (id) => H.allJobs().find((j) => j.id === id);
  H.jobOffers = (j) => (j.offersList || []).filter((o) => o.at <= Date.now());
  H.jobRow = (j) => {
    const c = H.cat(j.cat);
    const n = j.mine ? H.jobOffers(j).length : j.offers + (S.sentOffers[j.id] ? 1 : 0);
    return `<a class="jrow" href="annonse.html?id=${j.id}"><span class="ico">${H.icon(c.icon, 24)}</span>
      <div class="grow stack" style="gap:4px"><span class="row" style="gap:6px"><span class="pill">${c.name}</span>${j.mine ? '<span class="pill acc">Din annonse</span>' : ''}${S.sentOffers[j.id] ? '<span class="pill ok">Tilbud sendt</span>' : ''}${j.status === 'booked' ? '<span class="pill ok">Booket</span>' : ''}</span>
        <b style="font-size:16px">${H.esc(j.title)}</b><span class="meta">${H.esc(j.area)}${j.km ? ' · ' + j.km + ' km' : ''} · ${H.esc(j.date)} · lagt ut ${H.esc(j.posted)} · ${n} tilbud</span></div>
      <span class="budget">maks ${H.kr(j.budget)}</span></a>`;
  };

  /* ---------- bestillinger ---------- */
  H.createOrder = (o) => {
    const order = Object.assign({ id: 'o' + Date.now(), status: 'paid', reviewed: false, delivered: '', created: Date.now() }, o);
    S.orders.push(order); H.save();
    return order;
  };
  H.orderById = (id) => S.orders.find((o) => o.id === id);
  H.actionCount = () => S.orders.filter((o) => o.status === 'delivered' || (o.status === 'approved' && !o.reviewed)).length
    + S.myJobs.filter((j) => j.status === 'open' && H.jobOffers(j).some((o) => !o.seen)).length;

  /* ---------- meldinger ---------- */
  H.unread = () => Object.keys(S.threads).filter((fid) => { const t = S.threads[fid]; return t.length && t[t.length - 1].who === 'them' && (S.readThreads[fid] || 0) < t.length; }).length;
  H.sendMessage = (fid, text, onChange) => {
    text = String(text).trim(); if (!text) return;
    const f = H.byId(fid); if (!f) return;
    (S.threads[fid] = S.threads[fid] || []).push({ who: 'me', text, at: Date.now() });
    const t = text.toLowerCase(); let reply;
    if (/\d{3}\s?\d{2}\s?\d{3}|@|kontonummer|vipps meg/.test(t)) {
      S.threads[fid].push({ who: 'sys', text: 'Det ser ut som du deler kontaktinfo eller vil betale utenfor Freelio. Da er ikke betalingen beskyttet, og du mister retten til refusjon.', at: Date.now() });
      reply = 'Vi tar gjerne alt her i appen, så er vi begge trygge.';
    } else if (/pris|koster|kost|tilbud/.test(t)) reply = f.pk.map((p) => p[0] + ': ' + H.kr(p[1])).join('\n') + '\n\nDu kan booke en pakke direkte fra profilen min.';
    else if (/ledig|dato|når/.test(t)) reply = f.free ? 'Jeg har ledige datoer i november og desember. Hvilken dato tenker du på?' : 'Jeg er ganske booket fremover, men har ledig fra midten av desember.';
    else reply = `Takk for meldingen! Fortell gjerne litt mer om ${f.cat === 'dyr' ? 'hunden din' : 'oppdraget'}, så kommer jeg med et forslag.`;
    H.save(); onChange && onChange('typing');
    setTimeout(() => { S.threads[fid].push({ who: 'them', text: reply, at: Date.now() }); H.save(); onChange && onChange('reply'); H.mountHeader(); }, 1300);
  };

  /* ---------- assistent ---------- */
  H.ANSWERS = {
    'Hva bør jeg se etter i en fotograf?': { text: 'Se etter dette:\n\n1. Hele serier, ikke bare de beste bildene. Be om et fullt galleri fra en lignende jobb.\n2. Bilder i samme lys som ditt oppdrag. Vinterstid betyr lite dagslys.\n3. Lik stil i redigeringen gjennom hele serien.\n4. Hvor mye du får levert, og når.\n5. Hvem som eier rettighetene til bildene.\n\nI Sammenlign ser du leveringstid, svartid og pris side om side.', act: ['sammenlign.html', 'Åpne sammenligning'] },
    'Hva er en vanlig pris?': { text: 'Blant frilanserne på Freelio i Bærum og Asker:\n\nFotograf, halv dag: 8 000 til 9 500 kr\nKort reklamefilm: rundt 12 000 kr\nLogo: rundt 6 000 kr\nSnekker: rundt 650 kr per time\nHundelufting: rundt 250 kr per tur\n\nSett maks budsjett litt over det du helst vil betale. Da får du flere tilbud å velge mellom.' },
    'Hva bør jeg spørre om før jeg booker?': { text: 'Gode spørsmål:\n\n· Har du reserveutstyr?\n· Hva skjer hvis du blir syk?\n· Kan jeg se en hel jobb du har gjort?\n· Er reise inkludert?\n· Hvor mange runder med endringer får jeg?' },
    'Hvordan fungerer trygg betaling?': { text: 'Du betaler når du booker. Pengene holdes av betalingspartneren vår, og frilanseren får dem først når du har godkjent leveransen.\n\nDu har 5 dager på å se over. Er noe feil, melder du fra, og pengene holdes til saken er løst. Svarer du ikke, godkjennes leveransen automatisk.\n\nFreelio tar 5 % av beløpet fra frilanseren.', act: ['slik-fungerer-det.html#betaling', 'Les mer om betaling'] },
    'Skriv annonsen for meg': { text: 'Her er et forslag for et bryllup i Bærum. Du kan endre alt før du publiserer.', act: ['ny-annonse.html?eksempel=1', 'Åpne utfylt annonse'] }
  };
  H.answer = (q) => {
    if (H.ANSWERS[q]) return H.ANSWERS[q];
    const t = q.toLowerCase();
    if (/pris|koste|budsjett|dyrt/.test(t)) return H.ANSWERS['Hva er en vanlig pris?'];
    if (/betal|penger|depositum|trygg|refus/.test(t)) return H.ANSWERS['Hvordan fungerer trygg betaling?'];
    if (/annonse|skriv/.test(t)) return H.ANSWERS['Skriv annonsen for meg'];
    if (/fotograf|foto|bilde|video/.test(t)) return H.ANSWERS['Hva bør jeg se etter i en fotograf?'];
    if (/snekker|håndverk|kjøkken|terrasse/.test(t)) return { text: 'For snekker: be om befaring før pris, spør om materialer er med, og sjekk at firmaet er registrert i Brønnøysundregistrene. Erik Lunde i Bærum har gratis befaring.', act: ['frilanser.html?id=erik', 'Se Erik Lunde'] };
    if (/hund|dyr|katt/.test(t)) return { text: 'For hundepasser: spør om erfaring med din rase, hvor mange hunder de går med samtidig og om de har politiattest. Leo Karlsen i Sandvika har politiattest og 54 omtaler.', act: ['frilanser.html?id=leo', 'Se Leo Karlsen'] };
    if (/nettside|web|app|it/.test(t)) return { text: 'For nettside: spør om du kan oppdatere innholdet selv, hvem som eier domenet og hva drift koster per måned.', act: ['sok.html?kat=it', 'Se utviklere'] };
    return { text: 'Fortell meg hva slags jobb det gjelder, når og hvor, så hjelper jeg deg å finne riktig person og skrive en tydelig annonse.' };
  };

  /* ---------- auth ---------- */
  H.requireLogin = () => {
    if (S.user) return true;
    location.replace('logg-inn.html?neste=' + encodeURIComponent(location.pathname.split('/').pop() + location.search));
    return false;
  };

  /* ---------- toast ---------- */
  let tt;
  H.toast = (msg) => {
    let el = document.getElementById('toast');
    if (!el) { el = document.createElement('div'); el.id = 'toast'; el.className = 'toast'; el.setAttribute('role', 'status'); document.body.appendChild(el); }
    el.textContent = msg; el.hidden = false;
    clearTimeout(tt); tt = setTimeout(() => (el.hidden = true), 3600);
  };
  H.flash = (msg) => { try { sessionStorage.setItem('freelio:flash', msg); } catch (e) {} };

  /* ---------- toppmeny og bunntekst ---------- */
  const page = document.body.dataset.page || '';
  H.mountHeader = () => {
    const el = document.getElementById('site-header'); if (!el) return;
    const nav = [['utforsk.html', 'Utforsk'], ['sok.html', 'Finn frilanser'], ['oppdrag.html', 'Oppdrag'], ['kart.html', 'Kart']];
    const cur = (href) => (href.replace('.html', '') === page ? 'aria-current="page"' : '');
    const unread = H.unread(); const act = H.actionCount();
    const wasOpen = el.querySelector('.top.open');
    el.innerHTML = `<div class="demo-note">Demo. Ingen ekte innlogging eller betaling. Data lagres bare i nettleseren din.</div>
    <header class="top${wasOpen ? ' open' : ''}"><div class="wrap">
      <div class="top-in">
        <a class="logo" href="index.html" aria-label="Freelio, til forsiden"><span class="logo-mark">${H.icon('check', 18, 3)}</span>Freelio</a>
        <nav class="mainnav" aria-label="Hovedmeny">${nav.map(([h, t]) => `<a href="${h}" ${cur(h)}>${t}</a>`).join('')}</nav>
        <div class="usernav">
          <a class="hide-md" href="assistent.html" ${cur('assistent.html')}>${H.icon('spark', 18)} Assistent</a>
          <a class="hide-sm" href="meldinger.html" ${cur('meldinger.html')} aria-label="Meldinger${unread ? ', ' + unread + ' uleste' : ''}">${H.icon('chat', 20)}<span class="hide-md">Meldinger</span>${unread ? `<span class="count">${unread}</span>` : ''}</a>
          <a class="hide-sm" href="mine-oppdrag.html" ${cur('mine-oppdrag.html')} aria-label="Mine oppdrag${act ? ', ' + act + ' venter på deg' : ''}">${H.icon('bag', 20)}<span class="hide-md">Mine oppdrag</span>${act ? `<span class="count">${act}</span>` : ''}</a>
          ${S.user ? `<a href="min-side.html" ${cur('min-side.html')} aria-label="Min side">${H.icon('user', 20)}<span class="hide-md">${H.esc(H.first(S.user.name))}</span></a>` : `<a href="logg-inn.html" ${cur('logg-inn.html')}>${H.icon('user', 20)}<span class="hide-sm">Logg inn</span></a>`}
          <a class="btn primary sm hide-sm" href="ny-annonse.html" style="color:var(--on-accent);margin-left:6px">${H.icon('plus', 18, 2.2)} Ny annonse</a>
        </div>
        <button class="ibtn menu-btn" data-a="menu" aria-expanded="${!!wasOpen}" aria-label="Meny">${H.icon('menu', 22)}</button>
      </div>
      <nav class="drawer" aria-label="Meny for mobil">
        <a href="ny-annonse.html">Legg ut oppdrag</a>${nav.map(([h, t]) => `<a href="${h}">${t}</a>`).join('')}
        <a href="assistent.html">Assistent</a><a href="meldinger.html">Meldinger${unread ? ` (${unread})` : ''}</a><a href="mine-oppdrag.html">Mine oppdrag${act ? ` (${act})` : ''}</a>
        <a href="${S.user ? 'min-side.html' : 'logg-inn.html'}">${S.user ? 'Min side' : 'Logg inn'}</a><a href="bli-frilanser.html">Bli frilanser</a>
      </nav>
    </div></header>`;
  };
  H.mountFooter = () => {
    const el = document.getElementById('site-footer'); if (!el) return;
    el.innerHTML = `<footer class="foot"><div class="wrap">
      <div class="foot-grid">
        <div class="stack" style="gap:10px"><a class="logo" href="index.html"><span class="logo-mark">${H.icon('check', 18, 3)}</span>Freelio</a><p class="small muted">Finn, sammenlign og lei lokale frilansere. Pengene utbetales først når jobben er levert.</p></div>
        <div><h3>For kunder</h3><ul><li><a href="sok.html">Finn frilanser</a></li><li><a href="ny-annonse.html">Legg ut oppdrag</a></li><li><a href="sammenlign.html">Sammenlign</a></li><li><a href="assistent.html">Assistent</a></li></ul></div>
        <div><h3>For frilansere</h3><ul><li><a href="bli-frilanser.html">Bli frilanser</a></li><li><a href="oppdrag.html">Ledige oppdrag</a></li><li><a href="slik-fungerer-det.html#priser">Priser og avgift</a></li></ul></div>
        <div><h3>Hjelp</h3><ul><li><a href="slik-fungerer-det.html">Slik fungerer det</a></li><li><a href="slik-fungerer-det.html#betaling">Trygg betaling</a></li><li><a href="hjelp.html">Hjelpesenter</a></li><li><a href="om.html">Om Freelio</a></li></ul></div>
        <div><h3>Personvern og vilkår</h3><ul><li><a href="vilkar.html">Brukervilkår</a></li><li><a href="personvern.html">Personvern</a></li><li><a href="cookies.html">Cookies</a></li><li><a href="#" data-a="cookieSettings">Endre cookie-valg</a></li></ul></div>
      </div>
      <div class="foot-bottom"><span>© 2026 Freelio</span><span>Betaling gjennom lisensiert betalingspartner. Innlogging med Vipps og BankID.</span></div>
    </div></footer>`;
  };
  H.mountCookie = (force) => {
    if (S.cookie && !force) return;
    let el = document.getElementById('cookie');
    if (!el) { el = document.createElement('div'); el.id = 'cookie'; el.className = 'cookie'; el.setAttribute('role', 'dialog'); el.setAttribute('aria-label', 'Cookies'); document.body.appendChild(el); }
    el.innerHTML = `<b>Vi bruker cookies</b><p class="small muted">Nødvendige cookies holder deg innlogget og betalingen trygg. Med ditt samtykke bruker vi også cookies til statistikk og markedsføring. <a href="cookies.html">Les mer</a></p>
      <div class="row"><button class="btn soft" data-a="cookie" data-v="no">Kun nødvendige</button><button class="btn soft" data-a="cookie" data-v="yes">Godta alle</button></div>`;
  };

  /* ---------- felles handlinger ---------- */
  H.actions = {
    menu: (v, el) => { const top = el.closest('.top'); top.classList.toggle('open'); el.setAttribute('aria-expanded', top.classList.contains('open')); },
    cookie: (v) => { S.cookie = v; S.cookies = { analyse: v === 'yes', ads: v === 'yes' }; H.save(); const c = document.getElementById('cookie'); if (c) c.remove(); H.toast(v === 'yes' ? 'Takk. Du kan endre valget under Min side.' : 'Vi bruker bare nødvendige cookies.'); },
    cookieSettings: () => H.mountCookie(true),
    save: (v) => {
      const i = S.saved.indexOf(v);
      if (i > -1) { S.saved.splice(i, 1); H.toast('Fjernet fra lagrede.'); } else { S.saved.push(v); H.toast('Lagret. Du finner lagrede på Min side.'); }
      H.save(); H.rerender();
    },
    cmp: (v) => {
      const i = S.cmp.indexOf(v);
      if (i > -1) S.cmp.splice(i, 1);
      else if (S.cmp.length >= 3) { H.toast('Du kan sammenligne opptil 3 om gangen.'); return; }
      else S.cmp.push(v);
      H.save(); H.rerender();
    }
  };
  H.render = null;
  H.rerender = () => { if (H.render) H.render(); };

  document.addEventListener('click', (e) => {
    const el = e.target.closest('[data-a]');
    if (!el) return;
    const fn = H.actions[el.dataset.a];
    if (!fn) return;
    e.preventDefault();
    fn(el.dataset.v, el, e);
  });

  H.boot = (render) => {
    H.render = render || null;
    H.mountHeader(); H.mountFooter(); H.mountCookie();
    if (render) render();
    try { const f = sessionStorage.getItem('freelio:flash'); if (f) { sessionStorage.removeItem('freelio:flash'); H.toast(f); } } catch (e) {}
  };
})();
