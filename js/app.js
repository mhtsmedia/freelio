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
    logout: '<path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    play: '<path d="M7 4v16l13-8z"/>',
    download: '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
    drone: '<circle cx="5" cy="6" r="2.5"/><circle cx="19" cy="6" r="2.5"/><circle cx="5" cy="18" r="2.5"/><circle cx="19" cy="18" r="2.5"/><path d="M7 8l3 3M17 8l-3 3M7 16l3-3M17 16l-3-3"/><rect x="10" y="10" width="4" height="4" rx="1"/>',
    phone: '<rect x="7" y="3" width="10" height="18" rx="2"/><path d="M11 18h2"/>',
    rotate: '<path d="M20 11a8 8 0 1 0-2.3 5.7"/><path d="M20 4v7h-7"/>',
    'c-automotiv': '<path d="M3.5 16.5H3v-3.2c0-.5.2-1 .6-1.3L6 9.8l1.6-2.6c.3-.5.9-.8 1.5-.8h5.6c.6 0 1.1.3 1.5.7l2.3 2.7 2.4.7c.7.2 1.1.8 1.1 1.5v3.3c0 .5-.4 1-1 1h-.5"/><path d="M10 16.5h4"/><circle cx="7" cy="16.5" r="2.3"/><circle cx="17" cy="16.5" r="2.3"/><path d="M6 9.8h12.5M12 6.4v3.4"/>',
    'c-bryllup': '<path d="M12 7.2c-1.5-1.1-2.6-1.9-2.6-3 0-1.1 1.5-1.6 2.6-.4 1.1-1.2 2.6-.7 2.6.4 0 1.1-1.1 1.9-2.6 3z"/><circle cx="7" cy="12" r="2.7"/><circle cx="17" cy="12" r="2.7"/><path d="M4.3 12c0 1.9.3 3.2.9 4M9.7 12c0 1.9-.3 3.2-.9 4"/><path d="M2 21.5c.4-2.5 2.4-4 5-4s4.6 1.5 5 4M12 21.5c.4-2.5 2.4-4 5-4s4.6 1.5 5 4"/><path d="m15.6 17.7 1.4 1.8 1.4-1.8"/>',
    'c-portrett': '<rect x="4" y="2.5" width="16" height="19" rx="2.5"/><circle cx="12" cy="10" r="3.2"/><path d="M7.5 21.5c.7-3 2.4-4.7 4.5-4.7s3.8 1.7 4.5 4.7"/>',
    'c-event': '<rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/><path d="M7 13.5h.01M11 13.5h.01M7 17.5h.01"/><circle cx="16" cy="16" r="2.8"/><path d="m14.8 16.1.9.9 1.6-1.7"/>',
    'c-produkt': '<path d="M12 2.5 3.5 7v10l8.5 4.5 8.5-4.5V7z"/><path d="M3.5 7 12 11.5 20.5 7M12 11.5v10"/><path d="m7.8 4.7 8.4 4.6v3.4"/><path d="M6 14.6l2 1M6 16.8l1.3.7"/>',
    'c-eiendom': '<path d="M3 11 12 3.5l9 7.5"/><path d="M5.5 9.5v11h13v-11"/><path d="M10 20.5v-5.5h4v5.5"/>',
    'c-drone': '<path d="M2 5h7M15 5h7M5.5 5v2.5M18.5 5v2.5"/><rect x="3.5" y="7.5" width="4" height="3" rx="1"/><rect x="16.5" y="7.5" width="4" height="3" rx="1"/><path d="M7.5 9.5h2c0-1.6 1.1-2.8 2.5-2.8s2.5 1.2 2.5 2.8h2M7.5 9.5l2.5 3h4l2.5-3"/><path d="M9.6 12.5 8 19M14.4 12.5 16 19"/><rect x="10.3" y="14" width="3.4" height="3" rx=".8"/>',
    'c-reklamefilm': '<rect x="3" y="9" width="18" height="12" rx="2"/><path d="M3 9 2.4 5.6l16.8-3 .6 3.4"/><path d="M6.8 4.8 8.9 8M12 3.9l2.1 3.2"/><path d="M10.5 12.5v5l4-2.5z"/>',
    'c-some': '<rect x="6" y="2.5" width="12" height="19" rx="2.5"/><path d="M10.5 5h3"/><path d="M9 10.5c0-.8.6-1.5 1.5-1.5h3c.9 0 1.5.7 1.5 1.5v2c0 .8-.6 1.5-1.5 1.5h-2L10 15.5V14h0c-.6 0-1-.7-1-1.5z"/><path d="M8.5 18.5h7"/>',
    clipboard: '<rect x="4.5" y="4" width="15" height="17.5" rx="2.5"/><path d="M9 4V2.8h1.6a1.4 1.4 0 0 1 2.8 0H15V5.5H9z"/><path d="m7.5 10 1.2 1.2 2-2M7.5 14.5l1.2 1.2 2-2M13 10.2h3.5M13 14.7h3.5"/>',
    moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>'
  };
  H.icon = (n, s = 20, w = 1.8, fill = 'none') => `<svg aria-hidden="true" width="${s}" height="${s}" viewBox="0 0 24 24" fill="${fill}" stroke="currentColor" stroke-width="${Math.round(w * 78) / 100}" stroke-linecap="round" stroke-linejoin="round">${ICON[n] || ''}</svg>`;
  H.star = (s = 14) => `<svg aria-hidden="true" width="${s}" height="${s}" viewBox="0 0 24 24" fill="currentColor">${ICON.star}</svg>`;

  /* ---------- små hjelpere ---------- */
  H.esc = (t) => String(t == null ? '' : t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  H.kr = (n) => Math.round(+n || 0).toLocaleString('nb-NO').replace(/\u00a0/g, ' ') + ' kr';
  H.num = (n) => String(n).replace('.', ',');
  H.qs = (k) => new URLSearchParams(location.search).get(k);
  H.pal = (i) => D.PAL[((i % D.PAL.length) + D.PAL.length) % D.PAL.length];
  H.phStyle = (i) => { const p = H.pal(i); return `--a:${p[0]};--b:${p[1]};--s:${p[2]}`; };
  H.inCat = (f, kat) => kat === 'alle' || f.cat === kat || (f.niches || []).includes(kat);
  // Kategorien «Bilder» heter nå «Automotiv». Gamle profiler, bilder og innlegg flyttes over.
  const OLD = { bilder: 'automotiv' };
  H.fixCats = (f) => {
    if (!f) return f;
    if (OLD[f.cat]) f.cat = OLD[f.cat];
    if (f.niches) f.niches = [...new Set(f.niches.map((n) => OLD[n] || n))];
    (f.portfolio || []).forEach((x) => { if (OLD[x.cat]) x.cat = OLD[x.cat]; });
    return f;
  };
  H.cat = (id) => D.CATS.find((c) => c.id === id) || { id, name: id, icon: 'grid' };
  H.first = (name) => String(name).split(' ')[0];
  H.FEE = 0.05;
  H.today = () => new Date().toLocaleDateString('nb-NO', { day: '2-digit', month: '2-digit', year: 'numeric' });

  /* ---------- lagring ---------- */
  const KEY = 'freelio:v1';
  const DEFAULTS = () => ({
    user: null, saved: [], liked: [], cmp: [],
    orders: [],
    myJobs: [], threads: {}, readThreads: {}, cookie: null, cookies: { analyse: false, ads: false },
    extraReviews: {}, profile: null, sentOffers: {}, asst: [], posts: [], folders: []
  });
  let mem = null;
  H.load = (force) => {
    if (mem && !force) return mem;
    try { const raw = localStorage.getItem(KEY); mem = raw ? Object.assign(DEFAULTS(), JSON.parse(raw)) : DEFAULTS(); }
    catch (e) { mem = DEFAULTS(); }
    return mem;
  };
  H.saveLocal = () => { try { localStorage.setItem(KEY, JSON.stringify(mem)); } catch (e) { /* privat modus: data lever bare i denne fanen */ } };
  // Byttes ut av cloud.js når databasen er koblet til
  H.save = H.saveLocal;
  H.flush = () => Promise.resolve();
  H.go = (url) => { location.href = url; };
  H.uid = () => (window.crypto && crypto.randomUUID ? crypto.randomUUID() : 'id' + Date.now() + Math.random().toString(36).slice(2));
  H.reset = () => { mem = DEFAULTS(); H.save(); };
  const S = (H.S = H.load());

  /* ---------- frilansere ---------- */
  H.all = () => {
    // Legger til ekte omtaler. Ekte frilansere får snitt bare av ekte omtaler. Demo-frilansere har et startgrunnlag.
    const withReviews = (f) => {
      H.fixCats(f);
      const extra = (S.extraReviews || {})[f.id] || [];
      const real = f.demo === false || f.id === (S.profile && S.profile.id);
      const baseN = real ? 0 : f.reviews || 0, baseSum = real ? 0 : (f.rating || 0) * baseN;
      const n = baseN + extra.length;
      const done = real ? Math.max(f.jobs || 0, extra.length, (S.orders || []).filter((o) => o.fid === f.id && o.status === 'approved').length) : f.jobs;
      return Object.assign({}, f, { jobs: done, rv: extra.concat(real ? [] : f.rv || []), reviews: n, realReviews: extra.length, rating: n ? (baseSum + extra.reduce((t, r) => t + r[1], 0)) / n : 0 });
    };
    const list = D.FREELANCERS.filter((f) => !S.profile || f.id !== S.profile.id).map(withReviews);
    if (S.profile && S.profile.published) list.push(withReviews(S.profile));
    return list;
  };
  H.byId = (id) => H.all().find((f) => f.id === id);
  // Rydd bort data som peker til frilansere som ikke finnes lenger (for eksempel fra en eldre versjon)
  H.prune = function prune() {
    const ok = (id) => !!H.byId(id);
    S.orders = S.orders.filter((o) => ok(o.fid));
    Object.keys(S.threads).forEach((id) => { if (!ok(id)) delete S.threads[id]; });
    S.saved = S.saved.filter(ok); S.cmp = S.cmp.filter(ok);
    S.myJobs.forEach((j) => { j.offersList = (j.offersList || []).filter((o) => ok(o.fid)); });
    Object.keys(S.extraReviews).forEach((id) => { if (!ok(id)) delete S.extraReviews[id]; });
    if (S.profile && !D.CATS.some((c) => c.id === S.profile.cat)) S.profile.cat = D.CATS[0].id;
  };
  // Samtalepartner: en frilanser, eller en kunde når du selv er frilanseren (nøkkel c:<kunde-id>)
  H.partner = (key) => {
    if (String(key).startsWith('c:')) { const p = (S.partners || {})[key] || { name: 'Kunde' }; return { id: key, name: p.name, photo: p.photo || null, ini: String(p.name).split(/\s+/).map((w) => w[0] || '').join('').slice(0, 2).toUpperCase(), col: '#5B5F97', resp: '', customer: true, gone: !!p.gone }; }
    return H.byId(key);
  };
  H.ratingTxt = (f) => (f.reviews > 0 ? H.num((+f.rating).toFixed(1)) : 'Ny');
  H.priceTxt = (f) => 'fra ' + H.kr(f.from) + (f.unit || '');
  H.avatar = (f, s = 40) => `<span class="av" style="width:${s}px;height:${s}px;background:${f.col || '#5B5F97'};font-size:${Math.round(s * 0.36)}px">${f.photo ? `<img src="${H.esc(f.photo)}" alt="" loading="lazy">` : H.esc(f.ini || '?')}</span>`;
  // Bilde fra porteføljen hvis frilanseren har lastet opp, ellers plassholder
  // i = 'cover' gir bakgrunnsbildet (eller første bilde i porteføljen)
  // i = 'card' gir bildet på kortet i søket: eget kortbilde, ellers bakgrunnsbildet, ellers første bilde i porteføljen
  H.ph = (f, i = 0, cls = '', tag = 'span', attrs = '', inner = '', big = false) => {
    const isCover = i === 'cover', isCard = i === 'card'; if (isCover || isCard) i = 0;
    const own = (isCard && (f.cardImg || f.coverImg)) || (isCover && f.coverImg) || null;
    const img = own || (f.portfolio || [])[i];
    const vid = img && img.type === 'video';
    if (img) return `<${tag} class="ph has-img ${cls}" ${attrs}><img class="cover" src="${H.esc(vid ? img.thumb : big ? img.url : img.thumb || img.url)}" alt="" loading="lazy">${vid && !own ? `<span class="play-badge">${H.icon('play', 16, 2, 'currentColor')}</span>` : ''}${inner}</${tag}>`;
    return `<${tag} class="ph ${cls}" style="${H.phStyle((f.pal || 0) + i)}" ${attrs}>${inner}</${tag}>`;
  };

  /* ---------- bilder (profil og portefølje) ---------- */
  H.resizeImage = async (file, max, square = false, q = 0.82) => {
    if (!file || !/^image\//.test(file.type)) throw new Error('Velg en bildefil (JPG, PNG eller WebP).');
    let bmp;
    try { bmp = await createImageBitmap(file, { imageOrientation: 'from-image' }); }
    catch (e) { bmp = await new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = () => rej(new Error('Kunne ikke lese bildet. Prøv JPG eller PNG.')); i.src = URL.createObjectURL(file); }); }
    const w = bmp.width || bmp.naturalWidth, h = bmp.height || bmp.naturalHeight;
    let sx = 0, sy = 0, sw = w, sh = h;
    if (square) { const m = Math.min(w, h); sx = (w - m) / 2; sy = (h - m) / 2; sw = sh = m; }
    const k = Math.min(1, max / Math.max(sw, sh)), cw = Math.round(sw * k), ch = Math.round(sh * k);
    const cv = document.createElement('canvas'); cv.width = cw; cv.height = ch;
    cv.getContext('2d').drawImage(bmp, sx, sy, sw, sh, 0, 0, cw, ch);
    const blob = await new Promise((r) => cv.toBlob((b) => (b && b.type === 'image/webp' ? r(b) : cv.toBlob(r, 'image/jpeg', q)), 'image/webp', q));
    return { blob, w: cw, h: ch };
  };
  // Lagrer et bilde og gir tilbake en adresse. I demo-modus blir det en data-URL. cloud.js bytter til Supabase Storage.
  H.storeImage = (kind, blob) => new Promise((r) => { const fr = new FileReader(); fr.onload = () => r(fr.result); fr.readAsDataURL(blob); });
  H.dropImage = async () => {};
  // Lager et stillbilde fra videoen som brukes i rutenettet
  H.videoPoster = (file) => {
    return new Promise((res, rej) => {
      const v = document.createElement('video'), u = URL.createObjectURL(file);
      const stop = setTimeout(() => { URL.revokeObjectURL(u); rej(new Error('Nettleseren kan ikke lese denne videoen. Prøv MP4.')); }, 15000);
      v.muted = true; v.playsInline = true; v.preload = 'auto'; v.src = u;
      v.onerror = () => { clearTimeout(stop); URL.revokeObjectURL(u); rej(new Error('Nettleseren kan ikke lese denne videoen. Prøv MP4.')); };
      v.onloadedmetadata = () => { v.currentTime = Math.min(1, (v.duration || 2) / 3); };
      v.onseeked = () => {
        const k = Math.min(1, 900 / Math.max(v.videoWidth, v.videoHeight)), c = document.createElement('canvas');
        c.width = Math.round(v.videoWidth * k); c.height = Math.round(v.videoHeight * k);
        c.getContext('2d').drawImage(v, 0, 0, c.width, c.height);
        c.toBlob((b) => { clearTimeout(stop); URL.revokeObjectURL(u); b ? res({ blob: b, w: v.videoWidth, h: v.videoHeight, dur: Math.round(v.duration) }) : rej(new Error('Kunne ikke lage forhåndsvisning.')); }, 'image/jpeg', 0.82);
      };
    });
  };
  H.VID_MB = () => (window.Cloud && Cloud.on ? 50 : 3);
  // Komprimerer en video i nettleseren til den er under grensen. Bruker Mediabunny (WebCodecs).
  // Lastes bare inn når noen faktisk laster opp en video som er for stor.
  // o.max er grensen i byte (standard er grensen for porteføljen), o.minBr er laveste bitrate vi godtar
  H.fitVideo = async (file, onProgress, o = {}) => {
    const max = o.max || H.VID_MB() * 1048576, mbTxt = Math.round(max / 1048576), minBr = o.minBr || 350000;
    if (file.size <= max) return file;
    if (!window.VideoEncoder) throw new Error('Videoen er over ' + mbTxt + ' MB, og denne nettleseren kan ikke gjøre den mindre. Prøv Chrome, Edge eller Safari, eller korte ned videoen.');
    const MB = await import(new URL('js/vendor/mediabunny-1.61.4.min.mjs', document.baseURI).href);
    const input = new MB.Input({ formats: MB.ALL_FORMATS, source: new MB.BlobSource(file) });
    const vt = await input.getPrimaryVideoTrack();
    if (!vt) throw new Error('Fant ingen video i filen.');
    const dur = await input.computeDuration();
    const audioBr = 96000, dw = vt.displayWidth, dh = vt.displayHeight;
    // Sikter på 88 % av grensen. Blir filen likevel for stor, prøver den igjen med lavere kvalitet.
    let vbr = Math.min(6e6, Math.floor((max * 0.88 * 8) / Math.max(1, dur) - audioBr));
    if (vbr < minBr) throw new Error(`Videoen er for lang til å bli under ${mbTxt} MB i god kvalitet. Korte den ned til under ${Math.floor((max * 0.88 * 8) / (minBr + 100000) / 60)} minutter.`);
    for (let round = 0; round < 3; round++) {
      const long = vbr > 3.5e6 ? 1920 : vbr > 1.6e6 ? 1280 : vbr > 800000 ? 960 : 640;
      const k = Math.min(1, long / Math.max(dw, dh));
      const width = Math.round((dw * k) / 2) * 2, height = Math.round((dh * k) / 2) * 2;
      const src = round ? new MB.Input({ formats: MB.ALL_FORMATS, source: new MB.BlobSource(file) }) : input;
      const output = new MB.Output({ format: new MB.Mp4OutputFormat({ fastStart: 'in-memory' }), target: new MB.BufferTarget() });
      const conv = await MB.Conversion.init({ input: src, output, video: { width, height, fit: 'fill', bitrate: vbr }, audio: { bitrate: audioBr }, showWarnings: false });
      if (!conv.isValid) throw new Error('Nettleseren kan ikke komprimere denne videoen. Prøv å eksportere den som MP4 og last opp igjen.');
      if (onProgress) conv.onProgress = (p) => onProgress(Math.min(99, Math.round((round * 100 + p * 100) / (round + 1))));
      await conv.execute();
      const out = new Blob([output.target.buffer], { type: 'video/mp4' });
      if (out.size <= max) { if (onProgress) onProgress(100); return out; }
      vbr = Math.floor(vbr * ((max * 0.8) / out.size));
      if (vbr < minBr * 0.7) break;
    }
    throw new Error(`Klarte ikke å få videoen under ${mbTxt} MB. Korte den ned og prøv igjen.`);
  };
  // Innlegg på Utforsk. Uten database lagres de bare i nettleseren. cloud.js bytter til Supabase.
  H.addPost = async (p) => { S.posts = S.posts || []; S.posts.unshift(Object.assign({}, p, { id: H.uid(), fid: S.profile.id, at: Date.now() })); H.save(); };
  H.removePost = async (id) => { S.posts = (S.posts || []).filter((x) => x.id !== id); H.save(); };
  // Redigering av profilbilde: dra for å flytte, zoom med glidebryter, hjul eller to fingre, roter 90 grader.
  // Gir tilbake et kvadratisk bilde (512 x 512) eller null hvis brukeren avbryter.
  // Beskjær et bilde. o.aspect er bredde/høyde (1 = kvadrat), o.round viser sirkel (profilbilde).
  H.cropImage = (file, o = {}) => new Promise((resolve) => {
    const A = o.aspect || 1, ROUND = o.round !== false && A === 1 && !o.aspect;
    const OUTW = o.outW || 512, OUTH = Math.round(OUTW / A);
    const TITLE = o.title || 'Juster profilbildet';
    const finish = (val) => { document.removeEventListener('keydown', onKey); wrap.classList.add('out'); setTimeout(() => wrap.remove(), 200); document.body.style.overflow = ''; if (lastFocus) lastFocus.focus(); resolve(val); };
    const lastFocus = document.activeElement;
    const wrap = document.createElement('div');
    wrap.className = 'crop-wrap'; wrap.setAttribute('role', 'dialog'); wrap.setAttribute('aria-modal', 'true'); wrap.setAttribute('aria-label', TITLE);
    wrap.innerHTML = `<div class="crop-box"${A > 1 ? ' style="width:min(680px,100%)"' : ''}>
        <div class="row" style="justify-content:space-between"><b style="font-size:17px">${H.esc(TITLE)}</b><button type="button" class="ibtn" data-c="cancel" aria-label="Avbryt">${H.icon('close', 18, 2)}</button></div>
        <p class="hint">${H.esc(o.hint || 'Dra bildet for å flytte det. Zoom slik at ansiktet ditt fyller sirkelen.')}</p>
        <div class="crop-view${ROUND ? ' round' : ''}" style="aspect-ratio:${A}" tabindex="0" aria-label="Bildeutsnitt. Bruk piltastene for å flytte og pluss eller minus for å zoome."><img alt="" draggable="false"></div>
        <div class="row" style="gap:12px;flex-wrap:nowrap"><span aria-hidden="true">${H.icon('search', 16)}</span><label class="sr" for="cropZoom">Zoom</label><input type="range" id="cropZoom" min="1" max="4" step="0.01" value="1" class="crop-range"><button type="button" class="ibtn" data-c="rotate" aria-label="Roter 90 grader" title="Roter">${H.icon('rotate', 18)}</button></div>
        <div class="row" style="justify-content:flex-end"><button type="button" class="btn soft" data-c="cancel">Avbryt</button><button type="button" class="btn primary" data-c="save">Bruk bildet</button></div>
      </div>`;
    document.body.appendChild(wrap); document.body.style.overflow = 'hidden';
    const view = wrap.querySelector('.crop-view'), img = view.querySelector('img'), zoomEl = wrap.querySelector('#cropZoom');
    let src = null, iw = 0, ih = 0, V = 0, VH = 0, base = 1, zoom = 1, x = 0, y = 0;
    const clamp = () => {
      const s = base * zoom, mx = Math.max(0, (iw * s - V) / 2), my = Math.max(0, (ih * s - VH) / 2);
      x = Math.min(mx, Math.max(-mx, x)); y = Math.min(my, Math.max(-my, y));
    };
    const draw = () => {
      clamp(); const s = base * zoom;
      img.style.width = iw + 'px'; img.style.height = ih + 'px';
      img.style.transform = `translate(${x - (iw * s) / 2}px, ${y - (ih * s) / 2}px) scale(${s})`;
      zoomEl.value = zoom;
    };
    const setSource = (canvasOrImg) => {
      src = canvasOrImg; iw = src.width || src.naturalWidth; ih = src.height || src.naturalHeight;
      V = view.clientWidth; VH = view.clientHeight; base = Math.max(V / iw, VH / ih); zoom = 1; x = 0; y = 0;
      img.src = src.toDataURL ? src.toDataURL('image/jpeg', 0.92) : src.src;
      draw();
    };
    const load = new Image();
    let rot = 0;
    const rotate = () => {
      const cv = document.createElement('canvas'); cv.width = ih; cv.height = iw;
      const g = cv.getContext('2d'); g.translate(ih, 0); g.rotate(Math.PI / 2); g.drawImage(src, 0, 0); setSource(cv); rot = (rot + 1) % 4;
    };
    // o.state gjenoppretter et tidligere utsnitt, så du kan justere bildet uten å laste det opp på nytt
    load.onload = () => {
      setSource(load);
      const st = o.state;
      if (st) { for (let i = 0; i < (st.rot || 0); i++) rotate(); zoom = Math.min(4, Math.max(1, st.zoom || 1)); x = (st.rx || 0) * V; y = (st.ry || 0) * VH; draw(); }
    };
    load.onerror = () => { H.toast('Kunne ikke lese bildet. Prøv JPG eller PNG.'); finish(null); };
    load.src = URL.createObjectURL(file);
    const setZoom = (z, cx = 0, cy = 0) => {
      const nz = Math.min(4, Math.max(1, z)), k = nz / zoom;
      x = cx + (x - cx) * k; y = cy + (y - cy) * k; zoom = nz; draw();
    };
    // Dra og klyp
    const pts = new Map(); let pinch = 0;
    view.addEventListener('pointerdown', (e) => { view.setPointerCapture(e.pointerId); pts.set(e.pointerId, [e.clientX, e.clientY]); if (pts.size === 2) { const [a, b] = [...pts.values()]; pinch = Math.hypot(a[0] - b[0], a[1] - b[1]); } });
    view.addEventListener('pointermove', (e) => {
      if (!pts.has(e.pointerId)) return;
      const prev = pts.get(e.pointerId); pts.set(e.pointerId, [e.clientX, e.clientY]);
      if (pts.size === 2) { const [a, b] = [...pts.values()]; const d = Math.hypot(a[0] - b[0], a[1] - b[1]); if (pinch) setZoom(zoom * (d / pinch)); pinch = d; return; }
      x += e.clientX - prev[0]; y += e.clientY - prev[1]; draw();
    });
    const up = (e) => { pts.delete(e.pointerId); if (pts.size < 2) pinch = 0; };
    view.addEventListener('pointerup', up); view.addEventListener('pointercancel', up);
    view.addEventListener('wheel', (e) => { e.preventDefault(); const r = view.getBoundingClientRect(); setZoom(zoom * Math.exp(-e.deltaY * 0.0015), e.clientX - r.left - V / 2, e.clientY - r.top - VH / 2); }, { passive: false });
    view.addEventListener('keydown', (e) => {
      const m = { ArrowLeft: [-10, 0], ArrowRight: [10, 0], ArrowUp: [0, -10], ArrowDown: [0, 10] }[e.key];
      if (m) { e.preventDefault(); x += m[0]; y += m[1]; draw(); }
      if (e.key === '+' || e.key === '=') setZoom(zoom + 0.1);
      if (e.key === '-') setZoom(zoom - 0.1);
    });
    zoomEl.addEventListener('input', () => setZoom(+zoomEl.value));
    const onKey = (e) => { if (e.key === 'Escape') finish(null); };
    document.addEventListener('keydown', onKey);
    wrap.addEventListener('click', (e) => {
      const c = e.target.closest('[data-c]'); if (!c) { if (e.target === wrap) finish(null); return; }
      if (c.dataset.c === 'cancel') finish(null);
      if (c.dataset.c === 'rotate' && src) rotate();
      if (c.dataset.c === 'save' && src) {
        const cv = document.createElement('canvas'); cv.width = OUTW; cv.height = OUTH;
        const g = cv.getContext('2d'), k = OUTW / V, s = base * zoom * k;
        g.fillStyle = '#fff'; g.fillRect(0, 0, OUTW, OUTH);
        g.translate(OUTW / 2 + x * k, OUTH / 2 + y * k); g.scale(s, s); g.drawImage(src, -iw / 2, -ih / 2);
        const state = { zoom, rx: x / V, ry: y / VH, rot };
        const done = (b) => { if (b) b.cropState = state; finish(b); };
        cv.toBlob((b) => (b && b.type === 'image/webp' ? done(b) : cv.toBlob(done, 'image/jpeg', 0.88)), 'image/webp', 0.88);
      }
    });
    setTimeout(() => view.focus(), 50);
  });
  H.photoNote = 'Profilbildet skal være et tydelig bilde av deg selv, der ansiktet ditt synes. Ikke bruk logo, tegning, kjæledyr eller bilder av arbeid du har gjort. Da vet kundene hvem de møter.';
  H.photoPicker = (who) => `<div class="photo-pick">
      ${H.avatar(who, 88)}
      <div class="stack grow" style="gap:8px">
        <b style="font-size:15px">Profilbilde</b>
        <p class="hint">${H.photoNote}</p>
        <label class="check"><input type="checkbox" id="photoOk"> <span>Bildet er av meg</span></label>
        <div class="row"><label class="btn soft sm" for="photoFile" id="photoBtn">${who.photo ? 'Bytt bilde' : 'Last opp bilde'}</label><input type="file" id="photoFile" accept="image/jpeg,image/png,image/webp" class="sr">${who.photo && who.photoSrc ? '<button type="button" class="btn soft sm" data-a="photoEdit">Juster bildet</button>' : ''}${who.photo ? '<button type="button" class="btn link small" data-a="photoRemove">Fjern bildet</button>' : ''}</div>
        <span class="err-text" id="photoErr" role="alert"></span>
      </div>
    </div>`;
  // Lagrer et nytt utsnitt av profilbildet. src er originalen (ny ved opplasting, samme ved justering).
  H.setPhoto = async (blob, src) => {
    const url = await H.storeImage('avatar', blob);
    const old = S.user && S.user.photo, oldSrc = S.user && S.user.photoSrc;
    if (S.user) Object.assign(S.user, { photo: url, photoSrc: src, photoCrop: blob.cropState || null });
    if (S.profile) S.profile.photo = url;
    H.save(); H.dropImage(old); if (oldSrc && oldSrc !== src) H.dropImage(oldSrc); H.mountHeader();
    if (H.savePhotoMeta) H.savePhotoMeta(src, blob.cropState || null);
  };
  H.photoEditDone = null;
  H.bindPhotoPicker = (done) => {
    H.photoEditDone = done;
    const inp = document.getElementById('photoFile'); if (!inp) return;
    const err = (t) => { document.getElementById('photoErr').textContent = t; };
    inp.addEventListener('click', (e) => { if (!document.getElementById('photoOk').checked) { e.preventDefault(); err('Kryss av for at bildet er av deg før du laster opp.'); } });
    inp.addEventListener('change', async () => {
      const file = inp.files[0]; inp.value = ''; if (!file) return;
      if (!document.getElementById('photoOk').checked) { err('Kryss av for at bildet er av deg før du laster opp.'); return; }
      const btn = document.getElementById('photoBtn');
      try {
        if (!/^image\//.test(file.type)) throw new Error('Velg en bildefil (JPG, PNG eller WebP).');
        btn.textContent = 'Juster bildet …';
        const blob = await H.cropImage(file);
        if (!blob) { btn.textContent = S.user && S.user.photo ? 'Bytt bilde' : 'Last opp bilde'; return; }
        btn.textContent = 'Laster opp …';
        // Originalen lagres også, så bildet kan justeres senere uten ny opplasting
        const orig = await H.resizeImage(file, 1600);
        await H.setPhoto(blob, await H.storeImage('avatar-src', orig.blob));
        H.toast('Profilbildet er oppdatert'); done && done();
      } catch (e) { err(e.message || 'Kunne ikke laste opp bildet.'); btn.textContent = 'Last opp bilde'; }
    });
  };
  H.verified = (f) => (f.verified ? `<span style="color:var(--muted);display:inline-flex" role="img" aria-label="BankID-verifisert">${H.icon('shield', 14, 2)}</span>` : '');

  // Bla gjennom porteføljen rett fra kortet. Med et fagfelt valgt vises bare bilder fra det fagfeltet.
  // Ellers kortbildet (eller bakgrunnsbildet) først, så hele porteføljen.
  H.carousel = (f, cat) => {
    const pfl = f.portfolio || [];
    const inCat = cat && cat !== 'alle' ? pfl.filter((x) => (x.cat || f.cat) === cat) : [];
    const lead = f.cardImg || f.coverImg;
    const imgs = (inCat.length ? inCat : [].concat(lead ? [lead] : [], pfl)).slice(0, 8);
    if (!imgs.length || (imgs.length < 2 && !inCat.length)) return '';
    return `<div class="fc-car">
      <a class="fc-track" href="frilanser.html?id=${f.id}${inCat.length ? '&kat=' + cat : ''}" aria-label="${H.esc(f.name)}, ${H.esc(f.role)}. ${imgs.length} bilder">${imgs.map((x) => `<span class="fc-slide"><img src="${H.esc(x.thumb || x.url)}" alt="" loading="lazy" draggable="false">${x.type === 'video' ? `<span class="play-badge">${H.icon('play', 16, 2, 'currentColor')}</span>` : ''}</span>`).join('')}</a>
      ${imgs.length > 1 ? `<button class="fc-nav prev" data-a="car" data-v="-1" aria-label="Forrige bilde" hidden>${H.icon('back', 16, 2.2)}</button>
      <button class="fc-nav next" data-a="car" data-v="1" aria-label="Neste bilde">${H.icon('back', 16, 2.2)}</button>
      <span class="fc-dots" aria-hidden="true">${imgs.map((_, i) => `<i${i ? '' : ' class="on"'}></i>`).join('')}</span>` : ''}</div>`;
  };
  H.fCard = (f, opts = {}) => {
    const saved = S.saved.includes(f.id);
    const inCmp = S.cmp.includes(f.id);
    return `<article class="fcard">
      ${H.carousel(f, opts.cat) || H.ph(f, 'card', '', 'a', `href="frilanser.html?id=${f.id}" aria-label="${H.esc(f.name)}, ${H.esc(f.role)}"`)}
      <button class="ibtn heart" data-a="save" data-v="${f.id}" aria-pressed="${saved}" aria-label="${saved ? 'Fjern fra lagrede' : 'Lagre'} ${H.esc(f.name)}" style="color:${saved ? 'var(--like)' : 'var(--fg)'}">${H.icon('heart', 18, 1.8, saved ? 'currentColor' : 'none')}</button>
      ${opts.cmp ? `<button class="cmp" data-a="cmp" data-v="${f.id}" aria-pressed="${inCmp}">${H.icon(inCmp ? 'check' : 'plus', 13, 2.4)} Sammenlign</button>` : ''}
      <div class="row" style="justify-content:space-between;flex-wrap:nowrap;gap:8px"><a href="frilanser.html?id=${f.id}" class="t">${H.esc(f.name)} ${H.verified(f)}</a><span class="rate">${H.star(12)} ${H.ratingTxt(f)}</span></div>
      <span class="meta">${H.esc(f.role)} · ${H.esc(f.area)}</span>
      <span class="price">${H.priceTxt(f)}</span>
    </article>`;
  };

  /* ---------- lagret i mapper ---------- */
  // En mappe: { id, name, items: [{ t, id, at }], at, owner }. t er 'f' (frilanser), 'p' (innlegg) eller 'j' (oppdrag).
  // owner er bruker-id-en mappen er lagret på. Mapper laget uten innlogging har ingen owner.
  H.folders = () => (S.folders = S.folders || []);
  H.inFolders = (t, id) => H.folders().filter((m) => m.items.some((x) => x.t === t && x.id === id));
  H.isSavedItem = (t, id) => (t === 'f' && S.saved.includes(id)) || H.inFolders(t, id).length > 0;
  H.makeFolder = (name) => {
    const m = { id: H.uid(), name: String(name).trim().slice(0, 60) || 'Ny mappe', items: [], at: Date.now(), owner: (window.Cloud && Cloud.uid) || null };
    H.folders().push(m); H.save(); return m;
  };
  H.toggleInFolder = (mid, t, id) => {
    const m = H.folders().find((x) => x.id === mid); if (!m) return;
    const i = m.items.findIndex((x) => x.t === t && x.id === id);
    if (i > -1) m.items.splice(i, 1);
    else { m.items.unshift({ t, id, at: Date.now() }); if (t === 'f' && !S.saved.includes(id)) S.saved.push(id); }
    H.save();
  };
  H.folderItem = (x) => (x.t === 'f' ? H.byId(x.id) : x.t === 'j' ? H.jobById(x.id) : (S.posts || []).find((p) => p.id === x.id));
  // Velg mapper for en frilanser, et innlegg eller et oppdrag
  H.pickFolder = (t, id) => {
    const last = document.activeElement;
    const wrap = document.createElement('div');
    wrap.className = 'crop-wrap'; wrap.setAttribute('role', 'dialog'); wrap.setAttribute('aria-modal', 'true'); wrap.setAttribute('aria-label', 'Lagre i mappe');
    const what = { f: 'frilanseren', p: 'innlegget', j: 'oppdraget' }[t] || 'dette';
    const draw = () => {
      const list = H.folders();
      wrap.innerHTML = `<div class="crop-box folder-box">
        <div class="row" style="justify-content:space-between"><b style="font-size:17px">Lagre i mappe</b><button type="button" class="ibtn" data-f="close" aria-label="Lukk">${H.icon('close', 18, 2)}</button></div>
        <p class="hint">Velg hvilke mapper ${what} skal ligge i.</p>
        <div class="stack" style="gap:6px">${list.length ? list.map((m) => { const on = m.items.some((x) => x.t === t && x.id === id); return `<button type="button" class="folder-opt" data-f="toggle" data-id="${m.id}" aria-pressed="${on}"><span class="folder-check">${on ? H.icon('check', 14, 3) : ''}</span><span class="grow">${H.esc(m.name)}</span><span class="meta">${m.items.length}</span></button>`; }).join('') : '<p class="muted small">Du har ingen mapper ennå. Lag den første under.</p>'}</div>
        <form class="row" data-f="new" style="flex-wrap:nowrap"><label class="sr" for="newFolder">Navn på ny mappe</label><input class="inp" id="newFolder" maxlength="60" placeholder="Ny mappe, f.eks. Bryllup" autocomplete="off"><button class="btn soft" type="submit">Lag mappe</button></form>
        <div class="row" style="justify-content:space-between"><a class="small" href="lagret.html">Se alt du har lagret</a><button type="button" class="btn primary" data-f="close">Ferdig</button></div>
      </div>`;
    };
    const close = () => { document.removeEventListener('keydown', key); wrap.remove(); document.body.style.overflow = ''; if (last && last.focus) last.focus(); H.rerender(); };
    const key = (e) => { if (e.key === 'Escape') close(); };
    wrap.addEventListener('click', (e) => {
      const c = e.target.closest('[data-f]');
      if (!c) { if (e.target === wrap) close(); return; }
      if (c.dataset.f === 'close') close();
      if (c.dataset.f === 'toggle') { const mid = c.dataset.id; H.toggleInFolder(mid, t, id); draw(); const b = wrap.querySelector(`[data-id="${mid}"]`); if (b) b.focus(); }
    });
    wrap.addEventListener('submit', (e) => {
      e.preventDefault();
      const inp = wrap.querySelector('#newFolder'); const name = inp.value.trim();
      if (!name) { inp.focus(); return; }
      const m = H.makeFolder(name); H.toggleInFolder(m.id, t, id); draw();
      wrap.querySelector('#newFolder').focus();
    });
    draw();
    document.addEventListener('keydown', key); document.body.appendChild(wrap); document.body.style.overflow = 'hidden';
    setTimeout(() => { const b = wrap.querySelector('.folder-opt') || wrap.querySelector('#newFolder'); if (b) b.focus(); }, 50);
  };

  /* ---------- sted på kart ---------- */
  // Finner omtrentlig posisjon for et stedsnavn i Norge med OpenStreetMap (Nominatim). Svaret huskes i nettleseren.
  H.geocode = async (place) => {
    const q = String(place || '').trim(); if (!q) return null;
    const k = 'freelio:geo:' + q.toLowerCase();
    try { const c = localStorage.getItem(k); if (c) return JSON.parse(c); } catch (e) {}
    const r = await fetch('https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&countrycodes=no&accept-language=nb&q=' + encodeURIComponent(q));
    if (!r.ok) throw new Error('Fant ikke stedet');
    const j = await r.json();
    const hit = j && j[0] ? [Math.round(+j[0].lat * 1e4) / 1e4, Math.round(+j[0].lon * 1e4) / 1e4] : null;
    try { localStorage.setItem(k, JSON.stringify(hit)); } catch (e) {}
    return hit;
  };

  /* ---------- oppdrag (annonser) ---------- */
  H.allJobs = () => S.myJobs.map((j) => Object.assign({ mine: true, km: 0, by: 'Deg', posted: j.postedTxt || 'nå' }, j)).reverse().concat(D.JOBS);
  H.jobById = (id) => H.allJobs().find((j) => j.id === id);
  H.jobOffers = (j) => (j.offersList || []).filter((o) => o.at <= Date.now());
  H.jobRow = (j) => {
    const c = H.cat(j.cat);
    const n = j.mine ? H.jobOffers(j).length : j.offers + (S.sentOffers[j.id] ? 1 : 0);
    const tags = (j.mine ? '<span class="pill acc">Din annonse</span>' : '') + (S.sentOffers[j.id] ? '<span class="pill ok">Tilbud sendt</span>' : '') + (j.status === 'booked' ? '<span class="pill ok">Booket</span>' : '');
    return `<a class="jrow" href="annonse.html?id=${j.id}"><span class="ico">${H.icon(c.icon, 22, 1.6)}</span>
      <div class="grow stack" style="gap:2px"><b style="font-size:15px;font-weight:700">${H.esc(j.title)}</b><span class="meta">${c.name} · ${H.esc(j.area)} · ${H.esc(j.date)} · ${n} tilbud</span>${tags ? `<span class="row" style="gap:6px;margin-top:4px">${tags}</span>` : ''}</div>
      <span class="budget">${H.kr(j.budget)}</span></a>`;
  };

  /* ---------- bestillinger ---------- */
  H.createOrder = (o) => {
    const order = Object.assign({ id: H.uid(), role: 'customer', status: 'paid', reviewed: false, delivered: '', created: Date.now() }, o);
    S.orders.push(order); H.save();
    return order;
  };
  H.orderById = (id) => S.orders.find((o) => o.id === id);
  H.actionCount = () => S.orders.filter((o) => (o.role === 'freelancer' ? ['paid', 'dispute'].includes(o.status) : o.status === 'delivered' || (o.status === 'approved' && !o.reviewed))).length
    + S.myJobs.filter((j) => j.status === 'open' && H.jobOffers(j).some((o) => !o.seen)).length;

  /* ---------- meldinger ---------- */
  H.unread = () => Object.keys(S.threads).filter((fid) => { const t = S.threads[fid]; return H.partner(fid) && t.length && t[t.length - 1].who === 'them' && (S.readThreads[fid] || 0) < t.length; }).length;
  H.sendMessage = (fid, text, onChange) => {
    text = String(text).trim(); if (!text) return;
    const f = H.partner(fid); if (!f) return;
    (S.threads[fid] = S.threads[fid] || []).push({ who: 'me', text, at: Date.now() });
    // Bare demo-frilansere svarer automatisk. Ekte personer svarer selv.
    const auto = !f.customer && f.demo !== false;
    const t = text.toLowerCase(); let reply;
    if (/\d{3}\s?\d{2}\s?\d{3}|@|kontonummer|vipps meg/.test(t)) {
      S.threads[fid].push({ who: 'sys', text: 'Det ser ut som du deler kontaktinfo eller vil betale utenfor Freelio. Da er ikke betalingen beskyttet, og du mister retten til refusjon.', at: Date.now() });
      reply = 'Vi tar gjerne alt her i appen, så er vi begge trygge.';
    } else if (/pris|koster|kost|tilbud/.test(t)) reply = f.pk.map((p) => p[0] + ': ' + H.kr(p[1])).join('\n') + '\n\nDu kan booke en pakke direkte fra profilen min.';
    else if (/ledig|dato|når/.test(t)) reply = f.free ? 'Jeg har ledige datoer i november og desember. Hvilken dato tenker du på?' : 'Jeg er ganske booket fremover, men har ledig fra midten av desember.';
    else reply = `Takk for meldingen! Fortell gjerne litt mer om oppdraget, så kommer jeg med et forslag.`;
    if (!auto) { H.save(); onChange && onChange('sent'); return; }
    H.save(); onChange && onChange('typing');
    setTimeout(() => { S.threads[fid].push({ who: 'them', text: reply, at: Date.now() }); H.save(); onChange && onChange('reply'); H.mountHeader(); }, 1300);
  };

  /* ---------- assistent ---------- */
  H.ANSWERS = {
    'Hva bør jeg se etter i en fotograf?': { text: 'Se etter dette:\n\n1. Hele serier, ikke bare de beste bildene. Be om et fullt galleri fra en lignende jobb.\n2. Bilder i samme lys som ditt oppdrag. Vinterstid betyr lite dagslys.\n3. Lik stil i redigeringen gjennom hele serien.\n4. Hvor mye du får levert, og når.\n5. Hvem som eier rettighetene til bildene.\n\nI Sammenlign ser du leveringstid, svartid og pris side om side.', act: ['sammenlign.html', 'Åpne sammenligning'] },
    'Hva er en vanlig pris?': { text: 'Blant frilanserne på Freelio i Bærum og Asker:\n\nBryllupsfotograf, halv dag: 8 000 til 9 500 kr\nBryllupsfilm, halv dag: rundt 18 000 kr\nPortrett i studio: rundt 2 500 kr\nBoligbilder: 2 900 til 4 200 kr\nKort reklamefilm: rundt 12 000 kr\n\nSett maks budsjett litt over det du helst vil betale. Da får du flere tilbud å velge mellom.' },
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
    if (/fotograf|foto|bilde/.test(t)) return H.ANSWERS['Hva bør jeg se etter i en fotograf?'];
    if (/drone|luft/.test(t)) return { text: 'For dronefoto: spør om piloten har sertifikat (A1/A3 eller A2), om de har forsikring, og om området tillater flyging. Sjekk også at været er tatt med i avtalen.', act: ['sok.html?kat=drone', 'Se dronepiloter'] };
    if (/bolig|eiendom|leilighet|hytte/.test(t)) return { text: 'For boligbilder: spør om leveringstid (48 timer er vanlig), antall bilder, og om dronebilder og kveldsbilder er med.', act: ['sok.html?kat=eiendom', 'Se eiendomsfotografer'] };
    if (/film|video|reklame|reels|tiktok/.test(t)) return { text: 'For video: spør om lengde, format (16:9 eller 9:16), hvem som velger musikk, hvor mange runder med endringer du får, og om du får råfilene.', act: ['sok.html?kat=reklamefilm', 'Se videografer'] };
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
  // act = { label, a, v } gir en knapp i meldingen som kjører H.actions[a](v)
  H.toast = (msg, act) => {
    let el = document.getElementById('toast');
    if (el) el.remove();
    el = document.createElement('div'); el.id = 'toast'; el.className = 'toast'; el.setAttribute('role', 'status'); document.body.appendChild(el);
    el.textContent = msg;
    if (act) { const b = document.createElement('button'); b.type = 'button'; b.className = 'toast-btn'; b.dataset.a = act.a; b.dataset.v = act.v; b.textContent = act.label; el.append(' ', b); b.addEventListener('click', () => el.remove()); }
    clearTimeout(tt); tt = setTimeout(() => el.remove(), act ? 6000 : 3600);
  };
  H.flash = (msg) => { try { sessionStorage.setItem('freelio:flash', msg); } catch (e) {} };

  /* ---------- tema ---------- */
  H.isDark = () => { const t = document.documentElement.dataset.theme; return t ? t === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches; };
  H.setTheme = (t) => {
    const r = document.documentElement;
    r.classList.add('theme-anim'); r.dataset.theme = t;
    try { localStorage.setItem('freelio:theme', t); } catch (e) {}
    setTimeout(() => r.classList.remove('theme-anim'), 450);
    H.mountHeader();
  };

  /* ---------- logo ---------- */
  H.logo = (word = true) => {
    const L = window.FREELIO_LOGO;
    if (!L) return '<b>freelio</b>';
    return `<svg class="mk" viewBox="${L.mark.vb}" aria-hidden="true"><path fill-rule="evenodd" d="${L.mark.d}"/></svg>${word ? `<svg class="wm" viewBox="${L.word.vb}" aria-hidden="true"><path fill-rule="evenodd" d="${L.word.d}"/></svg>` : ''}`;
  };

  /* ---------- skeleton ---------- */
  H.skel = (spec) => {
    const [kind, nStr] = String(spec).split(':'); const n = +nStr || 4;
    const rep = (h) => Array.from({ length: n }, () => h).join('');
    if (kind === 'cards') return `<div class="cards" style="grid-column:1/-1">${rep('<div><div class="sk sk-img"></div><div class="sk sk-line w60"></div><div class="sk sk-line w40"></div></div>')}</div>`;
    if (kind === 'list') return rep('<div class="sk-row"><div class="sk sk-av" style="border-radius:12px"></div><div class="grow"><div class="sk sk-line w60" style="margin:0"></div><div class="sk sk-line w40"></div></div><div class="sk sk-line w30" style="width:70px;margin:0"></div></div>');
    if (kind === 'feed') return rep('<div class="stack"><div class="row"><div class="sk sk-av"></div><div class="grow"><div class="sk sk-line w40" style="margin:0"></div><div class="sk sk-line w30"></div></div></div><div class="sk" style="aspect-ratio:4/5;border-radius:18px"></div></div>');
    if (kind === 'profile') return `<div class="wrap" style="padding-top:20px"><div class="sk cover"></div><div class="row" style="margin-top:-40px;padding-inline:20px;align-items:flex-end"><div class="sk" style="width:104px;height:104px;border-radius:50%;box-shadow:0 0 0 5px var(--bg)"></div><div class="grow"><div class="sk sk-line lg w40"></div><div class="sk sk-line w30"></div></div></div><div class="prof-grid"><div><div class="sk sk-line w100"></div><div class="sk sk-line w80"></div><div class="gallery" style="margin-top:24px">${'<div class="sk" style="aspect-ratio:1/1;border-radius:10px"></div>'.repeat(6)}</div></div><div class="sk" style="height:220px;border-radius:14px"></div></div></div>`;
    return `<div class="wrap" style="max-width:1000px;padding-block:36px"><div class="sk sk-line w30"></div><div class="sk sk-line lg w60" style="height:34px;margin-top:20px"></div><div class="two" style="padding:24px 0"><div><div class="sk sk-line w100"></div><div class="sk sk-line w80"></div><div class="sk sk-line w60"></div><div class="sk" style="height:180px;border-radius:14px;margin-top:24px"></div></div><div class="sk" style="height:240px;border-radius:14px"></div></div></div>`;
  };

  /* ---------- toppmeny og bunntekst ---------- */
  const page = document.body.dataset.page || '';
  H.mountHeader = () => {
    const el = document.getElementById('site-header'); if (!el) return;
    const nav = [['index.html', 'Hjem'], ['utforsk.html', 'Utforsk'], ['sok.html', 'Finn frilanser'], ['oppdrag.html', 'Oppdrag']];
    const cur = (href) => (href.replace('.html', '') === page ? 'aria-current="page"' : '');
    const unread = H.unread(); const act = H.actionCount();
    const wasOpen = el.querySelector('.top.open');
    const dark = H.isDark();
    el.innerHTML = `<header class="top${wasOpen ? ' open' : ''}"><div class="wrap">
      <div class="top-in">
        <a class="logo" href="index.html" aria-label="Freelio, til forsiden">${H.logo()}</a>
        <nav class="mainnav" aria-label="Hovedmeny">${nav.map(([h, t]) => `<a href="${h}" ${cur(h)}>${t}</a>`).join('')}</nav>
        <div class="usernav">
          <button class="ibtn lbl theme-btn" data-a="theme" aria-label="${dark ? 'Bytt til lys modus' : 'Bytt til mørk modus'}" title="${dark ? 'Lys modus' : 'Mørk modus'}">${H.icon(dark ? 'sun' : 'moon', 19)}<span class="lbl-t">${dark ? 'Lys' : 'Mørk'}</span></button>
          <a class="ibtn lbl hide-md" href="assistent.html" aria-label="Assistent" title="Assistent">${H.icon('spark', 19)}<span class="lbl-t">Assistent</span></a>
          <a class="ibtn lbl hide-sm" href="meldinger.html" aria-label="Meldinger${unread ? ', ' + unread + ' uleste' : ''}" title="Meldinger">${H.icon('chat', 19)}<span class="lbl-t">Meldinger</span>${unread ? '<span class="dot"></span>' : ''}</a>
          <a class="ibtn lbl hide-sm" href="mine-oppdrag.html" aria-label="Mine oppdrag${act ? ', ' + act + ' venter på deg' : ''}" title="Mine oppdrag">${H.icon('clipboard', 19)}<span class="lbl-t">Mine oppdrag</span>${act ? '<span class="dot"></span>' : ''}</a>
          <a class="ibtn lbl" href="${S.user ? 'min-side.html' : 'logg-inn.html'}" aria-label="${S.user ? 'Min side' : 'Logg inn'}" title="${S.user ? 'Min side' : 'Logg inn'}">${H.icon('user', 19)}<span class="lbl-t">${S.user ? 'Min side' : 'Logg inn'}</span></a>
          <a class="btn primary sm hide-sm" href="ny-annonse.html" style="margin-left:8px">Legg ut oppdrag</a>
        </div>
        <button class="ibtn menu-btn" data-a="menu" aria-expanded="${!!wasOpen}" aria-label="Meny">${H.icon(wasOpen ? 'close' : 'menu', 20)}</button>
      </div>
      <nav class="drawer" aria-label="Meny for mobil"><div>
        <a href="ny-annonse.html">Legg ut oppdrag</a>${nav.map(([h, t]) => `<a href="${h}">${t}</a>`).join('')}<a href="kart.html">Kart</a>
        <a href="assistent.html">Assistent</a><a href="meldinger.html">Meldinger${unread ? ` (${unread})` : ''}</a><a href="mine-oppdrag.html">Mine oppdrag${act ? ` (${act})` : ''}</a><a href="lagret.html">Lagret</a>
        <a href="${S.user ? 'min-side.html' : 'logg-inn.html'}">${S.user ? 'Min side' : 'Logg inn'}</a>
      </div></nav>
    </div></header>`;
    H.mountTabbar(unread, act);
  };
  /* bunnmeny på mobil, bare i det nye designet (se js/design.js) */
  H.mountTabbar = (unread = H.unread(), act = H.actionCount()) => {
    let el = document.getElementById('tabbar');
    if (document.documentElement.dataset.design === 'gammel') { if (el) el.remove(); return; }
    if (!el) { el = document.createElement('nav'); el.id = 'tabbar'; el.className = 'tabbar'; el.setAttribute('aria-label', 'Hurtigmeny'); document.body.appendChild(el); }
    const items = [['index.html', 'home', 'Hjem'], ['sok.html', 'search', 'Finn'], ['ny-annonse.html', 'plus', 'Legg ut'], ['mine-oppdrag.html', 'clipboard', 'Mine oppdrag', act, 'venter på deg'], ['meldinger.html', 'chat', 'Meldinger', unread, 'uleste']];
    el.innerHTML = items.map(([h, ic, t, n, why]) => `<a href="${h}" ${h.replace('.html', '') === page ? 'aria-current="page"' : ''}${n ? ` aria-label="${t}, ${n} ${why}"` : ''}>${H.icon(ic, 22)}${n ? '<span class="dot"></span>' : ''}<span>${t}</span></a>`).join('');
  };
  H.mountFooter = () => {
    const el = document.getElementById('site-footer'); if (!el) return;
    const links = [['sok.html', 'Finn frilanser'], ['oppdrag.html', 'Oppdrag'], ['kart.html', 'Kart'], ['bli-frilanser.html', 'Bli frilanser'], ['slik-fungerer-det.html', 'Slik fungerer det'], ['slik-fungerer-det.html#priser', 'Priser'], ['hjelp.html', 'Hjelp'], ['om.html', 'Om oss'], ['vilkar.html', 'Vilkår'], ['personvern.html', 'Personvern'], ['cookies.html', 'Cookies']];
    el.innerHTML = `<footer class="foot"><div class="wrap">
      <div class="foot-in">
        <div class="stack" style="gap:14px;max-width:300px"><a class="logo" href="index.html" aria-label="Freelio">${H.logo()}</a><p class="small muted">Finn, sammenlign og lei lokale frilansere. Pengene utbetales først når jobben er levert.</p></div>
        <nav aria-label="Bunnmeny">${links.map(([h, t]) => `<a href="${h}">${t}</a>`).join('')}<a href="#" data-a="cookieSettings">Cookie-valg</a></nav>
      </div>
      <div class="foot-bottom"><span>© 2026 Freelio</span><span>Betaling er ikke koblet på ennå. Ingen penger trekkes.</span></div>
    </div></footer>`;
  };
  H.mountCookie = (force) => {
    if (S.cookie && !force) return;
    let el = document.getElementById('cookie');
    if (!el) { el = document.createElement('div'); el.id = 'cookie'; el.className = 'cookie'; el.setAttribute('role', 'dialog'); el.setAttribute('aria-label', 'Cookies'); document.body.appendChild(el); }
    el.innerHTML = `<b style="font-size:15px">Cookies</b><p class="small muted">Vi bruker nødvendige cookies for innlogging og betaling. Statistikk og markedsføring bare hvis du sier ja. <a href="cookies.html">Les mer</a></p>
      <div class="row"><button class="btn soft sm" data-a="cookie" data-v="no">Kun nødvendige</button><button class="btn primary sm" data-a="cookie" data-v="yes">Godta alle</button></div>`;
  };

  /* ---------- felles handlinger ---------- */
  const popIn = (sel) => requestAnimationFrame(() => { const n = document.querySelector(sel); if (n) n.classList.add('pop'); });
  H.actions = {
    menu: (v, el) => { const top = el.closest('.top'); const o = top.classList.toggle('open'); el.setAttribute('aria-expanded', o); el.innerHTML = H.icon(o ? 'close' : 'menu', 20); },
    theme: () => H.setTheme(H.isDark() ? 'light' : 'dark'),
    photoEdit: async () => {
      const src = S.user && S.user.photoSrc; if (!src) return;
      try {
        const file = await (await fetch(src)).blob();
        const blob = await H.cropImage(file, { state: S.user.photoCrop });
        if (!blob) return;
        await H.setPhoto(blob, src);
        H.toast('Profilbildet er oppdatert'); if (H.photoEditDone) H.photoEditDone();
      } catch (e) { H.toast(e.message || 'Kunne ikke åpne bildet'); }
    },
    photoRemove: () => { const old = S.user && S.user.photo; H.dropImage(S.user && S.user.photoSrc); if (S.user) { S.user.photoSrc = null; S.user.photoCrop = null; } if (H.savePhotoMeta) H.savePhotoMeta(null, null); if (S.user) S.user.photo = null; if (S.profile) S.profile.photo = null; H.save(); H.dropImage(old); H.mountHeader(); H.toast('Profilbildet er fjernet'); H.rerender(); },
    cookie: (v) => {
      S.cookie = v; S.cookies = { analyse: v === 'yes', ads: v === 'yes' }; H.save();
      const c = document.getElementById('cookie'); if (c) { c.classList.add('out'); setTimeout(() => c.remove(), 300); }
    },
    cookieSettings: () => H.mountCookie(true),
    save: (v) => {
      const i = S.saved.indexOf(v);
      if (i > -1) {
        S.saved.splice(i, 1);
        H.folders().forEach((m) => { m.items = m.items.filter((x) => !(x.t === 'f' && x.id === v)); });
        H.toast('Fjernet fra lagrede');
      } else { S.saved.push(v); H.toast('Lagret', { label: 'Legg i mappe', a: 'folder', v: 'f:' + v }); }
      H.save(); H.rerender(); popIn(`[data-a="save"][data-v="${v}"] svg`);
    },
    // v = 'f:<id>', 'p:<id>' eller 'j:<id>'
    folder: (v) => { const t = String(v).slice(0, 1), id = String(v).slice(2); if (t && id) H.pickFolder(t, id); },
    cmp: (v) => {
      const i = S.cmp.indexOf(v);
      if (i > -1) S.cmp.splice(i, 1);
      else if (S.cmp.length >= 3) { H.toast('Du kan sammenligne opptil 3 om gangen'); return; }
      else S.cmp.push(v);
      H.save(); H.rerender();
    }
  };
  H.popIn = popIn;
  H.render = null;
  H.rerender = () => { if (H.render) H.render(); };

  const closeMenu = () => { const t = document.querySelector('.top.open'); if (!t) return; t.classList.remove('open'); const b = t.querySelector('.menu-btn'); b.setAttribute('aria-expanded', 'false'); b.innerHTML = H.icon('menu', 20); };
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeMenu(); });
  H.actions.car = (v, el) => { const t = el.closest('.fc-car').querySelector('.fc-track'); t.scrollBy({ left: +v * t.clientWidth, behavior: 'smooth' }); };
  document.addEventListener('scroll', (e) => {
    const t = e.target; if (!t.classList || !t.classList.contains('fc-track')) return;
    const n = t.children.length, i = Math.round(t.scrollLeft / t.clientWidth), car = t.parentElement;
    car.querySelectorAll('.fc-dots i').forEach((d, k) => d.classList.toggle('on', k === i));
    car.querySelector('.prev').hidden = i <= 0; car.querySelector('.next').hidden = i >= n - 1;
  }, true);
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.top')) closeMenu();
    const el = e.target.closest('[data-a]');
    if (!el) return;
    const fn = H.actions[el.dataset.a];
    if (!fn) return;
    e.preventDefault();
    fn(el.dataset.v, el, e);
  });

  // Simulert lastetid, så skeleton vises slik den vil gjøre mot en ekte server
  H.LOAD_MS = 450;
  H.boot = (render) => {
    H.render = render || null;
    H.mountHeader(); H.mountFooter(); H.mountCookie();
    const sk = render ? [...document.querySelectorAll('[data-skel]')] : [];
    const go = () => {
      document.body.classList.add('reveal');
      sk.forEach((n) => n.removeAttribute('aria-busy'));
      if (render) render();
      setTimeout(() => document.body.classList.remove('reveal'), 1000);
      if (H.flashNow) { H.toast(H.flashNow); H.flashNow = null; }
      try { const f = sessionStorage.getItem('freelio:flash'); if (f) { sessionStorage.removeItem('freelio:flash'); H.toast(f); } } catch (e) {}
    };
    if (sk.length) { sk.forEach((n) => { n.setAttribute('aria-busy', 'true'); n.innerHTML = H.skel(n.dataset.skel); }); setTimeout(go, H.LOAD_MS); }
    else go();
  };
})();
