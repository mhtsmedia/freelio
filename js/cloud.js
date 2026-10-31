/* Kobling mellom nettsiden og Supabase.
   Sidene jobber mot det samme objektet (H.S) som i demo-modus. Denne filen:
   1. henter data fra databasen før sidens egen kode kjører (pull)
   2. sender endringer tilbake når siden kaller H.save() (push)
   Finnes ikke tabellene ennå, faller siden tilbake til demo-modus med data i nettleseren. */
(function () {
  const H = window.H, D = window.HDATA, cfg = window.FREELIO_CONFIG || {};
  const C = (window.Cloud = { on: false, ready: false, uid: null });
  const S = H.S;

  const runPageScripts = () => {
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', runPageScripts); return; }
    document.querySelectorAll('script[type="text/freelio"]').forEach((s) => {
      const n = document.createElement('script'); n.textContent = s.textContent; s.replaceWith(n);
    });
  };

  if (!cfg.supabaseUrl || !cfg.supabaseKey || !window.supabase) { H.prune(); runPageScripts(); return; }

  const sb = (C.sb = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseKey));
  C.on = true;
  H.LOAD_MS = 0;

  /* ---------- hjelpere ---------- */
  const ref = cfg.supabaseUrl.replace(/^https?:\/\//, '').split('.')[0];
  const storedSession = () => { try { return JSON.parse(localStorage.getItem(`sb-${ref}-auth-token`) || 'null'); } catch (e) { return null; } };
  const posted = (iso) => {
    const d = Math.floor((Date.now() - Date.parse(iso)) / 864e5);
    return d <= 0 ? 'i dag' : d === 1 ? 'i går' : `for ${d} dager siden`;
  };
  const dateTxt = (iso) => new Date(iso).toLocaleDateString('nb-NO', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const ini = (name) => String(name || '?').split(/\s+/).map((w) => w[0] || '').join('').slice(0, 2).toUpperCase();
  const must = (r) => { if (r.error) throw r.error; return r.data; };
  const clone = (x) => JSON.parse(JSON.stringify(x === undefined ? null : x));
  const pick = (o, keys) => { const r = {}; Object.keys(o).forEach((k) => { if (!keys.includes(k)) r[k] = o[k]; }); return r; };
  H.uid = () => (crypto.randomUUID ? crypto.randomUUID() : 'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'.replace(/x/g, () => ((Math.random() * 16) | 0).toString(16)));

  // Innlogget bruker fra lagret økt, så menyen er riktig før dataene er hentet
  const sess = storedSession();
  if (sess && sess.user) {
    const u = sess.user;
    S.user = { id: u.id, name: (u.user_metadata && u.user_metadata.name) || (u.email || '').split('@')[0], email: u.email, method: 'E-post', since: dateTxt(u.created_at || Date.now()) };
  } else S.user = null;

  /* ---------- mapping mellom databasen og sidene ---------- */
  const fromFreelancer = (r) => Object.assign({ rv: [], niches: [], tags: [], pk: [] }, r.data, { id: r.id, demo: r.demo, userId: r.user_id, published: r.published });
  const freelancerRow = (p) => ({ id: C.uid, user_id: C.uid, demo: false, published: !!p.published, data: pick(p, ['id', 'demo', 'userId', 'published', 'rv']) });

  const jobRow = (j) => ({ id: j.id, owner_id: C.uid, demo: false, status: j.status || 'open', data: pick(j, ['id', 'status', 'offersList', 'mine', 'by', 'posted', 'created']) });
  const orderRow = (o) => ({
    id: o.id, customer_id: o.role === 'freelancer' ? o.customerId : C.uid, freelancer_id: o.fid, job_id: o.jobId || null,
    status: o.status, title: o.title, price: Math.round(o.price), reviewed: !!o.reviewed,
    data: pick(o, ['id', 'fid', 'jobId', 'status', 'title', 'price', 'reviewed', 'role', 'customerId', 'customerName', 'created'])
  });

  /* ---------- hent alt (pull) ---------- */
  let snap = null;
  C.pull = async function () {
    const { data: { session } } = await sb.auth.getSession();
    C.uid = session ? session.user.id : null;

    const [fr, rv, jobs] = await Promise.all([
      sb.from('freelancers').select('id,user_id,demo,published,data').order('created_at'),
      sb.from('reviews').select('*').order('created_at', { ascending: false }),
      sb.from('jobs').select('id,owner_id,demo,status,data,created_at').order('created_at', { ascending: false })
    ]);
    const frRows = must(fr), rvRows = must(rv), jobRows = must(jobs);

    // Frilansere og omtaler
    S.extraReviews = {};
    rvRows.forEach((r) => (S.extraReviews[r.freelancer_id] = S.extraReviews[r.freelancer_id] || []).push([r.author_name, r.stars, r.job_label, r.text, r.author_id === C.uid, r.order_id]));
    const all = frRows.map(fromFreelancer).map((f) => {
      if (!f.demo) { const ex = S.extraReviews[f.id] || []; f.reviews = 0; f.rv = []; f.rating = 0; }
      return f;
    });
    D.FREELANCERS = all.filter((f) => f.published && f.id !== C.uid);
    S.profile = all.find((f) => f.userId && f.userId === C.uid) || null;

    // Oppdrag
    const myJobRows = jobRows.filter((r) => C.uid && r.owner_id === C.uid);
    D.JOBS = jobRows.filter((r) => !(C.uid && r.owner_id === C.uid)).map((r) => Object.assign({ offers: 0, km: 0 }, r.data, { id: r.id, status: r.status, posted: r.data.posted || posted(r.created_at), by: r.data.by || 'Kunde på Freelio' }));
    S.myJobs = myJobRows.reverse().map((r) => Object.assign({}, r.data, { id: r.id, status: r.status, created: Date.parse(r.created_at), postedTxt: dateTxt(r.created_at), offersList: [] }));

    S.orders = []; S.threads = {}; S.sentOffers = {}; S.saved = []; S.partners = {};
    if (C.uid) {
      const [prof, offers, orders, msgs, saved] = await Promise.all([
        sb.from('profiles').select('id,name,avatar_url,created_at').eq('id', C.uid).maybeSingle(),
        sb.from('offers').select('*'),
        sb.from('orders').select('*').order('created_at'),
        sb.from('messages').select('*').order('created_at'),
        sb.from('saved').select('freelancer_id')
      ]);
      const p = must(prof);
      S.user = Object.assign({}, S.user || {}, { id: C.uid, photo: (p && p.avatar_url) || null, name: (p && p.name) || (S.user && S.user.name) || 'Bruker', email: session.user.email, method: 'E-post', since: dateTxt((p && p.created_at) || session.user.created_at) });

      must(offers).forEach((o) => {
        const job = S.myJobs.find((j) => j.id === o.job_id);
        if (job) job.offersList.push({ fid: o.freelancer_id, price: o.price, msg: o.msg, at: Date.parse(o.visible_at), seen: o.seen });
        if (S.profile && o.freelancer_id === S.profile.id) S.sentOffers[o.job_id] = { price: o.price, msg: o.msg, at: Date.parse(o.created_at) };
      });

      const orderRows = must(orders), msgRows = must(msgs);
      const customerIds = [...new Set(orderRows.filter((o) => o.customer_id !== C.uid).map((o) => o.customer_id).concat(msgRows.filter((m) => m.customer_id !== C.uid).map((m) => m.customer_id)))];
      const names = {};
      const photos = {};
      if (customerIds.length) must(await sb.from('profiles').select('id,name,avatar_url').in('id', customerIds)).forEach((r) => { names[r.id] = r.name; photos[r.id] = r.avatar_url; });

      S.orders = orderRows.map((r) => Object.assign({}, r.data, {
        id: r.id, fid: r.freelancer_id, jobId: r.job_id, status: r.status, title: r.title, price: r.price, reviewed: r.reviewed, created: Date.parse(r.created_at),
        role: r.customer_id === C.uid ? 'customer' : 'freelancer', customerId: r.customer_id, customerName: names[r.customer_id] || 'Slettet bruker'
      }));

      msgRows.forEach((m) => {
        const mine = m.customer_id === C.uid;
        const key = mine ? m.freelancer_id : 'c:' + m.customer_id;
        if (!mine) S.partners[key] = { name: names[m.customer_id] || 'Slettet bruker', photo: photos[m.customer_id] || null, gone: !names[m.customer_id] };
        const who = m.sender === 'system' ? 'sys' : (mine ? (m.sender === 'customer' ? 'me' : 'them') : (m.sender === 'freelancer' ? 'me' : 'them'));
        (S.threads[key] = S.threads[key] || []).push({ who, text: m.text, at: Date.parse(m.created_at) });
      });
      orderRows.forEach((r) => { if (r.customer_id !== C.uid) S.partners['c:' + r.customer_id] = { name: names[r.customer_id] || 'Slettet bruker', photo: photos[r.customer_id] || null, gone: !names[r.customer_id] }; });

      S.saved = must(saved).map((r) => r.freelancer_id);
    }
    const exists = (id) => !!H.byId(id);
    S.cmp = (S.cmp || []).filter(exists);
    snap = takeSnap();
    H.saveLocal();
    // Antall fullførte oppdrag lagres på profilen, så alle besøkende ser riktig tall
    if (S.profile) {
      const done = Math.max((S.extraReviews[S.profile.id] || []).length, S.orders.filter((o) => o.fid === S.profile.id && o.status === 'approved').length);
      if (done > (S.profile.jobs || 0)) { S.profile.jobs = done; if (C.ready) H.save(); else C.dirty = true; }
    }
  };

  /* ---------- send endringer (push) ---------- */
  function takeSnap() {
    const offers = {};
    S.myJobs.forEach((j) => (j.offersList || []).forEach((o) => (offers[j.id + '|' + o.fid] = { seen: !!o.seen })));
    const threads = {}; Object.keys(S.threads).forEach((k) => (threads[k] = S.threads[k].length));
    const reviews = []; Object.values(S.extraReviews || {}).forEach((l) => l.forEach((r) => r[5] && reviews.push(r[5])));
    return {
      user: !!S.user, photo: (S.user && S.user.photo) || null, profile: S.profile ? JSON.stringify(freelancerRow(S.profile)) : null,
      jobs: Object.fromEntries(S.myJobs.map((j) => [j.id, JSON.stringify(jobRow(j))])), offers,
      sent: Object.keys(S.sentOffers || {}),
      orders: Object.fromEntries(S.orders.map((o) => [o.id, JSON.stringify(orderRow(o))])),
      threads, reviews, saved: (S.saved || []).slice()
    };
  }

  async function push() {
    if (!snap) return;
    if (snap.user && !S.user) { await sb.auth.signOut(); snap = takeSnap(); return; }
    if (!C.uid) { snap = takeSnap(); return; }
    const next = takeSnap();

    if (S.user && next.photo !== snap.photo) must(await sb.from('profiles').update({ avatar_url: next.photo }).eq('id', C.uid));
    if (S.profile && next.profile !== snap.profile) must(await sb.from('freelancers').upsert(freelancerRow(S.profile)));

    for (const j of S.myJobs) {
      const row = jobRow(j);
      if (!snap.jobs[j.id]) must(await sb.from('jobs').insert(row));
      else if (snap.jobs[j.id] !== next.jobs[j.id]) must(await sb.from('jobs').update({ status: row.status, data: row.data }).eq('id', j.id));
    }
    for (const id of Object.keys(snap.jobs)) if (!next.jobs[id]) must(await sb.from('jobs').delete().eq('id', id));

    for (const j of S.myJobs) for (const o of j.offersList || []) {
      const k = j.id + '|' + o.fid;
      if (!snap.offers[k]) must(await sb.from('offers').insert({ job_id: j.id, freelancer_id: o.fid, price: Math.round(o.price), msg: o.msg || '', visible_at: new Date(o.at || Date.now()).toISOString(), seen: !!o.seen }));
      else if (snap.offers[k].seen !== !!o.seen) must(await sb.from('offers').update({ seen: !!o.seen }).eq('job_id', j.id).eq('freelancer_id', o.fid));
    }

    if (S.profile) {
      for (const jid of next.sent) if (!snap.sent.includes(jid)) { const o = S.sentOffers[jid]; must(await sb.from('offers').insert({ job_id: jid, freelancer_id: S.profile.id, price: Math.round(o.price), msg: o.msg || '' })); }
      for (const jid of snap.sent) if (!next.sent.includes(jid)) must(await sb.from('offers').delete().eq('job_id', jid).eq('freelancer_id', S.profile.id));
    }

    for (const o of S.orders) {
      const row = orderRow(o);
      if (!snap.orders[o.id]) must(await sb.from('orders').insert(row));
      else if (snap.orders[o.id] !== next.orders[o.id]) must(await sb.from('orders').update({ status: row.status, reviewed: row.reviewed, price: row.price, data: row.data }).eq('id', o.id));
    }

    const rows = [];
    for (const key of Object.keys(S.threads)) {
      const list = S.threads[key], from = snap.threads[key] || 0;
      list.slice(from).forEach((m) => {
        if (key.startsWith('c:')) {
          if (!S.profile) return;
          rows.push({ customer_id: key.slice(2), freelancer_id: S.profile.id, sender: m.who === 'sys' ? 'system' : 'freelancer', text: m.text });
        } else rows.push({ customer_id: C.uid, freelancer_id: key, sender: m.who === 'me' ? 'customer' : m.who === 'sys' ? 'system' : 'freelancer', text: m.text });
      });
    }
    if (rows.length) must(await sb.from('messages').insert(rows));

    for (const [fid, list] of Object.entries(S.extraReviews || {})) for (const r of list) {
      if (r[4] && r[5] && !snap.reviews.includes(r[5])) must(await sb.from('reviews').insert({ order_id: r[5], author_id: C.uid, freelancer_id: fid, author_name: r[0], stars: r[1], job_label: r[2], text: r[3] }));
    }

    for (const id of next.saved) if (!snap.saved.includes(id)) must(await sb.from('saved').insert({ user_id: C.uid, freelancer_id: id }));
    for (const id of snap.saved) if (!next.saved.includes(id)) must(await sb.from('saved').delete().eq('user_id', C.uid).eq('freelancer_id', id));

    snap = next;
  }

  let chain = Promise.resolve();
  const errText = (e) => {
    const m = (e && (e.message || e.error_description)) || String(e);
    if (/row-level security/i.test(m)) return 'Du har ikke tilgang til å gjøre dette.';
    if (/Failed to fetch|NetworkError/i.test(m)) return 'Fikk ikke kontakt med serveren. Sjekk nettet og prøv igjen.';
    return m;
  };
  H.save = () => {
    H.saveLocal();
    if (!C.ready) return;
    chain = chain.then(push).catch((e) => { console.error(e); H.toast('Kunne ikke lagre: ' + errText(e)); snap = takeSnap(); });
  };
  H.flush = () => chain;
  H.go = async (url) => { await H.flush(); location.href = url; };
  H.refresh = async () => { await H.flush(); await C.pull(); };

  /* ---------- bilder ---------- */
  H.storeImage = async (kind, blob) => {
    if (!C.uid) throw new Error('Du må være logget inn for å laste opp bilder.');
    const ext = { 'image/webp': 'webp', 'image/png': 'png', 'video/mp4': 'mp4', 'video/quicktime': 'mov', 'video/webm': 'webm' }[blob.type] || 'jpg';
    const path = `${C.uid}/${kind}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}.${ext}`;
    const r = await sb.storage.from('profiles').upload(path, blob, { contentType: blob.type, upsert: false });
    if (r.error) throw new Error(/bucket not found/i.test(r.error.message) ? 'Bildelagringen er ikke satt opp. Kjør database/bilder.sql i Supabase.'
      : /mime|size|exceeded|too large/i.test(r.error.message) && /^video/.test(blob.type) ? 'Videolagring er ikke slått på ennå. Kjør database/video.sql i Supabase.' : r.error.message);
    return sb.storage.from('profiles').getPublicUrl(path).data.publicUrl;
  };
  H.dropImage = async (url) => {
    const m = String(url || '').match(/\/object\/public\/profiles\/(.+)$/);
    if (m && C.uid) await sb.storage.from('profiles').remove([decodeURIComponent(m[1])]);
  };

  /* ---------- innlogging ---------- */
  C.signUp = async (name, email, password) => {
    const back = location.href.replace(/[^/]*$/, '') + 'logg-inn.html';
    const r = await sb.auth.signUp({ email, password, options: { data: { name }, emailRedirectTo: back } });
    if (r.error) throw r.error;
    return !!r.data.session;
  };
  C.signIn = async (email, password) => { const r = await sb.auth.signInWithPassword({ email, password }); if (r.error) throw r.error; };
  C.signOut = async () => { await H.flush(); await sb.auth.signOut(); };
  C.deleteAccount = async () => { await H.flush(); const r = await sb.rpc('delete_my_account'); if (r.error) throw r.error; await sb.auth.signOut(); };
  C.authError = (e) => {
    const m = (e && e.message) || '';
    if (/Invalid login credentials/i.test(m)) return 'Feil e-post eller passord.';
    if (/already registered|already been registered/i.test(m)) return 'Det finnes allerede en konto med denne e-posten. Logg inn i stedet.';
    if (/Email not confirmed/i.test(m)) return 'Du må bekrefte e-posten din først. Sjekk innboksen.';
    if (/at least 6|Password should/i.test(m)) return 'Passordet må ha minst 6 tegn.';
    if (/valid email|invalid format/i.test(m)) return 'Skriv inn en gyldig e-postadresse.';
    if (/rate limit|too many/i.test(m)) return 'For mange forsøk. Vent litt og prøv igjen.';
    if (/signups? (are|is) disabled|signups not allowed/i.test(m)) return 'Det er ikke mulig å opprette nye kontoer akkurat nå. (Supabase: e-postinnlogging eller nye registreringer er slått av.)';
    return errText(e);
  };

  /* ---------- oppstart ---------- */
  H.mountHeader(); H.mountFooter();
  document.querySelectorAll('[data-skel]').forEach((n) => { n.setAttribute('aria-busy', 'true'); n.innerHTML = H.skel(n.dataset.skel); });
  C.pull()
    .then(() => { C.ready = true; if (C.dirty) { C.dirty = false; H.save(); } })
    .catch((e) => {
      console.error(e);
      const missing = /does not exist|schema cache|PGRST205|42P01/i.test((e && (e.message || e.code)) || '');
      C.on = false;
      H.save = H.saveLocal; H.go = (url) => { location.href = url; }; H.flush = () => Promise.resolve();
      Object.assign(S, H.load(true));
      H.prune();
      H.flashNow = missing ? 'Databasen er ikke satt opp ennå. Siden kjører i demo-modus.' : 'Fikk ikke kontakt med databasen. Siden kjører i demo-modus.';
    })
    .finally(runPageScripts);
})();
