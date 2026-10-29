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
  async function add(orderId, file) {
    const isVideo = file.type.startsWith('video/');
    if (!isVideo && !file.type.startsWith('image/')) throw new Error('Bare bilder og video kan lastes opp');
    const p = isVideo ? await fromVideo(file) : await fromImage(file);
    const id = 'm' + Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
    await put({ id, orderId, name: file.name, mime: file.type, original: file, preview: p.preview, thumb: p.thumb });
    return { id, name: file.name, type: p.type, mime: file.type, size: file.size, psize: p.preview.size, w: p.w, h: p.h, duration: p.duration || 0 };
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

  return { add, sample, get, byOrder, remove, removeOrder, size, dur, download, supported: 'indexedDB' in window };
})();
