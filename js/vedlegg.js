/* Vedlegg i meldinger.
   Filene sendes over HTTPS (TLS) og lagres i en privat mappe i Supabase Storage («vedlegg»), som Supabase
   krypterer på disken. Bare kunden og frilanseren i samtalen kan åpne dem: reglene i database/vedlegg.sql
   sjekker hvem du er, og filene vises med lenker som slutter å virke etter en time.
   Krever database/vedlegg.sql. */
window.Vedlegg = (function () {
  const BUCKET = 'vedlegg', MAX = 25 * 1024 * 1024, MAXN = 5;
  // Filtyper som kan sendes. Samme liste som i database/vedlegg.sql.
  const TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif', 'image/avif',
    'video/mp4', 'video/quicktime', 'video/webm', 'audio/mpeg', 'audio/mp4', 'audio/wav', 'audio/x-m4a',
    'application/pdf', 'text/plain', 'text/csv', 'application/zip', 'application/x-zip-compressed',
    'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'];
  // Noen nettlesere gir ingen filtype. Da gjettes den ut fra filendelsen.
  const BY_EXT = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp', gif: 'image/gif', heic: 'image/heic', heif: 'image/heif', avif: 'image/avif', mp4: 'video/mp4', mov: 'video/quicktime', webm: 'video/webm', mp3: 'audio/mpeg', m4a: 'audio/mp4', wav: 'audio/wav', pdf: 'application/pdf', txt: 'text/plain', csv: 'text/csv', zip: 'application/zip', doc: 'application/msword', docx: TYPES[20], xls: TYPES[21], xlsx: TYPES[22], ppt: TYPES[23], pptx: TYPES[24] };
  const typeOf = (file) => (TYPES.includes(file.type) ? file.type : BY_EXT[String(file.name).split('.').pop().toLowerCase()] || '');
  const urls = {};
  const api = {
    MAX, MAXN, TYPES,
    accept: TYPES.join(','),
    // Lagringen. Kan byttes ut i tester.
    store: () => (window.Cloud && Cloud.on && Cloud.sb ? Cloud.sb.storage.from(BUCKET) : null),
    // Hvem samtalen er mellom: kunde-id og frilanser-id. key er nøkkelen i S.threads.
    convo(key) {
      const S = H.S, uid = window.Cloud && Cloud.uid;
      if (!uid) return null;
      if (String(key).startsWith('c:')) return S.profile ? { cid: key.slice(2), fid: S.profile.id } : null;
      return { cid: uid, fid: key };
    },
    // Teksten som sendes når meldingen bare er vedlegg (vises i lista over samtaler)
    label: (files) => '📎 ' + (files.length === 1 ? files[0].n : files.length + ' filer'),
    // Gyldig vedlegg fra en melding. Det kommer fra databasen, så det sjekkes før det brukes.
    valid: (x) => !!x && typeof x.n === 'string' && typeof x.p === 'string' && /^[0-9a-f-]{36}\/[^/]{1,80}\/[A-Za-z0-9-]{8,60}$/.test(x.p),
    isImage: (x) => /^image\/(jpeg|png|webp|gif|avif)$/.test(x.t || ''),
    // Sjekker filen før opplasting. Gir en feilmelding, eller tom tekst hvis den er grei.
    check(file) {
      if (file.size > MAX) return `${file.name} er større enn 25 MB.`;
      if (!typeOf(file)) return `${file.name} kan ikke sendes. Send bilder, video, PDF, Office-filer eller zip.`;
      return '';
    },
    // Laster opp én fil. Gir tilbake det som lagres i meldingen.
    async upload(file, convo) {
      const err = api.check(file); if (err) throw new Error(err);
      const st = api.store(); if (!st || !convo) throw new Error('Logg inn for å sende vedlegg.');
      const id = crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36) + Math.random().toString(36).slice(2, 12);
      const path = `${convo.cid}/${convo.fid}/${id}`, type = typeOf(file);
      const r = await st.upload(path, file, { contentType: type, upsert: false });
      if (r.error) {
        const m = r.error.message || '';
        if (/bucket not found/i.test(m)) throw new Error('Vedlegg er ikke slått på ennå. Kjør database/vedlegg.sql i Supabase.');
        if (/row-level security|policy|unauthorized/i.test(m)) throw new Error('Du kan ikke sende filer i denne samtalen ennå.');
        if (/mime|type/i.test(m)) throw new Error(`${file.name} kan ikke sendes. Send bilder, video, PDF, Office-filer eller zip.`);
        throw new Error(m);
      }
      return { n: String(file.name || 'fil').slice(0, 120), t: type, s: file.size, p: path };
    },
    // Lenke til filen som virker i en time. Med download lastes den ned med riktig navn.
    async url(x, download) {
      const k = x.p + (download ? '#dl' : '');
      if (urls[k] && urls[k].until > Date.now()) return urls[k].url;
      const st = api.store(); if (!st) throw new Error('Logg inn for å åpne vedlegg.');
      const r = await st.createSignedUrl(x.p, 3600, download ? { download: x.n } : undefined);
      if (r.error) throw new Error('Fant ikke filen. Den kan være slettet.');
      urls[k] = { url: r.data.signedUrl, until: Date.now() + 50 * 60 * 1000 };
      return r.data.signedUrl;
    },
    // Laster ned filen til enheten
    async save(x) {
      const a = document.createElement('a'); a.href = await api.url(x, true); a.download = x.n; a.rel = 'noopener';
      document.body.appendChild(a); a.click(); a.remove();
    }
  };
  return api;
})();
