/* Leveranser: komprimerte forhåndsvisninger og originalfiler.
   Bilder skaleres ned og lagres som WebP/JPEG for visning. Video får et stillbilde (plakat) for visning.
   Originalene lagres urørt i nettleserens IndexedDB, og kan lastes ned i full kvalitet.
   I den ferdige appen gjør serveren dette (for eksempel med Cloudflare Images / Stream eller Mux),
   og originalene ligger i lagring som S3 eller Supabase Storage. */
window.Media = (function () {
  const DB = 'freelio-media', STORE = 'files';
  const PREVIEW_MAX = 1600, THUMB_MAX = 480;
  let dbp;

  const db = () => dbp || (dbp = new Promise((res, rej) => {
    const r = indexedDB.open(DB, 1);
    r.onupgradeneeded = () => { const s = r.result.createObjectStore(STORE, { keyPath: 'id' }); s.createIndex('order', 'orderId'); };
    r.onsuccess = () => res(r.result);
    r.onerror = () => rej(r.error);
  }));
  const tx = async (mode, fn) => { const d = await db(); return new Promise((res, rej) => { const t = d.transaction(STORE, mode); const out = fn(t.objectStore(STORE)); t.oncomplete = () => res(out && out.result !== undefined ? out.result : out); t.onerror = () => rej(t.error); }); };

  const put = (rec) => tx('readwrite', (s) => s.put(rec));
  const get = (id) => tx('readonly', (s) => s.get(id));
  const byOrder = (orderId) => tx('readonly', (s) => s.index('order').getAll(orderId));
  const removeOrder = async (orderId) => { const all = await byOrder(orderId); return tx('readwrite', (s) => all.forEach((r) => s.delete(r.id))); };

  const canvasBlob = (cv, q) => new Promise((res) => cv.toBlob((b) => (b && b.type === 'image/webp' ? res(b) : cv.toBlob(res, 'image/jpeg', q)), 'image/webp', q));
  const fit = (w, h, max) => { const k = Math.min(1, max / Math.max(w, h)); return [Math.round(w * k), Math.round(h * k)]; };
  const draw = (src, w, h, max) => { const [cw, ch] = fit(w, h, max); const cv = document.createElement('canvas'); cv.width = cw; cv.height = ch; cv.getContext('2d').drawImage(src, 0, 0, cw, ch); return cv; };

  async function fromImage(file) {
    let bmp;
    try { bmp = await createImageBitmap(file, { imageOrientation: 'from-image' }); }
    catch (e) { bmp = await new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = rej; i.src = URL.createObjectURL(file); }); }
    const w = bmp.width || bmp.naturalWidth, h = bmp.height || bmp.naturalHeight;
    const preview = await canvasBlob(draw(bmp, w, h, PREVIEW_MAX), 0.8);
    const thumb = await canvasBlob(draw(bmp, w, h, THUMB_MAX), 0.72);
    return { type: 'image', w, h, preview, thumb };
  }

  function fromVideo(file) {
    return new Promise((res, rej) => {
      const v = document.createElement('video');
      const url = URL.createObjectURL(file);
      v.muted = true; v.playsInline = true; v.preload = 'auto'; v.src = url;
      v.onerror = () => { URL.revokeObjectURL(url); rej(new Error('Kunne ikke lese videoen')); };
      v.onloadedmetadata = () => { v.currentTime = Math.min(1, (v.duration || 2) * 0.1); };
      v.onseeked = async () => {
        const w = v.videoWidth, h = v.videoHeight;
        const preview = await canvasBlob(draw(v, w, h, 1280), 0.78);
        const thumb = await canvasBlob(draw(v, w, h, THUMB_MAX), 0.7);
        URL.revokeObjectURL(url);
        res({ type: 'video', w, h, duration: v.duration, preview, thumb });
      };
    });
  }

  // Behandler én fil og lagrer original og forhåndsvisning. Returnerer metadata som kan lagres sammen med bestillingen.
  async function add(orderId, file, onProgress) {
    const isVideo = file.type.startsWith('video/');
    if (!isVideo && !file.type.startsWith('image/')) throw new Error('Bare bilder og video kan lastes opp');
    const p = isVideo ? await fromVideo(file) : await fromImage(file);
    const id = 'm' + Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
    let parts = 0;
    if (cloud()) {
      if (file.size > MAX_FILE) throw new Error('Filen er større enn ' + size(MAX_FILE) + '. Del den opp eller send den på en annen måte.');
      const st = Cloud.sb.storage.from(BUCKET);
      const up = async (path, blob) => {
        const r = await st.upload(`${orderId}/${id}/${path}`, blob, { contentType: blob.type || file.type || 'application/octet-stream', upsert: false });
        if (r.error) throw new Error(r.error.message);
      };
      const say = (t) => onProgress && onProgress(t);
      await up('thumb', p.thumb); await up('preview', p.preview);
      if (isVideo) {
        // «stream» er versjonen kunden ser før godkjenning. Store videoer får en mindre utgave.
        const stream = file.size <= CHUNK ? file : await H.fitVideo(file, (pc) => say(`Lager forhåndsvisning … ${pc} %`), { max: CHUNK, minBr: 150000 });
        say('Laster opp forhåndsvisning …'); await up('stream', stream);
      }
      // Originalen. Over 45 MB deles den i biter (Supabase gratis tar maks 50 MB per fil). Låst til kunden har godkjent.
      if (!isVideo || file.size > CHUNK) {
        if (file.size <= CHUNK) await up('original', file);
        else {
          parts = Math.ceil(file.size / CHUNK);
          for (let i = 0; i < parts; i++) { say(`Laster opp original … ${Math.round((i / parts) * 100)} %`); await up(`original/${i}`, file.slice(i * CHUNK, (i + 1) * CHUNK, 'application/octet-stream')); }
        }
      }
    } else await put({ id, orderId, name: file.name, mime: file.type, original: file, preview: p.preview, thumb: p.thumb });
    return { id, name: file.name, type: p.type, mime: file.type, size: file.size, psize: p.preview.size, w: p.w, h: p.h, duration: p.duration || 0, parts };
  }

  // Lager eksempelfiler, så flyten kan testes uten egne bilder
  async function sample(orderId, n, pal) {
    const out = [];
    for (let i = 0; i < n; i++) {
      const cv = document.createElement('canvas'); cv.width = 4000; cv.height = 2667;
      const c = cv.getContext('2d'); const p = pal(i);
      c.fillStyle = p[0]; c.fillRect(0, 0, 4000, 1520);
      c.fillStyle = p[1]; c.fillRect(0, 1520, 4000, 1147);
      c.fillStyle = p[2]; c.beginPath(); c.arc(2900, 850, 280, 0, 7); c.fill();
      c.globalAlpha = 0.5; c.fillStyle = p[1]; c.beginPath(); c.ellipse(1300, 1520, 2200, 360, 0, Math.PI, 0); c.fill();
      for (let k = 0; k < 9000; k++) { c.globalAlpha = 0.05; c.fillStyle = k % 2 ? '#000' : '#fff'; c.fillRect(Math.random() * 4000, Math.random() * 2667, 3, 3); }
      const blob = await new Promise((r) => cv.toBlob(r, 'image/png'));
      out.push(await add(orderId, new File([blob], `IMG_${4200 + i}.png`, { type: 'image/png' })));
    }
    return out;
  }

  const size = (b) => (b >= 1e9 ? (b / 1e9).toFixed(1) + ' GB' : b >= 1e6 ? (b / 1e6).toFixed(1) + ' MB' : Math.max(1, Math.round(b / 1e3)) + ' kB').replace('.', ',');
  const dur = (s) => { s = Math.round(s || 0); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); };

  function download(blob, name) {
    const a = document.createElement('a'); const url = URL.createObjectURL(blob);
    a.href = url; a.download = name; document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 4000);
  }

  const remove = (id) => tx('readwrite', (s) => s.delete(id));

  /* ---------- felles for demo (IndexedDB) og Supabase Storage ---------- */
  const BUCKET = 'deliveries', CHUNK = 45 * 1024 * 1024, MAX_FILE = 4 * 1024 * 1024 * 1024;
  const cloud = () => window.Cloud && Cloud.on && Cloud.sb;
  const kindFor = (meta, kind) => (kind === 'original' && meta.type === 'video' ? 'stream' : kind);
  const urlCache = {};
  // Adresse til en fil for visning: thumb, preview eller original
  async function url(orderId, meta, kind) {
    const k = meta.id + kind;
    if (urlCache[k]) return urlCache[k];
    if (cloud()) {
      const r = await Cloud.sb.storage.from(BUCKET).createSignedUrl(`${orderId}/${meta.id}/${kindFor(meta, kind)}`, 3600);
      if (r.error) return '';
      return (urlCache[k] = r.data.signedUrl);
    }
    const rec = await get(meta.id);
    return rec ? (urlCache[k] = URL.createObjectURL(rec[kind])) : '';
  }
  // Last ned originalen i full kvalitet
  async function save(orderId, meta, onProgress) {
    if (cloud() && meta.parts) {
      // Henter bitene og setter dem sammen til én fil igjen
      const st = Cloud.sb.storage.from(BUCKET), chunks = [];
      for (let i = 0; i < meta.parts; i++) {
        if (onProgress) onProgress(Math.round((i / meta.parts) * 100));
        const r = await st.createSignedUrl(`${orderId}/${meta.id}/original/${i}`, 600);
        if (r.error) return false;
        const res = await fetch(r.data.signedUrl); if (!res.ok) return false;
        chunks.push(await res.blob());
      }
      if (onProgress) onProgress(100);
      download(new Blob(chunks, { type: meta.mime || 'application/octet-stream' }), meta.name);
      return true;
    }
    if (cloud()) {
      const r = await Cloud.sb.storage.from(BUCKET).createSignedUrl(`${orderId}/${meta.id}/${meta.type === 'video' ? 'stream' : 'original'}`, 300, { download: meta.name });
      if (r.error) return false;
      const a = document.createElement('a'); a.href = r.data.signedUrl; a.download = meta.name; document.body.appendChild(a); a.click(); a.remove();
      return true;
    }
    const rec = await get(meta.id);
    if (!rec) return false;
    download(rec.original, meta.name);
    return true;
  }
  async function discard(orderId, meta) {
    if (cloud()) {
      const paths = ['thumb', 'preview', meta.type === 'video' ? 'stream' : 'original'].concat(Array.from({ length: meta.parts || 0 }, (_, i) => 'original/' + i));
      await Cloud.sb.storage.from(BUCKET).remove(paths.map((k) => `${orderId}/${meta.id}/${k}`)); return;
    }
    return remove(meta.id);
  }

  return { add, sample, get, byOrder, remove, removeOrder, url, save, discard, size, dur, download, supported: 'indexedDB' in window || !!cloud() };
})();
